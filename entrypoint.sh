#!/usr/bin/env bash
# Voidly Accessibility Check — composite GitHub Action entrypoint.
#
# Reads inputs from environment, calls the Voidly accessibility batch API
# once per target country, aggregates results, writes a report to
# $GITHUB_STEP_SUMMARY, and emits outputs via $GITHUB_OUTPUT.
#
# Exits 0 by default. Exits 1 only when fail-on-blocked=true AND at least
# one (domain, country) pair returned status=blocked.

set -euo pipefail

# ---------- helpers ----------
log()  { printf '%s\n' "$*" >&2; }
warn() { printf '::warning::%s\n' "$*"; }
fail() { printf '::error::%s\n' "$*"; exit 1; }

# Render an emoji + label for a status. One emoji per row, max.
status_glyph() {
  case "$1" in
    blocked)    printf '%s' "✕ blocked" ;;
    accessible) printf '%s' "✓ accessible" ;;
    unknown)    printf '%s' "? unknown" ;;
    error)      printf '%s' "! error" ;;
    *)          printf '%s' "? $1" ;;
  esac
}

# ---------- input validation ----------
DOMAINS_RAW="${INPUT_DOMAINS:-}"
COUNTRIES_RAW="${INPUT_COUNTRIES:-IR,RU,CN}"
FAIL_ON_BLOCKED="${INPUT_FAIL_ON_BLOCKED:-false}"
REPORT_FORMAT="${INPUT_REPORT_FORMAT:-markdown}"
API_KEY="${INPUT_API_KEY:-}"
API_BASE_URL="${INPUT_API_BASE_URL:-https://api.voidly.ai}"

[ -n "$DOMAINS_RAW" ]   || fail "input 'domains' is required"
[ -n "$COUNTRIES_RAW" ] || fail "input 'countries' is required"

case "$REPORT_FORMAT" in
  markdown|json) ;;
  *) fail "input 'report-format' must be 'markdown' or 'json' (got: $REPORT_FORMAT)" ;;
esac

case "$FAIL_ON_BLOCKED" in
  true|false) ;;
  *) fail "input 'fail-on-blocked' must be 'true' or 'false' (got: $FAIL_ON_BLOCKED)" ;;
esac

# Split CSV into newline-delimited lists, trimming whitespace and empties.
csv_to_lines() {
  printf '%s' "$1" \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' \
    | grep -v '^$' || true
}

mapfile -t DOMAINS   < <(csv_to_lines "$DOMAINS_RAW")
mapfile -t COUNTRIES < <(csv_to_lines "$COUNTRIES_RAW")

[ "${#DOMAINS[@]}"   -gt 0 ] || fail "no valid domains parsed from input"
[ "${#COUNTRIES[@]}" -gt 0 ] || fail "no valid countries parsed from input"

# Lightweight format checks. We don't reject — just warn — so the API
# stays the source of truth on what it accepts.
for d in "${DOMAINS[@]}"; do
  [[ "$d" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || warn "domain '$d' looks unusual; sending anyway"
done
for c in "${COUNTRIES[@]}"; do
  [[ "$c" =~ ^[A-Za-z]{2}$ ]] || warn "country '$c' is not a 2-letter ISO code; sending anyway"
done

if [ "${#DOMAINS[@]}" -gt 50 ]; then
  warn "checking ${#DOMAINS[@]} domains; the API caps batch requests at 50 per call"
fi

log "Voidly Accessibility Check"
log "  domains:   ${#DOMAINS[@]}"
log "  countries: ${#COUNTRIES[@]}"
log "  endpoint:  $API_BASE_URL"

# ---------- build domains JSON array once ----------
DOMAINS_JSON=$(printf '%s\n' "${DOMAINS[@]}" \
  | jq -R . \
  | jq -s .)

# ---------- per-country API calls ----------
RESULTS_FILE=$(mktemp)
trap 'rm -f "$RESULTS_FILE"' EXIT

# Aggregate ndjson: one {domain, country, status, methods, accessibilityScore}
# object per line. We assemble the final report from this.
> "$RESULTS_FILE"

for country in "${COUNTRIES[@]}"; do
  COUNTRY_UPPER=$(printf '%s' "$country" | tr '[:lower:]' '[:upper:]')
  PAYLOAD=$(jq -n \
    --argjson domains "$DOMAINS_JSON" \
    --arg country "$COUNTRY_UPPER" \
    '{domains: $domains, country: $country}')

  log "→ POST /v1/accessibility/batch country=$COUNTRY_UPPER"

  HEADERS=(-H "Content-Type: application/json" -H "User-Agent: voidly-check-action/1.0")
  [ -n "$API_KEY" ] && HEADERS+=(-H "Authorization: Bearer $API_KEY")

  RESPONSE=$(mktemp)
  HTTP_CODE=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    --max-time 30 \
    "${HEADERS[@]}" \
    -X POST \
    -d "$PAYLOAD" \
    "$API_BASE_URL/v1/accessibility/batch" || echo "000")

  if [ "$HTTP_CODE" != "200" ]; then
    BODY=$(cat "$RESPONSE" 2>/dev/null | head -c 500 || true)
    warn "API returned HTTP $HTTP_CODE for country=$COUNTRY_UPPER: $BODY"
    # Emit one synthetic 'error' row per domain so the report still shows the country.
    for d in "${DOMAINS[@]}"; do
      jq -n \
        --arg domain "$d" \
        --arg country "$COUNTRY_UPPER" \
        --arg http "$HTTP_CODE" \
        '{domain: $domain, country: $country, status: "error", http_code: $http, methods: [], accessibilityScore: null}' \
        >> "$RESULTS_FILE"
    done
    rm -f "$RESPONSE"
    continue
  fi

  jq -c --arg country "$COUNTRY_UPPER" \
    '.results[] | {domain, country: $country, status, methods: (.methods // []), accessibilityScore}' \
    "$RESPONSE" >> "$RESULTS_FILE"
  rm -f "$RESPONSE"
done

TOTAL_CHECKS=$(wc -l < "$RESULTS_FILE" | tr -d ' ')
BLOCKED_JSON=$(jq -cs '[.[] | select(.status == "blocked")]' "$RESULTS_FILE")
BLOCKED_COUNT=$(printf '%s' "$BLOCKED_JSON" | jq 'length')

# Most-affected country, for a deep-link in the summary.
TOP_COUNTRY=$(jq -rs '
  [.[] | select(.status == "blocked")]
  | group_by(.country)
  | map({country: .[0].country, n: length})
  | sort_by(-.n)[0]?.country // empty
' "$RESULTS_FILE")
REPORT_URL=""
[ -n "$TOP_COUNTRY" ] && REPORT_URL="https://voidly.ai/${TOP_COUNTRY,,}"

# ---------- step summary ----------
SUMMARY_TARGET="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

if [ "$REPORT_FORMAT" = "json" ]; then
  {
    echo '```json'
    jq -s '{total_checks: length, blocked: [.[] | select(.status == "blocked")], all: .}' "$RESULTS_FILE"
    echo '```'
  } >> "$SUMMARY_TARGET"
else
  {
    echo "## Voidly Accessibility Report"
    echo ""
    echo "Checked **${#DOMAINS[@]}** domain(s) across **${#COUNTRIES[@]}** country/countries — **$TOTAL_CHECKS** total checks."
    echo ""
    if [ "$BLOCKED_COUNT" -eq 0 ]; then
      echo "**No blocking detected.** All targets returned \`accessible\` or \`unknown\`."
    else
      echo "**$BLOCKED_COUNT blocked result(s) detected.**"
    fi
    echo ""
    echo "| Domain | Country | Status | Methods |"
    echo "|---|---|---|---|"
    jq -rs '
      sort_by(.country, .domain)[]
      | "| \(.domain) | \(.country) | \(.status) | \((.methods // []) | join(", ")) |"
    ' "$RESULTS_FILE" \
      | while IFS= read -r row; do
          status=$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')
          glyph=$(status_glyph "$status")
          echo "$row" | awk -v g="$glyph" -F'|' 'BEGIN{OFS="|"} {$4=" "g" "; print}'
        done
    echo ""
    if [ -n "$REPORT_URL" ]; then
      echo "Most-affected country: [$TOP_COUNTRY full report]($REPORT_URL)"
    fi
    echo ""
    echo "_Powered by [Voidly](https://voidly.ai) — 19.6M+ live censorship samples across 130 countries. CC BY 4.0._"
  } >> "$SUMMARY_TARGET"
fi

# ---------- outputs ----------
OUT="${GITHUB_OUTPUT:-/dev/stdout}"
{
  echo "blocked-count=$BLOCKED_COUNT"
  echo "total-checks=$TOTAL_CHECKS"
  # Multi-line output: blocked-domains may be a long JSON array.
  echo "blocked-domains<<EOF_BLOCKED"
  echo "$BLOCKED_JSON"
  echo "EOF_BLOCKED"
  echo "report-url=$REPORT_URL"
} >> "$OUT"

# ---------- exit code ----------
log ""
log "Result: $BLOCKED_COUNT blocked / $TOTAL_CHECKS total"

if [ "$BLOCKED_COUNT" -gt 0 ] && [ "$FAIL_ON_BLOCKED" = "true" ]; then
  fail "$BLOCKED_COUNT blocked result(s) detected and fail-on-blocked=true"
fi

if [ "$BLOCKED_COUNT" -gt 0 ]; then
  warn "$BLOCKED_COUNT blocked result(s) detected (fail-on-blocked=false, not failing)"
fi

exit 0
