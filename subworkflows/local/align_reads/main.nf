/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { BWA_MEM as AR_BWA_MEM                       } from '../../../modules/nf-core/bwa/mem'
include { PICARD_ADDORREPLACEREADGROUPS               } from '../../../modules/nf-core/picard/addorreplacereadgroups'
include { PICARD_MARKDUPLICATES                       } from '../../../modules/nf-core/picard/markduplicates'
include { COMPILE_DEDUP_STATS                         } from '../../../modules/local/compile_dedup_stats'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ALIGN_READS {

    take:
    ch_samples
    ch_genomes
    ch_versions

    main:

    ch_samples
        .combine ( ch_genomes )
        .filter { row -> row[0].species == row[2].id }
        .map { row -> [[id:row[0].id, species:row[0].species], row[3]] }
        .set { ch_sample_genomes }

    ch_no_file = Channel.fromPath ( "${workflow.projectDir}/assets/NO_FILE" )
        .map { row -> [[], row] }
        .first ( )

    AR_BWA_MEM (
        ch_samples,
        ch_sample_genomes,
        ch_no_file,
        true
    )
    ch_versions = ch_versions.mix ( AR_BWA_MEM.out.versions )

    AR_BWA_MEM.out.bam
        .map { row -> [row[0].species, row[0].id] }
        .join ( 
            ch_sample_genomes
                .map { row -> [row[0].species, row[0].id, row[1][0], row[1][1]] },
            by:[0, 1]
        )
        .map { row -> [[id:row[0]], row[2], row[3]] }
        .set { fasta_fai_array }

    fasta_fai_array
        .map { row -> [[id:row[0]], row[1]] }
        .set { ch_fasta_array}

    fasta_fai_array
        .map { row -> [[id:row[0]], row[2]] }
        .set { ch_fai_array}

    PICARD_ADDORREPLACEREADGROUPS (
        AR_BWA_MEM.out.bam,
        ch_fasta_array,
        ch_fai_array
    )
    ch_versions.mix ( PICARD_ADDORREPLACEREADGROUPS.out.versions )

    PICARD_MARKDUPLICATES (
        PICARD_ADDORREPLACEREADGROUPS.out.bam,
        ch_fasta_array,
        ch_fai_array
    )
    ch_versions.mix ( PICARD_MARKDUPLICATES.out.versions )

    PICARD_MARKDUPLICATES.out.bam
        .map { row -> [row[0].id] + row }
        .join (
            PICARD_MARKDUPLICATES.out.bai
                .map { row -> [row[0].id, row[1]] }
        )
        .map { row -> [id:row[1].id, species:row[1].species, bam:row[2], bai:row[3]] }
        .set { ch_aligned }

    PICARD_MARKDUPLICATES.out.metrics
        .map { row -> row[1] }
        .collect ( sort:true )
        .set { ch_dedup_stats }

    COMPILE_DEDUP_STATS (
        ch_dedup_stats
    )

    emit:
    aligned       = ch_aligned
    mapping_stats = COMPILE_DEDUP_STATS.out.stats
    versions      = ch_versions
}
