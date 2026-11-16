nextflow.enable.types = true

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { BWA_MEM as AR_BWA_MEM        } from '../../../modules/bwa_mem'
include { PICARD_PROCESS               } from '../../../modules/picard_process'
include { COMPILE_DEDUP_STATS          } from '../../../modules/compile_dedup_stats'
include { MERGE_BAMS                   } from '../../../modules/merge_bams'
include { COVERAGE                     } from '../../../modules/coverage'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

record SampleRecord {
    meta: Map
    fastqs: List<Path>
}
record GenomeRecord {
    id: String
    fasta: List<Path>
    index: List<Path>
}
record BamRecord {
    meta: Map
    bam: Path
    bai: Path
    coverage: Path?
}

workflow ALIGN_READS {

    take:
    ch_samples       : Channel<SampleRecord>
    ch_genomes       : Channel<GenomeRecord>
    ch_existing_bams : Channel<BamRecord>

    main:
    ch_sample_genomes = ch_samples
        .map { row -> record(
                id: row.meta.species,
                meta: row.meta,
                fastqs: row.fastqs
            )
        }
        .join ( ch_genomes, by: 'id' )
        .map { row -> record(
                meta: row.meta,
                fastqs: row.fastqs,
                fasta: row.fasta,
                index: row.index
            )
        }

    ch_bams = AR_BWA_MEM (
        ch_sample_genomes,
        false
    )

    ch_picard_bams = PICARD_PROCESS (
        ch_bams
    )

    ch_dedup_stats = ch_picard_bams
        .map { row -> row.stats }
        .collect ( )
        .map { row -> row.toSorted() }

    ch_mapping_stats = COMPILE_DEDUP_STATS (
        ch_dedup_stats
    )

    ch_grouped_bams = ch_picard_bams
        .map { row -> tuple( row.meta.strain, [row.bam, row.bai] ) }
        .mix (
            ch_existing_bams.map { row -> tuple( row.meta.strain, [row.bam, row.bai] ) }
        )
        .groupBy ( )
        .map { row ->
            def files = row[1].toList().collectMany { it -> it }.toSorted()
            def bams = files.findAll { it -> it.name.endsWith('.bam') }.toList()
            def bais = files.findAll { it -> it.name.endsWith('.bai') }.toList()
            record(
                meta: [id: row[0]],
                bams: bams,
                bais: bais
            )
        }

    ch_multi_bams = ch_grouped_bams
        .filter { row -> row.bams.size() > 1 }

    ch_single_bams = ch_grouped_bams
        .filter { row -> row.bams.size() == 1 }
        .map { row -> record(
                meta: row.meta,
                bam: row.bams[0],
                bai: row.bais[0]
            )
        }

    ch_merged_bams = MERGE_BAMS (
        ch_multi_bams
    ).mix ( ch_single_bams )

    ch_coverage_bams = COVERAGE (
        ch_merged_bams
    )

    emit:
    aligned: Channel<BamRecord>  = ch_coverage_bams
    mapping_stats: Value<Path> = ch_mapping_stats
}
