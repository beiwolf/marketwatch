# MarketWatch Memory Bank

Canonical running memory of repository changes and why they were made.

## Latest state
- Branch: `main`
- Remote: `origin` (`https://github.com/beiwolf/marketwatch.git`)
- Last updated: 2026-03-05 (session 4)
- Latest commit: `c04c2b8` — sched+ui: launchd scheduler, flow history panel, compact news list

---

## Change history (newest first)

### 2026-03-05 — `c04c2b8`
**Message:** `sched+ui: launchd scheduler, flow history panel, compact news list`

**Files changed:**
- `index.html`
- `scripts/install_launchd_scheduler.sh`

**What changed:**
- Added launchd installer script for a real persistent scheduler service:
  - label `com.beiwolf.marketwatch.scheduler`
  - runs `automation.sh` at login and keeps it alive.
- Updated dashboard with second-tier FLOW history/pattern section (recent-day table from `flow_index.json`).
- Condensed NEWS rendering by capping visible highlights to latest 12 and constraining list height (`highlights-list`), preventing page from growing monolithically.

---

### 2026-03-04 — `c76aecb`
**Message:** `ux: remove standalone sources panel; show source headline inline with highlights`

**Files changed:**
- `index.html`

**What changed:**
- Removed the standalone "News Sources" card from the right column.
- Enriched each highlight row to show source context inline:
  - source outlet badge
  - source headline next to the highlight metadata
- Kept highlight text clickable to open the linked source URL.
- UX goal: users can scan insight + provenance in one place without jumping between sections.

---

### 2026-03-04 — `d110814`
**Message:** `docs: add MEMORY_BANK with running repo change history`

**Files changed:**
- `MEMORY_BANK.md` (created)

**What changed:**
- Created this file to track why each commit was made.
- Serves as canonical persistent memory across Claude Code sessions.

---

### 2026-03-04 — `2a089b4`
**Message:** `ux: clickable highlights linked to source URLs`

**Files changed:**
- `automation.sh`
- `index.html`
- `prompts/news_prompt.txt`

**What changed:**
- Added clickable highlight UX in dashboard so a highlight can open its supporting source URL.
- Added source outlet badges for highlights.
- Updated news prompt contract so each highlight includes:
  - `source_url`
  - `source_outlet`
- Brought `automation.sh` into tracked repo history (script used for scheduler/orchestration).

---

### 2026-03-04 — `96edb45`
**Message:** `news: 7:14 PM ET — update #4 | 15 sources`

**Files changed:**
- `data/news.json`
- `data/news_index.json`

**What changed:**
- Executed a news aggregation run.
- Merged latest breaking/highlights/sources into `data/news.json`.
- Updated daily index metadata in `data/news_index.json`.

---

### 2026-03-04 — `2f1626d`
**Message:** `news: 6:55 PM ET — update #3 | 10 sources`

**Files changed:**
- `data/news.json`
- `data/news_index.json`

**What changed:**
- Executed a news aggregation run and pushed resulting state.

---

### 2026-03-04 — `306cec7`
**Message:** `news: 6:55 PM ET — update #2 | 9 sources`

**Files changed:**
- `data/news.json`
- `data/news_index.json`

**What changed:**
- Additional news merge/update in the same operational window.

---

### 2026-03-04 — `db0e349`
**Message:** `flow: 6:26 PM ET — net +4.88% | SPY +0.78%`

**Files changed:**
- `data/flow.json`
- `data/flow_index.json`
- `data/archive/flow-2026-03-04.json`

**What changed:**
- Successful flow snapshot write.
- Daily flow archive created/appended.
- Flow index updated with latest net/SPY metadata.

---

### 2026-03-04 — `0929493`
**Message:** `news: 6:19 PM ET — update #1 | 5 sources`

**Files changed:**
- `data/news.json`
- `data/news_index.json`

**What changed:**
- First successful news run for the day and initial source accumulation.

---

### 2026-03-04 — `b0f54a6`
**Message:** `v6: Robinhood-inspired UI redesign`

**Files changed:**
- `index.html`

**What changed:**
- Replaced `Share Tech Mono` + `Rajdhani` fonts with `Inter` (body) + `JetBrains Mono` (numbers/tickers).
- Removed all terminal effects: scanline overlay (`body::before/::after`), CSS grid pattern.
- Introduced CSS variables: `--r` (12px card radius), `--r-sm` (8px), `--r-pill` (100px).
- All cards now use `border-radius: var(--r)` with softer borders.
- Topbar chips and date buttons are pill-shaped (`border-radius: var(--r-pill)`).
- Net Flow Score panel redesigned as Robinhood-style hero: 68px bold mono score spans full width; `net-stats` stacks below as flex column (instead of side-by-side grid).
- Sector rows: ETF code rendered as inset pill badge (`bg3` + `border2`); percentage at 14px bold mono.
- Narrative mover styled as inset block (`bg3` + border + padding) instead of plain text line.
- Sentiment badges and source Read links are pill-shaped.
- Audit entries have `--r-sm` rounded corners.
- All label sizes bumped from 9px → 11px.
- Sparkline hex colors updated from `#00f082`/`#ff2d4a` to `#00d68f`/`#ff4757` to match new palette.
- New color palette: green `#00d68f`, red `#ff4757`, blue `#60a5fa`, amber `#f59e0b`.

---

### 2026-03-04 — `18dc8fe`
**Message:** `v5: split flow/news prompts, news aggregation schema, intraday sparkline`

**What changed (high-level):**
- Prompt split by concern (flow vs news).
- News schema + aggregation behavior improvements.
- Intraday sparkline support added.

---

### 2026-03-04 — `3f263ff`
**Message:** `v4: research_prompt.txt — Claude returns JSON only, OpenClaw handles writes`

**What changed (high-level):**
- Explicit role separation: Claude returns JSON; automation handles filesystem writes.

---

### 2026-03-04 — `f0b02dd`
**Message:** `v3: archive-based audit trail, date picker, index.json manifest`

**What changed (high-level):**
- Added audit trail and historical browsing primitives.

---

### 2026-03-04 — `f686ad9`
**Message:** `initial deploy — marketwatch dashboard`

**What changed (high-level):**
- Initial project deployment and baseline dashboard.

---

## Operational notes (today)
- Scheduler is a background process (`automation.sh`), not system cron.
- Flow parser was hardened to extract JSON even when Claude wraps it with prose/fences.
- News loop was changed to run every 60 minutes 24/7 (flow remains market-hours-gated).
- Telegram status notifications were integrated into loop outcomes (success/failure summaries).

## Working rules (requested by owner)
- Before making any repository change, consult `MEMORY_BANK.md` first for current context.
- After every change that gets pushed to GitHub, immediately append/update this memory bank with:
  - commit hash
  - files changed
  - what changed and why

---

## How to refresh this memory bank
```bash
cd ~/Desktop/marketwatch
git log --oneline --decorate --max-count=50
```
Then update this file with commit purpose + changed files.
