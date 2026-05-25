#!/bin/bash
# =============================================================
# SivanInvest — ManyChat → Airtable Workflow Setup
# Usage:  AIRTABLE_API_KEY=patXXXX ./sivaninvest-workflows/setup.sh
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Validate input ────────────────────────────────────────────
if [ -z "${AIRTABLE_API_KEY:-}" ]; then
  echo "ERROR: AIRTABLE_API_KEY is required."
  echo "Get your token at: https://airtable.com/create/tokens"
  echo "Usage: AIRTABLE_API_KEY=patXXXX $0"
  exit 1
fi

echo "[1/4] Creating Airtable API credential..."
CRED_TMP=$(mktemp /tmp/airtable-cred-XXXX.json)
trap 'rm -f "$CRED_TMP"' EXIT

cat > "$CRED_TMP" <<EOF
[
  {
    "name": "Airtable API",
    "type": "httpHeaderAuth",
    "data": {
      "name": "Authorization",
      "value": "Bearer ${AIRTABLE_API_KEY}"
    }
  }
]
EOF

n8n import:credentials --input="$CRED_TMP"
echo "    Credential created."

echo "[2/4] Importing workflow..."
n8n import:workflow --input="$SCRIPT_DIR/manychat-airtable-sync.workflow.json"
echo "    Workflow imported."

echo "[3/4] Looking up credential ID to patch workflow nodes..."
# Use n8n REST API (requires N8N_HOST and N8N_API_KEY env vars if auth is enabled)
N8N_HOST="${N8N_HOST:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"

if [ -n "$N8N_API_KEY" ]; then
  CRED_ID=$(curl -sf -H "X-N8N-API-KEY: $N8N_API_KEY" \
    "${N8N_HOST}/api/v1/credentials" \
    | python3 -c "import sys,json; data=json.load(sys.stdin); creds=[c for c in data.get('data',[]) if c.get('name')=='Airtable API']; print(creds[0]['id'] if creds else '')" 2>/dev/null || true)

  if [ -n "$CRED_ID" ]; then
    echo "    Credential ID: $CRED_ID — patching workflow JSON..."
    WORKFLOW_JSON="$SCRIPT_DIR/manychat-airtable-sync.workflow.json"
    sed -i "s/REPLACE_WITH_YOUR_CREDENTIAL_ID/$CRED_ID/g" "$WORKFLOW_JSON"
    n8n import:workflow --input="$WORKFLOW_JSON"
    echo "    Workflow re-imported with credential ID."
  else
    echo "    WARN: Could not resolve credential ID via API."
    echo "    Open the workflow in n8n UI and select 'Airtable API' in each HTTP Request node."
  fi
else
  echo "    N8N_API_KEY not set — skip auto-patching."
  echo "    Open the workflow in n8n UI and select 'Airtable API' in each HTTP Request node (4 nodes)."
fi

echo "[4/4] Done!"
echo ""
echo "Next steps:"
echo "  1. Open n8n → Workflows → 'שמירת פרטי קשר מדיה חברתית'"
echo "  2. Click the Webhook node → 'Listen for test event' → copy the URL"
echo "  3. Activate the workflow (toggle top-right)"
echo "  4. Paste the webhook URL into ManyChat Flow → External Request action"
echo ""
echo "Webhook URL will be: ${N8N_HOST}/webhook/manychat-leads-sync"
