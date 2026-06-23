#!/bin/bash

#import variables from config file
source ./config.sh
source ./cal_tools.sh

#restart_proc

if [ ! -d ${PROJ_DATA}/${pcal}.${freq}${ifext} ]
then
    #expecting stuff like rawdata/2026-01-02_0145_C9999/raw.ms
    casa 6 --nologger --nogui -c import_raw_bigcat.py ${PROJ_ROOT}/rawdata/*_${pcode}/raw.ms

    #user supplied arg
    #no actually we can just load in the *pcode.uvfits from the data directory
    shopt -s nullglob
    files=("${PROJ_DATA}"/*_"${pcode}".uvfits)
    rawuvfits="${files[0]}"
    #rawuvfits=$1
    load_data $rawuvfits
fi

if [ ! -f ${PROJ_DATA}/${pcal}_BANDPASS_DONE ]
then
    blflag_data ${pcal} chan amp
    flag_mfcal_sequence

    #for manual flagging
    blflag_data ${pcal} chan amp
    blflag_data ${pcal} time phase

    flag_mfcal_sequence
    blflag_data ${pcal} chan amp
    flag_mfcal_sequence

    touch ${PROJ_DATA}/${pcal}_BANDPASS_DONE

    blflag_data ${pcal} chan amp
fi

if [ ! -f ${PROJ_DATA}/${pcal}_GAIN_DONE ]
then

    flag_gpcal_primary_sequence
    blflag_data ${pcal} chan amp
    blflag_data ${pcal} chan phase
    flag_gpcal_primary_sequence
    blflag_data ${pcal} real imag
    touch ${PROJ_DATA}/${pcal}_GAIN_DONE
fi

if [ ! -f ${PROJ_DATA}/${scal}_GAIN_DONE ]
then
    #copy primary cal data to secondary cal data
    gpcopy vis=${PROJ_DATA}/${pcal}.${freq}${ifext} out=${PROJ_DATA}/${scal}.${freq}${ifext}

    blflag_data ${scal} chan amp
    blflag_data ${scal} chan amp
    flag_gpcal_secondary # This is gain cal
    blflag_data ${scal} chan amp
    blflag_data ${scal} time amp
    blflag_data ${scal} chan phase
    flag_gpcal_secondary
    blflag_data ${scal} real imag
    #assuming all OK, apply flux scale from primary cal onto secondary:
    gpboot vis=${PROJ_DATA}/${scal}.${freq}${ifext} cal=${PROJ_DATA}/${pcal}.${freq}${ifext};
    touch ${PROJ_DATA}/${scal}_GAIN_DONE
fi 

if [ ! -f ${PROJ_DATA}/${target}_CALIB_DONE ]
then

    #now copy calibration solutions to target data
    gpcopy vis=${PROJ_DATA}/${scal}.${freq}${ifext} out=${PROJ_DATA}/${target}.${freq}${ifext};

    #now average gain solutions over the 2-minute interval when on the secondary-cal
    gpaver vis=${PROJ_DATA}/${target}.${freq}${ifext} interval=2

    auto_flag ${target}
    blflag_data ${target} chan amp
    blflag_data ${target} chan amp

    #now apply calibrations to target using uvaver
    uvaver vis=${PROJ_DATA}/${target}.${freq}${ifext} out=${PROJ_DATA}/${target}.${freq}${ifext}.cal

    #and also to the secondary cal, if needed (no clobber)
    if [ ! -d ${PROJ_DATA}/${scal}.${freq}${ifext}.cal ]
    then    
        uvaver vis=${PROJ_DATA}/${scal}.${freq}${ifext} out=${PROJ_DATA}/${scal}.${freq}${ifext}.cal
    fi
    touch ${PROJ_DATA}/${target}_CALIB_DONE
fi

if [ ! -f ${PROJ_DATA}/${target}.${freq}${ifext}.cal.uvfits ]
then
    #this is the final calibrated data product, which we will export to uvfits and then import into CASA for imaging
    fits in=${PROJ_DATA}/${target}.${freq}${ifext}.cal out=${PROJ_DATA}/${target}.${freq}${ifext}.cal.uvfits op=uvout
fi

if [ ! -d ${PROJ_DATA}/${target}.${freq}${ifext}.cal.ms ]
then
    #import calibrated uvfits into CASA format measurement set for imaging
    casa 6 --nologger --nogui -c casa_import.py ${PROJ_DATA}/${target}.${freq}${ifext}.cal.uvfits
fi

wsclean -name ${PROJ_DATA}/${target}.img -data-column DATA -save-source-list -multiscale -multiscale-scale-bias 0.8 -niter 25000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 3 -auto-mask 7.0 -join-channels -channels-out 8 -fit-spectral-pol 3 -minuv-l 1600 ${PROJ_DATA}/${target}.${freq}${ifext}.cal.ms ; rm ${PROJ_DATA}/*000?-*.fits

for r in ${SC_INDEX[@]}
do
    echo "Starting selfcal round ${r} with calmode ${SC_CALMODE[r-1]} and solint ${SC_SOLINT[r-1]}"
    if (( r == 1)); then
        #first round of selfcal should be derived from the original calibrated data
        ms_to_selfcal=${PROJ_DATA}/${target}.${freq}${ifext}.cal.ms
    else
        #subsequent rounds should be derived from the previous selfcal round
        ms_to_selfcal=${PROJ_DATA}/${target}.${freq}${ifext}.selfcal_$((r-1)).ms
    fi
    casa 6 --nologger --nogui -c selfcal.py --ms ${ms_to_selfcal} --index ${r} --calmode ${SC_CALMODE[r-1]} --field "${SC_FIELD}" --spw "${SC_SPW}" --refant "${SC_REFANT}" --combine "${SC_COMBINE}" --minsnr ${SC_MINSNR} --parang ${SC_PARANG} --apply_calwt ${SC_APPLY_CALWT}
    #new_ms = args.ms.replace(".cal.ms", f".selfcal_{args.index}.ms")
    new_ms=${PROJ_DATA}/${target}.${freq}${ifext}.selfcal_${r}.ms
    wsclean ${WSCLEAN_OPTS[r-1]} -name ${PROJ_DATA}/${target}_${SC_PREFIX[r-1]} -minuv-l 1600 ${new_ms} ; rm ${PROJ_DATA}/*000?-*.fits
done

