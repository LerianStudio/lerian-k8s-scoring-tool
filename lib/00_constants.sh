#!/bin/bash
# =============================================================================
# 00_constants.sh - Global Constants and Default Configuration
# =============================================================================
# Part of the Lerian Infrastructure Scoring Tool v2.
#
# This file defines ALL global constants, default configuration values,
# scoring weights, color codes, and initialized data variables used
# throughout the tool. It is meant to be sourced by the main script,
# not executed directly.
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Script Metadata
# -----------------------------------------------------------------------------
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="Lerian Infrastructure Scoring Tool"

# -----------------------------------------------------------------------------
# 2. Default Configuration
# -----------------------------------------------------------------------------
CLIENT_NAME="${CLIENT_NAME:-lerian-environment}"
TARGET_NAMESPACES="${TARGET_NAMESPACES:-midaz;midaz-plugins}"
OUTPUT_FORMAT="text"
OUTPUT_FILE=""
COLLECT_EXTERNAL_DBS="${COLLECT_EXTERNAL_DBS:-true}"
SKIP_K8S_COLLECTION=false
ENVIRONMENT="${ENVIRONMENT:-prd}"
CUSTOMER="${CUSTOMER:-}"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"

# -----------------------------------------------------------------------------
# 3. Color Codes (Terminal Output)
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# -----------------------------------------------------------------------------
# 4. Health Bands (0-100 scale, used by ALL domains)
# -----------------------------------------------------------------------------
#   90-100 = Excellent
#   75-89  = Good
#   60-74  = Fair
#   40-59  = Poor
#   0-39   = Critical
# -----------------------------------------------------------------------------
HEALTH_EXCELLENT_MIN=90
HEALTH_GOOD_MIN=75
HEALTH_FAIR_MIN=60
HEALTH_POOR_MIN=40

# -----------------------------------------------------------------------------
# 5. K8s Scoring Category Weights (8 categories, sum = 100)
# -----------------------------------------------------------------------------
K8S_WEIGHT_NODES=20
K8S_WEIGHT_WORKLOADS=20
K8S_WEIGHT_RESOURCES=15
K8S_WEIGHT_SECURITY=15
K8S_WEIGHT_STORAGE=10
K8S_WEIGHT_EVENTS=10
K8S_WEIGHT_NETWORKING=5
K8S_WEIGHT_CONFIG=5

# -----------------------------------------------------------------------------
# 6. DB Scoring Category Weights
# -----------------------------------------------------------------------------

# PostgreSQL weights (sum = 100)
PG_WEIGHT_PERFORMANCE=15
PG_WEIGHT_AVAILABILITY=15
PG_WEIGHT_MAINTENANCE=15
PG_WEIGHT_REPLICATION=15
PG_WEIGHT_RESOURCES=10
PG_WEIGHT_SECURITY=10
PG_WEIGHT_IO=10
PG_WEIGHT_INDEXES=5
PG_WEIGHT_CONFIG=5

# MongoDB weights (sum = 100)
MONGO_WEIGHT_PERFORMANCE=20
MONGO_WEIGHT_REPLICATION=20
MONGO_WEIGHT_RESOURCES=15
MONGO_WEIGHT_STORAGE=15
MONGO_WEIGHT_SECURITY=10
MONGO_WEIGHT_TOPOLOGY=10
MONGO_WEIGHT_INDEXES=5
MONGO_WEIGHT_CONFIG=5

# Valkey weights (sum = 100)
VALKEY_WEIGHT_MEMORY=20
VALKEY_WEIGHT_PERFORMANCE=20
VALKEY_WEIGHT_REPLICATION=15
VALKEY_WEIGHT_PERSISTENCE=15
VALKEY_WEIGHT_CONNECTIONS=10
VALKEY_WEIGHT_CLUSTER=10
VALKEY_WEIGHT_SECURITY=5
VALKEY_WEIGHT_CONFIG=5

# RabbitMQ weights (sum = 100)
RMQ_WEIGHT_QUEUES=20
RMQ_WEIGHT_THROUGHPUT=20
RMQ_WEIGHT_RESOURCES=15
RMQ_WEIGHT_CLUSTER=15
RMQ_WEIGHT_CONNECTIONS=10
RMQ_WEIGHT_SECURITY=10
RMQ_WEIGHT_PERSISTENCE=5
RMQ_WEIGHT_CONFIG=5

# -----------------------------------------------------------------------------
# 7. Grand Unified Score Weights (default; absent domains redistributed)
# -----------------------------------------------------------------------------
UNIFIED_WEIGHT_K8S=30
UNIFIED_WEIGHT_PG=25
UNIFIED_WEIGHT_MONGO=20
UNIFIED_WEIGHT_VALKEY=15
UNIFIED_WEIGHT_RMQ=10

# -----------------------------------------------------------------------------
# 8. Global Data Variables (initialized to empty/defaults)
# -----------------------------------------------------------------------------

# Cluster metadata
CLUSTER_NAME=""
CLUSTER_SERVER=""
K8S_VERSION=""
NODE_COUNT=0

# K8s raw data (JSON defaults)
NODE_INFO='{"items":[]}'
POD_INFO='{"items":[]}'
DEPLOYMENT_INFO='{"items":[]}'
STATEFULSET_INFO='{"items":[]}'
DAEMONSET_INFO='{"items":[]}'
SERVICE_INFO='{"items":[]}'
INGRESS_INFO='{"items":[]}'
PVC_INFO='{"items":[]}'
PV_INFO='{"items":[]}'
CONFIGMAP_INFO='{"items":[]}'
SECRET_INFO='{"items":[]}'
EVENT_INFO='{"items":[]}'
HPA_INFO='{"items":[]}'
PDB_INFO='{"items":[]}'
NETWORKPOLICY_INFO='{"items":[]}'
RESOURCEQUOTA_INFO='{"items":[]}'
LIMITRANGE_INFO='{"items":[]}'

# K8s feature flags
METRICS_AVAILABLE=false
RBAC_INFO=""

# DB raw data — primary
PG_RAW_DATA=""
MONGO_RAW_DATA=""
VALKEY_RAW_DATA=""
RMQ_RAW_DATA=""

# DB raw data — PostgreSQL supplementary
PG_BGWRITER_DATA=""
PG_TABLE_IO_DATA="[]"
PG_INDEX_IO_DATA="[]"
PG_WAL_IO_DATA="{}"
PG_STAT_IO_DATA="[]"
PG_TABLES_DATA="[]"
PG_INDEXES_DATA="[]"
PG_DATABASES_DATA="[]"
PG_SEQ_SCANS_DATA="[]"
PG_DUPLICATE_INDEXES="[]"
PG_ROLES_DATA="[]"
PG_CONNECTIONS_DATA="[]"
PG_REPL_SLOTS="[]"

# DB raw data — MongoDB supplementary
MONGO_DATABASES_DATA="[]"
MONGO_COLLECTIONS_DATA="[]"

# DB raw data — Valkey/Redis supplementary
VALKEY_SLOWLOG_DATA=""
VALKEY_SLOWLOG_LEN="0"
VALKEY_CLIENT_LIST=""
VALKEY_DBSIZE=""
VALKEY_MAXMEMORY_POLICY=""
VALKEY_TIMEOUT=""
VALKEY_HZ=""
VALKEY_SLOWLOG_THRESHOLD=""

# DB raw data — RabbitMQ supplementary
RMQ_QUEUES_DATA="[]"
RMQ_NODES_DATA="[]"
RMQ_CONNECTIONS_DATA="[]"
RMQ_CHANNELS_DATA="[]"
RMQ_VHOSTS_DATA="[]"
RMQ_EXCHANGES_DATA="[]"
RMQ_BINDINGS_DATA="[]"

# DB status tracking
EXTERNAL_PG_STATUS="not_checked"
EXTERNAL_MONGO_STATUS="not_checked"
EXTERNAL_REDIS_STATUS="not_checked"
EXTERNAL_RABBITMQ_STATUS="not_checked"

# Attention log — accumulates warnings/errors during execution
ATTENTION_LOG=""

# DB score variables (initialized to 0)
PG_SCORE=0
MONGO_SCORE=0
VALKEY_SCORE=0
RMQ_SCORE=0

# DB rating text/emoji
PG_RATING_TEXT=""
PG_RATING_EMOJI=""
MONGO_RATING_TEXT=""
MONGO_RATING_EMOJI=""
VALKEY_RATING_TEXT=""
VALKEY_RATING_EMOJI=""
RMQ_RATING_TEXT=""
RMQ_RATING_EMOJI=""

# Grand Unified Score
UNIFIED_SCORE=0
UNIFIED_RATING_TEXT=""
UNIFIED_RATING_EMOJI=""

# Tool availability flags
PSQL_AVAILABLE=false
MONGO_AVAILABLE=false
REDIS_CLI_AVAILABLE=false
CURL_AVAILABLE=false

# -----------------------------------------------------------------------------
# 9. External DB Configuration (overridable via env vars, default empty)
# -----------------------------------------------------------------------------

# PostgreSQL
EXTERNAL_PG_HOST="${EXTERNAL_PG_HOST:-}"
EXTERNAL_PG_PORT="${EXTERNAL_PG_PORT:-}"
EXTERNAL_PG_USER="${EXTERNAL_PG_USER:-}"
EXTERNAL_PG_PASS="${EXTERNAL_PG_PASS:-}"
EXTERNAL_PG_DATABASES="${EXTERNAL_PG_DATABASES:-}"

# MongoDB
EXTERNAL_MONGO_HOST="${EXTERNAL_MONGO_HOST:-}"
EXTERNAL_MONGO_PORT="${EXTERNAL_MONGO_PORT:-}"
EXTERNAL_MONGO_USER="${EXTERNAL_MONGO_USER:-}"
EXTERNAL_MONGO_PASS="${EXTERNAL_MONGO_PASS:-}"
EXTERNAL_MONGO_DATABASES="${EXTERNAL_MONGO_DATABASES:-}"
EXTERNAL_MONGO_ENGINE="${EXTERNAL_MONGO_ENGINE:-}"

# Valkey / Redis
EXTERNAL_REDIS_HOST="${EXTERNAL_REDIS_HOST:-}"
EXTERNAL_REDIS_PORT="${EXTERNAL_REDIS_PORT:-}"
EXTERNAL_REDIS_PASS="${EXTERNAL_REDIS_PASS:-}"

# RabbitMQ
EXTERNAL_RABBITMQ_HOST="${EXTERNAL_RABBITMQ_HOST:-}"
EXTERNAL_RABBITMQ_PORT="${EXTERNAL_RABBITMQ_PORT:-}"
EXTERNAL_RABBITMQ_USER="${EXTERNAL_RABBITMQ_USER:-}"
EXTERNAL_RABBITMQ_PASS="${EXTERNAL_RABBITMQ_PASS:-}"
