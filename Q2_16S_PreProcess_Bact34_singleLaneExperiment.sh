#!/bin/bash

#SBATCH --account=round-np
#SBATCH --partition=round-np
#SBATCH -N 1
#SBATCH -J Individ_Q2_pp
#SBATCH -t 24:50:00 
#SBATCH -D /uufs/chpc.utah.edu/common/home/u0210816/Projects/MHCIIonIECs_19/16S
#SBATCH -o /uufs/chpc.utah.edu/common/home/u0210816/Projects/MHCIIonIECs_19/16S/jobs/IndividTimeSeries_Q2_pp.outerror

#NOTE: This script runs for an Illumina 16S based sequencing experiment WITH OLD BACT34 PRIMERS (not used past 2018)
# and for a SINGLE sequencing lane only.


#### Env #######
module load singularity/3.1.1
PROJNAME=IndividTimeSeries
SCRATCH=/scratch/kingspeak/serial/u0210816/16S/MHCIIonIECs_IndividTimeSeries # Will be made, as long as you have permissions in directory.
ResultDir=/uufs/chpc.utah.edu/common/home/u0210816/Projects/MHCIIonIECs_19/16S/IndividTimeSeriesOnly # Will be created if not existing already.
WRKDIR=/uufs/chpc.utah.edu/common/home/round-group2/zs_MHCIIonIECs_wrkdir/Individ # Will be made. 
# Manifest file can list .gz or unzipped .fastq files. NOTE: (documentation has been out of date for awhile in qiime2.
# Manifest format should be a CSV with headers: sample-id,absolute-filepath,direction
MANIFEST=/uufs/chpc.utah.edu/common/home/u0210816/Projects/MHCIIonIECs_19/16S/metadata/manifest_qiime_VilCre_IndividHousedTimeSeries.csv
MAP=/uufs/chpc.utah.edu/common/home/u0210816/Projects/MHCIIonIECs_19/16S/metadata/map_qiime_VilCre_IndividHousedTimeSeries.txt
CLASSIFIER=/uufs/chpc.utah.edu/common/home/round-group1/reference_seq_dbs/qiime2/training-feature-classifiers/v1_Bact34Primers/gg_13_8_v34Bact_classifier.qza
ContainerImage=docker://qiime2/core:2019.4
XDG_RUNTIME_DIR=${SCRATCH}/tmp_XDG
################
#### Param #####
Nproc=16
JoinedTrimLength=392
FPrimerSeqToTrim=TAGGGRGGCWGCAGTRRGG
RPrimerSeqToTrim=TTCTACHVGGGTATCTAATCCTGTT
MinMergeLength=289
################
#### Setup ####
mkdir -p $SCRATCH
mkdir -p ${SCRATCH}/tmp_XDG
mkdir -p ${SCRATCH}/raw
mkdir -p ${WRKDIR}
mkdir -p ${ResultDir}/q2_viz
###############
#### SINGULARITYENV ###########
export SINGULARITYENV_RAW1=${RAW1}
export SINGULARITYENV_UHOME=${HOME}
export SINGULARITYENV_MANIFEST=${MANIFEST}
export SINGULARITYENV_SCRATCH=${SCRATCH}
export SINGULARITYENV_WRKDIR=${WRKDIR}
export SINGULARITYENV_XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}
export SINGULARITYENV_Nproc=${Nproc}
export SINGULARITYENV_FPrimerSeqToTrim=${FPrimerSeqToTrim}
export SINGULARITYENV_RPrimerSeqToTrim=${RPrimerSeqToTrim}
export SINGULARITYENV_MinMergeLength=${MinMergeLength}
export SINGULARITYENV_MAP=${MAP}
export SINGULARITYENV_CLASSIFIER=${CLASSIFIER}
###############################

# Part 1: Import sequences (this is slow)
# Input manifest file can have .gz or unzipped fastq

cd ${SCRATCH}

echo "TIME: START import = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' \
--input-path ${MANIFEST} \
--output-path ${SCRATCH}/inseqs-demux.qza \
--input-format PairedEndFastqManifestPhred33

singularity exec ${ContainerImage} qiime demux summarize \
  --i-data ${SCRATCH}/inseqs-demux.qza \
  --o-visualization ${SCRATCH}/inseq-demux-summary.qzv  
echo "TIME: END import = `date +"%Y-%m-%d %T"`"

# Copy visualization results to ResultDir and artifacts to working dir
cp ${SCRATCH}/*.qzv ${ResultDir}/q2_viz
cp ${SCRATCH}/inseqs-demux.qza ${WRKDIR}/ # Generally, it is not useful and too big to copy full input sequence artifacts

# Part 2: Clean, denoise, filter chimeras, create table and phylogeny, call taxonomy

echo "TIME: START trim, merge = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime cutadapt trim-paired \
--i-demultiplexed-sequences ${SCRATCH}/inseqs-demux.qza \
--o-trimmed-sequences PE-demux_trim.qza \
--p-front-f ${FPrimerSeqToTrim} \
--p-front-r ${RPrimerSeqToTrim} \
--p-cores $Nproc

singularity exec ${ContainerImage} qiime vsearch join-pairs \
--i-demultiplexed-seqs PE-demux_trim.qza \
--o-joined-sequences PE-demux_trim_join.qza \
--p-minmergelen ${MinMergeLength} \
--verbose \

singularity exec ${ContainerImage} qiime demux summarize \
  --i-data PE-demux_trim_join.qza \
  --o-visualization PE-demux_trim_join.qzv
  
#At this stage plots should be inspected to infer the JoinedTrimLength for deblur. It should hold whenever using the same primer set though.

singularity exec ${ContainerImage} qiime quality-filter q-score-joined \
--i-demux PE-demux_trim_join.qza \
--o-filtered-sequences PE-demux_trim_join_filt.qza \
--o-filter-stats PE-demux_trim_join_filt_stats.qza \
--p-min-quality 10 
echo "TIME: END trim, merge = `date +"%Y-%m-%d %T"`"

echo "TIME: START denoise = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime deblur denoise-16S \
--i-demultiplexed-seqs PE-demux_trim_join_filt.qza \
--p-trim-length $JoinedTrimLength \
--p-jobs-to-start $Nproc \
--o-table table.qza \
--o-representative-sequences repseq.qza \
--o-stats table_stats.qza

singularity exec ${ContainerImage} qiime feature-table summarize \
--i-table table.qza \
--o-visualization table.qzv
echo "TIME: END denoise = `date +"%Y-%m-%d %T"`"

# Chimera filtering using "include borderline chimeras parameters"

echo "TIME: START chimera filter = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime vsearch uchime-denovo \
--i-table table.qza \
--i-sequences repseq.qza \
--output-dir uchime_out
  
singularity exec ${ContainerImage} qiime feature-table filter-features \
--i-table table.qza \
--m-metadata-file uchime_out/chimeras.qza \
--p-exclude-ids \
--o-filtered-table table_nochim.qza
  
singularity exec ${ContainerImage} qiime feature-table filter-seqs \
--i-data repseq.qza \
--m-metadata-file uchime_out/chimeras.qza \
--p-exclude-ids \
--o-filtered-data repseq_nochim.qza
  
singularity exec ${ContainerImage} qiime feature-table summarize \
--i-table table_nochim.qza \
--o-visualization table_nochim.qzv
--m-sample-metadata-file ${MAP}

singularity exec ${ContainerImage} qiime feature-table tabulate-seqs \
--i-data repseq_nochim.qza \
--o-visualization repseq_nochim.qzv
echo "TIME: END chimera filter = `date +"%Y-%m-%d %T"`"

echo "TIME: START phylogeny = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime phylogeny align-to-tree-mafft-fasttree \
--i-sequences repseq_nochim.qza \
--o-alignment aligned_repseq_nochim.qza \
--o-masked-alignment masked_aligned_repseq_nochim.qza \
--o-tree tree_unroot.qza \
--o-rooted-tree tree_root.qza
echo "TIME: END phylogeny = `date +"%Y-%m-%d %T"`"

echo "TIME: START taxonomy = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime feature-classifier classify-sklearn \
--i-classifier ${CLASSIFIER} \
--i-reads repseq_nochim.qza \
--o-classification taxonomy.qza \
--p-n-jobs ${Nproc}

singularity exec ${ContainerImage} qiime metadata tabulate \
--m-input-file taxonomy.qza \
--o-visualization taxonomy.qzv

singularity exec ${ContainerImage} qiime taxa barplot \
--i-table table_nochim.qza \
--i-taxonomy taxonomy.qza \
--m-metadata-file ${MAP} \
--o-visualization table_taxbarplots.qzv
echo "TIME: END taxonomy = `date +"%Y-%m-%d %T"`"

cp *.qzv ${ResultDir}/q2_viz/
cp *.qza ${WRKDIR}/
