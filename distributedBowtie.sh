#!/bin/bash -l
#SBATCH -A staff --qos=short #b2013023 #--qos=short 
#SBATCH -p node
#SBATCH -n 2 -N 2
#SBATCH -t 0:15:00
#SBATCH -J dist_test

# parameters for a series ${series}, experiment number ${step}
step=4
series=11

#get the full path for the short read files
file1=`readlink -f ../reads1.fq`
file2=`readlink -f ../reads2.fq`
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

# dd copies chunks of the files to each node in parallel
# and the reference genome after...
ofPath=/dev/shm/$SLURM_JOB_ID
for ((i=0; i<$nNodes; i++));do
	skip=$(($i*$count)); echo $skip
	ssh  ${nodes[$i]} "mkdir -p $ofPath &&\
		dd if=$file2 skip=$skip bs=$bs count=$count  of=$ofPath/r$i.fastq iflag=direct &&\
		dd if=$file1 skip=$skip bs=$bs count=$count  of=$ofPath/f$i.fastq iflag=direct &&\
	 	cp -r $genome $ofPath && echo node ${nodes[$i]} done!" &
done
wait
echo finished distributing the data!
outDir=striped$series\_$nNodes
echo creating out dir: $outDir
mkdir -p $outDir

# collecting the data distribution time, and the transfer speed
cat slurm-$SLURM_JOB_ID.out |grep bytes|cut -f6 -d' '|sort > $outDir/dist$step 
cat slurm-$SLURM_JOB_ID.out |grep copied|cut -f8 -d' '|sort >$outDir/speed$step

# remotely executing the "runBowtieRemote.sh" to align the reads
# and copying the SAM files from the nodes to the
# $root/$outDir/mergedSam$i files
root=`pwd`
for ((i=0; i<$nNodes; i++));do
	(ssh ${nodes[$i]} '/bin/bash -sl'  < ./runBowtieRemote.sh $ofPath && echo $ofPath &&	
	echo copying SAM file from ${nodes[$i]}
	/usr/bin/time -f "%e Merging  Real Time (secs)" ssh ${nodes[$i]} " cat $ofPath/*.sam > $root/$outDir/mergedSam$i" ) #&&
#	rm $root/$outDir/mergedSam$i) &\
done
wait

# retrieving the information about alignment and SAM merging times
cat slurm-$SLURM_JOB_ID.out |grep Alignment|cut -f1 -d' '|sort >$outDir/alignment$step
cat slurm-$SLURM_JOB_ID.out |grep Merging|cut -f1 -d' '|sort >$outDir/merging$step
cat slurm-$SLURM_JOB_ID.out >$outDir/log$step

