#!/bin/bash

#import variables from config file
source ./config.sh

restart_proc() {
    
    if [[ $start_fresh == 1 ]]; then

	#delete all files before a new run
	rm -fr ${pcode}*.uv *.2100* *.5500 *.9000

    fi
    return 0
    
}

load_data_cabb() {

    #load in all the files for this project code
    #note - make sure you discard all files used for array setup before you load data
    atlod in=${PROJ_DATA}/*.$pcode out=${PROJ_DATA}/$pcode".uv" options=birdie,noauto,xycorr,rfiflag
    
    #split into 1934-638.<blah blah>
    uvsplit vis=${PROJ_DATA}/$pcode".uv"

    mv ${pcal}* ${PROJ_DATA}/
    mv ${scal}* ${PROJ_DATA}/
    mv ${target}* ${PROJ_DATA}/

    echo "loaded and split primary cal data"
    return 0
}

load_data() {

    fitsfile=$1

    uvout=${fitsfile/.uvfits/}
    echo "exporting $fitsfile to $uvout"
    fits in=$fitsfile out=$uvout op=uvin
    # Convert to FITS

    #flag zero-valued data
    uvzflag vis=$uvout
    uvflag vis=$uvout select="auto or amplitude(500)" flagval="flag"
    # Split
    echo "splitting $uvout"
    uvsplit vis=$uvout

    echo "moving to $PROJ_DATA"
    mv ${pcal}* ${PROJ_DATA}/
    mv ${scal}* ${PROJ_DATA}/
    mv ${target}* ${PROJ_DATA}/
    mv *.${freq}*/ ${PROJ_DATA}/
    
    # Clean up
    # os.system("rm -r {} {} {}.flagversions {}".format(fitsfile, mir_ms, mir_ms, uvout))
}

auto_flag() {

    src=$1
    stokes=$2
    
    #do some auto-flagging
    if [[ -z ${stokes} ]]; then
	#first do on Stokes xy, yx
	pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=xx,yy,yx,xy  options=nodisp #flagpar=7,5,5,3,6,3,20
	pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=xx,yy,xy,yx  options=nodisp #flagpar=7,5,5,3,6,3,20
    elif [[ ${stokes} == "v" ]]; then
	pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=i,q,u,v  options=nodisp #flagpar=7,5,5,3,6,3,20
	pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=i,q,v,u  options=nodisp #flagpar=7,5,5,3,6,3,20
    elif [[ ${stokes} == "i" ]]; then
	pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=v,u,q,i  options=nodisp #flagpar=7,5,5,3,6,3,20
	pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=v,u,i,q  options=nodisp #flagpar=7,5,5,3,6,3,20	
    else
	return 1
	echo "please enter a blank value or 'v'"
    fi
	
    
    #now on each instr. pol. independently
    # for stokes in xx yy xy yx
    # do
    # 	pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=${stokes} flagpar=7,5,5,3,6,3,20 options=nodisp
    # done
    ##then Q, U
    #pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=i,v,q,u flagpar=7,5,5,3,6,3,20 options=nodisp
    #pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=i,v,u,q flagpar=7,5,5,3,6,3,20 options=nodisp
    return 0
}

blflag_data() {

    src=$1
    x=$2
    y=$3
    
    blflag vis=${PROJ_DATA}/${src}.$freq${ifext} options=nobase,nofqav stokes=xx,yy device=/xs axis=${x},${y}
    
}

auto_flag_target() {

    auto_flag $target
    auto_flag $target v
    auto_flag $target i
    
    #do some auto-flagging
    #on Q, U
    #pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=xx,yy,xy,yx flagpar=7,5,5,3,6,3,20 options=nodisp
    #pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=xx,yy,yx,xy flagpar=7,5,5,3,6,3,20 options=nodisp
    #on I
    #pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=v,q,u,i flagpar=7,5,5,3,6,3,20 options=nodisp
    ##on xx,yy
    #pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=xy,yx,xx,yy flagpar=7,5,5,3,6,3,20 options=nodisp
    #pgflag vis=${PROJ_DATA}/${src}.${freq}${ifext} "command=<b" device=/xs stokes=xy,yx,yy,xx flagpar=7,5,5,3,6,3,20 options=nodisp

    return 0
}

flag_mfcal() {

    ### block for one round of flagging and bandpass calibration
    
    #set the interval
    interval=$1

    #auto-flag
    auto_flag ${pcal}

    #now calibrate
    mfcal vis=${PROJ_DATA}/${pcal}.${freq}$ifext interval=${interval} refant=${refant}

    #plot spectrum
    uvspec vis=${PROJ_DATA}/${pcal}.${freq}${ifext} axis=chan,amp stokes=xx,yy device=/xs interval=9999 options=nobase #all baselines overlaid

    #stop and wait to continue
    read -p "Press enter to continue"

    return 0
}


flag_mfcal_auto() {

    ### block for one round of flagging and bandpass calibration
    
    #set the interval
    interval=$1

    #auto-flag
    auto_flag ${pcal}

    #now calibrate
    mfcal vis=${PROJ_DATA}/${pcal}.${freq}$ifext interval=${interval} refant=${refant}

    #plot spectrum
    uvspec vis=${PROJ_DATA}/${pcal}.${freq}${ifext} axis=chan,amp stokes=xx,yy device=/xs interval=9999 options=nobase #all baselines overlaid

    #stop and wait to continue
    #read -p "Press enter to continue"

    return 0
}



flag_mfcal_sequence() {

    ###loops through flagging and bandpass calibration until user gives non-blank input
    
    #initial bandpass calibration using 1934
    mfcal vis=${PROJ_DATA}/${pcal}.${freq}${ifext} interval=15.0 refant=$refant

    echo "doing flag-bandpass cal with interval=1.0"
    read -s -p "hit enter to continue; type any key and hit enter stop" continue_flag
    while [[ -z ${continue_flag} ]]; do
	#if input is not blank, then exit loop
	#this is redundant
	if [ ! -z ${continue_flag} ]; then
	    break
	fi
	
	flag_mfcal 1.0

	read -s -p "hit enter to continue; type any key and hit enter stop" continue_flag
	
    done

    echo "doing flag-bandpass cal with interval = 0.1"
    read -s -p "hit enter to continue; type any key and hit enter stop" continue_flag2
    while [[ -z ${continue_flag2} ]]; do
	#if input is not blank, then exit loop
	#redundant
	if [ ! -z ${continue_flag2} ]; then
	    break
	fi
	
	flag_mfcal 0.1

	read -s -p "hit enter to continue; type any key and hit enter stop" continue_flag2
	
    done    

    return 0
}


flag_mfcal_sequence_auto() {

    ###loops through flagging and bandpass calibration for a defined number of turns
    
    #initial bandpass calibration using 1934
    mfcal vis=${PROJ_DATA}/${pcal}.${freq}${ifext} interval=15.0 refant=$refant

    echo "doing flag-bandpass cal with interval=0.1"
    niter_flag_mfcal=$1

    for it__ in `seq 0 ${niter_flag_mfcal}`;
    do
	

	#if input is not blank, then exit loop
	#this is redundant
	
	flag_mfcal_auto 0.1

	#read -s -p "hit enter to continue; type any key and hit enter stop" continue_flag
	
    done

    echo "doing flag-bandpass cal with interval = 1.0"

    #read -s -p "hit enter to continue; type any key and hit enter stop" continue_flag2
    for it__ in `seq 0 ${niter_flag_mfcal}`;
    do
	#if input is not blank, then exit loop
	#redundant
	if [ ! -z ${continue_flag2} ]; then
	    break
	fi
	
	flag_mfcal_auto 1.0

	#read -s -p "hit enter to continue; type any key and hit enter stop" continue_flag2
	
    done    

    return 0
}


flag_gpcal_primary() {

    interval=$1
    
    #auto-flag
    auto_flag ${pcal}
    spec_freq=$(printf %.1f "$((  10**3 * $( echo ${freq} ) / 1000 ))e-3")
    gpcal vis=${PROJ_DATA}/$pcal.${freq}${ifext} interval=${interval} options=xyvary minants=3 nfbin=${gpcal_nfbins} refant=$refant spec=${spec_freq}

    #check out primary cal data in real vs imag. This should look like a fat line that extends horizontally on the real axis, and is centered around 0 on the imaginary axis
    uvplt vis=${PROJ_DATA}/$pcal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav,nobase,equal device=/xs
    #stop and wait to continue
    read -p "Press enter to continue"

    #inspect per baseline
    uvplt vis=${PROJ_DATA}/$pcal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav nxy=5,3  device=/xs
    #stop and wait to continue
    read -p "Press enter to continue"
    
}

flag_gpcal_primary_auto() {

    interval=$1
    
    #auto-flag
    auto_flag ${pcal}
    spec_freq=$(printf %.1f "$((  10**3 * $( echo ${freq} ) / 1000 ))e-3")
    gpcal vis=${PROJ_DATA}/$pcal.${freq}${ifext} interval=${interval} options=xyvary minants=3 nfbin=${gpcal_nfbins} refant=$refant spec=${spec_freq}

    #check out primary cal data in real vs imag. This should look like a fat line that extends horizontally on the real axis, and is centered around 0 on the imaginary axis
    uvplt vis=${PROJ_DATA}/$pcal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav,nobase,equal device=/cps
    #stop and wait to continue
    #read -p "Press enter to continue"

    #inspect per baseline
    uvplt vis=${PROJ_DATA}/$pcal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav nxy=5,3  device=/cps
    #stop and wait to continue
    #read -p "Press enter to continue"
    
}


flag_gpcal_primary_sequence() {

    #set reference frequency in GHz for gpcal
    spec_freq=$(printf %.1f "$((  10**3 * $( echo ${freq} ) / 1000 ))e-3")
    
    gpcal vis=${PROJ_DATA}/$pcal.${freq}${ifext} interval=0.1 options=xyvary minants=3 nfbin=${gpcal_nfbins} refant=$refant spec=${spec_freq} 

    #check out primary cal data in real vs imag. This should look like a fat line that extends horizontally on the real axis, and is centered around 0 on the imaginary axis
    uvplt vis=${PROJ_DATA}/$pcal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav,nobase,equal device=/xs
    #stop and wait to continue
    read -p "Press enter to continue"

    #inspect per baseline
    uvplt vis=${PROJ_DATA}/$pcal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav nxy=5,3  device=/xs
    #stop and wait to continue
    read -p "Press enter to continue"
    
    read -s -p "hit enter to continue; type any key and hit enter stop" continue_flag
    while [[ -z ${continue_flag} ]]; do
	#if input is blank, then exit loop
	if [ ! -z ${continue_flag} ]; then
	    break
	fi
	
	flag_gpcal_primary 0.1

	read -s -p "hit enter to continue; type any key and hit enter stop" continue_flag
	
    done


    return 0
}


flag_gpcal_primary_sequence_auto() {


    niter_flag_gpcal=$1
    #set reference frequency in GHz for gpcal
    spec_freq=$(printf %.1f "$((  10**3 * $( echo ${freq} ) / 1000 ))e-3")
    
    gpcal vis=${PROJ_DATA}/$pcal.${freq}${ifext} interval=0.1 options=xyvary minants=3 nfbin=${gpcal_nfbins} refant=$refant spec=${spec_freq} 

    #check out primary cal data in real vs imag. This should look like a fat line that extends horizontally on the real axis, and is centered around 0 on the imaginary axis
    uvplt vis=${PROJ_DATA}/$pcal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav,nobase,equal device=/xs
    #stop and wait to continue
    #read -p "Press enter to continue"

    #inspect per baseline
    uvplt vis=${PROJ_DATA}/$pcal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav nxy=5,3  device=/xs
    #stop and wait to continue
    #read -p "Press enter to continue"
    for it__ in `seq 0 ${niter_flag_gpcal}`;
    do
	
	flag_gpcal_primary_auto 0.1

    done


    return 0
}



flag_gpcal_secondary() {

    auto_flag $scal
    
    #set reference frequency in GHz for gpcal
    spec_freq=$(printf %.1f "$((  10**3 * $( echo ${freq} ) / 1000 ))e-3")
    
    gpcal vis=${PROJ_DATA}/$scal.${freq}${ifext} interval=2 options="xyvary,qusolve,reset" minants=3 nfbin=${gpcal_nfbins} spec=${spec_freq} refant=$refant

    auto_flag $scal
    
    gpcal vis=${PROJ_DATA}/$scal.${freq}${ifext} interval=0.1 options="xyvary,qusolve,reset" minants=3 nfbin=${gpcal_nfbins} spec=${spec_freq} refant=$refant

    uvspec vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=chan,amp stokes=xx,yy device=/xs interval=9999 nxy=5,3
    read -p "Press enter to continue"
    #phase vs chan
    uvspec vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=chan,phase stokes=xx,yy device=/xs interval=9999 nxy=5,3
    read -p "Press enter to continue"
    #amp vs time
    uvplt vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=time,amp stokes=xx,yy device=/xs interval=9999 nxy=5,3
    read -p "Press enter to continue"
    #phase vs time
    uvplt vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=time,phase stokes=xx,yy device=/xs interval=9999 nxy=5,3
    read -p "Press enter to continue"

    #check out secondary cal data in real vs imag. This should look like a fat line that extends horizontally on the real axis, and is centered around 0 on the imaginary axis
    uvplt vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav,nobase,equal device=/xs
    #stop and wait to continue
    read -p "Press enter to continue"

    #inspect per baseline
    uvplt vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav nxy=5,3  device=/xs
    #stop and wait to continue
    read -p "Press enter to continue"

    return 0
}

flag_gpcal_secondary_auto() {

    auto_flag $scal
    
    #set reference frequency in GHz for gpcal
    spec_freq=$(printf %.1f "$((  10**3 * $( echo ${freq} ) / 1000 ))e-3")
    
    gpcal vis=${PROJ_DATA}/$scal.${freq}${ifext} interval=2 options="xyvary,qusolve,reset" minants=3 nfbin=${gpcal_nfbins} spec=${spec_freq} refant=$refant

    auto_flag $scal
    
    gpcal vis=${PROJ_DATA}/$scal.${freq}${ifext} interval=0.1 options="xyvary,qusolve,reset" minants=3 nfbin=${gpcal_nfbins} spec=${spec_freq} refant=$refant

    uvspec vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=chan,amp stokes=xx,yy device=/cps interval=9999 nxy=5,3

    uvspec vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=chan,phase stokes=xx,yy device=/cps interval=9999 nxy=5,3

    #amp vs time
    uvplt vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=time,amp stokes=xx,yy device=/cps interval=9999 nxy=5,3

    #phase vs time
    uvplt vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=time,phase stokes=xx,yy device=/cps interval=9999 nxy=5,3


    #check out secondary cal data in real vs imag. This should look like a fat line that extends horizontally on the real axis, and is centered around 0 on the imaginary axis
    uvplt vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav,nobase,equal device=/cps
    #stop and wait to continue

    #inspect per baseline
    uvplt vis=${PROJ_DATA}/$scal.${freq}${ifext} axis=real,imag stokes=xx,yy options=nofqav nxy=5,3  device=/cps
    #stop and wait to continue


    return 0
}

