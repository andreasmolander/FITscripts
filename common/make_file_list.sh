#!/bin/bash

# script to generate file list from alien, only data raw/calib CTFs at the moment
# 
# Usage: ./make_file_list.sh -y <year> -p <lhcperiod> -r <runnumber> -t <type> -n <nfiles> -f <filename>

set -x # Debug

year=
lhcperiod=
runnumber=
type="raw"
nfiles=-1
filename=file.lst

Usage()
{
	echo "Usage: ${0##*/} [OPTION]"
	echo "  -y, --year YEAR      year"
	echo "  -p, --period PERIOD  LHC period"
	echo "  -r, --run RUN        run number"
	echo "  -t, --type TYPE      file type (raw, calib)"
	echo "  -n, --nfiles NFILES  number of files to pick randomly"
	echo "  -f, --filename FILE  output file name"
	echo "  -h, --help           print this help"
	exit
}

while [ $# -gt 0 ]; do
	case $1 in
		-y) year=$2; shift 2;;
		-p) lhcperiod=$2; shift 2;;
		-r) runnumber=$2; shift 2;;
		-t) type=$2; shift 2;;
		-n) nfiles=$2; shift 2;;
		-f) filename=$2; shift 2;;
		-h|--help) Usage;;
		*) echo "Wrong input"; Usage;
	esac
done

if [ $type != "raw" ] && [ $type != "calib" ]; then
	# Asume it's AO2D then
	echo "Looking for AO2D files"
	alien_find "/alice/data/${year}/${lhcperiod}/${runnumber}/${type} AO2D*.root" > $filename
else
	echo "Looking for CTF files"
	if [ -z $lhcperiod ]; then
		alien_find "/alice/data/${year}/ ${runnumber}/${type}/*/o2_ctf_run*.root" > $filename    
	else
		alien_find "/alice/data/${year}/${lhcperiod}/${runnumber}/${type} o2_ctf_run*.root" > $filename
	fi
fi

echo "Total number of files = $(cat $filename | wc -l)"

if [ $nfiles -gt -1 ]; then
	echo "Picking ${nfiles} randomly"
	shuf -n $nfiles $filename -o $filename
fi

sed -i -e 's/^/alien\:\/\//' $filename