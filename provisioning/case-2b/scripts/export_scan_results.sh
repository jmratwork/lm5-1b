#!/usr/bin/env bash
# Export Nmap scan results and Gitea report metadata for PUC2-Sub Case 2b.
# Usage: GITEA_TOKEN=<token> ./export_scan_results.sh [output_dir]
#
# Requires: curl, jq
# Environment variables:
#   GITEA_TOKEN   - Gitea API token (admin or instructor account)
#   GITEA_URL     - Gitea base URL (default: http://report-repo.internal:3000)
#   GITEA_ORG     - Gitea organisation name (default: cyberrange-2b)

set -euo pipefail

GITEA_URL="${GITEA_URL:-http://report-repo.internal:3000}"
GITEA_ORG="${GITEA_ORG:-cyberrange-2b}"
OUTPUT_DIR="${1:-/tmp/scan-export-$(date +%Y%m%d-%H%M%S)}"

if [[ -z "${GITEA_TOKEN:-}" ]]; then
  echo "ERROR: GITEA_TOKEN environment variable is required." >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "[*] Exporting trainee report metadata from ${GITEA_URL}/api/v1/orgs/${GITEA_ORG}/repos ..."

curl -s \
  -H "Authorization: token ${GITEA_TOKEN}" \
  "${GITEA_URL}/api/v1/orgs/${GITEA_ORG}/repos?limit=50" \
  | jq '[.[] | {
      repo:         .name,
      trainee:      .owner.login,
      stars:        .stars_count,
      open_issues:  .open_issues_count,
      last_push:    .updated,
      clone_url:    .clone_url
    }]' \
  > "${OUTPUT_DIR}/trainee-repos.json"

echo "[+] Trainee repos saved: ${OUTPUT_DIR}/trainee-repos.json"

REPO_COUNT=$(jq 'length' "${OUTPUT_DIR}/trainee-repos.json")
echo "[*] Found ${REPO_COUNT} trainee repositories."

# Fetch open issues (instructor feedback) per repo
echo "[*] Fetching instructor feedback issues ..."

jq -r '.[].repo' "${OUTPUT_DIR}/trainee-repos.json" | while read -r REPO; do
  curl -s \
    -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_URL}/api/v1/repos/${GITEA_ORG}/${REPO}/issues?type=issues&state=open&limit=50" \
    | jq --arg repo "${REPO}" '[.[] | {repo: $repo, issue_id: .number, title: .title, state: .state, created: .created_at}]' \
    >> "${OUTPUT_DIR}/feedback-issues.json"
done

echo "[+] Feedback issues saved: ${OUTPUT_DIR}/feedback-issues.json"

# Generate summary JSON
echo "[*] Generating cohort summary ..."

jq -n \
  --arg export_ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg org "${GITEA_ORG}" \
  --argjson repos "$(cat "${OUTPUT_DIR}/trainee-repos.json")" \
  '{
    export_timestamp: $export_ts,
    organisation: $org,
    cohort_size: ($repos | length),
    reports_submitted: ($repos | map(select(.last_push != null)) | length),
    repositories: $repos
  }' \
  > "${OUTPUT_DIR}/cohort-summary.json"

echo "[+] Cohort summary saved: ${OUTPUT_DIR}/cohort-summary.json"
echo ""
echo "Export complete. Files in: ${OUTPUT_DIR}/"
ls -lh "${OUTPUT_DIR}/"
