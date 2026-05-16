#!/bin/bash
# Bulk upload PDFs/TXT to AgroBot AFIR knowledge collection
# Usage: WEBUI_API_KEY=sk-... ./bulk-upload-afir.sh [PDF_DIR]

set -uo pipefail

# === CONFIG ===
BASE_URL="${BASE_URL:-http://localhost:8080}"
KNOWLEDGE_ID="${KNOWLEDGE_ID:-6fb39d08-6dcc-4b1c-b112-5dc65a707f54}"  # AFIR
PDF_DIR="${1:-/opt/agrobot/upload-queue}"
LOG_FILE="${LOG_FILE:-/tmp/afir-upload-$(date +%Y%m%d-%H%M%S).log}"
POLL_INTERVAL=5      # sec between status checks
MAX_WAIT=900         # sec max per file (15 min — match Docling timeout)
COOL_DOWN=2          # sec between files (let server breathe)

# === VALIDATIONS ===
if [ -z "${WEBUI_API_KEY:-}" ]; then
  echo "ERROR: WEBUI_API_KEY env var not set"
  echo "Get it from: Open WebUI → profile → Settings → Account → API Keys"
  echo "Then run: WEBUI_API_KEY=sk-... $0"
  exit 1
fi

if [ ! -d "$PDF_DIR" ]; then
  echo "ERROR: PDF_DIR not found: $PDF_DIR"
  exit 1
fi

# Check API key works
AUTH_TEST=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $WEBUI_API_KEY" \
  "$BASE_URL/api/v1/auths/")
if [ "$AUTH_TEST" != "200" ]; then
  echo "ERROR: API key authentication failed (HTTP $AUTH_TEST)"
  exit 1
fi

# Check knowledge collection exists
KN_TEST=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $WEBUI_API_KEY" \
  "$BASE_URL/api/v1/knowledge/$KNOWLEDGE_ID")
if [ "$KN_TEST" != "200" ]; then
  echo "ERROR: Knowledge collection $KNOWLEDGE_ID not found (HTTP $KN_TEST)"
  exit 1
fi

# === LIST FILES ALREADY IN AFIR (skip those) ===
echo "Fetching files already in AFIR..."
EXISTING_FILES=$(curl -s -H "Authorization: Bearer $WEBUI_API_KEY" \
  "$BASE_URL/api/v1/knowledge/$KNOWLEDGE_ID" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('\n'.join(f.get('meta',{}).get('name','') or f.get('filename','') for f in d.get('files',[])))")

echo "$EXISTING_FILES" | sed 's/^/  - /'
echo ""

# === MAIN LOOP ===
TOTAL=$(ls -1 "$PDF_DIR"/*.pdf "$PDF_DIR"/*.txt 2>/dev/null | wc -l)
SUCCESS=0
FAILED=0
SKIPPED=0
CURRENT=0

echo "=== Bulk upload to AFIR ==="
echo "Source: $PDF_DIR"
echo "Total files: $TOTAL"
echo "Log: $LOG_FILE"
echo "Knowledge ID: $KNOWLEDGE_ID"
echo ""

START_TIME=$(date +%s)

# Iterate over PDFs and TXTs
shopt -s nullglob
for FILE in "$PDF_DIR"/*.pdf "$PDF_DIR"/*.txt; do
  CURRENT=$((CURRENT+1))
  FNAME=$(basename "$FILE")
  FSIZE=$(stat -c%s "$FILE")
  FSIZE_KB=$((FSIZE / 1024))

  printf "[%d/%d] %s (%dKB)... " "$CURRENT" "$TOTAL" "$FNAME" "$FSIZE_KB"

  # Skip if already in AFIR
  if echo "$EXISTING_FILES" | grep -Fxq "$FNAME"; then
    echo "SKIP (already in AFIR)"
    SKIPPED=$((SKIPPED+1))
    echo "[$FNAME] SKIPPED" >> "$LOG_FILE"
    continue
  fi

  STEP_START=$(date +%s)

  # === STEP 1: Upload file (triggers Docling + embedding) ===
  UPLOAD_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/files/?process=true&process_in_background=false" \
    -H "Authorization: Bearer $WEBUI_API_KEY" \
    -F "file=@$FILE" \
    --max-time $((MAX_WAIT + 60)))

  FILE_ID=$(echo "$UPLOAD_RESPONSE" | python3 -c "import sys,json;
try:
    d=json.load(sys.stdin); print(d.get('id') or d.get('detail','NONE'))
except: print('PARSE_ERROR')" 2>/dev/null)

  if [ -z "$FILE_ID" ] || [ "$FILE_ID" = "NONE" ] || [ "$FILE_ID" = "PARSE_ERROR" ]; then
    echo "FAIL (upload failed)"
    echo "[$FNAME] UPLOAD_FAIL: $UPLOAD_RESPONSE" >> "$LOG_FILE"
    FAILED=$((FAILED+1))
    continue
  fi

  # === STEP 2: Add file to AFIR knowledge collection ===
  ADD_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/knowledge/$KNOWLEDGE_ID/file/add" \
    -H "Authorization: Bearer $WEBUI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"file_id\":\"$FILE_ID\"}")

  ADD_OK=$(echo "$ADD_RESPONSE" | python3 -c "import sys,json;
try:
    d=json.load(sys.stdin)
    print('OK' if d.get('id') else 'FAIL')
except: print('PARSE_ERROR')" 2>/dev/null)

  if [ "$ADD_OK" != "OK" ]; then
    echo "FAIL (add to knowledge: $ADD_RESPONSE)"
    echo "[$FNAME] ADD_FAIL (file_id=$FILE_ID): $ADD_RESPONSE" >> "$LOG_FILE"
    FAILED=$((FAILED+1))
    continue
  fi

  DURATION=$(($(date +%s) - STEP_START))
  echo "OK ${DURATION}s"
  echo "[$FNAME] OK in ${DURATION}s (file_id=$FILE_ID)" >> "$LOG_FILE"
  SUCCESS=$((SUCCESS+1))

  # Cool-down to avoid overwhelming Docling
  sleep $COOL_DOWN
done

# === SUMMARY ===
ELAPSED=$(($(date +%s) - START_TIME))
ELAPSED_MIN=$((ELAPSED / 60))

echo ""
echo "=== DONE in ${ELAPSED_MIN}m ${ELAPSED}s ==="
echo "  Success: $SUCCESS"
echo "  Failed:  $FAILED"
echo "  Skipped: $SKIPPED"
echo "  Total:   $TOTAL"
echo ""
echo "Log: $LOG_FILE"
if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "Failures:"
  grep -E "FAIL" "$LOG_FILE" | head -10
fi
