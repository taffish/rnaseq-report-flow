rnaseq-report-flow 0.1.0-r1

Purpose:
  Collect outputs from upstream TAFFISH RNA-seq subflows and write a static
  project report, summary tables, collected key files, methods, versions,
  command provenance, logs, and a manifest under one explicit output directory.

Flow family role:
  This is the report-layer TAFFISH RNA-seq subflow. It can be run directly to
  collect compatible upstream outputs, and it is intended to be the final
  reporting step of future rnaseq-standard-flow orchestration.

Usage:
  taf-rnaseq-report-flow \
    --de-out de-out \
    --enrichment-out enrichment-out \
    --project-name "Yeast SNF2 RNA-seq" \
    --outdir report-out

  taf-rnaseq-report-flow \
    --expression-out expression-out \
    --de-out de-out \
    --enrichment-out enrichment-out \
    --outdir report-out

  taf-rnaseq-report-flow \
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
  At least one upstream output directory:

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
  <outdir>/04_reports/rnaseq_report.html
  <outdir>/04_reports/project_summary.tsv
  <outdir>/04_reports/collected_files.tsv
  <outdir>/04_reports/commands.sh
  <outdir>/04_reports/versions.tsv
  <outdir>/04_reports/methods.txt
  <outdir>/04_reports/flow_summary.tsv
  <outdir>/run.manifest.json

Dependencies:
  r1 has no additional TAFFISH tool dependency. It is a static collector using
  shell utilities only. Upstream analysis dependencies are recorded from the
  upstream flow outputs.

Boundaries:
  r1 does not rerun Salmon, Kallisto, HISAT2, samtools, featureCounts, RSeQC,
  Qualimap, DESeq2, enrichment, MultiQC, or RMarkdown. It does not download
  references, gene sets, or databases. It does not perform biological
  interpretation; it organizes upstream results and provenance for review and
  project delivery.

Wrapper options:
  -h, --help       Show this help.
  -v, --version    Show package and command version.
  --compile        Print generated shell code instead of running it.
