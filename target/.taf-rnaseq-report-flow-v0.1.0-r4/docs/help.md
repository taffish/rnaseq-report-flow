rnaseq-report-flow 0.1.0-r4

Purpose:
  Collect outputs from upstream TAFFISH RNA-seq subflows or a completed
  rnaseq-standard-flow run and write an enhanced bilingual static HTML project
  report with one-click English/Chinese switching, an offline interpretation
  companion page, summary tables, collected key files, collected plots, linked
  QC/report HTML bundles, methods, versions, command provenance, logs, and a
  manifest under one explicit output directory.

Flow family role:
  This is the report-layer TAFFISH RNA-seq subflow. It can be run directly to
  collect compatible upstream outputs, and it is intended to be the final
  reporting step of rnaseq-standard-flow orchestration.

Usage:
  taf-rnaseq-report-flow \
    --standard-out rnaseq-standard-out \
    --project-name "Yeast SNF2 RNA-seq" \
    --outdir report-out

  taf-rnaseq-report-flow \
    --de-out de-out \
    --enrichment-out enrichment-out \
    --project-name "Yeast SNF2 RNA-seq" \
    --outdir report-out

  taf-rnaseq-report-flow \
    --expression-out expression-out \
    --alignment-out align-out \
    --count-out count-out \
    --alignment-qc-out alignment-qc-out \
    --de-out de-out \
    --enrichment-out enrichment-out \
    --outdir report-out

Required output:
  --outdir PATH, -o PATH
      Output directory. The flow refuses to run if PATH already exists unless
      --force is used.

Required input:
  Provide --standard-out or at least one upstream output directory:

  --standard-out PATH
      Completed rnaseq-standard-flow output directory. r4 auto-discovers
      reference, expression, alignment, count, alignment_qc, de, and
      enrichment blocks under PATH/03_results/ when present. It also consumes
      standard-flow top-level plot collections under PATH/03_results/plots,
      PATH/03_results/plots/png, and PATH/03_results/plots/pdf when available.

  --reference-out PATH
      Output directory from rnaseq-index-flow.

  --expression-out PATH
      Output directory from rnaseq-expression-flow.

  --alignment-out PATH
      Output directory from rnaseq-alignment-flow.

  --count-out PATH
      Output directory from rnaseq-count-flow.

  --alignment-qc-out PATH
      Output directory from rnaseq-alignment-qc-flow.

  --de-out PATH
      Output directory from rnaseq-de-flow.

  --enrichment-out PATH
      Output directory from rnaseq-enrichment-flow.

Other options:
  --project-name TEXT
      Report title. Default: RNA-seq project.

  --force
      Replace standard rnaseq-report-flow outputs inside an existing outdir.

Output tree:
  <outdir>/00_inputs/upstream_outputs.tsv
  <outdir>/01_logs/flow.log
  <outdir>/01_logs/steps/01_collect_inputs.log
  <outdir>/01_logs/steps/02_render_report.log
  <outdir>/03_results/collected_tables/
  <outdir>/03_results/collected_plots/
  <outdir>/03_results/collected_html/
  <outdir>/04_reports/rnaseq_report.html
  <outdir>/04_reports/report_interpretation.html
  <outdir>/04_reports/project_summary.tsv
  <outdir>/04_reports/key_metrics.tsv
  <outdir>/04_reports/collected_files.tsv
  <outdir>/04_reports/plot_files.tsv
  <outdir>/04_reports/plot_gallery.tsv
  <outdir>/04_reports/html_reports.tsv
  <outdir>/04_reports/tool_links.tsv
  <outdir>/04_reports/commands.sh
  <outdir>/04_reports/versions.tsv
  <outdir>/04_reports/methods.txt
  <outdir>/04_reports/flow_summary.tsv
  <outdir>/run.manifest.json

Report contents:
  r4 renders a branded TAFFISH HTML report with the real TAFFISH logo embedded
  in the HTML, one-click English/Chinese switching, overview metrics, module
  status, workflow-oriented biological sections, static workflow diagrams,
  active sidebar section highlighting while scrolling, embedded PNG figures,
  PDF plot links, linked MultiQC/FastQC/Qualimap HTML reports when present,
  DESeq2 table previews, ORA/GSEA table previews, tool/source links,
  collected-file indexes, a linked interpretation companion page,
  deliverables/output-structure summaries, version records, and provenance
  pointers.

  Figures are placed in the sections where they are biologically meaningful:
  reference preparation, read QC and expression quantification, alignment and
  counting QC, differential expression, and functional enrichment. The main
  report is therefore a guided project report rather than a single collected
  figure gallery. The HTML keeps both languages internally, but only one
  language is visible at a time.

  Functional enrichment figures include readable/classic dotplots and, when
  produced by rnaseq-enrichment-flow r3, ORA top-term barplot, GSEA NES plot,
  and GSEA enrichment curves.

Interpretation guide:
  <outdir>/04_reports/report_interpretation.html is generated beside the main
  report. It is a compact RNA-seq primer and report guide: RNA-seq basics,
  experimental design, recommended reading order, module-level biological
  questions, sticky left-side contents, scroll-aware section highlighting,
  long-form step chapters from wet-lab origin to biological and technical
  interpretation, common statistics, common plot interpretation, ORA/GSEA
  boundaries, beginner FAQ, reusable files, and common misinterpretations. It
  is static and offline like the main report.

Detailed manuals:
  https://github.com/taffish/rnaseq-report-flow/blob/main/docs/report-interpretation.zh.md
  https://github.com/taffish/rnaseq-report-flow/blob/main/docs/report-interpretation.en.md

  r4 fixes a language-toggle edge case in workflow diagrams, performs a
  post-render check for UTF-8/Latin-1 Chinese mojibake in generated HTML, and
  repairs that specific encoding failure automatically when iconv is available.

  When a completed rnaseq-standard-flow output is supplied, the report uses
  its standardized DE/enrichment PDF and PNG plot collection when available,
  including split png/pdf subdirectories, avoiding duplicate plot copies from
  the nested subflow directories.

Dependencies:
  r4 has no additional TAFFISH tool dependency. It is a static collector using
  shell utilities only. Upstream analysis dependencies are recorded from the
  upstream flow outputs.

Boundaries:
  r4 does not rerun Salmon, Kallisto, HISAT2, samtools, featureCounts, RSeQC,
  Qualimap, DESeq2, enrichment, MultiQC, or RMarkdown. It does not download
  references, gene sets, or databases. It provides bilingual context for
  interpreting workflow modules, but it does not make project-specific
  biological conclusions. Manuscript figures should usually be regenerated from
  the output tables with project-specific styling.

Wrapper options:
  -h, --help       Show this help.
  -v, --version    Show package and command version.
  --compile        Print generated shell code instead of running it.
