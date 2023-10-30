#!/bin/bash

# Script to extract and analyze asyncronous quality control plots for FV0

# set -x # Debug

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CWD=$(pwd)

CURLPROXY="-x socks5h://localhost:8081"

USE_ALIEN=true # fetch the AQC results from alien, i.e. the merged file QC_fullrun.root
OVERWRITE=true
REMOVE_AQCFILE=true

PRINT_PLOTS=true
PLOTFORMAT=png
ROOTSTYLE_DIR="${SCRIPT_DIR}/../root_styles"

print_plots() {
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
    rootprint -f $PLOTFORMAT aqc_fv0.root:FV0/Digits/AmpPerChannel
    mv AmpPerChannel.$PLOTFORMAT plots/AmpPerChannel.$PLOTFORMAT

    rootprint -f $PLOTFORMAT -S $logy aqc_fv0.root:FV0/Digits/AmpPerChannel
    mv AmpPerChannel.$PLOTFORMAT plots/AmpPerChannel_logy.$PLOTFORMAT

    rootprint -f $PLOTFORMAT -S $logylogz aqc_fv0.root:FV0/Digits/AmpPerChannel
    mv AmpPerChannel.$PLOTFORMAT plots/AmpPerChannel_logylogz.$PLOTFORMAT

    # Time per channel
    rootprint -f $PLOTFORMAT aqc_fv0.root:FV0/Digits/TimePerChannel
    mv TimePerChannel.$PLOTFORMAT plots/TimePerChannel.$PLOTFORMAT

    rootprint -f $PLOTFORMAT -S $logz aqc_fv0.root:FV0/Digits/TimePerChannel
    mv TimePerChannel.$PLOTFORMAT plots/TimePerChannel_logz.$PLOTFORMAT

    # Sum of amplitudes
    rootprint -f $PLOTFORMAT -S $logy aqc_fv0.root:FV0/Digits/SumAmpA
    mv SumAmpA.$PLOTFORMAT plots/SumAmpA_logy.$PLOTFORMAT

    rootprint -f $PLOTFORMAT -S $logxlogy aqc_fv0.root:FV0/Digits/SumAmpA
    mv SumAmpA.$PLOTFORMAT plots/SumAmpA_logxlogy.$PLOTFORMAT

    rootprint -f $PLOTFORMAT -S $logy aqc_fv0.root:FV0/DigitsPrepared/SumAmpAXRange
    mv SumAmpAXRange.$PLOTFORMAT plots/SumAmpA_xrange_logy.$PLOTFORMAT

    rootprint -f $PLOTFORMAT -S $logxlogy aqc_fv0.root:FV0/DigitsPrepared/SumAmpAXRange
    mv SumAmpAXRange.$PLOTFORMAT plots/SumAmpA_xrange_logxlogy.$PLOTFORMAT

    # Number of channels
    rootprint -f $PLOTFORMAT aqc_fv0.root:FV0/Digits/NumChannelsA
    mv NumChannelsA.$PLOTFORMAT plots/NumChannelsA.$PLOTFORMAT

    rootprint -f $PLOTFORMAT -S $logy aqc_fv0.root:FV0/Digits/NumChannelsA
    mv NumChannelsA.$PLOTFORMAT plots/NumChannelsA_logy.$PLOTFORMAT

    # Number of triggers
    rootprint -f $PLOTFORMAT aqc_fv0.root:FV0/Digits/TriggersSoftware
    mv TriggersSoftware.$PLOTFORMAT plots/TriggersSoftware.$PLOTFORMAT

    rootprint -f $PLOTFORMAT -S $logy aqc_fv0.root:FV0/Digits/TriggersSoftware
    mv TriggersSoftware.$PLOTFORMAT plots/TriggersSoftware_logy.$PLOTFORMAT

    # Average time
    rootprint -f $PLOTFORMAT aqc_fv0.root:FV0/Digits/AverageTimeA
    mv AverageTimeA.$PLOTFORMAT plots/AverageTimeA.$PLOTFORMAT
}

abort() {
    echo "Aborting..."
    echo "$1" >>"${CWD}/failed.txt"
    cd $CWD
    exit 1
}

extract_aqc() {
    year="$1"
    lhcperiod="$2"
    runnumber="$3"
    pass="$4"

    runstring="${year}_${lhcperiod}_${runnumber}_${pass}"
    rundir="${CWD}/${lhcperiod}/${pass}/${runnumber}"

    if [ ! -d "${rundir}" ]; then
        mkdir -p $rundir
    fi

    cd $rundir

    echo $(date) >log.txt
    echo "$year $period $runnumber $pass" >>log.txt
    echo "Use alien=${USE_ALIEN}" >>log.txt

    extract=false # whether or not to (re)create the aqc_fv0.root file (set to true if it doesn't exist or if $OVERWRITE = true)

    if $USE_ALIEN; then
        # Download QC_fullrun.root from alien
        ($OVERWRITE || [ ! -f QC_fullrun.root ]) && download=true || download=false
        ($download || [ ! -f aqc_fv0.root ]) && extract=true || extract=false

        if $download; then
            alienpath="/alice/data/${year}/${lhcperiod}/${runnumber}/${pass}"
            qcfullrun_filename=$(alien_find "${alienpath} QC_fullrun.root")
            if [[ $? -ne 0 || "$qcfullrun_filename" = "" ]]; then
                echo "QC_fullrun.root not found in ${alienpath}" >>log.txt
                abort $runstring
            fi
            alien_cp $qcfullrun_filename file:.
            if [ $? -ne 0 ]; then
                echo "Failed to copy ${qcfullrun_filename}" >>log.txt
                abort $runstring
            fi
        fi
    else
        ($OVERWRITE || [ ! -f aqc_fv0.root ]) && extract=true || extract=false
    fi

    if $extract; then
        root -b -l -q "${SCRIPT_DIR}/ExtractAQCPlots.C(${USE_ALIEN})" >root_log.txt
        if [ $? -ne 0 ]; then
            echo "ROOT macro ${SCRIPT_DIR}/ExtractAQCPlots.C failed. See root_log.txt for info."
            echo "ROOT macro ${SCRIPT_DIR}/ExtractAQCPlots.C failed. See root_log.txt for info." >>log.txt
            # TODO: remove QC_fullrun.root
            abort $runstring
        fi
    else
        echo "Will not extract plots" >>log.txt
    fi

    # Trigger validation has to be checked from online QC at the moment
    curl $CURLPROXY -s http://alio2-cr1-hv-qcdb-gpn.cern.ch:8083/browse/qc/FV0/QO/TrgValidationCheck/RunNumber=$runnumber | grep 'qc_quality = \(2\|3\|10\)' >TrgValidationCheck.txt
    n_qo_not_good=$(cat TrgValidationCheck.txt | wc -l)
    if [ $n_qo_not_good -eq 0 ]; then
        rm TrgValidationCheck.txt
    fi

    if [[ "$USE_ALIEN" = "true" && "$REMOVE_AQCFILE" = "true" ]]; then
        rm QC_fullrun.root
    fi

    if $PRINT_PLOTS; then
        print_plots
    fi

    cd $CWD
}

if [ "$#" -eq 1 ]; then
    while IFS="," read -r year period runnumber pass; do
        extract_aqc "$year" "$period" "$runnumber" "$pass"
    done <$1
elif [ "$#" -eq 4 ]; then
    extract_aqc "$1" "$2" "$3" "$4"
else
    echo "Usage: $0 <inputfile>"
    echo "or"
    echo "Usage: $0 <year> <period> <runNumber> <pass>"
    exit 1
fi
