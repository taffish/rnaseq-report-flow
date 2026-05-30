#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd "$script_dir/.." && pwd)
bio_apps_dir=$(CDPATH= cd "$project_dir/../../../.." && pwd)
rnaseq_root=$(CDPATH= cd "$project_dir/../.." && pwd)
assembly_flow_dir="$rnaseq_root/subflows/rnaseq-denovo-assembly-flow"
expression_flow_dir="$rnaseq_root/subflows/rnaseq-denovo-expression-flow"
annotation_flow_dir="$rnaseq_root/subflows/rnaseq-denovo-annotation-flow"
default_data_root=$(CDPATH= cd "$rnaseq_root/test-data/yeast/data/03_results" 2>/dev/null && pwd || printf '%s\n' "$rnaseq_root/test-data/yeast/data/03_results")
data_root=${TAFFISH_RNASEQ_TESTDATA:-$default_data_root}

for target_dir in \
    "$bio_apps_dir/tools/trinity/target" \
    "$bio_apps_dir/tools/spades/target" \
    "$bio_apps_dir/tools/fastqc/target" \
    "$bio_apps_dir/tools/fastp/target" \
    "$bio_apps_dir/tools/seqkit/target" \
    "$bio_apps_dir/tools/busco/target" \
    "$bio_apps_dir/tools/multiqc/target" \
    "$bio_apps_dir/tools/salmon/target" \
    "$bio_apps_dir/tools/transdecoder/target" \
    "$bio_apps_dir/tools/diamond/target" \
    "$assembly_flow_dir/target" \
    "$expression_flow_dir/target" \
    "$annotation_flow_dir/target"
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

skip_run() {
    echo "test-denovo-real-run: skipped: $*" >&2
    exit 0
}

is_true() {
    case "$1" in
        T|t|true|TRUE|True|1|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

if [ ! -d "$data_root" ]; then
    skip_run "RNA-seq test data root not found: $data_root"
fi

fastq_pkg="$data_root/yeast-snf2-fastq-mini-v1"
wt_fastq="$fastq_pkg/reads/WT_01.fq.gz"
ko_fastq="$fastq_pkg/reads/SNF2KO_01.fq.gz"
reference_tar="$data_root/yeast-reference-sgd-r64.4.1-v1/source/S288C_reference_genome_R64-4-1_20230830.tgz"
go_terms="$data_root/yeast-sgd-go-gene-sets-r64.4.1-v1/metadata/go_terms.tsv"

[ -s "$wt_fastq" ] || skip_run "missing yeast WT FASTQ: $wt_fastq"
[ -s "$ko_fastq" ] || skip_run "missing yeast SNF2KO FASTQ: $ko_fastq"
[ -s "$reference_tar" ] || skip_run "missing yeast reference tarball: $reference_tar"
[ -s "$go_terms" ] || skip_run "missing yeast GO terms: $go_terms"

if ! command -v taf >/dev/null 2>&1; then
    echo "test-denovo-real-run: taf command not found in PATH." >&2
    exit 127
fi

for dep in \
    taf-trinity-v2.15.2-r2 \
    taf-spades-v4.2.0-r1 \
    taf-fastqc-v0.12.1-r1 \
    taf-fastp-v1.3.3-r3 \
    taf-seqkit-v2.13.0-r2 \
    taf-busco-v6.0.0-r2 \
    taf-multiqc-v1.35-r2 \
    taf-salmon-v1.11.4-r1 \
    taf-transdecoder-v6.0.0-r1 \
    taf-diamond-v2.2.1-r1
do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "test-denovo-real-run: dependency wrapper not found in PATH: $dep" >&2
        exit 127
    fi
done

run_root="$script_dir/test-real-run-report-denovo-0.2.0-r2"
if [ -e "$run_root" ]; then
    if is_true "${FORCE:-false}"; then
        rm -rf "$run_root"
    else
        echo "test-denovo-real-run: output already exists: $run_root" >&2
        echo "test-denovo-real-run: set FORCE=true to replace it." >&2
        exit 1
    fi
fi

echo "[DENOVO-REAL] build rnaseq-denovo-assembly-flow"
(
    cd "$assembly_flow_dir"
    taf check
    taf build
)

echo "[DENOVO-REAL] build rnaseq-denovo-expression-flow"
(
    cd "$expression_flow_dir"
    taf check
    taf build
)

echo "[DENOVO-REAL] build rnaseq-denovo-annotation-flow"
(
    cd "$annotation_flow_dir"
    taf check
    taf build
)

echo "[DENOVO-REAL] build rnaseq-report-flow"
(
    cd "$project_dir"
    taf check
    taf build
)

assembly_flow_cmd="$assembly_flow_dir/target/taf-rnaseq-denovo-assembly-flow-v0.1.0-r1"
expression_flow_cmd="$expression_flow_dir/target/taf-rnaseq-denovo-expression-flow-v0.1.0-r1"
annotation_flow_cmd="$annotation_flow_dir/target/taf-rnaseq-denovo-annotation-flow-v0.1.0-r1"
report_flow_cmd="$project_dir/target/taf-rnaseq-report-flow-v0.2.0-r2"

for cmd in "$assembly_flow_cmd" "$expression_flow_cmd" "$annotation_flow_cmd" "$report_flow_cmd"; do
    if [ ! -x "$cmd" ]; then
        echo "test-denovo-real-run: built flow command is missing or not executable: $cmd" >&2
        exit 1
    fi
done

mkdir -p "$run_root/work/reads" "$run_root/work/resources"

echo "[DENOVO-REAL] prepare real yeast FASTQ subset"
gzip -cd "$wt_fastq" | awk 'NR <= 8000 { print }' > "$run_root/work/reads/WT_01.fq"
gzip -cd "$ko_fastq" | awk 'NR <= 8000 { print }' > "$run_root/work/reads/SNF2KO_01.fq"
test -s "$run_root/work/reads/WT_01.fq"
test -s "$run_root/work/reads/SNF2KO_01.fq"

samples="$run_root/work/samples.tsv"
{
    printf 'sample_id\tread1\tcondition\n'
    printf 'WT_01\treads/WT_01.fq\tWT\n'
    printf 'SNF2KO_01\treads/SNF2KO_01.fq\tsnf2_KO\n'
} > "$samples"

protein_db="$run_root/work/resources/sgd_orf_translations.faa"
go_map="$run_root/work/resources/sgd_orf_go_map.tsv"

echo "[DENOVO-REAL] prepare real SGD protein FASTA and GO map"
tar -xOzf "$reference_tar" S288C_reference_genome_R64-4-1_20230830/orf_trans_all_R64-4-1_20230830.fasta.gz \
    | gzip -cd \
    | awk '
        /^>/ {
            print
            next
        }
        {
            gsub(/\*/, "")
            gsub(/[[:space:]]/, "")
            if ($0 != "") print
        }
    ' > "$protein_db"
test -s "$protein_db"

tar -xOzf "$reference_tar" S288C_reference_genome_R64-4-1_20230830/gene_association_R64-4-1_20230830.sgd.gz \
    | gzip -cd \
    | awk -F '\t' -v OFS='\t' -v terms="$go_terms" '
        BEGIN {
            while ((getline line < terms) > 0) {
                n = split(line, t, "\t")
                if (n < 3 || t[1] == "go_id") continue
                go_name[t[1]] = t[2]
                go_namespace[t[1]] = t[3]
            }
            close(terms)
            print "subject_id", "go_id", "go_name", "namespace"
        }
        /^!/ || NF < 11 { next }
        {
            split($11, synonyms, "|")
            subject = synonyms[1]
            go = $5
            if (subject == "" || go == "") next
            name = (go in go_name) ? go_name[go] : go
            namespace = (go in go_namespace) ? go_namespace[go] : $9
            if (namespace == "P") namespace = "biological_process"
            else if (namespace == "F") namespace = "molecular_function"
            else if (namespace == "C") namespace = "cellular_component"
            key = subject SUBSEP go
            if (!(key in seen)) {
                seen[key] = 1
                print subject, go, name, namespace
            }
        }
    ' > "$go_map"
test -s "$go_map"

echo "[DENOVO-REAL] rnaseq-denovo-assembly-flow yeast subset"
(
    cd "$run_root/work"
    "$assembly_flow_cmd" \
        --samples "$samples" \
        --outdir "$run_root/denovo-assembly-out" \
        --threads 2 \
        --max-memory 2G \
        --min-contig-len 100 \
        --skip-fastqc \
        --no-normalize
)

assembled="$run_root/denovo-assembly-out/03_results/transcripts/assembled_transcripts.filtered.fa"
test -s "$assembled"

echo "[DENOVO-REAL] rnaseq-denovo-expression-flow yeast subset"
(
    cd "$run_root/work"
    "$expression_flow_cmd" \
        --samples "$samples" \
        --transcripts "$assembled" \
        --outdir "$run_root/denovo-expression-out" \
        --threads 2 \
        --library-type A \
        --kmer 15 \
        --skip-fastqc \
        --min-assigned-frags 1
)

echo "[DENOVO-REAL] rnaseq-denovo-annotation-flow yeast subset"
(
    cd "$run_root/work"
    "$annotation_flow_cmd" \
        --transcripts "$assembled" \
        --protein-db "$protein_db" \
        --go-map "$go_map" \
        --outdir "$run_root/denovo-annotation-out" \
        --threads 2 \
        --min-orf-aa 30 \
        --evalue 1e-3 \
        --max-target-seqs 1
)

echo "[DENOVO-REAL] rnaseq-report-flow de novo report"
(
    cd "$run_root"
    "$report_flow_cmd" \
        --denovo-assembly-out denovo-assembly-out \
        --denovo-expression-out denovo-expression-out \
        --denovo-annotation-out denovo-annotation-out \
        --project-name "Yeast SNF2 de novo RNA-seq report" \
        --outdir report-out
)

out="$run_root/report-out"
test -s "$out/04_reports/rnaseq_report.html"
test -s "$out/04_reports/report_interpretation.html"
test -s "$out/04_reports/project_summary.tsv"
test -s "$out/04_reports/key_metrics.tsv"
test -s "$out/04_reports/collected_files.tsv"
test -s "$out/run.manifest.json"
grep -F 'denovo_present	yes' "$out/04_reports/project_summary.tsv" >/dev/null
grep -F 'De novo Assembly, Expression, and Annotation' "$out/04_reports/rnaseq_report.html" >/dev/null
grep -F '无参组装、表达与注释' "$out/04_reports/rnaseq_report.html" >/dev/null

echo "[DENOVO-REAL] ok"
echo "[DENOVO-REAL] report: $out/04_reports/rnaseq_report.html"
echo "[DENOVO-REAL] interpretation: $out/04_reports/report_interpretation.html"
