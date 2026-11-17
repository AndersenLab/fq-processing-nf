nextflow.enable.types = true

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { SUBSET_READS             } from '../../../modules/subset_reads'
include { BWA_MEM as SI_BWA_MEM    } from '../../../modules/bwa_mem'
include { COMPILE_SPECIES_STATS    } from '../../../modules/compile_species_stats'

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
    genome: String
    fasta: List<Path>
    index: List<Path>
}
record StatsRecord {
    stats: Path
    passed: Path
    failed: Path
}

workflow SPECIES_IDENTIFICATION {

    take:
    ch_trimmed: Channel<SampleRecord>
    ch_genomes: Channel<GenomeRecord>
    subsample: Value<Integer>
    min_mapping: Value<BigDecimal>

    main:
    ch_subset = SUBSET_READS (
            ch_trimmed,
            subsample
        ).combine ( ch_genomes )
        .map { tuple ->
            def sample = tuple[0]
            def genome = tuple[1]
            def meta = sample.meta
            meta.id = "${sample.meta.id}_${genome.genome}"
            meta.sample = sample.meta.id
            meta.expected_species = sample.meta.species
            meta.species = genome.genome
            record(
                meta: meta,
                fastqs: sample.fastqs,
                fasta: genome.fasta,
                index: genome.index,
            )
        }

    ch_species_stats = SI_BWA_MEM (
            ch_subset,
            true
        )
        .map { row -> row.stats }
        .collect ( )
        .map { row -> row.toList() }

    ch_compiled_stats = COMPILE_SPECIES_STATS (
            ch_species_stats,
            min_mapping
        )

    ch_identified = ch_compiled_stats
        .flatMap { csv -> csv.passed.splitCsv(sep: "\t", header: true) }
        .map { row -> 
            def tsvRow = row as Map
            record(
                id: tsvRow.strain,
                species: tsvRow.species
            )
        }
        .join (
            ch_trimmed.map { row -> record(
                id: row.meta.id,
                meta: row.meta,
                fastqs: row.fastqs
                )
            }, by: "id"
        )
        .map { row -> 
            record(
                meta: row.meta,
                fastqs: row.fastqs,
            )
        }

    emit:
    species_stats: Value<StatsRecord> = ch_compiled_stats
    identified: Channel<SampleRecord>   = ch_identified
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
