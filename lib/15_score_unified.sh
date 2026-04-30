#!/bin/bash
# =============================================================================
# 15_score_unified.sh - Grand Unified Infrastructure Score
# =============================================================================
# Aggregates all domain scores (K8s, PG, Mongo, Valkey, RMQ) into a single
# composite score. Handles absent domains by redistributing weight.
#
# Formula: Grand Score = Σ (Domain Score × Domain Weight)
# Critical Override: If any domain < 40, cap at 59
#
# Default weights (from 00_constants.sh):
#   K8s 30%, PG 25%, Mongo 20%, Valkey 15%, RMQ 10%
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

# -----------------------------------------------------------------------------
# Result variables
# -----------------------------------------------------------------------------
UNIFIED_SCORE=0
UNIFIED_RATING_TEXT=""
UNIFIED_RATING_EMOJI=""

# -----------------------------------------------------------------------------
# _domain_present DOMAIN_KEY
#   Returns 0 (true) if the domain produced a valid score, 1 otherwise.
#   Checks both score > 0 AND the relevant connection/collection status.
#
#   Accepted keys: k8s, pg, mongo, valkey, rmq
# -----------------------------------------------------------------------------
_domain_present() {
    local domain="$1"
    case "$domain" in
        k8s)
            # K8s is present if the overall score was set (collection ran)
            [ "${K8S_SCORE_OVERALL:-0}" -gt 0 ] 2>/dev/null && return 0
            ;;
        pg)
            [ "${PG_SCORE:-0}" -gt 0 ] 2>/dev/null \
                && [ "${EXTERNAL_PG_STATUS:-}" = "connected" ] \
                && return 0
            ;;
        mongo)
            [ "${MONGO_SCORE:-0}" -gt 0 ] 2>/dev/null \
                && [ "${EXTERNAL_MONGO_STATUS:-}" = "connected" ] \
                && return 0
            ;;
        valkey)
            [ "${VALKEY_SCORE:-0}" -gt 0 ] 2>/dev/null \
                && [ "${EXTERNAL_REDIS_STATUS:-}" = "connected" ] \
                && return 0
            ;;
        rmq)
            [ "${RMQ_SCORE:-0}" -gt 0 ] 2>/dev/null \
                && [ "${EXTERNAL_RABBITMQ_STATUS:-}" = "connected" ] \
                && return 0
            ;;
    esac
    return 1
}

# -----------------------------------------------------------------------------
# compute_unified_score
#   Calculates the Grand Unified Infrastructure Score by:
#     1. Detecting which domains are present
#     2. Summing weighted scores, redistributing weight among present domains
#     3. Applying the critical-domain override (any domain < 40 => cap at 59)
#     4. Setting UNIFIED_SCORE, UNIFIED_RATING_TEXT, UNIFIED_RATING_EMOJI
# -----------------------------------------------------------------------------
compute_unified_score() {
    log_info "Computing Grand Unified Infrastructure Score..."

    local weighted_sum=0
    local total_weight=0
    local has_critical=0
    local breakdown=""

    # --- Domain: K8s ---
    if _domain_present k8s; then
        local w="${UNIFIED_WEIGHT_K8S:-30}"
        local s="${K8S_SCORE_OVERALL:-0}"
        weighted_sum=$(( weighted_sum + s * w ))
        total_weight=$(( total_weight + w ))
        if [ "$s" -lt 40 ] 2>/dev/null; then has_critical=1; fi
        breakdown="${breakdown}K8s=${s}(w${w}) "
    fi

    # --- Domain: PostgreSQL ---
    if _domain_present pg; then
        local w="${UNIFIED_WEIGHT_PG:-25}"
        local s="${PG_SCORE:-0}"
        weighted_sum=$(( weighted_sum + s * w ))
        total_weight=$(( total_weight + w ))
        if [ "$s" -lt 40 ] 2>/dev/null; then has_critical=1; fi
        breakdown="${breakdown}PG=${s}(w${w}) "
    fi

    # --- Domain: MongoDB ---
    if _domain_present mongo; then
        local w="${UNIFIED_WEIGHT_MONGO:-20}"
        local s="${MONGO_SCORE:-0}"
        weighted_sum=$(( weighted_sum + s * w ))
        total_weight=$(( total_weight + w ))
        if [ "$s" -lt 40 ] 2>/dev/null; then has_critical=1; fi
        breakdown="${breakdown}Mongo=${s}(w${w}) "
    fi

    # --- Domain: Valkey ---
    if _domain_present valkey; then
        local w="${UNIFIED_WEIGHT_VALKEY:-15}"
        local s="${VALKEY_SCORE:-0}"
        weighted_sum=$(( weighted_sum + s * w ))
        total_weight=$(( total_weight + w ))
        if [ "$s" -lt 40 ] 2>/dev/null; then has_critical=1; fi
        breakdown="${breakdown}Valkey=${s}(w${w}) "
    fi

    # --- Domain: RabbitMQ ---
    if _domain_present rmq; then
        local w="${UNIFIED_WEIGHT_RMQ:-10}"
        local s="${RMQ_SCORE:-0}"
        weighted_sum=$(( weighted_sum + s * w ))
        total_weight=$(( total_weight + w ))
        if [ "$s" -lt 40 ] 2>/dev/null; then has_critical=1; fi
        breakdown="${breakdown}RMQ=${s}(w${w}) "
    fi

    # --- Calculate unified score ---
    if [ "$total_weight" -gt 0 ] 2>/dev/null; then
        UNIFIED_SCORE=$(_bc_int "$weighted_sum / $total_weight")
        UNIFIED_SCORE=$(_clamp "$UNIFIED_SCORE")
    else
        UNIFIED_SCORE=0
        log_warning "No domains available for unified scoring"
    fi

    # --- Critical domain override ---
    if [ "$has_critical" -eq 1 ] && [ "$UNIFIED_SCORE" -gt 59 ] 2>/dev/null; then
        log_warning "Critical domain override: at least one domain scored < 40 — capping unified at 59"
        UNIFIED_SCORE=59
    fi

    # --- Rating ---
    UNIFIED_RATING_TEXT=$(get_rating_text "$UNIFIED_SCORE")
    UNIFIED_RATING_EMOJI=$(get_rating_emoji "$UNIFIED_SCORE")

    # --- Log ---
    log_success "Grand Unified Score: ${UNIFIED_SCORE}/100 (${UNIFIED_RATING_TEXT}) — ${breakdown:-no domains}"
}
