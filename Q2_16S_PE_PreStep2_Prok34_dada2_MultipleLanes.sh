#!/bin/bash

#SBATCH --account=round
#SBATCH --partition=notchpeak
#SBATCH -J dada2_s2
#SBATCH -t 48:00:00
#SBATCH -D 
#SBATCH -o 

# NOTE:
# 1. Requires $RunID variable passed to script. Intended to keep separate run IDs for analysis of each before merge.
# 2. Requires input truncation left and right values determined after PreStep2. Inspect quality graphs for truncation locations.



module use ~/MyModules
module load miniconda3/latest
source activate qiime2-2020.6

#### Env #######
PROJNAME=
SCRATCH=
ResultDir=
WRKDIR=
# Manifest file can list .gz or unzipped .fastq files.
# As multiple runs should be all looked at for error file separately, I will Import
# and deblur or dada2 them each separately and pass runID with sbatch to submit multiple jobs
# For mulitple runs, manifes file name should have RunID variable in it.
MANIFEST=/uufs/chpc.utah.edu/common/home/u0210816/Projects/AAF_19/metadata/manifest_prok_${RunID}.txt
# A file with Gnomex Sample ID in first column and a column (specified by GROUPBYCOL) containing original Sample template ID.
MAPBYGNOMEXID=
GROUPBYCOL=OrigID
CLASSIFIER=/uufs/chpc.utah.edu/common/home/round-group1/reference_seq_dbs/qiime2/training-feature-classifiers/gg_13_8_v34Prok_classifier_sk0.20.2.qza
################
#### Param #####
Nproc=28
JoinedTrimLength=392
FPrimerSeqToTrim=TGCCTACGGGNBGCASCAG
RPrimerSeqToTrim=GCGACTACNVGGGTATCTAATCC
# Not relevant MinMergeLength and MaxDiffs for dada2
MinMergeLength=189
MaxDiffs=30
# Trunc relevant to each run:
TruncLeft=
TruncRight=
################
#### Setup ####
mkdir -p $SCRATCH
mkdir -p ${SCRATCH}/tmp_XDG
mkdir -p ${SCRATCH}/raw
mkdir -p ${WRKDIR}
mkdir -p ${ResultDir}/q2_viz
###############

# Part 1: Import sequences (this is slow)
# Input manifest file can have .gz or unzipped fastq

cd ${SCRATCH}

# Note, we don't trim in deblur and let cutadapt's increase flexibility deal with primers beforehand.

qiime dada2 denoise-paired \
  --i-demultiplexed-seqs ${RunID}_inseqs-demux_trim.qza \
  --p-trim-left-f 0 \
  --p-trim-left-r 0 \
  --p-trunc-len-f ${TruncLeft} \
  --p-trunc-len-r ${TruncRight} \
  --o-table ${RunID}_table.qza \
  --o-representative-sequences  ${RunID}_repseq.qza \
  --o-denoising-stats  ${RunID}_denoising-stats.qza
  
qiime feature-table summarize \
--i-table ${RunID}_table.qza \
--o-visualization ${RunID}_table.qzv
echo "TIME: END denoise = `date +"%Y-%m-%d %T"`"

qiime feature-table tabulate-seqs \
--i-data ${RunID}_repseq.qza \
--o-visualization ${RunID}_repseq.qzv

cp *.qzv ${ResultDir}/q2_viz/
cp *.qza ${WRKDIR}/