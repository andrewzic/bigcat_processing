#!/bin/bash

###set some useful variable names###
#project root directory
export PROJ_ROOT=/path/to/your/files
export PROJ_SCRIPTS=${PROJ_ROOT}/scripts/
export PROJ_DATA=${PROJ_ROOT}/data/
export PROJ_PROC=${PROJ_ROOT}/proc/
export PROJ_IMG=${PROJ_ROOT}/img/
if [ ! -d ${PROJ_DATA} ]
then
    mkdir -p ${PROJ_DATA}
fi

#parameter to indicate you want to start from scratch
export start_fresh=1

#project code
export pcode=C3999

#primary calibrator source name - should be 1934-638 in most cases
export pcal=1934-638

#secondary calibrator source name
#change this to whatever your phase cal is
export scal=SECONDARY_CAL

#target name
#change this
export target=TARGET

#frequency: usually 2100 (16cm receiver, L/S-band), 5500 or 9000 (4cm receiver, C/X band), etc
export freq=FREQ

#phase reference antenna. Usually 3 works okay
export refant=3

#no. frequency bins for gpcal. Default = 4
export gpcal_nfbins=4

#File IF extension. When observing in L-band, both IFs are centred at 2100 MHz, so ".1" or ".2" etc. are added to the file extension
#Only required if freq = 2100 or if using zoom bands
#Otherwise, leave blank i.e. ifext=""
export ifext=""

#CLEAN iterations
export clean_niters=100000

#CLEAN threshold, in Jy
export clean_thresh=6e-5 

#imaging robustness parameter for briggs weighting
export robust=1.0

#image size in primary beam widths for inversion and imaging. Note - source deconvolution should only happen in inner 50% of image
export pb_imsize=4

export nmfcal_auto=5

export ngpcal_auto=5

SC_FIELD="${SC_FIELD:-}"
SC_SPW="${SC_SPW:-}"
SC_REFANT="${SC_REFANT:-ANT3}"
SC_COMBINE="${SC_COMBINE:-scan}"
SC_MINSNR="${SC_MINSNR:-3.0}"
SC_PARANG="${SC_PARANG:-}"
SC_APPLY_CALWT="${SC_APPLY_CALWT:-False}"

# Round tags & controls
declare -ag IMG_TAGS=("initial_scratch" "selfcal_1" "selfcal_2" "selfcal_3" "selfcal_4" "selfcal_5")
declare -ag SC_INDEX=(1 2 3 4 5)
declare -ag SC_CALMODE=("p" "p" "p" "p" "ap" )
declare -ag SC_SOLINT=("480s" "300s" "120s" "30s" "600s" )
declare -ag SC_PREFIX=("selfcal1_p" "selfcal2_p" "selfcal3_p" "selfcal4_p" "selfcal5_ap" )

# WSClean options (per round)
declare -ag WSCLEAN_OPTS
WSCLEAN_OPTS[0]="${WSCLEAN_OPTS0:-"-data-column DATA -save-source-list -mgain 0.8 -multiscale -multiscale-scale-bias 0.8 -niter 25000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 3 -auto-mask 15.0 -join-channels -channels-out 8 -fit-spectral-pol 3"}"
WSCLEAN_OPTS[1]="${WSCLEAN_OPTS1:-"-data-column DATA -save-source-list -mgain 0.8 -multiscale -multiscale-scale-bias 0.8 -niter 100000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 2 -auto-mask 15.0 -join-channels -channels-out 8 -fit-spectral-pol 3"}"
WSCLEAN_OPTS[2]="${WSCLEAN_OPTS2:-"-data-column DATA -save-source-list -mgain 0.8 -multiscale -multiscale-scale-bias 0.8 -niter 100000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 1.0 -auto-mask 8.0 -join-channels -channels-out 8 -fit-spectral-pol 3"}"
WSCLEAN_OPTS[3]="${WSCLEAN_OPTS3:-"-data-column DATA -save-source-list -mgain 0.8 -multiscale -multiscale-scale-bias 0.8 -niter 100000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 1.0 -auto-mask 5.0 -join-channels -channels-out 8 -fit-spectral-pol 3"}"
WSCLEAN_OPTS[4]="${WSCLEAN_OPTS4:-"-data-column DATA -save-source-list -mgain 0.8 -multiscale -multiscale-scale-bias 0.8 -niter 100000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 1.0 -auto-mask 3.0 -join-channels -channels-out 8 -fit-spectral-pol 3"}"
WSCLEAN_OPTS[5]="${WSCLEAN_OPTS5:-"-data-column DATA -save-source-list -mgain 0.8 -multiscale -multiscale-scale-bias 0.8 -niter 100000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 0.5 -auto-mask 5.0 -join-channels -channels-out 8 -fit-spectral-pol 3"}"
WSCLEAN_OPTS[6]="${WSCLEAN_OPTS6:-"-data-column DATA -save-source-list -mgain 0.8 -multiscale -multiscale-scale-bias 0.8 -niter 100000 -pol i -weight briggs 1.5 -scale 1asec -size 2048 2048 -auto-threshold 0.5 -auto-mask 5.0 -join-channels -channels-out 8 -fit-spectral-pol 3"}"
