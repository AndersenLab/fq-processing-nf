nextflow.enable.types = true

//
// Subworkflow with functionality specific to the andersenlab/fq-processing-nf pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


include { GET_EXISTING_BAMS         } from '../../../modules/get_existing_bams'
include { MERGE_BAM_LIST            } from '../../../modules/merge_bam_list'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
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
record BamRecord {
    meta: Map
    bam: Path
    bai: Path
}

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args // array: List of positional nextflow CLI args
    outdir: Path      // path: The output directory where the results will be saved
    

    main:

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Create channel from input file provided through params.input
    //

    ch_samples = channel.fromPath( params.samplesheet, checkIfExists: true )
        .flatMap { tsv -> tsv.splitCsv(sep: "\t", header: true) }
        .map { row ->
            def fastqs = []
            if (params.fastq_path_prefix != null) {
                fastqs += [ params.fastq_path_prefix + "/" + row['fq1'] ]
            } else {
                fastqs += [ row['fq1'] ]
            }
            def single_end = true
            if (row['fq2'] != "") {
                if (params.fastq_path_prefix != null) {
                    fastqs += [ params.fastq_path_prefix + "/" + row['fq2'] ]
                } else {
                    fastqs += [ row['fq2'] ]
                }
                single_end = false
            }
            record(
                    meta: [
                        id: row['id'],
                        lb: row['lb'],
                        species: row['species'],
                        strain: row['strain'],
                        single_end: single_end
                    ],
                    fastqs: fastqs,
            )
        }

    ch_genomes = channel.fromPath( params.genomesheet, checkIfExists: true )
        .flatMap { tsv -> tsv.splitCsv(sep: "\t", header: true) }
        .map { row -> record(
                genome: row['species'],
                fasta: [ row['genome'], "${row['genome']}.fai" ],
                index: [
                    "${row['genome']}.amb",
                    "${row['genome']}.ann",
                    "${row['genome']}.bwt",
                    "${row['genome']}.pac",
                    "${row['genome']}.sa"
                ]
            )
        }

    if (params.merge_external_bams) {
        ch_genome_bam_dir = channel.fromPath( params.genomesheet, checkIfExists: true )
            .flatMap { tsv -> tsv.splitCsv(sep: "\t", header: true) }
            .filter { row -> row['bam_dir'] != "" }
            .map { row -> record(
                    genome: row['species'],
                    bam_dir: row['bam_dir'],
                    samplesheet: file(params.samplesheet)
                )
            }

        ch_bam_tsv = GET_EXISTING_BAMS(
            ch_genome_bam_dir
        )

        ch_existing_bams = MERGE_BAM_LIST(
                ch_bam_tsv
                    .collect()
            )
            .flatMap { tsv -> tsv.splitCsv(sep: "\t", header: true) }
            .map { row -> record(
                    meta: [strain: row['strain']],
                    bam: row['bam'],
                    bai: row['bai']
                )
            }
    } else {
        ch_existing_bams = channel.empty( )
    }

    emit:
    samples: Channel<SampleRecord>    = ch_samples
    genomes: Channel<GenomeRecord>    = ch_genomes
    existing_bams: Channel<BamRecord> = ch_existing_bams
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output

    main:
    summary_params = [:]

    //
    // Completion email and summary
    //
    workflow.onComplete {

        completionSummary(monochrome_logs)
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    def (metas, fastqs) = input[1..2]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect{ meta -> meta.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }

    return [ metas[0], fastqs ]
}
