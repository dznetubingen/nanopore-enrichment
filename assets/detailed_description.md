# Description
This is a detailed description on how to run the QC pipeline for an enrichment run and then determine the repeat lengths.

# Data preparation
First, we have to get the sequencing data in the form of **fastq** and **FastA** files. All analysis will be done on the **Bob** server (172.21.49.157), while the sequencing data is typically stored on tu-hac. This might change in the future.

Locate the sequencing run on tu-hac, by logging in their with:
```
ssh ashu@tu-hac.dzne.de
```

Then loacte to the directory containing the enrichment runs:
```
cd /volume1/Nanopore/NanoporeFinal/c9_enrichment
```

There, select the directory of interest and change into it (using **cd**). The FastQ and FastQ files are typically contained in some directories called **fastq_pass** and **fast5_pass**. For the FastQ files, you have to concatenate all of the files into one file by using the **cat** command, e.g.:
```
cat fastq_pass/*.fastq > all_files.fastq
```
This would create the file **all_files.fastq** which now contains all the FastQ files of the directory.

Next, we need to copy the newly created FastQ files and the folder **fast5_pass** to a directory on Bob, which we have to create there. For instance, let's use the directory:
**/mnt/md0/kevin/nanopore_enrichment/nanopore_test** for this purpose. We can copy over the files with **scp** or a similar tool:

```
scp -r fast5_pass kevin@172.21.49.157:/mnt/md0/kevin/nanopore_enrichment/nanopore_test
```
Of course, adjust the user name to your own.

# Running the QC Pipeline
Once we have the data copied to a directory on the server, we need to make sure to have a Reference genome available (hg38) and a BED file specifying the target range. Now, we can run the QC pipeline:

```
nextflow run dznetubingen/nanopore-enrichment --fastq all_pass_20190905_DN19_Probes1345.fastq --reference ../GRCh38.primary_assembly.genome.fa --targets targets.bed --study test --threads 20 -profile standard
```

Of course, you have to get the NextFlow executable first. At this step, it is important to use the **full paths** to the files, and not the relative paths, as I've done above - otherwise the pipeline will fail.

# Repeat Counting
Once the QC pipeline is finished, or the reads have been mapped to the reference genome using *minimap2* manually, you can run the STRique pipeline. First, transform the BAM file (alignment output) to SAM format using samtools:

```
samtools view -h -o file_name.sam file_name.bam
```

Then, make sure the fast5_pass folder is available and fire up the STRique docker container:

```
docker run -ti -v /path/to/your/data:/data giesselmann/strique
```

Now you can run the indexing like so:
```
python3 /app/scripts/STRique.py index --recursive --out_prefix fast5_pass fast5_pass/ > sample_enrichment.fofn ```

And finally the repeat counting step:

```
python3 /app/scripts/STRique.py count --t 20 --algn file_name.sam sample_enrichment.fofn /app/models/r9_4_450bps.model c9orf72_hg38_config_noChr.tsv > sample.strique.tsv 
 ```

 ## Analysis of STRique results
 You can visualize the results of the STRique repeat counting in histograms using the script 'generate_repeat_histogram.R' in the 'bin' directory. Just specify the path to the STRique results file and run the script. It will produce two histograms of repeat lengths, one for all repeats and one for repeats that have been filtered for small repeat lengths (default cutoff is 10, can be changed in the script).




