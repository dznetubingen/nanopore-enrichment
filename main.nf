#!/usr/bin/env nextflow


def helpMessage() {
    log.info"""
    =========================================
     Cas9 enrichment
    =========================================
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run tristankast/cas9_enrichment --reads reads.fastq.gz --reference reference.fastq --targets targets.bed --gstride 100 --target_proximity 5000 --offtarget_level 40 --name run_name
    Mandatory arguments:
      --reads                       Path to the reads
      --reference                   Path to the unzip reference genome
      --targets                     Path to the bed file containing the location of the enriched region
      -profile                      Hardware config to use
    Options:
      --gstride                     Bin size for summarising depth of coverage across the reference_genome
      --target_proximity            Distance up- and down-stream of ontarget BED for defining target proximal mapping
      --offTarget                   Threshold for defining off-target mapping
    Other options:
      --outdir                      The output directory where the results will be saved
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.
    """.stripIndent()
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}

custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}

if(params.name == null){
  custom_runName = workflow.runName
}

gstride = params.gstride
target_proximity = params.target_proximity
offtarget_level = params.offtarget_level

Channel
        .fromPath( params.reads )
        .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads} !" }
        .into { ch_reads_copy; ch_reads_minimap2; ch_onTargetReadDump; ch_offTargetReadDump}

Channel
        .fromPath( params.reference )
        .ifEmpty { exit 1, "Cannot find any reference file matching: ${params.reads} !" }
        .into {ch_reference_copy; ch_reference_minimap; ch_reference_R}

Channel
        .fromPath( params.targets )
        .ifEmpty { exit 1, "Cannot find any target region file matching: ${params.reads} !" }
        .into {ch_targets_copy; ch_targets_R}


// Header log info
log.info "========================================="
log.info " hybrid-assembly"
log.info "========================================="
def summary = [:]
summary['Run Name']               = custom_runName ?: workflow.runName
summary['Reads file']             = params.reads
summary['Reference file']         = params.reference
summary['Target regions file']    = params.targets
summary['Max Memory']             = params.max_memory
summary['Max CPUs']               = params.max_cpus
summary['Max Time']               = params.max_time
summary['Output dir']             = params.outdir
summary['Working dir']            = workflow.workDir
summary['Container']              = workflow.container
summary['Current home']           = "$HOME"
summary['Current user']           = "$USER"
summary['Current path']           = "$PWD"
summary['Script dir']             = workflow.projectDir
summary['Config Profile']         = workflow.profile
summary['gstride']                = params.gstride
summary['target_proximity']       = params.target_proximity
summary['offtarget_level']        = params.offtarget_level
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="


//if [ ! -d "$PWD/RawData" ]; then
//  mkdir $PWD/RawData
//fi


process copy_data {
      input:
      file reads from ch_reads_copy
      file reference from ch_reference_copy
      file targets from ch_targets_copy

      script:
      """
      #!/usr/bin/env python
      import sys
      import os

      if not os.path.isdir('$PWD/RawData/'):
        os.system("mkdir $PWD/RawData/")

      if not os.path.isdir('$PWD/ReferenceData/'):
        os.system("mkdir $PWD/ReferenceData/")

      os.system("cp $targets $PWD/RawData/")
      os.system("cp $reads $PWD/RawData/")
      os.system("cp $reference $PWD/ReferenceData/")

      os.system("chmod 777 ${workflow.projectDir}/harvest.R")
      print("cp ${workflow.projectDir}/harvest.R $PWD/harvest.R")
      os.system("cp ${workflow.projectDir}/harvest.R $PWD/harvest.R")
      """
}


/*process copy_Rscript {
  script:
  """
  cp ${workflow.projectDir}/harvest.R $PWD/harvest.R
  """
}*/


process minimap_index {
      publishDir "$PWD/ReferenceData", mode: 'copy'

      input:
      file reference from ch_reference_minimap

      output:
      file "*mmi" into ch_minimap2_index

      script:
      """
      minimap2 -t 15 -d ${reference.baseName}.mmi  $reference
      """
  }

process minimap_run {

      input:
      file index from ch_minimap2_index
      file reads from ch_reads_minimap2


      output:
      file "${custom_runName}.sam" into ch_minimap2_sam

      script:
      """
      minimap2 -2 -a -x map-ont --MD -R '@RG\\tID:${custom_runName}\\tSM:${custom_runName}' -t 15 $index $reads > ${custom_runName}.sam
      """
}

process samtools_view {
      publishDir "$PWD/Analysis/Minimap2", mode: 'copy', pattern: '*unmapped*'

      input:
      file samfile from ch_minimap2_sam

      output:
      file ""+custom_runName+".unsorted.bam" into ch_samtools_view_bam_mapped
      file ""+custom_runName+".unmapped.bam" into ch_samtools_view_bam_unmapped

      script:
      """
      samtools view -b -@ 15 -F 0x4 -U ${custom_runName}.unmapped.bam $samfile > ${custom_runName}.unsorted.bam
      """
}

process samtools_sort {
      publishDir "$PWD/Analysis/Minimap2", mode: 'copy'

      input:
      file bamfile from ch_samtools_view_bam_mapped

      output:
      file "${custom_runName}.bam" into ch_samtools_sort_bam

      script:
      """
      samtools sort -@ 15 $bamfile > ${custom_runName}.bam
      """
}

process samtools_index {
      publishDir "$PWD/Analysis/Minimap2", mode: 'copy'

      input:
      file bamfile_sorted from ch_samtools_sort_bam

      output:
      file "*bai*" into ch_samtools_index
      file "delay_file.txt" into ch_delay

      script:
      """
      samtools index -@ 15 $bamfile_sorted
      touch delay_file.txt
      """
}

// render quality values from unmapped reads
process samtools_view_unmapped {
      publishDir "$PWD/Analysis/Minimap2", mode: 'copy'

      input:
      file unmapped_bamfile from ch_samtools_view_bam_unmapped
      file "delay_file.txt" from ch_delay

      output:
      file "${custom_runName}.unmapped.quals" into ch_samtools_view_qual_unmapped
      file "delay_file.txt" into ch_delay_2

      script:
      """
      samtools view -@ 5 -O sam $unmapped_bamfile | awk '{{print \$11}}' > ${custom_runName}.unmapped.quals

      """
}

// perform the R preprocess
process Rpreprocess {
      publishDir "$PWD/Analysis/R", mode: 'copy'

      input:
      file targets from ch_targets_R
      file reference from ch_reference_R

      file "delay_file.txt" from ch_delay_2

      output:
      //file "*OnTarget.mappedreads" into ch_R_onTarget
      //file "*OffTarget.mappedreads" into ch_R_offTarget

      file "delay_file.txt" into ch_delay_3, ch_delay_4

      script:
      """
      Rscript $PWD/harvest.R $targets ${custom_runName} $reference $gstride $target_proximity $offtarget_level 16 $PWD
      chmod -R 777 $PWD/Analysis/OffTarget
      chmod -R 777 $PWD/Analysis/OnTarget
      """
}

process onTargetReadDump{
      publishDir "$PWD/Analysis/OnTarget", mode: 'copy'
      params.onTarget = "$PWD/Analysis/OnTarget/${custom_runName}.OnTarget.mappedreads"
      ch_R_onTarget = Channel.fromPath(params.onTarget)

      input:
      file allReads from ch_onTargetReadDump
      file onTargetReads from ch_R_onTarget

      file "delay_file.txt" from ch_delay_3

      output:
      file "${custom_runName}.OnTarget.fastq" into ch_onTargetReadDump_fastq

      script:
      """
      seqtk subseq $allReads $onTargetReads > ${custom_runName}.OnTarget.fastq
      """
}

process offTargetReadDump{
      publishDir "$PWD/Analysis/OffTarget", mode: 'copy'
      params.offTarget = "$PWD/Analysis/OffTarget/${custom_runName}.OffTarget.mappedreads"
      ch_R_offTarget = Channel.fromPath(params.offTarget)

      input:
      file allReads from ch_offTargetReadDump
      file offTargetReads from ch_R_offTarget

      file "delay_file.txt" from ch_delay_4

      output:
      file "${custom_runName}.OffTarget.fastq" into ch_offTargetReadDump_fastq

      script:
      """
      seqtk subseq $allReads $offTargetReads > ${custom_runName}.OffTarget.fastq
      """
}



workflow.onComplete {
      log.info "Pipeline Complete"

}
