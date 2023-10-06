#!/bin/bash

# script to generate file list from alien, only data CTFs at the moment

# if [ ! "$#" -eq 3 ]; then
#     echo "Usage: $0 <year> <lhcperiod> <runNumber>"
#     exit 1
# fi

# year="$1"
# lhcperiod="$2"
# runnumber="$3"

year=2023
lhcperiod=LHC23zze
runnumber=543950

nfiles=5000
filename=file.lst

alien_find "/alice/data/${year}/${lhcperiod}/${runnumber}/raw o2_ctf_run*.root" > $filename
echo "Total number of files = $(cat $filename | wc -l)"
echo "Picking ${nfiles} randomly"
shuf -n $nfiles $filename -o $filename

sed -i -e 's/^/alien\:\/\//' $filename