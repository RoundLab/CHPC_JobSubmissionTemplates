#!/bin/bash

#SBATCH --account=round
#SBATCH --partition=notchpeak-shared
#SBATCH -J h2_${SampleID}
#SBATCH -n 16
#SBATCH -t 18:00:00
#SBATCH -D /uufs/chpc.utah.edu/common/home/u0210816/Projects/CRC_19/CCPS_19/
#SBATCH -o /uufs/chpc.utah.edu/common/home/u0210816/Projects/CRC_19/CCPS_19/jobs/metagen_h2_step1.outerror

module load singularity/3.3.0


#### Directory paths and vars to change ######
SCRATCH=/scratch/general/nfs1/u0210816/CCPS/MetaGen
RAWDIR1=/uufs/chpc.utah.edu/common/home/round-group2/CCPS-III_raw_MetaOmics/Metagenomes/15411R/Fastq
RAWDIR2=/uufs/chpc.utah.edu/common/home/round-group2/CCPS-III_raw_MetaOmics/Metagenomes/15412R/Fastq
RAWDIR3=
RAWDIR4=
WRKDIR=/uufs/chpc.utah.edu/common/home/round-group2/CCPS_III_Metagenomics_19-08
NThreads=14 # Should not be more than processes requested by sbatch directive
# Host reference bowtie2 index to remove reads from
HostRefIndex=/uufs/chpc.utah.edu/common/home/u0210816/round-group1/reference_seq_dbs/kneaddata_db/Homo_sapiens
# The chocophlan pan-genome reference database (Reqd. in Step 2)
FullNTDB=/uufs/chpc.utah.edu/common/home/u0210816/round-group1/reference_seq_dbs/humann2/chocophlan/
# The UniRef Protein database (Usually the UniRef90, EC-filtered subset)(Reqd. in Step 3)
ProtDB=/uufs/chpc.utah.edu/common/home/u0210816/round-group1/reference_seq_dbs/humann2/uniref/
# Metaphlan2 directory MUST be provided, as metaphlan2 will always try to pull update and needs writable location
MetaphlanDB=/uufs/chpc.utah.edu/common/home/u0210816/round-group1/reference_seq_dbs/metaphlan2/
##############################################
######## Containers ##########################
Humann2Container="docker://biobakery/humann2:0.0.1"
Metaphlan2Container="docker://biobakery/metaphlan2:2.7.7"
KneaddataContainer="docker://biobakery/kneaddata:0.0.1"
###############################################

# Setup
rm -R ${SCRATCH}/kneaddata/${SampleID}
rm -R ${SCRATCH}/metaphlan_out/${SampleID}
rm -R ${SCRATCH}/humann2_out/${SampleID}
mkdir -p ${SCRATCH}/raw
mkdir -p ${SCRATCH}/kneaddata
mkdir -p ${SCRATCH}/metaphlan_out
mkdir -p ${SCRATCH}/humann2_out
mkdir -p ${WRKDIR}/kneaddata_logs
mkdir -p ${WRKDIR}/metaphlan2_alignments
export SINGULARITYENV_SCRATCH=${SCRATCH}
export SINGULARITYENV_RAWDIR=${RAWDIR}
export SINGULARITYENV_WRKDIR=${WRKDIR}
export SINGULARITYENV_NThreads=${NThreads}
export SINGULARITYENV_HostRefIndex=${HostRefIndex}
export SINGULARITYENV_SampleID=${SampleID}
export SINGULARITYENV_JointNTDB=${JointNTDB}
export SINGULARITYENV_MetaphlanDB=${MetaphlanDB}

mkdir -p ${SCRATCH}/tmp_xdg_runtime_dir
export XDG_RUNTIME_DIR=${SCRATCH}/tmp_xdg_runtime_dir

rawdir=( $RAWDIR1 $RAWDIR2 $RAWDIR3 $RAWDIR4 )
for dir in "${rawdir[@]}"
do cd ${dir}
cp ${SampleID}_*.gz ${SCRATCH}/raw/
done

cd ${SCRATCH}/raw

# for f in *R1_001.fastq.gz
#
# do SampleID=`echo ${f} | cut -f 1 -d '_'`

gunzip ${SampleID}_*.gz
# Kneaddata run. Options include: renaming by short run ID, increasing bowtie2 processes, do NOT include discordant pairs, and NOT keeping intermediate files (HumanGenome alignments)
echo "TIME: START Kneaddata = `date +"%Y-%m-%d %T"`"
for f in ${SampleID}_*_R1_001.fastq
	do singularity exec ${KneaddataContainer} kneaddata --input ${f} --input ${f%_R1_001.fastq}_R2_001.fastq -db $HostRefIndex --output ${SCRATCH}/kneaddata/${SampleID} --output-prefix ${SampleID} --bowtie2-options="--very-fast" --bowtie2-options="--no-discordant" -t $NThreads --max-memory 1200m
done
echo "TIME: END Kneaddata = `date +"%Y-%m-%d %T"`"

# Metaphlan 2 run.  Only running on 1st read. Note, positional arguments for input and output.
# Note, metaphlan2 is run as part of humann2 command as well, but running it separatly allows more control and doesn't add much time on cluster.
cd $SCRATCH/kneaddata/${SampleID}
echo "TIME: START Metaphlan2 = `date +"%Y-%m-%d %T"`"
singularity exec ${Metaphlan2Container} metaphlan2.py ${SampleID}_paired_1.fastq ${SCRATCH}/metaphlan_out/${SampleID}_MPout.txt --sample_id_key ${SampleID} --bowtie2out ${SCRATCH}/metaphlan_out/${SampleID}.bowtie2.bz2 --nproc $NThreads --input_type fastq -t rel_ab --bowtie2db ${MetaphlanDB}
echo "TIME: END Metaphlan2 = `date +"%Y-%m-%d %T"`"


# Remove unpaired reads. Remove "contaminating" human reads, for metagenomes (could be useful from metatranscriptomes)
rm ${SampleID}_*unmatched*.fastq; rm ${SampleID}.trimmed.*.fastq
# Retain a copy of the kneaddata log files which contain useful numbers of cleaned reads
cp ${SampleID}.log ${WRKDIR}/kneaddata_logs/
cp ${SCRATCH}/metaphlan_out/${SampleID}.bowtie2.bz2 ${WRKDIR}/metaphlan2_alignments
# Remove raw reads from scratch
rm ${SCRATCH}/raw/${SampleID}*.fastq

# Concatenate cleaned read 1 and read 2 and zip to save space (gzipped files can input into humann2, but not kneaddata)
echo "TIME: START Cat and Zip = `date +"%Y-%m-%d %T"`"
cat ${SampleID}_paired_[12].fastq > ${SampleID}_paired_R1R2.fastq
# rm ${SampleID}_paired_[12].fastq
pigz -p $NThreads ${SampleID}_paired_R1R2.fastq
echo "TIME: END Cat and Zip = `date +"%Y-%m-%d %T"`"

echo "TIME: START Humann2 = `date +"%Y-%m-%d %T"`"
singularity exec ${Humann2Container} humann2 --input ${SampleID}_paired_R1R2.fastq.gz --output ${SCRATCH}/humann2_out/${SampleID} --nucleotide-database ${FullNTDB} --threads $NThreads --protein-database ${ProtDB} --prescreen-threshold 0.00001
echo "TIME: END Humann2 = `date +"%Y-%m-%d %T"`"

cd ${SCRATCH}/raw

# done
