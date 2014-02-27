#!/bin/bash -l

module load gcc
module load bioinfo-tools
module load bowtie/0.12.8

# names of the forward and reverse read files
forward=(`ls $1/f*.fastq`)
reverse=(`ls $1/r*.fastq`)
echo "forward reads"  $forward
echo "reverse reads"  $reverse

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
echo "start line " $startLine
# prints the starting line
sed -ne "$startLine"p $forward
#===============

# some name for the SAM file...
name=tair10_TEST;
cd $1
/usr/bin/time -f "%e Alignment  Real Time (secs)"\
		bowtie  -S -p 16 a_thaliana -X 600 --chunkmbs 400  -1 <(sed -ne $startLine',$p'  $forward) -2<(sed -ne "$startLine"',$p'  $reverse)  $name.sam
