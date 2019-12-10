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

// make channels for FastQ and Reference
Channel.fromPath( params.reads ).ifEmpty { exit 1, "Cannot find any file matching: ${params.reads} !" }.into { ch_reads }
Channel.fromPath( params.reference ).ifEmpty { exit 1, "Cannot find any file matching: ${params.reference} !" }.into { ch_ref }
Channel.fromPath( params.targets ).ifEmpty { exit 1, "Cannot find any file matching: ${params.targets} !" }.into { ch_targets }
// Get parameters
fastq = params.reads
reference = params.reference
targets = params.targets
study = params.study
threads = params.threads

gstride = params.gstride
target_proximity = params.target_proximity
offtarget_level = params.offtarget_level



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



process run_pipeline{
      publishDir "results", mode: 'copy'

      input:
      file ref from ch_ref
      file reads from ch_reads
      file targets from ch_targets

      output:
      file '*' into output_ch

      script:
      """
      python ${workflow.projectDir}/bin/generate_config.py ${params.study} ${params.reference} ${params.targets} ${params.fastq} --threads ${params.threads}

      cp  ${workflow.projectDir}/bin/* .

      cp -r ${workflow.projectDir}/assets .

      snakemake -j ${params.threads} all
      """
}


process render_report{
      publishDir "results/report", mode: 'copy'
      errorStrategy 'ignore'

      input:
      file '*' from output_ch

      output:
      file "*.html" into report_ch

      script:
      """
      R --slave -e 'rmarkdown::render("cas9_enrichment_report.Rmd", "html_document")'
      mv cas9_enrichment_report.html cas9_enrichment_report_${params.study}.html
      """

}


workflow.onComplete {
      log.info "Pipeline Complete"

}
