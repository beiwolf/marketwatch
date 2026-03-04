# 📊 MarketWatch Dashboard

Live S&P 500 sector money flow monitor + market news aggregator.

**Live site:** https://beiwolf.github.io/marketwatch

## Data architecture

```
data/
  flow.json              <- current sector snapshot (overwritten each run)
  news.json              <- current news (overwritten each run)
  index.json             <- lightweight manifest of all archived trading days
  archive/
    2026-03-04.json      <- all snapshots for that day (append-only array)
    2026-03-05.json
    ...                  <- one file per trading day, grows forever
```

Each agent run:
1. Overwrites flow.json + news.json with fresh data
2. Appends snapshot to data/archive/YYYY-MM-DD.json (today's file, created if missing)
3. Updates data/index.json with today's summary entry (date, entry count, net open/close)
4. git pushes — live site updates within ~60 seconds

## Why this architecture
- flow.json and news.json stay tiny (single snapshot) — fast to fetch
- Each daily archive file stays small (~50KB max per trading day at 10-min intervals)
- index.json is a lightweight manifest — dashboard loads it to populate date picker without downloading all history
- Any past trading day is one fetch away: data/archive/YYYY-MM-DD.json
- Scales indefinitely — years of history with no performance degradation

*Not financial advice.*
