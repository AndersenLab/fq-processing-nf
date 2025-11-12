/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTP                   } from '../modules/nf-core/fastp'
include { SPECIES_IDENTIFICATION  } from '../subworkflows/local/species_identification'
// include { ALIGN_READS             } from './subworkflows/local/align_reads'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow FQ_PROCESSING {

    take:
    ch_samples
    ch_genomes
    subsample
    skip_trimming
    skip_species_check
    ch_versions

    main:
    if (skip_trimming) {
        ch_trimmed    = ch_samples
        ch_fastp_json = Channel.empty()
        ch_fastp_html = Channel.empty()
        ch_fastp_log  = Channel.empty()
    } else {
        // TODO Add minlength argument = 20
        FASTP (
            ch_samples.map { it: [it[0], it[1], "${workflow.projectDir}/assets/NO_FILE"] },
            false,
            false,
            false,
        )
        ch_versions   = ch_versions.mix(FASTP.out.versions)
        ch_trimmed    = FASTP.out.reads
        ch_fastp_json = FASTP.out.json
        ch_fastp_html = FASTP.out.html
        ch_fastp_log  = FASTP.out.log
    }

    if (skip_species_check) {
        ch_species_stats     = Channel.empty()
        ch_identified        = ch_trimmed
        ch_mismatched        = Channel.empty()
        ch_species_report    = Channel.empty()
        ch_mismatched_report = Channel.empty()
    } else {
        SPECIES_IDENTIFICATION(
            ch_trimmed,
            ch_genomes,
            params.subsample,
            ch_versions
        )
        ch_versions          = SPECIES_IDENTIFICATION.out.versions
        ch_species_stats     = SPECIES_IDENTIFICATION.out.species_stats
        ch_identified        = SPECIES_IDENTIFICATION.out.identified
        ch_mismatched        = SPECIES_IDENTIFICATION.out.mismatched
        // ch_species_report    = SPECIES_IDENTIFICATION.out.species_report
        // ch_mismatched_report = SPECIES_IDENTIFICATION.out.mismatched_report
    }

    // If reads were trimmed, organize them by their identified species or as needing review

    // ALIGN_READS(
    //     ch_identified,
    //     ch_genomes
    // )
    // ch_versions.mix(ALIGN_READS.out.versions)
    // ch_aligned        = ALIGN_READS.out.aligned
    // ch_aligned_report = ALIGN_READS.out.report

    emit:
    identified    = ch_identified
    mismatched    = ch_mismatched
    // fastp_json = ch_fastp_json
    // fastp_html = ch_fastp_html
    // fastp_log  = ch_fastp_log
    species_stats = ch_species_stats
    versions      = ch_versions
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
