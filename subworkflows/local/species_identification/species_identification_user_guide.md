# Species Identification Subworkflow - User Guide

## Quick Start

This guide helps you understand and use the species identification feature in the fq-processing-nf pipeline.

## What Does This Do?

The species identification subworkflow answers the question: **"Does this sample contain the species I think it does?"**

It does this by:
1. Taking a small sample of your reads (10,000 by default)
2. Aligning them to all your reference genomes
3. Calculating what percentage maps to each genome
4. Flagging samples that don't match expectations

## When Should You Use This?

✅ **Always recommended when:**
- Processing samples from multiple species
- Receiving samples from external facilities
- Working with newly collected specimens
- Historical samples with uncertain provenance
- High-throughput screening projects

❌ **Can skip when:**
- Single-species projects with trusted samples
- Computational resources are extremely limited
- Re-processing previously validated data

## Setting Up Your Input Files

### 1. Samplesheet (samples.csv)

Your samplesheet MUST include an `id` and `species` column:

```csv
id,species,fastq_1,fastq_2
CE001,celegans,/data/CE001_R1.fq.gz,/data/CE001_R2.fq.gz
CB002,cbriggsae,/data/CB002_R1.fq.gz,/data/CB002_R2.fq.gz
CT003,ctropicalis,/data/CT003_R1.fq.gz,/data/CT003_R2.fq.gz
```

**Important**: The `species` value must match the genome IDs in your genomesheet!

### 2. Genomesheet (genomes.csv)

Provide reference genomes for ALL species you expect to see:

```csv
id,bwa_index,fasta
celegans,/genomes/celegans/bwa_index,/genomes/celegans/genome.fa
cbriggsae,/genomes/cbriggsae/bwa_index,/genomes/cbriggsae/genome.fa
ctropicalis,/genomes/ctropicalis/bwa_index,/genomes/ctropicalis/genome.fa
```

**Pro Tip**: Include common contaminants (e.g., human, E. coli) to catch unexpected contamination.

## Running the Pipeline

### Basic Command

```bash
nextflow run andersenlab/fq-processing-nf \
    --samplesheet samples.csv \
    --genomesheet genomes.csv \
    --outdir results/ \
    -profile docker
```

### Advanced Options

```bash
nextflow run andersenlab/fq-processing-nf \
    --samplesheet samples.csv \
    --genomesheet genomes.csv \
    --subsample 20000 \              # Use more reads (default: 10000)
    --skip_species_check false \     # Ensure species check runs (default)
    --outdir results/ \
    -profile docker \
    -resume                          # Resume if interrupted
```

### Skip Species Identification

If you want to skip this check entirely:

```bash
nextflow run andersenlab/fq-processing-nf \
    --samplesheet samples.csv \
    --genomesheet genomes.csv \
    --skip_species_check \           # Disable species validation
    --outdir results/
```

## Understanding the Output

### Directory Structure

After running the pipeline, you'll see:

```
results/
├── species_stats/
│   └── species_mapping_stats.tsv       ← Main results file
├── trimmed/
│   ├── celegans/                       ← Validated C. elegans samples
│   │   ├── CE001_1.fq.gz
│   │   └── CE001_2.fq.gz
│   ├── cbriggsae/                      ← Validated C. briggsae samples
│   │   ├── CB002_1.fq.gz
│   │   └── CB002_2.fq.gz
│   └── ctropicalis/                    ← Validated C. tropicalis samples
│       ├── CT003_1.fq.gz
│       └── CT003_2.fq.gz
└── to_review/                          ← Samples needing attention!
    ├── PROBLEM_SAMPLE_1.fq.gz
    └── PROBLEM_SAMPLE_2.fq.gz
```

### Interpreting species_mapping_stats.tsv

This file shows the percentage of reads mapping to each genome:

```tsv
SAMPLE      celegans    cbriggsae   ctropicalis
CE001       0.967       0.018       0.012
CB002       0.034       0.956       0.008
MIXED003    0.456       0.487       0.045
LOWQUAL004  0.234       0.189       0.167
```

**How to read this:**
- **CE001**: 96.7% maps to *C. elegans* → ✓ Correct
- **CB002**: 95.6% maps to *C. briggsae* → ✓ Correct
- **MIXED003**: Split between two species → ⚠ Problem!
- **LOWQUAL004**: Low mapping everywhere → ⚠ Problem!

## What Makes a Sample "Valid"?

A sample passes validation when:

1. ✅ **Exactly one genome** has ≥95% mapping
2. ✅ **That genome** matches the expected species label

### Examples

#### ✅ Valid Sample
```
Sample: CE001 (Expected: celegans)
Mappings: celegans=96.5%, cbriggsae=2.1%, ctropicalis=0.8%
Result: VALID → Proceeds to analysis
```

#### ❌ Species Mismatch
```
Sample: CE001 (Expected: celegans)
Mappings: celegans=2.1%, cbriggsae=96.5%, ctropicalis=0.8%
Result: FLAGGED → Check if sample was mislabeled
```

#### ❌ Contamination/Mixed
```
Sample: CE001 (Expected: celegans)
Mappings: celegans=60.0%, cbriggsae=35.0%, ctropicalis=3.0%
Result: FLAGGED → Possible contamination
```

#### ❌ Low Quality
```
Sample: CE001 (Expected: celegans)
Mappings: celegans=45.0%, cbriggsae=40.0%, ctropicalis=12.0%
Result: FLAGGED → Check sequence quality
```

## Troubleshooting Common Issues

### Issue: All Samples Are Flagged

**Possible Causes:**
1. **Wrong reference genomes** - Species IDs don't match
2. **Threshold too strict** - 95% might be too high for your data
3. **Poor sequence quality** - Check your FASTQ files

**Solutions:**
```bash
# 1. Verify species IDs match between files
grep "^id" samples.csv
grep "^id" genomes.csv

# 2. Check a few reads manually
zcat sample_R1.fq.gz | head -n 4

# 3. Review FASTP quality reports (if trimming enabled)
ls results/fastp_reports/
```

### Issue: Many Samples in to_review/

**What to Check:**

1. **Open species_mapping_stats.tsv** and look for patterns:
   ```bash
   column -t -s $'\t' results/species_stats/species_mapping_stats.tsv | less -S
   ```

2. **Common patterns:**
   - All samples map to wrong species → **Label swap in samplesheet**
   - Random samples flagged → **Individual sample issues**
   - All have low mapping → **Wrong reference genome version**
   - Consistent contamination → **Lab contamination issue**

### Issue: Unexpected Species Detection

**Example**: Human sequences in *C. elegans* samples

**Investigation Steps:**

1. **Add human genome to genomesheet**:
   ```csv
   id,bwa_index,fasta
   celegans,/genomes/celegans/bwa_index,/genomes/celegans/genome.fa
   hsapiens,/genomes/human/bwa_index,/genomes/human/genome.fa
   ```

2. **Re-run to quantify contamination**:
   ```bash
   nextflow run andersenlab/fq-processing-nf \
       --samplesheet samples.csv \
       --genomesheet genomes_with_human.csv \
       --outdir results_with_human/ \
       -resume
   ```

3. **Check contamination levels** in new `species_mapping_stats.tsv`

## Advanced Usage

### Adjusting the Subsample Size

More reads = more accurate but slower:

```bash
# Conservative (faster, less accurate)
--subsample 5000

# Default (balanced)
--subsample 10000

# Thorough (slower, more accurate)
--subsample 50000
```

**Recommendation**: Start with default (10,000). Increase only if you see borderline cases near the 95% threshold.

### Modifying the Validation Threshold

⚠️ **Note**: Currently requires editing the subworkflow code

The 95% threshold is hardcoded in `subworkflows/local/species_identification/main.nf`:

```groovy
COMPILE_SPECIES_STATS(
    ch_species_stats,
    ch_expected_species,
    0.95  // ← Change this value
)
```

**Suggestions:**
- **Strict** (99%): For high-quality data, minimal tolerance
- **Standard** (95%): Default, good for most cases
- **Relaxed** (90%): For divergent strains or lower quality

### Using with Multiple Strains

If working with different strains of the same species:

**Option 1**: Use species-level identification only
```csv
id,species,fastq_1,fastq_2
N2,celegans,N2_R1.fq.gz,N2_R2.fq.gz
CB4856,celegans,CB4856_R1.fq.gz,CB4856_R2.fq.gz
```

**Option 2**: Add strain-specific genomes (advanced)
```csv
id,bwa_index,fasta
celegans_N2,/genomes/N2/bwa_index,/genomes/N2/genome.fa
celegans_CB4856,/genomes/CB4856/bwa_index,/genomes/CB4856/genome.fa
```

Then update species labels accordingly.

## Best Practices

### ✅ Do's

1. **Include related species** in your genomesheet
   - If studying *C. elegans*, include *C. briggsae* and *C. tropicalis*
   - Helps identify true contamination vs. cross-species

2. **Keep metadata organized**
   - Use consistent species naming (e.g., always "celegans", not "c_elegans" or "CElegans")
   - Document expected species clearly

3. **Review flagged samples promptly**
   - Don't ignore the `to_review/` directory
   - Each flagged sample indicates a potential issue

4. **Save species_mapping_stats.tsv**
   - Useful for publications (Supplementary Data)
   - Documents sample quality control

### ❌ Don'ts

1. **Don't skip species check on multi-species projects**
   - The time cost is minimal
   - The potential error cost is enormous

2. **Don't ignore systematic patterns**
   - If 50% of samples fail, it's not random
   - Investigate the root cause

3. **Don't use incomplete genome sets**
   - Missing an expected species will cause false flags

4. **Don't modify sample IDs between samplesheet and analysis**
   - Must maintain consistent identifiers throughout

## Real-World Examples

### Example 1: Clean Dataset

```tsv
SAMPLE      celegans    cbriggsae   ctropicalis
CE_N2_1     0.982       0.009       0.006
CE_N2_2     0.977       0.011       0.008
CB_AF16_1   0.008       0.981       0.007
CT_NIC58_1  0.012       0.006       0.978
```

**Result**: All samples validated ✓
**Action**: Proceed with full analysis

### Example 2: Single Mislabeled Sample

```tsv
SAMPLE      celegans    cbriggsae   ctropicalis
CE001       0.982       0.009       0.006
CE002       0.977       0.011       0.008
CE003       0.008       0.981       0.007  ← Flagged!
CE004       0.985       0.008       0.005
```

**Result**: CE003 flagged (labeled as elegans, is briggsae)
**Action**: 
1. Check laboratory records
2. Verify sample tube labels
3. Update metadata and re-run or exclude

### Example 3: Contamination Event

```tsv
SAMPLE      celegans    cbriggsae   ctropicalis
CE001       0.982       0.009       0.006
CE002       0.632       0.345       0.018  ← Flagged!
CE003       0.651       0.329       0.015  ← Flagged!
CE004       0.985       0.008       0.005
```

**Result**: CE002 and CE003 show *C. elegans* + *C. briggsae* contamination
**Action**:
1. Check if these samples were processed together
2. Investigate potential cross-contamination
3. May need to exclude or re-sequence

### Example 4: Poor Quality Sample

```tsv
SAMPLE      celegans    cbriggsae   ctropicalis
CE001       0.982       0.009       0.006
CE002       0.287       0.245       0.189  ← Flagged!
CE003       0.985       0.008       0.005
```

**Result**: CE002 shows low mapping across all genomes
**Action**:
1. Check FASTP quality report
2. Examine raw FASTQ quality scores
3. Likely needs re-sequencing

## Performance Expectations

### Typical Runtime

| Samples | Genomes | Subsample | Time     |
|---------|---------|-----------|----------|
| 10      | 2       | 10,000    | 2-3 min  |
| 50      | 3       | 10,000    | 8-12 min |
| 100     | 3       | 10,000    | 15-20 min|
| 100     | 5       | 10,000    | 25-30 min|

*Times assume 8-16 cores with parallel execution*

### Resource Requirements

**Per alignment task:**
- CPU: 1-2 cores
- Memory: 2-4 GB
- Disk: <500 MB

**Total (100 samples, 3 genomes):**
- Peak parallel jobs: 300
- Total compute hours: ~5-10 hours
- Wall time: 15-20 minutes (with parallelization)

## Getting Help

### Check Pipeline Logs

```bash
# View main pipeline log
cat results/pipeline_info/execution_trace.txt

# Check specific process
nextflow log <run_name> -f process,status,exit,hash
```

### Common Error Messages

**"No such file or directory: bwa_index"**
- Check genome sheet paths are correct
- Ensure BWA index files exist and are readable

**"Missing required field: species"**
- Verify samplesheet has "species" column
- Check for typos in column headers

**"Sample X not found in expected_species.tsv"**
- Species name mismatch between samplesheet and genomesheet
- Check for extra spaces or different naming conventions

### Reporting Issues

When reporting problems, include:
1. Pipeline version/commit
2. Sample of your samplesheet (anonymized)
3. Sample of your genomesheet
4. The specific error message
5. Contents of `results/species_stats/species_mapping_stats.tsv`

## Summary Checklist

Before running:
- [ ] Samplesheet has `id` and `species` columns
- [ ] Genomesheet includes all expected species
- [ ] Species names match between files
- [ ] Reference genomes are BWA-indexed
- [ ] Sufficient disk space for output

After running:
- [ ] Check `species_mapping_stats.tsv` for patterns
- [ ] Review samples in `to_review/` directory
- [ ] Validate that expected species are correctly identified
- [ ] Document any excluded or problematic samples
- [ ] Save QC report for publication/records

## Further Reading

- **Main Pipeline Documentation**: See repository README.md
- **Module Details**: Check `modules/local/*/main.nf` files
- **Configuration Options**: Review `nextflow.config`
- **Technical Documentation**: See `species_identification_documentation.md`

---

**Questions?** Open an issue at https://github.com/AndersenLab/fq-processing-nf/issues