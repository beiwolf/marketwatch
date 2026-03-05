#!/usr/bin/env bash
set -u

cd ~/Desktop/marketwatch || exit 1

TG_TARGET="${TG_TARGET:-8349285086}"

send_status() {
  local msg="$1"
  openclaw message send --channel telegram --target "$TG_TARGET" --message "$msg" >/dev/null 2>&1 || true
}

run_flow_update() {

DATE=$(TZ="America/New_York" date "+%B %-d, %Y")
TIME=$(TZ="America/New_York" date "+%-I:%M %p")
ISO_DATE=$(TZ="America/New_York" date "+%Y-%m-%d")

echo "[FLOW] Starting update — $TIME ET"

PREV_NET=$(python3 -c "
import json
try:
 d = json.load(open('data/flow.json'))
 v = d.get('net_flow_score')
 print(v if v is not None else 'null')
except: print('null')
")

PREV_SECTORS=$(python3 -c "
import json
try:
 d = json.load(open('data/flow.json'))
 s = d.get('sectors', [])
 print(json.dumps([{'etf': x['etf'], 'change': x['change']} for x in s]) if s else 'null')
except: print('null')
")

PROMPT=$(sed \
-e "s/{DATE}/$DATE/g" \
-e "s/{TIME}/$TIME/g" \
-e "s|{PREV_NET}|$PREV_NET|g" \
-e "s|{PREV_SECTORS}|$PREV_SECTORS|g" \
prompts/flow_prompt.txt)

CLAUDE_OUT=$(claude --allowedTools "WebSearch,WebFetch" --print "$PROMPT" 2>/tmp/mw_flow_err.log)
if [ $? -ne 0 ]; then
 echo "[FLOW] ❌ Claude CLI failed — $(cat /tmp/mw_flow_err.log)"
 return 1
fi

PARSED=$(RAW="$CLAUDE_OUT" python3 - <<'PY' 2>/tmp/mw_flow_parse.log
import os, json, re, sys
raw = os.environ.get('RAW', '').strip()

candidate = raw
m = re.search(r'```json\s*(\{.*?\})\s*```', raw, re.S | re.I)
if m:
    candidate = m.group(1).strip()
else:
    m2 = re.search(r'\{', raw)
    if m2:
        start = m2.start()
        depth = 0
        end = None
        in_str = False
        esc = False
        for i, ch in enumerate(raw[start:], start=start):
            if in_str:
                if esc:
                    esc = False
                elif ch == '\\':
                    esc = True
                elif ch == '"':
                    in_str = False
            else:
                if ch == '"':
                    in_str = True
                elif ch == '{':
                    depth += 1
                elif ch == '}':
                    depth -= 1
                    if depth == 0:
                        end = i
                        break
        if end is not None:
            candidate = raw[start:end+1].strip()

try:
    d = json.loads(candidate)
    assert 'sectors' in d and len(d['sectors']) > 0
    print(json.dumps(d))
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
PY
)

if [ $? -ne 0 ]; then
 echo "[FLOW] ❌ JSON parse failed — $(cat /tmp/mw_flow_parse.log)"
 echo "$CLAUDE_OUT" > /tmp/mw_flow_raw.txt
 return 1
fi

echo "$PARSED" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
with open('data/flow.json', 'w') as f: json.dump(d, f, indent=2)
print('Wrote data/flow.json')
"

python3 -c "
import json, os
iso = '$ISO_DATE'
path = f'data/archive/flow-{iso}.json'
flow = json.load(open('data/flow.json'))
archive = json.load(open(path)) if os.path.exists(path) else []
archive.append(flow)
with open(path, 'w') as f: json.dump(archive, f, indent=2)
print(f'Archive: {path} — {len(archive)} snapshots')
"

python3 -c "
import json, os
iso = '$ISO_DATE'
path = f'data/archive/flow-{iso}.json'
archive = json.load(open(path))
net_open = archive[0]['net_flow_score'] if archive else None
net_close = archive[-1]['net_flow_score'] if archive else None
index = json.load(open('data/flow_index.json'))
entry = next((e for e in index if e.get('date') == iso), None)
if entry:
 entry.update({'entries': len(archive), 'net_close': net_close, 'last_updated': '$TIME ET'})
else:
 index.append({'date': iso, 'entries': len(archive), 'net_open': net_open, 'net_close': net_close, 'last_updated': '$TIME ET'})
index.sort(key=lambda e: e['date'], reverse=True)
with open('data/flow_index.json', 'w') as f: json.dump(index, f, indent=2)
print('flow_index.json updated')
"

NET=$(python3 -c "import json; d=json.load(open('data/flow.json')); print(f\"{d.get('net_flow_score',0):+.2f}\")")
SPY=$(python3 -c "import json; d=json.load(open('data/flow.json')); print(f\"{d.get('sp500_change',0):+.2f}\")")
git add data/flow.json data/flow_index.json "data/archive/flow-$ISO_DATE.json"
if ! git diff --cached --quiet; then
 git commit -m "flow: $TIME ET — net ${NET}% | SPY ${SPY}%"
 git push origin main
 echo "[FLOW] ✅ Pushed — net ${NET}% | SPY ${SPY}%"
fi

COUNT=$(python3 -c "import json; print(len(json.load(open('data/archive/flow-$ISO_DATE.json'))))")
echo "[FLOW] Done — $COUNT snapshots today"
return 0

}

run_news_update() {

DATE=$(TZ="America/New_York" date "+%B %-d, %Y")
TIME=$(TZ="America/New_York" date "+%-I:%M %p")
ISO_DATE=$(TZ="America/New_York" date "+%Y-%m-%d")

echo "[NEWS] Starting update — $TIME ET"

EXISTING_URLS=$(python3 -c "
import json
try:
 d = json.load(open('data/news.json'))
 urls = [s['url'] for s in d.get('sources', [])]
 print(json.dumps(urls))
except: print('[]')
")

EXISTING_HIGHLIGHTS_COUNT=$(python3 -c "
import json
try:
 d = json.load(open('data/news.json'))
 print(len(d.get('highlights', [])))
except: print('0')
")

PROMPT=$(sed \
-e "s/{DATE}/$DATE/g" \
-e "s/{TIME}/$TIME/g" \
-e "s|{EXISTING_URLS}|$EXISTING_URLS|g" \
-e "s|{EXISTING_HIGHLIGHTS_COUNT}|$EXISTING_HIGHLIGHTS_COUNT|g" \
prompts/news_prompt.txt)

CLAUDE_OUT=$(claude --allowedTools "WebSearch,WebFetch" --print "$PROMPT" 2>/tmp/mw_news_err.log)
if [ $? -ne 0 ]; then
 echo "[NEWS] ❌ Claude CLI failed — $(cat /tmp/mw_news_err.log)"
 return 1
fi

PARSED=$(echo "$CLAUDE_OUT" | python3 -c "
import sys, json, re
raw = sys.stdin.read().strip()
raw = re.sub(r'^\x60\x60\x60json\s*', '', raw)
raw = re.sub(r'^\x60\x60\x60\s*', '', raw)
raw = re.sub(r'\s*\x60\x60\x60$', '', raw).strip()
try:
 d = json.loads(raw)
 assert 'summary' in d
 print(json.dumps(d))
except Exception as e:
 print(f'ERROR: {e}', file=sys.stderr); sys.exit(1)
" 2>/tmp/mw_news_parse.log)

if [ $? -ne 0 ]; then
 echo "[NEWS] ❌ JSON parse failed — $(cat /tmp/mw_news_parse.log)"
 echo "$CLAUDE_OUT" > /tmp/mw_news_raw.txt
 return 1
fi

PARSED_JSON="$PARSED" TIME_ET="$TIME ET" ISO_DAY="$ISO_DATE" python3 - <<'PY'
import json, os

iso = os.environ['ISO_DAY']
time_et = os.environ['TIME_ET']
new_data = json.loads(os.environ['PARSED_JSON'])

try:
 existing = json.load(open('data/news.json'))
 if existing.get('date') != iso:
  existing = {'date': iso, 'last_updated': None, 'update_count': 0, 'breaking': [], 'summary': None, 'highlights': [], 'sources': []}
except:
 existing = {'date': iso, 'last_updated': None, 'update_count': 0, 'breaking': [], 'summary': None, 'highlights': [], 'sources': []}

new_breaking = new_data.get('breaking', [])
existing_texts = {b['text'] if isinstance(b, dict) else b for b in existing.get('breaking', [])}
for item in new_breaking:
 text = item['text'] if isinstance(item, dict) else item
 if text not in existing_texts:
  existing['breaking'].insert(0, item)
  existing_texts.add(text)
existing['breaking'] = existing['breaking'][:5]

existing['summary'] = new_data.get('summary', existing.get('summary'))

new_highlights = new_data.get('new_highlights', [])
existing_highlight_texts = [h['text'].lower() for h in existing.get('highlights', []) if isinstance(h, dict) and 'text' in h]
added = 0
for h in new_highlights:
 if not isinstance(h, dict) or 'text' not in h:
  continue
 prefix = h['text'].lower()[:50]
 if not any(prefix in t for t in existing_highlight_texts):
  existing['highlights'].insert(0, h)
  existing_highlight_texts.insert(0, h['text'].lower())
  added += 1
existing['highlights'] = existing['highlights'][:20]

existing_urls = {s['url'] for s in existing.get('sources', []) if isinstance(s, dict) and 'url' in s}
new_sources = new_data.get('new_sources', [])
for s in new_sources:
 if isinstance(s, dict) and s.get('url') and s['url'] not in existing_urls:
  existing['sources'].append(s)
  existing_urls.add(s['url'])

existing['last_updated'] = time_et
existing['update_count'] = existing.get('update_count', 0) + 1
existing['date'] = iso

with open('data/news.json', 'w') as f:
 json.dump(existing, f, indent=2)

print(f'news.json updated — update #{existing["update_count"]} | {len(existing["highlights"])} highlights | {len(existing["sources"])} sources | {added} new highlights added')
PY

python3 -c "
import json
iso = '$ISO_DATE'
news = json.load(open('data/news.json'))
index = json.load(open('data/news_index.json'))
entry = next((e for e in index if e.get('date') == iso), None)
if entry:
 entry.update({'updates': news['update_count'], 'sources': len(news.get('sources',[])), 'last_updated': '$TIME ET'})
else:
 index.append({'date': iso, 'updates': news['update_count'], 'sources': len(news.get('sources',[])), 'last_updated': '$TIME ET'})
index.sort(key=lambda e: e['date'], reverse=True)
with open('data/news_index.json', 'w') as f: json.dump(index, f, indent=2)
print('news_index.json updated')
"

UPDATE_N=$(python3 -c "import json; print(json.load(open('data/news.json')).get('update_count',0))")
SOURCE_N=$(python3 -c "import json; print(len(json.load(open('data/news.json')).get('sources',[])))")
git add data/news.json data/news_index.json
if ! git diff --cached --quiet; then
 git commit -m "news: $TIME ET — update #${UPDATE_N} | ${SOURCE_N} sources"
 git push origin main
 echo "[NEWS] ✅ Pushed — update #${UPDATE_N} | ${SOURCE_N} sources accumulated"
fi

echo "[NEWS] Done"
return 0

}

run_end_of_day_archive() {

ISO_DATE=$(TZ="America/New_York" date "+%Y-%m-%d")
TIME=$(TZ="America/New_York" date "+%-I:%M %p")

echo "[EOD] Running end-of-day archive for $ISO_DATE"

python3 -c "
import os, shutil
iso = '$ISO_DATE'
src = 'data/news.json'
dst = f'data/archive/news-{iso}.json'
if os.path.exists(src):
 shutil.copy2(src, dst)
 print(f'Archived news to {dst}')
else:
 print('No news.json to archive')
"

python3 -c "
import json, os
iso = '$ISO_DATE'
archive_path = f'data/archive/flow-{iso}.json'
if os.path.exists(archive_path):
 archive = json.load(open(archive_path))
 index = json.load(open('data/flow_index.json'))
 entry = next((e for e in index if e.get('date') == iso), None)
 if entry:
  entry['finalized'] = True
  entry['total_snapshots'] = len(archive)
  entry['net_open'] = archive[0]['net_flow_score'] if archive else None
  entry['net_close'] = archive[-1]['net_flow_score'] if archive else None
 with open('data/flow_index.json', 'w') as f: json.dump(index, f, indent=2)
 print(f'Flow index finalized for {iso} — {len(archive)} total snapshots')
"

git add data/archive/ data/flow_index.json data/news_index.json
if ! git diff --cached --quiet; then
 git commit -m "eod archive: $ISO_DATE — market closed $TIME ET"
 git push origin main
 echo "[EOD] ✅ End-of-day archive pushed for $ISO_DATE"
fi

}

# PHASE 0 — STARTUP & ENVIRONMENT CHECK
cd ~/Desktop/marketwatch || exit 1

OK=1

test -f data/flow.json && echo "✅ data/flow.json" || { echo "❌ MISSING data/flow.json"; OK=0; }
test -f data/news.json && echo "✅ data/news.json" || { echo "❌ MISSING data/news.json"; OK=0; }
test -f data/flow_index.json && echo "✅ data/flow_index.json" || { echo "❌ MISSING data/flow_index.json"; OK=0; }
test -f data/news_index.json && echo "✅ data/news_index.json" || { echo "❌ MISSING data/news_index.json"; OK=0; }
test -d data/archive && echo "✅ data/archive/" || { echo "❌ MISSING data/archive/"; OK=0; }
test -f prompts/flow_prompt.txt && echo "✅ prompts/flow_prompt.txt" || { echo "❌ MISSING flow_prompt.txt"; OK=0; }
test -f prompts/news_prompt.txt && echo "✅ prompts/news_prompt.txt" || { echo "❌ MISSING news_prompt.txt"; OK=0; }
which claude >/dev/null 2>&1 && echo "✅ claude CLI found" || { echo "❌ claude CLI not in PATH"; OK=0; }
git remote -v >/dev/null 2>&1 && echo "✅ git remote set" || { echo "❌ no git remote"; OK=0; }

if [ "$OK" -ne 1 ]; then
  echo "Startup check failed. Exiting."
  exit 1
fi

LAST_FLOW_RUN=0
LAST_NEWS_RUN=0
LAST_ARCHIVE_DATE=""

echo "[MAIN] Scheduler started"

while true; do

NOW=$(date +%s)
ISO_DATE=$(TZ="America/New_York" date "+%Y-%m-%d")
DAY=$(TZ="America/New_York" date "+%u")
HOUR=$(TZ="America/New_York" date "+%H")
MIN=$(TZ="America/New_York" date "+%M")
TOTAL_MIN=$((10#$HOUR * 60 + 10#$MIN))
MARKET_OPEN=570
MARKET_CLOSE=990
IS_WEEKDAY=$( [ "$DAY" -le 5 ] && echo "1" || echo "0" )
IS_MARKET_HOURS=$( [ "$IS_WEEKDAY" = "1" ] && [ "$TOTAL_MIN" -ge "$MARKET_OPEN" ] && [ "$TOTAL_MIN" -lt "$MARKET_CLOSE" ] && echo "1" || echo "0" )

if [ "$IS_WEEKDAY" = "1" ] && [ "$TOTAL_MIN" -ge "$MARKET_CLOSE" ] && [ "$TOTAL_MIN" -lt "$((MARKET_CLOSE + 30))" ] && [ "$LAST_ARCHIVE_DATE" != "$ISO_DATE" ]; then
if run_end_of_day_archive; then
  send_status "📦 EOD archive complete for $ISO_DATE"
else
  send_status "❌ EOD archive failed for $ISO_DATE"
fi
LAST_ARCHIVE_DATE="$ISO_DATE"
fi

FLOW_DUE=0
if [ "$IS_MARKET_HOURS" = "1" ]; then
ELAPSED_FLOW=$((NOW - LAST_FLOW_RUN))
[ "$ELAPSED_FLOW" -ge 600 ] && FLOW_DUE=1
fi

NEWS_DUE=0
ELAPSED_NEWS=$((NOW - LAST_NEWS_RUN))
[ "$ELAPSED_NEWS" -ge 3600 ] && NEWS_DUE=1

if [ "$FLOW_DUE" = "1" ]; then
if run_flow_update; then
  LAST_FLOW_RUN=$NOW
  FLOW_METRICS=$(python3 - <<'PY'
import json
try:
 d=json.load(open('data/flow.json'))
 net=d.get('net_flow_score',0)
 spy=d.get('sp500_change',0)
 print(f"net {net:+.2f}% | SPY {spy:+.2f}%")
except Exception:
 print("metrics unavailable")
PY
)
  send_status "✅ FLOW update $(TZ=\"America/New_York\" date \"+%-I:%M %p\") ET — $FLOW_METRICS"
else
  ERR=$(cat /tmp/mw_flow_err.log /tmp/mw_flow_parse.log 2>/dev/null | tail -n 3 | tr '\n' ' ')
  send_status "❌ FLOW update failed $(TZ=\"America/New_York\" date \"+%-I:%M %p\") ET — ${ERR:-unknown error}"
fi
fi

if [ "$NEWS_DUE" = "1" ]; then
if run_news_update; then
  LAST_NEWS_RUN=$NOW
  NEWS_METRICS=$(python3 - <<'PY'
import json
try:
 d=json.load(open('data/news.json'))
 print(f"update #{d.get('update_count',0)} | highlights {len(d.get('highlights',[]))} | sources {len(d.get('sources',[]))}")
except Exception:
 print("metrics unavailable")
PY
)
  send_status "✅ NEWS update $(TZ=\"America/New_York\" date \"+%-I:%M %p\") ET — $NEWS_METRICS"
else
  ERR=$(cat /tmp/mw_news_err.log /tmp/mw_news_parse.log 2>/dev/null | tail -n 3 | tr '\n' ' ')
  send_status "❌ NEWS update failed $(TZ=\"America/New_York\" date \"+%-I:%M %p\") ET — ${ERR:-unknown error}"
fi
fi

sleep 60

done
