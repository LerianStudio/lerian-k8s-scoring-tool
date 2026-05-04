#!/bin/bash
set -e

# --- Bash 3.2+ check (macOS compat) ---
if ((BASH_VERSINFO[0] < 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2))); then
    echo "Error: Bash 3.2+ required. Current: ${BASH_VERSION}"
    exit 1
fi

REPO_OWNER="LerianStudio"
REPO_NAME="lerian-k8s-scoring-tool"
REPO_BRANCH="main"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
TARBALL_URL="${REPO_URL}/archive/refs/heads/${REPO_BRANCH}.tar.gz"
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/commits/${REPO_BRANCH}"
CRON_MARKER="# lerian-scoring-tool"

echo "================================================"
echo "  Lerian Infrastructure Scoring Tool Installer"
echo "================================================"
echo ""

# --- Check prerequisites ---
echo "Checking prerequisites..."
MISSING=""
for cmd in curl jq bc kubectl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING="${MISSING} ${cmd}"
    fi
done

if [ -n "$MISSING" ]; then
    echo "Error: Missing required tools:${MISSING}"
    echo ""
    echo "Install them before running this installer:"
    echo "  macOS:  brew install${MISSING}"
    echo "  Debian: sudo apt install${MISSING}"
    echo "  RHEL:   sudo dnf install${MISSING}"
    exit 1
fi
echo "  All prerequisites found."
echo ""

# --- Prompt for customer name ---
printf "Enter customer name (e.g. Lerian Studio): "
read -r CUSTOMER_NAME

if [ -z "$CUSTOMER_NAME" ]; then
    echo "Error: Customer name cannot be empty."
    exit 1
fi

CUSTOMER_SLUG=$(echo "$CUSTOMER_NAME" | sed 's/ /-/g')
echo "  Customer: ${CUSTOMER_NAME} (slug: ${CUSTOMER_SLUG})"
echo ""

# --- Detect OS and set install directory ---
case "$(uname -s)" in
    Darwin*)
        INSTALL_DIR="/usr/local/share/lerian-scoring"
        OS_TYPE="macOS"
        ;;
    Linux*)
        INSTALL_DIR="/opt/lerian-scoring"
        OS_TYPE="Linux"
        ;;
    *)
        echo "Error: Unsupported OS: $(uname -s)"
        exit 1
        ;;
esac

echo "Detected ${OS_TYPE}. Install directory: ${INSTALL_DIR}"
echo ""

# --- Create install directory ---
if [ -d "$INSTALL_DIR" ]; then
    echo "Existing installation found at ${INSTALL_DIR}"
    printf "Overwrite? (Y/n): "
    read -r OVERWRITE
    if [ "$OVERWRITE" = "n" ] || [ "$OVERWRITE" = "N" ]; then
        echo "Aborted."
        exit 0
    fi
fi

if [ ! -w "$(dirname "$INSTALL_DIR")" ]; then
    echo "Need elevated permissions to write to ${INSTALL_DIR}"
    sudo mkdir -p "${INSTALL_DIR}/lib" "${INSTALL_DIR}/logs"
    sudo chown -R "$(id -u):$(id -g)" "$INSTALL_DIR"
else
    mkdir -p "${INSTALL_DIR}/lib" "${INSTALL_DIR}/logs"
fi

# --- Get current commit SHA ---
echo "Fetching latest version info..."
CURRENT_SHA=$(curl -fsSL --connect-timeout 10 --max-time 30 "$API_URL" | jq -r '.sha')

if [ -z "$CURRENT_SHA" ] || [ "$CURRENT_SHA" = "null" ]; then
    echo "Error: Could not fetch version info from GitHub."
    echo "Check your internet connection and try again."
    exit 1
fi
echo "  Latest commit: ${CURRENT_SHA:0:7}"
echo ""

# --- Download and extract ---
echo "Downloading scoring tool..."
TMPDIR_DL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_DL"' EXIT

curl -fsSL --connect-timeout 10 --max-time 120 "$TARBALL_URL" -o "${TMPDIR_DL}/scoring.tar.gz"

echo "Extracting..."
tar -xzf "${TMPDIR_DL}/scoring.tar.gz" -C "$TMPDIR_DL"

EXTRACTED_DIR="${TMPDIR_DL}/${REPO_NAME}-${REPO_BRANCH}"
if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "Error: Unexpected archive structure."
    exit 1
fi

# --- Copy files to install directory ---
echo "Installing files..."
cp "${EXTRACTED_DIR}/lerian-scoring.sh" "${INSTALL_DIR}/lerian-scoring.sh"
chmod +x "${INSTALL_DIR}/lerian-scoring.sh"

if [ -d "${EXTRACTED_DIR}/lib" ]; then
    rm -rf "${INSTALL_DIR}/lib"
    cp -r "${EXTRACTED_DIR}/lib" "${INSTALL_DIR}/lib"
fi

echo "  Installed lerian-scoring.sh + $(ls "${INSTALL_DIR}/lib/" | wc -l | tr -d ' ') modules"

# --- Write config file ---
cat > "${INSTALL_DIR}/scoring.conf" <<CONF
SCORING_CUSTOMER="${CUSTOMER_SLUG}"
SCORING_REPO="${REPO_OWNER}/${REPO_NAME}"
SCORING_BRANCH="${REPO_BRANCH}"
SCORING_INSTALLED_SHA="${CURRENT_SHA}"
SCORING_INSTALL_DIR="${INSTALL_DIR}"
SCORING_EXTRA_FLAGS=""
CONF

echo "  Config written to ${INSTALL_DIR}/scoring.conf"

# --- Write update script ---
cat > "${INSTALL_DIR}/update-scoring-tool.sh" <<'UPDATER'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/scoring.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Config not found: ${CONF_FILE}"
    exit 1
fi

. "$CONF_FILE"

REPO="${SCORING_REPO}"
BRANCH="${SCORING_BRANCH}"
LOCAL_SHA="${SCORING_INSTALLED_SHA}"
API_URL="https://api.github.com/repos/${REPO}/commits/${BRANCH}"
TARBALL_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

REMOTE_SHA=$(curl -fsSL --connect-timeout 10 --max-time 30 "$API_URL" 2>/dev/null | jq -r '.sha' 2>/dev/null)

if [ -z "$REMOTE_SHA" ] || [ "$REMOTE_SHA" = "null" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: Could not fetch remote SHA. Skipping."
    exit 0
fi

if [ "$REMOTE_SHA" = "$LOCAL_SHA" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] OK: Up to date (${LOCAL_SHA:0:7})"
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] UPDATE: ${LOCAL_SHA:0:7} -> ${REMOTE_SHA:0:7}"

TMPDIR_UPD=$(mktemp -d)
trap 'rm -rf "$TMPDIR_UPD"' EXIT

curl -fsSL --connect-timeout 10 --max-time 120 "$TARBALL_URL" -o "${TMPDIR_UPD}/scoring.tar.gz"
tar -xzf "${TMPDIR_UPD}/scoring.tar.gz" -C "$TMPDIR_UPD"

REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)
EXTRACTED_DIR="${TMPDIR_UPD}/${REPO_NAME}-${BRANCH}"

if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Unexpected archive structure. Aborting."
    exit 1
fi

cp "${EXTRACTED_DIR}/lerian-scoring.sh" "${SCRIPT_DIR}/lerian-scoring.sh"
chmod +x "${SCRIPT_DIR}/lerian-scoring.sh"

if [ -d "${EXTRACTED_DIR}/lib" ]; then
    rm -rf "${SCRIPT_DIR}/lib"
    cp -r "${EXTRACTED_DIR}/lib" "${SCRIPT_DIR}/lib"
fi

sed -i.bak "s|^SCORING_INSTALLED_SHA=.*|SCORING_INSTALLED_SHA=\"${REMOTE_SHA}\"|" "$CONF_FILE"
rm -f "${CONF_FILE}.bak"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] OK: Updated to ${REMOTE_SHA:0:7}"

LOG_FILE="${SCRIPT_DIR}/logs/update.log"
if [ -f "$LOG_FILE" ]; then
    LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')
    if [ "$LINES" -gt 100 ]; then
        tail -100 "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
fi
UPDATER

chmod +x "${INSTALL_DIR}/update-scoring-tool.sh"
echo "  Update script written."

# --- Setup cron jobs ---
echo ""
echo "Configuring cron jobs..."

EXISTING_CRON=$(crontab -l 2>/dev/null || true)

CLEANED_CRON=$(echo "$EXISTING_CRON" | grep -v "lerian-scoring" || true)

NEW_CRON="${CLEANED_CRON}"

if [ -n "$NEW_CRON" ]; then
    NEW_CRON="${NEW_CRON}
"
fi

NEW_CRON="${NEW_CRON}${CRON_MARKER}-update
0 * * * * ${INSTALL_DIR}/update-scoring-tool.sh >> ${INSTALL_DIR}/logs/update.log 2>&1
${CRON_MARKER}-daily-run
0 5 * * * ${INSTALL_DIR}/lerian-scoring.sh --customer \"${CUSTOMER_SLUG}\" ${SCORING_EXTRA_FLAGS} >> ${INSTALL_DIR}/logs/scoring.log 2>&1"

echo "$NEW_CRON" | crontab -

echo "  Hourly auto-update: every hour at :00"
echo "  Daily scoring run:  every day at 5:00 AM"

# --- Done ---
echo ""
echo "================================================"
echo "  Installation Complete!"
echo "================================================"
echo ""
echo "  Install dir:  ${INSTALL_DIR}"
echo "  Customer:     ${CUSTOMER_SLUG}"
echo "  Version:      ${CURRENT_SHA:0:7}"
echo ""
echo "  Files:"
echo "    ${INSTALL_DIR}/lerian-scoring.sh    Main tool"
echo "    ${INSTALL_DIR}/update-scoring-tool.sh   Auto-updater"
echo "    ${INSTALL_DIR}/scoring.conf              Configuration"
echo "    ${INSTALL_DIR}/logs/                     Logs directory"
echo ""
echo "  Cron jobs (crontab -l to verify):"
echo "    Hourly  - Check for updates from GitHub"
echo "    5:00 AM - Run scoring for ${CUSTOMER_SLUG}"
echo ""
echo "  To customize the daily run, edit:"
echo "    ${INSTALL_DIR}/scoring.conf"
echo "    Set SCORING_EXTRA_FLAGS for options like --no-external-dbs"
echo ""
echo "  To uninstall:"
echo "    crontab -l | grep -v lerian-scoring | crontab -"
echo "    rm -rf ${INSTALL_DIR}"
echo ""
