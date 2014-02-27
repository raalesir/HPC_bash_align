#!/bin/bash -l

#SBATCH -A b2013023 #--qos=short
#SBATCH -p node
#SBATCH -n 1 
#SBATCH -t 5:00:00
#SBATCH -J align

module unload pgi
module load gcc
module load bioinfo-tools
#module load bwa
module load bowtie/0.12.8
module load samtools/0.1.19


date
cores=16
dir=${cores}cores_III_5
mkdir -p ${dir}
timeFile=/proj/b2013023/nobackup/testDataThalianaArchive/${dir}/timings
touch ${timeFile}

name=schneb
file1=`readlink -f datasetIII_1.fastq.bz2` #SRR611084_1.fastq.bz2`
#file2=`readlink -f SRR611085_1.fastq.bz2`
file2=`readlink -f datasetIII_2.fastq.bz2` #SRR611084_2.fastq.bz2`
#file4=`readlink -f SRR611085_2.fastq.bz2`
genome=`readlink -f indexes`
genomeIndexName=a_thaliana
genomeFastaName=TAIR10_all.fas


for ((i=0; i<3; i++));do
	/usr/bin/time -o ${timeFile} -a -f "%e sec running Bowtie" \
		bowtie  -S -p${cores}  ${genomeIndexName}  -X 600 --chunkmbs 500  -1<(pbzip2 -dc ${file1}) -2<(pbzip2 -dc ${file2})  ${dir}/$name.sam


	echo "converting to BAM"
	/usr/bin/time -o ${timeFile} -a -f "%e sec  converting to BAM"\
		samtools view  -@ ${cores}  -bS -o ${dir}/$name.bam ${dir}/$name.sam

	echo "sorting BAM"
	/usr/bin/time -o ${timeFile} -a -f "%e  sec sorting BAM"\
		samtools sort  -@ ${cores} -m 8G  ${dir}/$name.bam ${dir}/$name.sorted

	samtools faidx indexes/${genomeFastaName}

	echo "indexing the sorted BAMs"
	/usr/bin/time -o ${timeFile} -a -f "%e  sec for indexing the sorted  BAM "\
		samtools index  ${dir}/$name.sorted.bam 

	#samtools mpileup -uf indexes/TAIR10_all.fas $name.sorted.bam >${dir}/snp_$name

	echo "calling mpileup" 
	{ time  samtools view -H ${dir}/$name.sorted.bam | grep "\@SQ" | sed 's/^.*SN://g' | cut -f 1 | \
		xargs -I {} -n 1 -P ${cores} sh -c "samtools mpileup -BQ0 -d 100000 -uf indexes/${genomeFastaName} -r {} ${dir}/$name.sorted.bam | \
			bcftools view -vcg - > ${dir}/tmp.{}.vcf 2>/dev/null" ; }  2>>${timeFile}

done

date
