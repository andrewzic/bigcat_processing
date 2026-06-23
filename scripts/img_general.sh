#!/bin/bash

#import variables from config file
source ./config.sh
source ./img_tools.sh

cd ${PROJ_IMG}

dirty_image $target.${freq}${ifext}.cal i
# dirty_image $scal.${freq}${ifext}.cal q
# dirty_image $scal.${freq}${ifext}.cal u
dirty_image $target.${freq}${ifext}.cal v

cgcurs_map $target.${freq}${ifext}.cal i

clean_map $target.${freq}${ifext}.cal i

uvmodel_mfs $target.${freq}${ifext}.cal ${target}.${freq}${ifext}.cal.imodel

cd ${PROJ_ROOT}
