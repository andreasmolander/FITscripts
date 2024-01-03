#!/bin/bash

# script to generate file list from alien
# 
# Usage: ./make_file_list.sh -y <year> -p <lhcperiod> -r <runnumber> -t <type> [-n <nfiles> -f <filename>]

# set -x # Debug

year=""
lhcperiod=""
runnumber=""
type=""
nfiles=-1
filename=file.lst

Usage()
{
	echo "Usage: ${0##*/} [OPTION]"
	echo "  -y, --year YEAR      year"
	echo "  -p, --period PERIOD  LHC period"
	echo "  -r, --run RUN        run number"
	echo "  -t, --type TYPE      file type. Options: raw, calib, [pass], mc. raw and calib are data CTFs. [pass] is data AO2Ds from [pass]. mc is MC AO2Ds."
	echo "  -n, --nfiles NFILES  number of files to pick randomly"
	echo "  -f, --filename FILE  output file name"
	echo "  -h, --help           print this help"
	exit
}

while [ $# -gt 0 ]; do
	case $1 in
		-y | --year)     year=$2;      shift 2;;
		-p | --period)   lhcperiod=$2; shift 2;;
		-r | --run)      runnumber=$2; shift 2;;
		-t | --type)     type=$2;      shift 2;;
		-n | --nfiles)   nfiles=$2;    shift 2;;
		-f | --filename) filename=$2;  shift 2;;
		-h | --help)     Usage;;
		*) echo "Wrong input"; Usage;
	esac
done

# TODO: is it safe to leave out period for all but MC?
if [ "$year" == "" ] || [ "$lhcperiod" == "" ] || [ "$runnumber" == "" ] || [ "$type" == "" ]; then
	echo "Missing arguments"
	Usage
	exit 1
fi

if [ "$type" == "raw" ] || [ "$type" == "calib" ]; then
	echo "Looking for CTF files"
	if [ -z $lhcperiod ]; then
		alien_find "/alice/data/${year}/ ${runnumber}/${type}/*/o2_ctf_run*.root" > $filename    
	else
		alien_find "/alice/data/${year}/${lhcperiod}/${runnumber}/${type} o2_ctf_run*.root" > $filename
	fi
elif [ "$type" == "mc" ]; then
	echo "Looking for MC files"
	alien_find "/alice/sim/${year}/${lhcperiod}/ ${runnumber}/*/AO2D.root" > $filename
else
	# Asume it's data AO2D then
	echo "Looking for AO2D files"
	# Should we look for AO2D_merged.root?
	if [ -z $lhcperiod ]; then
		alien_find "/alice/data/${year}/ ${runnumber}/${type}/*/AO2D.root" > $filename
	else
		alien_find "/alice/data/${year}/${lhcperiod}/${runnumber}/${type} AO2D.root" > $filename
	fi
fi

echo "Total number of files = $(cat $filename | wc -l)"

if [ $(cat $filename | wc -l) -eq 0 ]; then
	echo "No files found"
	exit 1
fi

if [ $nfiles -gt -1 ]; then
	echo "Picking ${nfiles} randomly"
	shuf -n $nfiles $filename -o $filename
fi

sed -i -e 's/^/alien\:\/\//' $filename