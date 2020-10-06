#!/bin/bash

#SBATCH --account=round-np
#SBATCH --partition=round-shared-np
#SBATCH -J h2_s1_out_check
#SBATCH -n 12
#SBATCH -t 03:30:00
#SBATCH -D /uufs/chpc.utah.edu/common/home/u0210816/Projects/CRC_19/CCPS_19/
#SBATCH -o /uufs/chpc.utah.edu/common/home/u0210816/Projects/CRC_19/CCPS_19/jobs/h2_check_step1_out.outerror

#### Directory paths and vars to change ######
SCRATCH=/scratch/general/nfs1/u0210816/CCPS/MetaGen
RAWDIR1=/uufs/chpc.utah.edu/common/home/round-group2/CCPS-III_raw_MetaOmics/Metagenomes/15411R/Fastq
RAWDIR2=/uufs/chpc.utah.edu/common/home/round-group2/CCPS-III_raw_MetaOmics/Metagenomes/15412R/Fastq
RAWDIR3=
RAWDIR4=
WRKDIR=/uufs/chpc.utah.edu/common/home/round-group2/CCPS_III_Metagenomics_19-08/
NThreads=12 # Should not be more than processes requested by sbatch directive
# Host reference bowtie2 index to remove reads from
HostRefIndex=/uufs/chpc.utah.edu/common/home/u0210816/round-group1/reference_seq_dbs/kneaddata_db/Homo_sapiens
# The chocophlan pan-genome reference database (Reqd. in Step 2)
FullNTDB=/uufs/chpc.utah.edu/common/home/u0210816/round-group1/reference_seq_dbs/humann2/chocophlan/
# The UniRef Protein database (Usually the UniRef90, EC-filtered subset)(Reqd. in Step 3)
ProtDB=/uufs/chpc.utah.edu/common/home/u0210816/round-group1/reference_seq_dbs/humann2/uniref/
# Shared nucleotide index, created in step 2 from joint-taxonomic profile (Reqd. in Step 3)
# JointNTDB=/uufs/chpc.utah.edu/common/home/round-group1/reference_seq_dbs/humann2/chocophlan
##############################################
# Critical: Add mock or ID of control/calibrator sample to be removed from genefamily outputs:
MockID=15411X45

######## Containers ##########################
Humann2Container="docker://biobakery/humann2:0.0.1"
Metaphlan2Container="docker://biobakery/metaphlan2:2.7.7"
KneaddataContainer="docker://biobakery/kneaddata:0.0.1"
###############################################

module load singularity/3.3.0

# Setup
export SINGULARITYENV_SCRATCH=${SCRATCH}
export SINGULARITYENV_RAWDIR=${RAWDIR}
export SINGULARITYENV_WRKDIR=${WRKDIR}
export SINGULARITYENV_NThreads=${NThreads}
export SINGULARITYENV_HostRefIndex=${HostRefIndex}
export SINGULARITYENV_SampleID=${SampleID}
export SINGULARITYENV_JointNTDB=${JointNTDB}

# Header line file: "SampleID	kd1	kd2	mp1	mp2	hu1	hu2	hu3"
# Corresponds to "SampleID	<kneaddata single read cleaned> <kneaddata both pairs.gz> <metaphlan_result> <metaphlan_bt2> <genefamilies> <pathabundance> <pathcoverage>"
printf "#SampleID\tkd_clean1\tkd_paired\tmp_out\tmp_align\tgenefam\tpathabund\tpathcov\n" > ${SCRATCH}/output_report.txt

# 1) Get samples IDs that should have run and file presence-absence for each
rawdir=( $RAWDIR1 $RAWDIR2 $RAWDIR3 $RAWDIR4 )
for dir in "${rawdir[@]}"
do cd ${dir}
	for f in *R1_001.fastq.gz
		do SampleID=`echo ${f} | cut -f 1 -d '_'`

		# 1) Check outputs and report
		cd ${SCRATCH}/
		[ -f kneaddata/${SampleID}/${SampleID}_paired_1.fastq ] && kd1="1" || kd1="0"
		[ -f kneaddata/${SampleID}/${SampleID}_paired_R1R2.fastq.gz ] && kd2="1" || kd2="0"
		[ -f metaphlan_out/${SampleID}_MPout.txt ] && mp1="1" || mp1="0"
		[ -f metaphlan_out/${SampleID}.bowtie2.bz2 ] && mp2="1" || mp2="0"
		[ -f humann2_out/${SampleID}/${SampleID}_paired_R1R2_genefamilies.tsv ] && hu1="1" || hu1="0"
		[ -f humann2_out/${SampleID}/${SampleID}_paired_R1R2_pathabundance.tsv ] && hu2="1" || hu2="0"
		[ -f humann2_out/${SampleID}/${SampleID}_paired_R1R2_pathcoverage.tsv ] && hu3="1" || hu3="0"
		printf "${SampleID}\t${kd1}\t${kd2}\t${mp1}\t${mp2}\t${hu2}\t${hu2}\t${hu3}\n" >> ${SCRATCH}/output_report.txt

	# Finish loop for all sample IDs in a rawdir
	done
# Finish raw dir loop
done

# 2) Check if all present, else exit
cd ${SCRATCH}
# if grep -qP "\t0\s" ${SCRATCH}/output_report.txt
	# then echo "Missing results found, exiting."
	# exit
	# else echo "All results files present. Moving to norm and join."
# fi

# 3) Move key outputs to WRKDIR:
mkdir -p ${WRKDIR}/humann2_step1_individ_archives/kneaddata_logs
mkdir -p ${WRKDIR}/humann2_step1_individ_archives/metaphlan2_out
mkdir -p ${WRKDIR}/humann2_step1_individ_archives/metaphlan2_aligns
mkdir -p ${WRKDIR}/humann2_step1_individ_archives/humann2_logs
mkdir -p ${WRKDIR}/humann2_step1_individ_archives/humann2_results

for dir in "${rawdir[@]}"
do cd ${dir}
	for f in *R1_001.fastq.gz
		do SampleID=`echo ${f} | cut -f 1 -d '_'`

		# 1) Copy outputs to directory for archive and joining
		cd ${SCRATCH}/
		cp kneaddata/${SampleID}/${SampleID}.log ${WRKDIR}/humann2_step1_individ_archives/kneaddata_logs/
		cp metaphlan_out/${SampleID}_MPout.txt ${WRKDIR}/humann2_step1_individ_archives/metaphlan2_out/
		cp metaphlan_out/${SampleID}.bowtie2.bz2 ${WRKDIR}/humann2_step1_individ_archives/metaphlan2_aligns/
		cp humann2_out/${SampleID}/${SampleID}_paired_R1R2_genefamilies.tsv ${WRKDIR}/humann2_step1_individ_archives/humann2_results/
		cp humann2_out/${SampleID}/${SampleID}_paired_R1R2_pathabundance.tsv ${WRKDIR}/humann2_step1_individ_archives/humann2_results/
		cp humann2_out/${SampleID}/${SampleID}_paired_R1R2_pathcoverage.tsv ${WRKDIR}/humann2_step1_individ_archives/humann2_results/
		cp humann2_out/${SampleID}/${SampleID}_paired_R1R2_humann2_temp/${SampleID}_paired_R1R2.log ${WRKDIR}/humann2_step1_individ_archives/humann2_logs/
		cp humann2_out/${SampleID}/${SampleID}_paired_R1R2_humann2_temp/${SampleID}_paired_R1R2_metaphlan_bugs_list.tsv ${WRKDIR}/humann2_step1_individ_archives/humann2_logs/
	# Finish loop for all sample IDs in a rawdir
	done
# Finish raw dir loop
done

# 4) Make joined files, normalize, rename, etc.
cd ${WRKDIR}/humann2_step1_individ_archives/
singularity exec ${Humann2Container} humann2_join_tables -i humann2_results/ --file_name pathabundance.tsv -o ../all_w_cont_pathabund.tsv
singularity exec ${Humann2Container} humann2_join_tables -i humann2_results/ --file_name pathcoverage.tsv -o ../all_w_cont_pathcov.tsv
singularity exec ${Humann2Container} humann2_join_tables -i humann2_results/ --file_name genefamilies.tsv -o ../all_w_cont_genefam.tsv
cd ${WRKDIR}
#Normalize the raw RPK (reads per kilobase) by each samples mapped sequence depth.
singularity exec ${Humann2Container} humann2_renorm_table --input all_w_cont_genefam.tsv --output all_w_cont_genefam_CoPM.tsv --units cpm --update-snames
singularity exec ${Humann2Container} humann2_renorm_table --input all_w_cont_genefam.tsv --output all_w_cont_genefam_relab.tsv --units relab --update-snames
# Echo the header IDs now, so I can create the metadata headers to turn these into .pcl files
head -n 1 all_w_cont_genefam.tsv > header_all_w_cont.txt


# For now, same as above but with removing the mock artificial community sample. Should implement check for presence of MockID and multiples to remove.
cd ${WRKDIR}/humann2_step1_individ_archives/
cp -r humann2_results/ tmp_humann2_results/
rm tmp_humann2_results/${MockID}*.tsv
singularity exec ${Humann2Container} humann2_join_tables -i tmp_humann2_results/ --file_name pathabundance.tsv -o ../all_pathabund.tsv
singularity exec ${Humann2Container} humann2_join_tables -i tmp_humann2_results/ --file_name pathcoverage.tsv -o ../all_pathcov.tsv
singularity exec ${Humann2Container} humann2_join_tables -i tmp_humann2_results/ --file_name genefamilies.tsv -o ../all_genefam.tsv
rm -R tmp_humann2_results/
cd ${WRKDIR}
#Normalize the raw RPK (reads per kilobase) by each samples mapped sequence depth.
singularity exec ${Humann2Container} humann2_renorm_table --input all_genefam.tsv --output all_genefam_CoPM.tsv --units cpm --update-snames
singularity exec ${Humann2Container} humann2_renorm_table --input all_genefam.tsv --output all_genefam_relab.tsv --units relab --update-snames
#Same as above, but removing the UNMAPPED, UNINTEGRATED, and UNGROUPED.
singularity exec ${Humann2Container} humann2_renorm_table --input all_genefam.tsv --output all_genefam_CoPM_noUN.tsv --units cpm --update-snames -s n
singularity exec ${Humann2Container} humann2_renorm_table --input all_genefam.tsv --output all_genefam_relab_noUN.tsv --units relab --update-snames -s n
# Echo the header IDs now, so I can create the metadata headers to turn these into .pcl files
head -n 1 all_genefam.tsv > header_all.txt

# 5) Create archive of unjoined key outputs in WRKDIR:
cd ${WRKDIR}
tar -cf - humann2_step1_individ_archives/ | pigz -p ${NThreads} > humann2_step1_individ_res_logs.tar.gz
