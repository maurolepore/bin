#!/bin/bash

# ─── Colors ───────────────────────────────────────────────
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

TIMEOUT=6
ALL_OK=true

# ─── Statuspage (Atlassian) services ──────────────────────
declare -A SERVICES=(
  ["GitHub"]="https://www.githubstatus.com/api/v2/status.json"
  ["Anthropic/Claude"]="https://status.anthropic.com/api/v2/status.json"
  ["Airtable"]="https://status.airtable.com/api/v2/status.json"
  ["Vercel"]="https://www.vercelstatus.com/api/v2/status.json"
  ["Cloudflare"]="https://www.cloudflarestatus.com/api/v2/status.json"
  ["Stripe"]="https://status.stripe.com/api/v2/status.json"
  ["Datadog"]="https://status.datadoghq.com/api/v2/status.json"
  ["PagerDuty"]="https://status.pagerduty.com/api/v2/status.json"
)

# ─── Header ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}${CYAN}   🛰  Service Status Check — $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# ─── Check Statuspage services ────────────────────────────
check_statuspage() {
  local name=$1
  local url=$2
  local response indicator description

  response=$(curl -s --max-time "$TIMEOUT" "$url" 2>/dev/null)

  if [[ -z "$response" ]]; then
    echo -e "  ${RED}✗${RESET}  ${BOLD}$name${RESET} — ${RED}unreachable${RESET}"
    ALL_OK=false
    return
  fi

  indicator=$(echo "$response" | jq -r '.status.indicator' 2>/dev/null)
  description=$(echo "$response" | jq -r '.status.description' 2>/dev/null)

  case "$indicator" in
    none)
      echo -e "  ${GREEN}✓${RESET}  ${BOLD}$name${RESET} — ${GREEN}$description${RESET}"
      ;;
    minor)
      echo -e "  ${YELLOW}⚠${RESET}  ${BOLD}$name${RESET} — ${YELLOW}$description${RESET}"
      ALL_OK=false
      ;;
    major|critical)
      echo -e "  ${RED}✗${RESET}  ${BOLD}$name${RESET} — ${RED}$description${RESET}"
      ALL_OK=false
      ;;
    *)
      echo -e "  ${YELLOW}?${RESET}  ${BOLD}$name${RESET} — ${YELLOW}unknown ($indicator)${RESET}"
      ;;
  esac
}

for name in "${!SERVICES[@]}"; do
  check_statuspage "$name" "${SERVICES[$name]}"
done

# ─── AWS (RSS-based fallback) ──────────────────────────────
echo ""
echo -e "${BOLD}  AWS Health${RESET}"

# Check if AWS CLI + Health API is available (requires Business/Enterprise support)
if command -v aws &>/dev/null && aws health describe-events --region us-east-1 --max-items 1 &>/dev/null 2>&1; then
  events=$(aws health describe-events \
    --region us-east-1 \
    --filter "eventStatusCodes=open" \
    --query 'events[*].[service,eventTypeCode,region]' \
    --output text 2>/dev/null)

  if [[ -z "$events" ]]; then
    echo -e "  ${GREEN}✓${RESET}  No open events (via AWS Health API)"
  else
    echo -e "  ${RED}✗${RESET}  Open events detected:"
    echo "$events" | while read -r line; do
      echo -e "       ${RED}→${RESET} $line"
    done
    ALL_OK=false
  fi
else
  # Fallback: parse the public RSS summary
  rss=$(curl -s --max-time "$TIMEOUT" "https://status.aws.amazon.com/rss/all.rss" 2>/dev/null)
  if [[ -z "$rss" ]]; then
    echo -e "  ${YELLOW}?${RESET}  Could not reach AWS status RSS"
  else
    issues=$(echo "$rss" | grep -o '<title>[^<]*<\/title>' | sed 's/<[^>]*>//g' | grep -iv "amazon web services" | head -5)
    if [[ -z "$issues" ]]; then
      echo -e "  ${GREEN}✓${RESET}  No recent issues (via public RSS)"
    else
      echo -e "  ${YELLOW}⚠${RESET}  Recent RSS entries:"
      echo "$issues" | while read -r line; do
        echo -e "       ${YELLOW}→${RESET} $line"
      done
    fi
  fi
fi

# ─── Summary ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
if $ALL_OK; then
  echo -e "  ${GREEN}${BOLD}All systems operational ✓${RESET}"
else
  echo -e "  ${RED}${BOLD}One or more services may have issues ✗${RESET}"
fi
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
