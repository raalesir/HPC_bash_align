hpcPipeline.sh
-------------
Implements 'standard' pipeline: reads mapping and SNP calling with the Bowtie and Samtools correspondingly.
Both Bowtie and Samtools are utilizing the multicore  parallelization.
The script is to be submitted to SLURM.

distributedBowtie.sh and runBowtieRemote.sh
------------------
The scripts provide a workflow aimed to introduce a MPI-like parallelization for the short reads alignment with the Bowtie.
The raw data for the pair-ended reads is in the "*.fastq.bz2" archives, located on the high-performance storage, providing up to 80 Gbits/sec traffic.
The storage can stripe the data, meaning that the different pieces of the file can be placed on the different physical HDDs.
The dd utility is used to pull the chunks of the data from the storage to the local node scratches in _parallel_.
After the chunks delivery, the chunks are passed some filtering to satisfy the Bowtie format.
The mapping is done in the multicore regime, OMP parallelism. The resulting SAM files are pushed back to the high-preformance storage.

The _distributedBowtie.sh_ is being submitted to SLURM and calls the _runBowtieRemote.sh_ remotely on each submitted node.
