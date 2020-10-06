#!/bin/bash

#SBATCH --account=round-np
#SBATCH --partition=round-shared-np
#SBATCH -n 24
#SBATCH --time=12:00:00
#SBATCH -o /uufs/chpc.utah.edu/common/home/u0210816/Projects/WoodRatITS_19/jobs/UNITE_classifier_training.outerror
#SBATCH -J TrainITS

# Method: Pulls reference sets from UNITE database, unzip, import to qiime object and train classifier.
# See UNITE donwloads page: https://unite.ut.ee/repository.php
# Here, and usually, I use the "dynamic" species hypothesis clustering set. I think this is the ideal reference for taxa calling.
# I also use the provided set that was trimmed by ITSx. The download includes a "developer" folder with the untrimmed set tht has flanking SSU, LSU seqs not trimmed.

module use ~/MyModules; module load miniconda3/latest
Qiime2CondaVersion=qiime2-2020.2
source activate ${Qiime2CondaVersion}

# Directory for RefSeqs
REFSEQDIR=/uufs/chpc.utah.edu/common/home/round-group1/reference_seq_dbs/qiime2/UNITE_ITS
# Link to path of sequences
WebHostedRef=https://files.plutof.ut.ee/public/orig/98/AE/98AE96C6593FC9C52D1C46B96C2D9064291F4DBA625EF189FEC1CCAFCF4A1691.gz
VersionDate=2020.02.04

cd ${REFSEQDIR}
wget -O DownloadedRefSeqs.tar.gz ${WebHostedRef}
tar -xzf DownloadedRefSeqs.tar.gz
cd sh_qiime_release*
InputRepSeqs=`ls sh_refs_qiime*_dynamic_*.fasta`
InputTaxa=`ls sh_taxonomy*_dynamic_*.txt`

qiime tools import \
--input-path ${InputRepSeqs} \
--output-path ../${InputRepSeqs}.qza \
--type 'FeatureData[Sequence]'

qiime tools import \
--input-path ${InputTaxa} \
--type FeatureData[Taxonomy] \
--input-format HeaderlessTSVTaxonomyFormat \
--output-path ../${InputTaxa}.qza

qiime feature-classifier fit-classifier-naive-bayes \
--i-reference-reads ../${InputRepSeqs}.qza \
--i-reference-taxonomy ../${InputTaxa}.qza \
--o-classifier ../naive_bayes_classifier_${InputRepSeqs%.fasta}_${VersionDate}.qza

cd ../
rm DownloadedRefSeqs
rm -R sh_qiime_release*
