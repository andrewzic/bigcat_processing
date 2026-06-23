#!/bin/bash

#import variables from config file
source ./config.sh
source ./cal_tools.sh

#restart_proc

#load_data

flag_mfcal_sequence_auto ${nmfcal_auto}

#for manual flagging
blflag_data $pcal chan amp
blflag_data $pcal chan phase
blflag_data $pcal time phase

flag_mfcal_sequence_auto ${nmfcal_auto}

flag_gpcal_primary_sequence_auto ${ngpcal_auto}

gpcopy vis=${PROJ_DATA}/$pcal.${freq}${ifext} out=${PROJ_DATA}/$scal.${freq}${ifext}


flag_gpcal_secondary_auto
flag_gpcal_secondary_auto

#assuming all OK, apply flux scale from primary cal onto secondary:
gpboot vis=${PROJ_DATA}/$scal.${freq}${ifext} cal=${PROJ_DATA}/$pcal.${freq}${ifext};

#now copy calibration solutions to target data
gpcopy vis=${PROJ_DATA}/$scal.${freq}${ifext} out=${PROJ_DATA}/$target.${freq}${ifext};

#now average gain solutions over the 2-minute interval when on the secondary-cal
gpaver vis=${PROJ_DATA}/$target.${freq}${ifext} interval=2


auto_flag $target

#now apply calibrations to target using uvaver
uvaver vis=${PROJ_DATA}/$target.${freq}${ifext} out=${PROJ_DATA}/$target.${freq}${ifext}.cal

#and also to the secondary cal
uvaver vis=${PROJ_DATA}/$scal.${freq}${ifext} out=${PROJ_DATA}/$scal.${freq}${ifext}.cal

#this concludes the calibration


