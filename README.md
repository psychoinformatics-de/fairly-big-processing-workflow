# A template for decentralized, reproducible processing

This repository contains all materials described in Wierzba et al. (2021) and
can be used as a template to set up similar processing workflows.

Please cite the corresponding publication when using this workflow or materials
from it, as well as its underlying software tools.

- [ADD Wierzba et al. 2021]
- [datalad](https://zenodo.org/record/4495661#.YEuShCUo8UE):
  Hanke, Michael, Halchenko, Yaroslav O., Poldrack, Benjamin, Meyer, Kyle, Solanky, Debanjum Singh, Alteva, Gergana, … Nichols, B. Nolan. (2021, February 2). datalad/datalad: ## 0.14.0 (February 02, 2021) (Version 0.14.0). Zenodo. http://doi.org/10.5281/zenodo.4495661

This repository contains the following files:

- ``bootstrap_test.sh``: A self-contained example analysis with HTCondor with
  openly shared structural MRI data from the Studyforrest project and a
  structural pipeline. It requires minimal adjustments of file paths to your
  filesystem, and can be ran as a quick example provided the software
  requirements are met.
- ``tutorial.md``: A tutorial to setup a self-contained analysis from
  ``bootstrap_test.sh``
- ``bootstrap.sh``: This script bootstraps the analysis workflow from scratch
  presented in Wierzba et al. (2021) from scratch. Running it requires UKBiobank
  data and a CAT software container. You can use this file or
  ``bootstrap_test.sh`` to adjust the workflow to your usecase - please edit
  anything with a "FIX-ME" mark-up.
- ``code_cat_standalone_batchUKB.txt``: A Batch file for CAT12 processing. This
  script is relevant to setup the CAT12 processing pipeline reported in
  [Wierzba et al., 2021]()
- ``finalize_job_outputs``: A script that wraps up CAT processing outputs into
  tarballs



# Table of contens


<!--ts-->
* [Software requirements](#software-requirements)
* [Workflow overview](#workflow-overview)
* [Original analysis of Wierzba et al.](#Reproduce-wierzba-et-al.)
    * [CAT Software container](#software-container)
    * [UKBiobank data](#UK-Biobank-data)
    * [Adjust and run the bootstrapping script](#Adjust-and-run-the-bootstrapping-script)
* [Adjust the workflow to your own needs](#adjust-the-workflow)
    * [Create a container dataset](#Create-a-container-dataset)
    * [Create an input dataset](#Create-an-input-dataset)
    * [Bootstrapping the framework](#Bootstrapping-the-framework)
    * [Testing your setup](#testing-your-setup)
    * [Job submission](#job-submission)
    * [After workflow completion](#after-workflow-completion)
* [Common problems and how to fix them](#Common-problems-and-how-to-fix-them)
* [Frequently asked questions](#Frequently-asked-questions)
* [Further workflow adjustments](#further-workflow-adjustments)
* [Further information](#further-reading)

<!--te-->

## Software requirements

The machines involved in your workflow need the following software:

- [datalad](https://www.datalad.org/) and its dependencies (Installation
  instructions are at [handbook.datalad.org](http://handbook.datalad.org/en/latest/intro/installation.html#install)).
  Make sure that you have recent versions of DataLad, git-annex, and Git.
- [datalad-container](http://docs.datalad.org/projects/container/en/latest/index.html#),
  a DataLad extension for working with containerized software environments that
  can be installed using [pip](https://pip.pypa.io/en/stable/): ``pip install datalad-container``.
- [Singularity](https://sylabs.io/docs/)
- The Unix tool [flock](https://linux.die.net/man/1/flock) for file locking
- A job scheduling/batch processing tool such as [HTCondor](https://research.cs.wisc.edu/htcondor/) or
  [SLURM](https://slurm.schedmd.com/documentation.html)

Make sure to have a Git identity set up.

## Workflow overview

![](https://github.com/datalad-handbook/artwork/blob/master/src/ukbworkflow.svg)

A bootstrapping script will assemble an analysis dataset based on
- input data
- containerized software environment
- optional additional scripts or files

This dataset is a fully self-contained analysis, and includes a job submission
setup for HTCondor or SLURM based batch processing.
By default, the computational jobs operate on a per-subject level.

During bootstrapping, two RIA stores (more information at
[handbook.datalad.org/r.html?RIA](http://handbook.datalad.org/r.html?RIA)) are
created, one temporary input store used for cloning the analysis, and one
permanent output store used for collecting the results.
The analysis dataset is pushed into each store.

After bootstrapping, a user can navigate into the analysis dataset that is
created in the current directory. Based on available job scheduling system, an
HTCondor DAG or a SLURM batch file can be submitted.
The jobs will clone the analysis dataset into temporary locations, retrieve the
relevant subset of data for a participant-based job, and push their results -
data and process provenance separately - into the output store.

After the jobs finished successfully, a user consolidates the results and
restores file availability. The results of the computation are then accessible
from the output store.

We recommend to read and compute the tutorial described in ``tutorial.md`` as a
small analysis to test the workflow.


## Reproduce Wierzba et al.

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

Any software container can be added to a dataset with the following steps:

Create a dataset:
```
$ datalad create pipeline
$ cd pipeline
```

Add a software-container to the dataset. The ``--url`` parameter can be a local
path to your container image, or a URL to a container hub such as Dockerhub or
Singularity Hub.
By default, a software container will be called with ``singularity exec
<image>``. In order to customize this invocation, for example into ``singularity
run <image> <customcommand>``, use the ``--call-fmt`` argument. Below, the
invocation is customized to bindmount the current working directory into the
container, and execute a command instead of the containers' runscript.
A different example of this is also in the tutorial in this repository.

```
$ datalad containers-add cat --url <path/or/url/to/image>  \
  --call-fmt "singularity run -B {{pwd}} --cleanenv {img} {cmd}"
```

Afterwards, you can use this dataset to link your software container to your
analysis setup.

### UK Biobank data

Assuming you have [successfully registered for UK Biobank data and have been
approved](https://www.ukbiobank.ac.uk/enable-your-research/register), you can
use the DataLad extension
[datalad-ukbiobank](https://github.com/datalad/datalad-ukbiobank) to transform
UK Biobank data into a BIDS-like structured dataset. The extension can be used
when no data has yet been retrieved, but also when data tarballs have already
been downloaded to local infrastructure. Please consult the software's
[documentation](http://docs.datalad.org/projects/ukbiobank/en/latest/index.html)
for more information and tutorials.

### Adjust and run the bootstrapping script

``bootstrap.sh`` sets up the complete CAT analysis set up (relevant input and output
RIA stores, participant-wise jobs, job submission setup for HTCondor or SLURM)
automatically, but it requires adjustments to your local paths.
Within the script, a ``FIX-ME`` markup indicates where adjustments may be
necessary.
We recommend to open the file in a text reader of your choice and work through
the document using a find command to catch all FIX-ME's.

Afterwards, run the script:

```
bash bootstrap.sh
```

If you can see the word "SUCCESS" at the end of the log messages in prints to
your terminal and no suspicious errors/warning, set up completed successfully.
It will have created a DataLad dataset underneath your current working
directory, by default under the name ``cat``.

Navigate into this directory, and submit the compute jobs with the job
scheduling setup you have chosen in ``bootstrap.sh`` (see the general section
[Job submission](#job-submission)).
After job completion, perform a few sanity checks, merge the result branches,
and restore file availability (see the general section [After workflow
completion](#after-workflow-completion)).

### Working with a UKB-CAT result dataset

As detailed in Wierzba et al., the results of the CAT computation on UKBiobank
data are wrapped into four tarballs per participant. This allowed us to save
results in a single dataset (see
[handbook.datalad.org/r.html?gobig](https://handbook.datalad.org/r.html?gobig)
for dataset file number limits).
This result dataset can be used to create special-purpose datasets that contain
dedicated result subsets and can be used for further analyses.

The code below sketches a setup to create such datasets in a provenance-tracked
manner:

```
# create a dataset that includes tissue volume statistics per ROI, parcellation,
# and subject:
$ datalad create ukb_tiv
$ cd ukb_tiv
# register the ukb results as a subdataset:
$ datalad clone -d . <path/to/ukb_vbm> inputs/ukb_vbm
# extract volumes from inforoi.tar.gz and parse them from xml to csv.
$ datalad run -m "..."
  --input "inputs/ukb_vbm/sub-*/*/inforoi.tar.gz"
  --output "stats/"
  "sh -c 'rm -rf stats; mkdir -p stats; find inputs/ukb_vbm -name inforoi.tar.gz \
  -print -exec python3 code/tiv_xml2csv.py stats/cat {{}} \\;'"
# In the end, the ukb_tiv has a CSV file for each parcellation, and each CSV file
# has one row per subject with the respective tissue statistics.

# For a different use case, but in a similar way,
# we extracted the vbm results for all subjects using
$ datalad run -m "..."
  --input inputs/ukb_vbm/sub-*/*/vbm.tar.gz
  --output .
  "rm -rf m0wp1; mkdir -p m0wp1; find inputs/ukb_vbm -name vbm.tar.gz -exec \
   tar --one-top-level=m0wp1 --strip-components=1 --wildcards -xvf {{}} \
   '\"'\"'mri/m0wp1*.nii'\"'\"' \\; ; find m0wp1 -name '\"'\"'*.nii'\"'\"' -exec gzip -9 -v {{}} \\;'"

```

## Adjust the workflow

You can adjust the workflow to other datasets, systems, and pipelines.
Before making major adjustments, we recommend to try the analysis with the
tutorial provided in this repository in order to ensure that the workflow works
in principle on your system.

The workflow is tuned towards analyses that operate on a per participant level.
The adjustment is easiest if you have an input dataset with a BIDS-like structure
(sub-xxx directories on the first level of your input dataset), because the job
submission setup for HTCondor and SLURM works by finding subject directories and
building jobs based on these identifiers. If your input data is differently
structured, make sure to adjust the ``find`` command in the relevant section of
the bootstrapping script.

We highly recommend to use the workflow for computational jobs that can run
fully in parallel and do not write to the same file. Otherwise, you will see
merge conflict in data files. This can be solved in simple cases (see
[here](http://handbook.datalad.org/en/latest/beyond_basics/101-171-enki.html#merging-results)
for an example), but requires experience with Git.

We also recommend to tune your analysis for computational efficiency and minimal
storage demands. Optimize the compute time of your pipeline, audit carefully
that only relevant results are saved and remove uncessary results right within
your pipeline, and, if necessary, wrap job results into tarballs.

### Create a container dataset

There is a public dataset with software containers available at
[https://github.com/repronim/containers](https://github.com/repronim/containers).
You can install it as a subdataset and use any of its containers - the tutorial
showcases an example of this.

When you want to build your own container dataset, create a new dataset and add a
container from a local path or URL to it.
An example can be found at
[handbook.datalad.org/en/latest/r.html?OHBM2020](handbook.datalad.org/en/latest/r.html?OHBM2020).

After linking the container to your analysis dataset, the bootstrap script will
add the container to the top-level analysis dataset.
Make sure to supply the correct call-format configuration to this call.
The call format configures how your container is called during the analysis, and
it can be for example used to preconfigure bind-mounts.
More information on call-formats can be found in the
[documentation of ``datalad containers-add``](http://docs.datalad.org/projects/container/en/latest/generated/man/datalad-containers-add.html).

### Create an input dataset

There are more than 200TB of public data available as DataLad datasets at
[datasets.datalad.org](http://datasets.datalad.org/), among them popular
neuroimaging datasets such as any dataset on
[OpenNeuro](http://handbook.datalad.org/r.html?OpenNeuro) or the [human
connectome project open access dataset](https://github.com/datalad-datasets/human-connectome-project-openaccess).
The tutorial uses such a public dataset.

If your data is not yet a DataLad dataset, you can transform it into one with
the following commands:

```
# create a dataset in an existing directory
$ datalad create -f .
# save its contents
$ datalad save . -m "Import all data"
```

This process can look different if your dataset is very large or contains
private files. We recommend to read
[handbook.datalad.org/beyond_basics/101-164-dataladdening.html](http://handbook.datalad.org/en/latest/beyond_basics/101-164-dataladdening.html)
for an overview on how to transform data into datasets.


### Bootstrapping the framework
When both input dataset and the container are accessible, the complete analysis
dataset and job submission setup can be bootstrapped using ``bootstrap.sh``.
All relevant adjustments of the file are marked with a "FIX-ME" comments.


### Testing your setup

We advise to test the setup with a handful of jobs before scaling up. In order
to do this:

- Submit a few jobs
- Make sure they finish successfully and check the logs carefully for any
  problems
- Clone the output dataset and check if all required branches are present
- Attempt a merge
- restore file availability information
- attempt a rerun


### Job submission

The workflow can be used with or without job scheduling software. For a
single-participant job, the script ``code/participant_job.sh`` needs to be
called with a source dataset, a participant identifier, and an output location
``bootstrap.sh`` contains a setup for HTCondor and SLURM.

When using job scheduling systems other than HTCondor or SLURM, you will need to
create the necessary submit files yourself. The ``participant_job.sh`` should
not need any adjustments. We would be happy if you would contribute additional
job scheduling setups with a pull request.

#### HTCondor submission

If your HPC systems run HTCondor, the complete analysis can be submitted as a
DAG. The bootstrapping script will have created the necessary files.
To submit the jobs inside of the created analysis dataset run:

```
# create a directory for logs (it is gitignored)
$ mkdir -p dag_tmp
# copy the dag into this directory
$ cp code/process.condor_dag dag_tmp/
# submit the DAG. -maxidle 1 slides the jobs into the system smoothly instead of
# all at once. Change the batch name, if you want to
condor_submit_dag -batch-name UKB -maxidle 1 dag_tmp/process.condor_dag
```

#### SLURM submission

If your HPC systems run SLURM, the complete analysis can be submitted from an
sbatch.

TODO

## After workflow completion

As described in more detail in Wierzba et al. (2021), the results of the
computation exist on separate branches in the output dataset.
They need to be merged into the main branch and connected to the result data in
the storage sibling of the RIA remote.

### Merging branches

1. Clone the output dataset from the RIA store into a temporary location.

You can find out which ID the dataset has in the RIA store by running ``datalad
-f '{infos[dataset][id]}' wtf -S dataset`` in the analysis dataset.

```
$ cd /tmp
# adjust the url to your file system and dataset id
$ datalad clone 'ria+file:///data/project/ukb/outputstore#155b4ccd-737b-4e42-8283-812ffd27a661' merger
[INFO   ] Scanning for unlocked files (this may take some time)
[INFO   ] Configure additional publication dependency on "output-storage"
configure-sibling(ok): . (sibling)
install(ok): /tmp/merger (dataset)
action summary:
  configure-sibling (ok: 1)
  install (ok: 1)

$ cd merger
```

2. Sanity checks

The branches were predictably named and start with a ``job-`` prefix.
Check the number of branches against your expected number of jobs:

```
$ git branch -a | grep job- | sort | wc -l
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
$ for i in $(git branch -a | grep job- | sort); do [ x"$(git show-ref $i \
  | cut -d ' ' -f1)" = x"46faaa8e42a5ae1a1915d4772550ca98ff837f5d" ] && \
  echo $i; done | tee /tmp/nores.txt | wc -l
```

3. Merging

With the above commands you can create a list of all branches that have results
and can be merged. Make sure to replace the commit hash with that of your own
project.

```
$ for i in $(git branch -a | grep job- | sort); \
  do [ x"$(git show-ref $i  \
     | cut -d ' ' -f1)" != x"46faaa8e42a5ae1a1915d4772550ca98ff837f5d" ] && \
     echo $i; \
done | tee /tmp/haveres.txt
```


If there are less than 5000 branches to merge, you will probably be fine by
merging all branches at once. With more branches, the branch names can exceed
your terminal length limitation. In these cases, we recommend merging them in
batches of, e.g., 5000:

```
$ git merge -m "Merge computing results (5k batch)" $(for i in $(head -5000 ../haveres.txt | tail -5000); do echo origin/$i; done)
```

Please note: The Merging operations progressively slows down with a large amount
of branches. When merging ~40k branches in batches of 5000, we saw the following
merge times (in minutes) for the batches:
15min,  22min, 32min, 40min, 49min, 58min, 66min

4. Push the merge back

After merging, take a look around in your temporary clone and check that
everything looks like you expect it to look. Afterwards, push the merge back
into the RIA store with Git.

```
$ git push
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

## Common problems and how to fix them

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

Please get in touch by filing an issue for further questions and help.

## Frequently asked questions

**What is filelocking and what do I need to do?**
File locking is used as the last step in any computation during the final "git
push" operation. It prevents that more than one process push their results at
the same time by holding a single shared lockfile for the duration of the
process, and only starting the process when the lockfile is free.
You will not need to create, remove, or care about the lockfile, the setup in
``bootstrap.sh`` suffices.


## Further workflow adjustments

The framework and its underlying tools are versatile and flexible. When
adjusting the workflow to other scenarios please make sure that no two jobs
write results to the same file, unless you are prepared to handle resulting
merge conflicts. An examples on how to fix simple merge conflicts is at
[handbook.datalad.org/beyond_basics/101-171-enki.html#merging-results](http://handbook.datalad.org/en/latest/beyond_basics/101-171-enki.html#merging-results).


## Further reading

More information about DataLad, the concepts relevant to this workflow, and
additional examples can be found at
[handbook.datalad.org](http://handbook.datalad.org)
