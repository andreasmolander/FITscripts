#!/bin/bash

# Script to monitor the FT0 aging
#
# Usage: ./ft0_aging_monitoring.sh <input_file>
# 
# <input_file> is a text file containing the list of runs to be processed
# 
# The script dumps the QC results and the channel amplitudes and times in a csv file
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

overwrite="true"

if [ ! -e $input_file ]; then
	echo "Input file $input_file does not exist"
	exit 1
fi

cwd=$(pwd)
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
root_macro_path="${script_dir}"

readarray -t lines < "$input_file"

for line in "${lines[@]}"; do
	IFS="," read -r -a fields <<< "$line"
	# check if it's the first line
	if [[ $line == *"runNumber"* ]]; then
		continue
	fi
	run="${fields[0]}"
	timeO2Start="${fields[1]},${fields[2]}"
	# time looks like this: "11/10/2023, 08:45:48"
	# pick the date from here
	dateO2start=$(echo $line | cut -d',' -f2 | xargs -0)
	# remove '"' from timeO2Start
	dateO2start=$(echo $dateO2start | tr -d '"')
	# swap position of day and month
	dateO2start=$(echo $dateO2start | awk -F'/' '{print $2"/"$1"/"$3}')
	dateO2start=$(date -d "$dateO2start" +"%Y-%m-%d")

	echo "Processing run $run"

	rundir="${dateO2start}_${run}" 
	echo $rundir

	if [ -d $rundir ]; then
		if [ "$overwrite" == "true" ]; then
			echo "Run $run already exists, overwriting"
			rm -r $rundir
		else
			echo "Run $run already exists, skipping"
			continue
		fi
	fi
		
	mkdir -p $rundir
	cd $rundir

	echo "run: $run" > run_info.txt
	echo "timeO2Start: $timeO2Start" >> run_info.txt
	echo "Running QC on run ${run}"
	# run the QC bash script and wait for it to finish
	eval "${script_dir}/run_ft0_aging_qc.sh" "$year" "$run"
	# "${script_dir}/run_ft0_aging_c.sh" "$year" "$lhcperiod" "$run" &
	# wait

	echo "Extracting channel ampltidues and times from the QC results and dump them to a csv file"
	if [ -e "ft0_aging_qc_${run}.root" ]; then
		root -b -l -q "${root_macro_path}/PrintAgingQcHistograms.C(\"ft0_aging_qc_${run}.root\", \"ft0_aging_amplitude_${run}.csv\")"
		root -b -l -q "${root_macro_path}/PrintAgingQcHistograms.C(\"ft0_aging_qc_${run}.root\", \"ft0_aging_time_${run}.csv\", false)"
		python3 "${script_dir}/../common/transposeCSV.py" "ft0_aging_amplitude_${run}.csv" "ft0_aging_amplitude_${run}.csv"
		python3 "${script_dir}/../common/transposeCSV.py" "ft0_aging_time_${run}.csv" "ft0_aging_time_${run}.csv"
	else
		echo "File aging_qc_${run}.root does not exist, skipping"
	fi
	cd $cwd
done
