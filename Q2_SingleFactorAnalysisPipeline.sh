#!/bin/bash

#SBATCH --account=round-np
#SBATCH --partition=round-shared-np
#SBATCH -n 12
#SBATCH -J DSS_Q2_pp
#SBATCH -t 12:50:00 
#SBATCH -D /uufs/chpc.utah.edu/common/home/u0210816/Projects/MHCIIonIECs_19/16S
#SBATCH -o /uufs/chpc.utah.edu/common/home/u0210816/Projects/MHCIIonIECs_19/16S/jobs/DSS_Q2_pp.outerror

WRKDIR=/uufs/chpc.utah.edu/common/home/round-group2/zs_MHCIIonIECs_wrkdir/AgedAndSep/
ResultDir=/uufs/chpc.utah.edu/common/home/u0210816/Projects/MHCIIonIECs_19/16S/AgedSepOnly # Will be created if not existing already.
INTABLE=/uufs/chpc.utah.edu/common/home/round-group2/zs_MHCIIonIECs_wrkdir/AgedAndSep/table_nochim.qza
MAP=/uufs/chpc.utah.edu/common/home/u0210816/Projects/MHCIIonIECs_19/16S/metadata/map_Vil_final_AgedAndSepHoused_2015.txt
FACTOR2TEST=Genotype

Nproc=10
RDepth=2500

ContainerImage=docker://qiime2/core:2019.4
# Singularity export
export SINGULARITYENV_WRKDIR=${WRKDIR}
export SINGULARITYENV_MAP=${MAP}
export SINGULARITYENV_INTABLE=${INTABLE}
export SINGULARITYENV_Nproc=${Nproc}
export SINGULARITYENV_RDepth=${RDepth}
export SINGULARITYENV_FACTOR2TEST=${FACTOR2TEST}
# setup
module load singularity/3.1.1
mkdir -p ${WRKDIR}/q2_viz
mkdir -p ${ResultDir}/q2_viz


#Analyses
singularity exec ${ContainerImage} qiime diversity core-metrics-phylogenetic --i-table $INTABLE --i-phylogeny tree_root.qza --p-sampling-depth 2500 --p-n-jobs 12 --m-metadata-file $MAP --output-dir corediv_2500

# alpha significance and visualizations loop
cd corediv_${RDepth}
for f in shannon_vector.qza observed_otus_vector.qza evenness_vector.qza faith_pd_vector.qza; do singularity exec ${ContainerImage} qiime diversity alpha-group-significance --i-alpha-diversity $f --m-metadata-file $MAP --o-visualization ${f%.qza}_sig.qzv; done
cd ../

# Beta significance loop
cd corediv_${RDepth}
for g in unweighted_unifrac_distance_matrix.qza weighted_unifrac_distance_matrix.qza bray_curtis_distance_matrix.qza jaccard_distance_matrix.qza; do singularity exec ${ContainerImage} qiime diversity beta-group-significance --i-distance-matrix $g --m-metadata-file $MAP --m-metadata-column ${FACTOR2TEST} --p-permutations 9999 --o-visualization ${g%.qza}_sig.qzv; done
cd ../

# ancom for ASVs, as well as taxa levels, and a bar chart again with the filtered input OTU table
mkdir -p ancom_${FACTOR2TEST}
for lev in 4 5 6 7; do singularity exec ${ContainerImage} qiime taxa collapse --i-table ${INTABLE} --i-taxonomy taxonomy.qza --p-level ${lev} --o-collapsed-table ancom_${FACTOR2TEST}/coltable_${lev}.qza; singularity exec ${ContainerImage} qiime composition add-pseudocount --i-table ancom_${FACTOR2TEST}/coltable_${lev}.qza --o-composition-table ancom_${FACTOR2TEST}/coltable_${lev}_pseudo.qza; done
singularity exec ${ContainerImage} qiime composition add-pseudocount --i-table ${INTABLE} --o-composition-table ancom_${FACTOR2TEST}/table_pseudo.qza
cd ancom_${FACTOR2TEST}
for pseudotable in *_pseudo.qza; do singularity exec ${ContainerImage} qiime composition ancom --i-table ${pseudotable} --m-metadata-file ${MAP} --m-metadata-column ${FACTOR2TEST} --p-difference-function mean_difference --o-visualization ${pseudotable%.qza}_ancom.qzv; done 
cd ../


# Cleaning up and saving results:
cp corediv_${RDepth}/*.qzv ${ResultDir}/q2_viz/
cp ancom_${FACTOR2TEST}/*.qzv ${ResultDir}/q2_viz/
cp q2_viz/*.qzv ${ResultDir}/q2_viz