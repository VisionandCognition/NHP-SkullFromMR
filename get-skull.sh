#!/bin/bash

# make sure this is the same version you aligned NMT to
# it will make additional steps easier
S=Kid

# set some paths
nmt_fld=/NHP_MRI/Template/NMT_v2.0/NMT_v2.0_sym/NMT_v2.0_sym
nmt=${nmt_fld}/NMT_v2.0_sym.nii.gz
nmtb=${nmt_fld}/NMT_v2.0_sym_brainmask.nii.gz
nmt_ss=/NHP_MRI/Template/NMT_v2.0/NMT_v2.0_sym/SingleSubjects/input_files
skull_fld=/NHP_MRI/Mircen/Skulls
skull_fld_ss=${skull_fld}/${S}
# create folder and copy scan
mkdir -p ${skull_fld_ss}
cp ${nmt_ss}/${S}.nii.gz ${skull_fld_ss}/${S}.nii.gz

# warp NMT 2 sub (aff)
3dAllineate -source ${nmt} \
	-base ${skull_fld_ss}/${S}.nii.gz \
	-prefix ${skull_fld_ss}/NMT_srs2${S}.nii.gz \
	-cost lpc -cmass -warp srs \
	-1Dparam_save ${skull_fld_ss}/1Dmat
flirt -in ${nmt} -ref ${skull_fld_ss}/NMT_srs2${S}.nii.gz -dof 9 \
	-out ${skull_fld_ss}/nmt_aff2ind.nii.gz -omat ${skull_fld_ss}/LT.mat
flirt -in ${nmtb} -ref ${skull_fld_ss}/${S}.nii.gz  \
	-out ${skull_fld_ss}/brainmask.nii.gz -init ${skull_fld_ss}/LT.mat -applyxfm
3dAutomask -dilate 6.0 -prefix ${skull_fld_ss}/brainmask_dil.nii.gz \
	${skull_fld_ss}/brainmask.nii.gz -overwrite
cp ${skull_fld_ss}/brainmask_dil.nii.gz ${skull_fld_ss}/brainmask_dil_ed.nii.gz

3dAutomask -dilate 5.0 -prefix ${skull_fld_ss}/${S}_am.nii.gz \
	${skull_fld_ss}/${S}.nii.gz -overwrite
fslmaths ${skull_fld_ss}/${S}.nii.gz -mas ${skull_fld_ss}/${S}_am.nii.gz \
	${skull_fld_ss}/${S}_preskull.nii.gz

# Manually inspect ${S}.nii.gz and set the upper threshold for dark inclusion
UTH=40
fslmaths ${skull_fld_ss}/${S}.nii.gz -uthr ${UTH} -bin ${skull_fld_ss}/preskull.nii.gz
fslmaths ${skull_fld_ss}/preskull.nii.gz -mas ${skull_fld_ss}/${S}_am.nii.gz \
	${skull_fld_ss}/skull.nii.gz

# =====================================================================================
# Here, you might need to touch up that brainmask_dil_ed.nii.gz.
# Use whatever software; FSLEYES, ITKSNAP, SLICER or FREEVIEW should all be fine
#
# You should end up with a mask that encompasses the skull space. This mask is created
# from a dilated brainmask and will miss anterior skull but is likely ok where the 
# skull is closer to the brain.
#
# Similarly you may also want to edit skull.nii.gz to add some missing voxels
# =====================================================================================

# mask skull with dilated and edited brainmask
fslmaths ${skull_fld_ss}/skull.nii.gz \
	-mas ${skull_fld_ss}/brainmask_dil_ed.nii.gz \
	${skull_fld_ss}/skull2.nii.gz
cp ${skull_fld_ss}/skull2.nii.gz ${skull_fld_ss}/skull2_ed.nii.gz

# smooth (you may need to tinker with the gaussian width)
fslmaths ${skull_fld_ss}/skull2_ed.nii.gz -kernel gauss 0.5 \
	-fmean -thr 0.1 -bin ${skull_fld_ss}/skull2s.nii.gz

# here you may need to add a few empty slices to not get any clipping
# fslmaths ${skull_fld_ss}/skull2_ed_fovplus.nii.gz -kernel gauss 0.5 \
# 	-fmean -thr 0.1 -bin ${skull_fld_ss}/skull2s.nii.gz

# cut off the bottom that doesn't mkae sense
fslroi ${skull_fld_ss}/skull2s.nii.gz ${skull_fld_ss}/skull2s_top.nii.gz \
	0 -1 0 -1 40 60   

# generate stl surface
IsoSurface -isorois -Tsmooth 0.01 500 -input ${skull_fld_ss}/skull2s_top.nii.gz  \
	-o_stl ${skull_fld_ss}/skull_final.stl -overwrite

# =====================================================================================
# Now that we have a mesh of the skull, go to Meshlab to edit it:
# - remove loose islands
# - smooth a bit and simplify
# =====================================================================================
