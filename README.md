# rnaseq-report-flow

`taf-rnaseq-report-flow` collects outputs from upstream TAFFISH RNA-seq
subflows and writes a bilingual static project report, summary tables,
an offline interpretation companion page, collected key files, collected plots,
linked QC/report HTML bundles, methods, versions, command provenance, logs, and
a manifest under one explicit output directory.

Package identity:

- name: `rnaseq-report-flow`
- command: `taf-rnaseq-report-flow`
- kind: `flow`
- version: `0.1.0-r4`
- license: Apache-2.0

## RNA-seq Flow Position

This app is the report-layer subflow in the TAFFISH bulk RNA-seq flow family.
It can be run directly to collect any compatible upstream RNA-seq flow outputs,
and it is also designed to be the final reporting step of the
`rnaseq-standard-flow` umbrella. The umbrella should reuse this static
collector rather than duplicate report assembly.

## Scope

r4 supports enhanced static report collection from a completed
`rnaseq-standard-flow` output directory or any combination of these upstream
RNA-seq flow output directories:

- `rnaseq-index-flow`
- `rnaseq-expression-flow`
- `rnaseq-alignment-flow`
- `rnaseq-count-flow`
- `rnaseq-alignment-qc-flow`
- `rnaseq-de-flow`
- `rnaseq-enrichment-flow`

At least `--standard-out` or one upstream output directory is required. All
input directories are read-only. The report flow writes only to its own
`--outdir`.

r4 deliberately does not rerun Salmon, Kallisto, HISAT2, samtools,
featureCounts, RSeQC, Qualimap, DESeq2, ORA, GSEA, MultiQC, or RMarkdown. It
does not download references, gene sets, or databases. It does not perform
project-specific biological interpretation beyond organizing the upstream flow
outputs into bilingual, workflow-oriented sections with plain-language context
and a companion RNA-seq primer / interpretation guide.

## Dependencies

r4 has no additional TAFFISH tool dependencies. It is a self-contained static
collector implemented with the TAFFISH flow shell runtime and ordinary POSIX
utilities such as `awk`, `sed`, `cp`, `mkdir`, `date`, and `wc`.

Upstream flow dependencies remain recorded in the collected upstream
`versions.tsv` and `commands.sh` files.

## Usage

Collect a completed standard-flow run:

```sh
taf-rnaseq-report-flow \
  --standard-out rnaseq-standard-out \
  --project-name "Yeast SNF2 RNA-seq" \
  --outdir report-out
```

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
- `--standard-out PATH` or at least one upstream output directory option.

Optional upstream outputs:

- `--standard-out PATH`: completed `rnaseq-standard-flow` output directory. r4
  auto-discovers nested `03_results/reference`, `expression`, `alignment`,
  `count`, `alignment_qc`, `de`, and `enrichment` blocks when present, and
  consumes the standard-flow top-level `03_results/plots`, `03_results/plots/png`,
  and `03_results/plots/pdf` plot collections when available.
- `--reference-out PATH`: output from `rnaseq-index-flow`.
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
    collected_html/
  04_reports/
    rnaseq_report.html
    report_interpretation.html
    project_summary.tsv
    key_metrics.tsv
    collected_files.tsv
    plot_files.tsv
    plot_gallery.tsv
    html_reports.tsv
    tool_links.tsv
    commands.sh
    versions.tsv
    methods.txt
    flow_summary.tsv
  run.manifest.json
```

Important files:

- `04_reports/rnaseq_report.html`: enhanced static project-level report with
  the real TAFFISH logo embedded from the source asset, one-click
  English/Chinese switching, overview metrics, module status, biologically
  organized sections, embedded PNG plots, linked PDFs, table previews, linked
  QC/report HTML bundles, source links, and provenance pointers.
- `04_reports/report_interpretation.html`: offline companion primer explaining
  RNA-seq basics, experimental design, recommended reading order, module-level
  biological questions, step-level deep dives that connect biology to technical
  evidence, common statistics, common RNA-seq plot interpretation, ORA/GSEA
  boundaries, beginner FAQ, and common misinterpretations.
- `04_reports/project_summary.tsv`: high-level counts and timestamps.
- `04_reports/key_metrics.tsv`: report-ready overview metrics extracted from
  upstream summaries.
- `04_reports/collected_files.tsv`: map from original upstream files to copied
  report files.
- `04_reports/plot_files.tsv`: map from original plot files to copied report
  plot files.
- `04_reports/plot_gallery.tsv`: one row per plot group, linking PNG and PDF
  copies when available.
- `04_reports/html_reports.tsv`: linked HTML report bundles copied from
  upstream QC/report outputs, such as MultiQC, FastQC, and Qualimap.
- `04_reports/tool_links.tsv`: collected tool/flow version rows with known
  TAFFISH or upstream source links.
- `04_reports/versions.tsv`: report-flow version plus upstream version rows.
- `04_reports/commands.sh`: report-flow provenance plus upstream command logs.
- `04_reports/methods.txt`: report-flow methods plus upstream methods text.

## Report Structure

The main HTML is not a single figure dump. r4 uses a modern static layout with
a sticky sidebar, scroll-aware active section highlight, language switch,
static workflow diagrams, project-level metric cards, section-specific plot
cards, an interpretation-guide entry, a deliverables section, and compact table
previews. It organizes content by biological workflow meaning:

- Overview: project status, module coverage, and key metrics.
- Reading guide: one-click link to `04_reports/report_interpretation.html`,
  plus short interpretation principles for quality, statistics, gene sets, and
  reusable evidence. The companion page itself is a sticky-sidebar,
  scroll-aware, bilingual RNA-seq primer for new users and customer-facing
  explanation, with long-form module chapters covering wet-lab origin,
  biological meaning, biological difficulty, technical difficulty, flow
  implementation, report interpretation, and provenance.
- Reference preparation: genome, annotation, transcriptome, index, and gene
  mapping summaries.
- Read QC and expression quantification: FastQC/MultiQC links, Salmon/Kallisto
  summaries, and expression matrices.
- Alignment, counting, and RNA-seq QC: BAM maps, featureCounts summaries,
  RSeQC/Qualimap/MultiQC links, and optional alignment-route evidence.
- Differential expression: PCA, sample correlation, expression distributions,
  MA/volcano plots, DEG counts, heatmap, top-gene expression, and DESeq2 tables.
- Functional enrichment: ORA/GSEA summaries, readable/classic enrichment
  dotplots, ORA top-term barplot, GSEA NES ranking, and GSEA enrichment curves
  when produced by `rnaseq-enrichment-flow` r3.
- Deliverables: output tree, plot gallery index, HTML report index, and main
  reusable files.
- Tools and provenance: TAFFISH links, upstream tool source links, versions,
  methods, commands, and collected-file indexes.

Additional written interpretation manuals are included in this repository:

- `docs/report-interpretation.zh.md`
- `docs/report-interpretation.en.md`

The report includes the real TAFFISH logo as an embedded image so the generated
HTML remains portable. The source copy is kept in `assets/taffish-logo.png`.
The HTML stores both English and Chinese text internally, but only the selected
language is visible at a time.

r4 fixes the workflow-diagram language toggle so English pages do not show
Chinese helper text in flow cards. It also checks the generated HTML for the
specific UTF-8/Latin-1 mojibake pattern that can appear on non-UTF-8 server
locales and repairs that report HTML automatically with `iconv` when needed.

## Collected Content

The flow collects key summary tables, compact plots, and report HTML bundles
when present. Examples include:

- reference summaries, genome-index metadata, and `tx2gene.tsv`
- expression matrices and `quant_files.tsv`
- BAM file maps and alignment summaries
- featureCounts matrices and assignment summaries
- RNA-seq alignment QC summaries
- DESeq2 result tables, gene lists, plot summaries, and the DE plot set
- MultiQC reports from expression, alignment, count, and alignment-QC modules
- FastQC sample reports from expression outputs
- Qualimap sample reports from alignment-QC outputs
- ORA/GSEA result tables, dotplot source tables, enrichment plot summaries,
  readable/classic dotplots, ORA barplot, GSEA NES plot, and GSEA enrichment
  curves when present

When `--standard-out` is used and standard-flow has already collected
DE/enrichment plots under `03_results/plots`, `03_results/plots/png`, or
`03_results/plots/pdf`, report-flow uses that top-level plot collection and
avoids duplicating nested DE/enrichment plot copies.

HTML reports are copied with the local asset directories required for offline
viewing when the upstream tool writes a recognizable bundle. This keeps the
main report compact while still linking to detailed QC and sample-level
reports.

## Validation

`tests/smoke.sh` builds the report flow and runs it on tiny synthetic upstream
output directories. It checks enhanced HTML report generation, collected
tables, collected plots, copied HTML report bundles, tool links, provenance,
language-toggle CSS, C-locale rendering, mojibake absence, `--force`, and
output-directory cleanliness.

`tests/formal.sh` uses the central yeast SNF2 count matrix and GO gene-set
bundle when available. It builds and runs `rnaseq-de-flow`, builds and runs
`rnaseq-enrichment-flow` r3, then collects the real `de-out` and
`enrichment-out` directories through `rnaseq-report-flow`. It checks the r4
plot gallery, workflow diagrams, active navigation hooks, linked report surface,
language-toggle CSS, mojibake absence, and deliverables section. The central data tree can be prepared
with `repos/apps/bio/flows/rna-seq/test-data/yeast/rnaseq-yeast-get-data`;
downstream formal tests read it via `TAFFISH_RNASEQ_TESTDATA` or the default
local `test-data/yeast/data/03_results` path.
