#!/bin/bash

#SBATCH --account=round-np
#SBATCH --partition=round-shared-np
#SBATCH -n 20
#SBATCH -J TrainClassifier
#SBATCH -t 12:50:00 
#SBATCH -D /uufs/chpc.utah.edu/common/home/u0210816/
#SBATCH -o /uufs/chpc.utah.edu/common/home/u0210816/temp.outerror

# Just training taxonomic classifier on input set

SciKitVersion=0.21.2

#### Env #######
module use ~/MyModules
module load miniconda3/latest
source activate qiime2-2019.7

cd /uufs/chpc.utah.edu/common/home/round-group1/reference_seq_dbs/qiime2/training-feature-classifiers

qiime feature-classifier extract-reads \
  --i-sequences 99_otus_seq.qza \
  --p-f-primer TGCCTACGGGNBGCASC \
  --p-r-primer GCGACTACNVGGGTATCTAAT \
  --p-min-length 100 \
  --p-max-length 600 \
  --o-reads 99otus_seq_Prok34Primers.qza

qiime feature-classifier fit-classifier-naive-bayes \
  --i-reference-reads 99otus_seq_Prok34Primers.qza \
  --i-reference-taxonomy 99_ref_tax.qza \
  --o-classifier gg_13_8_v34Prok_classifier_sk${SciKitVersion}.qza