# Species Identification Subworkflow - Documentation

Complete documentation for the `SPECIES_IDENTIFICATION` subworkflow in the [andersenlab/fq-processing-nf](https://github.com/AndersenLab/fq-processing-nf) pipeline.

## 📚 Documentation Files

| File | Purpose | Target Audience |
|------|---------|-----------------|
| **[User Guide](species_identification_user_guide.md)** | Practical guide for running and interpreting results | Lab scientists, data analysts, end users |
| **[Technical Documentation](species_identification_documentation.md)** | Complete technical specification and implementation details | Developers, bioinformaticians, maintainers |
| **[Workflow Diagram](species_identification_workflow_diagram.txt)** | Visual representation of the workflow | All users |
| **[Summary](DOCUMENTATION_SUMMARY.md)** | Documentation package overview and navigation guide | All users |

## 🚀 Quick Start

### For Users (First Time)
1. Read: [User Guide - Quick Start Section](species_identification_user_guide.md#quick-start)
2. Review: [Workflow Diagram](species_identification_workflow_diagram.txt)
3. Check: [User Guide - Setting Up Input Files](species_identification_user_guide.md#setting-up-your-input-files)

### For Developers
1. Study: [Technical Documentation - Workflow Architecture](species_identification_documentation.md#workflow-architecture)
2. Review: [Technical Documentation - Process Flow](species_identification_documentation.md#process-flow)
3. Check: [Workflow Diagram](species_identification_workflow_diagram.txt)

## 🎯 What Does This Subworkflow Do?

The species identification subworkflow validates that sequenced samples match their expected species labels by:

1. **Subsampling** 10,000 reads from each sample
2. **Aligning** to multiple reference genomes
3. **Calculating** mapping percentages
4. **Validating** against expected species
5. **Routing** samples to "validated" or "needs review" channels

**Key Benefit**: Catches sample mix-ups, contamination, and mislabeling before expensive downstream analysis.

## 📊 Example Output

### Validation Results
```tsv
SAMPLE      celegans    cbriggsae   ctropicalis   Status
CE001       0.967       0.018       0.012         ✓ Valid
CB002       0.034       0.956       0.008         ✓ Valid
MIXED003    0.456       0.487       0.045         ⚠ Review
LOWQUAL004  0.234       0.189       0.167         ⚠ Review
```

### Directory Organization
```
results/
├── species_stats/
│   └── species_mapping_stats.tsv       ← Review this file
├── trimmed/
│   ├── celegans/                       ← Validated samples by species
│   ├── cbriggsae/
│   └── ctropicalis/
└── to_review/                          ← Flagged samples (investigate!)
    ├── MIXED003_1.fq.gz
    └── LOWQUAL004_1.fq.gz
```

## 🔍 When to Use

### ✅ Recommended For:
- Multi-species projects
- External sample sources
- High-throughput screening
- Uncertain sample provenance
- Quality control requirements

### ⏭️ Can Skip For:
- Single-species trusted samples
- Re-processing validated data
- Extreme resource constraints

## 💡 Quick Examples

### Basic Usage
```bash
nextflow run andersenlab/fq-processing-nf \
    --samplesheet samples.csv \
    --genomesheet genomes.csv \
    --outdir results/ \
    -profile docker
```

### With Custom Settings
```bash
nextflow run andersenlab/fq-processing-nf \
    --samplesheet samples.csv \
    --genomesheet genomes.csv \
    --subsample 20000 \              # More reads for higher confidence
    --outdir results/ \
    -profile docker
```

### Skip Species Check
```bash
nextflow run andersenlab/fq-processing-nf \
    --samplesheet samples.csv \
    --genomesheet genomes.csv \
    --skip_species_check \           # Disable validation
    --outdir results/
```

## 📖 Documentation Guide by Task

### "I want to run the pipeline for the first time"
→ **[User Guide](species_identification_user_guide.md)**
- Quick Start
- Setting Up Your Input Files
- Running the Pipeline
- Understanding the Output

### "I have samples flagged for review"
→ **[User Guide - Troubleshooting](species_identification_user_guide.md#troubleshooting-common-issues)**
- What Makes a Sample "Valid"?
- Troubleshooting Common Issues
- Real-World Examples
- Interpreting species_mapping_stats.tsv

### "I need to understand the algorithm"
→ **[Technical Documentation](species_identification_documentation.md)**
- Workflow Architecture
- Process Flow (12 detailed steps)
- Key Modules
- Validation Logic

### "I want to modify the workflow"
→ **[Technical Documentation - Extending](species_identification_documentation.md#extending-the-subworkflow)**
- Adding Custom Validation Rules
- Parameterizing Thresholds
- Module Specifications
- Integration Patterns

### "I need a visual overview"
→ **[Workflow Diagram](species_identification_workflow_diagram.txt)**
- ASCII Workflow Diagram
- Decision Tree
- Performance Timeline
- Mermaid Diagram Code

## 🎓 Key Concepts

### Validation Criteria
A sample **passes** when:
- ✅ Exactly ONE genome has ≥95% mapping
- ✅ That genome matches the expected species label

### Common Failure Modes
| Pattern | Meaning | Action |
|---------|---------|--------|
| High mapping to wrong species | Sample mislabeled | Check lab records |
| Split mapping (2+ species) | Contamination | Investigate source |
| Low mapping everywhere | Poor quality | Check FASTQ quality |
| Systematic failures | Wrong reference | Verify genome files |

## ⚡ Performance

### Typical Runtime
- **10 samples, 2 genomes**: 2-3 minutes
- **100 samples, 3 genomes**: 15-20 minutes
- **100 samples, 5 genomes**: 25-30 minutes

### Resource Requirements (per task)
- **CPU**: 1-2 cores
- **Memory**: 2-4 GB
- **Disk**: <500 MB

## 🛠️ Input Files Required

### 1. Samplesheet (samples.csv)
```csv
id,species,fastq_1,fastq_2
CE001,celegans,/data/CE001_R1.fq.gz,/data/CE001_R2.fq.gz
CB002,cbriggsae,/data/CB002_R1.fq.gz,/data/CB002_R2.fq.gz
```
**Critical**: `species` must match genome IDs!

### 2. Genomesheet (genomes.csv)
```csv
id,bwa_index,fasta
celegans,/genomes/celegans/bwa_index,/genomes/celegans/genome.fa
cbriggsae,/genomes/cbriggsae/bwa_index,/genomes/cbriggsae/genome.fa
```
**Tip**: Include all expected species + common contaminants

## 🔧 Configuration

### Available Parameters
```groovy
params {
    subsample = 10000              // Number of reads for species check
    skip_species_check = false     // Enable/disable validation
    skip_trimming = false           // Run FASTP trimming first
}
```

### Validation Threshold
Currently hardcoded at 95% in the subworkflow. See [Technical Documentation - Configuration](species_identification_documentation.md#configuration) for details.

## 📝 Troubleshooting Quick Reference

| Symptom | Check | Solution |
|---------|-------|----------|
| All samples flagged | Species ID mismatch | Verify samplesheet vs genomesheet IDs |
| Random samples flagged | Check mapping stats | Review individual sample quality |
| Low mapping overall | Wrong genome version | Verify reference genome sources |
| Many "to_review" samples | Threshold too strict | Consider lowering from 95% |

**Full troubleshooting guide**: [User Guide - Troubleshooting Section](species_identification_user_guide.md#troubleshooting-common-issues)

## 🤝 Contributing

Ways to improve this documentation:

1. **Report unclear sections**: Open GitHub issue
2. **Suggest improvements**: Submit pull request
3. **Share examples**: Contribute real-world cases
4. **Ask questions**: Help us build better FAQs

## 📚 Additional Resources

### Pipeline Components
- Main workflow: `workflows/fq_processing.nf`
- Read trimming: FASTP module
- Alignment subworkflow: `subworkflows/local/read_alignment/`

### External Documentation
- [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html)
- [nf-core modules](https://nf-co.re/modules)
- [BWA Manual](http://bio-bwa.sourceforge.net/)
- [SAMtools Documentation](http://www.htslib.org/doc/samtools.html)

## 📞 Support

### Getting Help
1. Check relevant documentation section
2. Review troubleshooting guides
3. Search existing GitHub issues
4. Open new issue with details

### Reporting Issues
Include:
- Pipeline version
- Sample input files (anonymized)
- Error messages
- Contents of `species_mapping_stats.tsv`

## 📄 License

This documentation describes the `andersenlab/fq-processing-nf` pipeline, which is licensed under MIT.

## ✍️ Authors

**Original Pipeline Author**: Michael Sauria  
**Documentation**: Seqera AI  
**Repository**: https://github.com/AndersenLab/fq-processing-nf

---

## Document Versions

| Document | Size | Description |
|----------|------|-------------|
| User Guide | ~14 KB | Practical usage guide |
| Technical Documentation | ~16 KB | Implementation details |
| Workflow Diagram | ~11 KB | Visual representations |
| Summary | ~10 KB | Documentation overview |

**Total Documentation**: ~50 KB covering all aspects of the species identification subworkflow

---

**Last Updated**: November 12, 2025  
**Pipeline Repository**: https://github.com/AndersenLab/fq-processing-nf