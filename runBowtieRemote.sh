#!/bin/bash -l

module load gcc
module load bioinfo-tools
module load bowtie/0.12.8

# names of the forward and reverse reads
forward=$1 # (`ls /dev/shm/$1/f*.fastq`)
#reverse=(`ls /dev/shm/$1/r*.fastq`)

# ===============
# the following piece of code determines the 
# the FASTQ  header.
# it locates the first line starting with "@" such that 
# there is a line starting with "+" two lines below
arr1=(`head -n 11 $forward |grep -n '^@'|cut -f1 -d:`) 
#echo \@ ${arr1[@]}
arr2=(`head -n 11 $forward |grep -n '^+'|cut -f1 -d:`)
#echo + ${arr2[@]}

headerArrLength=${#arr1[@]}
#echo headerArrLength is $headerArrLength

for (( i=0; i<${headerArrLength}; i++ ));do
	if [[ ${arr2[@]} ==  *$((${arr1[$i]} + 2))*  ]];then
#		echo yes! ${arr1[$i]}
	break
	fi
done
startLine=${arr1[$i]} 
echo $startLine
# prints the starting line
sed -ne "$startLine"p $forward
#===============

name=tair10dataset4;
cd /scratch/$1
/usr/bin/time -f "%e Alignment  Real Time (secs)"\
		bowtie  -S -p 16 a_thaliana -X 600 --chunkmbs 400  -M 1 --best -1 <(sed -ne $startLine',$p'  $forward) -2<(sed -ne "$startLine"',$p'  $reverse)  $name.sam
