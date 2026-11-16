nextflow.enable.types = true

process BWA_MEM {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container 'community.wave.seqera.io/library/bwa_htslib_samtools:83b50ff84ead50d0'

    input:
    record(
        meta: Map,
        fastqs: List<Path>,
        fasta: List<Path>,
        index: List<Path>
    )
    stats_only: Boolean

    output:
    record(
        meta: meta,
        bam: file("${meta.id}.bam", optional: true),
        bai: file("${meta.id}.bai", optional: true),
        stats: file("${meta.id}_${meta.species}.stats", optional: true),
    )

    topic:
    record(tool: "bwa", version:eval("bwa 2>&1 | sed 's/^.*Version: //; s/Contact:.*\$//'")) >> 'versions'
    record(tools: "samtools", version:eval("samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//'")) >> 'versions'

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def idxstats_only = stats_only ? "true" : "false"
    """

    bwa mem \\
        $args \\
        -t $task.cpus \\
        $fasta[0] \\
        $fastqs \\
        | samtools sort $args2 --threads $task.cpus -o ${prefix}.bam -
    
    samtools \\
        index \\
        -b \\
        --threads $task.cpus \\
        ${prefix}.bam \\
        -o ${prefix}.bam.bai

    if [[ ${idxstats_only} == "true" ]]; then
        samtools \\
            idxstats \\
            --threads ${task.cpus} \\
            ${prefix}.bam \\
            > ${prefix}.idxstats
        rm ${prefix}.bam
        rm ${prefix}.bam.bai

        awk -v ID="${meta.id}" -v SPECIES="${meta.species}" '{
            # Skip the header line
            if (NR > 1) {
                # Count mapped reads
                MAPPED=MAPPED+\$3;
                # Count unmapped reads
                UNMAPPED=UNMAPPED+\$4;
            }
        } END {
            # Print the sample, species, and percent of mapped reads with a header line
            printf "ID\\tSPECIES\\tPERCENT_MAPPING\\n%s\\t%s\\t%f\\n", ID, SPECIES, MAPPED / (MAPPED + UNMAPPED);
        }' ${prefix}.idxstats > ${meta.id}_${meta.species}.stats
        rm ${prefix}.idxstats
    fi
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def idxstats_only = stats_only ? "true" : "false"
    """
    if [[ ${idxstats_only} == "true" ]]; then
        touch ${meta.id}_${meta.species}.stats
    else
        touch ${prefix}.bam
        touch ${prefix}.bam.bai
    fi
    """
}
