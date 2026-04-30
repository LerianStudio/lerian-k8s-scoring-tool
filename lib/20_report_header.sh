#!/bin/bash
# Report Header — ASCII art banner, YAML frontmatter, and Executive Summary
# Bash 3.2+ compatible (no associative arrays)
#
# Depends on: 02_i18n.sh, 01_util.sh (get_rating_text, get_rating_emoji, get_rating_bar)

report_header() {
    local report_start_time="${1:-$(date '+%Y-%m-%d %H:%M:%S %z')}"

    # YAML Frontmatter
    cat << EOF
---
title: $(lang_get "report_title")
generated: $(date '+%Y-%m-%dT%H:%M:%S%z')
cluster: $CLUSTER_NAME
kubernetes_version: $K8S_VERSION
target_namespaces: $TARGET_NAMESPACES
report_type: comprehensive_metrics
language: $CURRENT_LANG
---

EOF

    # ASCII Art Banner
    cat << 'BANNER'
```ascii
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    ██╗  ██╗██╗   ██╗██████╗ ███████╗██████╗ ███╗   ██╗       ║
║    ██║ ██╔╝██║   ██║██╔══██╗██╔════╝██╔══██╗████╗  ██║       ║
║    █████╔╝ ██║   ██║██████╔╝█████╗  ██████╔╝██╔██╗ ██║       ║
║    ██╔═██╗ ██║   ██║██╔══██╗██╔══╝  ██╔══██╗██║╚██╗██║       ║
║    ██║  ██╗╚██████╔╝██████╔╝███████╗██║  ██║██║ ╚████║       ║
║    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝       ║
║                                                              ║
BANNER

    # Subtitle — translated and uppercased
    local subtitle
    subtitle=$(lang_get "report_title" | tr '[:lower:]' '[:upper:]')
    printf '║    %-58s║\n' "$subtitle"
    cat << 'BANNER'
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```
BANNER
    echo ""

    # Main title
    echo "# $(lang_get 'report_title')"
    echo ""

    # Status line
    local status_text="HEALTHY"
    if [ "${K8S_SCORE_OVERALL:-0}" -lt 40 ]; then
        status_text="CRITICAL"
    elif [ "${K8S_SCORE_OVERALL:-0}" -lt 60 ]; then
        status_text="NEEDS ATTENTION"
    elif [ "${K8S_SCORE_OVERALL:-0}" -lt 75 ]; then
        status_text="HEALTHY WITH WARNINGS"
    fi

    echo "> **Status:** \`$status_text\` | **Report ID:** \`k8s-metrics-$(date '+%Y%m%d-%H%M%S')\`"
    echo ""
    echo "---"
    echo ""

    # Executive Summary
    local overall_rating
    local overall_emoji
    overall_rating=$(get_rating_text "${K8S_SCORE_OVERALL:-0}")
    overall_emoji=$(get_rating_emoji "${K8S_SCORE_OVERALL:-0}")

    echo "## $(lang_get 'exec_summary')"
    echo ""
    echo "| $(lang_get 'th_metric') | $(lang_get 'th_value') | $(lang_get 'th_status') |"
    echo "|:-------|:------|:-------|"
    echo "| **Overall Health Score** | \`${K8S_SCORE_OVERALL:-0}/100\` | $overall_emoji $overall_rating |"
    echo "| **Cluster Context** | \`${CLUSTER_NAME:-unknown}\` | Active |"
    echo "| **Kubernetes Version** | \`${K8S_VERSION:-unknown}\` | |"
    echo "| **API Server** | \`${CLUSTER_SERVER:-unknown}\` | Reachable |"
    echo "| **Total Nodes** | \`${NODE_COUNT:-0}\` | Operational |"
    echo "| **Report Generated** | \`$(date '+%Y-%m-%d %H:%M:%S %z')\` | |"
    echo "| **Target Namespaces** | \`${TARGET_NAMESPACES:-all}\` | |"
    echo ""
    echo "> $(lang_get 'pro_tip_report')"
    echo ""
    echo "---"
    echo ""
}

report_health_dashboard() {
    echo "## $(lang_get 'health_dashboard')"
    echo ""
    echo "### $(lang_get 'overall_health')"
    echo ""
    echo "| Overall Score | $(lang_get 'th_rating') | $(lang_get 'th_status') |"
    echo "|:--------------|:-------|:-------|"
    echo "| **${K8S_SCORE_OVERALL:-0} / 100** | **$(get_rating_text "${K8S_SCORE_OVERALL:-0}")** | $(get_rating_bar "${K8S_SCORE_OVERALL:-0}") $(get_rating_emoji "${K8S_SCORE_OVERALL:-0}") |"
    echo ""
    echo "### $(lang_get 'category_breakdown')"
    echo ""
    echo "> $(lang_get 'scoring_methodology_text')"
    echo ""
    echo "| $(lang_get 'th_category') | $(lang_get 'th_score') | $(lang_get 'th_weight') | $(lang_get 'th_rating') | $(lang_get 'th_status') |"
    echo "|:---------|:------|:-------|:-------|:-------|"

    # Helper to print a single dashboard row
    _dashboard_row() {
        local name="$1" score="$2" weight="$3"
        echo "| $name | ${score}/100 | ${weight}% | $(get_rating_text "$score") | $(get_rating_bar "$score") $(get_rating_emoji "$score") |"
    }

    _dashboard_row "$(lang_get 'cat_nodes')"      "${K8S_SCORE_NODES:-0}"      "${K8S_WEIGHT_NODES:-15}"
    _dashboard_row "$(lang_get 'cat_workloads')"   "${K8S_SCORE_WORKLOADS:-0}"  "${K8S_WEIGHT_WORKLOADS:-20}"
    _dashboard_row "$(lang_get 'cat_resources')"   "${K8S_SCORE_RESOURCES:-0}"  "${K8S_WEIGHT_RESOURCES:-15}"
    _dashboard_row "$(lang_get 'cat_security')"    "${K8S_SCORE_SECURITY:-0}"   "${K8S_WEIGHT_SECURITY:-15}"
    _dashboard_row "$(lang_get 'cat_storage')"     "${K8S_SCORE_STORAGE:-0}"    "${K8S_WEIGHT_STORAGE:-10}"
    _dashboard_row "$(lang_get 'cat_events')"      "${K8S_SCORE_EVENTS:-0}"     "${K8S_WEIGHT_EVENTS:-10}"
    _dashboard_row "$(lang_get 'cat_networking')"   "${K8S_SCORE_NETWORKING:-0}" "${K8S_WEIGHT_NETWORKING:-10}"
    _dashboard_row "$(lang_get 'cat_config')"      "${K8S_SCORE_CONFIG:-0}"     "${K8S_WEIGHT_CONFIG:-5}"

    echo ""
    echo "**$(lang_get 'score_interpretation'):**"
    lang_get_block "score_interpretation"
    echo ""
    echo "---"
    echo ""
}
