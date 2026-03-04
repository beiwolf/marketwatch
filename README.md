# 📊 MarketWatch Dashboard

Live S&P 500 sector money flow + market news dashboard.
**Live:** https://beiwolf.github.io/marketwatch

## Architecture

```
data/
  flow.json              <- current sector snapshot (overwritten each run)
  news.json              <- current news (overwritten each run)
  index.json             <- manifest of all archived trading days
  archive/
    2026-03-04.json      <- all snapshots for that day (append-only array)
    2026-03-05.json      <- one file per trading day, unlimited history
```

## How it runs

OpenClaw calls `claude --print` every 10 minutes during market hours.
Claude returns a single JSON object with flow + news data.
OpenClaw handles all file writes, archiving, and git push.
GitHub Pages serves the updated site within ~60 seconds.

*Not financial advice.*
