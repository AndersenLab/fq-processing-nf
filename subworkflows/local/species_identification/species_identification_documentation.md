# Species Identification Subworkflow Documentation

## Overview

The `SPECIES_IDENTIFICATION` subworkflow is a critical quality control component of the `fq-processing-nf` pipeline that validates whether sequenced samples match their expected species labels. This subworkflow performs rapid species verification by aligning subsampled reads against multiple reference genomes and calculating mapping percentages to identify potential sample mix-ups, contamination, or mislabeling.

## Purpose

Species misidentification is a common problem in high-throughput sequencing workflows that can lead to:
- Incorrect downstream analyses
- Wasted computational resources
- Compromised research conclusions

This subworkflow automatically flags samples for review when:
- The observed species doesn't match the expected species label
- Multiple species show significant mapping percentages (potential contamination)
- No species shows adequate mapping percentage (potential quality issues)

## Location

```
subworkflows/local/species_identification/main.nf
```

## Workflow Architecture

### Input Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `ch_trimmed` | Channel | Tuple of metadata and trimmed FASTQ files `[meta, reads]` where `meta` contains at minimum `id` and `species` fields |
| `ch_genomes` | Channel | Reference genome information `[meta, bwa_index, reference_fasta]` for multiple species |
| `subsample` | Integer | Number of reads to subsample for rapid species identification (default: 10,000) |
| `ch_versions` | Channel | Software version tracking channel |

### Output Channels

| Channel | Type | Description |
|---------|------|-------------|
| `species_stats` | File | Compiled mapping statistics across all samples and genomes |
| `identified` | Channel | Samples that passed species verification `[meta, reads]` |
| `mismatched` | Channel | Samples flagged for review due to species mismatch `[meta, reads]` |
| `versions` | Channel | Updated software version tracking |

## Process Flow

### 1. Expected Species Collection

```groovy
ch_trimmed
    .map { row -> "${row[0].id}\t${row[0].species}" }
    .collectFile(name:"expected_species.tsv", newLine:true)
    .set { ch_expected_species }
```

**Purpose**: Creates a reference file mapping each sample ID to its expected species designation from the metadata.

### 2. Read Subsampling (`SUBSET_READS`)

**Module**: `modules/local/subset_reads`

**Function**: Extracts a configurable number of reads (default: 10,000) from each sample to enable rapid alignment without processing complete datasets.

**Rationale**: Species identification requires only a small fraction of reads for accurate classification, dramatically reducing computational time.

**Output**: Subsampled FASTQ files (`*.subset.fq.gz`)

### 3. Sample-Genome Combination Matrix

```groovy
SUBSET_READS.out.subset
    .combine(ch_genomes)
    .set { sample_genome_array }
```

**Purpose**: Creates a Cartesian product of all samples × all reference genomes, enabling each sample to be tested against every possible species.

**Example**: If you have 10 samples and 3 reference genomes (e.g., *C. elegans*, *C. briggsae*, *C. tropicalis*), this creates 30 alignment tasks.

### 4. Channel Reformatting

```groovy
sample_genome_array
    .map { row -> [[id:"${row[0].id}_${row[2].id}", sample:row[0].id, species:row[2].id], row[1]] }
    .set { ch_sample_array }

sample_genome_array
    .map { row -> [[id:"${row[0].id}_${row[2].id}", sample:row[0].id, species:row[2].id], row[3]] }
    .set { ch_genome_array }
```

**Purpose**: Restructures channels to track both sample origin and genome identity in the metadata, creating unique IDs like `sample123_celegans`.

### 5. Reference-Free Alignment Preparation

```groovy
ch_no_file = Channel.fromPath("${workflow.projectDir}/assets/NO_FILE")
    .map { row -> [[], row] }
    .first()
```

**Purpose**: Creates a placeholder for optional BWA-MEM sort BAM input (not used in this workflow).

### 6. BWA-MEM Alignment (`SI_BWA_MEM`)

**Module**: `modules/nf-core/bwa/mem`

**Function**: Aligns subsampled reads against each reference genome using BWA-MEM algorithm.

**Parameters**:
- `sort_bam`: `true` - produces coordinate-sorted BAM files

**Output**: BAM alignment files for each sample-genome combination

### 7. BAM Indexing (`SI_SAMTOOLS_INDEX`)

**Module**: `modules/nf-core/samtools/index`

**Function**: Creates BAM index (`.bai`) files required for downstream processing.

### 8. BAM Index Synchronization

```groovy
SI_BWA_MEM.out.bam
    .map { row -> [row[0].id, row[0], row[1]] }
    .join(
        SI_SAMTOOLS_INDEX.out.bai
            .map { row -> [row[0].id, row[1]] }
    )
    .map { row -> [row[1], row[2], row[3]] }
    .set { ch_indexed_bam }
```

**Purpose**: Synchronizes BAM files with their corresponding indices using a join operation on the unique ID, ensuring paired inputs for idxstats.

### 9. Alignment Statistics (`SI_SAMTOOLS_IDXSTATS`)

**Module**: `modules/nf-core/samtools/idxstats`

**Function**: Generates alignment statistics showing mapped and unmapped read counts per reference sequence.

**Output Format** (TSV):
```
chromosome1    length1    mapped_reads1    unmapped_reads1
chromosome2    length2    mapped_reads2    unmapped_reads2
*              0          0                unmapped_total
```

### 10. Per-Genome Statistics Calculation (`SPECIES_STATS`)

**Module**: `modules/local/species_stats`

**Function**: Processes idxstats output to calculate the percentage of reads mapping to each genome.

**Algorithm**:
```awk
PERCENT_MAPPING = TOTAL_MAPPED / (TOTAL_MAPPED + TOTAL_UNMAPPED)
```

**Output Format**:
```
ID              SPECIES         PERCENT_MAPPING
sample123       celegans        0.956234
sample123       cbriggsae       0.023156
```

### 11. Statistics Aggregation

```groovy
SPECIES_STATS.out.stats
    .map { row -> row[1] }
    .collect()
    .set { ch_species_stats }
```

**Purpose**: Collects all individual sample-genome statistics files for comprehensive analysis.

### 12. Species Validation (`COMPILE_SPECIES_STATS`)

**Module**: `modules/local/compile_species_stats`

**Function**: Performs the core species identification logic by comparing mapping percentages against expected species labels.

**Validation Criteria**:
1. **Minimum Mapping Threshold**: Default 95% (`min_mapping = 0.95`)
2. **Single Best Match**: Only one genome exceeds the mapping threshold
3. **Correct Species**: The best-matching genome matches the expected species

**Decision Logic**:

```
IF (exactly_one_genome >= 95% mapping) AND (that_genome == expected_species):
    → VALID sample
ELSE:
    → FLAGGED for review (potential mismatch)
```

**Outputs**:
- `species_mapping_stats.tsv`: Matrix of all samples × genomes with mapping percentages
- `valid_samples.txt`: Sample IDs passing validation
- `to_review_samples.txt`: Sample IDs requiring manual review

**Example Output Matrix** (`species_mapping_stats.tsv`):
```
SAMPLE          celegans    cbriggsae   ctropicalis
sample_001      0.962       0.018       0.014
sample_002      0.034       0.951       0.008
sample_003      0.485       0.492       0.012    ← Flagged (ambiguous)
```

### 13. Channel Splitting by Validation Status

```groovy
COMPILE_SPECIES_STATS.out.valid
    .splitCsv()
    .map { row -> [row[0]] }
    .join(
        ch_trimmed.map { row -> [row[0].id] + row }
    )
    .map { row -> [row[1], row[2]] }
    .set { ch_identified }

COMPILE_SPECIES_STATS.out.invalid
    .splitCsv(sep:"\t")
    .map { row -> [row[0]] }
    .join(
        ch_trimmed.map { row -> [row[0].id] + row }
    )
    .map { row -> [row[1], row[2]] }
    .set { ch_mismatched }
```

**Purpose**: Separates the original trimmed reads into two streams based on validation results:
- **Identified**: Proceeds to downstream alignment and analysis
- **Mismatched**: Routed to `to_review` directory for manual inspection

## Key Modules

### SUBSET_READS
- **Language**: Bash
- **Container**: None (local execution)
- **Function**: Extracts first N reads (N × 4 lines) from FASTQ files
- **Handles**: Both gzipped and uncompressed files, paired-end and single-end

### SPECIES_STATS
- **Language**: AWK
- **Container**: None (local execution)
- **Function**: Calculates mapping percentage from samtools idxstats output
- **Formula**: `MAPPED / (MAPPED + UNMAPPED)`

### COMPILE_SPECIES_STATS
- **Language**: AWK
- **Container**: None (local execution)
- **Functions**:
  1. Creates sample × genome mapping matrix
  2. Validates samples against expected species
  3. Implements insertion sort for consistent ordering
  4. Applies configurable mapping threshold

## Configuration

### Pipeline Parameters

Set in `nextflow.config` or via command line:

```bash
--subsample 10000              # Number of reads for species check
--skip_species_check false     # Enable/disable species validation
```

### Adjustable Thresholds

The minimum mapping percentage is hardcoded in the subworkflow:

```groovy
COMPILE_SPECIES_STATS(
    ch_species_stats,
    ch_expected_species,
    0.95  // ← Minimum mapping threshold (95%)
)
```

**Recommendation**: Consider parameterizing this value for flexibility in different biological contexts.

## Use Cases

### Typical Scenarios Where Samples Are Flagged

1. **Sample Swap**: Sample labeled as *C. elegans* but predominantly aligns to *C. briggsae*
   ```
   Expected: elegans | Observed: elegans=5%, briggsae=96% → FLAGGED
   ```

2. **Contamination**: Significant mapping to multiple species
   ```
   Expected: elegans | Observed: elegans=60%, briggsae=35% → FLAGGED
   ```

3. **Low Quality**: Poor mapping across all genomes
   ```
   Expected: elegans | Observed: elegans=45%, briggsae=40% → FLAGGED
   ```

4. **Correct Match**: Clear single species match
   ```
   Expected: elegans | Observed: elegans=97%, briggsae=2% → VALID
   ```

## Integration with Main Workflow

The subworkflow integrates into `workflows/fq_processing.nf`:

```groovy
if (skip_species_check) {
    ch_identified = ch_trimmed  // Skip validation
    ch_mismatched = Channel.empty()
} else {
    SPECIES_IDENTIFICATION(ch_trimmed, ch_genomes, params.subsample, ch_versions)
    ch_identified = SPECIES_IDENTIFICATION.out.identified
    ch_mismatched = SPECIES_IDENTIFICATION.out.mismatched
}
```

Validated samples proceed to alignment, while mismatched samples are published to the `to_review` directory for manual inspection.

## Performance Considerations

### Computational Efficiency

- **Subsampling Strategy**: Using 10,000 reads instead of millions reduces alignment time by 99%+
- **Parallel Execution**: All sample-genome combinations run concurrently
- **Resource Requirements**: Minimal CPU/memory due to small input size

### Scalability

For a project with:
- 100 samples
- 5 reference genomes
- 10,000 reads per sample

**Total alignments**: 500 tasks
**Typical runtime**: 1-5 minutes per alignment
**Total wall time**: ~5-15 minutes with parallel execution

## Output Files

### Directory Structure

```
work_dir/
├── species_stats/
│   └── species_mapping_stats.tsv      # Complete mapping matrix
├── trimmed/
│   ├── celegans/                      # Validated C. elegans samples
│   ├── cbriggsae/                     # Validated C. briggsae samples
│   └── ...
└── to_review/                          # Flagged samples requiring review
    ├── sample_003_1.fq.gz
    └── sample_003_2.fq.gz
```

### Interpreting Results

#### species_mapping_stats.tsv

A matrix showing mapping percentages for visual inspection:

```tsv
SAMPLE          species1    species2    species3
valid_sample    0.963       0.021       0.008
problem_sample  0.456       0.478       0.055
```

**Interpretation**:
- `valid_sample`: Clear match to species1 (96.3%)
- `problem_sample`: Ambiguous (split between species1 and species2) → Flagged

## Best Practices

### Input Requirements

1. **Accurate Metadata**: Ensure `species` field in samplesheet is correct
2. **Complete Genome Set**: Include all expected species in genomesheet
3. **Quality Sequences**: Pre-trimming recommended (though pipeline includes optional trimming)

### Troubleshooting

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| Many samples flagged | Wrong reference genomes | Verify genomesheet matches expected species |
| All samples flagged | Threshold too stringent | Adjust `min_mapping` parameter (currently 0.95) |
| Low mapping across all genomes | Poor sequence quality | Check FASTP reports, increase subsample size |
| Unexpected species matches | Sample labeling errors | Review laboratory records |

## Extending the Subworkflow

### Adding Custom Validation Rules

The `COMPILE_SPECIES_STATS` module could be extended to:

1. **Multi-species tolerance**: Allow samples with expected dual-species signatures
2. **Contamination reporting**: Flag samples with >X% secondary species
3. **Genus-level validation**: Accept any species within correct genus

### Parameterizing Thresholds

Consider modifying the subworkflow to accept configurable thresholds:

```groovy
workflow SPECIES_IDENTIFICATION {
    take:
    // ... existing parameters ...
    min_mapping_threshold  // Add as parameter

    main:
    COMPILE_SPECIES_STATS(
        ch_species_stats,
        ch_expected_species,
        min_mapping_threshold  // Use parameter instead of hardcoded 0.95
    )
}
```

Then update `nextflow.config`:

```groovy
params {
    min_mapping_threshold = 0.95  // Default value
}
```

## Dependencies

### Software Requirements

- **BWA**: Burrows-Wheeler Aligner for read mapping
- **SAMtools**: BAM file processing and statistics
- **AWK**: Text processing for statistics calculation
- **GNU Coreutils**: Basic file operations (gzip, zcat, head)

### Reference Data Requirements

The genomesheet must provide for each species:
1. BWA index files (`.amb`, `.ann`, `.bwt`, `.pac`, `.sa`)
2. Reference FASTA file
3. Species identifier matching sample metadata

## Related Documentation

- **Main Workflow**: `workflows/fq_processing.nf`
- **Module Documentation**: 
  - `modules/local/subset_reads/`
  - `modules/local/species_stats/`
  - `modules/local/compile_species_stats/`
- **Configuration**: `nextflow.config`
- **Input Format**: Sample and genome sheet specifications

## Authors & Maintenance

- **Original Author**: Michael Sauria
- **Repository**: https://github.com/AndersenLab/fq-processing-nf
- **License**: MIT

## Changelog

This documentation describes the subworkflow as implemented in the current version of the pipeline. For updates and modifications, see the repository's `CHANGELOG.md`.

---

## Quick Reference

### Command Line Usage

```bash
# Run with species identification (default)
nextflow run andersenlab/fq-processing-nf \
    --samplesheet samples.csv \
    --genomesheet genomes.csv \
    --subsample 10000 \
    --outdir results/

# Skip species identification
nextflow run andersenlab/fq-processing-nf \
    --samplesheet samples.csv \
    --skip_species_check \
    --outdir results/
```

### Required Input Formats

**samplesheet.csv**:
```csv
id,species,fastq_1,fastq_2
sample001,celegans,/path/to/R1.fq.gz,/path/to/R2.fq.gz
```

**genomesheet.csv**:
```csv
id,bwa_index,fasta
celegans,/path/to/index/prefix,/path/to/genome.fa
```

### Key Outputs

- ✅ `species_stats/species_mapping_stats.tsv` - Complete mapping results
- ✅ `trimmed/{species}/` - Validated samples by species
- ⚠️ `to_review/` - Samples requiring manual review