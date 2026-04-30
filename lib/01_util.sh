#!/bin/bash
#===============================================================================
# 01_util.sh — Utility functions for k8s-scoring-tool v2
#
# Provides: logging, platform detection, unit conversion, JSON helpers,
#           rating/scoring helpers (0-100 scale), kubectl namespace helpers,
#           and prerequisites checking.
#
# Bash 3.2+ compatible — no associative arrays, no namerefs, no declare -A.
# This file is sourced, not executed directly.
#===============================================================================

#-------------------------------------------------------------------------------
# Logging Functions
# All output goes to stderr so stdout remains clean for report data.
#-------------------------------------------------------------------------------

log_info()    { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Add an entry to the attention log (captured in attention.md)
# Usage: attention_add "CATEGORY" "SEVERITY" "message"
#   CATEGORY: K8s, PostgreSQL, MongoDB, Valkey, RabbitMQ, General
#   SEVERITY: ERROR, WARNING, INFO
attention_add() {
    local category="$1"
    local severity="$2"
    local message="$3"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    ATTENTION_LOG="${ATTENTION_LOG}| ${ts} | ${severity} | ${category} | ${message} |
"
}

#-------------------------------------------------------------------------------
# Platform Detection
#-------------------------------------------------------------------------------

detect_os() {
    case "$(uname -s)" in
        Linux*)
            if grep -qi 'microsoft\|wsl' /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*) echo "macos" ;;
        CYGWIN*) echo "windows" ;;
        MINGW*)  echo "windows" ;;
        MSYS*)   echo "windows" ;;
        FreeBSD*) echo "freebsd" ;;
        *) echo "unknown" ;;
    esac
}

detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/alpine-release ]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}

# Initialize at load time
OS_TYPE=$(detect_os)
LINUX_DISTRO=""
if [ "$OS_TYPE" = "linux" ] || [ "$OS_TYPE" = "wsl" ]; then
    LINUX_DISTRO=$(detect_linux_distro)
fi

get_pkg_install_cmd() {
    case "$OS_TYPE" in
        macos)
            if command -v brew &> /dev/null; then
                echo "brew install"
            else
                echo ""
            fi
            ;;
        linux|wsl)
            case "$LINUX_DISTRO" in
                ubuntu|debian|pop|linuxmint|elementary) echo "sudo apt-get install -y" ;;
                fedora) echo "sudo dnf install -y" ;;
                rhel|centos|rocky|almalinux|ol)
                    if command -v dnf &> /dev/null; then
                        echo "sudo dnf install -y"
                    else
                        echo "sudo yum install -y"
                    fi
                    ;;
                alpine) echo "sudo apk add" ;;
                arch|manjaro|endeavouros) echo "sudo pacman -S --noconfirm" ;;
                opensuse*|sles) echo "sudo zypper install -y" ;;
                *) echo "" ;;
            esac
            ;;
        freebsd) echo "sudo pkg install -y" ;;
        *) echo "" ;;
    esac
}

get_psql_package() {
    case "$OS_TYPE" in
        macos) echo "libpq" ;;
        linux|wsl)
            case "$LINUX_DISTRO" in
                ubuntu|debian|pop|linuxmint|elementary) echo "postgresql-client" ;;
                fedora|rhel|centos|rocky|almalinux|ol) echo "postgresql" ;;
                alpine) echo "postgresql-client" ;;
                arch|manjaro|endeavouros) echo "postgresql-libs" ;;
                opensuse*|sles) echo "postgresql" ;;
                *) echo "postgresql-client" ;;
            esac
            ;;
        freebsd) echo "postgresql16-client" ;;
        *) echo "postgresql-client" ;;
    esac
}

get_mongosh_package() {
    case "$OS_TYPE" in
        macos) echo "mongosh" ;;
        linux|wsl)
            case "$LINUX_DISTRO" in
                ubuntu|debian|pop|linuxmint|elementary) echo "mongodb-mongosh" ;;
                fedora|rhel|centos|rocky|almalinux|ol) echo "mongodb-mongosh" ;;
                alpine) echo "mongosh" ;;
                arch|manjaro|endeavouros) echo "mongosh-bin" ;;
                *) echo "mongosh" ;;
            esac
            ;;
        *) echo "mongosh" ;;
    esac
}

get_redis_package() {
    case "$OS_TYPE" in
        macos) echo "redis" ;;
        linux|wsl)
            case "$LINUX_DISTRO" in
                ubuntu|debian|pop|linuxmint|elementary) echo "redis-tools" ;;
                fedora|rhel|centos|rocky|almalinux|ol) echo "redis" ;;
                alpine) echo "redis" ;;
                arch|manjaro|endeavouros) echo "redis" ;;
                opensuse*|sles) echo "redis" ;;
                *) echo "redis-tools" ;;
            esac
            ;;
        freebsd) echo "redis" ;;
        *) echo "redis-tools" ;;
    esac
}

get_curl_package() {
    echo "curl"
}

install_db_tool() {
    local tool_name="$1"
    local package_name="$2"
    local pkg_cmd
    pkg_cmd=$(get_pkg_install_cmd)

    if [ -z "$pkg_cmd" ]; then
        log_warning "Cannot auto-install on this system - please install $package_name manually"
        return 1
    fi

    log_info "Installing $tool_name ($package_name)..."

    # Special handling for mongosh on Debian/Ubuntu - use npm or MongoDB repo
    if [ "$tool_name" = "mongosh" ] && { [ "$OS_TYPE" = "linux" ] || [ "$OS_TYPE" = "wsl" ]; } && [[ "$LINUX_DISTRO" =~ ^(ubuntu|debian|pop|linuxmint|elementary)$ ]]; then
        if command -v npm &> /dev/null; then
            if npm install -g mongosh 2>/dev/null; then
                log_success "Installed mongosh via npm"
                return 0
            fi
        fi
        log_warning "For mongosh on Debian/Ubuntu, see: https://www.mongodb.com/docs/mongodb-shell/install/"
        return 1
    fi

    # Special handling for libpq on macOS - brew install doesn't add to PATH
    if [ "$tool_name" = "psql" ] && [ "$OS_TYPE" = "macos" ]; then
        if $pkg_cmd "$package_name" 2>/dev/null; then
            local libpq_bin=""
            if [ -d "/opt/homebrew/opt/libpq/bin" ]; then
                libpq_bin="/opt/homebrew/opt/libpq/bin"
            elif [ -d "/usr/local/opt/libpq/bin" ]; then
                libpq_bin="/usr/local/opt/libpq/bin"
            fi
            if [ -n "$libpq_bin" ] && [ -x "$libpq_bin/psql" ]; then
                export PATH="$libpq_bin:$PATH"
                log_success "Installed $tool_name (added $libpq_bin to PATH)"
                return 0
            fi
        fi
        log_error "Failed to install $tool_name"
        return 1
    fi

    if $pkg_cmd "$package_name" 2>/dev/null; then
        log_success "Installed $tool_name"
        return 0
    else
        log_error "Failed to install $tool_name"
        return 1
    fi
}

is_running_inside_container() {
    if [[ -f /.dockerenv ]]; then
        return 0
    fi
    if [[ -f /proc/1/cgroup ]] && grep -q 'docker\|lxc\|kubepods\|containerd' /proc/1/cgroup 2>/dev/null; then
        return 0
    fi
    if [[ -n "${container:-}" ]] || [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]]; then
        return 0
    fi
    return 1
}

resolve_host_for_local() {
    local host="$1"
    case "$host" in
        host.docker.internal|host.k3d.internal)
            if is_running_inside_container; then
                echo "$host"
            else
                echo "127.0.0.1"
            fi
            ;;
        *.svc.cluster.local|*.midaz.svc.cluster.local)
            if is_running_inside_container; then
                echo "$host"
            else
                echo "127.0.0.1"
            fi
            ;;
        localhost)
            echo "127.0.0.1"
            ;;
        *)
            echo "$host"
            ;;
    esac
}

build_connection_hosts() {
    local original_host="$1"
    local resolved_host="$2"
    local result="$resolved_host"

    if [ "$original_host" != "$resolved_host" ]; then
        result="$result $original_host"
    fi

    local add_local=false
    if [[ "$original_host" == "host.docker.internal" ]] || \
       [[ "$original_host" == "host.k3d.internal" ]] || \
       [[ "$original_host" == *".svc.cluster.local"* ]] || \
       [[ "$resolved_host" != "$original_host" ]]; then
        add_local=true
    fi

    if [ "$add_local" = true ]; then
        [[ " $result " != *" 127.0.0.1 "* ]] && result="$result 127.0.0.1"
        [[ " $result " != *" localhost "* ]] && result="$result localhost"
    fi

    if command -v docker &>/dev/null; then
        local docker_gw
        docker_gw=$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || echo "")
        if [ -n "$docker_gw" ] && [[ " $result " != *" $docker_gw "* ]]; then
            result="$result $docker_gw"
        fi
    fi

    echo "$result"
}

#-------------------------------------------------------------------------------
# Unit Conversion Functions
#-------------------------------------------------------------------------------

convert_to_bytes() {
    local value=$1
    if [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "0"
        return
    fi
    local number=$(echo "$value" | sed 's/[^0-9.]//g')
    if [ -z "$number" ]; then
        echo "0"
        return
    fi
    local unit=$(echo "$value" | sed 's/[0-9.]//g')

    case "$unit" in
        Ki) echo "$number * 1024" | bc 2>/dev/null || echo "0" ;;
        Mi) echo "$number * 1024 * 1024" | bc 2>/dev/null || echo "0" ;;
        Gi) echo "$number * 1024 * 1024 * 1024" | bc 2>/dev/null || echo "0" ;;
        Ti) echo "$number * 1024 * 1024 * 1024 * 1024" | bc 2>/dev/null || echo "0" ;;
        K)  echo "$number * 1000" | bc 2>/dev/null || echo "0" ;;
        M)  echo "$number * 1000000" | bc 2>/dev/null || echo "0" ;;
        G)  echo "$number * 1000000000" | bc 2>/dev/null || echo "0" ;;
        T)  echo "$number * 1000000000000" | bc 2>/dev/null || echo "0" ;;
        *)  echo "${number:-0}" ;;
    esac
}

convert_cpu_to_millicores() {
    local value=$1
    if [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "0"
        return
    fi

    if [[ "$value" == *"m" ]]; then
        local result="${value%m}"
        echo "${result:-0}"
    elif [[ "$value" == *"n" ]]; then
        local result=$(echo "scale=0; ${value%n} / 1000000" | bc 2>/dev/null || echo "0")
        echo "${result:-0}"
    else
        local result=$(echo "scale=0; $value * 1000" | bc 2>/dev/null || echo "0")
        echo "${result:-0}"
    fi
}

# Trim leading/trailing whitespace — safe replacement for 'echo "$val" | xargs'
# xargs fails on unbalanced quotes in k8s resource names/values
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

format_bytes() {
    local bytes=$1
    if [ -z "$bytes" ] || [ "$bytes" = "0" ]; then
        echo "0 B"
        return
    fi
    if (( $(echo "$bytes >= 1099511627776" | bc -l) )); then
        printf "%.2f Ti\n" "$(echo "scale=2; $bytes / 1099511627776" | bc)"
    elif (( $(echo "$bytes >= 1073741824" | bc -l) )); then
        printf "%.2f Gi\n" "$(echo "scale=2; $bytes / 1073741824" | bc)"
    elif (( $(echo "$bytes >= 1048576" | bc -l) )); then
        printf "%.2f Mi\n" "$(echo "scale=2; $bytes / 1048576" | bc)"
    elif (( $(echo "$bytes >= 1024" | bc -l) )); then
        printf "%.2f Ki\n" "$(echo "scale=2; $bytes / 1024" | bc)"
    else
        echo "${bytes} B"
    fi
}

#-------------------------------------------------------------------------------
# JSON Helper Functions
#-------------------------------------------------------------------------------

json_val() {
    local data="$1"
    local field="$2"
    local default="${3:-0}"
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$data" ]; then
        echo "$data" | jq -r "
            .$field // $default
            | if type == \"object\" and has(\"low\") then .low // 0
              elif type == \"object\" then $default
              else .
              end
        " 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# Extract a field value from redis INFO output
# Usage: redis_info_val <key> [default]
redis_info_val() {
    local key="$1"
    local default="${2:-0}"
    if [ -n "$VALKEY_RAW_DATA" ]; then
        local val
        val=$(echo "$VALKEY_RAW_DATA" | grep "^${key}:" | cut -d: -f2 | tr -d '\r' || echo "")
        if [ -n "$val" ]; then echo "$val"; else echo "$default"; fi
    else
        echo "$default"
    fi
}

#-------------------------------------------------------------------------------
# Rating / Scoring Helpers (v2: 0-100 scale)
#-------------------------------------------------------------------------------

get_rating_text() {
    local score=$1
    local score_int=$(printf "%.0f" "$score" 2>/dev/null || echo "0")
    if [ "$score_int" -ge 90 ]; then lang_get "rating_excellent"
    elif [ "$score_int" -ge 75 ]; then lang_get "rating_good"
    elif [ "$score_int" -ge 60 ]; then lang_get "rating_fair"
    elif [ "$score_int" -ge 40 ]; then lang_get "rating_poor"
    else lang_get "rating_critical"
    fi
}

get_rating_emoji() {
    local score=$1
    local score_int=$(printf "%.0f" "$score" 2>/dev/null || echo "0")
    if [ "$score_int" -ge 90 ]; then echo "🟢"
    elif [ "$score_int" -ge 75 ]; then echo "🔵"
    elif [ "$score_int" -ge 60 ]; then echo "🟡"
    elif [ "$score_int" -ge 40 ]; then echo "🟠"
    else echo "🔴"
    fi
}

get_rating_bar() {
    local score=$1
    local score_int=$(printf "%.0f" "$score" 2>/dev/null || echo "0")
    local filled=$((score_int / 5))  # 20 blocks for 0-100
    if [ "$filled" -gt 20 ]; then filled=20; fi
    if [ "$filled" -lt 0 ]; then filled=0; fi
    local empty=$((20 - filled))
    local bar="["
    local i=0
    while [ "$i" -lt "$filled" ]; do bar+="█"; i=$((i+1)); done
    i=0
    while [ "$i" -lt "$empty" ]; do bar+="░"; i=$((i+1)); done
    bar+="]"
    echo "$bar"
}

#-------------------------------------------------------------------------------
# kubectl Namespace Helpers
#-------------------------------------------------------------------------------

# Run a kubectl JSON query across all target namespaces and merge .items arrays
# Usage: kubectl_ns_json <resource> [extra-args...]
# Returns a single JSON object with merged .items array
kubectl_ns_json() {
    local resource="$1"
    shift

    if [ "$TARGET_NAMESPACES" = "all" ]; then
        kubectl get "$resource" --all-namespaces -o json "$@" 2>/dev/null || echo '{"items":[]}'
        return
    fi

    local merged_items="[]"
    local IFS_BAK="$IFS"
    IFS=';'
    for ns in $TARGET_NAMESPACES; do
        ns=$(trim "$ns")
        if [ -z "$ns" ]; then continue; fi
        local result
        result=$(kubectl get "$resource" -n "$ns" -o json "$@" 2>/dev/null || echo '{"items":[]}')
        if [ "$JQ_AVAILABLE" = "true" ]; then
            merged_items=$(echo "$merged_items" "$result" | jq -s '.[0] + (.[1].items // [])' 2>/dev/null || echo "$merged_items")
        else
            # Fallback: just use the last namespace result
            merged_items=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('items',[])))" 2>/dev/null || echo "[]")
        fi
    done
    IFS="$IFS_BAK"

    echo "{\"items\": $merged_items}"
}

# Run kubectl top pods across target namespaces and merge line output
# Usage: kubectl_ns_top_pods
kubectl_ns_top_pods() {
    if [ "$TARGET_NAMESPACES" = "all" ]; then
        kubectl top pods --all-namespaces --no-headers 2>/dev/null || echo ""
        return
    fi

    local IFS_BAK="$IFS"
    IFS=';'
    for ns in $TARGET_NAMESPACES; do
        ns=$(trim "$ns")
        if [ -z "$ns" ]; then continue; fi
        # Prepend namespace column to match --all-namespaces format (NS NAME CPU MEM)
        kubectl top pods -n "$ns" --no-headers 2>/dev/null | while read -r line; do
            echo "$ns $line"
        done || true
    done
    IFS="$IFS_BAK"
}

# Run kubectl get events across target namespaces and merge JSON
# Usage: kubectl_ns_events
kubectl_ns_events() {
    if [ "$TARGET_NAMESPACES" = "all" ]; then
        kubectl get events --all-namespaces --sort-by='.lastTimestamp' -o json 2>/dev/null || echo '{"items":[]}'
        return
    fi

    local merged_items="[]"
    local IFS_BAK="$IFS"
    IFS=';'
    for ns in $TARGET_NAMESPACES; do
        ns=$(trim "$ns")
        if [ -z "$ns" ]; then continue; fi
        local result
        result=$(kubectl get events -n "$ns" --sort-by='.lastTimestamp' -o json 2>/dev/null || echo '{"items":[]}')
        if [ "$JQ_AVAILABLE" = "true" ]; then
            merged_items=$(echo "$merged_items" "$result" | jq -s '.[0] + (.[1].items // [])' 2>/dev/null || echo "$merged_items")
        fi
    done
    IFS="$IFS_BAK"
    echo "{\"items\": $merged_items}"
}

#-------------------------------------------------------------------------------
# Prerequisites Check
#-------------------------------------------------------------------------------

check_prerequisites() {
    log_info "Checking prerequisites..."

    # On macOS, add common Homebrew keg-only paths if they exist
    if [ "$OS_TYPE" = "macos" ]; then
        for keg_bin in /opt/homebrew/opt/libpq/bin /usr/local/opt/libpq/bin; do
            if [ -d "$keg_bin" ] && [[ ":$PATH:" != *":$keg_bin:"* ]]; then
                export PATH="$keg_bin:$PATH"
            fi
        done
    fi

    # Check if kubectl is installed (required unless --external-dbs-only)
    if ! command -v kubectl &> /dev/null; then
        if [ "$SKIP_K8S_COLLECTION" = true ]; then
            log_warning "kubectl is not installed - K8s metrics will be unavailable"
        else
            log_error "kubectl is not installed or not in PATH"
            exit 1
        fi
    else
        # Check if kubectl can connect to cluster
        if ! kubectl cluster-info &> /dev/null; then
            if [ "$SKIP_K8S_COLLECTION" = true ]; then
                log_warning "Cannot connect to Kubernetes cluster - K8s metrics unavailable"
            else
                log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
                exit 1
            fi
        fi

        # Check if metrics-server is available
        if ! kubectl top nodes &> /dev/null 2>&1; then
            log_warning "metrics-server may not be installed. Real-time usage metrics will be unavailable."
            METRICS_AVAILABLE=false
        else
            METRICS_AVAILABLE=true
        fi
    fi

    # Check bc (calculator) — attempt install if missing
    if command -v bc &> /dev/null; then
        BC_AVAILABLE=true
    else
        log_warning "bc not available - attempting auto-install..."
        local bc_pkg="bc"
        install_db_tool "bc" "$bc_pkg" && BC_AVAILABLE=true || {
            log_warning "bc not available - using basic arithmetic"
        }
    fi

    # Check jq — attempt install if missing (critical for JSON parsing)
    if command -v jq &> /dev/null; then
        JQ_AVAILABLE=true
    else
        log_warning "jq not available - attempting auto-install..."
        install_db_tool "jq" "jq" && JQ_AVAILABLE=true || {
            log_warning "jq not available - some JSON parsing will be limited"
        }
    fi

    # Check curl
    if command -v curl &> /dev/null; then
        CURL_AVAILABLE=true
    else
        log_warning "curl not available - RabbitMQ checks will be skipped"
        if [ "$COLLECT_EXTERNAL_DBS" = "true" ]; then
            install_db_tool "curl" "$(get_curl_package)" && CURL_AVAILABLE=true || true
        fi
    fi

    # Check psql
    if command -v psql &> /dev/null; then
        PSQL_AVAILABLE=true
    else
        if [ "$COLLECT_EXTERNAL_DBS" = "true" ]; then
            log_info "psql not found - attempting auto-install..."
            install_db_tool "psql" "$(get_psql_package)" && PSQL_AVAILABLE=true || true
        fi
    fi

    # Check mongosh/mongo
    if command -v mongosh &> /dev/null; then
        MONGO_AVAILABLE=true
        MONGO_CMD="mongosh"
    elif command -v mongo &> /dev/null; then
        MONGO_AVAILABLE=true
        MONGO_CMD="mongo"
    else
        if [ "$COLLECT_EXTERNAL_DBS" = "true" ]; then
            log_info "mongosh not found - attempting auto-install..."
            install_db_tool "mongosh" "$(get_mongosh_package)" && {
                MONGO_AVAILABLE=true
                MONGO_CMD="mongosh"
            } || true
        fi
    fi

    # Check redis-cli
    if command -v redis-cli &> /dev/null; then
        REDIS_CLI_AVAILABLE=true
        # Detect timeout flag: redis-cli 8+ uses -t, older uses --connect-timeout
        if redis-cli -t 1 -h 127.0.0.1 -p 0 PING &>/dev/null 2>&1 || redis-cli --help 2>&1 | grep -q '^\s*-t <timeout>'; then
            REDIS_TIMEOUT_FLAG="-t"
        else
            REDIS_TIMEOUT_FLAG="--connect-timeout"
        fi
    else
        if [ "$COLLECT_EXTERNAL_DBS" = "true" ]; then
            log_info "redis-cli not found - attempting auto-install..."
            install_db_tool "redis-cli" "$(get_redis_package)" && {
                REDIS_CLI_AVAILABLE=true
                if redis-cli --help 2>&1 | grep -q '^\s*-t <timeout>'; then
                    REDIS_TIMEOUT_FLAG="-t"
                else
                    REDIS_TIMEOUT_FLAG="--connect-timeout"
                fi
            } || true
        fi
    fi
    REDIS_TIMEOUT_FLAG="${REDIS_TIMEOUT_FLAG:-"--connect-timeout"}"

    log_success "Prerequisites check completed"
}
