# rnaseq-report-flow

`taf-rnaseq-report-flow` collects outputs from upstream TAFFISH RNA-seq
subflows and writes a static project report, summary tables, collected key
files, methods, versions, command provenance, logs, and a manifest under one
explicit output directory.

Package identity:

- name: `rnaseq-report-flow`
- command: `taf-rnaseq-report-flow`
- kind: `flow`
- version: `0.1.0-r1`
- license: Apache-2.0

## RNA-seq Flow Position

This app is the report-layer subflow in the TAFFISH bulk RNA-seq flow family.
It can be run directly to collect any compatible upstream RNA-seq flow outputs,
and it is also designed to be the final reporting step of the future
`rnaseq-standard-flow` umbrella. The umbrella should reuse this static
collector rather than duplicate report assembly.

## Scope

r1 supports static report collection from any combination of these upstream
RNA-seq flow output directories:

- `rnaseq-expression-flow`
- `rnaseq-alignment-flow`
- `rnaseq-count-flow`
- `rnaseq-alignment-qc-flow`
- `rnaseq-de-flow`
- `rnaseq-enrichment-flow`

At least one upstream output directory is required. All upstream directories are
read-only inputs. The report flow writes only to its own `--outdir`.

r1 deliberately does not rerun Salmon, Kallisto, HISAT2, samtools,
featureCounts, RSeQC, Qualimap, DESeq2, ORA, GSEA, MultiQC, or RMarkdown. It
does not download references, gene sets, or databases. It does not perform
biological interpretation beyond organizing the upstream flow outputs.

## Dependencies

r1 has no additional TAFFISH tool dependencies. It is a self-contained static
collector implemented with the TAFFISH flow shell runtime and ordinary POSIX
utilities such as `awk`, `sed`, `cp`, `mkdir`, `date`, and `wc`.

Upstream flow dependencies remain recorded in the collected upstream
`versions.tsv` and `commands.sh` files.

## Usage

Collect a DE and enrichment report:

```sh
taf-rnaseq-report-flow \
  --de-out de-out \
  --enrichment-out enrichment-out \
  --project-name "Yeast SNF2 RNA-seq" \
  --outdir report-out
```

Collect the alignment-count route:

```sh
taf-rnaseq-report-flow \
  --alignment-out align-out \
  --count-out count-out \
  --alignment-qc-out alignment-qc-out \
  --de-out de-out \
  --enrichment-out enrichment-out \
  --outdir report-out
```

Collect the lightweight expression route:

```sh
taf-rnaseq-report-flow \
  --expression-out expression-out \
  --de-out de-out \
  --enrichment-out enrichment-out \
  --outdir report-out
```

## Parameters

Required:

- `--outdir PATH`, `-o PATH`: output directory. The flow refuses to run if it
  already exists unless `--force` is used.
- At least one upstream output directory option.

Optional upstream outputs:

- `--expression-out PATH`: output from `rnaseq-expression-flow`.
- `--alignment-out PATH`: output from `rnaseq-alignment-flow`.
- `--count-out PATH`: output from `rnaseq-count-flow`.
- `--alignment-qc-out PATH`: output from `rnaseq-alignment-qc-flow`.
- `--de-out PATH`: output from `rnaseq-de-flow`.
- `--enrichment-out PATH`: output from `rnaseq-enrichment-flow`.

Other options:

- `--project-name TEXT`: report title. Default: `RNA-seq project`.
- `--force`: replace the standard rnaseq-report-flow output files inside an
  existing output directory.

## Outputs

All flow-created files are written under `<outdir>/`:

```text
<outdir>/
  00_inputs/
    upstream_outputs.tsv
  01_logs/
    flow.log
    steps/
      01_collect_inputs.log
      02_render_report.log
  03_results/
    collected_tables/
    collected_plots/
  04_reports/
    rnaseq_report.html
    project_summary.tsv
    collected_files.tsv
    commands.sh
    versions.tsv
    methods.txt
    flow_summary.tsv
  run.manifest.json
```

Important files:

- `04_reports/rnaseq_report.html`: static project-level report.
- `04_reports/project_summary.tsv`: high-level counts and timestamps.
- `04_reports/collected_files.tsv`: map from original upstream files to copied
  report files.
- `04_reports/versions.tsv`: report-flow version plus upstream version rows.
- `04_reports/commands.sh`: report-flow provenance plus upstream command logs.
- `04_reports/methods.txt`: report-flow methods plus upstream methods text.

## Collected Content

The flow collects key summary tables and compact plots when present. Examples
include:

- expression matrices and `quant_files.tsv`
- BAM file maps and alignment summaries
- featureCounts matrices and assignment summaries
- RNA-seq alignment QC summaries
- DESeq2 result tables, gene lists, and DE plots
- ORA/GSEA result tables and enrichment dotplots

Large upstream reports, such as full MultiQC HTML files, are not copied in r1.
Their source modules remain listed through the upstream output directories and
the collected provenance files.

## Validation

`tests/smoke.sh` builds the report flow and runs it on tiny synthetic upstream
output directories. It checks report generation, collected files, provenance,
`--force`, and output-directory cleanliness.

`tests/formal.sh` uses the central yeast SNF2 count matrix and GO gene-set
bundle when available. It builds and runs `rnaseq-de-flow`, builds and runs
`rnaseq-enrichment-flow`, then collects the real `de-out` and `enrichment-out`
directories through `rnaseq-report-flow`. The central data tree can be prepared
with `repos/apps/bio/flows/rna-seq/test-data/yeast/rnaseq-yeast-get-data`;
downstream formal tests read it via `TAFFISH_RNASEQ_TESTDATA` or the default
local `test-data/yeast/data/03_results` path.
