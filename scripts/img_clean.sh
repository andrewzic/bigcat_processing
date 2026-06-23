#!/bin/bash

#import variables from config file
source ./config.sh
source ./img_tools.sh

cd ${PROJ_IMG}


clean_map $target.${freq}${ifext}.cal i

uvmodel_mfs $target.${freq}${ifext}.cal ${target}.${freq}${ifext}.cal.imodel

#selfcal_phase_sequence ${target}.${freq}${ifext}.cal

