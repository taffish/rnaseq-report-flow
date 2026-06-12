#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd "$script_dir/.." && pwd)

if ! command -v taf >/dev/null 2>&1; then
    echo "smoke: taf command not found in PATH." >&2
    exit 127
fi

if ! command -v taffish >/dev/null 2>&1; then
    echo "smoke: taffish command not found in PATH." >&2
    exit 127
fi

TAFFISH_CONTAINER_BACKEND=${TAFFISH_CONTAINER_BACKEND:-podman}
export TAFFISH_CONTAINER_BACKEND
TAF_HISTORY_MODE=${TAF_HISTORY_MODE:-off}
export TAF_HISTORY_MODE

tmpdir=$(mktemp -d "$project_dir/.taf-smoke.XXXXXX")
cleanup() {
    cd "$project_dir" 2>/dev/null || :
    rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM HUP

cd "$project_dir"

echo "[SMOKE] taf check"
taf check

echo "[SMOKE] taf build"
taf build

flow_cmd="$project_dir/target/taf-rnaseq-report-flow-v0.3.0-r1"
if [ ! -x "$flow_cmd" ]; then
    echo "smoke: built flow command is missing or not executable: $flow_cmd" >&2
    exit 1
fi

assert_no_mojibake() {
    html_file=$1
    for marker in "$(printf '\303\246')" "$(printf '\303\247')" "$(printf '\303\245')" "$(printf '\303\244')"; do
        if LC_ALL=C grep -aq "$marker" "$html_file"; then
            echo "smoke: possible UTF-8/Latin-1 mojibake remains in $html_file" >&2
            exit 1
        fi
    done
}

echo "[SMOKE] help and version"
"$flow_cmd" --help >/dev/null
"$flow_cmd" --version >/dev/null

run_dir="$tmpdir/run"
mkdir -p "$run_dir"

make_common_reports() {
    module_dir=$1
    flow_name=$2
    mkdir -p "$module_dir/04_reports"
    cat > "$module_dir/04_reports/versions.tsv" <<EOF
tool	version	source
$flow_name	0.1.0-r1	taffish flow
EOF
    cat > "$module_dir/04_reports/methods.txt" <<EOF
$flow_name smoke methods.
EOF
    cat > "$module_dir/04_reports/commands.sh" <<EOF
#!/bin/sh
# $flow_name smoke command log
EOF
    cat > "$module_dir/04_reports/flow_summary.tsv" <<EOF
metric	value
flow	$flow_name
sample_count	2
EOF
    cat > "$module_dir/run.manifest.json" <<EOF
{"flow":"$flow_name","version":"0.1.0-r1"}
EOF
}

echo "[SMOKE] create tiny upstream output fixtures"

expression_out="$run_dir/expression-out"
make_common_reports "$expression_out" "rnaseq-expression-flow"
mkdir -p "$expression_out/03_results/matrices"
cat > "$expression_out/04_reports/expression_summary.tsv" <<'EOF'
metric	value
sample_count	2
EOF
cat > "$expression_out/04_reports/quant_files.tsv" <<'EOF'
sample_id	quant_file
S1	salmon/S1/quant.sf
EOF
cat > "$expression_out/03_results/matrices/gene_counts.tsv" <<'EOF'
gene_id	S1	S2
geneA	10	12
EOF
cat > "$expression_out/03_results/matrices/gene_tpm.tsv" <<'EOF'
gene_id	S1	S2
geneA	50	60
EOF
mkdir -p "$expression_out/04_reports/multiqc_report_data" "$expression_out/03_results/fastqc/S1"
cat > "$expression_out/04_reports/multiqc_report.html" <<'EOF'
<!doctype html><html><body><h1>expression MultiQC</h1></body></html>
EOF
cat > "$expression_out/04_reports/multiqc_report_data/multiqc_data.json" <<'EOF'
{"report":"expression"}
EOF
cat > "$expression_out/03_results/fastqc/S1/S1_fastqc.html" <<'EOF'
<!doctype html><html><body><h1>S1 FastQC</h1></body></html>
EOF

alignment_out="$run_dir/align-out"
make_common_reports "$alignment_out" "rnaseq-alignment-flow"
mkdir -p "$alignment_out/03_results"
cat > "$alignment_out/03_results/alignment_summary.tsv" <<'EOF'
sample_id	mapped_reads
S1	100
EOF
cat > "$alignment_out/04_reports/bam_files.tsv" <<'EOF'
sample_id	bam	bai
S1	bam/S1.sorted.bam	bam/S1.sorted.bam.bai
EOF
mkdir -p "$alignment_out/04_reports/multiqc_report_data"
cat > "$alignment_out/04_reports/multiqc_report.html" <<'EOF'
<!doctype html><html><body><h1>alignment MultiQC</h1></body></html>
EOF

count_out="$run_dir/count-out"
make_common_reports "$count_out" "rnaseq-count-flow"
mkdir -p "$count_out/03_results/matrices"
cat > "$count_out/04_reports/count_summary.tsv" <<'EOF'
metric	value
assigned_reads	22
EOF
cat > "$count_out/03_results/matrices/gene_counts.tsv" <<'EOF'
gene_id	S1	S2
geneA	10	12
EOF
cat > "$count_out/03_results/assignment_summary.tsv" <<'EOF'
status	sample_id	count
Assigned	S1	10
EOF
mkdir -p "$count_out/04_reports/multiqc_report_data"
cat > "$count_out/04_reports/multiqc_report.html" <<'EOF'
<!doctype html><html><body><h1>count MultiQC</h1></body></html>
EOF

alignment_qc_out="$run_dir/alignment-qc-out"
make_common_reports "$alignment_qc_out" "rnaseq-alignment-qc-flow"
mkdir -p "$alignment_qc_out/03_results"
cat > "$alignment_qc_out/03_results/rnaseq_qc_summary.tsv" <<'EOF'
sample_id	total_records
S1	100
EOF
cp "$alignment_qc_out/03_results/rnaseq_qc_summary.tsv" "$alignment_qc_out/04_reports/rnaseq_qc_summary.tsv"
mkdir -p "$alignment_qc_out/04_reports/multiqc_report_data" "$alignment_qc_out/03_results/qualimap/S1/css"
cat > "$alignment_qc_out/04_reports/multiqc_report.html" <<'EOF'
<!doctype html><html><body><h1>alignment QC MultiQC</h1></body></html>
EOF
cat > "$alignment_qc_out/03_results/qualimap/S1/qualimapReport.html" <<'EOF'
<!doctype html><html><body><h1>S1 Qualimap</h1></body></html>
EOF
cat > "$alignment_qc_out/03_results/qualimap/S1/css/report.css" <<'EOF'
body { color: #222; }
EOF

de_out="$run_dir/de-out"
make_common_reports "$de_out" "rnaseq-de-flow"
mkdir -p "$de_out/03_results/de" "$de_out/03_results/gene_lists" "$de_out/03_results/plots"
cat > "$de_out/04_reports/de_summary.tsv" <<'EOF'
metric	value
significant_genes	2
EOF
cat > "$de_out/04_reports/contrasts.tsv" <<'EOF'
contrast
condition:treated:control
EOF
cat > "$de_out/03_results/de/results.tsv" <<'EOF'
gene_id	log2FoldChange	padj
geneA	2	0.01
EOF
cp "$de_out/03_results/de/results.tsv" "$de_out/03_results/de/results_shrunken.tsv"
cat > "$de_out/03_results/gene_lists/significant_genes.tsv" <<'EOF'
gene_id
geneA
EOF
cat > "$de_out/03_results/gene_lists/ranked_genes.tsv" <<'EOF'
gene_id	score
geneA	2
EOF
for plot in \
    pca_plot ma_plot volcano_plot deg_counts_barplot heatmap \
    sample_correlation_heatmap expression_distribution \
    normalized_count_distribution top_genes_expression
do
    printf 'PDF smoke\n' > "$de_out/03_results/plots/$plot.pdf"
    printf 'PNG smoke\n' > "$de_out/03_results/plots/$plot.png"
done
cat > "$de_out/03_results/plots/plot_summary.tsv" <<'EOF'
metric	value
plot_style	r2-unified
EOF

enrichment_out="$run_dir/enrichment-out"
make_common_reports "$enrichment_out" "rnaseq-enrichment-flow"
mkdir -p "$enrichment_out/03_results/enrichment"
cat > "$enrichment_out/03_results/enrichment/enrichment_summary.tsv" <<'EOF'
metric	value
ora_result_count	1
EOF
cat > "$enrichment_out/03_results/enrichment/ora_results.tsv" <<'EOF'
set_id	pvalue
set_alpha	0.01
EOF
cat > "$enrichment_out/03_results/enrichment/gsea_results.tsv" <<'EOF'
set_id	pvalue
set_beta	0.02
EOF
printf 'PDF smoke\n' > "$enrichment_out/03_results/enrichment/dotplot.pdf"
printf 'PNG smoke\n' > "$enrichment_out/03_results/enrichment/dotplot.png"
printf 'PDF smoke\n' > "$enrichment_out/03_results/enrichment/dotplot.original.pdf"
printf 'PNG smoke\n' > "$enrichment_out/03_results/enrichment/dotplot.original.png"
for plot in ora_barplot gsea_nes_plot gsea_enrichment_curves
do
    printf 'PDF smoke\n' > "$enrichment_out/03_results/enrichment/$plot.pdf"
    printf 'PNG smoke\n' > "$enrichment_out/03_results/enrichment/$plot.png"
done
cat > "$enrichment_out/03_results/enrichment/dotplot_source.tsv" <<'EOF'
metric	value
renderer	rnaseq-enrichment-flow
EOF
cat > "$enrichment_out/03_results/enrichment/plot_summary.tsv" <<'EOF'
metric	value
plot_style	r3-unified
EOF

denovo_assembly_out="$run_dir/denovo-assembly-out"
make_common_reports "$denovo_assembly_out" "rnaseq-denovo-assembly-flow"
mkdir -p "$denovo_assembly_out/03_results/assembly_qc" "$denovo_assembly_out/04_reports/multiqc_report_data"
cat > "$denovo_assembly_out/04_reports/flow_summary.tsv" <<'EOF'
metric	value
flow	rnaseq-denovo-assembly-flow
filtered_transcripts	42
filtered_n50	1200
busco_status	complete
EOF
cat > "$denovo_assembly_out/04_reports/assembly_summary.tsv" <<'EOF'
metric	value
filtered_transcripts	42
filtered_n50	1200
EOF
cat > "$denovo_assembly_out/03_results/assembly_qc/assembly_stats.tsv" <<'EOF'
metric	value
transcripts	42
n50	1200
EOF
cat > "$denovo_assembly_out/03_results/assembly_qc/seqkit_stats.tsv" <<'EOF'
file	num_seqs	sum_len	min_len	avg_len	max_len
transcripts.fa	42	12000	250	600	1800
EOF
cat > "$denovo_assembly_out/03_results/assembly_qc/read_support.tsv" <<'EOF'
sample_id	mapped_reads
S1	1000
EOF
cat > "$denovo_assembly_out/03_results/assembly_qc/busco_summary.tsv" <<'EOF'
metric	value
complete	95.0
EOF
cat > "$denovo_assembly_out/04_reports/multiqc_report.html" <<'EOF'
<!doctype html><html><body><h1>denovo assembly MultiQC</h1></body></html>
EOF

denovo_expression_out="$run_dir/denovo-expression-out"
make_common_reports "$denovo_expression_out" "rnaseq-denovo-expression-flow"
mkdir -p "$denovo_expression_out/03_results/matrices" "$denovo_expression_out/04_reports/multiqc_report_data" "$denovo_expression_out/03_results/fastqc/S1"
cat > "$denovo_expression_out/04_reports/flow_summary.tsv" <<'EOF'
metric	value
flow	rnaseq-denovo-expression-flow
transcript_rows	42
gene_rows	10
EOF
cat > "$denovo_expression_out/04_reports/expression_summary.tsv" <<'EOF'
sample_id	layout	trimmed	quant_sf	estimated_num_reads
S1	single	true	salmon/S1/quant.sf	1000
S2	single	true	salmon/S2/quant.sf	1200
EOF
cat > "$denovo_expression_out/04_reports/quant_files.tsv" <<'EOF'
sample_id	quant_file
S1	salmon/S1/quant.sf
EOF
cat > "$denovo_expression_out/04_reports/matrix_semantics.tsv" <<'EOF'
matrix	feature_space	description
transcript_counts	transcript	assembled transcript features
gene_counts	pseudo_gene	clustered transcript groups
EOF
cat > "$denovo_expression_out/04_reports/mapping_summary.tsv" <<'EOF'
metric	value
mapping_mode	cluster
EOF
cat > "$denovo_expression_out/04_reports/transcript_stats.tsv" <<'EOF'
metric	value
transcripts	42
EOF
cat > "$denovo_expression_out/03_results/matrices/transcript_counts.tsv" <<'EOF'
transcript_id	S1	S2
TRINITY_DN1_c0_g1_i1	10	12
EOF
cat > "$denovo_expression_out/03_results/matrices/transcript_tpm.tsv" <<'EOF'
transcript_id	S1	S2
TRINITY_DN1_c0_g1_i1	50	60
EOF
cat > "$denovo_expression_out/03_results/matrices/gene_counts.tsv" <<'EOF'
gene_id	S1	S2
cluster_1	10	12
EOF
cat > "$denovo_expression_out/03_results/matrices/gene_tpm.tsv" <<'EOF'
gene_id	S1	S2
cluster_1	50	60
EOF
cat > "$denovo_expression_out/04_reports/multiqc_report.html" <<'EOF'
<!doctype html><html><body><h1>denovo expression MultiQC</h1></body></html>
EOF
cat > "$denovo_expression_out/03_results/fastqc/S1/S1_fastqc.html" <<'EOF'
<!doctype html><html><body><h1>denovo S1 FastQC</h1></body></html>
EOF

denovo_annotation_out="$run_dir/denovo-annotation-out"
make_common_reports "$denovo_annotation_out" "rnaseq-denovo-annotation-flow"
mkdir -p "$denovo_annotation_out/00_inputs" "$denovo_annotation_out/03_results/annotation" "$denovo_annotation_out/03_results/gene_sets"
cat > "$denovo_annotation_out/04_reports/flow_summary.tsv" <<'EOF'
metric	value
flow	rnaseq-denovo-annotation-flow
annotated_transcript_count	30
gene_set_count	8
EOF
cat > "$denovo_annotation_out/04_reports/annotation_summary.tsv" <<'EOF'
metric	value
annotated_transcript_count	30
gene_set_count	8
EOF
cat > "$denovo_annotation_out/04_reports/transcript_stats.tsv" <<'EOF'
metric	value
transcripts	42
EOF
cat > "$denovo_annotation_out/00_inputs/annotation_inputs.tsv" <<'EOF'
input	path
protein_db	proteins.fa
EOF
cat > "$denovo_annotation_out/03_results/annotation/protein_hits.tsv" <<'EOF'
transcript_id	protein_id	evalue
TRINITY_DN1_c0_g1_i1	P12345	1e-30
EOF
cat > "$denovo_annotation_out/03_results/annotation/transcript_annotation.tsv" <<'EOF'
transcript_id	best_hit	description
TRINITY_DN1_c0_g1_i1	P12345	ribosomal protein
EOF
cat > "$denovo_annotation_out/03_results/annotation/id_mapping.tsv" <<'EOF'
transcript_id	gene_set_id
TRINITY_DN1_c0_g1_i1	GO:0006412
EOF
cat > "$denovo_annotation_out/03_results/gene_sets/denovo_go.gmt" <<'EOF'
GO:0006412	translation	TRINITY_DN1_c0_g1_i1
EOF
cat > "$denovo_annotation_out/03_results/gene_sets/denovo_background.tsv" <<'EOF'
feature_id
TRINITY_DN1_c0_g1_i1
EOF

echo "[SMOKE] rnaseq-report-flow tiny fixture"
(
    cd "$run_dir"
    "$flow_cmd" \
        --expression-out "$expression_out" \
        --alignment-out "$alignment_out" \
        --count-out "$count_out" \
        --alignment-qc-out "$alignment_qc_out" \
        --de-out "$de_out" \
        --enrichment-out "$enrichment_out" \
        --project-name "Smoke RNA-seq report" \
        --outdir report-out
)
cd "$project_dir"

out="$run_dir/report-out"

echo "[SMOKE] output checks"
test -s "$out/00_inputs/upstream_outputs.tsv"
test -s "$out/01_logs/flow.log"
test -s "$out/01_logs/steps/01_collect_inputs.log"
test -s "$out/01_logs/steps/02_render_report.log"
test -d "$out/03_results/collected_tables"
test -d "$out/03_results/collected_plots"
test -d "$out/03_results/collected_html"
test -s "$out/04_reports/rnaseq_report.html"
test -s "$out/04_reports/report_interpretation.html"
test -s "$out/04_reports/project_summary.tsv"
test -s "$out/04_reports/key_metrics.tsv"
test -s "$out/04_reports/collected_files.tsv"
test -s "$out/04_reports/plot_files.tsv"
test -s "$out/04_reports/plot_gallery.tsv"
test -s "$out/04_reports/html_reports.tsv"
test -s "$out/04_reports/embedded_html_reports.tsv"
test -s "$out/04_reports/tool_links.tsv"
test -s "$out/04_reports/commands.sh"
test -s "$out/04_reports/versions.tsv"
test -s "$out/04_reports/methods.txt"
test -s "$out/04_reports/flow_summary.tsv"
test -s "$out/04_reports/report_template_version.txt"
test -s "$out/run.manifest.json"

grep -F 'Smoke RNA-seq report' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'TAFFISH' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-template="taffish-flow-report"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-template-version="0.1.0"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'class="section-nav side-links"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'class="nav-group"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-lang-toggle="en"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-lang-toggle="zh"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'html[data-lang="en"] .lang-zh{display:none!important}' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '.flow-node>span' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'overflow:visible}.sidebar{position:sticky' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'max-height:calc(100vh - 36px)' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'TAFFISH RNA-seq project report' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'TAFFISH RNA-seq 项目报告' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'How to Read This Report' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '如何阅读本报告' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'report_interpretation.html' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-embedded-report-id="report.interpretation"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'id="taffish-embedded-html-reports"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'initEmbeddedReports' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'id="taffish-embedded-tables"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'initEmbeddedTables' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-embedded-table-id=' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'class="table-link-body"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '.embedded-table-link a{align-self:flex-start;margin-top:auto}' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Embedded table payloads' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-embedded-report-id="expression.multiqc"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Read QC and Expression Quantification' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '测序质控与表达定量' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Differential Expression' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '差异表达' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Functional Enrichment' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '功能富集' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'currentSectionId' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'requestAnimationFrame(update)' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'workflow-map' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Deliverables and Output Structure' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '交付文件与输出结构' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'ORA visual summary' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'GSEA directional summary' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'target="_blank" rel="noopener"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'https://github.com/taffish' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'https://taffish.github.io/' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data:image/png;base64,' "$out/04_reports/rnaseq_report.html" >/dev/null
assert_no_mojibake "$out/04_reports/rnaseq_report.html"
grep -F 'RNA-seq Interpretation Guide' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'RNA-seq 报告解读指南' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'guide-sidebar' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'guide-nav' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Contents' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '目录' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'RNA-seq Primer' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'RNA-seq 入门' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'From FASTQ to Biological Questions' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '从 FASTQ 到生物学问题' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Experimental Design Basics' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '实验设计基础' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Statistics Glossary' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '统计概念速查' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Beginner FAQ' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '新手 FAQ' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Deep-Dive Modules' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '深度模块解读' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Reference: biology becomes coordinates' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '参考：把生物学对象变成坐标和 ID' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Quantification: abundance is an estimate' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '表达定量：丰度是估计值' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Differential expression: variation becomes a model' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '差异表达：把变异放进模型' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Report and provenance: reproducibility is evidence' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '报告与溯源：可复现性也是证据' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Long-Form Module Chapters' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '长文模块章节' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Wet-lab origin' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '湿实验来源' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Technical difficulty' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '技术难点' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Recommended Reading Order' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '推荐阅读顺序' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Common Misinterpretations' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F '常见误读' "$out/04_reports/report_interpretation.html" >/dev/null
grep -F 'rnaseq_report.html' "$out/04_reports/report_interpretation.html" >/dev/null
assert_no_mojibake "$out/04_reports/report_interpretation.html"
grep -F 'provided_modules	6' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'plot_groups	14' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'html_report_links	7' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'embedded_html_reports	7' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'embedded_tables	' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'report_template	taffish-flow-report' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'report_template_version	0.1.0' "$out/04_reports/project_summary.tsv" >/dev/null
if grep -F 'Route	.' "$out/04_reports/key_metrics.tsv" >/dev/null; then
    echo "smoke: Route metric should not be an uninformative dot" >&2
    exit 1
fi
if grep -F 'DE source	.' "$out/04_reports/key_metrics.tsv" >/dev/null; then
    echo "smoke: DE source metric should not be an uninformative dot" >&2
    exit 1
fi
grep -F 'Collected plots	14' "$out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'Linked HTML reports	7' "$out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'Embedded tables	' "$out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'Embedded HTML reports	7' "$out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'rnaseq-report-flow	0.3.0-r1	taffish flow' "$out/04_reports/versions.tsv" >/dev/null
grep -F 'flow-report-template	0.1.0	repos/apps/templates/flow-report' "$out/04_reports/versions.tsv" >/dev/null
grep -F '0.1.0' "$out/04_reports/report_template_version.txt" >/dev/null
grep -F 'denovo_present	no' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'rnaseq-de-flow' "$out/04_reports/versions.tsv" >/dev/null
grep -F 'rnaseq-de-flow' "$out/04_reports/tool_links.tsv" >/dev/null
grep -F 'https://github.com/taffish/rnaseq-de-flow' "$out/04_reports/tool_links.tsv" >/dev/null
grep -F 'enrichment	ora_results' "$out/04_reports/collected_files.tsv" >/dev/null
grep -F 'enrichment	plot_summary' "$out/04_reports/collected_files.tsv" >/dev/null
grep -F 'expression	multiqc' "$out/04_reports/html_reports.tsv" >/dev/null
grep -F 'alignment_qc	qualimap_S1' "$out/04_reports/html_reports.tsv" >/dev/null
grep -F 'expression.multiqc' "$out/04_reports/embedded_html_reports.tsv" >/dev/null
grep -F 'alignment_qc.qualimap_S1' "$out/04_reports/embedded_html_reports.tsv" >/dev/null
grep -F 'report	interpretation' "$out/04_reports/embedded_html_reports.tsv" >/dev/null
test -s "$out/03_results/collected_html/expression.multiqc/index.html"
test -s "$out/03_results/collected_html/expression.multiqc/index.embedded.html"
test -s "$out/03_results/collected_html/alignment_qc.qualimap_S1/index.html"
test -s "$out/03_results/collected_html/alignment_qc.qualimap_S1/index.embedded.html"
test -s "$out/03_results/collected_html/report.interpretation/index.html"
test -s "$out/03_results/collected_html/report.interpretation/index.embedded.html"
grep -F 'de	pca_plot' "$out/04_reports/collected_files.tsv" >/dev/null
grep -F 'de	pca_plot	png' "$out/04_reports/plot_files.tsv" >/dev/null
grep -F 'enrichment	dotplot_original' "$out/04_reports/plot_gallery.tsv" >/dev/null
grep -F 'enrichment	ora_barplot' "$out/04_reports/plot_gallery.tsv" >/dev/null
grep -F 'enrichment	gsea_nes_plot' "$out/04_reports/plot_gallery.tsv" >/dev/null
grep -F 'enrichment	gsea_enrichment_curves' "$out/04_reports/plot_gallery.tsv" >/dev/null
grep -F '"flow": "rnaseq-report-flow"' "$out/run.manifest.json" >/dev/null
grep -F '"interpretation_guide":' "$out/run.manifest.json" >/dev/null
grep -F '"embedded_html_reports":' "$out/run.manifest.json" >/dev/null
grep -F '"embedded_tables":' "$out/run.manifest.json" >/dev/null
grep -F '"template": "taffish-flow-report"' "$out/run.manifest.json" >/dev/null
grep -F '"template_version": "0.1.0"' "$out/run.manifest.json" >/dev/null
if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$out/run.manifest.json" >/dev/null
fi

echo "[SMOKE] archived standard report package rerender"
(
    cd "$run_dir"
    "$flow_cmd" \
        --standard-out "$out" \
        --project-name "Smoke RNA-seq archived package rerender" \
        --analysis-mode reference \
        --outdir report-archive
)
archive_out="$run_dir/report-archive"
test -s "$archive_out/04_reports/rnaseq_report.html"
test -s "$archive_out/04_reports/project_summary.tsv"
test -s "$archive_out/run.manifest.json"
grep -F 'standard_report_package	yes' "$archive_out/04_reports/project_summary.tsv" >/dev/null
grep -F '# standard_report_package=yes' "$archive_out/04_reports/commands.sh" >/dev/null
grep -F 'data-template="taffish-flow-report"' "$archive_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'class="table-link-body"' "$archive_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'currentSectionId' "$archive_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'embedded_tables	' "$archive_out/04_reports/project_summary.tsv" >/dev/null
if grep -F 'Route	.' "$archive_out/04_reports/key_metrics.tsv" >/dev/null; then
    echo "smoke: archived package Route metric should not be an uninformative dot" >&2
    exit 1
fi
if grep -F 'DE source	.' "$archive_out/04_reports/key_metrics.tsv" >/dev/null; then
    echo "smoke: archived package DE source metric should not be an uninformative dot" >&2
    exit 1
fi
grep -F '"embedded_tables":' "$archive_out/run.manifest.json" >/dev/null
grep -F '"standard_report_package": "yes"' "$archive_out/run.manifest.json" >/dev/null
grep -F '"template": "taffish-flow-report"' "$archive_out/run.manifest.json" >/dev/null

echo "[SMOKE] rnaseq-report-flow tiny de novo fixture"
(
    cd "$run_dir"
    "$flow_cmd" \
        --denovo-assembly-out "$denovo_assembly_out" \
        --denovo-expression-out "$denovo_expression_out" \
        --denovo-annotation-out "$denovo_annotation_out" \
        --project-name "Smoke de novo RNA-seq report" \
        --analysis-mode denovo \
        --analysis-route salmon \
        --de-source salmon \
        --outdir report-denovo
)

denovo_out="$run_dir/report-denovo"
test -s "$denovo_out/04_reports/rnaseq_report.html"
test -s "$denovo_out/04_reports/report_interpretation.html"
test -s "$denovo_out/04_reports/project_summary.tsv"
test -s "$denovo_out/04_reports/key_metrics.tsv"
test -s "$denovo_out/04_reports/collected_files.tsv"
test -s "$denovo_out/04_reports/html_reports.tsv"
test -s "$denovo_out/04_reports/embedded_html_reports.tsv"
grep -F 'Smoke de novo RNA-seq report' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-template="taffish-flow-report"' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-template-version="0.1.0"' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'class="nav-group"' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'currentSectionId' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'id="taffish-embedded-tables"' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'initEmbeddedTables' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'class="table-link-body"' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-embedded-report-id="report.interpretation"' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'De novo Assembly, Expression, and Annotation' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F '无参组装、表达与注释' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'De novo route aware' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F '支持无参路线' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Transcriptome assembly' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F '转录组组装' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Skipped by analysis mode' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F '按分析模式跳过' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Assembly quality' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'De novo expression semantics' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Annotation and enrichment readiness' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Enrichment-ready' "$denovo_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'De novo RNA-seq Route' "$denovo_out/04_reports/report_interpretation.html" >/dev/null
grep -F '无参 RNA-seq 路线' "$denovo_out/04_reports/report_interpretation.html" >/dev/null
grep -F 'denovo_present	yes' "$denovo_out/04_reports/project_summary.tsv" >/dev/null
grep -F 'provided_modules	3' "$denovo_out/04_reports/project_summary.tsv" >/dev/null
grep -F 'Route	de novo salmon (assembled transcriptome)' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'DE source	de novo pseudo-gene counts' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'Avg Salmon reads	1100.00' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'Avg mapped %	N/A (de novo)' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'featureCounts assigned	N/A (de novo)' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'QC assigned tags	N/A (de novo)' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'De novo filtered transcripts	42' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'De novo N50	1200' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'De novo BUSCO	complete' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'De novo matrix semantics	tx2gene or cluster mapping: cluster-derived pseudo-gene matrix' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'De novo transcript rows	42' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'Pseudo-gene rows	10' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'Annotated transcripts	30' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'GO gene sets	8' "$denovo_out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'denovo_assembly	assembly_stats' "$denovo_out/04_reports/collected_files.tsv" >/dev/null
grep -F 'denovo_expression	matrix_semantics' "$denovo_out/04_reports/collected_files.tsv" >/dev/null
grep -F 'denovo_annotation	transcript_annotation' "$denovo_out/04_reports/collected_files.tsv" >/dev/null
grep -F 'denovo_annotation	denovo_go' "$denovo_out/04_reports/collected_files.tsv" >/dev/null
grep -F 'denovo_assembly	multiqc' "$denovo_out/04_reports/html_reports.tsv" >/dev/null
grep -F 'denovo_expression	fastqc_S1' "$denovo_out/04_reports/html_reports.tsv" >/dev/null
grep -F 'denovo_assembly.multiqc' "$denovo_out/04_reports/embedded_html_reports.tsv" >/dev/null
grep -F 'denovo_expression.fastqc_S1' "$denovo_out/04_reports/embedded_html_reports.tsv" >/dev/null
grep -F 'report	interpretation' "$denovo_out/04_reports/embedded_html_reports.tsv" >/dev/null
test -s "$denovo_out/03_results/collected_html/report.interpretation/index.embedded.html"
grep -F 'report_template_version	0.1.0' "$denovo_out/04_reports/project_summary.tsv" >/dev/null
grep -F 'rnaseq-denovo-assembly-flow' "$denovo_out/04_reports/tool_links.tsv" >/dev/null
grep -F 'rnaseq-denovo-expression-flow' "$denovo_out/04_reports/tool_links.tsv" >/dev/null
grep -F 'rnaseq-denovo-annotation-flow' "$denovo_out/04_reports/tool_links.tsv" >/dev/null
grep -F 'https://github.com/taffish/rnaseq-denovo-assembly-flow' "$denovo_out/04_reports/tool_links.tsv" >/dev/null
grep -F '"denovo_present": "yes"' "$denovo_out/run.manifest.json" >/dev/null
assert_no_mojibake "$denovo_out/04_reports/rnaseq_report.html"
assert_no_mojibake "$denovo_out/04_reports/report_interpretation.html"
if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$denovo_out/run.manifest.json" >/dev/null
fi

echo "[SMOKE] C-locale report rendering"
(
    cd "$run_dir"
    LC_ALL=C LANG=C "$flow_cmd" \
        --de-out "$de_out" \
        --enrichment-out "$enrichment_out" \
        --project-name "Smoke C locale report" \
        --outdir report-c-locale
)
locale_out="$run_dir/report-c-locale"
test -s "$locale_out/04_reports/rnaseq_report.html"
test -s "$locale_out/04_reports/report_interpretation.html"
grep -F 'TAFFISH RNA-seq 项目报告' "$locale_out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'RNA-seq 报告解读指南' "$locale_out/04_reports/report_interpretation.html" >/dev/null
grep -F '统计概念速查' "$locale_out/04_reports/report_interpretation.html" >/dev/null
grep -F '深度模块解读' "$locale_out/04_reports/report_interpretation.html" >/dev/null
grep -F '长文模块章节' "$locale_out/04_reports/report_interpretation.html" >/dev/null
grep -F 'Functional Enrichment' "$locale_out/04_reports/rnaseq_report.html" >/dev/null
grep -F '功能富集' "$locale_out/04_reports/rnaseq_report.html" >/dev/null
grep -F '.flow-node>span' "$locale_out/04_reports/rnaseq_report.html" >/dev/null
assert_no_mojibake "$locale_out/04_reports/rnaseq_report.html"
assert_no_mojibake "$locale_out/04_reports/report_interpretation.html"

echo "[SMOKE] existing outdir is refused"
if (
    cd "$run_dir"
    "$flow_cmd" \
        --de-out "$de_out" \
        --outdir report-out
) >/dev/null 2>&1; then
    echo "smoke: existing outdir was not refused." >&2
    exit 1
fi

echo "[SMOKE] --force rerun"
(
    cd "$run_dir"
    "$flow_cmd" \
        --de-out "$de_out" \
        --project-name "Smoke RNA-seq report force" \
        --outdir report-out \
        --force
)
test -s "$out/04_reports/rnaseq_report.html"
test -s "$out/04_reports/report_interpretation.html"
grep -F 'provided_modules	1' "$out/04_reports/project_summary.tsv" >/dev/null

stray=$(find "$run_dir" -mindepth 1 -maxdepth 1 ! -name expression-out ! -name align-out ! -name count-out ! -name alignment-qc-out ! -name de-out ! -name enrichment-out ! -name denovo-assembly-out ! -name denovo-expression-out ! -name denovo-annotation-out ! -name report-out ! -name report-archive ! -name report-denovo ! -name report-c-locale -print)
if [ -n "$stray" ]; then
    echo "smoke: flow wrote unexpected files outside outdir:" >&2
    printf '%s\n' "$stray" >&2
    exit 1
fi

echo "[SMOKE] ok"
