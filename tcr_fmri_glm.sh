#!/bin/bash

###################################################
# Project: tcr_fmri
# File: tcr_fmri_glm.sh
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
	clusterscript=${clustout}/x.${pid}.tcr_fmri_glm_${crun}
	while [ -f ${clusterscript} ]
	do
	((crun++))
	clusterscript=${clustout}/x.${pid}.tcr_fmri_glm_${crun}
	done

	;;

	"FALSE")

	tmpdir=`mktemp -d`
	clusterscript=${tmpdir}/x.${pid}.tcr_fmri_glm

	;;
esac

# Begin analysis script
echo "#!/bin/bash" >> ${clusterscript}
# Source metric_miscfunc.sh inside script to use check_exe function
echo "source metric_miscfunc.sh" >> ${clusterscript}

piddir=${dire}/${pid}_new
standout=${piddir}/standard
cleanout=${piddir}/clean
volregout=${piddir}/volreg

glmout=${piddir}/glm
check_dir ${glmout}

scanlist=()
for scan in `ls ${standout}/${pid}.tcr_rep*.nii.gz`
do

scanlist=(${scanlist[@]} ${scan})

iname=`basename ${scan%.*.*.*}`
exe="nt=`${AFNIDIR}/3dinfo -nt ${scan}`"
echo "${exe}" >> ${clusterscript}

exe="${AFNIDIR}/1d_tool.py -infile ${cleanout}/${iname}_csf.1D -demean -write ${glmout}/${iname}.csf_demean.1D"
echo "check_exe ${glmout}/${iname}.csf_demean.1D \"${exe}\"" >> ${clusterscript}

exe="cat ${glmout}/${iname}.csf_demean.1D >> ${glmout}/${pid}.csf_demean.1D"
echo "${exe}" >> ${clusterscript}

exe="cat ${volregout}/${iname}.motion_demean.1D >> ${glmout}/${pid}.motion_demean.1D"
echo "${exe}" >> ${clusterscript}

exe="cat ${dire}/new_custom_basis_set_\${nt}.1D >> ${glmout}/custom_basis_set.1D"
echo "${exe}" >> ${clusterscript}

done

exe="${AFNIDIR}/3dDeconvolve -input ${scanlist[@]}"
exe="${exe} -mask ${STDTPLDIR}/fMRIPrep_boldref_automask.nii.gz -polort 2 -num_stimts 5 -bout"
exe="${exe} -stim_file 1 ${glmout}/${pid}.csf_demean.1D -stim_label 1 csf"
exe="${exe} -stim_file 2 ${glmout}/custom_basis_set.1D'[0]' -stim_label 2 basis1"
exe="${exe} -stim_file 3 ${glmout}/custom_basis_set.1D'[1]' -stim_label 3 basis2"
exe="${exe} -stim_file 4 ${glmout}/custom_basis_set.1D'[2]' -stim_label 4 basis3"
exe="${exe} -stim_file 5 ${glmout}/custom_basis_set.1D'[3]' -stim_label 5 basis4"
exe="${exe} -ortvec ${glmout}/${pid}.motion_demean.1D motion_params"
exe="${exe} -x1D ${glmout}/${pid}.xmat.1D -cbucket ${glmout}/${pid}.cbucket.nii.gz -rout -bucket ${glmout}/${pid}.bucket.nii.gz"
echo "check_exe ${glmout}/${pid}.cbucket.nii.gz \"${exe}\"" >> ${clusterscript}

exe="r2vals=\`${AFNIDIR}/3dinfo -verb ${glmout}/${pid}.bucket.nii.gz | grep basis | grep R^2 | awk '{print \$4}'"
exe="${exe} | awk 'BEGIN {FS=\"#\"};{print \$2}' | awk '{printf \"%s,\",\$1}'\`"
echo "${exe}" >> ${clusterscript}

exe="${AFNIDIR}/3dTstat -sum -prefix ${glmout}/${pid}.tcr_R2.nii.gz ${glmout}/${pid}.bucket.nii.gz\"[\${r2vals%*,}]\""
echo "check_exe ${glmout}/${pid}.tcr_R2.nii.gz \"${exe}\"" >> ${clusterscript}

exe="basevols=\`${AFNIDIR}/3dinfo -verb ${glmout}/${pid}.cbucket.nii.gz | grep Pol#0 | awk '{print \$4}'"
exe="${exe} | awk 'BEGIN {FS=\"#\"};{print \$2}' | awk '{printf \"%s,\",\$1}'\`"
echo "${exe}" >> ${clusterscript}

exe="${AFNIDIR}/3dTstat -mean -prefix ${glmout}/${pid}.mean.nii.gz ${glmout}/${pid}.cbucket.nii.gz\"[\${basevols%*,}]\""
echo "check_exe ${glmout}/${pid}.mean.nii.gz \"${exe}\"" >> ${clusterscript}

exe="basisvols=\`${AFNIDIR}/3dinfo -verb ${glmout}/${pid}.cbucket.nii.gz | grep sub-brick | grep basis | awk '{print \$4}'"
exe="${exe} | awk 'BEGIN {FS=\"#\"};{print \$2}' | awk '{printf \"%s,\",\$1}'\`"
echo "${exe}" >> ${clusterscript}

exe="${AFNIDIR}/3dTcat -prefix ${glmout}/${pid}.basis_betas.nii.gz ${glmout}/${pid}.cbucket.nii.gz\"[\${basisvols%*,}]\""
echo "check_exe ${glmout}/${pid}.basis_betas.nii.gz \"${exe}\"" >> ${clusterscript}

exe="${AFNIDIR}/3dcalc -a ${glmout}/${pid}.basis_betas.nii.gz -b ${glmout}/${pid}.mean.nii.gz -expr "100*a/b" -prefix ${glmout}/${pid}.basis_betas_psc.nii.gz"
echo "check_exe ${glmout}/${pid}.basis_betas_psc.nii.gz \"${exe}\"" >> ${clusterscript}

#exe1="${AFNIDIR}/3dSynthesize -cbucket ${glmout}/${pid}.cbucket.nii.gz -matrix ${glmout}/${pid}.xmat.1D"
#exe1="${AFNIDIR}/3dSynthesize -cbucket ${glmout}/${pid}.cbucket.nii.gz -matrix new_custom_basis_set_xmat.1D"
#exe1="${exe1} -select basis1 -select basis2 -select basis3 -select basis4 -prefix ${glmout}/killme.${pid}.basis_fitts.nii.gz"
exe1="${AFNIDIR}/3dSynthesize -cbucket ${glmout}/${pid}.basis_betas.nii.gz -matrix ${dire}/new_custom_basis_set_xmat.1D"
exe1="${exe1} -select all -prefix ${glmout}/killme.${pid}.basis_fitts.nii.gz"
exe2="${AFNIDIR}/3dTcat -prefix ${glmout}/${pid}.basis_fitts.nii.gz ${glmout}/killme.${pid}.basis_fitts.nii.gz\"[0..89]\""
echo "check_exe ${glmout}/killme.${pid}.basis_fitts.nii.gz \"${exe1}\"" >> ${clusterscript}
echo "check_exe ${glmout}/${pid}.basis_fitts.nii.gz \"${exe2}\"" >> ${clusterscript}
echo "rm ${glmout}/killme.${pid}.basis_fitts.nii.gz" >> ${clusterscript}

exe="${AFNIDIR}/3dcalc -a ${glmout}/${pid}.basis_fitts.nii.gz -b ${glmout}/${pid}.mean.nii.gz -expr "100*a/b" -prefix ${glmout}/${pid}.basis_fitts_psc.nii.gz"
echo "check_exe ${glnmout}/${pid}.basis_fitts_psc.nii.gz \"${exe}\"" >> ${clusterscript}

exe="${AFNIDIR}/3dTstat -sum -prefix ${glmout}/${pid}.basis_auc.nii.gz ${glmout}/${pid}.basis_fitts.nii.gz"
echo "check_exe ${glmout}/${pid}.basis_auc.nii.gz \"${exe}\"" >> ${clusterscript}

exe="${AFNIDIR}/3dcalc -a ${glmout}/${pid}.mean.nii.gz -b ${glmout}/${pid}.basis_auc.nii.gz -expr "b/a" -prefix ${glmout}/${pid}.basis_auc_psc.nii.gz"
echo "check_exe ${glmout}/${pid}.basis_auc_psc.nii.gz \"${exe}\"" >> ${clusterscript}



### Execute script

case "$cluster_opt" in

	"TRUE")

	# Create cluster job
	echo "#!/bin/bash" >> ${clustout}/${pid}.tcr_fmri_glm.cluster_job_${crun}
	echo "#SBATCH --job-name=${pid}.tcr_fmri_glm_${crun}" >> ${clustout}/${pid}.tcr_fmri_glm.cluster_job_${crun}
	echo "#SBATCH -p cubric-default" >> ${clustout}/${pid}.tcr_fmri_glm.cluster_job_${crun}
	echo "#SBATCH --output ${clustout}/${pid}.tcr_fmri_glm_${crun}_%j.out" >> ${clustout}/${pid}.tcr_fmri_glm.cluster_job_${crun}
	echo "${clusterscript}" >> ${clustout}/${pid}.tcr_fmri_glm.cluster_job_${crun}

	chmod +x ${clusterscript}
	printf "\nsending %s tcr_fmri_glm job to the cluster..." "${pid}"
	sbatch ${clustout}/${pid}.tcr_fmri_glm.cluster_job_${crun}
	sleep 2

	;;

	"FALSE")

	bash ${clusterscript}
	rm -rf $tmpdir
	
	;;
esac















