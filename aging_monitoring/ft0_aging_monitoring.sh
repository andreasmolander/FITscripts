#!/bin/bash

# Script to monitor the FT0 aging
#
# Usage: ./ft0_aging_monitoring.sh <input_file>
# 
# <input_file> is a text file containing the list of runs to be processed
# 
# The script dumps the QC results and the channel amplitudes in a csv file
# in a subdirectory named after the run number.
#
# TODO: upload the QC results to CCDB

set -x # Debug

if [ $# -ne 1 ]; then
	echo "Usage: ${0##*/} <input_file>"
	exit 1
fi

year="2023"
input_file=$1

if [ ! -e $input_file ]; then
	echo "Input file $input_file does not exist"
	exit 1
fi

cwd=$(pwd)
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
root_macro_path="${script_dir}"

# while read -r run; do
for run in $(cat $input_file); do
	echo "Processing run $run"

	if [ -d $run ]; then
		echo "Run $run already exists, skipping"
		continue
	fi
		
	mkdir -p $run
	cd $run

	echo "Running QC on run ${run}"
	# run the QC bash script and wait for it to finish
	eval "${script_dir}/run_ft0_aging_qc.sh" "$year" "$run"
	# "${script_dir}/run_ft0_aging_c.sh" "$year" "$lhcperiod" "$run" &
	# wait

	echo "Extracting channel ampltidues from the QC results and dump them to a csv file"
	if [ -e "ft0_aging_qc_${run}.root" ]; then
		root -b -l -q "${root_macro_path}/PrintAgingQcHistograms.C(\"ft0_aging_qc_${run}.root\", \"ft0_aging_amplitudes_${run}.csv\")"
	else
		echo "File aging_qc_${run}.root does not exist, skipping"
	fi
	cd $cwd
# done < $input_file
done
