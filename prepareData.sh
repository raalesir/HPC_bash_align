#!/bin/bash -l
#SBATCH -A staff --qos=short #b2013023 #--qos=short 
#SBATCH -p node
#SBATCH --nodelist=m141,m167,m163,m159
#SBATCH -n 4 -N 4
#SBATCH -t 0:15:00
#SBATCH -J dist_test

# parameters for a series ${series}, experiment number ${step}
step=4
series=11

#get the full path for the short read files
file1=`readlink -f /pica/v6/staff/raalesir/reads1.fq`
file2=`readlink -f /pica/v6/staff/raalesir/reads2.fq`
#full path to the directory with the Bowtie indexed genome
genome=`readlink -f indexes`

#node list from the SLURM
nodes=(`scontrol show hostnames $SLURM_JOB_NODELIST`)
echo nodes in use: ${nodes[@]}
nNodes=${#nodes[@]}
echo 'number of nodes: '${nNodes}

# determine the file size
fSize=(`wc -c $file1`)


# calculates the number of blocks ${count}
# of size ${bs} for a chunk ${blockPerNode}
blockPerNode=$(($fSize/$nNodes))
bs=$((512*1024*10))
count=$(($blockPerNode/$bs))


echo partition size is: $blockPerNode

# dd copies in parallel chunks of data for each node
# and the reference genome after.
for ((i=0; i<$nNodes; i++));do
	skip=$(($i*$count)); echo $skip
	ssh  ${nodes[$i]} "mkdir -p /dev/shm/$SLURM_JOB_ID &&\
		dd if=$file2 skip=$skip bs=$bs count=$count  of=/dev/shm/$SLURM_JOB_ID/r$i.fastq iflag=direct &&\
		dd if=$file1 skip=$skip bs=$bs count=$count  of=/dev/shm/$SLURM_JOB_ID/f$i.fastq iflag=direct &&\
	 	cp -r $genome /dev/shm/$SLURM_JOB_ID && echo node ${nodes[$i]} done!" &
done
wait
echo finished distributing the data!
echo creating out dir: striped$series\_$nNodes
mkdir -p striped$series\_$nNodes

# collecting the data distribution time, and the transfer speed
cat slurm-$SLURM_JOB_ID.out |grep bytes|cut -f6 -d' '|sort > striped$series\_$nNodes/dist$step 
cat slurm-$SLURM_JOB_ID.out |grep copied|cut -f8 -d' '|sort >striped$series\_$nNodes/speed$step

# remotely executing the "cutLines.sh" to align the reads
# and copying the SAM files from the nodes to the
# $root/striped$series\_$nNodes/mergedSam$i files
root=`pwd`
for ((i=0; i<$nNodes; i++));do
	(ssh ${nodes[$i]} '/bin/bash -sl'  < ./runBowtieRemote.sh $SLURM_JOB_ID && 	
	echo copying SAM file from ${nodes[$i]}
	/usr/bin/time -f "%e Merging  Real Time (secs)" ssh ${nodes[$i]} " cat /dev/shm/$SLURM_JOB_ID/*.sam > $root/striped$series\_$nNodes/mergedSam$i" &&
	rm $root/striped$series\_$nNodes/mergedSam$i) &\
done
wait

# retrieving the information about alignment and SAM merging times
cat slurm-$SLURM_JOB_ID.out |grep Alignment|cut -f1 -d' '|sort >striped$series\_$nNodes/alignment$step
cat slurm-$SLURM_JOB_ID.out |grep Merging|cut -f1 -d' '|sort >striped$series\_$nNodes/merging$step
cat slurm-$SLURM_JOB_ID.out >striped$series\_$nNodes/log$step

