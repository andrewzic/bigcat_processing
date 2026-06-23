#!/bin/bash

#import variables from config file
source ./config.sh
source ./cal_tools.sh

restart_proc

#expecting stuff like rawdata/2026-01-02_0145_C9999/raw.ms
casa 6 --nologger --nogui -c import_raw_bigcat.py ${PROJ_ROOT}/rawdata/*_${pcode}/raw.ms

#user supplied arg
#no actually we can just load in the *pcode.uvfits from the data directory
shopt -s nullglob
files=("${PROJ_DATA}"/*_"${pcode}".uvfits)
rawuvfits="${files[0]}"
#rawuvfits=$1
load_data $rawuvfits

blflag_data $pcal chan amp
flag_mfcal_sequence

#for manual flagging
blflag_data $pcal chan amp
blflag_data $pcal time phase

flag_mfcal_sequence
blflag_data $pcal chan amp
flag_mfcal_sequence

blflag_data $pcal chan amp

flag_gpcal_primary_sequence
blflag_data $pcal chan amp
blflag_data $pcal chan phase
flag_gpcal_primary_sequence

gpcopy vis=${PROJ_DATA}/$pcal.${freq}${ifext} out=${PROJ_DATA}/$scal.${freq}${ifext}

blflag_data $scal chan amp
blflag_data $scal chan amp
flag_gpcal_secondary # This is gain cal
blflag_data $scal chan amp
blflag_data $scal time amp
blflag_data $scal chan phase
flag_gpcal_secondary

#assuming all OK, apply flux scale from primary cal onto secondary:
gpboot vis=${PROJ_DATA}/$scal.${freq}${ifext} cal=${PROJ_DATA}/$pcal.${freq}${ifext};

#now copy calibration solutions to target data
gpcopy vis=${PROJ_DATA}/$scal.${freq}${ifext} out=${PROJ_DATA}/$target.${freq}${ifext};

#now average gain solutions over the 2-minute interval when on the secondary-cal
gpaver vis=${PROJ_DATA}/$target.${freq}${ifext} interval=2

auto_flag $target
blflag_data $target chan amp
blflag_data $target chan amp

#now apply calibrations to target using uvaver
uvaver vis=${PROJ_DATA}/$target.${freq}${ifext} out=${PROJ_DATA}/$target.${freq}${ifext}.cal

#and also to the secondary cal, if needed (no clobber)
if [ ! -d ${PROJ_DATA}/$scal.${freq}${ifext}.cal ]
then    
    uvaver vis=${PROJ_DATA}/$scal.${freq}${ifext} out=${PROJ_DATA}/$scal.${freq}${ifext}.cal
fi

#this concludes the calibration
#export to uvfits
fits in=${PROJ_DATA}/$target.${freq}${ifext}.cal out=${PROJ_DATA}/$target.${freq}${ifext}.cal.uvfits op=uvout

casa 6 --nologger --nogui -c casa_import.py ${PROJ_DATA}/${target}.${freq}${ifext}.cal.uvfits

wsclean -name ${target}.img -data-column DATA -save-source-list -multiscale -multiscale-scale-bias 0.8 -niter 25000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 3 -auto-mask 7.0 -join-channels -channels-out 8 -fit-spectral-pol 3 -minuv-l 1600 ${target}.${freq}${ifext}.cal.ms ; rm *000?-*.fits
