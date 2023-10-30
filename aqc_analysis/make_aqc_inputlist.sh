#!/bin/bash

# Script to generate AQC analysis input list based on the daily report mail
#
# The input looks something like this:
#
# RAW data

#   LHCPERIOD QC
#     Run: RUNNUMBER, job id: 2938946211, path: /alice/data/YEAR/LHCPERIOD/RUNNUMBER/PASS/2000/QC
#     Run: RUNNUMBER, job id: 2939022824, path: /alice/data/YEAR/LHCPERIOD/RUNNUMBER/PASS/0150/QC
#     Run: RUNNUMBER, job id: 2939010643, path: /alice/data/YEAR/LHCPERIOD/RUNNUMBER/PASS/0930/QC
#     Run: RUNNUMBER, job id: 2938943720, path: /alice/data/YEAR/LHCPERIOD/RUNNUMBER/PASS/1200/QC

# Generate an output file with the following format:
# YEAR,LHCPERIOD,RUNNUMBER,PASS

set -x # Debug

# Input and output files
input_file=$1
output_file=$2

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Input file '$input_file' does not exist."
    exit 1
fi

# Create an empty output file or overwrite an existing one
> "$output_file"

# Process the input file
while IFS= read -r line; do
    if [[ "$line" =~ Run:\ ([0-9]+),\ job\ id:[\ 0-9]+,\ path:\ (.*)$ ]]; then
        run_number="${BASH_REMATCH[1]}"
        path="${BASH_REMATCH[2]}"

        # Extract YEAR, LHCPERIOD, and PASS from the path
				IFS='/' read -r -a path_array <<< "$path"
				year="${path_array[3]}"
				lhcperiod="${path_array[4]}"
				pass="${path_array[6]}"

				# Write the output to the output file
				echo "$year,$lhcperiod,$run_number,$pass" >> "$output_file"
    fi
done < "$input_file"

echo "Output written to '$output_file'."
