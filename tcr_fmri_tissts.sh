#!/bin/bash

###################################################
# Project: tcr_fmri
# File: tcr_fmri_tissts.sh
# Author: Joe Whittaker (whittakerj3@cardiff.ac.uk)
#
# Analysis of Thigh-Cuff Release fMRI data using
# metric scripts. 
# 
###################################################

# Directories
dire=/cubric/data/sapjw12/TCR_BOLD/tcr_fmri # project folder
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
	clusterscript=${clustout}/x.${pid}.tcr_fmri_tissts_${crun}
	while [ -f ${clusterscript} ]
	do
	((crun++))
	clusterscript=${clustout}/x.${pid}.tcr_fmri_tissts_${crun}
	done

	;;

	"FALSE")

	tmpdir=`mktemp -d`
	clusterscript=${tmpdir}/x.${pid}.tcr_fmri_tissts

	;;
esac

# Begin analysis script
echo "#!/bin/bash" >> ${clusterscript}
# Source metric_miscfunc.sh inside script to use check_exe function
echo "source metric_miscfunc.sh" >> ${clusterscript}

piddir=${dire}/${pid}_new
standout=${piddir}/standard
anatout=${piddir}/anat
tcrout=${piddir}/tcr
glmout=${piddir}/glm

tissout=${piddir}/tiss_ts
check_dir ${tissout}

thr=0.95

gm=${anatout}/${pid}.anat.gm_pve.nii.gz
gmout=${tissout}/`basename ${gm%.*.*}`
wm=${anatout}/${pid}.anat.wm_pve.nii.gz
wmout=${tissout}/`basename ${wm%.*.*}`
csf=${anatout}/${pid}.anat.csf_pve.nii.gz
csfout=${tissout}/`basename ${csf%.*.*}`

refvol=${STDTPLDIR}/tpl-MNI152NLin2009cAsym_res-02_desc-brain_T1w.nii.gz
transformlist=(${anatout}/${pid}.anat.mni.1Warp.nii.gz ${anatout}/${pid}.anat.mni.0GenericAffine.mat)

exe="metric_normalise.sh -input ${gm} -prefix ${gmout} -ref ${refvol} -transform `echo ${transformlist[@]}`"
echo "check_exe ${gmout}.mni.nii.gz \"${exe}\"" >> ${clusterscript}

gm=${gmout}.mni.nii.gz
gmout=${tissout}/`basename ${gm%.*.*}`.thr.nii.gz
exe="${AFNIDIR}/3dcalc -a ${gm} -expr "step\(a-${thr}\)" -prefix ${gmout}"
echo "check_exe ${gmout} \"${exe}\"" >> ${clusterscript}


exe="metric_normalise.sh -input ${wm} -prefix ${wmout} -ref ${refvol} -transform `echo ${transformlist[@]}`"
echo "check_exe ${wmout}.mni.nii.gz \"${exe}\"" >> ${clusterscript}

wm=${wmout}.mni.nii.gz
wmout=${tissout}/`basename ${wm%.*.*}`.thr.nii.gz
exe="${AFNIDIR}/3dcalc -a ${wm} -expr "step\(a-${thr}\)" -prefix ${wmout}"
echo "check_exe ${wmout} \"${exe}\"" >> ${clusterscript}

for n in `seq 1 3`
do

wm=${wmout}
wmout=${tissout}/`basename ${wm%.*.*.*}`.ero${n}.nii.gz

exe="${AFNIDIR}/3dcalc -a ${wm} -b a+i -c a-i -d a+j -e a-j -f a+k -g a-k"
exe="${exe} -expr "a*\(1-amongst\(0,b,c,d,e,f,g\)\)" -prefix ${wmout}"
echo "check_exe ${wmout} \"${exe}\"" >> ${clusterscript}

done

wm1=${tissout}/${pid}.anat.wm_pve.mni.thr.nii.gz
wm2=${tissout}/${pid}.anat.wm_pve.mni.ero1.nii.gz
wmout=${tissout}/${pid}.anat.wm_super.nii.gz
exe="${AFNIDIR}/3dcalc -a ${wm1} -b ${wm2} -expr "a-b" -prefix ${wmout}"
echo "check_exe ${wmout} \"${exe}\"" >> ${clusterscript}

wm1=${tissout}/${pid}.anat.wm_pve.mni.ero1.nii.gz
wm2=${tissout}/${pid}.anat.wm_pve.mni.ero2.nii.gz
wmout=${tissout}/${pid}.anat.wm_mid1.nii.gz
exe="${AFNIDIR}/3dcalc -a ${wm1} -b ${wm2} -expr "a-b" -prefix ${wmout}"
echo "check_exe ${wmout} \"${exe}\"" >> ${clusterscript}

wm1=${tissout}/${pid}.anat.wm_pve.mni.ero2.nii.gz
wm2=${tissout}/${pid}.anat.wm_pve.mni.ero3.nii.gz
wmout=${tissout}/${pid}.anat.wm_mid2.nii.gz
exe="${AFNIDIR}/3dcalc -a ${wm1} -b ${wm2} -expr "a-b" -prefix ${wmout}"
echo "check_exe ${wmout} \"${exe}\"" >> ${clusterscript}

wm1=${tissout}/${pid}.anat.wm_pve.mni.ero3.nii.gz
wm2=${tissout}/${pid}.anat.wm_deep.nii.gz
exe="cp ${wm1} ${wm2}"
echo "check_exe ${wm2} \"${exe}\"" >> ${clusterscript}


exe="metric_normalise.sh -input ${csf} -prefix ${csfout} -ref ${refvol} -transform `echo ${transformlist[@]}`"
echo "check_exe ${csfout}.mni.nii.gz \"${exe}\"" >> ${clusterscript}

csf=${csfout}.mni.nii.gz
csfout=${tissout}/`basename ${csf%.*.*}`.thr.nii.gz
exe="${AFNIDIR}/3dcalc -a ${csf} -expr "step\(a-${thr}\)" -prefix ${csfout}"
echo "check_exe ${csfout} \"${exe}\"" >> ${clusterscript}


mset=${tissout}/${pid}.anat.gm_pve.mni.thr.nii.gz 
input=${tcrout}/${pid}.tcr.nii.gz
inputfit=${glmout}/${pid}.basis_fitts_psc.nii.gz
output=${tissout}/${pid}.tcr_gm.ts.1D
outputfit=${tissout}/${pid}.fit_gm.ts.1D
exe="${AFNIDIR}/3dmaskave -quiet -mask ${mset} ${input}"
echo "check_exe_out ${output} \"${exe}\" ${output}" >> ${clusterscript}
exe="${AFNIDIR}/3dmaskave -quiet -mask ${mset} ${inputfit}"
echo "check_exe_out ${outputfit} \"${exe}\" ${outputfit}" >> ${clusterscript}

mset=${tissout}/${pid}.anat.csf_pve.mni.thr.nii.gz 
output=${tissout}/${pid}.tcr_csf.ts.1D
outputfit=${tissout}/${pid}.fit_csf.ts.1D
exe="${AFNIDIR}/3dmaskave -quiet -mask ${mset} ${input}"
echo "check_exe_out ${output} \"${exe}\" ${output}" >> ${clusterscript}
exe="${AFNIDIR}/3dmaskave -quiet -mask ${mset} ${inputfit}"
echo "check_exe_out ${outputfit} \"${exe}\" ${outputfit}" >> ${clusterscript}

for mtype in super mid1 mid2 deep
do

mset=${tissout}/${pid}.anat.wm_${mtype}.nii.gz 
output=${tissout}/${pid}.tcr_wm_${mtype}.ts.1D
outputfit=${tissout}/${pid}.fit_wm_${mtype}.ts.1D
exe="${AFNIDIR}/3dmaskave -quiet -mask ${mset} ${input}"
echo "check_exe_out ${output} \"${exe}\" ${output}" >> ${clusterscript}
exe="${AFNIDIR}/3dmaskave -quiet -mask ${mset} ${inputfit}"
echo "check_exe_out ${outputfit} \"${exe}\" ${outputfit}" >> ${clusterscript}

done

### Execute script

case "$cluster_opt" in

	"TRUE")

	# Create cluster job
	echo "#!/bin/bash" >> ${clustout}/${pid}.tcr_fmri_tissts.cluster_job_${crun}
	echo "#SBATCH --job-name=${pid}.tcr_fmri_tissts_${crun}" >> ${clustout}/${pid}.tcr_fmri_tissts.cluster_job_${crun}
	echo "#SBATCH -p cubric-default" >> ${clustout}/${pid}.tcr_fmri_tissts.cluster_job_${crun}
	echo "#SBATCH --output ${clustout}/${pid}.tcr_fmri_tissts_${crun}_%j.out" >> ${clustout}/${pid}.tcr_fmri_tissts.cluster_job_${crun}
	echo "${clusterscript}" >> ${clustout}/${pid}.tcr_fmri_tissts.cluster_job_${crun}

	chmod +x ${clusterscript}
	printf "\nsending %s tcr_fmri_tissts job to the cluster..." "${pid}"
	sbatch ${clustout}/${pid}.tcr_fmri_tissts.cluster_job_${crun}
	sleep 2

	;;

	"FALSE")

	bash ${clusterscript}
	rm -rf $tmpdir
	
	;;
esac












