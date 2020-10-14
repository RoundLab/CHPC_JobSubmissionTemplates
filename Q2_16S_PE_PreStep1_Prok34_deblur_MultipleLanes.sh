#!/bin/bash

#SBATCH --account=round
#SBATCH --partition=notchpeak
#SBATCH -J deblur_s1
#SBATCH -t 24:50:00
#SBATCH -D 
#SBATCH -o

# NOTE:
# 1. Requires $RunID variable passed to script. Intended to keep separate run IDs for analysis of each before merge.

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
# RunID variable should be in manifest file name for this to work properly.
MANIFEST=
# The file map that lists by Gnomex/Illumina ID, and has a column for sample template (GROUPBYCOL below)
MAPBYGNOMEXID=
# The column header in MAPBYGNOMEXID that has values relating each Gnomex ID to the sample template.
GROUPBYCOL=OrigID 
CLASSIFIER=/uufs/chpc.utah.edu/common/home/round-group1/reference_seq_dbs/qiime2/training-feature-classifiers/gtdb_ssu_r89_v34Prok_uniq_classifier_sk0.23.1.qza
################
#### Param #####
Nproc=`expr \`nproc\` - 2`
JoinedTrimLength=392
FPrimerSeqToTrim=TGCCTACGGGNBGCASCAG
RPrimerSeqToTrim=GCGACTACNVGGGTATCTAATCC
MinMergeLength=189
MaxDiffs=30
################
#### Setup ####
mkdir -p $SCRATCH
mkdir -p ${SCRATCH}/raw
mkdir -p ${WRKDIR}
mkdir -p ${ResultDir}/q2_viz
###############

cd ${SCRATCH}

echo "TIME: START import = `date +"%Y-%m-%d %T"`"
qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' \
--input-path ${MANIFEST} \
--output-path ${SCRATCH}/${RunID}_inseqs-demux.qza \
--input-format PairedEndFastqManifestPhred33V2

qiime demux summarize \
  --i-data ${SCRATCH}/${RunID}_inseqs-demux.qza \
  --o-visualization ${SCRATCH}/${RunID}_inseqs-demux.qzv
echo "TIME: END import = `date +"%Y-%m-%d %T"`"

# Part 2: trim and join

echo "TIME: START trim, merge = `date +"%Y-%m-%d %T"`"
qiime cutadapt trim-paired \
--i-demultiplexed-sequences ${SCRATCH}/${RunID}_inseqs-demux.qza \
--o-trimmed-sequences ${RunID}_inseqs-demux_trim.qza \
--p-front-f ${FPrimerSeqToTrim} \
--p-front-r ${RPrimerSeqToTrim} \
--p-cores $Nproc

qiime vsearch join-pairs \
--i-demultiplexed-seqs ${RunID}_inseqs-demux_trim.qza \
--o-joined-sequences ${RunID}_inseqs-demux_trim_join.qza \
--p-minmergelen ${MinMergeLength} \
--verbose \

qiime demux summarize \
  --i-data ${RunID}_inseqs-demux_trim_join.qza \
  --o-visualization ${RunID}_inseqs-demux_trim_join.qzv

# Copy visualization results to ResultDir and artifacts to working dir
cp *.qzv ${ResultDir}/q2_viz

# cp ${SCRATCH}/inseqs-demux.qza ${WRKDIR}/ # Generally, it is not useful and too big to copy full input sequence artifacts


