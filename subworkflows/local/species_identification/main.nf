/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { SUBSET_READS             } from '../../../modules/local/subset_reads'
include { BWA_MEM as SI_BWA_MEM    } from '../../../modules/nf-core/bwa/mem'
include { SAMTOOLS_INDEX as SI_SAMTOOLS_INDEX                               } from '../../../modules/nf-core/samtools/index'
include { SAMTOOLS_IDXSTATS as SI_SAMTOOLS_IDXSTATS                         } from '../../../modules/nf-core/samtools/idxstats'
include { SPECIES_STATS            } from '../../../modules/local/species_stats'
include { COMPILE_SPECIES_STATS    } from '../../../modules/local/compile_species_stats'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SPECIES_IDENTIFICATION {

    take:
    ch_trimmed
    ch_genomes
    subsample
    ch_versions

    main:
    ch_trimmed
        .map { row -> "${row[0].id}\t${row[0].species}" }
        .collectFile( name:"expected_species.tsv", newLine:true )
        .set { ch_expected_species }

    SUBSET_READS (
        ch_trimmed,
        subsample
    )

    SUBSET_READS.out.subset
        .combine( ch_genomes )
        .set { sample_genome_array }
        
        
    sample_genome_array
        .map { row -> [[id:"${row[0].id}_${row[2].id}", sample:row[0].id, species:row[2].id], row[1]] }
        .set { ch_sample_array }
    
    sample_genome_array
        .map { row -> [[id:"${row[0].id}_${row[2].id}", sample:row[0].id, species:row[2].id], row[3]] }
        .set { ch_genome_array }
        
    ch_no_file = Channel.fromPath( "${workflow.projectDir}/assets/NO_FILE" )
        .map { row -> [[], row] }
        .first ( )

    SI_BWA_MEM (
        ch_sample_array,
        ch_genome_array,
        ch_no_file,
        true
    )
    ch_versions = ch_versions.mix( SI_BWA_MEM.out.versions )

    SI_SAMTOOLS_INDEX (
        SI_BWA_MEM.out.bam
    )
    ch_versions = ch_versions.mix( SI_SAMTOOLS_INDEX.out.versions )

    SI_BWA_MEM.out.bam
        .map { row -> [row[0].id, row[0], row[1]] }
        .join ( 
            SI_SAMTOOLS_INDEX.out.bai
                .map { row -> [row[0].id, row[1]] }
        )
        .map { row -> [row[1], row[2], row[3]] }
        .set { ch_indexed_bam }

    SI_SAMTOOLS_IDXSTATS (
        ch_indexed_bam
    )
    ch_versions = ch_versions.mix( SI_SAMTOOLS_IDXSTATS.out.versions )

    SI_SAMTOOLS_IDXSTATS.out.idxstats
        .map { row -> [[id:row[0].sample, species:row[0].species], row[1]] }
        .set { ch_idxstats }
        
    SPECIES_STATS (
        ch_idxstats
    )

    SPECIES_STATS.out.stats
        .map { row -> row[1] }
        .collect ( )
        .set { ch_species_stats }
    
    COMPILE_SPECIES_STATS (
        ch_species_stats,
        ch_expected_species,
        0.95
    )

    COMPILE_SPECIES_STATS.out.valid
        .splitCsv ( )
        .map { row -> [row[0]] }
        .join (
            ch_trimmed.map { row -> [row[0].id] + row }
        )
        .map { row -> [row[1], row[2]] }
        .set { ch_identified }

    COMPILE_SPECIES_STATS.out.invalid
        .splitCsv ( sep:"\t" )
        .map { row -> [row[0]] }
        .join (
            ch_trimmed.map { row -> [row[0].id] + row }
        )
        .map { row -> [row[1], row[2]] }
        .set { ch_mismatched }

    emit:
    species_stats  = COMPILE_SPECIES_STATS.out.stats
    identified     = ch_identified
    mismatched     = ch_mismatched
    // species_report = ch_species_report
    versions       = ch_versions
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
