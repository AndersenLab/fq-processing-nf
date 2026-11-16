nextflow.enable.types = true

process COMPILE_SPECIES_STATS {
    label "local"
    maxRetries 0

    conda null
    container null

    input:
    stats: List<Path>
    min_mapping: BigDecimal
    
    stage:
    stageAs(stats, "stats/*")

    output:
    record(
        stats: file("species_mapping_stats.tsv"),
        passed: file("passed_samples.tsv"),
        failed: file("failed_samples.tsv"),
    )

    script:
    """
    awk '
    function insertion_sort(arr, keys) {
        # Populate 'keys' array with indices of 'arr'
        num_keys = 0
        for (idx in arr) {
            keys[++num_keys] = idx
        }

        # Perform insertion sort on 'keys'
        for (i = 2; i <= num_keys; i++) {
            key = keys[i]
            j = i - 1
            while (j > 0 && keys[j] > key) { # Adjust comparison for desired order
                keys[j+1] = keys[j]
                j--
            }
            keys[j+1] = key
        }
    }{
        # Ingest percent mapping for each sample-species combination, keyed by sample
        if (FNR > 1) {
            if (length(SAMPLES[\$1]) == 0){
                SAMPLES[\$1] = \$2 "," \$3;
            } else {
                SAMPLES[\$1] = SAMPLES[\$1] "\\t" \$2 "," \$3;
            }
        }
    } END {
        # Sort by sample name
        insertion_sort(SAMPLES, SORTED);
        # For each sample, print a formatted row
        for (I=1; I<=length(SORTED); I++) {
            # Split the species and percent mapping values and create a percent mapping array keyed by species
            split(SAMPLES[SORTED[I]],ITEMS,"\\t");
            for (J=1; J<=length(ITEMS); J++) {
                split(ITEMS[J],ITEM,",");
                VALUES[ITEM[1]] = ITEM[2];
            }
            delete ITEMS;
            # Sort the species names
            insertion_sort(VALUES, GENOMES);
            # If this is the first sample, print a header line
            if (I == 1) {
                printf "SAMPLE";
                for (J=1; J<=length(GENOMES); J++) {
                    printf "\\t%s", GENOMES[J];
                }
                printf "\\n";
            }
            # Print the percent mapping values, ordered by sorted species name
            printf "%s", SORTED[I];
            for (J=1; J<=length(GENOMES); J++) {
                printf "\\t%s", VALUES[GENOMES[J]];
            }
            printf "\\n";
            delete VALUES;
        }
    }' stats/* > species_mapping_stats.tsv

    awk -v MINMAPPING="${min_mapping}" 'BEGIN{
            printf "strain\\tspecies\\t\% mapping\\n" > "passed_samples.tsv";
            printf "strain\\tspecies\\t\% mapping\\n" > "failed_samples.tsv";
        }{
        # Load the header line with species names
        if (FNR == 1) {
            SPECIES[0]='unidentified';
            for (I=2; I<=NF; I++) {
                SPECIES[I] = \$I;
            }
        } else {
            SAMPLE = \$1;
            COUNT = 0;
            BEST_VALUE = 0;
            BEST_MAPPING = 0;
            # Count how many percent mapping values match or exceed the cutoff value and which species has the highest value
            for (I=2; I<=NF; I++) {
                if (\$I >= MINMAPPING) {
                    COUNT = COUNT + 1;
                }
                if (BEST_MAPPING < \$I) {
                    BEST_VALUE = I;
                    BEST_MAPPING = \$I;
                }
            }
            # If there is a single match, mark sample with species, otherwise as unidentified
            if (COUNT == 1) {
                printf "%s\\t%s\\t%s\\n", SAMPLE, SPECIES[BEST_VALUE], BEST_MAPPING > "passed_samples.tsv";
            }  else {
                if (COUNT > 1) {
                    MULTIPLE=",multiple matches";
                } else {
                    MULTIPLE="";
                }
                printf "%s\\t%s%s\\t%s\\n", SAMPLE, SPECIES[BEST_VALUE], MULTIPLE, BEST_MAPPING > "failed_samples.tsv";
            }
        }
    }' species_mapping_stats.tsv
    """

    stub:
    """
    touch species_mapping_stats.tsv
    touch passed_samples.tsv
    touch failed_samples.tsv
    """
}
