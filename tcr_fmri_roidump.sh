#!/bin/bash

###################################################
# Project: tcr_fmri
# File: tcr_fmri_roidump.sh
# Author: Joe Whittaker (whittakerj3@cardiff.ac.uk)
#
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
	clusterscript=${clustout}/x.${pid}.tcr_fmri_roidump_${crun}
	while [ -f ${clusterscript} ]
	do
	((crun++))
	clusterscript=${clustout}/x.${pid}.tcr_fmri_roidump_${crun}
	done

	;;

	"FALSE")

	tmpdir=`mktemp -d`
	clusterscript=${tmpdir}/x.${pid}.tcr_fmri_roidump

	;;
esac


# Begin analysis script
echo "#!/bin/bash" >> ${clusterscript}
# Source metric_miscfunc.sh inside script to use check_exe function
echo "source metric_miscfunc.sh" >> ${clusterscript}

piddir=${dire}/${pid}_new

tcrout=${piddir}/tcr
anatout=${piddir}/anat
glmout=${piddir}/glm

roiout=${piddir}/roidump
check_dir ${roiout}

TPLDIR=/home/sapjw12/code/metric/templates
cortical_atlas=${STDTPLDIR}/tpl-MNI152NLin2009cAsym_res-02_atlas-HOCPA_desc-th0_dseg.nii.gz
subcortical_atlas=${STDTPLDIR}/tpl-MNI152NLin2009cAsym_res-02_atlas-HOSPA_desc-th50_dseg.nii.gz

transform=(${anatout}/${pid}.anat.mni.1Warp.nii.gz ${anatout}/${pid}.anat.mni.0GenericAffine.mat)
refvol=${STDTPLDIR}/tpl-MNI152NLin2009cAsym_res-02_desc-brain_T1w.nii.gz

gm=${anatout}/${pid}.anat.gm_pve.nii.gz 

exe="metric_normalise.sh -input ${gm} -prefix ${roiout}/${pid}.gm_pve -ref ${refvol} -transform `echo ${transform[@]}`"
echo "check_exe ${roiout}/${pid}.gm_pve.mni.nii.gz \"${exe}\"" >> ${clusterscript}

# Cortical ROIs
if [ ! -f ${roiout}/${pid}.tcr_cortical_ts.1D ]
then
	for roi_val in `seq 1 48`
	do
		exe="${ANTSDIR}/ThresholdImage 3 ${cortical_atlas} ${roiout}/killme_roi_cort_${roi_val}.nii.gz ${roi_val} ${roi_val} 1 0"
		echo "check_exe ${roiout}/killme_roi_cort_${roi_val}.nii.gz \"${exe}\"" >> ${clusterscript}
		exe="${AFNIDIR}/3dcalc -a ${roiout}/${pid}.gm_pve.mni.nii.gz -b ${roiout}/killme_roi_cort_${roi_val}.nii.gz -expr "b*step\(a-0.66\)" -prefix ${roiout}/killme_roi_cort_${roi_val}_gm.nii.gz"
		echo "check_exe ${roiout}/killme_roi_cort_${roi_val}_gm.nii.gz \"${exe}\"" >> ${clusterscript}
		#exe="${AFNIDIR}/3dmaskave -quiet -mask ${roiout}/killme_roi_cort_${roi_val}_gm.nii.gz ${tcrout}/${pid}.tcr.nii.gz"
		#echo "check_exe_out ${roiout}/killme_tcr_roi_${roi_val}.1D \"${exe}\" ${roiout}/killme_tcr_roi_${roi_val}.1D" >> ${clusterscript}
		exe="${AFNIDIR}/3dmaskave -quiet -mask ${roiout}/killme_roi_cort_${roi_val}.nii.gz ${tcrout}/${pid}.tcr.nii.gz"
		echo "check_exe_out ${roiout}/killme_tcr_roi_${roi_val}.1D \"${exe}\" ${roiout}/killme_tcr_roi_${roi_val}.1D" >> ${clusterscript}
		exe="${AFNIDIR}/3dmaskave -quiet -mask ${roiout}/killme_roi_cort_${roi_val}.nii.gz ${glmout}/${pid}.basis_fitts_psc.nii.gz"
		echo "check_exe_out ${roiout}/killme_fit_roi_${roi_val}.1D \"${exe}\" ${roiout}/killme_fit_roi_${roi_val}.1D" >> ${clusterscript}
	done
	echo "check_exe_out ${roiout}/${pid}.tcr_cortical_ts.1D \"paste \`ls ${roiout}/killme_tcr_roi_*.1D\`\" ${roiout}/${pid}.tcr_cortical_ts.1D" >> ${clusterscript}
	echo "check_exe_out ${roiout}/${pid}/fit_cortical_ts.1D \"paste \`ls ${roiout}/killme_fit_roi_*.1D\`\" ${roiout}/${pid}.fit_cortical_ts.1D" >> ${clusterscript}
	echo "rm ${roiout}/killme*" >> ${clusterscript}
fi	

### Execute script

case "$cluster_opt" in

	"TRUE")

	# Create cluster job
	echo "#!/bin/bash" >> ${clustout}/${pid}.tcr_fmri_roidump.cluster_job_${crun}
	echo "#SBATCH --job-name=${pid}.tcr_fmri_roidump_${crun}" >> ${clustout}/${pid}.tcr_fmri_roidump.cluster_job_${crun}
	echo "#SBATCH -p cubric-default" >> ${clustout}/${pid}.tcr_fmri_roidump.cluster_job_${crun}
	echo "#SBATCH --output ${clustout}/${pid}.tcr_fmri_roidump_${crun}_%j.out" >> ${clustout}/${pid}.tcr_fmri_roidump.cluster_job_${crun}
	echo "${clusterscript}" >> ${clustout}/${pid}.tcr_fmri_roidump.cluster_job_${crun}

	chmod +x ${clusterscript}
	printf "\nsending %s tcr_fmri_roidump job to the cluster..." "${pid}"
	sbatch ${clustout}/${pid}.tcr_fmri_roidump.cluster_job_${crun}
	sleep 2

	;;

	"FALSE")

	bash ${clusterscript}
	rm -rf $tmpdir
	
	;;
esac





