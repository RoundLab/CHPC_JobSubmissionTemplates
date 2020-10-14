#!/bin/bash

#SBATCH --account=round
#SBATCH --partition=notchpeak
#SBATCH -J deblur_s2
#SBATCH -t 24:50:00
#SBATCH -D 
#SBATCH -o 

# NOTE:
# 1. Requires $RunID variable passed to script. Intended to keep separate run IDs for analysis of each before merge.
# 2. Requires input joined trim length determined after PreStep1. Inspect quality graphs for truncation locations.

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

qiime quality-filter q-score-joined \
--i-demux ${RunID}_inseqs-demux_trim_join.qza \
--o-filtered-sequences ${RunID}_inseqs-demux_trim_join_filt.qza \
--o-filter-stats ${RunID}_inseqs-demux_trim_join_filt_stats.qza \
--p-min-quality 10
echo "TIME: END trim, merge = `date +"%Y-%m-%d %T"`"

echo "TIME: START denoise = `date +"%Y-%m-%d %T"`"
qiime deblur denoise-16S \
--i-demultiplexed-seqs ${RunID}_inseqs-demux_trim_join_filt.qza \
--p-trim-length $JoinedTrimLength \
--p-jobs-to-start $Nproc \
--o-table ${RunID}_table.qza \
--o-representative-sequences ${RunID}_repseq.qza \
--o-stats ${RunID}_deblur_stats.qza

qiime feature-table summarize \
--i-table ${RunID}_table.qza \
--o-visualization ${RunID}_table.qzv
echo "TIME: END denoise = `date +"%Y-%m-%d %T"`"

qiime deblur visualize-stats --i-deblur-stats ${RunID}_deblur_stats.qza --o-visualization ${RunID}_deblur_stats.qzv

qiime feature-table tabulate-seqs \
--i-data ${RunID}_repseq.qza \
--o-visualization ${RunID}_repseq.qzv

cp *.qzv ${ResultDir}/q2_viz/
cp *.qza ${WRKDIR}/


