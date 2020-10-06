#!/bin/bash

#SBATCH --account=round-np
#SBATCH --partition=round-shared-np
#SBATCH --ntasks=24
#SBATCH --time=48:00:00
#SBATCH -o /uufs/chpc.utah.edu/common/home/u0210816/Projects/WoodRatITS_19/jobs/Q2_ITS_preprocess_v2.1_Qiime2CondaEnv.outerror
#SBATCH -J ITSpp

module load fastx_toolkit
# Miniconda3 CHPC module is not very useful on its own b/c no write permissions in install dir, but
# after creating user module, one can load own python environments with miniconda there
# Requires: ITSxpress plugin
module use ~/MyModules; module load miniconda3/latest

############
RefSeqsArtifact=/uufs/chpc.utah.edu/common/home/round-group1/reference_seq_dbs/qiime2/UNITE_ITS/sh_refs_qiime_ver7_dynamic_s_01.12.2017.qza
TrainedClassifierArtifact=/uufs/chpc.utah.edu/common/home/round-group1/reference_seq_dbs/qiime2/UNITE_ITS/naive_bayes_classifier_sh_refs_qiime_ver7_dynamic_s_01.12.2017.qza
Nproc=22
RUNID=17950R
RAWDIR=/uufs/chpc.utah.edu/common/home/round-group1/raw_illumina_seq/17950R_WoodRatITS/Reads
SCRATCH=/scratch/general/nfs1/u0210816/WoodRatITS/
WRKDIR=/uufs/chpc.utah.edu/common/home/u0210816/Projects/WoodRatITS_19
Qiime2CondaVersion=qiime2-2019.7
############
mkdir -p ${WRKDIR}/metadata
mkdir -p ${WRKDIR}/q2_viz
mkdir -p ${SCRATCH}
source activate ${Qiime2CondaVersion}

cd ${RAWDIR}


# Make manifest file on the fly, place in metadata file in project directory
echo -e "sample-id\tforward-absolute-filepath\treverse-absolute-filepath" > ${WRKDIR}/metadata/manifest_${RUNID}.txt
for f in *R1_001.fastq.gz
do
  SAMPLEID=`basename ${f%%_*}`
    echo -e "${SAMPLEID}\t${PWD}/${f}\t${PWD}/${f%R1_001.fastq.gz}R2_001.fastq.gz" >> ${WRKDIR}/metadata/manifest_${RUNID}.txt
done
cd ${SCRATCH}

# Make manifest file on the fly, place in metadata file in project directory
# Manifest formats have changed. Here is for different version of manifest file
# echo "sample-id,absolute-filepath,direction" > ${WRKDIR}/metadata/manifest_${RUNID}.txt
# for f in *R1_001.fastq.gz
# do
#   SAMPLEID=`basename ${f%%_*}`
#   echo "${SAMPLEID},${PWD}/${f},forward" >> ${WRKDIR}/metadata/manifest_${RUNID}.txt
#   echo "${SAMPLEID},${PWD}/${f%R1_001.fastq.gz}R2_001.fastq.gz,reverse" >> ${WRKDIR}/metadata/manifest_${RUNID}.txt
# done
# cd ${SCRATCH}

ManifestFile=${WRKDIR}/metadata/manifest_${RUNID}.txt

qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' --input-path ${ManifestFile} --output-path inseq_PE_demux.qza --input-format PairedEndFastqManifestPhred33V2

qiime vsearch join-pairs --i-demultiplexed-seqs inseq_PE_demux.qza --o-joined-sequences PE_demux_join.qza --p-minmergelen 300

qiime quality-filter q-score-joined --i-demux PE_demux_join.qza --o-filtered-sequences PE_demux_join_filt.qza --o-filter-stats PE_demux_join_filt_stats.qza --p-min-quality 10

rm -R temp_export
qiime tools export --input-path PE_demux_join_filt.qza --output-path temp_export

conda deactivate

rm -R RCd
mkdir -p RCd
cp temp_export/MANIFEST RCd/MANIFEST
cp temp_export/metadata.yml RCd/metadata.yml
cd temp_export/
for f in *.gz; do gunzip -c $f | fastx_reverse_complement -Q 33 -z -o ../RCd/${f}; done
cd ../
rm -R temp_export

source activate ${Qiime2CondaVersion}

qiime tools import --type SampleData[SequencesWithQuality] --input-path RCd/ --output-path PE_demux_join_filt_RCd.qza
# rm -R RCd

qiime itsxpress trim-single --i-per-sample-sequences PE_demux_join_filt_RCd.qza --p-region ITS2 --p-threads ${Nproc} --o-trimmed PE_demux_join_filt_RCd_ITSx.qza

qiime deblur denoise-other \
--i-demultiplexed-seqs PE_demux_join_filt_RCd_ITSx.qza \
--i-reference-seqs ${RefSeqsArtifact} \
--p-trim-length 150 \
--o-table table.qza \
--o-representative-sequences rep_set.qza \
--o-stats deblur_perSampleStats.qza \
--p-sample-stats \
--p-jobs-to-start ${Nproc}

qiime feature-table summarize \
--i-table table.qza \
--o-visualization table.qzv

qiime feature-classifier classify-sklearn \
--i-classifier ${TrainedClassifierArtifact} \
--i-reads rep_set.qza \
--o-classification taxonomy.qza \
--p-n-jobs 12

qiime metadata tabulate \
--m-input-file taxonomy.qza \
--o-visualization taxonomy.qzv

qiime taxa barplot \
--i-table table.qza \
--i-taxonomy taxonomy.qza \
--o-visualization taxbarplots_AllSamplesNoFilter.qzv



# Copy key outputs back to wrkdir:
cp *.qza ${WRKDIR}; cp *.qzv ${WRKDIR}/q2_viz
