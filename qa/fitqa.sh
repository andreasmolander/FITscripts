#!/bin/bash

# Script that runs the FIT AO2D QA
#
# Usage: fitqa.sh [OPTION]

# set -x # Debug

# detectors
doFIT=false # not implemented yet
doFT0=false
doFV0=true
doFDD=false

aodfile=""
config=""
batchmode=""
bcconv=false   # run bc-converter
collconv=false # run collision-converter
zdcconb=false  # run zdc-converter
print=false

# Function that prints usage help
Usage() {
    echo "Usage: ${0##*/} [OPTION]"
    echo "  --fit				 run the FIT AO2D QA (not implemented)"
    echo "  --ft0				 run the FT0 AO2D QA"
    echo "  --fv0				 run the FV0 AO2D QA"
    echo "  --fdd				 run the FDD AO2D QA"
    echo "  -c, --config CONFIG  use config file CONFIG"
    echo "  --aod-file FILE      use AO2D file FILE"
    echo "  -b, --batch          batchmode"
    echo "  --bcconv             run the BC converter"        # automate based on timestamp?
    echo "  --collconv           run the collision converter" # automate based on timestamp?
    echo "  --zdcconv            run the ZDC converter"       # automate based on timestamp?
    echo "  -p, --print          print the workflow command without running it"
    echo "  -h, --help           print this help"
    exit
}

# Parse script arguments
while [ $# -gt 0 ]; do
    case $1 in
    -c | --config)   config="--configuration json://$2"; shift 2 ;;
         --aod-file) aodfile="--aod-file $2";            shift 2 ;;
    -b | --batch)    batchmode="-b";                     shift 1 ;;
         --bcconv)   bcconv=true;                        shift 1 ;;
         --collconv) collconv=true;                      shift 1 ;;
         --zdcconv)  zdcconv=true;                       shift 1 ;;
    -p | --print)    print=true;                         shift 1 ;;
    -h | --help)     Usage ;;
    *)               echo "Wrong input"; Usage ;
    esac
done

# Collect script arguments
args_all="$aodfile $config $batchmode"

# Construct workflow command
workflow=""
if [ "$bcconv" = true ]; then
    workflow+="o2-analysis-bc-converter $args_all"
    workflow+=" | "
fi
workflow+=" o2-analysis-timestamp $args_all"
if [ "$collconv" = true ]; then
    workflow+=" | o2-analysis-collision-converter $args_all"
fi
if [ "$zdcconv" = true ]; then
    workflow+=" | o2-analysis-zdc-converter $args_all"
fi
workflow+=" | o2-analysis-track-propagation $args_all"
workflow+=" | o2-analysis-tracks-extra-converter $args_all"
workflow+=" | o2-analysis-trackselection $args_all"
workflow+=" | o2-analysis-event-selection $args_all"
workflow+=" | o2-analysis-multiplicity-table $args_all"
if [ "$doFIT" = true ]; then
    echo "Common FIT QA not implemented yet"
    exit 1
fi
if [ "$doFT0" = true ]; then
    workflow+=" | o2-analysis-ft0-corrected-table $args_all"
    workflow+=" | o2-analysis-ft0-qa $args_all"
fi
if [ "$doFV0" = true ]; then
    workflow+=" | o2-analysis-fv0-qa $args_all"
fi
if [ "$doFDD" = true ]; then
    workflow+=" | o2-analysis-fdd-qa $args_all"
fi

if [ "$print" = true ]; then
    # Print the workflow command without running it
    echo "Workflow command:"
    echo $workflow | sed 's/| /|\n/g'
else
    # Print the workflow command and run it
    echo "Running workflow:"
    echo $workflow | sed 's/| /|\n/g'
    eval $workflow
fi
