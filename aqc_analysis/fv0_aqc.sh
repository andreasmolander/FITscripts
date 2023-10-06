#!/bin/bash

# Script to extract and analyze asyncronous quality control plots for FV0

set -x # Debug

usealien=true # fetch the AQC results from alien, i.e. the merged file QC_fullrun.root

printplots=true
plotformat=png

overwrite=true
remove_aqcfile=true

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOTSTYLE_DIR="${SCRIPT_DIR}/../root_styles"

PrintPlots()
{
    # Print plots based on aqc_fv0.root in the current working directory

    if [ ! -d plots ]; then
        mkdir plots
    fi

    # Plot style ROOT macros
    logy="${ROOTSTYLE_DIR}/logy.C"
    logz="${ROOTSTYLE_DIR}/logz.C"
    logxlogy="${ROOTSTYLE_DIR}/logxlogy.C"
    logylogz="${ROOTSTYLE_DIR}/logylogz.C"

    # AmpPerChannel
    rootprint -f $plotformat aqc_fv0.root:FV0/Digits/AmpPerChannel
    mv AmpPerChannel.$plotformat plots/AmpPerChannel.$plotformat

    rootprint -f $plotformat -S $logy aqc_fv0.root:FV0/Digits/AmpPerChannel
    mv AmpPerChannel.$plotformat plots/AmpPerChannel_logy.$plotformat

    rootprint -f $plotformat -S $logylogz aqc_fv0.root:FV0/Digits/AmpPerChannel
    mv AmpPerChannel.$plotformat plots/AmpPerChannel_logylogz.$plotformat

    # Time per channel
    rootprint -f $plotformat aqc_fv0.root:FV0/Digits/TimePerChannel
    mv TimePerChannel.$plotformat plots/TimePerChannel.$plotformat

    rootprint -f $plotformat -S $logz aqc_fv0.root:FV0/Digits/TimePerChannel
    mv TimePerChannel.$plotformat plots/TimePerChannel_logz.$plotformat

    # Sum of amplitudes
    rootprint -f $plotformat -S $logy aqc_fv0.root:FV0/Digits/SumAmpA
    mv SumAmpA.$plotformat plots/SumAmpA_logy.$plotformat

    rootprint -f $plotformat -S $logxlogy aqc_fv0.root:FV0/Digits/SumAmpA
    mv SumAmpA.$plotformat plots/SumAmpA_logxlogy.$plotformat

    rootprint -f $plotformat -S $logy aqc_fv0.root:FV0/DigitsPrepared/SumAmpAXRange
    mv SumAmpAXRange.$plotformat plots/SumAmpA_xrange_logy.$plotformat

    rootprint -f $plotformat -S $logxlogy aqc_fv0.root:FV0/DigitsPrepared/SumAmpAXRange
    mv SumAmpAXRange.$plotformat plots/SumAmpA_xrange_logxlogy.$plotformat

    # Number of channels
    rootprint -f $plotformat aqc_fv0.root:FV0/Digits/NumChannelsA
    mv NumChannelsA.$plotformat plots/NumChannelsA.$plotformat

    rootprint -f $plotformat -S $logy aqc_fv0.root:FV0/Digits/NumChannelsA
    mv NumChannelsA.$plotformat plots/NumChannelsA_logy.$plotformat

    # Number of triggers
    rootprint -f $plotformat aqc_fv0.root:FV0/Digits/TriggersSoftware
    mv TriggersSoftware.$plotformat plots/TriggersSoftware.$plotformat

    rootprint -f $plotformat -S $logy aqc_fv0.root:FV0/Digits/TriggersSoftware
    mv TriggersSoftware.$plotformat plots/TriggersSoftware_logy.$plotformat
}

ExtractAQC()
{
    year="$1"
    lhcperiod="$2"
    runnumber="$3"
    pass="$4"

    cwd=$(pwd)
    rundir="${cwd}/${lhcperiod}/${pass}/${runnumber}"

    if [ ! -d "${rundir}" ]; then
        mkdir -p $rundir
    fi

    cd $rundir

    echo $(date) > log.txt
    echo "$year $period $runnumber $pass" >> log.txt
    echo "Use alien=${usealien}" >> log.txt

    extract=false # whether or not to (re)create the aqc_fv0.root file (set to true if it doesn't exist or if $overwrite = true)

    if $usealien; then
        # Download QC_fullrun.root from alien
        ( $overwrite || [ ! -e QC_fullrun.root ] ) && download=true || download=false
        ( $download || [ ! -e aqc_fv0.root ] ) && extract=true || extract=false

        if $download; then
            alienpath="/alice/data/${year}/${lhcperiod}/${runnumber}/${pass}"
            qcfullrun_filename=$(alien_find "${alienpath} QC_fullrun.root")
            if [[ $? -ne 0 || "$qcfullrun_filename" = "" ]]; then
                echo "QC_fullrun.root not found in ${alienpath}" >> log.txt
                cd $cwd
                return 1
            fi
            alien_cp $qcfullrun_filename file:.
            if [ $? -ne 0 ]; then
                echo "Failed to copy ${qcfullrun_filename}" >> log.txt
                cd $cwd
                return 1
            fi
        fi
    else
        ( $overwrite || [ ! -e aqc_fv0.root ] ) && extract=true || extract=false
    fi

    if $extract; then
        root -b -l -q "${SCRIPT_DIR}/ExtractAQCPlots.C(${usealien})" > root_log.txt
        if [ $? -ne 0 ]; then
            echo "ROOT macro ${SCRIPT_DIR}/ExtractAQCPlots.C failed. See root_log.txt for info."
            echo "ROOT macro ${SCRIPT_DIR}/ExtractAQCPlots.C failed. See root_log.txt for info." >> log.txt
        fi
    else
        echo "Will not extract plots" >> log.txt
    fi

    if $printplots; then
        PrintPlots
    fi

    if [[ "$usealien" = "true" && "$remove_aqcfile" = "true" ]]; then
        rm QC_fullrun.root
    fi

    cd $cwd
}

if [ "$#" -eq 1 ]; then
    while IFS="," read -r year period runnumber pass;
    do
        ExtractAQC "$year" "$period" "$runnumber" "$pass"
    done < $1
elif [ "$#" -eq 4 ]; then
    ExtractAQC "$1" "$2" "$3" "$4"
else
    echo "Usage: $0 <inputfile>"
    echo "or"
    echo "Usage: $0 <year> <period> <runNumber> <pass>"
    exit 1
fi
