#!/bin/bash
# this script takes a CAT output structure and packages
# the desired pieces into a set of four compressed tarballs

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
tar -czf "$outputdir/inforoi.tar.gz" report/cat* label/cat*
tar -czf "$outputdir/vbm.tar.gz" mri/m0wp1* mri/mwp1* mri/wp0*
tar -czf "$outputdir/native.tar.gz" mri/p0* mri_atlas/*
tar -czf "$outputdir/surface.tar.gz" surf/*
