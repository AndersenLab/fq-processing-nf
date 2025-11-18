process COMPILE_SPECIES_STATS {
    label "local"
    maxRetries 0

    conda null
    container null

    input:
    path(stats, name: "stats/*")
    path(expected_species)
    val(min_mapping)

    output:
    path("species_mapping_stats.tsv") , emit: stats
    path("valid_samples.txt")         , emit: valid
    path("to_review_samples.txt")     , emit: invalid

    when:
    task.ext.when == null || task.ext.when

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

    awk -v MINMAPPING="${min_mapping}" '{
        # Load expected species for each sample from the first file
        if (NR == FNR) {
            EXPECTED[\$1] = \$2;
        } else {
            # Load the header line with species names
            if (FNR == 1) {
                for (I=2; I<=NF; I++) {
                    SPECIES[I] = \$I;
                }
            } else {
                SAMPLE = \$1;
                COUNT = 0;
                BEST_VALUE = 0;
                # Count how many percent mapping values match or exceed the cutoff value and which species has the highest value
                for (I=2; I<=NF; I++) {
                    if (\$I >= MINMAPPING) {
                        COUNT = COUNT + 1;
                        BEST_VALUE = I;
                    }
                }
                # If there is a single match to the correct species, mark sample as valid, otherwise as a mismatch
                if (COUNT == 1 && SPECIES[BEST_VALUE] == EXPECTED[SAMPLE]) {
                    MATCH = "valid";
                }  else {
                    MATCH = "mismatch";
                }
                printf "%s\\t%s\\n", SAMPLE, MATCH;
            }
        }
    }' ${expected_species} species_mapping_stats.tsv > sample_matches.tsv

    # Pull valid and mismatched sample names into separate lists
    grep -w valid sample_matches.tsv | cut -f 1 > valid_samples.txt
    grep -w mismatch sample_matches.tsv | cut -f 1 > to_review_samples.txt
    """

    stub:
    """
    touch species_mapping_stats.tsv
    touch valid_samples.txt
    touch to_review_samples.txt
    """
}