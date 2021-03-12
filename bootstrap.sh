set -e -u

# Jobs are set up to not require a shared filesystem (except for the lockfile)

# submit DAG to condor
# rm -rf dag_tmp; mkdir -p dag_tmp; cp code/process.condor_dag dag_tmp/ && condor_submit_dag -batch-name UKBVBM -maxidle 1 dag_tmp/process.condor_dag

# define ID for git commits (take from local user configuration)
git_name="$(git config user.name)"
git_email="$(git config user.email)"

# ------------------------------------------------------------------------------
# FIX-ME: Supply a RIA-URL to a RIA store that will collect all outputs. This
# RIA store will be created if it doesn't yet exist.
#-------------------------------------------------------------------------------
# define the dataset store all output will go to
output_store="ria+file:///data/project/ukb_vbm/outputstore"

# ------------------------------------------------------------------------------
# FIX-ME: Supply RIA URLs to the RIA stores that host the container dataset and
# the input dataset. TODO: add "how to" in README
#-------------------------------------------------------------------------------
# define the location of the stores all analysis inputs will be obtained from
container_store="ria+http://containers.ds.inm7.de"
ukb_raw_store="ria+http://ukb.ds.inm7.de"
#TODO: make the "ukb_raw_store" name generic
#-------------------------------------------------------------------------------
# FIX-ME: Replace "ukb_cat" with a dataset name of your choice.
#-------------------------------------------------------------------------------
source_ds="ukb_cat"

# Create a source dataset with all analysis components as an analysis access
# point. Job submission will take place from a checkout of this dataset, but no
# results will be pushed into itdatalad create -c yoda $source_ds
cd $source_ds

#-------------------------------------------------------------------------------
# FIX-ME: Replace '~cat' with an alias or dataset ID of your own container
# dataset.
#-------------------------------------------------------------------------------
# register a container with the CAT tool
datalad clone -d . "${container_store}#~cat" code/pipeline

# TODO: add a variable for the container name!

#-------------------------------------------------------------------------------
# FIX-ME: Configure your own container call in the --call-fmt argument.
# {img} and {cmd} are standard placeholders and  will be replaced
# with the container name and the command given in "datalad containers-run".
# Curly brackets in any other parts of this configuration need to be escaped with
# another curly bracket. Replace '~cat' with an alias or dataset ID of your own container
# dataset.
#-------------------------------------------------------------------------------
# configure a custom container call to satisfy the needs of this analysis
datalad containers-add \
  --call-fmt 'singularity exec -B {{pwd}} --cleanenv {img} {cmd}' \
  -i code/pipeline/.datalad/environments/cat/image \
  cat
git commit --amend -m 'Register CAT pipeline dataset'

# import necessary custom code, it will live in the dataset as its original
# location
cp /data/project/ukb_vbm/finalize_job_outputs.sh code
datalad save -m "Import script to tune the CAT outputs for storage"
git commit --no-edit --amend --author "Małgorzata Wierzba <gosia.wierzba@gmail.com>"
cp /data/project/ukb_vbm/code_cat_standalone_batchUKB.txt code/cat_standalone_batch.txt
datalad save -m "Import desired CAT batch configuration"
git commit --no-edit --amend --author "Felix Hoffstaedter <f.hoffstaedter@fz-juelich.de>"


#-------------------------------------------------------------------------------
# FIX-ME: Replace '~bids' with an alias or dataset ID of your own input dataset.
# FIX-ME: Replace "ukb" with a name of your choice
#-------------------------------------------------------------------------------
# register the UKB input dataset, a superdataset with 42k subdatasets
# comprising all participants
datalad clone -d . "${ukb_raw_store}#~bids" inputs/ukb
git commit --amend -m 'Register UKB raw dataset in BIDS format as input'

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
datalad get -n "inputs/ukb/${subid}"

# the meat of the matter
# look for T1w files in the input data for the given participant
# it is critical for reproducibility that the command given to
# `containers-run` does not rely on any property of the immediate
# computational environment (env vars, services, etc)
find \
  inputs/ukb/${subid} \
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

# it may be that the above command did not yield any outputs
# and no commit was made (no T1s found for the given participant)
# we nevertheless push the branch to have a record that this was
# attempted and did not fail

# file content first -- does not need a lock, no interaction with Git
datalad push --to joc-storage
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
# TODO: explain lock file in README
echo .condor_datalad_lock >> .gitignore

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

# tell condor that a job es self contained and the executable
# is enough to bootstrap the computation on the execute node
should_transfer_files = yes
# explicitly do not transfer anything back
# we are using datalad for everything that matters
transfer_output_files = ""

# the actual job script, nothing condor-specific in it
executable     = $ENV(PWD)/code/participant_job

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
environment = "\
  JOBID=$(subject).$(Cluster) \
  DSLOCKFILE=$ENV(PWD)/.condor_datalad_lock \
  DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__100ukb='ria+http://ukb.ds.inm7.de#{id}' \
  DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__101cat='ria+http://containers.ds.inm7.de#{id}' \
  GIT_AUTHOR_NAME='Michael Hanke' \
  GIT_AUTHOR_EMAIL='michael.hanke@gmail.com' \
  "

# place the job logs into PWD/logs, using the same name as for the result branches
# (JOBID)
log    = $ENV(PWD)/logs/$(subject)_$(Cluster).log
output = $ENV(PWD)/logs/$(subject)_$(Cluster).out
error  = $ENV(PWD)/logs/$(subject)_$(Cluster).err
# essential args for `participant_job`
# 1: where to clone the analysis dataset
# 2: location to push the result git branch to
# 3: ID of the subject to process
arguments = "\
  ria+file:///data/project/ukb_vbm/inputstore#8938de76-0302-45b5-9825-3c6ce3f3fffe \
  file:///data/project/ukb_vbm/outputstore/893/8de76-0302-45b5-9825-3c6ce3f3fffe \
  sub-$(subject) \
  "
queue
EOT
# TODO: make this more generic, provide explanation
# processing graph specification for computing all jobs
cat > code/process.condor_dag << "EOT"
# Processing DAG
EOT
for s in $(find inputs/ukb -maxdepth 1 -type d -name 'sub-*' -printf '%f\n'); do
  s=${s:4}
  printf "JOB sub-$s code/process.condor_submit\nVARS sub-$s subject=\"$s\"\n" >> code/process.condor_dag
done
datalad save -m "HTCondor submission setup" code/ .gitignore


# cleanup
# we have generated the DAG, we do not need to keep the massive input dataset
# around
# having it around wastes resources and makes many git operations needlessly
# slow
datalad uninstall -r --nocheck inputs/ukb

# make sure the fully configured output dataset is available from the designated
# store
# juseless-output-collector (joc)
# TODO: make this generic, more explanation
datalad create-sibling-ria -s joc "${output_store}"
datalad push --to joc

# if we get here, we are happy
echo SUCCESS
