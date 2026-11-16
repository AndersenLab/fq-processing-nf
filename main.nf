#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    andersenlab/fq-processing-nf
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/andersenlab/fq-processing-nf
----------------------------------------------------------------------------------------
*/

nextflow.enable.types = true

// Global default params, used in configs
params {

    // TODO nf-core: Specify your pipeline's command line flags
    // Input options
    samplesheet: String            = null
    genomesheet: String            = null
    subsample: Integer             = 10000
    min_length: Integer            = 20
    min_mapping: BigDecimal        = 0.95
    fastq_path_prefix: String      = ""
    skip_trimming: Boolean         = false
    skip_species_check: Boolean    = false
    merge_external_bams: Boolean   = false

    publish_dir_mode: String       = 'copy'
    monochrome_logs: Boolean       = false
    version: Boolean               = false
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_fq-processing-nf_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_fq-processing-nf_pipeline'
include { FQ_PROCESSING           } from './workflows/fq_processing'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

record SampleRecord {
    meta: Map
    fastqs: List<Path>
}
record BamRecord {
    meta: Map
    bam: Path
    bai: Path
    coverage: Path?
}
record StatsRecord {
    stats: Path
    passed: Path
    failed: Path
}
record VersionRecord {
    tool: String
    version: String
}

workflow {

    main:
    log.info ""
    log.info "samplesheet                         = ${params.samplesheet}"
    log.info "genomesheet                         = ${params.genomesheet}"
    log.info "fastq_path_prefix                   = ${params.fastq_path_prefix}"
    log.info "Output directory                    = ${workflow.outputDir}"
    log.info "skip_trimming                       = ${params.skip_trimming}"
    if (!params.skip_trimming){
        log.info "min_length                          = ${params.min_length}"
    }
    log.info "skip_species_check                  = ${params.skip_species_check}"
    if (!params.skip_species_check){
        log.info "subsample                           = ${params.subsample}"
        log.info "min_mapping                         = ${params.min_mapping}"
    }
    log.info "merge_external_bams                 = ${params.merge_external_bams}"
    if (!nextflow.version.matches('>=26.04.0')) {
        error("This pipeline requires Nextflow version 26.0 or higher, but you are running version ${nextflow.version}")
    }

    // SUBWORKFLOW: Run initialisation tasks
    
    pipeline_initialization_call = PIPELINE_INITIALISATION (
        params.version,
        params.monochrome_logs,
        args,
        workflow.outputDir
    )

    //
    // WORKFLOW: Run main workflow
    //
    fq_processing_call = FQ_PROCESSING (
        pipeline_initialization_call.samples,
        pipeline_initialization_call.genomes,
        pipeline_initialization_call.existing_bams
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        workflow.outputDir,
        params.monochrome_logs,
    )

    publish:
    trimmed       = fq_processing_call.trimmed
    aligned       = fq_processing_call.aligned
    species_stats = fq_processing_call.species_stats
    mapping_stats = fq_processing_call.mapping_stats
    versions      = fq_processing_call.versions
}

output {
    trimmed: Channel<SampleRecord> {
        path { sample ->
            sample.fastqs >> (params.skip_trimming ? null : "trimmed/")
        }
        mode params.publish_dir_mode
        overwrite true
    }
    aligned: Channel<BamRecord> {
        path { sample ->
            sample.bam >> "aligned/${sample.meta.species}/"
            sample.bai >> "aligned/${sample.meta.species}/"
            sample.coverage >> "aligned/${sample.meta.species}/"
        }
        mode params.publish_dir_mode
        overwrite true
    }
    species_stats: Value<StatsRecord> {
        path {sample -> 
            sample.stats >> (params.skip_species_check ? null : "species_check/")
            sample.passed >> (params.skip_species_check ? null : "species_check/")
            sample.failed >> (params.skip_species_check ? null : "species_check/")
        }
        mode params.publish_dir_mode
        overwrite true
    }
    mapping_stats: Value<Path> {
        path "aligned/"
        mode params.publish_dir_mode
        overwrite true
    }
    versions: Value<Path> {
        path "./"
        mode params.publish_dir_mode
        overwrite true
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
