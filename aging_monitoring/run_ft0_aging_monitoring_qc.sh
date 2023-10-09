#!/bin/bash

# Script to run QC on FT0 aging monitoring laser runs
#
# Usage: ./run_ft0_aging_monitoring_qc.sh <year> <lhcperiod> <run>
#
# The script dumps the QC results in a root file named ft0_aging_monitoring_qc_<run>.root

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
qc_dir="/home/andreas/alice/QualityControl"
#qc_dir=$QUALITYCONTROL_ROOT

if [ $# -ne 3 ]; then
	echo "Usage: ${0##*/} <year> <lhcperiod> <run>"
	exit 1
fi

year=$1
lhcperiod=$2
run=$3

input_file_list="file.lst"

if [ ! -e $input_file_list ]; then
	${script_dir}/../common/make_file_list.sh -y $year -p $lhcperiod -r $run -t calib -n -1 -f $input_file_list
fi

#Construct the workflow command
workflow=""
# Read the CTF files
workflow+="o2-ctf-reader-workflow --ctf-input ${input_file_list} --onlyDet FT0 -b --severity=error"
# Run the QC
workflow+=" | o2-qc -b --config \"json://${qc_dir}/Modules/FIT/FT0/etc/ft0-aging-monitoring.json\" --local-batch \"ft0_aging_monitoring_qc_${run}.root\""

echo "Running workflow:"
echo $workflow | sed 's/| /|\n/g'
eval $workflow

