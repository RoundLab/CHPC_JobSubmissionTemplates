#!/bin/bash

#SBATCH --account=round-np
#SBATCH --partition=round-shared-np
#SBATCH -n 20
#SBATCH -J deblur_s3
#SBATCH -t 16:50:00
#SBATCH -D 
#SBATCH -o 


# NOTE:
# 1. **NOT optimized for automation. Need to change the filenames manually still for tables (qiime feature-table merge) and repseqs (qiime feature-table merge-seqs) to merge.

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
# Here, we merge tables and keep default of error on overlalping sample as they are currently gnomexID and want to keep seaprate for now.
qiime feature-table merge \
--i-tables 16154R_table.qza 15341R_table.qza 15219R_table.qza 15218R_table.qza 14231R_table.qza \
--o-merged-table table_AllByGnomexID.qza

qiime feature-table group \
--i-table table_AllByGnomexID.qza \
--m-metadata-file ${MAPBYGNOMEXID} \
--p-axis sample \
--m-metadata-column ${GROUPBYCOL} \
--p-mode sum \
--o-grouped-table group_table.qza

qiime feature-table summarize \
--i-table group_table.qza \
--o-visualization group_table.qzv

qiime feature-table merge-seqs \
--i-data 16154R_repseq.qza 15341R_repseq.qza 15219R_repseq.qza 15218R_repseq.qza 14231R_repseq.qza \
--o-merged-data repseq_All.qza

qiime phylogeny align-to-tree-mafft-fasttree \
--i-sequences repseq_All.qza \
--o-alignment aligned_repseq_All.qza \
--o-masked-alignment masked_aligned_repseq_All.qza \
--o-tree tree_unroot.qza \
--p-n-threads ${Nproc} \
--o-rooted-tree tree_root.qza

qiime feature-classifier classify-sklearn \
--i-classifier ${CLASSIFIER} \
--i-reads repseq_All.qza \
--o-classification taxonomy_gtdb.qza \
--p-n-jobs ${Nproc}

qiime metadata tabulate \
--m-input-file taxonomy_gtdb.qza \
--o-visualization taxonomy_gtdb.qzv

cp *.qzv ${ResultDir}/q2_viz/
cp *.qza ${WRKDIR}/
#remove the large sequence artifacts that are not needed post table creation.
cd ${WRKDIR}; rm *_inseqs-demux*.qza; rm *aligned_repseq*
