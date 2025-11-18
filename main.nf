#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    andersenlab/fq-processing-nf
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/andersenlab/fq-processing-nf
----------------------------------------------------------------------------------------
*/

if (nextflow.version < 25.0) {
    nextflow.preview.output = true
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

workflow {

    main:

    
    // SUBWORKFLOW: Run initialisation tasks
    
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.samplesheet,
        params.genomesheet,
        params.fastq_path_prefix
    )

    //
    // WORKFLOW: Run main workflow
    //
    FQ_PROCESSING (
        PIPELINE_INITIALISATION.out.samples,
        PIPELINE_INITIALISATION.out.genomes,
        params.subsample,
        params.min_mapping,
        params.skip_trimming,
        params.skip_species_check,
        PIPELINE_INITIALISATION.out.versions
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    // PIPELINE_COMPLETION (
    //     params.outdir,
    //     params.monochrome_logs,
    // )

    //
    // Collate versions output
    //
    FQ_PROCESSING.out.versions
        .collectFile ( name: 'workflow_software_versions.txt', sort: true, newLine: true )
        .set { ch_collated_versions }

    publish:
    versions      = ch_collated_versions
    species_stats = FQ_PROCESSING.out.species_stats
    identified    = FQ_PROCESSING.out.identified
    mismatched    = FQ_PROCESSING.out.mismatched
    aligned       = FQ_PROCESSING.out.aligned
    mapping_stats = FQ_PROCESSING.out.mapping_stats
    // fastp_json = FQ_PROCESSING.out.fastp_json
    // fastp_html = FQ_PROCESSING.out.fastp_html
    // fastp_log  = FQ_PROCESSING.out.fastp_log
}

output {
    versions {
        path '.'
        mode params.publish_dir_mode
    }
    species_stats {
        path '.'
        mode params.publish_dir_mode
    }
    identified {
        path { sample ->
            if (sample.single_end) {
                sample.read1 >> "trimmed/${sample.species}/${sample.id}.${sample.suffix}"
            } else {
                sample.read1 >> "trimmed/${sample.species}/${sample.id}_1R.${sample.suffix}"
                sample.read2 >> "trimmed/${sample.species}/${sample.id}_2R.${sample.suffix}"
            }
        }
        mode params.publish_dir_mode
    }
    mismatched {
        path { sample ->
            if (sample.single_end) {
                sample.read1 >> "to_review/${sample.id}.${sample.suffix}"
            } else {
                sample.read1 >> "to_review/${sample.species}/${sample.id}_1R.${sample.suffix}"
                sample.read2 >> "to_review/${sample.species}/${sample.id}_2R.${sample.suffix}"
            }
        }
        mode params.publish_dir_mode
    }
    aligned {
        path { sample ->
            sample.bam >> "mapped/${sample.species}/${sample.id}.bam"
            sample.bai >> "mapped/${sample.species}/${sample.id}.bam.bai"
        }
        mode params.publish_dir_mode
    }
    mapping_stats {
        path '.'
        mode params.publish_dir_mode
    }
//     fastp_json {
//         path 'trimmed'
//         mode params.publish_dir_mode
//     }
//     fastp_html {
//         path 'trimmed'
//         mode params.publish_dir_mode
//     }
//     fastp_log {
//         path 'trimmed'
//         mode params.publish_dir_mode
//     }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
