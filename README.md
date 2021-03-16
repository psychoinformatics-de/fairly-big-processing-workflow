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
- ``bootstrap_test.sh``: A self-contained example analysis with HTCondor with
  openly shared structural MRI data from the Studyforrest project and a
  structural pipeline. It requires minimal adjustments of file paths to your
  filesystem, and can be ran as a quick example provided the software
  requirements are met.


# Table of contens

<!--ts-->
* [Software requirements](#software-requirements)
* [Workflow overview](#workflow-overview)

<!--te-->

## Software requirements

The machines involved in your workflow need the following software:

- [datalad](https://www.datalad.org/) and its dependencies (Installation
  instructions are at [handbook.datalad.org](http://handbook.datalad.org/en/latest/intro/installation.html#install)).
  Make sure that you have recent versions of DataLad, git-annex, and Git.
- [Singularity](https://sylabs.io/docs/)
- The Unix tool [flock](https://linux.die.net/man/1/flock) for file locking
- optional: A job scheduling/batch processing tool such as [HTCondor](https://research.cs.wisc.edu/htcondor/) or
  [SLURM](https://slurm.schedmd.com/documentation.html)


## Workflow overview

![](https://github.com/datalad-handbook/artwork/blob/master/src/ukbworkflow.svg)

TODO: include step-wise workflow









## Reproduce the analysis in Wierzba et al. (2021)

We have used the workflow to process UK Biobank data with the computational
anatomy toolbox (CAT) for SPM.
While we are not able to share the data or container image due to data usage and
software license restrictions, we share everything that is relevant to create
these workflow components.

### Software container

The Singularity recipe and documentation on how to build a container Image from
it and use it can be found at
[github.com/m-wierzba/cat-container](https://github.com/m-wierzba/cat-container).

#### Transform the software container into a dataset

TODO

### UK Biobank data

Assuming you have [successfully registered for UK Biobank data and have been
approved](https://www.ukbiobank.ac.uk/enable-your-research/register), you can
use the DataLad extension
[datalad-ukbiobank](https://github.com/datalad/datalad-ukbiobank) to transform
UK Biobank data into a BIDS-like structured dataset. The extension can be used
when no data has yet been retrieved, but also when data tarballs have already
been downloaded to local infrastructure.

### Adjust and run the bootstrapping script

``bootstrap.sh`` sets up the complete analysis set up (relevant input and output
RIA stores, participant-wise jobs, job submission setup for HTCondor or SLURM)
automatically, but it requires adjustments to your paths and workflows.
Within the script, a ``FIX-ME`` markup indicates where adjustments may be
necessary.
We recommend to open the file in a text reader of your choice and work through
the document using a find command to catch all FIX-ME's.

Afterwards, run the script:

```
bash bootstrap.sh
```

If you can see the word "SUCCESS" at the end of the log messages in prints to
your terminal and no suspicuous errors/warning, set up completed successfully.
It will have created a DataLad dataset underneath your current working
directory, by default under the name TODO.

Navigate into this directory, and submit the compute jobs with the job
scheduling setup you have chosen in ``bootstrap.sh``.








## Adjust the workflow for your own needs

You can adjust the workflow to other datasets, systems, and pipelines.
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
$ for i in $(git branch | grep job- | sort); do [ x"$(git show-ref $i \
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

### Restoring file availability info

After merging result branches, we need to query the datastore special remote for
file availability.
This information was specifically "lost" in the compute jobs, in order to avoid
the implied synchronization problem across compute jobs, and to boost throughput.
Run the following command to restore it:

```
$ git annex fsck --fast -f output-storage
```

Sanity check that we have a file content location on record for every annexed
file by checking that the following command does not have any outputs:

```
$ git annex find --not --in output-storage
```

This will update the ``git-annex`` branch and all file contents retrievable via
datalad get.
We advise to declare the local clone dead, in order to avoid this temporary
working copy to get on record in all future clones:

```
$ git annex dead here
```

Finally, write back to the datastore:


```
$ datalad push --data nothing
```

At this point, the dataset can be cloned from the datastore, and its file
contents can be retrieved via ``datalad get``. A recomputation can be done on a
per-file level with ``datalad rerun``.

## Testing your setup

We advise to test the setup with a handful of jobs before scaling up. In order
to do this:

- Submit a few jobs
- Make sure they finish successfully and check the logs carefully for any
  problems
- Clone the output dataset and check if all required branches are present
- Attempt a merge
- restore file availability information
- attempt a rerun


### Common problems and how to fix them

**Protocol mismatches**
RIA URLs specify a protocol, such as ``ria+file://``, ``ria+http://``, or
``ria+ssh``. If this protocol doesn't match the required access protocol (for
example because you created the RIA input or output store with a ``ria+file://``
URL but computations run on another server an need a ``ria+ssh://`` URL), you
will need to reconfigure. This can be done with an environment variable
``DATALAD_GET_SUBDATASET__SOURCE__CANDIDATE__101<name>=<correct url>``. You can
find an example in the bootstrap file and more information in
[handbook.datalad.org/r.html?clone-priority](handbook.datalad.org/en/latest/r.html?clone-priority).

**Heavy Git Object stores**
With many thousand jobs, the object store of the resulting dataset can
accumulate substantial clutter. This can be reduced by running ``git gc`` from
time to time.


### Frequently asked questions

**What is filelocking and what do I need to do?**
File locking is used as the last step in any computation during the final "git
push" operation. It prevents that more than one process push their results at
the same time by holding a single shared lockfile for the duration of the
process, and only starting the process when the lockfile is free.
You will not need to create, remove, or care about the lockfile, the setup in
``bootstrap.sh`` suffices.


### Further workflow adjustments

The framework and its underlying tools are versatile and flexible. When
adjusting the workflow to other scenarios please make sure that no two jobs
write results to the same file, unless you are prepared to handle resulting
merge conflicts. An examples on how to fix simple merge conflicts is at
[handbook.datalad.org/beyond_basics/101-171-enki.html#merging-results](http://handbook.datalad.org/en/latest/beyond_basics/101-171-enki.html#merging-results).
