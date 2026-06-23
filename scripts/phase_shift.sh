#!/bin/bash

#import variables from config file
echo "HERE"
echo ${PWD}
source ./config.sh
source ./img_tools.sh

cd ${PROJ_DATA}


sed -i 's/freq=9000/freq=5500/g' ${PROJ_SCRIPTS}/config.sh
source ${PROJ_SCRIPTS}/config.sh
source ${PROJ_SCRIPTS}/config.sh

phaseshift $target.${freq}${ifext}.cal.uvsub "23,39,39.808" "-69,11,46.34"
mv $target.${freq}${ifext}.cal.uvsub.ps $target.${freq}${ifext}.cal.uvsub.dstuc_a

phaseshift $target.${freq}${ifext}.cal.uvsub "23,39,39.577" "-69,11,41.01"
mv $target.${freq}${ifext}.cal.uvsub.ps $target.${freq}${ifext}.cal.uvsub.dstuc_b

cd ${PROJ_SCRIPTS}
sed -i 's/freq=5500/freq=9000/g' ${PROJ_SCRIPTS}/config.sh

source ${PROJ_SCRIPTS}/config.sh
source ${PROJ_SCRIPTS}/img_tools.sh


cd ${PROJ_DATA}
phaseshift $target.${freq}${ifext}.cal.uvsub "23,39,39.808" "-69,11,46.34"
mv $target.${freq}${ifext}.cal.uvsub.ps $target.${freq}${ifext}.cal.uvsub.dstuc_a

phaseshift $target.${freq}${ifext}.cal.uvsub "23,39,39.577" "-69,11,41.01"
mv $target.${freq}${ifext}.cal.uvsub.ps $target.${freq}${ifext}.cal.uvsub.dstuc_b


cd ${PROJ_ROOT}
