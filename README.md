# rnaseq-report-flow

`taf-rnaseq-report-flow` collects outputs from upstream TAFFISH RNA-seq
subflows and writes a bilingual static project report, summary tables,
an offline interpretation companion page, collected key files, collected plots,
embedded QC/report child pages, copied fallback HTML bundles, methods, versions,
command provenance, logs, and a manifest under one explicit output directory.

Package identity:

- name: `rnaseq-report-flow`
- command: `taf-rnaseq-report-flow`
- kind: `flow`
- version: `0.3.0-r1`
- license: Apache-2.0

## RNA-seq Flow Position

This app is the report-layer subflow in the TAFFISH bulk RNA-seq flow family.
It can be run directly to collect any compatible upstream RNA-seq flow outputs,
and it is also designed to be the final reporting step of the
`rnaseq-standard-flow` umbrella. The umbrella should reuse this static
collector rather than duplicate report assembly.

## Scope

0.3.0-r1 supports enhanced static report collection from a completed
`rnaseq-standard-flow` output directory or any combination of these upstream
RNA-seq flow output directories:

- `rnaseq-index-flow`
- `rnaseq-expression-flow`
- `rnaseq-alignment-flow`
- `rnaseq-count-flow`
- `rnaseq-alignment-qc-flow`
- `rnaseq-de-flow`
- `rnaseq-enrichment-flow`
- `rnaseq-denovo-assembly-flow`
- `rnaseq-denovo-expression-flow`
- `rnaseq-denovo-annotation-flow`

At least `--standard-out` or one upstream output directory is required. All
input directories are read-only. The report flow writes only to its own
`--outdir`.

0.3.0-r1 is backward-compatible with the existing reference-route report contract: existing commands that
only pass `--standard-out`, reference-route outputs, DE outputs, or enrichment
outputs continue to work unchanged. The existing de novo options remain
additive and only affect the report when those upstream directories are
supplied or auto-discovered under `--standard-out`.

0.3.0-r1 is a report-contract feature release over `0.2.0-r2`: the main HTML is
now designed as a standalone delivery artifact based on the shared TAFFISH
`flow-report` template contract. It carries embedded payloads for PNG figures,
collected TSV/text tables, collected QC/report child pages, and the RNA-seq
interpretation guide. Users can click a MultiQC, FastQC, Qualimap, table, or
guide link from the main report and open the original child page or text page in
a separate local browser page even when only the main HTML is distributed. The
copied `03_results/collected_html/` bundles and `03_results/collected_tables/`
files remain available for audit and fallback.

0.3.0-r1 deliberately does not rerun Salmon, Kallisto, HISAT2, samtools,
featureCounts, RSeQC, Qualimap, Trinity, rnaSPAdes, seqkit, BUSCO,
TransDecoder, DIAMOND, DESeq2, ORA, GSEA, MultiQC, or RMarkdown. It does not
download references, gene sets, protein databases, GO mappings, or other online
resources. It does not perform project-specific biological interpretation
beyond organizing the upstream flow outputs into bilingual, workflow-oriented
sections with plain-language context and a companion RNA-seq primer /
interpretation guide.

## Dependencies

0.3.0-r1 has no additional TAFFISH tool dependencies. It is a self-contained static
collector implemented with the TAFFISH flow shell runtime and ordinary shell
utilities such as `awk`, `sed`, `cp`, `mkdir`, `date`, `find`, `base64`, `tr`,
and `wc`.

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

Collect a no-reference/de novo route:

```sh
taf-rnaseq-report-flow \
  --denovo-assembly-out denovo-assembly-out \
  --denovo-expression-out denovo-expression-out \
  --denovo-annotation-out denovo-annotation-out \
  --project-name "No-reference RNA-seq" \
  --outdir report-out
```

## Parameters

Required:

- `--outdir PATH`, `-o PATH`: output directory. The flow refuses to run if it
  already exists unless `--force` is used.
- `--standard-out PATH` or at least one upstream output directory option.

Optional upstream outputs:

- `--standard-out PATH`: completed `rnaseq-standard-flow` output directory. 0.3.0-r1
  auto-discovers nested `03_results/reference`, `expression`, `alignment`,
  `count`, `alignment_qc`, `de`, `enrichment`, `denovo_assembly`,
  `denovo_expression`, and `denovo_annotation` blocks when present, and
  consumes the standard-flow top-level `03_results/plots`, `03_results/plots/png`,
  and `03_results/plots/pdf` plot collections when available. Hyphenated
  de novo result directory names, such as `03_results/denovo-assembly`, are
  also recognized for compatibility with draft outputs. Archived standard
  delivery packages that already contain `03_results/collected_tables`,
  `03_results/collected_plots`, `03_results/collected_html`, and the matching
  `04_reports/*.tsv` indexes can also be used as `--standard-out` inputs; the
  report flow reconstructs compatible module inputs from those collected files
  and renders a fresh template report without rerunning upstream analysis.
- `--reference-out PATH`: output from `rnaseq-index-flow`.
- `--expression-out PATH`: output from `rnaseq-expression-flow`.
- `--alignment-out PATH`: output from `rnaseq-alignment-flow`.
- `--count-out PATH`: output from `rnaseq-count-flow`.
- `--alignment-qc-out PATH`: output from `rnaseq-alignment-qc-flow`.
- `--de-out PATH`: output from `rnaseq-de-flow`.
- `--enrichment-out PATH`: output from `rnaseq-enrichment-flow`.
- `--denovo-assembly-out PATH`: output from `rnaseq-denovo-assembly-flow`.
  The report collects assembly summaries, assembly statistics, read support,
  optional BUSCO status, versions, methods, commands, manifest, and HTML
  bundles when present.
- `--denovo-expression-out PATH`: output from `rnaseq-denovo-expression-flow`.
  The report collects transcript count/TPM matrices, optional gene or
  pseudo-gene matrices, quant indexes, mapping summaries, matrix semantics,
  transcript statistics, QC/report HTML bundles, versions, methods, commands,
  and manifest when present.
- `--denovo-annotation-out PATH`: output from `rnaseq-denovo-annotation-flow`.
  The report collects annotation summaries, protein hits, transcript
  annotation, optional ID mapping, annotation-derived `denovo_go.gmt`,
  `denovo_background.tsv`, versions, methods, commands, and manifest when
  present.

Other options:

- `--project-name TEXT`: report title. Default: `RNA-seq project`.
- `--analysis-mode auto|reference|denovo|mixed`: analysis mode shown in the
  report overview. Default: `auto`. `rnaseq-standard-flow` passes this
  explicitly so the overview distinguishes genome-guided and no-reference
  transcriptome routes even before top-level standard-flow summaries are
  finalized.
- `--analysis-route auto|salmon|both|none|unknown`: standard-flow route shown
  in key metrics. Default: `auto`. `rnaseq-standard-flow` passes this
  explicitly so the report does not depend on a top-level summary file that is
  written after the report step.
- `--de-source auto|salmon|featurecounts|none|unknown`: DE count source shown
  in key metrics. Default: `auto`. Use `salmon` for Salmon/tximport counts or
  `featurecounts` for the optional reference alignment/count route.
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
    embedded_html_reports.tsv
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
  and embedded QC/report child pages, source links, and provenance pointers.
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
- `04_reports/embedded_html_reports.tsv`: index of copied HTML bundles that
  were converted into embedded child-page payloads inside the main report,
  including byte counts and embedding status.
- `04_reports/tool_links.tsv`: collected tool/flow version rows with known
  TAFFISH or upstream source links.
- `04_reports/versions.tsv`: report-flow version plus upstream version rows.
- `04_reports/commands.sh`: report-flow provenance plus upstream command logs.
- `04_reports/methods.txt`: report-flow methods plus upstream methods text.

## Report Structure

The main HTML is not a single figure dump. 0.3.0-r1 uses a modern static layout with
a sticky sidebar, scroll-aware active section highlight, language switch,
static workflow diagrams, project-level metric cards, section-specific plot
cards, an interpretation-guide entry, a deliverables section, and compact table
previews. It organizes content by biological workflow meaning:

- Overview: project status, module coverage, and key metrics.
- Reading guide: one-click link to `04_reports/report_interpretation.html`,
  with an embedded child-page payload in the main report when JavaScript is
  available,
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
- De novo assembly, expression, and annotation: assembly quality, transcript
  feature-space metrics, optional BUSCO status, transcript-level expression
  matrices, matrix semantics, homolog-derived annotation, and enrichment
  readiness when those no-reference outputs are supplied.
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

0.3.0-r1 also embeds collected TSV/text tables and QC/report child pages into
the main `rnaseq_report.html` when they can be bundled safely. Clicking a table
opens a local text page from the embedded table payload. Clicking a MultiQC,
FastQC, Qualimap, the interpretation guide, or a similar report opens the
original child report in a new local browser page from the embedded HTML
payload. The renderer intentionally uses `window.open` plus `document.write`
and does not use top-level `blob:`, `iframe`, or `srcdoc` transport, because
heavy reports such as MultiQC can lose interactive plots under those transports.
Copied bundles in `03_results/collected_html/` and source tables in
`03_results/collected_tables/` remain available as fallback and audit material.

0.3.0-r1 keeps the language-toggle and encoding fixes: English pages do not show
Chinese helper text in flow cards, and generated HTML is checked for the
specific UTF-8/Latin-1 mojibake pattern that can appear on non-UTF-8 server
locales. When `iconv` is available, that report HTML is repaired automatically.

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
- de novo assembly summaries, assembly statistics, seqkit statistics,
  read-support tables, optional BUSCO summaries, and assembly HTML reports
- de novo expression summaries, quant file indexes, matrix semantics,
  mapping summaries, transcript statistics, transcript count/TPM matrices,
  optional gene or pseudo-gene matrices, and expression QC/report HTML bundles
- de novo key metrics that spell out transcript-level-only matrices when no
  explicit tx2gene or cluster mapping was supplied
- de novo annotation summaries, annotation input records, protein hits,
  transcript annotation, optional ID mapping, annotation-derived GMT, and
  annotation-derived background genes

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
tables, collected plots, copied and embedded HTML report bundles, de novo assembly/
expression/annotation collection, de novo report sections, tool links,
provenance, language-toggle CSS, C-locale rendering, mojibake absence,
`--force`, and output-directory cleanliness.

`tests/formal.sh` uses the central yeast SNF2 count matrix and GO gene-set
bundle when available. It builds and runs `rnaseq-de-flow`, builds and runs
`rnaseq-enrichment-flow` r3, then collects the real `de-out` and
`enrichment-out` directories through `rnaseq-report-flow`. It checks the 0.3.0-r1
plot gallery, workflow diagrams, active navigation hooks, embedded report surface,
embedded child-report index, language-toggle CSS, mojibake absence, and deliverables section. The central
data tree can be prepared with
`repos/apps/bio/flows/rna-seq/test-data/yeast/rnaseq-yeast-get-data`;
downstream formal tests read it via `TAFFISH_RNASEQ_TESTDATA` or the default
local `test-data/yeast/data/03_results` path.
