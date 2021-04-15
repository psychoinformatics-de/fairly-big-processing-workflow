#!/usr/bin/sh

subid=$1
# -----------------------------------------------------------------------------
# FMRIPREP SPECIFIC ADJUSTMENTS - NOT NECESSARY FOR OTHER PIPELINES
# create workdir for fmriprep inside to simplify singularity call
# PWD will be available in the container
mkdir -p .git/tmp/wdir
# pybids (inside fmriprep) gets angry when it sees dangling symlinks
# of .json files -- wipe them out by temporarily placing them in a zip archive,
# spare only those that belong to the participant we want to process in this job
# After job completion, the jsons will be restored
find inputs/data -mindepth 2 -name '*.json' -a ! -wholename "$subid" -exec gzip {} +

# execute fmriprep. Its runscript is available as /singularity within the
# container
/singularity -b inputs/data . participant --participant-label $subid \
    --anat-only -w .git/tmp/wdir --fs-no-reconall --skip-bids-validation \
    --fs-license-file code/license.txt


# restore the jsons we have moved out of the way
find inputs/data -mindepth 2 -name '*.json.gz' -a ! -wholename "$subid" -exec gunzip {} +
