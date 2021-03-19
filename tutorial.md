# Workflow tutorial

This tutorial helps you to set up a preprocessing workflow for [structural data
of the Studyforrest project](https://github.com/psychoinformatics-de/studyforrest-data-structural)
with [fmriprep](https://github.com/psychoinformatics-de/studyforrest-data-structural).

### Software requirements and other prerequisites

- DataLad version 0.14 or higher
- Singularity
- [flock](https://linux.die.net/man/1/flock)
- HTCondor (TODO: SLURM)
- a freesurfer license file ([free
  registration](https://surfer.nmr.mgh.harvard.edu/registration.html) required

Please make sure that you have a configured Git identity (see [instructions
here](http://handbook.datalad.org/intro/installation.html#initial-configuration)).

Please place a freesurfer license file in your home directory.

## Step-by-Step

Clone this repository to your compute cluster.

```
git clone <TODO>
```

### Adjust variables to your system

The relevant file for this tutorial is ``bootstrap_test.sh``.
Open it in an editor of your choice, and adjust the following fields:

- ``output_store`` and ``input_store``: Please provide RIA URLs to a place where
  an input and an output store can be created. These locations should be
  writable by you. More information on RIA stores and RIA URLs is at
  [handbook.datalad.org/r.html?RIA](http://handbook.datalad.org/r.html?RIA)

No other adjustments should be necessary. Optionally, you can

- adjust the variable ``source_ds`` to a name of your choice. If
  you do not modify it, the worklfow will set up a temporary analysis dataset
  called ``forrest``.
- If your freesurfer license is not located in your home directory, replace the
  line ``cp ~/license.txt code/license.txt`` with an alternative
  copy command that transfers the freesurfer license from a different place
  into ``code/license.txt``.

### Bootstrap the analysis

Execute ``bootstrap_test.sh`` by running

```
$ bash bootstrap_test.sh
```

This command will:

- Create a temporary analysis dataset called "forrest" under your current
  directory
- Link openly available input data from GitHub ([studyforrest data](https://github.com/psychoinformatics-de/studyforrest-data-structural))
  and an openly available available container collection ([ReproNim
  containers](https://github.com/repronim/containers)) to your analysis
- Create a temporary input RIA store and an output RIA store under the paths you
  have supplied, and register them in the analysis dataset
- Create an HTCondor-based job submission setup for structural preprocessing on
  a per subject level
- Push the analysis dataset into both RIA stores

If the script finishes with "SUCCESS", you're good to go.

### Submit the jobs

Navigate into the newly created analysis dataset, and submit the Condor DAG that
was created automatically

```
$ cd forrest
$ condor_submit_dag code/process.condor_dag
-----------------------------------------------------------------------
File for submitting this DAG to HTCondor           : code/process.condor_dag.condor.sub
Log of DAGMan debugging messages                 : code/process.condor_dag.dagman.out
Log of HTCondor library output                     : code/process.condor_dag.lib.out
Log of HTCondor library error messages             : code/process.condor_dag.lib.err
Log of the life of condor_dagman itself          : code/process.condor_dag.dagman.log

Submitting job(s).
1 job(s) submitted to cluster 413143.
```


You can monitor the execution of the jobs via standard HTCondor commands such as
``condor_q -nobatch`` or by checking the log files that will be collected in the
directory ``logs```and in ``code/process.condor_dag*`` files.

When the jobs have finished, make sure that all jobs finished successfully, for
example by querying the log files for the word "SUCCESS".


### Merge the results

After successful completion of all jobs, the result exit in individual branches
in the dataset in the output store.
To consolidate these results, all branches need to be merged.

This is done in a temporary dataset clone from the RIA store.
First, get the dataset ID in order to find its address in the RIA store. In your
analysis dataset, run

```
datalad -f '{infos[dataset][id]}' wtf -S dataset
2758dbcb-fa39-40fb-8e1e-6b30d9103549
```

Navigate into any temporary location, and clone the dataset from the output
store:

```
$ cd /tmp
$ datalad clone 'ria+file:///data/group/psyinf/myoutputstore#2758dbcb-fa39-40fb-8e1e-6b30d9103549' merger      1 !
[INFO   ] Scanning for unlocked files (this may take some time)
[INFO   ] Configure additional publication dependency on "output-storage"
configure-sibling(ok): . (sibling)
install(ok): /data/group/psyinf/scratch/merger (dataset)
action summary:
  configure-sibling (ok: 1)
  install (ok: 1)
```

Check that the expected number of branches is present:

```
$ cd merger
$ git branch -a | grep job- | sort | wc -l
21
```

Perform a further sanity check that each branch has a new commit. To do this,
find the most recent commit on the ``master`` branch (or ``main`` branch, if
your default branch is called ``main``).

```
git show-ref master | cut -d ' ' -f1
609e5395596b9fbc8534f9c175dbf95d631c633c
```

Plug this hash into the command below. If it returns 0, this means that every
job branch has a new commit on top of the reference commit the analysis started
from.

```
for i in $(git branch | grep job- | sort); do [ x"$(git show-ref $i \
  | cut -d ' ' -f1)" = x"609e5395596b9fbc8534f9c175dbf95d631c633c" ]  && \
  echo $i; done | tee /tmp/nores.txt | wc -l
0
```

As the number of result branches is very small, you can merge them in one go
with the following command:

```
$ git merge -m "Merge results" $(git branch -al | grep 'job-' | tr -d ' ')
Fast-forwarding to: remotes/origin/job-01.410198
Trying simple merge with remotes/origin/job-02.410204
Trying simple merge with remotes/origin/job-03.410193
Trying simple merge with remotes/origin/job-04.410194
Trying simple merge with remotes/origin/job-05.410203
Trying simple merge with remotes/origin/job-06.410197
Trying simple merge with remotes/origin/job-07.410189
Trying simple merge with remotes/origin/job-08.410205
Trying simple merge with remotes/origin/job-09.410192
Trying simple merge with remotes/origin/job-10.410191
Trying simple merge with remotes/origin/job-11.410206
Trying simple merge with remotes/origin/job-12.410200
Trying simple merge with remotes/origin/job-13.410188
Trying simple merge with remotes/origin/job-14.410190
Trying simple merge with remotes/origin/job-15.410196
Trying simple merge with remotes/origin/job-16.410202
Trying simple merge with remotes/origin/job-17.410195
Trying simple merge with remotes/origin/job-18.410201
Trying simple merge with remotes/origin/job-19.410187
Trying simple merge with remotes/origin/job-20.410199
Trying simple merge with remotes/origin/job-21.410186
Merge made by the 'octopus' strategy.
 fmriprep/sub-01/anat/sub-01_desc-brain_mask.json                                       | 1 +
 fmriprep/sub-01/anat/sub-01_desc-brain_mask.nii.gz                                     | 1 +
 fmriprep/sub-01/anat/sub-01_desc-preproc_T1w.json                                      | 1 +
 fmriprep/sub-01/anat/sub-01_desc-preproc_T1w.nii.gz                                    | 1 +
 fmriprep/sub-01/anat/sub-01_dseg.nii.gz                                                | 1 +
 [...]
```
This works well because different jobs never modified the same file. If you
would run a full fmriprep workflow, head over to
handbook.datalad.org/r.html?TODO for information on how to handle merge
conflicts in the ``CITATION.md`` file.

After you checked that everything is in order...

```
tree -d fmriprep
fmriprep
├── sub-01
│   ├── anat
│   ├── figures
│   └── log
│       └── 20210318-155553_c8ea2b0c-f557-429f-a598-faf34876ba5b
├── sub-02
│   ├── anat
│   ├── figures
│   └── log
│       └── 20210318-155635_65694134-71b9-40e2-aaee-57910bfa24f9
├── sub-03
│   ├── anat
│   ├── figures
│   └── log
│       └── 20210318-155550_949f06a2-d45d-445a-a07b-62f309765ea6
[...]
```

... push the merge back in to the outputstore:

```
git push
Enumerating objects: 23, done.
Counting objects: 100% (23/23), done.
Delta compression using up to 32 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 1.26 KiB | 431.00 KiB/s, done.
Total 3 (delta 1), reused 0 (delta 0)
To /data/group/psyinf/myoutputstore/275/8dbcb-fa39-40fb-8e1e-6b30d9103549
   609e539..ca3b612  master -> master
```

The name of the storage remote in the output store is "output-storage". We can
see it listed in a ``datalad siblings`` call:

```
datalad siblings
.: here(+) [git]
.: origin(-) [/data/group/psyinf/myoutputstore/275/8dbcb-fa39-40fb-8e1e-6b30d9103549 (git)]
.: output-storage(+) [ora]
```

A "git annex fs-check", done with the ``git annex fsck`` command, checks what
data is available from ``output-storage``, and links it to the correct files in
your dataset. Its important to do the operation with a ``--fast`` flag for big
datasets!

```
git annex fsck --fast -f output-storage
fsck fmriprep/sub-01/anat/sub-01_desc-brain_mask.json (fixing location log) ok
fsck fmriprep/sub-01/anat/sub-01_desc-brain_mask.nii.gz (fixing location log) ok
fsck fmriprep/sub-01/anat/sub-01_desc-preproc_T1w.json (fixing location log) ok
[...]
fsck fmriprep/sub-21/figures/sub-21_desc-summary_T1w.html (fixing location log) ok
fsck fmriprep/sub-21/figures/sub-21_dseg.svg (fixing location log) ok
fsck fmriprep/sub-21/figures/sub-21_space-MNI152NLin2009cAsym_T1w.svg (fixing location log) ok
fsck fmriprep/sub-21/log/20210318-155652_f2c4be32-546f-4ba1-803e-08ae2c587d15/fmriprep.toml (fixing location log) o
k
(recording state in git...)
```

Make sure that each file has associated content - the command below should not
return any output.

```
$ git annex find --not --in output-storage
```

As the dataset clone is a temporary clone used only for merging and restoring
file availability, we do not want to add it as a known location of data into the
distributed network of dataset clones:

```
$ git annex dead here
dead here ok
(recording state in git...)
```

Finally, do a ``datalad push`` without data to propagate the file availability
information back into the dataset in the store.
```
$ datalad push --data nothing
publish(ok): . (dataset) [refs/heads/git-annex->origin:refs/heads/git-annex 9f5319f..fc7819a]
```

## Create a dataset alias for easier cloning

To make cloning of the result dataset easier, create an alias for the dataset.
First, create a directory ``alias`` in the root of your RIA store:

```
$ mkdir /data/group/psyinf/myoutputstore/alias
```

Then, place a symlink with a name of your choice to the dataset inside of it:
```
$ ln -s /data/group/psyinf/myoutputstore/275/8dbcb-fa39-40fb-8e1e-6b30d9103549 /data/group/psyinf/myoutputstore/alias/structural-forrest
$ tree /data/group/psyinf/myoutputstore/alias
alias
└── structural-forrest -> ../275/8dbcb-fa39-40fb-8e1e-6b30d9103549
```


The dataset can now be cloned with its alias:

```
$ datalad clone 'ria+file:///data/group/psyinf/myoutputstore#~structural-forrest'
[INFO   ] Scanning for unlocked files (this may take some time)
[INFO   ] Configure additional publication dependency on "output-storage"
configure-sibling(ok): . (sibling)
install(ok): /tmp/structural-forrest (dataset)
action summary:
  configure-sibling (ok: 1)
  install (ok: 1)
```

Data is retrieved with `datalad get`:

```
$ cd structural-forrest
$ datalad get fmriprep/sub-08/anat/sub-08_desc-brain_mask.nii.gz
get(ok): fmriprep/sub-08/anat/sub-08_desc-brain_mask.nii.gz (file) [from output-storage...]
```

Check a provenance record of a subject:

```
$ git log fmriprep/sub-13/anat/
commit e2eb2592583acf16edfa17565ff2bd90fa0a7070 (origin/job-13.410188)
Author: Adina Wagner <adina.wagner@t-online.de>
Date:   Thu Mar 18 19:09:23 2021 +0100

    [DATALAD RUNCMD] Compute sub-13

    === Do not change lines below ===
    {
     "chain": [],
     "cmd": "singularity run -B {pwd} --cleanenv code/pipeline/images/bids/bids-fmriprep--20.2.0.sing /var/lib/cond
     "dsid": "2758dbcb-fa39-40fb-8e1e-6b30d9103549",
     "exit": 0,
     "extra_inputs": [
      "code/pipeline/images/bids/bids-fmriprep--20.2.0.sing"
     ],
     "inputs": [
      "inputs/data/sub-13/anat/",
      "code/license.txt"
     ],
     "outputs": [
      "fmriprep/sub-13"
     ],
     "pwd": "."
    }
    ^^^ Do not change lines above ^^^
```

Rerun a computation for a single subject:

```
$ datalad rerun e2eb2592583acf16edfa17565ff2bd90fa0a7070
datalad rerun e2eb2592583acf16edfa17565ff2bd90fa0a7070
[INFO   ] run commit e2eb259; (Compute sub-13)
[INFO   ] Making sure inputs are available (this may take some time)
[INFO   ] Scanning for unlocked files (this may take some time)
[INFO   ] Remote origin not usable by git-annex; setting annex-ignore
get(ok): inputs/data/sub-13/anat/sub-13_SWI.json (file) [from mddatasrc...]
get(ok): inputs/data/sub-13/anat/sub-13_SWI_defacemask.nii.gz (file) [from mddatasrc...]
get(ok): inputs/data/sub-13/anat/sub-13_SWImag.nii.gz (file) [from mddatasrc...]
get(ok): inputs/data/sub-13/anat/sub-13_SWIphase.nii.gz (file) [from mddatasrc...]
get(ok): inputs/data/sub-13/anat/sub-13_T1w.json (file) [from mddatasrc...]
get(ok): inputs/data/sub-13/anat/sub-13_T1w.nii.gz (file) [from mddatasrc...]
get(ok): inputs/data/sub-13/anat/sub-13_T1w_defacemask.nii.gz (file) [from mddatasrc...]
get(ok): inputs/data/sub-13/anat/sub-13_T2w.json (file) [from mddatasrc...]
get(ok): inputs/data/sub-13/anat/sub-13_T2w.nii.gz (file) [from mddatasrc...]
get(ok): inputs/data/sub-13/anat/sub-13_T2w_defacemask.nii.gz (file) [from mddatasrc...]
get(ok): inputs/data/sub-13/anat (directory)
```
