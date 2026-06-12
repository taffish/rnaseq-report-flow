#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd "$script_dir/.." && pwd)
bio_apps_dir=$(CDPATH= cd "$project_dir/../../../.." && pwd)
rnaseq_root=$(CDPATH= cd "$project_dir/../.." && pwd)
de_flow_dir="$rnaseq_root/subflows/rnaseq-de-flow"
enrichment_flow_dir="$rnaseq_root/subflows/rnaseq-enrichment-flow"
default_data_root=$(CDPATH= cd "$rnaseq_root/test-data/yeast/data/03_results" 2>/dev/null && pwd || printf '%s\n' "$rnaseq_root/test-data/yeast/data/03_results")
data_root=${TAFFISH_RNASEQ_TESTDATA:-$default_data_root}

for target_dir in \
    "$bio_apps_dir/tools/bioconductor-rnaseq/target" \
    "$bio_apps_dir/tools/enrichment-r/target" \
    "$de_flow_dir/target" \
    "$enrichment_flow_dir/target"
do
    if [ -d "$target_dir" ]; then
        PATH="$target_dir:$PATH"
    fi
done
export PATH

TAFFISH_CONTAINER_BACKEND=${TAFFISH_CONTAINER_BACKEND:-podman}
export TAFFISH_CONTAINER_BACKEND
TAF_HISTORY_MODE=${TAF_HISTORY_MODE:-off}
export TAF_HISTORY_MODE

skip_formal() {
    echo "formal: skipped: $*" >&2
    exit 0
}

assert_no_mojibake() {
    html_file=$1
    for marker in "$(printf '\303\246')" "$(printf '\303\247')" "$(printf '\303\245')" "$(printf '\303\244')"; do
        if LC_ALL=C grep -aq "$marker" "$html_file"; then
            echo "formal: possible UTF-8/Latin-1 mojibake remains in $html_file" >&2
            exit 1
        fi
    done
}

if [ ! -d "$data_root" ]; then
    skip_formal "RNA-seq formal data root not found: $data_root"
fi

counts="$data_root/yeast-snf2-counts-medium-v1/counts/gene_counts_12v12.tsv"
selected="$data_root/yeast-snf2-counts-medium-v1/source/selected_count_files.tsv"
gene_sets_pkg="$data_root/yeast-sgd-go-gene-sets-r64.4.1-v1"
gene_sets="$gene_sets_pkg/gene_sets/sgd_go_bp.gmt"
background="$gene_sets_pkg/background/yeast_background_genes.tsv"

[ -s "$counts" ] || skip_formal "missing yeast count matrix: $counts"
[ -s "$selected" ] || skip_formal "missing yeast selected count-file map: $selected"
[ -s "$gene_sets" ] || skip_formal "missing yeast SGD GO BP GMT: $gene_sets"
[ -s "$background" ] || skip_formal "missing yeast enrichment background: $background"

if ! command -v taf >/dev/null 2>&1; then
    echo "formal: taf command not found in PATH." >&2
    exit 127
fi

for dep in \
    taf-bioconductor-rnaseq-v3.23-r1 \
    taf-enrichment-r-v0.1.0-r1
do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "formal: dependency wrapper not found in PATH: $dep" >&2
        exit 127
    fi
done

echo "[FORMAL] build rnaseq-de-flow"
(
    cd "$de_flow_dir"
    taf check
    taf build
)
de_flow_cmd="$de_flow_dir/target/taf-rnaseq-de-flow-v0.2.0-r1"
if [ ! -x "$de_flow_cmd" ]; then
    echo "formal: built DE flow command is missing or not executable: $de_flow_cmd" >&2
    exit 1
fi

echo "[FORMAL] build rnaseq-enrichment-flow"
(
    cd "$enrichment_flow_dir"
    taf check
    taf build
)
enrichment_flow_cmd="$enrichment_flow_dir/target/taf-rnaseq-enrichment-flow-v0.2.0-r1"
if [ ! -x "$enrichment_flow_cmd" ]; then
    echo "formal: built enrichment flow command is missing or not executable: $enrichment_flow_cmd" >&2
    exit 1
fi

tmpdir=$(mktemp -d "$project_dir/.taf-formal.XXXXXX")
cleanup() {
    cd "$project_dir" 2>/dev/null || :
    rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM HUP

cd "$project_dir"

echo "[FORMAL] taf check"
taf check

echo "[FORMAL] taf build"
taf build

flow_cmd="$project_dir/target/taf-rnaseq-report-flow-v0.3.0-r1"
if [ ! -x "$flow_cmd" ]; then
    echo "formal: built report flow command is missing or not executable: $flow_cmd" >&2
    exit 1
fi

run_dir="$tmpdir/run"
mkdir -p "$run_dir"

metadata="$run_dir/metadata.tsv"
awk -F '\t' -v OFS='\t' '
    NR == 1 {
        for (i = 1; i <= NF; i++) col[$i] = i
        if (!("sample_id" in col) || !("condition" in col)) {
            print "formal: selected_count_files.tsv must contain sample_id and condition" > "/dev/stderr"
            exit 2
        }
        print "sample", "condition"
        next
    }
    $0 == "" { next }
    {
        print $(col["sample_id"]), $(col["condition"])
    }
' "$selected" > "$metadata"

echo "[FORMAL] rnaseq-de-flow yeast 12v12 count matrix"
(
    cd "$run_dir"
    "$de_flow_cmd" \
        --counts "$counts" \
        --metadata "$metadata" \
        --design '~ condition' \
        --contrast condition:snf2_KO:WT \
        --outdir de-out \
        --fit-type local \
        --min-count 10 \
        --min-samples 4 \
        --padj-cutoff 0.05 \
        --lfc-cutoff 1 \
        --top-var 500 \
        --top-heatmap 50
)

de_out="$run_dir/de-out"
test -s "$de_out/03_results/gene_lists/significant_genes.tsv"
test -s "$de_out/03_results/gene_lists/ranked_genes.tsv"
test -s "$de_out/04_reports/de_summary.tsv"

echo "[FORMAL] rnaseq-enrichment-flow yeast GO enrichment"
(
    cd "$run_dir"
    "$enrichment_flow_cmd" \
        --gene-list "$de_out/03_results/gene_lists/significant_genes.tsv" \
        --ranked-genes "$de_out/03_results/gene_lists/ranked_genes.tsv" \
        --gene-sets "$gene_sets" \
        --background "$background" \
        --outdir enrichment-out \
        --min-size 2 \
        --max-size 500 \
        --top-n 20
)

enrichment_out="$run_dir/enrichment-out"
test -s "$enrichment_out/03_results/enrichment/ora_results.tsv"
test -s "$enrichment_out/03_results/enrichment/gsea_results.tsv"
test -s "$enrichment_out/04_reports/flow_summary.tsv"

echo "[FORMAL] rnaseq-report-flow yeast DE/enrichment report"
(
    cd "$run_dir"
    "$flow_cmd" \
        --de-out "$de_out" \
        --enrichment-out "$enrichment_out" \
        --project-name "Yeast SNF2 RNA-seq formal" \
        --outdir report-out
)

out="$run_dir/report-out"
test -s "$out/00_inputs/upstream_outputs.tsv"
test -s "$out/01_logs/flow.log"
test -s "$out/01_logs/steps/01_collect_inputs.log"
test -s "$out/01_logs/steps/02_render_report.log"
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

grep -F 'Yeast SNF2 RNA-seq formal' "$out/04_reports/rnaseq_report.html" >/dev/null
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
grep -F 'Tools and Source Links' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '工具与来源链接' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Functional Enrichment' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '功能富集' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'currentSectionId' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'requestAnimationFrame(update)' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'workflow-map' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Deliverables and Output Structure' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'ORA visual summary' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'GSEA directional summary' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'target="_blank" rel="noopener"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data:image/png;base64,' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'id="taffish-embedded-html-reports"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'initEmbeddedReports' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'id="taffish-embedded-tables"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'initEmbeddedTables' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'data-embedded-table-id=' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'class="table-link-body"' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '.embedded-table-link a{align-self:flex-start;margin-top:auto}' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'Embedded table payloads' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'embedded_html_reports.tsv' "$out/04_reports/rnaseq_report.html" >/dev/null
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
grep -F 'provided_modules	2' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'denovo_present	no' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'plot_groups	14' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'embedded_html_reports	1' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'embedded_tables	' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'report_template	taffish-flow-report' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'report_template_version	0.1.0' "$out/04_reports/project_summary.tsv" >/dev/null
if grep -F 'Route	.' "$out/04_reports/key_metrics.tsv" >/dev/null; then
    echo "formal: Route metric should not be an uninformative dot" >&2
    exit 1
fi
if grep -F 'DE source	.' "$out/04_reports/key_metrics.tsv" >/dev/null; then
    echo "formal: DE source metric should not be an uninformative dot" >&2
    exit 1
fi
grep -F 'Collected plots	14' "$out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'Embedded tables	' "$out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'Embedded HTML reports	1' "$out/04_reports/key_metrics.tsv" >/dev/null
grep -F 'report	interpretation' "$out/04_reports/embedded_html_reports.tsv" >/dev/null
test -s "$out/03_results/collected_html/report.interpretation/index.embedded.html"
grep -F 'de	results' "$out/04_reports/collected_files.tsv" >/dev/null
grep -F 'enrichment	ora_results' "$out/04_reports/collected_files.tsv" >/dev/null
grep -F 'de	pca_plot	png' "$out/04_reports/plot_files.tsv" >/dev/null
grep -F 'enrichment	dotplot_original' "$out/04_reports/plot_gallery.tsv" >/dev/null
grep -F 'enrichment	ora_barplot' "$out/04_reports/plot_gallery.tsv" >/dev/null
grep -F 'enrichment	gsea_nes_plot' "$out/04_reports/plot_gallery.tsv" >/dev/null
grep -F 'enrichment	gsea_enrichment_curves' "$out/04_reports/plot_gallery.tsv" >/dev/null
grep -F 'rnaseq-de-flow' "$out/04_reports/versions.tsv" >/dev/null
grep -F 'rnaseq-enrichment-flow' "$out/04_reports/versions.tsv" >/dev/null
grep -F 'flow-report-template	0.1.0	repos/apps/templates/flow-report' "$out/04_reports/versions.tsv" >/dev/null
grep -F '0.1.0' "$out/04_reports/report_template_version.txt" >/dev/null
grep -F 'rnaseq-de-flow' "$out/04_reports/tool_links.tsv" >/dev/null
grep -F 'https://github.com/taffish/rnaseq-enrichment-flow' "$out/04_reports/tool_links.tsv" >/dev/null
grep -F '"flow": "rnaseq-report-flow"' "$out/run.manifest.json" >/dev/null
grep -F '"interpretation_guide":' "$out/run.manifest.json" >/dev/null
grep -F '"embedded_html_reports":' "$out/run.manifest.json" >/dev/null
grep -F '"embedded_tables":' "$out/run.manifest.json" >/dev/null
grep -F '"template": "taffish-flow-report"' "$out/run.manifest.json" >/dev/null
grep -F '"template_version": "0.1.0"' "$out/run.manifest.json" >/dev/null

if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$out/run.manifest.json" >/dev/null
fi

echo "[FORMAL] ok"
