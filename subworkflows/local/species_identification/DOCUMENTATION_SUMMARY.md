# Species Identification Subworkflow - Documentation Package

## Overview

This documentation package provides comprehensive information about the `SPECIES_IDENTIFICATION` subworkflow from the `andersenlab/fq-processing-nf` pipeline.

## What's Included

### 1. Technical Documentation (species_identification_documentation.md)
**Target Audience**: Developers, bioinformaticians, pipeline maintainers

**Contents**:
- Complete workflow architecture and process flow
- Detailed module descriptions and algorithms
- Channel transformations and data flow
- Integration with main pipeline
- Performance characteristics
- Extension and modification guidelines
- Technical specifications

**Use this when you need to**:
- Understand the implementation details
- Modify or extend the subworkflow
- Debug technical issues
- Integrate with other workflows
- Optimize performance

### 2. User Guide (species_identification_user_guide.md)
**Target Audience**: End users, lab scientists, data analysts

**Contents**:
- Quick start instructions
- Input file format requirements
- Step-by-step usage examples
- Output interpretation guide
- Troubleshooting common issues
- Real-world example scenarios
- Best practices and recommendations
- Performance expectations

**Use this when you need to**:
- Run the pipeline for the first time
- Understand what the output means
- Troubleshoot flagged samples
- Set up input files correctly
- Interpret species mapping results

### 3. Workflow Diagram (species_identification_workflow_diagram.txt)
**Target Audience**: All users

**Contents**:
- ASCII workflow diagram
- Process flow visualization
- Channel multiplicity illustration
- Decision tree for validation
- Performance timeline
- Data volume metrics
- Mermaid diagram code for rendering

**Use this when you need to**:
- Get a visual overview of the workflow
- Understand process dependencies
- Present the workflow in meetings
- Include in publications or reports
- Quick reference for workflow structure

## Quick Navigation Guide

### "I want to run the pipeline"
→ Start with **species_identification_user_guide.md**
- Section: "Quick Start"
- Section: "Setting Up Your Input Files"
- Section: "Running the Pipeline"

### "My samples are being flagged"
→ Check **species_identification_user_guide.md**
- Section: "Understanding the Output"
- Section: "What Makes a Sample Valid?"
- Section: "Troubleshooting Common Issues"
- Section: "Real-World Examples"

### "I need to understand how it works"
→ Read **species_identification_documentation.md**
- Section: "Workflow Architecture"
- Section: "Process Flow"
- Section: "Key Modules"

### "I want to modify the workflow"
→ Study **species_identification_documentation.md**
- Section: "Extending the Subworkflow"
- Section: "Configuration"
- Section: "Key Modules"

### "I need a visual representation"
→ Open **species_identification_workflow_diagram.txt**
- ASCII Workflow Diagram
- Decision Tree
- Mermaid Diagram Code

## Key Concepts Summary

### What It Does

The subworkflow validates that sequenced samples match their expected species labels by:

1. **Subsampling**: Takes 10,000 reads from each sample (fast, efficient)
2. **Multi-genome alignment**: Aligns reads to all reference genomes
3. **Percentage calculation**: Computes mapping percentage to each genome
4. **Validation**: Compares results against expected species labels
5. **Classification**: Routes samples to "identified" or "mismatched" channels

### Validation Criteria

A sample passes when:
- ✅ Exactly ONE genome has ≥95% mapping percentage
- ✅ That genome matches the expected species label

### Common Failure Modes

❌ **Species Mismatch**: Sample labeled incorrectly
❌ **Contamination**: Reads mapping to multiple species
❌ **Low Quality**: Poor mapping across all genomes
❌ **Wrong Reference**: Reference genome doesn't match data

## File Organization Recommendation

For optimal use, organize these files as follows:

```
project_documentation/
├── README.md                                    ← Link to all docs
├── species_identification/
│   ├── technical_documentation.md              ← Detailed technical info
│   ├── user_guide.md                            ← How-to for users
│   └── workflow_diagram.txt                     ← Visual reference
└── examples/
    ├── sample_samplesheet.csv
    ├── sample_genomesheet.csv
    └── example_species_mapping_stats.tsv
```

## Integration with Repository

Suggested placement in the `fq-processing-nf` repository:

```
fq-processing-nf/
├── docs/
│   ├── species_identification.md               ← User guide
│   └── advanced/
│       └── species_identification_technical.md  ← Technical docs
├── subworkflows/
│   └── local/
│       └── species_identification/
│           ├── main.nf
│           └── README.md                        ← Quick reference
└── assets/
    └── diagrams/
        └── species_identification_workflow.txt  ← Visual diagram
```

## Usage Examples by Role

### Research Scientist
1. Read **User Guide** sections:
   - "What Does This Do?"
   - "Setting Up Your Input Files"
   - "Interpreting species_mapping_stats.tsv"
2. Reference **Workflow Diagram** for overview
3. Check **User Guide** "Real-World Examples" for similar cases

### Bioinformatics Core
1. Review **Technical Documentation** for implementation details
2. Use **User Guide** "Troubleshooting" for user support
3. Reference **Performance Considerations** for resource allocation

### Pipeline Developer
1. Study **Technical Documentation** comprehensively
2. Review **Process Flow** and **Channel transformations**
3. Check **Extending the Subworkflow** for modification guidance
4. Use **Workflow Diagram** to understand dependencies

### Lab Manager
1. Skim **User Guide** "Overview" and "What Does This Do?"
2. Review **"When Should You Use This?"** for project planning
3. Check **Performance Expectations** for resource budgeting

## Key Statistics

### Documentation Coverage

- **Total pages**: ~40 pages (combined)
- **Code examples**: 30+
- **Workflow diagrams**: 5
- **Real-world examples**: 6
- **Troubleshooting scenarios**: 8

### Topics Covered

**Technical (Documentation)**:
- Process architecture (12 steps)
- Module descriptions (3 custom + 3 nf-core)
- Channel operations (8 transformations)
- Integration patterns
- Performance optimization
- Extension guidelines

**Practical (User Guide)**:
- Input formats
- Execution examples
- Output interpretation
- Troubleshooting (4 categories)
- Best practices (10+ tips)
- Real scenarios (4 examples)

**Visual (Diagram)**:
- Workflow ASCII diagram
- Decision tree
- Timeline
- Resource profile
- Mermaid code

## Maintenance Notes

### Keeping Documentation Current

When updating the subworkflow, review:

1. **Version-specific changes**:
   - Module updates
   - Parameter changes
   - New features

2. **Documentation to update**:
   - Technical: Process flow, module descriptions
   - User Guide: Command examples, output formats
   - Diagram: New processes or flows

3. **Testing examples**:
   - Verify all command examples work
   - Update output examples if format changes
   - Test troubleshooting steps

### Contributing Improvements

Suggested documentation enhancements:

- [ ] Add screenshots of actual output files
- [ ] Create video walkthrough for user guide
- [ ] Add interactive Mermaid diagrams
- [ ] Include example datasets (test data)
- [ ] Create FAQ section from user questions
- [ ] Add case studies from real projects
- [ ] Develop troubleshooting decision tree
- [ ] Create quick reference card (1-page)

## Version Information

**Pipeline**: andersenlab/fq-processing-nf
**Subworkflow**: SPECIES_IDENTIFICATION
**Documentation Created**: November 12, 2025
**Repository**: https://github.com/AndersenLab/fq-processing-nf

## Feedback and Contributions

To improve this documentation:

1. **Report issues**: Open GitHub issue with "Documentation" label
2. **Suggest improvements**: Submit pull request with changes
3. **Share examples**: Contribute real-world use cases
4. **Ask questions**: Questions become FAQ entries

## Additional Resources

### Related Pipeline Components

- **Main workflow**: `workflows/fq_processing.nf`
- **Read trimming**: FASTP module
- **Read alignment**: `subworkflows/local/read_alignment/`
- **Quality control**: General QC processes

### External Documentation

- **Nextflow DSL2**: https://www.nextflow.io/docs/latest/dsl2.html
- **nf-core modules**: https://nf-co.re/modules
- **BWA documentation**: http://bio-bwa.sourceforge.net/
- **SAMtools**: http://www.htslib.org/doc/samtools.html

### Scientific Background

**Key Publications** on species identification in sequencing:

1. Mapping-based approaches for sample QC
2. Contamination detection methods
3. Reference genome selection strategies
4. Quality metrics in genomics

## Summary

This documentation package provides comprehensive coverage of the species identification subworkflow from three perspectives:

1. **Technical** (for developers)
2. **Practical** (for users)
3. **Visual** (for everyone)

Choose the appropriate document based on your needs and role, and refer to this summary for navigation guidance.

---

**Questions or suggestions?** Contact the pipeline maintainers or open an issue on GitHub.