#!/bin/bash
# 飞书电子表格读取工具 - 供 Codex 使用
# 用法: bash scripts/feishu-read.sh <spreadsheet_token> [sheet_index]
# 示例: bash scripts/feishu-read.sh TThrs8eCGh6gChtTwWAcicQqnef 0
#   sheet_index: 0=第一个Sheet, 1=第二个... 默认0(全部)

set -e

TOKEN_ID="$1"
SHEET_INDEX="${2:-all}"

if [ -z "$TOKEN_ID" ]; then
  echo "用法: bash scripts/feishu-read.sh <spreadsheet_token> [sheet_index]"
  echo "  sheet_index: 0=第一个Sheet, 1=第二个, all=全部(默认)"
  exit 1
fi

# 从 openclaw.json 读取凭证
OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"
CREDS=$(python3 -c "
import json
with open('$OPENCLAW_JSON') as f:
    c = json.load(f)
acc = c.get('channels',{}).get('feishu',{}).get('accounts',{}).get('main',{})
print(f\"{acc.get('appId','')} {acc.get('appSecret','')}\")
" 2>/dev/null)

APP_ID=$(echo "$CREDS" | awk '{print $1}')
APP_SECRET=$(echo "$CREDS" | awk '{print $2}')

if [ -z "$APP_ID" ] || [ -z "$APP_SECRET" ]; then
  echo "错误: 无法读取飞书凭证" >&2
  exit 1
fi

# 获取 tenant_access_token
TOKEN=$(curl -s -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" | python3 -c "
import json,sys
r=json.load(sys.stdin)
if r.get('code')==0: print(r['tenant_access_token'])
else: print(f\"token error: {r}\",file=sys.stderr); sys.exit(1)
")

# 获取所有 Sheet 列表
SHEETS_JSON=$(curl -s "https://open.feishu.cn/open-apis/sheets/v3/spreadsheets/$TOKEN_ID/sheets/query" \
  -H "Authorization: Bearer $TOKEN")

SHEET_IDS=$(echo "$SHEETS_JSON" | python3 -c "
import json,sys
r=json.load(sys.stdin)
if r.get('code')!=0:
    print(f'error: {r}',file=sys.stderr); sys.exit(1)
for s in r['data']['sheets']:
    print(f\"{s['sheet_id']}|{s['title']}|{s['index']}\")
")

if [ "$SHEET_INDEX" = "all" ]; then
  # 读取所有 Sheet
  echo "$SHEET_IDS" | while IFS='|' read -r SID TITLE IDX; do
    echo ""
    echo "=== Sheet: $TITLE (index=$IDX) ==="
    VALUES=$(curl -s "https://open.feishu.cn/open-apis/sheets/v2/spreadsheets/$TOKEN_ID/values/$SID?valueRenderOption=ToString" \
      -H "Authorization: Bearer $TOKEN")
    echo "$VALUES" | python3 -c "
import json,sys
r=json.load(sys.stdin)
if r.get('code')==0:
    vals=r['data'].get('valueRange',{}).get('values',[])
    for row in vals:
        print('	'.join(str(c) for c in row))
else:
    print(f'error reading sheet: {r}',file=sys.stderr)
"
  done
else
  # 读取指定 Sheet
  TARGET=$(echo "$SHEET_IDS" | awk -F'|' -v idx="$SHEET_INDEX" '$3==idx{print $1}')
  TARGET_TITLE=$(echo "$SHEET_IDS" | awk -F'|' -v idx="$SHEET_INDEX" '$3==idx{print $2}')
  if [ -z "$TARGET" ]; then
    echo "错误: sheet_index $SHEET_INDEX 不存在" >&2
    echo "可用 Sheet:" >&2
    echo "$SHEET_IDS" | while IFS='|' read -r SID TITLE IDX; do
      echo "  $IDX: $TITLE" >&2
    done
    exit 1
  fi
  echo "=== Sheet: $TARGET_TITLE ==="
  VALUES=$(curl -s "https://open.feishu.cn/open-apis/sheets/v2/spreadsheets/$TOKEN_ID/values/$TARGET?valueRenderOption=ToString" \
    -H "Authorization: Bearer $TOKEN")
  echo "$VALUES" | python3 -c "
import json,sys
r=json.load(sys.stdin)
if r.get('code')==0:
    vals=r['data'].get('valueRange',{}).get('values',[])
    for row in vals:
        print('	'.join(str(c) for c in row))
else:
    print(f'error: {r}',file=sys.stderr)
"
fi
