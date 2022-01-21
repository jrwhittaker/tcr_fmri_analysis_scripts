#!/bin/bash

###################################################
# Project: tcr_fmri
# File: tcr_fmri_gslag.sh
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
	clusterscript=${clustout}/x.${pid}.tcr_fmri_gslag_${crun}
	while [ -f ${clusterscript} ]
	do
	((crun++))
	clusterscript=${clustout}/x.${pid}.tcr_fmri_gslag_${crun}
	done

	;;

	"FALSE")

	tmpdir=`mktemp -d`
	clusterscript=${tmpdir}/x.${pid}.tcr_fmri_gslag

	;;
esac

piddir=${dire}/${pid}_new
cleanout=${piddir}/clean
tcrout=${piddir}/tcr

# Begin analysis script
echo "#!/bin/bash" >> ${clusterscript}
# Source metric_miscfunc.sh inside script to use check_exe function
echo "source metric_miscfunc.sh" >> ${clusterscript}

gslagout=${piddir}/gslag
check_dir ${gslagout}


# Extract global signal
mset=${STDTPLDIR}/fMRIPrep_boldref_automask.nii.gz

exe="${AFNIDIR}/3dmaskave -quiet -mask ${mset} ${cleanout}/${pid}.rest.clean.nii.gz"
echo "check_exe_out ${gslagout}/${pid}.rest.gs.1D \"${exe}\" ${gslagout}/${pid}.rest.gs.1D" >> ${clusterscript}

exe="${AFNIDIR}/3dmaskave -quiet -mask ${mset} ${tcrout}/${pid}.tcr.nii.gz"
echo "check_exe_out ${gslagout}/${pid}.tcr.gs.1D \"${exe}\" ${gslagout}/${pid}.tcr.gs.1D" >> ${clusterscript}


# Make global signal lag matrix
exe="${dire}/MakeGSLagFile.R --input=${gslagout}/${pid}.rest.gs.1D --prefix=${gslagout}/${pid}.rest"
echo "check_exe ${gslagout}/${pid}.rest.gs_lagmatrix.1D \"${exe}\"" >> ${clusterscript}

exe="${dire}/MakeGSLagFile.R --input=${gslagout}/${pid}.tcr.gs.1D --prefix=${gslagout}/${pid}.tcr"
echo "check_exe ${gslagout}/${pid}.tcr.gs_lagmatrix.1D \"${exe}\"" >> ${clusterscript}


# tcat nifti file
exe="${AFNIDIR}/3dTcat -prefix ${gslagout}/${pid}.rest.tcat.nii.gz ${cleanout}/${pid}.rest.clean.nii.gz\"[11..590]\""
echo "check_exe ${gslagout}/${pid}.rest.tcat.nii.gz \"${exe}\"" >> ${clusterscript}

tcrnt=`${AFNIDIR}/3dnvals ${tcrout}/${pid}.tcr.nii.gz`
tcrnt=`echo "${tcrnt} - 10" | bc`
exe="${AFNIDIR}/3dTcat -prefix ${gslagout}/${pid}.tcr.tcat.nii.gz ${tcrout}/${pid}.tcr.nii.gz\"[11..${tcrnt}]\""
echo "check_exe ${gslagout}/${pid}.tcr.tcat.nii.gz \"${exe}\"" >> ${clusterscript}


# Voxelwise correlation
voxcordir=/home/sapjw12/code/voxel_crosscorr
exe="${voxcordir}/VoxelCrossCorr -input ${gslagout}/${pid}.rest.tcat.nii.gz -prefix ${gslagout}/${pid}.rest"
exe="${exe} -mask ${mset} -lagfile ${gslagout}/${pid}.rest.gs_lagmatrix.1D"
echo "check_exe ${gslagout}/${pid}.rest.cc.nii.gz \"${exe}\"" >> ${clusterscript}

exe="${voxcordir}/VoxelCrossCorr -input ${gslagout}/${pid}.tcr.tcat.nii.gz -prefix ${gslagout}/${pid}.tcr"
exe="${exe} -mask ${mset} -lagfile ${gslagout}/${pid}.tcr.gs_lagmatrix.1D"
echo "check_exe ${gslagout}/${pid}.tcr.cc.nii.gz \"${exe}\"" >> ${clusterscript}


### Execute script

case "$cluster_opt" in

	"TRUE")

	# Create cluster job
	echo "#!/bin/bash" >> ${clustout}/${pid}.tcr_fmri_gslag.cluster_job_${crun}
	echo "#SBATCH --job-name=${pid}.tcr_fmri_gslag_${crun}" >> ${clustout}/${pid}.tcr_fmri_gslag.cluster_job_${crun}
	echo "#SBATCH -p cubric-default" >> ${clustout}/${pid}.tcr_fmri_gslag.cluster_job_${crun}
	echo "#SBATCH --output ${clustout}/${pid}.tcr_fmri_gslag_${crun}_%j.out" >> ${clustout}/${pid}.tcr_fmri_gslag.cluster_job_${crun}
	echo "${clusterscript}" >> ${clustout}/${pid}.tcr_fmri_gslag.cluster_job_${crun}

	chmod +x ${clusterscript}
	printf "\nsending %s tcr_fmri_gslag job to the cluster..." "${pid}"
	sbatch ${clustout}/${pid}.tcr_fmri_gslag.cluster_job_${crun}
	sleep 2

	;;

	"FALSE")

	bash ${clusterscript}
	rm -rf $tmpdir
	
	;;
esac











