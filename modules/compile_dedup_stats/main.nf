nextflow.enable.types = true

process COMPILE_DEDUP_STATS {
    label "local"
    maxRetries 0

    conda null
    container null

    input:
    stats: List<Path>
    
    stage:
    stageAs(stats, "stats/*")

    output:
    file("valid_mapping_stats.tsv")

    script:
    """
    awk '
    BEGIN{
        HEADER = 0;
    }{ 
        if (\$1 == "LIBRARY") {
            if (NR == FNR) print \$0;
            HEADER = 1;
        } else if (HEADER == 1) {
            print \$0;
            HEADER = 0;
        }
    }' stats/* > valid_mapping_stats.tsv
    """

    stub:
    """
    touch valid_mapping_stats.tsv
    """
}