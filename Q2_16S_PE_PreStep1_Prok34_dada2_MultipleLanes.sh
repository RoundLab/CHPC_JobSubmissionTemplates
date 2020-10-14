#!/bin/bash

#SBATCH --account=round
#SBATCH --partition=notchpeak
#SBATCH -J dada2_s2
#SBATCH -t 48:00:00
#SBATCH -D 
#SBATCH -o 

# Requires $RunID variable passed to script. Intended to keep separate run IDs for analysis of each before merge.

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

echo "TIME: START import = `date +"%Y-%m-%d %T"`"
qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' \
--input-path ${MANIFEST} \
--output-path ${SCRATCH}/${RunID}_inseqs-demux.qza \
--input-format PairedEndFastqManifestPhred33V2

qiime demux summarize \
  --i-data ${SCRATCH}/${RunID}_inseqs-demux.qza \
  --o-visualization ${SCRATCH}/${RunID}_inseqs-demux-summary.qzv
echo "TIME: END import = `date +"%Y-%m-%d %T"`"

# Part 2: trim and join

echo "TIME: START trim, merge = `date +"%Y-%m-%d %T"`"
qiime cutadapt trim-paired \
--i-demultiplexed-sequences ${SCRATCH}/${RunID}_inseqs-demux.qza \
--o-trimmed-sequences ${RunID}_inseqs-demux_trim.qza \
--p-front-f ${FPrimerSeqToTrim} \
--p-front-r ${RPrimerSeqToTrim} \
--p-cores $Nproc

qiime demux summarize \
  --i-data ${RunID}_inseqs-demux_trim.qza \
  --o-visualization ${RunID}_inseqs-demux_trim.qzv

# Copy visualization results to ResultDir and artifacts to working dir
cp *.qzv ${ResultDir}/q2_viz
# cp ${SCRATCH}/inseqs-demux.qza ${WRKDIR}/ # Generally, it is not useful and too big to copy full input sequence artifacts

#At this stage plots should be inspected to infer the end trimming parameters used in dada2
