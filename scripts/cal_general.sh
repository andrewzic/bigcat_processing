#!/bin/bash

#import variables from config file
source ./config.sh
source ./cal_tools.sh

restart_proc

#user supplied arg
rawuvfits=$1
load_data $rawuvfits

flag_mfcal_sequence

#for manual flagging
blflag_data $pcal chan amp
blflag_data $pcal time phase

flag_mfcal_sequence

flag_gpcal_primary_sequence

gpcopy vis=${PROJ_DATA}/$pcal.${freq}${ifext} out=${PROJ_DATA}/$scal.${freq}${ifext}

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



#wsclean -name ${PROJ_DATA}/${target}.img -data-column DATA -save-source-list -multiscale -multiscale-scale-bias 0.8 -niter 25000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 3 -auto-mask 7.0 -join-channels -channels-out 8 -fit-spectral-pol 3 -minuv-l 1000 ${PROJ_DATA}/${target}.${freq}${ifext}.cal.ms
