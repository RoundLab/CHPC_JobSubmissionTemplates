<!-- TOC -->


<!-- /TOC -->

# Description
Templates for running high-throughput sequencing processing and/or analysis pipelines on CHPC via job submission.
Users generally just need to fill in a few variables in intro sections in order to run pipelines. Default values are provided where applicable.

# Templates
The following bash scripts templates with sbatch directives (aka "slurm scripts") are included:

## Q2_16S_PreProcessSingleLane_Prok34.slurm
An sbatch submission template that employs Qiime2 (with a docker container) to process a single lane of demultiplexed Parired-end fastq sequences derived from Round Lab's "Prok34" 16S rRNA gene primers (Takahashi, et al.). Trim lengths and QC are a good standard for high-quality runs with these primers, but plots should be inspected to ensure appropriate trim lengths. Overview:
- Pull sequences from remote source (on Gnomex, pull entire Fastq folder to downloads and retrieve "FDT Command Line")
- Make manifest file, read in seqs to qiime artifact
- Trim primers, overlap and denoise with deblur
- Call taxonomy for representative sequences, make table and phyogeny
- "Prok34" refers to the 16S primers from Takahashi, et al. that target V3 and V4 regions and have added 2 bp pads.

## Q2_16S_PreProcessMultipleLane_Prok34.slurm
- As for the corresponding SingleLane version, except can process 16S data from multiple lanes.
- Requires a mapping file to map sequence IDs from samples sequenced in more than one lane.

## Q2_TrainClassifier_Prok34.slurm
- Just a couple commands to extract a 16S region and retrain a scikit-learn classifier

## Q2_UNITE-ITS_TrainClassifier.slurm
- Pull UNITE fungal ITS sequence database and taxonomy and train classifier with Qiime2.

## (deprecated) Q2_ITS_preprocess_v2.1_Qiime2CondaEnv_deblur.slurm
- Sequence preprocessing using Deblur for denoising and ITSx on fungal ITS2 sequences.
- (Deprecated) ITSxpress plugin can now take reverse sequences as in our format. Also, prefer DADA2 for ITS seqs.

## h2_step1_singleSamplePerNode.slurm
- Uses biobakery tools with metagenomic reads to:
	1. Clean and filter host seqs with kneaddata
	2. Identify taxa to map to with metaphlan2 and describe metagenomic taxa present.
	3. Perform nucleotide alignments and translated alingments and pathway calcs with Humann2 pipeline and Map reads.
- Requires that the sequence project ID (eg. 12345X10) is provided as variable when submitting script. See note in template.
