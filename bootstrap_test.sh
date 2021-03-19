set -e -u

###############################################################################
#                               HOW TO USE                                    #
#                                                                             #
#       Please adjust every variable within a "FIX-ME" markup to your         #
#       filesystem, data, and software container.                             #
#       Depending on which job scheduling system you use, comment out         #
#       or remove the irrelevant system.                                      #
#       More information about this script can be found in the README.        #
#                                                                             #
###############################################################################


# Jobs are set up to not require a shared filesystem (except for the lockfile)
# ------------------------------------------------------------------------------
# FIX-ME: Supply a RIA-URL to a RIA store that will collect all outputs, and a
# RIA-URL to a different RIA store from which the dataset will be cloned from.
# Both RIA stores will be created if they don't yet exist.
output_store="ria+file:///data/group/psyinf/myoutputstore"
input_store="ria+file:///data/group/psyinf/myinputstore"
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


# ------------------------------------------------------------------------------
# FIX-ME: Supply the name of container you have registered (see README for info)
# FIX-ME: Supply a path or URL to the place where your container dataset is
# located, and a path or URL to the place where an input (super)dataset exists.
containername='bids-fmriprep'
container="https://github.com/ReproNim/containers.git"
data="https://github.com/psychoinformatics-de/studyforrest-data-structural.git"
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


#-------------------------------------------------------------------------------
# FIX-ME: Replace this name with a dataset name of your choice.
source_ds="forrest"
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


# Create a source dataset with all analysis components as an analysis access
# point.
datalad create -c yoda $source_ds
cd $source_ds

# clone the container-dataset as a subdataset. Please see README for
# instructions how to create a container dataset.
datalad clone -d . "${container}" code/pipeline

# Register the container in the top-level dataset.
#-------------------------------------------------------------------------------
# FIX-ME: If necessary, configure your own container call in the --call-fmt
# argument. If your container does not need a custom call format, remove the
# --call-fmt flag and its options below.
datalad containers-add \
  --call-fmt 'singularity run -B {{pwd}} --cleanenv {img} {cmd}' \
  -i code/pipeline/images/bids/bids-fmriprep--20.2.0.sing \
  $containername
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


# amend the previous commit with a nicer commit message
git commit --amend -m 'Register pipeline dataset'


# import custom code
# ------------------------------------------------------------------------------
# FIX-ME: If you need custom scripts, copy them into the analysis source
# dataset. If you don't need custom scripts, remove the copy and commit
# operations below. (The scripts below are only relevant for CAT processing)
cp ~/license.txt code/license.txt
datalad save -m "Add Freesurfer license file"
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


# create dedicated input and output locations. Results will be pushed into the
# output sibling and the analysis will start with a clone from the input sibling.
datalad create-sibling-ria -s output "${output_store}"
pushremote=$(git remote get-url --push output)
datalad create-sibling-ria -s input --storage-sibling off "${input_store}"

# register the input dataset
datalad clone -d . ${data} inputs/data
# amend the previous commit with a nicer commit message
git commit --amend -m 'Register input data dataset as a subdataset'


# the actual compute job specification
cat > code/participant_job << "EOT"
#!/bin/bash

# the job assumes that it is a good idea to run everything in PWD
# the job manager should make sure that is true

# fail whenever something is fishy, use -x to get verbose logfiles
set -e -u -x

dssource="$1"
pushgitremote="$2"
subid="$3"

# get the analysis dataset, which includes the inputs as well
# importantly, we do not clone from the lcoation that we want to push the
# results too, in order to avoid too many jobs blocking access to
# the same location and creating a throughput bottleneck
datalad clone "${dssource}" ds

# all following actions are performed in the context of the superdataset
cd ds

# in order to avoid accumulation temporary git-annex availability information
# and to avoid a syncronization bottleneck by having to consolidate the
# git-annex branch across jobs, we will only push the main tracking branch
# back to the output store (plus the actual file content). Final availability
# information can be establish via an eventual `git-annex fsck -f joc-storage`.
# this remote is never fetched, it accumulates a larger number of branches
# and we want to avoid progressive slowdown. Instead we only ever push
# a unique branch per each job (subject AND process specific name)
git remote add outputstore "$pushgitremote"

# all results of this job will be put into a dedicated branch
git checkout -b "job-$JOBID"

# we pull down the input subject manually in order to discover relevant
# files. We do this outside the recorded call, because on a potential
# re-run we want to be able to do fine-grained recomputing of individual
# outputs. The recorded calls will have specific paths that will enable
# recomputation outside the scope of the original Condor setup
datalad get -n "inputs/data/${subid}"

# -----------------------------------------------------------------------------
# FMRIPREP SPECIFIC ADJUSTMENTS - NOT NECESSARY FOR OTHER PIPELINES
# create workdir for fmriprep inside to simplify singularity call
# PWD will be available in the container
mkdir -p .git/tmp/wdir
# pybids (inside fmriprep) gets angry when it sees dangling symlinks
# of .json files -- wipe them out, spare only those that belong to
# the participant we want to process in this job
find inputs/data -mindepth 2 -name '*.json' -a ! -wholename "$3"'*T*w*' -delete

# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^




# ------------------------------------------------------------------------------
# FIX-ME: Replace the datalad containers-run command starting below with a
# command that fits your analysis. (Note that the command for CAT processing is
# quite complex and involves separate scripts - if you are not using CAT
# processing, remove everything until \; )

# the meat of the matter
# look for T1w files in the input data for the given participant
# it is critical for reproducibility that the command given to
# `containers-run` does not rely on any property of the immediate
# computational environment (env vars, services, etc)
datalad containers-run \
   -m "Compute ${subid}" \
   -n bids-fmriprep \
   --explicit \
   -o fmriprep/${subid} \
   -i inputs/data/${subid}/anat/ \
   -i code/license.txt \
    "inputs/data . participant --participant-label $subid --anat-only -w .git/tmp/wdir --fs-no-reconall --skip-bids-validation --fs-license-file {inputs[1]}"
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

# it may be that the above command did not yield any outputs
# and no commit was made (no T1s found for the given participant)
# we nevertheless push the branch to have a record that this was
# attempted and did not fail

# file content first -- does not need a lock, no interaction with Git
datalad push --to output-storage
# and the output branch
flock --verbose $DSLOCKFILE git push outputstore

echo SUCCESS
# job handler should clean up workspace
EOT
chmod +x code/participant_job
datalad save -m "Participant compute job implementation"

mkdir logs
echo logs >> .gitignore

###############################################################################
# HTCONDOR SETUP START - remove or adjust this according to your needs.
###############################################################################

# HTCondor compute setup
# the workspace is to be ignored by git
echo dag_tmp >> .gitignore
echo .condor_datalad_lock >> .gitignore

## define ID for git commits (take from local user configuration)
git_name="$(git config user.name)"
git_email="$(git config user.email)"

# compute environment for a single job
#-------------------------------------------------------------------------------
# FIX-ME: Adjust job requirements to your needs

cat > code/process.condor_submit << EOT
universe       = vanilla
# resource requirements for each job
request_cpus   = 1
request_memory = 4G
request_disk   = 5G

# tell condor that a job is self contained and the executable
# is enough to bootstrap the computation on the execute node
should_transfer_files = yes
# explicitly do not transfer anything back
# we are using datalad for everything that matters
transfer_output_files = ""

# the actual job script, nothing condor-specific in it
executable     = \$ENV(PWD)/code/participant_job

# the job expects these environment variables for labeling and synchronization
# - JOBID: subject AND process specific ID to make a branch name from
#     (must be unique across all (even multiple) submissions)
#     including the cluster ID will enable sorting multiple computing attempts
# - DSLOCKFILE: lock (must be accessible from all compute jobs) to synchronize
#     write access to the output dataset
# - DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__...:
#     (additional) locations for datalad to locate relevant subdatasets, in case
#     a configured URL is outdated
# - GIT_AUTHOR_...: Identity information used to save dataset changes in compute
#     jobs
environment = "\\
  JOBID=\$(subject).\$(Cluster) \\
  DSLOCKFILE=\$ENV(PWD)/.condor_datalad_lock \\
  DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__101cat='ria+http://containers.ds.inm7.de#{id}' \\
  GIT_AUTHOR_NAME='${git_name}' \\
  GIT_AUTHOR_EMAIL='${git_email}' \\
  "

# place the job logs into PWD/logs, using the same name as for the result branches
# (JOBID)
log    = \$ENV(PWD)/logs/\$(subject)_\$(Cluster).log
output = \$ENV(PWD)/logs/\$(subject)_\$(Cluster).out
error  = \$ENV(PWD)/logs/\$(subject)_\$(Cluster).err
# essential args for 'participant_job'
# 1: where to clone the analysis dataset
# 2: location to push the result git branch to. The 'ria+' prefix is stripped.
# 3: ID of the subject to process
arguments = "\\
  ${input_store}#$(datalad -f '{infos[dataset][id]}' wtf -S dataset) \\
  ${pushremote} \\
  sub-\$(subject) \\
  "
queue
EOT

# ------------------------------------------------------------------------------
# FIX-ME: Adjust the find command below to return the unit over which your
# analysis should parallelize. Here, subject directories on the first hierarchy
# level in the input data are returned by searching for the 'sub-*' prefix.
# The setup below creates an HTCondor DAG.
# ------------------------------------------------------------------------------
# processing graph specification for computing all jobs
cat > code/process.condor_dag << "EOT"
# Processing DAG
EOT
for s in $(find inputs/data -maxdepth 1 -type d -name 'sub-*' -printf '%f\n'); do
  s=${s:4}
  printf "JOB sub-$s code/process.condor_submit\nVARS sub-$s subject=\"$s\"\n" >> code/process.condor_dag
done
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

datalad save -m "HTCondor submission setup" code/ .gitignore

################################################################################
# HTCONDOR SETUP END
################################################################################


################################################################################
# SLURM SETUP START - remove or adjust to your needs
################################################################################

echo .SLURM_datalad_lock >> .gitignore

# SLURM compute environment
# makes sure that the jobs per node don't exceed RAM and wall clock time !!
cat > code/process.sbatch << "EOT"
#!/bin/bash -x
#SBATCH --account=jinm72
#SBATCH --mail-user=FIXME
#SBATCH --mail-type=END
#SBATCH --job-name=FIXME
#SBATCH --output=logs/processing-out.%j
#SBATCH --error=logs/processing-err.%j
#SBATCH --time=24:00:00
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=256
#SBATCH --partition=dc-cpu-bigmem
#SBATCH --nodes=1

srun parallel --delay 0.2  -a code/aomic_cat.jobs --use-cpus-instead-of-cores

wait
EOT



# create job.call-file for all commands to call
# each subject is processed on RAMDISK in an own dataset
fastdata=/dev/shm/

cat > code/call.cat << EOT
#!/bin/bash -x
#
# redundant input per subject

subid=\$1

# define DSLOCKFILE, DATALAD & GIT ENV for participant_job
export DSLOCKFILE=$(pwd)/.SLURM_datalad_lock \
DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__100aomic=${input_store}#{id} \
DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__101cat=${container}#{id} \
GIT_AUTHOR_NAME=\$(git config user.name) \
GIT_AUTHOR_EMAIL=\$(git config user.email) \
JOBID=\${subid:4}.\${SLURM_JOB_ID} \

# use subject specific folder
mkdir $fastdata\${subid}
cd $fastdata\${subid}

# run things
$(pwd)/code/participant_job \
${input_store}#$(datalad -f '{infos[dataset][id]}' wtf -S dataset) \
$(git remote get-url --push output) \
\${subid} \
>$(pwd)/logs/\${JOBID}.out \
2>$(pwd)/logs/\${JOBID}.err

EOT

chmod +x code/call.cat

# create job-file with commands for all jobs
cat > code/aomic_cat.jobs << "EOT"
#!/bin/bash
EOT

# ------------------------------------------------------------------------------
# FIX-ME: Adjust the find command below to return the unit over which your
# analysis should parallelize. Here, subject directories on the first hierarchy
# level in the input data are returned by searching for the 'sub-*' prefix.
#
for s in $(find inputs/aomic/ -maxdepth 1 -type d -name 'sub-*' -printf '%f\n'); do
  printf "code/call.cat $s\n" >> code/aomic_cat.jobs
done
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

chmod +x code/aomic_cat.jobs
datalad save -m "SLURM submission setup" code/ .gitignore

################################################################################
# SLURM SETUP END
################################################################################





# cleanup - we have generated the job definitions, we do not need to keep a
# massive input dataset around. Having it around wastes resources and makes many
# git operations needlessly slow
datalad uninstall -r --nocheck inputs/data

# make sure the fully configured output dataset is available from the designated
# store for initial cloning and pushing the results.
datalad push --to input
datalad push --to output

# if we get here, we are happy
echo SUCCESS
