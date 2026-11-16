nextflow.enable.types = true

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTP                   } from '../modules/fastp'
include { SPECIES_IDENTIFICATION  } from '../subworkflows/local/species_identification'
include { ALIGN_READS             } from '../subworkflows/local/align_reads'
include { COLLECT_VERSIONS        } from '../modules/collect_versions'

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
record StatsRecord {
    stats: Path
    passed: Path
    failed: Path
}
record VersionRecord {
    tool: String
    version: String
}

workflow FQ_PROCESSING {

    take:
    ch_samples       : Channel<SampleRecord>
    ch_genomes       : Channel<GenomeRecord>
    ch_existing_bams : Channel<BamRecord>

    main:
    if (params.skip_trimming) {
        ch_trimmed    = ch_samples
    } else {
        ch_trimmed = FASTP(
            ch_samples
        )
    }

    if (params.skip_species_check) {
        ch_species_stats = channel.value ( record(
                stats: null,
                passed: null,
                failed: null
            )
        )
        ch_identified    = ch_trimmed
    } else {
        species_identification_call = SPECIES_IDENTIFICATION(
            ch_trimmed,
            ch_genomes,
            channel.value( params.subsample ),
            channel.value( params.min_mapping )
        )
        ch_species_stats     = species_identification_call.species_stats
        ch_identified        = species_identification_call.identified
    }

    // If reads were trimmed, organize them by their identified species or as needing review

    align_reads_call = ALIGN_READS(
        ch_identified,
        ch_genomes,
        ch_existing_bams
    )
    ch_aligned        = align_reads_call.aligned
    ch_mapping_stats  = align_reads_call.mapping_stats

    // Compile versions of tools used in the workflow
    ch_versions = channel.topic("versions")
        .map { row -> new VersionRecord(row) }
        .map { row -> "${row.tool}\t${row.version}" }
        .collect ( )

    ch_collect_versions = COLLECT_VERSIONS(
        ch_versions
    )

    emit:
    trimmed: Channel<SampleRecord>      = ch_trimmed
    species_stats: Value<StatsRecord> = ch_species_stats
    aligned: Channel<BamRecord>         = ch_aligned
    mapping_stats: Value<Path>          = ch_mapping_stats
    versions: Value<Path>               = ch_collect_versions
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
