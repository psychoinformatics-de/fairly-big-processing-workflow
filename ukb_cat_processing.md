# Reproduce Wierzba et al.

We have used the processing workflow demonstrated in this repository to process
UK Biobank data with the computational anatomy toolbox (CAT) for SPM.
While we are not able to share the data or container image due to data usage and
software license restrictions, we share everything that is relevant to create
these workflow components.

<!--ts-->
To reproduce the analysis, you will need to:

- [build a software container with a compiled version of CAT](#software-container)
- [retrieve UKBiobank data as a BIDS-like structured dataset](#UK-Biobank-data)
- [Adjust the bootstrap script](#Bootstrapping-the-framework)

<!--te-->

## Software container

The Singularity recipe and documentation on how to build a container Image from
it and use it can be found at
[github.com/m-wierzba/cat-container](https://github.com/m-wierzba/cat-container).

## Transform the software container into a dataset

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
In order to streamline processing routines, you can store container datasets in
dedicated RIA stores (using the command ``datalad create-sibling-ria``), and
access the correct pipeline via its dataset ID.

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
automatically, but it requires adjustments to your local paths that point to
your container dataset and UKB input dataset.
Within the script, a ``FIX-ME`` markup indicates where adjustments may be
necessary.
We recommend to open the file in a text reader of your choice and work through
the document using a find command to catch all FIX-ME's.

Afterwards, run the script, to create analysis dataset, input and output RIA
store, and a SLURM and HTCondor submission setup:

```
bash bootstrap.sh
```

If you can see the word "SUCCESS" at the end of the log messages in prints to
your terminal and no suspicious errors/warning, set up completed successfully.
It will have created a DataLad dataset underneath your current working
directory, by default under the name ``cat``.

Navigate into this directory, and submit the compute jobs with the job
scheduling system of your choice (see the general section
on Job submission).
After job completion, perform a few sanity checks, merge the result branches,
and restore file availability (see the general section **After workflow
completion**).

### Working with a UKB-CAT result dataset

As detailed in Wierzba et al., the results of the CAT computation on UKBiobank
data are wrapped into four tarballs per participant in order to diskspace and
collect the results in a single dataset (see
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


