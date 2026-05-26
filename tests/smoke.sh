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

flow_cmd="$project_dir/target/taf-rnaseq-report-flow-v0.1.0-r1"
if [ ! -x "$flow_cmd" ]; then
    echo "smoke: built flow command is missing or not executable: $flow_cmd" >&2
    exit 1
fi

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

alignment_qc_out="$run_dir/alignment-qc-out"
make_common_reports "$alignment_qc_out" "rnaseq-alignment-qc-flow"
mkdir -p "$alignment_qc_out/03_results"
cat > "$alignment_qc_out/03_results/rnaseq_qc_summary.tsv" <<'EOF'
sample_id	total_records
S1	100
EOF
cp "$alignment_qc_out/03_results/rnaseq_qc_summary.tsv" "$alignment_qc_out/04_reports/rnaseq_qc_summary.tsv"

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
printf 'PDF smoke\n' > "$de_out/03_results/plots/pca_plot.pdf"
printf 'PDF smoke\n' > "$de_out/03_results/plots/ma_plot.pdf"
printf 'PDF smoke\n' > "$de_out/03_results/plots/volcano_plot.pdf"
printf 'PDF smoke\n' > "$de_out/03_results/plots/heatmap.pdf"

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
test -s "$out/04_reports/rnaseq_report.html"
test -s "$out/04_reports/project_summary.tsv"
test -s "$out/04_reports/collected_files.tsv"
test -s "$out/04_reports/commands.sh"
test -s "$out/04_reports/versions.tsv"
test -s "$out/04_reports/methods.txt"
test -s "$out/04_reports/flow_summary.tsv"
test -s "$out/run.manifest.json"

grep -F 'Smoke RNA-seq report' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F 'provided_modules	6' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'rnaseq-report-flow	0.1.0-r1	taffish flow' "$out/04_reports/versions.tsv" >/dev/null
grep -F 'rnaseq-de-flow' "$out/04_reports/versions.tsv" >/dev/null
grep -F 'enrichment	ora_results' "$out/04_reports/collected_files.tsv" >/dev/null
grep -F 'de	pca_plot' "$out/04_reports/collected_files.tsv" >/dev/null
grep -F '"flow": "rnaseq-report-flow"' "$out/run.manifest.json" >/dev/null
if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$out/run.manifest.json" >/dev/null
fi

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
grep -F 'provided_modules	1' "$out/04_reports/project_summary.tsv" >/dev/null

stray=$(find "$run_dir" -mindepth 1 -maxdepth 1 ! -name expression-out ! -name align-out ! -name count-out ! -name alignment-qc-out ! -name de-out ! -name enrichment-out ! -name report-out -print)
if [ -n "$stray" ]; then
    echo "smoke: flow wrote unexpected files outside outdir:" >&2
    printf '%s\n' "$stray" >&2
    exit 1
fi

echo "[SMOKE] ok"
