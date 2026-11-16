nextflow.enable.types = true

process MERGE_BAMS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container 'community.wave.seqera.io/library/bwa_htslib_samtools:83b50ff84ead50d0'

    input:
    record(
        meta: Map,
        bams: List<Path>,
        bais: List<Path>
    )

    stage:
    stageAs(bams, "unmerged/*")
    stageAs(bais, "unmerged/*")

    output:
    record(
        meta: meta,
        bam: file("${meta.id}.bam"),
        bai: file("${meta.id}.bai"),
    )

    topic:
    record(tools: "samtools", version:eval("samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//'")) >> 'versions'

    script:
    def args = task.ext.args        ?: ''
    def prefix = task.ext.prefix    ?: "${meta.id}"

    """
    samtools \\
        merge \\
        ${args} \\
        -o ${prefix}.bam \\
        -@ $task.cpus \\
        ${bams}

    samtools \\
        index \\
        -b \\
        --threads $task.cpus \\
        ${prefix}.bam \\
        -o ${prefix}.bam.bai
    """

    stub:
    def prefix = task.ext.prefix    ?: "${meta.id}"
    """
    touch ${prefix}.bam
    touch ${prefix}.bam.bai
    """
}
