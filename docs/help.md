rnaseq-report-flow 0.2.0-r2

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

Compatibility:
  0.2.0-r2 preserves the existing reference-route report contract. Existing rnaseq-standard-flow outputs
  and existing reference-route report commands continue to work unchanged.
  New 0.2.0-r2 options only add de novo assembly/expression/annotation report
  collection when those directories are supplied or auto-discovered.
  Compared with 0.2.0-r1, 0.2.0-r2 improves no-reference report summaries:
  de novo Salmon read depth comes from the de novo expression sample summary,
  reference-only alignment/count metrics are shown as N/A (de novo), and the
  report overview uses a de novo-first workflow diagram in denovo mode.

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

  taf-rnaseq-report-flow \
    --denovo-assembly-out denovo-assembly-out \
    --denovo-expression-out denovo-expression-out \
    --denovo-annotation-out denovo-annotation-out \
    --project-name "No-reference RNA-seq" \
    --outdir report-out

Required output:
  --outdir PATH, -o PATH
      Output directory. The flow refuses to run if PATH already exists unless
      --force is used.

Required input:
  Provide --standard-out or at least one upstream output directory:

  --standard-out PATH
      Completed rnaseq-standard-flow output directory. 0.2.0-r2 auto-discovers
      reference, expression, alignment, count, alignment_qc, de, enrichment,
      denovo_assembly, denovo_expression, and denovo_annotation blocks under
      PATH/03_results/ when present. It also consumes standard-flow top-level
      plot collections under PATH/03_results/plots, PATH/03_results/plots/png,
      and PATH/03_results/plots/pdf when available.

Reference-route upstream outputs:
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

De novo upstream outputs:
  --denovo-assembly-out PATH
      Output directory from rnaseq-denovo-assembly-flow. 0.2.0-r2 collects assembly
      summaries, assembly statistics, read-support tables, optional BUSCO
      status, versions, methods, commands, manifest, and report HTML bundles
      when present.

  --denovo-expression-out PATH
      Output directory from rnaseq-denovo-expression-flow. 0.2.0-r2 collects
      transcript-level count/TPM matrices, optional gene or pseudo-gene
      matrices, quant file indexes, mapping summaries, matrix semantics,
      transcript statistics, QC/report HTML bundles, versions, methods,
      commands, and manifest when present.

  --denovo-annotation-out PATH
      Output directory from rnaseq-denovo-annotation-flow. 0.2.0-r2 collects
      annotation summaries, protein hits, transcript annotation, optional ID
      mapping, annotation-derived denovo_go.gmt, denovo_background.tsv,
      versions, methods, commands, and manifest when present.

Other options:
  --project-name TEXT
      Report title. Default: RNA-seq project.

  --analysis-mode auto|reference|denovo|mixed
      Analysis mode shown in the report overview. Default: auto. Use
      reference for genome-guided RNA-seq, denovo for no-reference
      transcriptome assembly routes, or mixed when intentionally collecting
      both evidence spaces. rnaseq-standard-flow passes this explicitly.

  --analysis-route auto|salmon|both|none|unknown
      Standard-flow route shown in key metrics. Default: auto. Use salmon for
      the lightweight quantification route or both when reference mode also
      includes alignment/count evidence. rnaseq-standard-flow passes this
      explicitly before its final top-level summary is complete.

  --de-source auto|salmon|featurecounts|none|unknown
      Differential-expression count source shown in key metrics. Default:
      auto. Use salmon for Salmon/tximport counts or featurecounts for the
      optional reference alignment/count branch. rnaseq-standard-flow passes
      this explicitly.

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
  0.2.0-r2 renders a branded TAFFISH HTML report with the real TAFFISH logo embedded
  in the HTML, one-click English/Chinese switching, overview metrics, module
  status, workflow-oriented biological sections, static workflow diagrams,
  active sidebar section highlighting while scrolling, embedded PNG figures,
  PDF plot links, linked MultiQC/FastQC/Qualimap HTML reports when present,
  DESeq2 table previews, ORA/GSEA table previews, tool/source links,
  collected-file indexes, a linked interpretation companion page,
  deliverables/output-structure summaries, version records, and provenance
  pointers.

  When de novo outputs are supplied, 0.2.0-r2 adds a no-reference branch covering
  assembly quality, transcript-level expression semantics, functional
  annotation, and enrichment readiness. It keeps the boundary explicit:
  assembled transcript IDs are transcript features; gene-like or pseudo-gene
  matrices require an explicit mapping or clustering table. When no mapping is
  supplied, key metrics report transcript-level-only matrices rather than a
  vague "none" matrix space. Annotation is homolog-derived evidence controlled
  by the supplied protein/GO resources.

  Figures are placed in the sections where they are biologically meaningful:
  reference preparation, read QC and expression quantification, optional
  alignment and counting QC, optional de novo assembly/expression/annotation,
  differential expression, and functional enrichment. The main report is a
  guided project report rather than a single collected figure gallery. The HTML
  keeps both languages internally, but only one language is visible at a time.

  Functional enrichment figures include readable/classic dotplots and, when
  produced by rnaseq-enrichment-flow r3, ORA top-term barplot, GSEA NES plot,
  and GSEA enrichment curves.

Interpretation guide:
  <outdir>/04_reports/report_interpretation.html is generated beside the main
  report. It is a compact RNA-seq primer and report guide: RNA-seq basics,
  experimental design, reference and de novo route interpretation, recommended
  reading order, module-level biological questions, sticky left-side contents,
  scroll-aware section highlighting, long-form step chapters from wet-lab
  origin to biological and technical interpretation, common statistics, common
  plot interpretation, ORA/GSEA boundaries, beginner FAQ, reusable files, and
  common misinterpretations. It is static and offline like the main report.

Detailed manuals:
  https://github.com/taffish/rnaseq-report-flow/blob/main/docs/report-interpretation.zh.md
  https://github.com/taffish/rnaseq-report-flow/blob/main/docs/report-interpretation.en.md

Dependencies:
  0.2.0-r2 has no additional TAFFISH tool dependency. It is a static collector using
  shell utilities only. Upstream analysis dependencies are recorded from the
  upstream flow outputs.

Boundaries:
  0.2.0-r2 does not rerun Salmon, Kallisto, HISAT2, samtools, featureCounts, RSeQC,
  Qualimap, Trinity, rnaSPAdes, seqkit, BUSCO, TransDecoder, DIAMOND, DESeq2,
  enrichment, MultiQC, or RMarkdown. It does not download references, gene
  sets, protein databases, GO mappings, or other online resources. It provides
  bilingual context for interpreting workflow modules, but it does not make
  project-specific biological conclusions. Manuscript figures should usually
  be regenerated from the output tables with project-specific styling.

Wrapper options:
  -h, --help       Show this help.
  -v, --version    Show package and command version.
  --compile        Print generated shell code instead of running it.
