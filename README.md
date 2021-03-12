# A template for decentralized processing

This repository contains all materials described in Wierzba et al. (2021) and
can be used as a template to set up similar processing workflows.

Please cite the corresponding publication when using this workflow or materials
from it, as well as its underlying software tools.

- [ADD Wierzba et al. 2021]
- [datalad](https://zenodo.org/record/4495661#.YEuShCUo8UE):
  Hanke, Michael, Halchenko, Yaroslav O., Poldrack, Benjamin, Meyer, Kyle, Solanky, Debanjum Singh, Alteva, Gergana, … Nichols, B. Nolan. (2021, February 2). datalad/datalad: ## 0.14.0 (February 02, 2021) (Version 0.14.0). Zenodo. http://doi.org/10.5281/zenodo.4495661

This repository contains the following files:

- ``bootstrap.sh``: This script bootstraps the analysis workflow from scratch.
  Please adjust anything with a "FIX-ME" mark-up in order to adjust the workflow
  to your own analysis.
- ``code_cat_standalone_batchUKB.txt``: A Batch file for CAT12 processing. This
  script is relevant to setup the CAT12 processing pipeline reported in
  [Wierzba et al., 2021]()
- ``finalize_job_outputs``: A script that wraps up CAT processing outputs into
  tarballs
- Singularity: The original Singularity recipe for the computational anatomy
  toolbox (CAT) for SPM (Glaser & Dahnke) container. Building the container
  requires MATLAB, TODO ...
  You can build the container by running:

```
TODO
```


## Reproduce the analysis in Wierzba et al. (2021)



## Adjust the workflow for your own needs


The workflow is tuned towards analyses that operate on a per participant level
on input data 


### Create a container dataset

TODO: describe how to do that.
TODO: describe custom call formats.

### Bootstrapping the framework
When both input dataset and the container are accessible, the complete analysis
dataset and job submission setup can be bootstrapped using ``bootstrap.sh``.
All relevant adjustments of the file are marked with a "FIX-ME" comments.


### HTCondor submission versus SLURM batch processing versus no job scheduling

The workflow can be used with or without job scheduling software. For a
single-participant job, the script ``code/participant_job.sh`` needs to be
called with a source dataset, a participant identifier, and an output location
``bootstrap.sh`` contains a setup for HTCondor and SLURM.

When using job scheduling systems other than HTCondor or SLURM, 


### HTCondor submission as a DAG

inside of the created analysis dataset run:

```
rm -rf dag_tmp; mkdir -p dag_tmp; cp code/process.condor_dag dag_tmp/ && \
condor_submit_dag -batch-name UKBVBM -maxidle 1 dag_tmp/process.condor_dag
```

## After workflow completion

As described in more detail in Wierzba et al. (2021), the results of the
computation exist on separate branches in the output dataset.
They need to be merged into the main branch and connected to the result data in
the storage sibling of the RIA remote.


### Merging branches

1. Clone the output dataset from the RIA store into a temporary location.

```
# adjust the url to your file system and dataset id
$ datalad clone 'ria+file:///data/project/ukb/outputstore#155b4ccd-737b-4e42-8283-812ffd27a661' merger
[INFO   ] Scanning for unlocked files (this may take some time)
[INFO   ] Configure additional publication dependency on "output-storage"
configure-sibling(ok): . (sibling)
install(ok): /tmp/merger (dataset)
action summary:
  configure-sibling (ok: 1)
  install (ok: 1)

cd merger
```

2. Sanity checks

The branches were predictably named and start with a ``job-`` prefix.
Check the number of branches against your expected number of jobs:

```
git branch -a | grep job- | sort | wc -l
42767
```

It is advised to do additional checks whether the results have actually
been computed successfully, for example by querying log files. If the scripts
shared in this repository have only been altered at ``FIX-ME`` positions, you
should find the word "SUCCESS" in every job that was pushed successfully.
In order to check if a job has computed a result (some participants may lack the
relevant files and thus no output is produced in a successful job), compare its
most recent commit to the commit that identifies the analysis source dataset
state prior to computation. Where it is identical, the compute job hasn't
produced new outputs.

```
# show commit hash of the main development branch (replace with main if needed)
$ git show-ref master | cut -d ' ' -f1
46faaa8e42a5ae1a1915d4772550ca98ff837f5d
# query all branches for the most recent commit and check if it is identical.
# Write all branch identifiers for jobs without outputs into a file.
% for i in $(git branch | grep job- | sort); do [ x"$(git show-ref $i \
  | cut -d ' ' -f1)" = x"46faaa8e42a5ae1a1915d4772550ca98ff837f5d" ] && \
  echo $i; done | tee /tmp/nores.txt | wc -l
```

3. Merging

With the above commands you can create a list of all branches that have results
and can be merged. Make sure to replace the commit hash with that of your own
project.

```
for i in $(git branch -a | grep job- | sort); \
  do [ x"$(git show-ref $i  \
     | cut -d ' ' -f1)" != x"46faaa8e42a5ae1a1915d4772550ca98ff837f5d" ] && \
     echo $i; \
done | tee /tmp/haveres.txt
```


If there are less than 5000 branches to merge, you will probably be fine by
merging all branches at once. With more branches, the branch names can exceed
your terminal length limitation. In these cases, we recommend merging them in
batches of 5000:

```
git merge -m "Merge computing results (5k batch)" $(for i in $(head -5000 ../haveres.txt | tail -5000); do echo origin/$i; done)
```

Please note: Merging the batches progressively slows down. When merging ~40k
branches, we save the following times (in minutes) for merging batches:
15min,  22min, 32min, 40min, 49min, 58min, 66min

4. Push the merge back

After merging, take a look around in your temporary clone and check that
everything looks like you expect it to look. Afterwards, push the merge back
into the RIA store with Git.

```
git push
```

### Software requirements

TODO: add software requirements
TODO: explain file locking

### Further workflow adjustments

The framework and its underlying tools are versatile and flexible.
