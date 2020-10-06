#!/bin/bash

#SBATCH --account=round-np
#SBATCH --partition=round-np
#SBATCH -N 1
#SBATCH -J SM_1
#SBATCH -t 24:50:00 
#SBATCH -o 

# Notes: 
# 1. Canu (minion assembler), will try to submit sbatch jobs itself. Part of canu. Make sure to pass useGrid=false to Canu. Figure how to make better use of Canu's job submission.
# 2. SqueezeMeta conda env must have anvi already installed for conversion after squuezemeta.
# 3. This job script is single sample job as is. Must pass SampleFile variable at job export.

export SampleFile=${SampleFile}

####################################
ProjectName=
WRKDIR=
# SampleFile= Pass sample file var to job script to run each sample simultaneously
# See "/uufs/chpc.utah.edu/common/home/sundar-group1/Reference/reference_seq_dbs/SqueezeMetaDB/test/test.samples" for ref
# Example: NO HEADER. Each read id in first column will have Project name in sequential mode. File name is relative to raw directory required as input
# SRR1927149      SRR1927149_1.fastq.gz   pair1
# SRR1927149      SRR1927149_2.fastq.gz   pair2
# SRR1929485      SRR1929485_1.fastq.gz   pair1
# SRR1929485      SRR1929485_2.fastq.gz   pair2
SCRATCH=
mkdir -p $SCRATCH
minIONReadsDir=
SqueezeMetaRefDir=/uufs/chpc.utah.edu/common/home/sundar-group1/Reference/reference_seq_dbs/SqueezeMetaDB/db
# Num threads 2 - node num processors
NumThreads=24
########################################

###########################
module use ~/MyModules; module load miniconda3/latest; conda activate SqueezeMeta
configure_nodb.pl $SqueezeMetaRefDir
###########################

cd $SCRATCH

SqueezeMeta.pl -m sequential --minion -s ${SampleFile} -f ${minIONReadsDir} -t $NumThreads -assembly_options "useGrid=false minReadLength=500"

# Need to install anvio and SquezeMeta in same place

for projectdb in BC0*
    do 
    anvi-load-sqm.py -p $projectdb -o ${projectdb}_anvi --num-threads $NumThreads --run-scg-taxonomy --profile-SCVs
done
