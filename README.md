# 📊 MarketWatch Dashboard

Live S&P 500 sector money flow monitor + market news aggregator.

**🌐 Live site:** https://beiwolf.github.io/marketwatch

## What it shows
- Net flow score across all 11 S&P 500 sector ETFs
- Inflow / outflow waterfall with volume signals and deltas
- Market mood, breadth, regime classification
- Breaking news, summary, highlights, and source links
- Full session audit trail — every snapshot, collapsible

## Data files (updated by agent each run)
- `data/flow.json` — current sector flow snapshot
- `data/news.json` — current news aggregation
- `data/history.json` — append-only audit trail

## Architecture
Static HTML dashboard reads JSON via fetch() — works on GitHub Pages.
Agent scrapes live data, updates JSON, pushes to GitHub. Site reflects changes within ~60 seconds.

*Not financial advice.*
