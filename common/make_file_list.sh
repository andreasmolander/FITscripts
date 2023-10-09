#!/bin/bash

# script to generate file list from alien, only data raw/calib CTFs at the moment
set -x
year=
lhcperiod=
runnumber=
type="raw"
nfiles=-1
filename=file.lst

Usage()
{
    echo "Usage instructions not implemented"
}

while [ $# -gt 0 ]; do
    case $1 in
        -y) year=$2; shift 2;;
        -p) lhcperiod=$2; shift 2;;
        -r) runnumber=$2; shift 2;;
        -t) type=$2; shift 2;;
        -n) nfiles=$2; shift 2;;
        -f) filename=$2; shift 2;;
        *) echo "Wrong input"; Usage;
    esac
done

alien_find "/alice/data/${year}/${lhcperiod}/${runnumber}/${type} o2_ctf_run*.root" > $filename
echo "Total number of files = $(cat $filename | wc -l)"
if [ $nfiles -gt -1 ]; then
    echo "Picking ${nfiles} randomly"
    shuf -n $nfiles $filename -o $filename
fi

sed -i -e 's/^/alien\:\/\//' $filename