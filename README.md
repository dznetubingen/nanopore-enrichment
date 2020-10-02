# Nanopore Cas9 Enrichment Analysis
Pipeline for analysis of enrichment experiments using the Cas9-Nanopore protocol.

# Usage

## Enrichment QC Pipeline
A standard pipeline call can be executed like this:
```
nextflow run dznetubingen/nanopore-enrichment --fastq all_pass_20191017_STCL49_Cas9_Probes1345.fastq --reference Homo_sapiens.GRCh38.dna.primary_assembly.fa --targets targets.bed --study study_id --threads 6 -profile standard
```

The pipeline requires the following parameters:
* --fastq

This parameter specifies the path to the fastq files (can also be fastq.gz) from the sequencing run

* --reference

Path to the reference genome

* -- targets

The target region of the enrichment experiment in bed format.

* --study

Some ID of the experiment

* -profile

Which Nextflow profile to use. To use the pre-generated docker container, simply use the 'standard' profile.


## Repeat counting with STRique
This is not part of this pipeline, but a usual downstream step, which is why I explain how to run STRique here as well.
Once the pipeline has finished succesfully, we first have to transform the output BAM file to SAM format using the following command:

```
samtools view -h -o file_name.sam file_name.bam
```
Samtools can be easily installed from conda or used from the docker container 'tristankast/cas_pipeline', which is downloaded for the pipeline anyway.
The BAM file can be found in results/Analysis/Minimap2.

Next, we need the original fast5 files from the Nanopore run. Then, to run STRique, we fire up the ontainer giesselmann/strique as follows
```
docker run -ti -v /path/to/your/data:/data giesselmann/strique
```
Your data is now mounted under the '/data' directory.


As a first step of STRique, we have to index the fast5 files. You can do this with the following command (from within the container):
```
python3 /app/scripts/STRique.py index --recursive --out_prefix fast5_pass fast5_pass/ > sample_enrichment.fofn 
```

Finally we can run the actual search for the repeat:
```
python3 /app/scripts/STRique.py count --t 20 --algn file_name.sam sample_enrichment.fofn /app/models/r9_4_450bps.model c9orf72_hg38_config_noChr.tsv > sample.strique.tsv 
```
The file 'c9orf72_hg38_config_noChr.tsv' specifies the repeat to look for. It can be found in the 'assets' directory of this repository.
Each repeat and its length are now contained in 'sample.strique.tsv'.

### Analysis of STRique results
You can visualize the results of the STRique repeat counting in histograms using the script 'generate_repeat_histogram.R' in the 'bin' directory.
Just specify the path to the STRique results file and run the script. It will produce two histograms of repeat lengths, one for all repeats and one for repeats that
have been filtered for small repeat lengths (default cutoff is 10, can be changed in the script).



