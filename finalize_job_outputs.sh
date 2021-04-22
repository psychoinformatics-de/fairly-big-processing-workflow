#!/bin/bash
# this script takes a CAT output structure and packages
# the desired pieces into a set of four compressed tarballs
# that are reproducible

set -e -u

# input file - what CAT originally ran on
# the inputfile is coming in with leading subdirectories
# we know that it is a BIDS-compliant file, so we can strip
# .nii.gz (i.e. 7 chars)
inputfile="$(basename "$1" .nii.gz)"

# logic below assumes absolute paths
# files to process
inputdir="$(readlink -f "$2")"
# output destination
outputdir="$(readlink -f "$3")"

rm -f "$inputdir"/"$inputfile".nii
rm -f "$inputdir"/*/*.mat
rm -f "$inputdir"/report/catlog_"$inputfile".txt
rm -f "$inputdir"/mri/a0"$inputfile".nii
rm -f "$inputdir"/surf/rh.pial."$inputfile".gii
rm -f "$inputdir"/surf/rh.white."$inputfile".gii

mkdir -p "$outputdir"

cd "$inputdir"

# remove date and timing info from CAT log
# to make it reproducible on reruns
sed -i \
  -e '/^.*<date>.*<\/date>.*$/d' \
  -e 's,\(.*\)[ >][0-9]\+s</item>,\1...s</item>,' \
  -e 's,\(.* takes\) [0-9]\+.*second, \1...,' \
  ./report/cat_sub-*_T1w.xml
# FIXME if dataset has multiple sessions
#  ./report/cat_sub-*_ses-*_T1w.xml


# deterministic order and permissions, fixed timestamp
mytar="tar --sort=name --owner=0 --group=0 --numeric-owner --mode=ugo+rwX --mtime=1970-01-01"

$mytar -cO report/cat* label/cat* | gzip -cn9 > "$outputdir/inforoi.tar.gz"
$mytar -cO mri/m0wp1* mri/mwp1* mri/wp0* | gzip -cn9 > "$outputdir/vbm.tar.gz"
$mytar -cO mri/p0* mri_atlas/* | gzip -cn9 > "$outputdir/native.tar.gz"
$mytar -cO surf/* | gzip -cn9 > "$outputdir/surface.tar.gz"
