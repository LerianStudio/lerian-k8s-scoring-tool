#!/bin/bash
# =============================================================================
# lerian-scoring.sh - Lerian Infrastructure Scoring Tool (v2)
# =============================================================================
# Main entry point. Sources all library files from lib/ and orchestrates
# the collection, scoring, and reporting pipeline.
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

# -----------------------------------------------------------------------------
# Resolve the script's real directory (handles symlinks)
# -----------------------------------------------------------------------------
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    # If readlink returned a relative path, resolve it against the dir
    case "$SCRIPT_SOURCE" in
        /*) ;;
        *)  SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE" ;;
    esac
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# -----------------------------------------------------------------------------
# Source all lib/*.sh files in sorted order
# -----------------------------------------------------------------------------
for lib_file in "$SCRIPT_DIR"/lib/*.sh; do
    if [ -f "$lib_file" ]; then
        # shellcheck source=/dev/null
        . "$lib_file"
    fi
done

# -----------------------------------------------------------------------------
# Enable strict mode AFTER sourcing libs (libs may do setup that should not fail)
# -----------------------------------------------------------------------------
set -euo pipefail

# -----------------------------------------------------------------------------
# Help Text
# -----------------------------------------------------------------------------
show_help() {
    cat << 'HELPEOF'
Lerian Infrastructure Scoring Tool v2

Collects Kubernetes cluster metrics and external database health data,
scores each domain on a 0-100 scale, and produces a consolidated report.

Usage: lerian-scoring.sh [OPTIONS]

Options:
  -o, --output <format>       Output format: text, csv, json (default: text)
  -n, --namespace <ns>        Target namespaces (semicolon-separated) for
                              workload collection. Cluster-level info (nodes,
                              CPU, memory) is always collected globally.
                              (default: midaz;midaz-plugins)
  -f, --file <filename>       Save output to file (default: stdout)
  -c, --client <name>         Client / environment name
                              (default: $CLIENT_NAME or "lerian-environment")
  --no-external-dbs           Skip external database collection and scoring
  --external-dbs-only         Skip K8s collection; collect databases only
  -e, --environment <env>     Environment: stg, hml, prd (default: prd)
  --customer <name>           Customer identifier (required for webhook upload)
  --upload-webhook <url>      Webhook URL to upload the final report
  -h, --help                  Show this help message

Examples:
  lerian-scoring.sh                                  # Default namespaces
  lerian-scoring.sh -n "midaz-stg;midaz-plugins-stg" # Custom namespaces
  lerian-scoring.sh -n "all"                         # All namespaces
  lerian-scoring.sh -o csv -f report.csv             # Export to CSV
  lerian-scoring.sh -o json                          # JSON to stdout
  lerian-scoring.sh --no-external-dbs                # K8s only
  lerian-scoring.sh --external-dbs-only              # DB scoring only
  lerian-scoring.sh -e stg --customer "acme-staging"   # Staging environment
  lerian-scoring.sh -c "acme-prod" -o json -f out.json

Database Connection:
  Connection info is auto-discovered from Kubernetes ConfigMaps and Secrets
  in the target namespaces. Discovery is resilient with two phases:

    Phase 1: Tries well-known configmap names first (midaz-onboarding,
             midaz-transaction, midaz-ledger) — same as original behavior.
    Phase 2: If any credentials are still missing after Phase 1, scans ALL
             configmaps in target namespaces for DB keys (DB_HOST, MONGO_HOST,
             REDIS_HOST, RABBITMQ_HOST). Handles Terraform/Helm deployments
             with custom release names (e.g. <release>-onboarding).

  Also supports ledger-style prefixed keys (DB_ONBOARDING_HOST,
  DB_TRANSACTION_HOST, MONGO_ONBOARDING_HOST, MONGO_TRANSACTION_HOST, etc.)

  Override any value via environment variables:
    EXTERNAL_PG_HOST, EXTERNAL_PG_PORT, EXTERNAL_PG_USER, EXTERNAL_PG_PASS
    EXTERNAL_MONGO_HOST, EXTERNAL_MONGO_PORT, EXTERNAL_MONGO_USER, EXTERNAL_MONGO_PASS
    EXTERNAL_MONGO_ENGINE  (set to "documentdb" for AWS DocumentDB; auto if empty)
    EXTERNAL_REDIS_HOST, EXTERNAL_REDIS_PORT, EXTERNAL_REDIS_PASS
    EXTERNAL_RABBITMQ_HOST, EXTERNAL_RABBITMQ_PORT, EXTERNAL_RABBITMQ_USER,
    EXTERNAL_RABBITMQ_PASS

HELPEOF
    exit 0
}

# -----------------------------------------------------------------------------
# Parse CLI Arguments
# -----------------------------------------------------------------------------
UPLOAD_WEBHOOK_URL="https://lerian.app.n8n.cloud/webhook/lerian-scoring-tool"

while [ $# -gt 0 ]; do
    case "$1" in
        -o|--output)
            if [ $# -lt 2 ]; then
                echo "Error: --output requires a format argument (text, csv, json)" >&2
                exit 1
            fi
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -n|--namespace)
            if [ $# -lt 2 ]; then
                echo "Error: --namespace requires a namespace argument" >&2
                exit 1
            fi
            TARGET_NAMESPACES="$2"
            shift 2
            ;;
        -f|--file)
            if [ $# -lt 2 ]; then
                echo "Error: --file requires a filename argument" >&2
                exit 1
            fi
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -c|--client)
            if [ $# -lt 2 ]; then
                echo "Error: --client requires a name argument" >&2
                exit 1
            fi
            CLIENT_NAME="$2"
            shift 2
            ;;
        --no-external-dbs)
            COLLECT_EXTERNAL_DBS="false"
            shift
            ;;
        --external-dbs-only)
            SKIP_K8S_COLLECTION=true
            shift
            ;;
        -e|--environment)
            if [ $# -lt 2 ]; then
                echo "Error: --environment requires an argument (stg, hml, prd)" >&2
                exit 1
            fi
            ENVIRONMENT="$2"
            shift 2
            ;;
        --customer)
            if [ $# -lt 2 ]; then
                echo "Error: --customer requires a name argument" >&2
                exit 1
            fi
            CUSTOMER="$2"
            shift 2
            ;;
        --upload-webhook)
            if [ $# -lt 2 ]; then
                echo "Error: --upload-webhook requires a URL argument" >&2
                exit 1
            fi
            UPLOAD_WEBHOOK_URL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Run '$(basename "$0") --help' for usage information." >&2
            exit 1
            ;;
    esac
done

# Validate output format
case "$OUTPUT_FORMAT" in
    text|csv|json) ;;
    *)
        echo "Error: Invalid output format '$OUTPUT_FORMAT'. Must be text, csv, or json." >&2
        exit 1
        ;;
esac

# Validate environment
case "$ENVIRONMENT" in
    stg|hml|prd) ;;
    *)
        echo "Error: Invalid environment '$ENVIRONMENT'. Must be stg, hml, or prd." >&2
        exit 1
        ;;
esac

# Validate customer is set when webhook is configured
if [ -n "$UPLOAD_WEBHOOK_URL" ] && [ -z "$CUSTOMER" ]; then
    echo "Error: --customer is required when webhook upload is enabled." >&2
    echo "Usage: $(basename "$0") --customer <name>" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Execution Pipeline
# -----------------------------------------------------------------------------

# -- Phase 0: Prerequisites ---------------------------------------------------
check_prerequisites

# -- Phase 1: Credential Discovery ---------------------------------------------
if [ "$COLLECT_EXTERNAL_DBS" = "true" ]; then
    fetch_k8s_db_credentials
fi

# -- Phase 2: Data Collection --------------------------------------------------
if [ "$SKIP_K8S_COLLECTION" != true ]; then
    collect_all_k8s
fi

if [ "$COLLECT_EXTERNAL_DBS" = "true" ]; then
    log_info "Collecting external database metrics..."
    collect_postgresql_data
    collect_mongodb_data
    collect_valkey_data
    collect_rabbitmq_data
    log_success "External database collection completed"
fi

# -- Phase 3: Scoring ----------------------------------------------------------
if [ "$SKIP_K8S_COLLECTION" != "true" ]; then
    calculate_all_k8s_scores
fi

if [ "$COLLECT_EXTERNAL_DBS" = "true" ]; then
    log_info "Scoring external databases..."
    calculate_postgres_score
    calculate_mongodb_score
    calculate_valkey_score
    calculate_rabbitmq_score
    log_success "DB scoring complete — PG:${PG_SCORE} Mongo:${MONGO_SCORE} Valkey:${VALKEY_SCORE} RMQ:${RMQ_SCORE}"
fi

# Clear credentials from memory before report generation
if [ "$COLLECT_EXTERNAL_DBS" = "true" ]; then
    clear_db_credentials
fi
compute_unified_score

# -- Phase 4: Report Generation ------------------------------------------------
run_output "$OUTPUT_FORMAT" "$OUTPUT_FILE"

# -- Phase 5: Upload (optional) ------------------------------------------------
upload_report_webhook "$REPORT_FULL_PATH"
