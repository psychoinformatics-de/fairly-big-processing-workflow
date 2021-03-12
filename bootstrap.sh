set -e -u

# Jobs are set up to not require a shared filesystem (except for the lockfile)

# submit DAG to condor
# rm -rf dag_tmp; mkdir -p dag_tmp; cp code/process.condor_dag dag_tmp/ && condor_submit_dag -batch-name UKBVBM -maxidle 1 dag_tmp/process.condor_dag

# define ID for git commits (take from local user configuration)
git_name="$(git config user.name)"
git_email="$(git config user.email)"
# define the dataset store all output will go to
output_store="ria+file:///data/project/ukb_vbm/outputstore"
# define the location of the stores all analysis inputs will be obtained from
container_store="ria+http://containers.ds.inm7.de"
ukb_raw_store="ria+http://ukb.ds.inm7.de"

# all results a tracked in a single output dataset
# create a fresh one
# job submission will take place from a checkout of this dataset, but no
# results will be pushed into it
datalad create -c yoda ukb_cat
cd ukb_cat

# register a container with the CAT tool
datalad clone -d . "${container_store}#~cat" code/pipeline
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

# register the UKB input dataset, a superdataset with 42k subdatasets
# comprising all participants
datalad clone -d . "${ukb_raw_store}#~bids" inputs/ukb
git commit --amend -m 'Register UKB raw dataset in BIDS format as input'

# the actual compute job specification
cat > code/participant_job << "EOT"
#!/bin/bash

# the job assumes that it is a good idea to run everything in PWD
# the job manager should make sure that is true

# fail whenever something is fishy, use -x to get verbose logfiles
set -e -u -x

dsstore="$1"
dsid="$2"
subid="$3"

# get the output dataset, which includes the inputs as <F6><F6>well
# flock makes sure that this does not interfere with another job
# finishing at the same time, and pushing its results back
# importantly, we clone from the lcoation that we want to push the
# results too
flock --verbose $DSLOCKFILE \
        datalad clone "${dsstore}#${dsid}" ds

# all following actions are performed in the context of the superdataset
cd ds
git checkout -b "job-$JOBID"

# we pull down the input subject manually in order to discover relevant
# files. We do this outside the recorded call, because on a potential
# re-run we want to be able to do fine-grained recomputing of individual
# outputs. The recorded calls will have specific paths that will enable
# recomputation outside the scope of the original Condor setup
datalad get -n "inputs/ukb/${subid}"

# the meat of the matter, add actual parameterization after --participant-label
find \
  inputs/ukb/${subid} \
  -name '*T1w.nii.gz' \
  -exec sh -c '
    odir=$(echo {} | cut -d / -f3-4);
    datalad containers-run \
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
# we nevertheless push the branch to have a records that this was
# attempted and did not fail
flock --verbose $DSLOCKFILE datalad push --to origin

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

# compute environment for a single job
cat > code/process.condor_submit << EOT
universe       = vanilla
# resource requirements for each job
request_cpus   = 1
request_memory = 4G
request_disk   = 5G

should_transfer_files = yes
# explicitly do not transfer anything back
# we are using datalad for everything that matters
transfer_output_files = ""

executable     = \$ENV(PWD)/code/participant_job

# the job expects these environment variables for labeling and synchronization
environment = "\\
  JOBID=\$(subject).\$(Cluster) \\
  DSLOCKFILE=\$ENV(PWD)/.condor_datalad_lock \\
  DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__100ukb='${ukb_raw_store}#{id}' \\
  DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__101cat='${container_store}#{id}' \\
  GIT_AUTHOR_NAME='${git_name}' \\
  GIT_AUTHOR_EMAIL='${git_email}' \\
  "

log    = \$ENV(PWD)/logs/\$(subject)_\$(Cluster).log
output = \$ENV(PWD)/logs/\$(subject)_\$(Cluster).out
error  = \$ENV(PWD)/logs/\$(subject)_\$(Cluster).err
arguments = "\\
  ${output_store} \\
  $(datalad -f '{infos[dataset][id]}' wtf -S dataset) \\
  sub-\$(subject) \\
  "
queue
EOT

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
datalad create-sibling-ria -s joc "${output_store}"
datalad push --to joc

# if we get here, we are happy
echo SUCCESS
