## A template for decentralized processing

This repository contains all materials described in Wierzba et al. (2021) and
can be used as a template to set up similar processing workflows.

Please cite the corresponding publication when using this workflow, as well as
its underlying software tools.

- [ADD Wierzba et al. 2021]
- [ADD datalad reference]




Individual files in this repository are:

- bootstrap.sh: This script bootstraps the analysis workflow from scratch.
  Please replace placeholders and TODO's to adjust it to your own project.
- Singularity: The original Singularity recipe for the computational anatomy
  toolbox (CAT) for SPM (Glaser & Dahnke) container. Building the container
  requires MATLAB, TODO ...
  You can build the container by running:

```
TODO
```
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

### Software requirements

TODO: add software requirements
TODO: explain file locking

### Further workflow adjustments

The framework and its underlying tools are versatile and flexible.
