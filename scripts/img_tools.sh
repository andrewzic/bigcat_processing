#!/bin/bash

#import variables from config
source ./config.sh

dirty_image() {

    data=$1
    stokes=$2
    
    invert vis=${PROJ_DATA}/${data} map=${PROJ_DATA}/${data}.b${robust}.${stokes}map beam=${PROJ_DATA}/${data}.b${robust}.${stokes}beam  robust=${robust} stokes=${stokes} options=mfs,sdb imsize=${pb_imsize},${pb_imsize},beam

    fits in=${PROJ_DATA}/${data}.b${robust}.${stokes}map op=xyout out=${PROJ_DATA}/${data}.${stokes}.b${robust}.dirty.fits

    return 0
}

cgcurs_map() {

    data=$1
    stokes=$2
    
    cgcurs in=${data}.b${robust}.${stokes}map type=p range=0,0,log device=/xs labtyp=hms,dms options=region "region=perc(30)"
    mv cgcurs.region ${target}_inner.${freq}.region
    cgcurs in=${data}.b${robust}.${stokes}map type=p range=0,0,log device=/xs labtyp=hms,dms options=region

    cat ${target}_inner.${freq}.region > ${target}_map.${freq}.region
    cat cgcurs.region >> ${target}_map.${freq}.region
    return 0

}

clean_map() {

    data=$1
    stokes=$2
    
    mfclean map=${data}.b${robust}.${stokes}map beam=${data}.b${robust}.${stokes}beam out=${data}.b${robust}.${stokes}model cutoff=${clean_thresh} niters=${clean_niters} region=@${target}_map.${freq}.region

    restor model=${data}.b${robust}.${stokes}model beam=${data}.b${robust}.${stokes}beam map=${data}.b${robust}.${stokes}map out=${data}.b${robust}.${stokes}restor
    
    fits in=${data}.b${robust}.${stokes}restor op=xyout out=$target.${freq}.b${robust}.${stokes}.fits
    
    restor model=${data}.b${robust}.${stokes}model beam=${data}.b${robust}.${stokes}beam map=${data}.b${robust}.${stokes}map mode=residual out=${data}.b${robust}.${stokes}resid

    fits in=${data}.b${robust}.${stokes}resid op=xyout out=$target.${freq}.b${robust}.${stokes}resid.fits

    return 0
}

selfcal_phase_initial() {

    scdata=$1
    data=$2
    stokes=i
    
    cd ${PROJ_ROOT}
    datadir="./data/"
    imgdir="./img/"
    
    selfcal vis=${datadir}/${scdata} model=${imgdir}${data}.b${robust}.${stokes}model interval=2 clip=0.0004 options=phase,mfs

    invert vis=${datadir}/${scdata} map=${imgdir}${scdata}.b${robust}.imap beam=${imgdir}${scdata}.b${robust}.ibeam robust=${robust} stokes=i options=mfs,sdb imsize=${pb_imsize},${pb_imsize},beam

    mfclean map=${imgdir}${scdata}.b${robust}.imap beam=${imgdir}${scdata}.b${robust}.ibeam out=${imgdir}${scdata}.b${robust}.imodel cutoff=${clean_thresh} niters=${clean_niters} region=@${imgdir}/${target}_map.${freq}.region

    restor model=${imgdir}${scdata}.b${robust}.imodel beam=${imgdir}${scdata}.b${robust}.ibeam map=${imgdir}${scdata}.b${robust}.imap out=${imgdir}${scdata}.b${robust}.irestor
    
    fits in=${imgdir}${scdata}.b${robust}.irestor op=xyout out=${imgdir}${scdata}.b${robust}.i.fits
    cd ${PROJ_IMG}
    return 0
}



selfcal_phase() {

    data=$1
    model=$2

    cd ${PROJ_ROOT}
    datadir="./data/"
    imgdir="./img/"
    
    selfcal vis=${datadir}/${data} model=${model} interval=2 clip=0.0004 options=phase,mfs

    invert vis=${datadir}/${data} map=${imgdir}${data}.imap beam=${imgdir}${data}.ibeam robust=${robust} stokes=i options=mfs,sdb imsize=${pb_imsize},${pb_imsize},beam

    mfclean map=${imgdir}${data}.imap beam=${imgdir}${data}.ibeam out=${imgdir}${data}.imodel cutoff=${clean_thresh} niters=${clean_niters} region=@${imgdir}/${target}_map.${freq}.region

    restor model=${imgdir}${data}.imodel beam=${imgdir}${data}.ibeam map=${imgdir}${data}.imap out=${imgdir}${data}.irestor
    
    fits in=${imgdir}${data}.irestor op=xyout out=${imgdir}${data}.i.fits
    cd ${PROJ_IMG}
    return 0
}


selfcal_phase_sequence() {

    data=$1
    old_data=${data}
    iter=0
    scdata=${data}.selfcal${iter}
    echo ${scdata}
    cp -r ${PROJ_DATA}/${data} ${PROJ_DATA}/${scdata}
    echo "successfully copied ${PROJ_DATA}/${data} ${PROJ_DATA}/${scdata}"

    selfcal_phase_initial ${scdata} ${data}

    #iter=1
    scdata_old=${data}.selfcal0
    while read continue_flag; do
	echo "Type any key and hit enter to continue; enter a blank to stop"
	#if input is blank, then exit loop
	
	if [ ! -z ${continue_flag} ]; then
	    break
	fi
	echo ${iter}
	model=${imgdir}${scdata_old}.imodel
	echo ${model}
	selfcal_phase ${scdata} ${model}

	kvis ${scdata}.b${robust}.i.fits

	scdata_old=${old_data}.selfcal${iter}
	((iter++))
	echo ${iter}
	cp -r ${PROJ_DATA}/${scdata}.b${robust} ${PROJ_DATA}/${old_data}.selfcal${iter}
	scdata=${old_data}.selfcal${iter}
	
    done
    read -s -p "hit enter to continue; type any key and hit enter stop" continue_flag

    return 0
}

uvmodel_mfs() {

    data=$1
    model=$2
    uvmodel vis=${PROJ_DATA}/${data} model=${model} out=${PROJ_DATA}/${data}.uvsub options="subtract,mfs"

    return 0
    
}


phaseshift() {

    data=$1
    ra=$2
    dec=$3
    uvedit vis=${PROJ_DATA}/${data} ra=${ra} dec=${dec} out=${PROJ_DATA}/${data}.ps

    return 0
    
}
