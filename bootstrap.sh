set -e -u

#
#                      HOW TO USE
#
# Please adjust every variable with a "FIX-ME" comment on top.



# Jobs are set up to not require a shared filesystem (except for the lockfile)
# ------------------------------------------------------------------------------
# FIX-ME: Supply a RIA-URL to a RIA store that will collect all outputs, and a
# RIA-URL to a different RIA store from which the dataset will be cloned from.
# Both RIA stores will be created if it doesn't yet exist.
# Note: 'input_store' can be removed after processing has finished. It exists in
# order to be a safe and non-changing place from where the analysis source
# dataset is cloned from.
#-------------------------------------------------------------------------------
output_store="ria+file:///data/group/psyinf/forrestoutput"
input_store="ria+file:///data/group/psyinf/forrestinput"

# ------------------------------------------------------------------------------
# FIX-ME: Supply the name of container you have registered. (See README for more
# information)
# FIX-ME: Supply a path or URL to the place where your container dataset is
# located, and a path or URL to the place where an input (super)dataset exists.
#-------------------------------------------------------------------------------
containername='cat'
container="ria+http://containers.ds.inm7.de#~cat"
data="https://github.com/psychoinformatics-de/studyforrest-data-structural.git"

#-------------------------------------------------------------------------------
# FIX-ME: Replace this name with a dataset name of your choice.
#-------------------------------------------------------------------------------
source_ds="forrest_cat"

# Create a source dataset with all analysis components as an analysis access
# point. Job submission will take place from a checkout of this dataset, but no
# results will be pushed into it
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
  --call-fmt 'singularity exec -B {{pwd}} --cleanenv {img} {cmd}' \
  -i code/pipeline/.datalad/environments/${containername}/image \
  $containername
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

# amend the previous commit with a nicer commit message
git commit --amend -m 'Register pipeline dataset'

# ------------------------------------------------------------------------------
# FIX-ME: If you need custom scripts, copy them into the analysis source
# dataset. If you don't need custom scripts, remove the copy and commit
# operations below. (The scripts below are only relevant for CAT processing)
# ------------------------------------------------------------------------------
# import custom code for CAT
cp /data/group/psyinf/ukb_workflow_template/finalize_job_outputs.sh code
datalad save -m "Import script to tune the CAT outputs for storage"
git commit --no-edit --amend --author "Małgorzata Wierzba <gosia.wierzba@gmail.com>"
cp /data/group/psyinf/ukb_workflow_template/code_cat_standalone_batchUKB.txt code/cat_standalone_batch.txt
datalad save -m "Import desired CAT batch configuration"
git commit --no-edit --amend --author "Felix Hoffstaedter <f.hoffstaedter@fz-juelich.de>"


# create dedicated input and output locations. Results will be pushed into the
# output sibling, and the analysis will start with a clone from the input
# sibling.
datalad create-sibling-ria -s output "${output_store}"
pushremote=$(git remote get-url --push joc)
datalad create-sibling-ria -s input --storage-sibling off "${input_store}"

# register the input dataset
datalad clone -d . ${data} inputs/data
# amend the previous commit with a nicer commit message
git commit --amend -m 'Register input data dataset as a subdataset'


# the actual compute job specification
# TODO: Replace references to analysis-specific stuff in commands (e.g., "ukb")
# TODO: make "joc" more generic, explain that "joc-storage" will be setup
# automatically
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
find \
  inputs/data/${subid} \
  -name '*T1w.nii.gz' \
  -exec sh -c '
    odir=$(echo {} | cut -d / -f3-4);
    datalad -c datalad.annex.retry=12 containers-run \
      -m "Compute $odir" \
      -n cat \
      --explicit \
      -o $odir \
      -i {} \
      -i code/cat_standalone_batch.txt \
      -i code/finalize_job_outputs.sh \
      sh -e -u -x -c "
        rm -rf {outputs[0]}/tmp ;
        mkdir -p {outputs[0]}/tmp \
        && cp {inputs[0]} {outputs[0]}/tmp \
        && gzip -d {outputs[0]}/tmp/* \
        && /singularity -b {inputs[1]} {outputs[0]}/tmp/*.nii \
        && bash {inputs[2]} {inputs[0]} {outputs[0]}/tmp {outputs[0]} \
        && rm -rf {outputs[0]}/tmp \
        " \
  ' \;

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

# HTCondor compute setup
# the workspace is to be ignored by git
mkdir logs
echo logs >> .gitignore
echo dag_tmp >> .gitignore
echo .condor_datalad_lock >> .gitignore

## define ID for git commits (take from local user configuration)
git_name="$(git config user.name)"
git_email="$(git config user.email)"

#-------------------------------------------------------------------------------
# FIX-ME: Adjust job requirements to your needs
#-------------------------------------------------------------------------------

# TODO: Think about clone candidate sources
# compute environment for a single job
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
#  DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__100ukb='ria+http://ukb.ds.inm7.de#{id}' \
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
# ------------------------------------------------------------------------------
# processing graph specification for computing all jobs
cat > code/process.condor_dag << "EOT"
# Processing DAG
EOT
for s in $(find inputs/data -maxdepth 1 -type d -name 'sub-*' -printf '%f\n'); do
  s=${s:4}
  printf "JOB sub-$s code/process.condor_submit\nVARS sub-$s subject=\"$s\"\n" >> code/process.condor_dag
done
datalad save -m "HTCondor submission setup" code/ .gitignore


# cleanup
# we have generated the DAG, we do not need to keep the massive input dataset
# around
# having it around wastes resources and makes many git operations needlessly
# slow
datalad uninstall -r --nocheck inputs/data

# make sure the fully configured output dataset is available from the designated
# store for initial cloning and pushing the results.
datalad push --to input
datalad push --to output

# if we get here, we are happy
echo SUCCESS
