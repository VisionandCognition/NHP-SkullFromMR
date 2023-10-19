#!/bin/bash

# make sure this is the same version you aligned NMT to
# it will make additional steps easier
S=Diego2018

nmt_fld=/NHP_MRI/Template/NMT_v2.0/NMT_v2.0_sym/NMT_v2.0_sym
nmt=${nmt_fld}/NMT_v2.0_sym.nii.gz
nmtb=${nmt_fld}/NMT_v2.0_sym_brainmask.nii.gz
nmt_ss=/NHP_MRI/Template/NMT_v2.0/NMT_v2.0_sym/SingleSubjects/input_files

#skull_fld=/NHP_MRI/Mircen/Skulls
skull_fld=/NHP_MRI/Skull_MR
skull_fld_ss=${skull_fld}/${S}

mkdir -p ${skull_fld_ss}

cp ${nmt_ss}/${S}.nii.gz ${skull_fld_ss}/${S}.nii.gz

# There are cases where you would need to crop your ss or use a mask for
# 3dAllineate to not get confused by all non-brain voxels
ROI=_roi # leave empty for no roi
# ====
# set cost (lpc for T2w, lpa for T1w)
cost=lpa
# ===
3dAllineate -source ${nmt} \
	-base ${skull_fld_ss}/${S}${ROI}.nii.gz \
	-prefix ${skull_fld_ss}/NMT_srs2${S}.nii.gz \
	-cost ${cost} -cmass -warp srs \
	-1Dparam_save ${skull_fld_ss}/1Dmat \
	-overwrite

flirt -in ${nmt} -ref ${skull_fld_ss}/NMT_srs2${S}.nii.gz -dof 9 \
	-out ${skull_fld_ss}/nmt_aff2ind.nii.gz -omat ${skull_fld_ss}/LT.mat
flirt -in ${nmtb} -ref ${skull_fld_ss}/${S}${ROI}.nii.gz  \
	-out ${skull_fld_ss}/brainmask.nii.gz -init ${skull_fld_ss}/LT.mat -applyxfm
3dAutomask -dilate 6.0 -prefix ${skull_fld_ss}/brainmask_dil.nii.gz ${skull_fld_ss}/brainmask.nii.gz -overwrite
cp ${skull_fld_ss}/brainmask_dil.nii.gz ${skull_fld_ss}/brainmask_dil_ed.nii.gz

3dAutomask -dilate 5.0 -prefix ${skull_fld_ss}/${S}_am.nii.gz ${skull_fld_ss}/${S}${ROI}.nii.gz -overwrite
fslmaths ${skull_fld_ss}/${S}${ROI}.nii.gz -mas ${skull_fld_ss}/${S}_am.nii.gz ${skull_fld_ss}/${S}_preskull.nii.gz

# Manually inspect and set the upper threshold for dark inclusion
UTH=5000 #40
fslmaths ${skull_fld_ss}/${S}${ROI}.nii.gz -uthr ${UTH} -bin ${skull_fld_ss}/preskull.nii.gz
fslmaths ${skull_fld_ss}/preskull.nii.gz -mas ${skull_fld_ss}/${S}_am.nii.gz ${skull_fld_ss}/skull.nii.gz

# mask skull with dilated and edited brainmask
fslmaths ${skull_fld_ss}/skull.nii.gz -mas ${skull_fld_ss}/brainmask_dil_ed.nii.gz ${skull_fld_ss}/skull2.nii.gz
cp ${skull_fld_ss}/skull2.nii.gz ${skull_fld_ss}/skull2_ed.nii.gz

# Here, you are going to have to get your hands dirty and touch up that brainmask_dil_ed.nii.gz
# correct the skull mask in fsleyes

# smooth (you may need to tinker with the gaussian width)
fslmaths ${skull_fld_ss}/skull2_ed.nii.gz -kernel gauss 0.5 \
	-fmean -thr 0.1 -bin ${skull_fld_ss}/skull2s.nii.gz
# generate stl surface
IsoSurface -isorois -Tsmooth 0.01 500 -input ${skull_fld_ss}/skull2s.nii.gz  \
	-o_stl ${skull_fld_ss}/skull_final.stl -overwrite