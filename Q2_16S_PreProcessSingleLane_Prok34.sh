#!/bin/bash

#SBATCH --account=round-np
#SBATCH --partition=round-shared-np
#SBATCH -n 18
#SBATCH -J Q2_PreProcessProk34
#SBATCH -t 24:50:00
#SBATCH -D
#SBATCH -o

#	Values under "User-defined variables" and "param" sections must be filled in.

#### User-defined variables #################################
RUNID=
# Raw sequences directory can be anywhere, but if keeping on shared round lab space stick with syntax there (i.e. RunID_Description) (will be created if not existing)
RAWDIR=
# Directory on scratch file system for intermediate files (will be created if not existing)
SCRATCH=
# The results directory for key outputs. Generally, your project directory or within it. (will be created if not existing)
ResultDir=
# The qiime2 container image (update version tag as needed. Year.Month after "core:")
ContainerImage=docker://qiime2/core:2019.4
# FDT download command ENCLOSED IN DOUBLE QUOTES
FDTCL=
##############################################################
#### Param ###################################################
Nproc=14
JoinedTrimLength=392
FPrimerSeqToTrim=TGCCTACGGGNBGCASCAG
RPrimerSeqToTrim=GCGACTACNVGGGTATCTAATCC
# Minimum size after merge is set to Rprimer+Fprimer+10. Permissive, but remove most primer dimers
MinMergeLength=189
MaxDiffs=30
# Classifier will likely need to be retrained with differnt qiime versions as scikit classifier different versions are not compatible.
CLASSIFIER=/uufs/chpc.utah.edu/common/home/round-group1/reference_seq_dbs/qiime2/training-feature-classifiers/gg_13_8_v34Prok_classifier_sk0.20.2.qza
##############################################################
#### Setup ###################################################
module load singularity
mkdir -p ${RAWDIR}
mkdir -p ${SCRATCH}
mkdir -p ${SCRATCH}/tmp_XDG
mkdir -p ${ResultDir}/q2_viz; mkdir -p ${ResultDir}/metadata
#############################################################
#### SINGULARITYENV (no longer necessary) ###################
XDG_RUNTIME_DIR=${SCRATCH}/tmp_XDG
export SINGULARITYENV_RAWDIR=${RAWDIR}
export SINGULARITYENV_ResultDir=${ResultDir}
export SINGULARITYENV_RUNID=${RUNID}
export SINGULARITYENV_UHOME=${HOME}
export SINGULARITYENV_MANIFEST=${MANIFEST}
export SINGULARITYENV_SCRATCH=${SCRATCH}
export SINGULARITYENV_XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}
export SINGULARITYENV_Nproc=${Nproc}
export SINGULARITYENV_FPrimerSeqToTrim=${FPrimerSeqToTrim}
export SINGULARITYENV_RPrimerSeqToTrim=${RPrimerSeqToTrim}
export SINGULARITYENV_MinMergeLength=${MinMergeLength}
export SINGULARITYENV_MaxDiffs=${MaxDiffs}
export SINGULARITYENV_JoinedTrimLength=${JoinedTrimLength}
export SINGULARITYENV_CLASSIFIER=${CLASSIFIER}
##################################################################
cd ${RAWDIR}

# Pull newest fdt app and retrieve sequences.
echo "TIME: START pull seqs = `date +"%Y-%m-%d %T"`"
wget http://hci-bio-app.hci.utah.edu/fdt/fdtCommandLine.jar
${FDTCL}
rm fdtCommandLine.jar
echo "TIME: END pull seqs = `date +"%Y-%m-%d %T"`"

# Manifest formats have changed. Here is for different version of manifest file
# Make manifest file on the fly, place in metadata file in project directory
# echo -e "sample-id\tforward-absolute-filepath\treverse-absolute-filepath" > ${ResultDir}/metadata/manifest_${RUNID}.txt
# for f in ${RUNID}/Fastq/*R1_001.fastq.gz
# do
#   SAMPLEID=`basename ${f%%_*}`
#   echo -e "${SAMPLEID}\t${PWD}/${f}\t${PWD}/${f%R1_001.fastq.gz}R2_001.fastq.gz" >> ${ResultDir}/metadata/manifest_${RUNID}.txt
# done
# cd ${SCRATCH}

# Make manifest file on the fly, place in metadata file in project directory
echo "sample-id,absolute-filepath,direction" > ${ResultDir}/metadata/manifest_${RUNID}.txt
for f in ${RUNID}/Fastq/*R1_001.fastq.gz
do
  SAMPLEID=`basename ${f%%_*}`
  echo "${SAMPLEID},${PWD}/${f},forward" >> ${ResultDir}/metadata/manifest_${RUNID}.txt
  echo "${SAMPLEID},${PWD}/${f%R1_001.fastq.gz}R2_001.fastq.gz,reverse" >> ${ResultDir}/metadata/manifest_${RUNID}.txt
done
cd ${SCRATCH}

echo "TIME: START import = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' \
--input-path ${ResultDir}/metadata/manifest_${RUNID}.txt \
--output-path ${SCRATCH}/inseqs-demux.qza \
--input-format PairedEndFastqManifestPhred33

singularity exec ${ContainerImage} qiime demux summarize \
  --i-data ${SCRATCH}/inseqs-demux.qza \
  --o-visualization ${SCRATCH}/inseqs-demux-summary.qzv
echo "TIME: END import = `date +"%Y-%m-%d %T"`"

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
--p-maxdiffs ${MaxDiffs} \
--p-allowmergestagger \
--verbose

singularity exec ${ContainerImage} qiime demux summarize \
  --i-data PE-demux_trim_join.qza \
  --o-visualization PE-demux_trim_join.qzv

# At this stage plots should be inspected to infer the JoinedTrimLength for deblur. Generally, high qualtiy runs with same primers will hold.

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

singularity exec ${ContainerImage} qiime feature-table tabulate-seqs \
--i-data repseq.qza \
--o-visualization repseq.qzv

echo "TIME: START phylogeny = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime phylogeny align-to-tree-mafft-fasttree \
--i-sequences repseq.qza \
--o-alignment aligned_repseq.qza \
--o-masked-alignment masked_aligned_repseq.qza \
--o-tree tree_unroot.qza \
--o-rooted-tree tree_root.qza
echo "TIME: END phylogeny = `date +"%Y-%m-%d %T"`"

echo "TIME: START taxonomy = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime feature-classifier classify-sklearn \
--i-classifier ${CLASSIFIER} \
--i-reads repseq.qza \
--o-classification taxonomy.qza \
--p-n-jobs 12

singularity exec ${ContainerImage} qiime metadata tabulate \
--m-input-file taxonomy.qza \
--o-visualization taxonomy.qzv

singularity exec ${ContainerImage} qiime taxa barplot \
--i-table table.qza \
--i-taxonomy taxonomy.qza \
--o-visualization taxbarplots_AllSamplesNoFilter.qzv
echo "TIME: END taxonomy = `date +"%Y-%m-%d %T"`"

# Copy visualization results to ResultDir and key artifacts
cp ${SCRATCH}/*.qzv ${ResultDir}/q2_viz/
cp ${SCRATCH}/table.qza ${ResultDir}/; cp ${SCRATCH}/repseq.qza ${ResultDir}/; cp ${SCRATCH}/taxonomy.qza ${ResultDir}/; cp ${SCRATCH}/tree_root.qza ${ResultDir}/; cp ${SCRATCH}/tree_unroot.qza ${ResultDir}/
mv deblur.log ${ResultDir}/
# cp ${SCRATCH}/inseqs-demux.qza ${ResultDir}/ # Generally, it is not useful and too big to copy full input sequence artifacts

# Cleanup
rm ${SCRATCH}/*.qza; rm ${SCRATCH}/*.qzv
