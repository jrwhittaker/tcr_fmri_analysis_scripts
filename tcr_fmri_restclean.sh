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
	clusterscript=${clustout}/x.${pid}.tcr_fmri_restclean_${crun}
	while [ -f ${clusterscript} ]
	do
	((crun++))
	clusterscript=${clustout}/x.${pid}.tcr_fmri_restclean_${crun}
	done

	;;

	"FALSE")

	tmpdir=`mktemp -d`
	clusterscript=${tmpdir}/x.${pid}.tcr_fmri_restclean

	;;
esac

# Begin analysis script
echo "#!/bin/bash" >> ${clusterscript}
# Source metric_miscfunc.sh inside script to use check_exe function
echo "source metric_miscfunc.sh" >> ${clusterscript}

piddir=${dire}/${pid}_new
rawout=${piddir}/raw

volregout=${piddir}/volreg
standout=${piddir}/standard
cleanout=${piddir}/clean
gslagout=${piddir}/gslag

mset=${STDTPLDIR}/fMRIPrep_boldref_automask.nii.gz

exe="metric_clean_filter.sh -input ${standout}/${pid}.rest.mni.nii.gz -prefix ${cleanout}/${pid}.rest_nowm"
exe="${exe} -regress ${volregout}/${pid}.rest.motion_demean.1D ${cleanout}/${pid}.rest_csf.1D"
exe="${exe} -bandpass 0.01 0.1 -mask ${mset}"
echo "check_exe ${cleanout}/${pid}.rest_nowm.clean.nii.gz \"${exe}\"" >> ${clusterscript}


# Extract global signal

exe="${AFNIDIR}/3dmaskave -quiet -mask ${mset} ${cleanout}/${pid}.rest_nowm.clean.nii.gz"
echo "check_exe_out ${gslagout}/${pid}.rest_nowm.gs.1D \"${exe}\" ${gslagout}/${pid}.rest_nowm.gs.1D" >> ${clusterscript}


# Make global signal lag matrix
exe="${dire}/MakeGSLagFile.R --input=${gslagout}/${pid}.rest_nowm.gs.1D --prefix=${gslagout}/${pid}.rest_nowm"
echo "check_exe ${gslagout}/${pid}.rest_nowm.gs_lagmatrix.1D \"${exe}\"" >> ${clusterscript}


# tcat nifti file
exe="${AFNIDIR}/3dTcat -prefix ${gslagout}/${pid}.rest_nowm.tcat.nii.gz ${cleanout}/${pid}.rest_nowm.clean.nii.gz\"[11..590]\""
echo "check_exe ${gslagout}/${pid}.rest_nowm.tcat.nii.gz \"${exe}\"" >> ${clusterscript}


# Voxelwise correlation
voxcordir=/home/sapjw12/code/voxel_crosscorr
exe="${voxcordir}/VoxelCrossCorr -input ${gslagout}/${pid}.rest_nowm.tcat.nii.gz -prefix ${gslagout}/${pid}.rest_nowm"
exe="${exe} -mask ${mset} -lagfile ${gslagout}/${pid}.rest_nowm.gs_lagmatrix.1D"
echo "check_exe ${gslagout}/${pid}.rest_nowm.cc.nii.gz \"${exe}\"" >> ${clusterscript}


### Execute script

if [ 1 -eq 1 ]
then

case "$cluster_opt" in

	"TRUE")

	# Create cluster job
	echo "#!/bin/bash" >> ${clustout}/${pid}.tcr_fmri_restclean.cluster_job_${crun}
	echo "#SBATCH --job-name=${pid}.tcr_fmri_restclean_${crun}" >> ${clustout}/${pid}.tcr_fmri_restclean.cluster_job_${crun}
	echo "#SBATCH -p cubric-default" >> ${clustout}/${pid}.tcr_fmri_restclean.cluster_job_${crun}
	echo "#SBATCH --output ${clustout}/${pid}.tcr_fmri_restclean_${crun}_%j.out" >> ${clustout}/${pid}.tcr_fmri_restclean.cluster_job_${crun}
	echo "${clusterscript}" >> ${clustout}/${pid}.tcr_fmri_restclean.cluster_job_${crun}

	chmod +x ${clusterscript}
	printf "\nsending %s tcr_fmri_restclean job to the cluster..." "${pid}"
	sbatch ${clustout}/${pid}.tcr_fmri_restclean.cluster_job_${crun}
	sleep 2

	;;

	"FALSE")

	bash ${clusterscript}
	rm -rf $tmpdir
	
	;;
esac

fi
















