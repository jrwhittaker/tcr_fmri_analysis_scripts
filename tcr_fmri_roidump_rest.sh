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
	clusterscript=${clustout}/x.${pid}.tcr_fmri_roidump_rest_${crun}
	while [ -f ${clusterscript} ]
	do
	((crun++))
	clusterscript=${clustout}/x.${pid}.tcr_fmri_roidump_rest_${crun}
	done

	;;

	"FALSE")

	tmpdir=`mktemp -d`
	clusterscript=${tmpdir}/x.${pid}.tcr_fmri_roidump_rest

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
cleanout=${piddir}/clean
roiout=${piddir}/roidump

# Cortical ROIs
if [ ! -f ${roiout}/${pid}.rest_cortical_ts.1D ]
then
	for roi_val in `seq 1 48`
	do
		exe="${AFNIDIR}/3dmaskave -quiet -mask ${roiout}/killme_roi_cort_${roi_val}.nii.gz ${cleanout}/${pid}.rest_nowm.clean.nii.gz "
		echo "check_exe_out ${roiout}/killme_rest_roi_${roi_val}.1D \"${exe}\" ${roiout}/killme_rest_roi_${roi_val}.1D" >> ${clusterscript}

	done

	echo "check_exe_out ${roiout}/${pid}.rest_cortical_ts.1D \"paste \`ls ${roiout}/killme_rest_roi_*.1D\`\" ${roiout}/${pid}.rest_cortical_ts.1D" >> ${clusterscript}

fi

### Execute script

case "$cluster_opt" in

	"TRUE")

	# Create cluster job
	echo "#!/bin/bash" >> ${clustout}/${pid}.tcr_fmri_roidump_rest.cluster_job_${crun}
	echo "#SBATCH --job-name=${pid}.tcr_fmri_roidump_rest_${crun}" >> ${clustout}/${pid}.tcr_fmri_roidump_rest.cluster_job_${crun}
	echo "#SBATCH -p cubric-default" >> ${clustout}/${pid}.tcr_fmri_roidump_rest.cluster_job_${crun}
	echo "#SBATCH --output ${clustout}/${pid}.tcr_fmri_roidump_rest_${crun}_%j.out" >> ${clustout}/${pid}.tcr_fmri_roidump.cluster_job_${crun}
	echo "${clusterscript}" >> ${clustout}/${pid}.tcr_fmri_roidump_rest.cluster_job_${crun}

	chmod +x ${clusterscript}
	printf "\nsending %s tcr_fmri_roidump job to the cluster..." "${pid}"
	sbatch ${clustout}/${pid}.tcr_fmri_roidump_rest.cluster_job_${crun}
	sleep 2

	;;

	"FALSE")

	bash ${clusterscript}
	rm -rf $tmpdir
	
	;;
esac

