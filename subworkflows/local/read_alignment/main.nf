
include { PICARD_ADDORREPLACEREADGROUPS as SI_PICARD_ADDORREPLACEREADGROUPS } from '../../../modules/nf-core/picard/addorreplacereadgroups'
include { PICARD_MARKDUPLICATES as SI_PICARD_MARKDUPLICATES                 } from '../../../modules/nf-core/picard/markduplicates'
    // SI_BWA_MEM.out.bam
    //     .map { row -> [row[0].species, row[0].id] }
    //     .join ( 
    //         ch_genome_array
    //             .map { row -> [row[0].species, row[0].id, row[1][0], row[1][1]]},
    //         by:[0, 1]
    //     )
    //     .map { row -> [[id:row[0]], row[2], row[3]] }
    //     .set { fasta_fai_array }

    // fasta_fai_array
    //     .map { row -> [[id:row[0]], row[1]]}
    //     .set { ch_fasta_array}

    // fasta_fai_array
    //     .map { row -> [[id:row[0]], row[2]]}
    //     .set { ch_fai_array}

    // SI_PICARD_ADDORREPLACEREADGROUPS (
    //     SI_BWA_MEM.out.bam,
    //     ch_fasta_array,
    //     ch_fai_array
    // )
    // ch_versions.mix(SI_PICARD_ADDORREPLACEREADGROUPS.out.versions)

    // SI_PICARD_MARKDUPLICATES (
    //     SI_PICARD_ADDORREPLACEREADGROUPS.out.bam,
    //     ch_fasta_array,
    //     ch_fai_array
    // )
    // ch_versions.mix(SI_PICARD_MARKDUPLICATES.out.versions)
