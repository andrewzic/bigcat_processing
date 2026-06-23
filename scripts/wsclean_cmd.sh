#!/bin/bash

wsclean -name ${target}.img -data-column DATA -save-source-list -multiscale -multiscale-scale-bias 0.8 -niter 25000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 3 -auto-mask 7.0 -join-channels -channels-out 8 -fit-spectral-pol 3 -minuv-l 1600 ${target}.${freq}${ifext}.cal.ms ; rm *000?-*.fits
