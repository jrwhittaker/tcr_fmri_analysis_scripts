#!/bin/bash

###################################################
# Project: tcr_fmri
# File: tcr_fmri_preproc.sh
# Author: Joe Whittaker (whittakerj3@cardiff.ac.uk)
#
# Analysis of Thigh-Cuff Release fMRI data using
# metric scripts. 
# 
###################################################

# Directories
dire=/cubric/data/sapjw12/TCR_BOLD/tcr_fmri # project folder
retrodir=${dire}/retrofiles # retroicor regressors folder
clustdir=${dire}/cluster

# Source config and miscfunc metric files
source metric_config.sh
source metric_miscfunc.sh

### Compulsory arguments

pid=`get_arg "-pid" "$@"`
check_arg -pid $pid

### Options
cluster_opt=`exist_opt "-cluster" "$@"`

case "$cluster_opt" in

	"TRUE")

	if [ ! -d ${clustdir}/${pid} ]
	then
	mkdir ${clustdir}/${pid}
	fi
	clustout=${clustdir}/${pid}

	crun=0
	clusterscript=${clustout}/x.${pid}.tcr_fmri_preproc_${crun}
	while [ -f ${clusterscript} ]
	do
	((crun++))
	clusterscript=${clustout}/x.${pid}.tcr_fmri_preproc_${crun}
	done

	;;

	"FALSE")

	tmpdir=`mktemp -d`
	clusterscript=${tmpdir}/x.${pid}.tcr_fmri_preproc

	;;
esac

# Begin analysis script
echo "#!/bin/bash" >> ${clusterscript}
# Source metric_miscfunc.sh inside script to use check_exe function
echo "source metric_miscfunc.sh" >> ${clusterscript}

piddir=${dire}/${pid}_new
rawout=${piddir}/raw


## 1
# Process T1-weighted structural data

anatout=${piddir}/anat
check_dir ${anatout}

echo "printf \"\\n\\t...T1 processing\\n\"" >> ${clusterscript}
echo "check_exe ${anatout}/${pid}.anat.mni.Warped.nii.gz \"metric_antsprocess_t1.sh -input ${rawout}/${pid}.mprage.raw.nii.gz -prefix ${anatout}/${pid}.anat\"" >> ${clusterscript}

## 2
# Motion correct functional data

volregout=${piddir}/volreg
check_dir ${volregout}

echo "printf \"\\n\t...Motion correction\\n\"" >> ${clusterscript}

inputlist=(${rawout}/${pid}.rest.raw.nii.gz)
prefixlist=(${volregout}/${pid}.rest)
for irep in `ls ${rawout}/${pid}.tcr_rep*.raw.nii.gz`
do
inputlist=(${inputlist[@]} ${irep})
prep=`basename ${irep}`
prefixlist=(${prefixlist[@]} ${volregout}/${prep%.*.*.*})
done

echo "check_exe ${prefixlist[0]}.volreg.nii.gz \"metric_motion_correct.sh -input ${inputlist[@]} -prefix ${prefixlist[@]} -despike\"" >> ${clusterscript}

## 3
# RETROICOR correct functional data

retroout=${piddir}/retro
check_dir ${retroout}

echo "printf \"\\n\t...RETROICOR correction\\n\"" >> ${clusterscript}

inputlist=(${volregout}/${pid}.rest.volreg.nii.gz)
prefixlist=(${retroout}/${pid}.rest)

for irep in `ls ${rawout}/${pid}.tcr_rep*.raw.nii.gz`
do
iname=`basename ${irep%.*.*.*}`
inputlist=(${inputlist[@]} ${volregout}/${iname}.volreg.nii.gz)
prefixlist=(${prefixlist[@]} ${retroout}/${iname})
done

ninps=${#inputlist[@]}
nreps=`echo "${ninps} - 1" | bc`
for rep in `seq 0 ${nreps}`
do
input=${inputlist[${rep}]}
prefix=${prefixlist[${rep}]}
strmatch=`basename ${input%.*.*.*}`
strmatch=${strmatch##*.}
retrofilelist=(`ls ${retrodir}/${pid}/${pid}.${strmatch}*`)
if [ -z "${retrofilelist}" ]
then
echo "check_exe ${prefix}.retrocorrect.nii.gz \"cp ${input} ${prefix}.retrocorrect.nii.gz\"" >> ${clusterscript}
else
echo "check_exe ${prefix}.retrocorrect.nii.gz \"metric_retroicor_correct.sh -input ${input} -prefix ${prefix} -retrofiles ${retrofilelist[@]} -mbfactor 4 \"" >> ${clusterscript}
fi
done

## 4
# Make BOLD reference images for coregistration

boldrefout=${piddir}/boldref
check_dir ${boldrefout}

# AP image
echo "printf \"\\n\t...BOLD ref images\\n\"" >> ${clusterscript}
echo "check_exe ${boldrefout}/${pid}.ap.boldref.nii.gz \"metric_boldref.sh -input ${volregout}/volreg_finaltarget.nii.gz -prefix ${boldrefout}/${pid}.ap\"" >> ${clusterscript}

# PA image (combine the two different PA images)
exe="${AFNIDIR}/3dTcat -prefix ${boldrefout}/${pid}.pa.raw.nii.gz ${rawout}/${pid}.rest_pa.raw.nii.gz ${rawout}/${pid}.tcr_pa.raw.nii.gz"
echo "check_exe ${boldrefout}/${pid}.pa.boldref.nii.gz \"${exe}\"" >> ${clusterscript}
echo "check_exe ${boldrefout}/${pid}.pa.boldref.nii.gz \"metric_motion_correct.sh -input ${boldrefout}/${pid}.pa.raw.nii.gz -prefix ${boldrefout}/${pid}.pa\"" >> ${clusterscript}
echo "check_exe ${boldrefout}/${pid}.pa.boldref.nii.gz \"metric_boldref.sh -input ${boldrefout}/volreg_finaltarget.nii.gz -prefix ${boldrefout}/${pid}.pa\"" >> ${clusterscript}

echo "cleanlist=(${boldrefout}/${pid}.pa.volreg* ${boldrefout}/${pid}.pa.raw.nii.gz ${boldrefout}/volreg_finaltarget.nii.gz)" >> ${clusterscript}
echo "for f in \${cleanlist[@]}; do cleanup \$f; done" >> ${clusterscript}

## 5
# Susceptibility distortion correction

sdcout=${piddir}/sdc
check_dir ${sdcout}

echo "printf \"\\n\t...correct susceptibility distortions\\n\"" >> ${clusterscript}
echo "check_exe ${sdcout}/${pid}.sdc.nii.gz \"metric_sdc_qwarp.sh -ap ${boldrefout}/${pid}.ap.boldref.nii.gz -pa ${boldrefout}/${pid}.pa.boldref.nii.gz -prefix ${sdcout}/${pid}\"" >> ${clusterscript}

## 6
# Coregister SDC EPI to T1-weighted image with BBR

coregout=${piddir}/coreg
check_dir ${coregout}

echo "printf \"\\n\t...functional and structural coregistration\\n\"" >> ${clusterscript}
exe="metric_coregistration_bbr.sh -epi ${sdcout}/${pid}.sdc.nii.gz -t1 ${anatout}/${pid}.anat.nii.gz"
exe="${exe} -t1_brain ${anatout}/${pid}.anat.brain.nii.gz -prefix ${coregout}/${pid}.bbr -itk"
echo "check_exe ${coregout}/${pid}.bbr.nii.gz \"${exe}\"" >> ${clusterscript}

## 7
# Apply all transformations to functional data

standout=${piddir}/standard
check_dir ${standout}

echo "printf \"\\n\t...MNI normalisation\\n\"" >> ${clusterscript}

inputlist=(${retroout}/${pid}.rest.retrocorrect.nii.gz)
prefixlist=(${standout}/${pid}.rest)
for irep in `ls ${rawout}/${pid}.tcr_rep*.raw.nii.gz`
do
iname=`basename ${irep%.*.*.*}`
inputlist=(${inputlist[@]} ${retroout}/${iname}.retrocorrect.nii.gz)
prefixlist=(${prefixlist[@]} ${standout}/${iname})
done
transformlist=(${anatout}/${pid}.anat.mni.1Warp.nii.gz ${anatout}/${pid}.anat.mni.0GenericAffine.mat ${coregout}/${pid}.bbr_itk.mat)
refvol=${STDTPLDIR}/tpl-MNI152NLin2009cAsym_res-02_desc-brain_T1w.nii.gz

exe="metric_normalise.sh -input ${inputlist[@]} -prefix ${prefixlist[@]} -sdc ${sdcout}/${pid}.sdc_warp.nii.gz -ref ${refvol} -transform ${transformlist[@]} -ts"
echo "check_exe ${prefixlist[0]}.mni.nii.gz \"${exe}\"" >> ${clusterscript}

## 8
# Clean and filter data

cleanout=${piddir}/clean
check_dir ${cleanout}

# Create ANATICOR regressors
inputlist=(${standout}/${pid}.rest.mni.nii.gz)
prefixlist=(${cleanout}/${pid}.rest)
for irep in `ls ${rawout}/${pid}.tcr_rep*.raw.nii.gz`
do
iname=`basename ${irep%.*.*.*}`
inputlist=(${inputlist[@]} ${standout}/${iname}.mni.nii.gz)
prefixlist=(${prefixlist[@]} ${cleanout}/${iname})
done

exe="metric_anaticor_regressors.sh -input ${inputlist[@]} -prefix ${prefixlist[@]}"
exe="${exe} -csf ${anatout}/${pid}.anat.csf.nii.gz -wm ${anatout}/${pid}.anat.wm.nii.gz"
exe="${exe} -ref ${refvol} -transform ${anatout}/${pid}.anat.mni.1Warp.nii.gz ${anatout}/${pid}.anat.mni.0GenericAffine.mat -localwm -tplmask"
echo "check_exe ${cleanout}/${pid}.rest.local_wm.nii.gz \"${exe}\"" >> ${clusterscript}

mset=${STDTPLDIR}/fMRIPrep_boldref_automask.nii.gz

exe="metric_clean_filter.sh -input ${standout}/${pid}.rest.mni.nii.gz -prefix ${cleanout}/${pid}.rest"
exe="${exe} -regress ${volregout}/${pid}.rest.motion_demean.1D ${cleanout}/${pid}.rest_csf.1D"
exe="${exe} -voxel_regress ${cleanout}/${pid}.rest.local_wm.nii.gz -bandpass 0.01 0.1 -mask ${mset}"
echo "check_exe ${cleanout}/${pid}.rest.clean.nii.gz \"${exe}\"" >> ${clusterscript}

for irep in `ls ${rawout}/${pid}.tcr_rep*.raw.nii.gz`
do
iname=`basename ${irep%.*.*.*}`
inp=${standout}/${iname}.mni.nii.gz
exe="metric_clean_filter.sh -input ${inp} -prefix ${cleanout}/${iname}"
exe="${exe} -regress ${volregout}/${iname}.motion_demean.1D ${cleanout}/${iname}_csf.1D -mask ${mset}"
#exe="${exe} -voxel_regress ${cleanout}/${iname}.local_wm.nii.gz"
echo "check_exe ${cleanout}/${iname}.nii.gz \"${exe}\"" >> ${clusterscript}
done

## 9
# Average together TCR repeats

tcrout=${piddir}/tcr
check_dir ${tcrout}

echo "check_exe ${tcrout}/${pid}.tcr.nii.gz \"${AFNIDIR}/3dMean -prefix ${tcrout}/${pid}.tcr.nii.gz ${cleanout}/${pid}.tcr_rep*clean.nii.gz\"" >> ${clusterscript}


### Execute script

if [ 1 -eq 1 ]
then

case "$cluster_opt" in

	"TRUE")

	# Create cluster job
	echo "#!/bin/bash" >> ${clustout}/${pid}.tcr_fmri_preproc.cluster_job_${crun}
	echo "#SBATCH --job-name=${pid}.tcr_fmri_preproc_${crun}" >> ${clustout}/${pid}.tcr_fmri_preproc.cluster_job_${crun}
	echo "#SBATCH -p cubric-default" >> ${clustout}/${pid}.tcr_fmri_preproc.cluster_job_${crun}
	echo "#SBATCH --output ${clustout}/${pid}.tcr_fmri_preproc_${crun}_%j.out" >> ${clustout}/${pid}.tcr_fmri_preproc.cluster_job_${crun}
	echo "${clusterscript}" >> ${clustout}/${pid}.tcr_fmri_preproc.cluster_job_${crun}

	chmod +x ${clusterscript}
	printf "\nsending %s tcr_fmri_preproc job to the cluster..." "${pid}"
	sbatch ${clustout}/${pid}.tcr_fmri_preproc.cluster_job_${crun}
	sleep 2

	;;

	"FALSE")

	bash ${clusterscript}
	rm -rf $tmpdir
	
	;;
esac

fi










