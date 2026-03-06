#!/usr/bin/env bash
set -u

cd ~/Desktop/marketwatch || exit 1

TG_TARGET="${TG_TARGET:-8349285086}"
TASK="${1:-}"

send_status() {
  local msg="$1"
  openclaw message send --channel telegram --target "$TG_TARGET" --message "$msg" >/dev/null 2>&1 || true
}

run_claude_print() {
  local prompt="$1"
  local err_file="$2"
  local timeout_sec="${3:-180}"
  local debug_file="${4:-/Users/bot1/Desktop/marketwatch/logs/flow-debug.log}"

  python3 - "$prompt" "$err_file" "$timeout_sec" "$debug_file" <<'PY'
import subprocess, sys, time, hashlib, datetime, os
prompt = sys.argv[1]
err_file = sys.argv[2]
timeout_sec = int(sys.argv[3])
debug_file = sys.argv[4]

run_id = datetime.datetime.now().astimezone().strftime('%Y%m%d-%H%M%S')
prompt_hash = hashlib.sha256(prompt.encode('utf-8', errors='ignore')).hexdigest()[:12]
prompt_len = len(prompt)
logs_dir = os.path.dirname(debug_file) or '.'
timeout_bundle = os.path.join(logs_dir, f"claude-timeout-bundle-{run_id}.log")


def dbg(msg):
    ts = datetime.datetime.now().astimezone().isoformat()
    with open(debug_file, 'a', encoding='utf-8') as f:
        f.write(f"[{ts}] {msg}\n")


def bundle_write(title, content):
    with open(timeout_bundle, 'a', encoding='utf-8') as f:
        f.write(f"\n===== {title} =====\n")
        f.write((content or '').rstrip() + "\n")


def sh(cmd):
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
        return out
    except Exception as e:
        return f"ERROR running {' '.join(cmd)}: {e}"

if not prompt.strip():
    with open(err_file, 'w', encoding='utf-8') as f:
        f.write('ERROR: empty prompt\n')
    dbg(f"run_id={run_id} status=error reason=empty_prompt prompt_len={prompt_len} prompt_hash={prompt_hash}")
    sys.exit(2)

dbg(f"run_id={run_id} status=start timeout_sec={timeout_sec} prompt_len={prompt_len} prompt_hash={prompt_hash}")
start = time.time()

proc = subprocess.Popen(
    ['claude', '--allowedTools', 'WebSearch,WebFetch', '--print', prompt],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)

try:
    stdout, stderr = proc.communicate(timeout=timeout_sec)
    elapsed = round(time.time() - start, 2)
    with open(err_file, 'w', encoding='utf-8') as f:
        f.write(stderr or '')

    dbg(f"run_id={run_id} status=finish rc={proc.returncode} elapsed_sec={elapsed} stdout_len={len(stdout or '')} stderr_len={len(stderr or '')}")
    if stderr:
      dbg(f"run_id={run_id} stderr_tail={(stderr or '')[-400:].replace(chr(10),' | ')}")

    if proc.returncode != 0:
        sys.exit(proc.returncode)
    sys.stdout.write(stdout or '')
except subprocess.TimeoutExpired:
    elapsed = round(time.time() - start, 2)
    pid = proc.pid

    # Capture diagnostics BEFORE kill
    bundle_write('meta', f"run_id={run_id}\ntimeout_sec={timeout_sec}\nelapsed_sec={elapsed}\nprompt_len={prompt_len}\nprompt_hash={prompt_hash}\nclaude_pid={pid}")
    bundle_write('ps', sh(['ps', '-p', str(pid), '-ww', '-o', 'pid,ppid,etime,state,command']))
    bundle_write('lsof', sh(['lsof', '-p', str(pid)]))
    bundle_write('process_tree', sh(['pgrep', '-af', 'marketwatch_cron_runner.sh|claude']))

    try:
        subprocess.run(['sample', str(pid), '5', '-file', timeout_bundle], check=False)
    except Exception as e:
        bundle_write('sample_error', str(e))

    proc.kill()
    stdout, stderr = proc.communicate()

    with open(err_file, 'w', encoding='utf-8') as f:
        f.write('ERROR: claude timeout after %ss\n' % timeout_sec)
        if stderr:
            f.write(stderr)

    dbg(f"run_id={run_id} status=timeout elapsed_sec={elapsed} timeout_sec={timeout_sec} partial_stdout_len={len(stdout or '')} partial_stderr_len={len(stderr or '')} bundle={timeout_bundle}")
    if stderr:
      dbg(f"run_id={run_id} timeout_stderr_tail={(stderr or '')[-400:].replace(chr(10),' | ')}")
    sys.exit(124)
PY
}

in_market_window() {
  local day hour min total
  day=$(TZ="America/New_York" date "+%u")
  hour=$(TZ="America/New_York" date "+%H")
  min=$(TZ="America/New_York" date "+%M")
  total=$((10#$hour * 60 + 10#$min))
  # 9:30 ET to 16:30 ET, weekdays
  if [ "$day" -le 5 ] && [ "$total" -ge 570 ] && [ "$total" -lt 990 ]; then
    return 0
  fi
  return 1
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

CLAUDE_OUT=$(run_claude_print "$PROMPT" /tmp/mw_flow_err.log 180 /Users/bot1/Desktop/marketwatch/logs/flow-debug.log)
if [ $? -ne 0 ]; then
 echo "[FLOW] ❌ Claude CLI failed/timeout — $(cat /tmp/mw_flow_err.log)"
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
        start = m2.start(); depth = 0; end = None; in_str = False; esc = False
        for i, ch in enumerate(raw[start:], start=start):
            if in_str:
                if esc: esc = False
                elif ch == '\\': esc = True
                elif ch == '"': in_str = False
            else:
                if ch == '"': in_str = True
                elif ch == '{': depth += 1
                elif ch == '}':
                    depth -= 1
                    if depth == 0:
                        end = i; break
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

echo "$PARSED" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); json.dump(d, open('data/flow.json','w'), indent=2)"

python3 -c "
import json, os
iso='$ISO_DATE'; path=f'data/archive/flow-{iso}.json'
flow=json.load(open('data/flow.json'))
archive=json.load(open(path)) if os.path.exists(path) else []
archive.append(flow)
json.dump(archive, open(path,'w'), indent=2)
"

python3 -c "
import json
iso='$ISO_DATE'; path=f'data/archive/flow-{iso}.json'
archive=json.load(open(path))
net_open=archive[0]['net_flow_score'] if archive else None
net_close=archive[-1]['net_flow_score'] if archive else None
index=json.load(open('data/flow_index.json'))
entry=next((e for e in index if e.get('date')==iso), None)
if entry:
 entry.update({'entries': len(archive), 'net_close': net_close, 'last_updated': '$TIME ET'})
else:
 index.append({'date': iso, 'entries': len(archive), 'net_open': net_open, 'net_close': net_close, 'last_updated': '$TIME ET'})
index.sort(key=lambda e: e['date'], reverse=True)
json.dump(index, open('data/flow_index.json','w'), indent=2)
"

NET=$(python3 -c "import json; d=json.load(open('data/flow.json')); print(f\"{d.get('net_flow_score',0):+.2f}\")")
SPY=$(python3 -c "import json; d=json.load(open('data/flow.json')); print(f\"{d.get('sp500_change',0):+.2f}\")")
git add data/flow.json data/flow_index.json "data/archive/flow-$ISO_DATE.json"
if ! git diff --cached --quiet; then
 git commit -m "flow: $TIME ET — net ${NET}% | SPY ${SPY}%"
 git push origin main
fi

echo "[FLOW] ✅ Done — net ${NET}% | SPY ${SPY}%"
send_status "✅ FLOW update $TIME ET — net ${NET}% | SPY ${SPY}%"
}

run_news_update() {
DATE=$(TZ="America/New_York" date "+%B %-d, %Y")
TIME=$(TZ="America/New_York" date "+%-I:%M %p")
ISO_DATE=$(TZ="America/New_York" date "+%Y-%m-%d")

echo "[NEWS] Starting update — $TIME ET"

EXISTING_URLS=$(python3 -c "import json;\
try:\
 d=json.load(open('data/news.json')); print(json.dumps([s['url'] for s in d.get('sources',[]) if 'url' in s]))\
except: print('[]')")
EXISTING_HIGHLIGHTS_COUNT=$(python3 -c "import json;\
try: d=json.load(open('data/news.json')); print(len(d.get('highlights',[])))\
except: print('0')")

PROMPT=$(sed \
-e "s/{DATE}/$DATE/g" \
-e "s/{TIME}/$TIME/g" \
-e "s|{EXISTING_URLS}|$EXISTING_URLS|g" \
-e "s|{EXISTING_HIGHLIGHTS_COUNT}|$EXISTING_HIGHLIGHTS_COUNT|g" \
prompts/news_prompt.txt)

CLAUDE_OUT=$(run_claude_print "$PROMPT" /tmp/mw_news_err.log 180 /Users/bot1/Desktop/marketwatch/logs/news-debug.log)
if [ $? -ne 0 ]; then
 echo "[NEWS] ❌ Claude CLI failed/timeout — $(cat /tmp/mw_news_err.log)"
 return 1
fi

PARSED=$(echo "$CLAUDE_OUT" | python3 -c "import sys, json, re\
; raw=sys.stdin.read().strip()\
; raw=re.sub(r'^\\x60\\x60\\x60json\\s*','',raw)\
; raw=re.sub(r'^\\x60\\x60\\x60\\s*','',raw)\
; raw=re.sub(r'\\s*\\x60\\x60\\x60$','',raw).strip()\
; d=json.loads(raw); assert 'summary' in d; print(json.dumps(d))" 2>/tmp/mw_news_parse.log)
if [ $? -ne 0 ]; then
 echo "[NEWS] ❌ JSON parse failed — $(cat /tmp/mw_news_parse.log)"
 echo "$CLAUDE_OUT" > /tmp/mw_news_raw.txt
 return 1
fi

PARSED_JSON="$PARSED" TIME_ET="$TIME ET" ISO_DAY="$ISO_DATE" python3 - <<'PY'
import json, os
iso=os.environ['ISO_DAY']; time_et=os.environ['TIME_ET']; new_data=json.loads(os.environ['PARSED_JSON'])
try:
 existing=json.load(open('data/news.json'))
 if existing.get('date')!=iso:
  existing={'date':iso,'last_updated':None,'update_count':0,'breaking':[],'summary':None,'highlights':[],'sources':[]}
except:
 existing={'date':iso,'last_updated':None,'update_count':0,'breaking':[],'summary':None,'highlights':[],'sources':[]}
existing['summary']=new_data.get('summary', existing.get('summary'))
for item in new_data.get('breaking',[]):
 txt=item['text'] if isinstance(item,dict) else item
 seen={b['text'] if isinstance(b,dict) else b for b in existing.get('breaking',[])}
 if txt not in seen: existing['breaking'].insert(0,item)
existing['breaking']=existing['breaking'][:5]
added=0
existing_texts=[h['text'].lower() for h in existing.get('highlights',[]) if isinstance(h,dict) and 'text' in h]
for h in new_data.get('new_highlights',[]):
 if not isinstance(h,dict) or 'text' not in h: continue
 prefix=h['text'].lower()[:50]
 if not any(prefix in t for t in existing_texts):
  existing['highlights'].insert(0,h); existing_texts.insert(0,h['text'].lower()); added+=1
existing['highlights']=existing['highlights'][:20]
existing_urls={s['url'] for s in existing.get('sources',[]) if isinstance(s,dict) and s.get('url')}
for s in new_data.get('new_sources',[]):
 if isinstance(s,dict) and s.get('url') and s['url'] not in existing_urls:
  existing['sources'].append(s); existing_urls.add(s['url'])
existing['last_updated']=time_et
existing['update_count']=existing.get('update_count',0)+1
existing['date']=iso
json.dump(existing, open('data/news.json','w'), indent=2)
PY

python3 -c "
import json
iso='$ISO_DATE'; news=json.load(open('data/news.json')); index=json.load(open('data/news_index.json'))
entry=next((e for e in index if e.get('date')==iso), None)
if entry:
 entry.update({'updates': news['update_count'], 'sources': len(news.get('sources',[])), 'last_updated': '$TIME ET'})
else:
 index.append({'date': iso, 'updates': news['update_count'], 'sources': len(news.get('sources',[])), 'last_updated': '$TIME ET'})
index.sort(key=lambda e: e['date'], reverse=True)
json.dump(index, open('data/news_index.json','w'), indent=2)
"

UPDATE_N=$(python3 -c "import json; print(json.load(open('data/news.json')).get('update_count',0))")
SOURCE_N=$(python3 -c "import json; print(len(json.load(open('data/news.json')).get('sources',[])))")
git add data/news.json data/news_index.json
if ! git diff --cached --quiet; then
 git commit -m "news: $TIME ET — update #${UPDATE_N} | ${SOURCE_N} sources"
 git push origin main
fi

echo "[NEWS] ✅ Done — update #${UPDATE_N} | ${SOURCE_N} sources"
send_status "✅ NEWS update $TIME ET — update #${UPDATE_N} | ${SOURCE_N} sources"
}

run_eod_archive() {
ISO_DATE=$(TZ="America/New_York" date "+%Y-%m-%d")
TIME=$(TZ="America/New_York" date "+%-I:%M %p")
python3 -c "import os,shutil; iso='$ISO_DATE'; src='data/news.json'; dst=f'data/archive/news-{iso}.json';\
print('No news.json to archive') if not os.path.exists(src) else (shutil.copy2(src,dst), print(f'Archived news to {dst}'))"
python3 -c "import json, os; iso='$ISO_DATE'; p=f'data/archive/flow-{iso}.json';\
index=json.load(open('data/flow_index.json'));\
entry=next((e for e in index if e.get('date')==iso), None);\
archive=json.load(open(p)) if os.path.exists(p) else [];\
(entry.update({'finalized':True,'total_snapshots':len(archive),'net_open':archive[0]['net_flow_score'] if archive else None,'net_close':archive[-1]['net_flow_score'] if archive else None}) if entry else None);\
json.dump(index, open('data/flow_index.json','w'), indent=2)"

git add data/archive/ data/flow_index.json data/news_index.json
if ! git diff --cached --quiet; then
 git commit -m "eod archive: $ISO_DATE — market closed $TIME ET"
 git push origin main
fi
send_status "📦 EOD archive complete for $ISO_DATE"
}

mkdir -p ~/Desktop/marketwatch/logs
lockdir="/tmp/marketwatch_${TASK}.lockdir"
if ! mkdir "$lockdir" 2>/dev/null; then
  echo "[$(date)] $TASK skipped: lock held"
  exit 0
fi
trap 'rmdir "$lockdir" 2>/dev/null || true' EXIT

case "$TASK" in
  flow)
    if in_market_window; then
      run_flow_update || send_status "❌ FLOW update failed $(TZ='America/New_York' date '+%-I:%M %p') ET — $(tail -n 3 /tmp/mw_flow_err.log 2>/dev/null | tr '\n' ' ')"
    else
      echo "[FLOW] Skipped (outside market window)"
    fi
    ;;
  news)
    run_news_update || send_status "❌ NEWS update failed $(TZ='America/New_York' date '+%-I:%M %p') ET — $(tail -n 3 /tmp/mw_news_err.log 2>/dev/null | tr '\n' ' ')"
    ;;
  eod)
    day=$(TZ="America/New_York" date "+%u")
    if [ "$day" -le 5 ]; then run_eod_archive; fi
    ;;
  *)
    echo "Usage: $0 {flow|news|eod}"
    exit 2
    ;;
esac
