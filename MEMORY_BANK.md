# MarketWatch Memory Bank

Canonical running memory of repository changes and why they were made.

## Latest state
- Branch: `main`
- Remote: `origin` (`https://github.com/beiwolf/marketwatch.git`)
- Last updated: 2026-03-05 (session 8)
- Latest commit: `f0a19a4` — ux: simplify jargon for basic investors — plain English labels

---

## Change history (newest first)

### 2026-03-05 — `f0a19a4`
**Message:** `ux: simplify jargon for basic investors — plain English labels`

**Files changed:**
- `index.html`

**What changed:**
Replaced finance jargon with plain English labels to make the dashboard accessible to basic investors:
- "Net Flow Score" → "Market Flow" (card title + hero label)
- "Breadth" → "Sectors Up / Down"
- "% Advancing" → "% Green"
- "Avg Sector" → "Avg Move"
- "Sector Rotation" → "Sectors" + legend: "⚡ Unusual volume · ~ Estimated · ▲▼ Change"
- "◀ Outflow / Inflow ▶" → "◀ Money Out / Money In ▶"
- "Inflows / Outflows" → "Winners / Losers"
- "Net Flow Trend" → "Market Flow — 10 Days"
- "Regime changed" → "Market mode changed" (flip banner)
- "Regime" → "Mode" (timeline label)
- "Mood" → "Sentiment" (arc label)
- Sentiment ratio: `5↑ 2↓ 3→` → `5 Bullish 2 Bearish 3 Neutral`
- "Intraday net flow" → "Today's market flow" (sparkline label)

---

### 2026-03-05 — `b30e4c1`
**Message:** `feat: 13 new features — charts, heatmap, mood arc, regime alerts, minimap + more`

**Files changed:**
- `index.html`
- `sw.js` (created)

**What changed:**
All 13 features added in one comprehensive update:

1. **Multi-day net flow trend chart** — SVG line chart in "Net Flow Trend" card showing last 10 days of `net_close` from `flow_index.json`. Colored dots per day (green/red), zero-line, date labels.
2. **Sector heatmap** — New card in flow col. 4-column CSS grid of all sectors; background color intensity scales with magnitude relative to max, hue by direction (green/red).
3. **Flow regime timeline** — Appears inside each audit day block when regime transitions occurred. Compresses consecutive same-regime snapshots into pill trail with arrows between changes.
4. **Intraday mood arc** — Row of 8px colored dots (one per snapshot) inside audit day block; green=risk-on, red=risk-off, amber=neutral. Only shown if ≥2 snapshots have mood data.
5. **Sentiment ratio badge** — `5↑ 2↓ 3→` pill row in Key Highlights card header, populated on each `renderNews` call.
6. **Top Mover Spotlight card** — Dedicated card at top of right column. Shows top_mover name (large mono), % change, ETF badge, reason text. Populated from `renderFlow`.
7. **Regime flip alert** — Amber banner below topbar on page load when `flow_regime` differs from last known value. Persists across polls. Dismissable with ✕ button.
8. **Stale data warning** — `chip-updated` turns amber (`chip-amber`) if `generated_at` is >20 min old and current time is within market hours (9:30–16:30). Shows tooltip with age.
9. **URL hash deep-linking** — `#YYYY-MM-DD` in URL scrolls to matching `.audit-day-block` on load and on `hashchange`. Clicking any day header updates hash via `history.replaceState`.
10. **Jump to Today floating button** — Fixed bottom-right button (`↑ Today`). Appears when audit section is scrolled >60px above viewport. Scrolls to today's block and updates hash.
11. **Keyboard navigation** — Global `j`/`k` moves between `.audit-entry` elements (blue outline highlight), `Enter` toggles open/closed. Ignores when focused on form elements.
12. **Service worker / offline cache** — `sw.js` registered at `./sw.js`. Network-first strategy for `/data/` files (caches fresh responses, falls back to cache). Cache-first for shell. Cleans stale caches on activate.
13. **Minimap sidebar** — Fixed right-side panel (hidden `<1460px`). One colored bar per audit day; `IntersectionObserver` highlights the currently-visible day. Bars link to `#YYYY-MM-DD` hashes. Updated after `loadAllAudit` resolves.

**CSS additions:** `.hm-wrap/.hm-grid/.hm-cell/.hm-etf/.hm-name/.hm-pct`, `.trend-chart-wrap/.tc-svg`, `.mood-arc/.mood-arc-dots/.ma-dot`, `.regime-timeline/.rt-label/.rt-pills/.rt-pill/.rt-on/.rt-off/.rt-neu/.rt-arrow`, `.sent-ratio/.sr-bull/.sr-bear/.sr-neu`, `.spotlight-wrap/.spotlight-ticker/.spotlight-pct/.spotlight-reason`, `.regime-flip-banner/.rfb-icon/.rfb-text/.rfb-close`, `.jump-today-btn`, `.minimap/.mm-entry/.mm-label/.mm-bar/.mm-active`, `.audit-entry.kb-active`, `.audit-kb-hint`

**JS additions:** `checkRegimeFlip()`, `checkStaleData()`, `renderSectorHeatmap()`, `renderSentimentRatio()`, `buildMoodArc()`, `buildRegimeTimeline()`, `renderTrendChart()`, `jumpToToday()`, `initJumpToday()`, `initKeyboardNav()`, `updateMinimap()`, `updateMinimapActive()`, `scrollToHash()`. `auditDataCache` global object caches snapshots for minimap use.

---

### 2026-03-05 — `ff78889`
**Message:** `ux: show industry name + ETF ticker in audit sector cells`

**Files changed:**
- `index.html`

**What changed:**
- Audit snapshot sector cells previously only showed the ETF code (XLE, XLK, etc.) with no sector context.
- Each cell now shows the sector/industry name (`s.name`, e.g. "Technology") as the primary label, with the ETF ticker below it as a secondary tag.
- CSS: replaced `.asc-name` with `.asc-info` (flex column), `.asc-industry` (12px 500-weight text), `.asc-etf` (10px mono muted), `.asc-pct` (13px bold mono, right-aligned).
- JS: `buildAuditEntries` cell template updated to render both `s.name` and `s.etf`, with `s.name || s.etf` fallback.

---

### 2026-03-05 — `e6947cb`
**Message:** `ux: continuous-scroll flow audit — all days, inter/intra-day dividers`

**Files changed:**
- `index.html`

**What changed:**
- Removed date picker UI (Today button + past-dates `<select>`) from audit section header.
- Replaced single-date audit view with a full continuous scroll of all available days.
- New `loadAllAudit(indexData)` fetches all archive dates in parallel on first page load, renders newest-first.
- New `refreshTodayBlock()` called on every 60s poll — only re-fetches today's archive, not the full history.
- `auditInitialized` flag prevents re-running full load on subsequent polls.
- Removed JS functions: `loadAuditForDate`, `switchToToday`, `populateDatePicker`.
- Each day is a `.audit-day-block` containing:
  - **Inter-day header** (`.audit-day-header`): bold 4px left accent bar (green/red by closing net), 28px mono closing score, date + day-of-week label, snapshot count, status pill (Live / Finalized / Partial).
  - **Intra-day entries** (`.audit-day-entries`): existing `<details>` accordion rows, indented with a 2px left timeline rail whose color matches the day's direction.
- New CSS classes: `.audit-day-block`, `.audit-day-header`, `.audit-day-datecol`, `.audit-day-date`, `.audit-day-dow`, `.audit-day-close`, `.audit-day-info`, `.audit-day-meta`, `.audit-day-status` (.live / .final / .partial), `.audit-day-entries`.
- Removed CSS: `.date-picker-wrap`, `.date-picker-label`, `.date-btn`, `#date-select`, `.audit-day-label`.

---

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
