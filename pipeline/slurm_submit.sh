#!/usr/bin/env bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=4GB
#SBATCH --partition=cpu
#SBATCH --time=3:00:00

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script must be run with bash."
    echo "Try: bash $0 --data <DATA_PATH> --results <RESULTS_PATH> --workdir <WORKDIR> --format <FORMAT> [--additional-params \"...\"]"
    exit 1
fi

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $0 --data <DATA_PATH> --results <RESULTS_PATH> --workdir <WORKDIR> --format <FORMAT> [--additional-params "<ARGS>"]
  $0 -d <DATA_PATH> -r <RESULTS_PATH> -w <WORKDIR> -f <FORMAT> [-a "<ARGS>"]

Required arguments:
  -d, --data                Path to input data folder
  -r, --results             Path to results/output folder
  -w, --workdir             Path to Nextflow work directory
  -f, --format              Input format (one of: aind, spikeglx, openephys, nwb, spikeinterface)

Optional arguments:
  -a, --additional-params   Arbitrary extra parameters appended to the end of the nextflow command
  -h, --help                Show this help message and exit

Examples:
  sbatch $0 --data /path/to/data --results /path/to/results --workdir /path/to/work --format nwb
  sbatch $0 -d /path/to/data -r /path/to/results -w /path/to/work -f spikeglx -a "--resume --with-report report.html"
EOF
}

# modify this section to make the nextflow command available to your environment
# e.g., using a conda environment with nextflow installed
export NXF_SYNTAX_PARSER="v1"
export KACHERY_API_KEY="4TaospIr3VDLqOGlYWgoAoGGM3wDEiJw"
export NXF_APPTAINER_CACHEDIR="/work/pi_mmanuel_uri_edu/sorters/"

PIPELINE_PATH="/work/pi_mmanuel_uri_edu/aind-ephys-pipeline"

DATA_PATH=""
RESULTS_PATH=""
WORKDIR=""
FORMAT=""
ADDITIONAL_PARAMS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--data)
            [[ $# -ge 2 ]] || { echo "Error: $1 requires a value"; usage; exit 1; }
            DATA_PATH="$2"
            shift 2
            ;;
        -r|--results)
            [[ $# -ge 2 ]] || { echo "Error: $1 requires a value"; usage; exit 1; }
            RESULTS_PATH="$2"
            shift 2
            ;;
        -w|--workdir)
            [[ $# -ge 2 ]] || { echo "Error: $1 requires a value"; usage; exit 1; }
            WORKDIR="$2"
            shift 2
            ;;
        -f|--format)
            [[ $# -ge 2 ]] || { echo "Error: $1 requires a value"; usage; exit 1; }
            FORMAT="$2"
            shift 2
            ;;
        -a|--additional-params)
            [[ $# -ge 2 ]] || { echo "Error: $1 requires a value"; usage; exit 1; }
            ADDITIONAL_PARAMS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$1'"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$DATA_PATH" || -z "$RESULTS_PATH" || -z "$WORKDIR" || -z "$FORMAT" ]]; then
    echo "Error: --data/-d, --results/-r, --workdir/-w, and --format/-f are required."
    usage
    exit 1
fi

case "$FORMAT" in
    aind|spikeglx|openephys|nwb|spikeinterface)
        ;;
    *)
        echo "Error: Invalid format '$FORMAT'."
        echo "Valid formats: aind, spikeglx, openephys, nwb, spikeinterface"
        usage
        exit 1
        ;;
esac

# check if nextflow_local_custom.config exists
if [ -f "$PIPELINE_PATH/pipeline/nextflow_slurm_custom.config" ]; then
    CONFIG_FILE="$PIPELINE_PATH/pipeline/nextflow_slurm_custom.config"
else
    CONFIG_FILE="$PIPELINE_PATH/pipeline/nextflow_slurm.config"
fi
echo "Using config file: $CONFIG_FILE"

mkdir -p "$RESULTS_PATH/nextflow"

CMD=(
    nextflow
    -C "$CONFIG_FILE"
    -log "$RESULTS_PATH/nextflow/nextflow.log"
    run "$PIPELINE_PATH/pipeline/main_multi_backend.nf"
    -work-dir "$WORKDIR"
    --job_dispatch_args="--input $FORMAT"
)

# Append additional params (if provided) to the end of the command
if [[ -n "$ADDITIONAL_PARAMS" ]]; then
    # Intentionally split user-provided string into arguments
    # shellcheck disable=SC2206
    EXTRA_ARGS=( $ADDITIONAL_PARAMS )
    CMD+=( "${EXTRA_ARGS[@]}" )
fi

DATA_PATH="$DATA_PATH" RESULTS_PATH="$RESULTS_PATH" "${CMD[@]}"
