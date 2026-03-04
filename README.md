# 📊 MarketWatch Dashboard

Live S&P 500 sector money flow + aggregated market news.
**Live:** https://beiwolf.github.io/marketwatch

## Update cadence
- **Sector flow**: every 10 minutes during market hours (Mon–Fri 9:30 AM–4:30 PM ET)
- **Market news**: every 60 minutes, aggregated throughout the day (not overwritten)

## Data architecture

```
data/
  flow.json              <- latest sector flow snapshot (overwritten every 10 min)
  news.json              <- today's aggregated news (grows all day, resets at midnight)
  flow_index.json        <- manifest of all archived flow trading days
  news_index.json        <- manifest of all archived news days
  archive/
    flow-2026-03-04.json <- all intraday flow snapshots for that day (array)
    flow-2026-03-05.json
    news-2026-03-04.json <- end-of-day news snapshot for that day
    news-2026-03-05.json
```

## News aggregation strategy

Each hourly news update:
- Breaking: new items prepended, today's items kept (deduplicated by URL)
- Summary: replaced with latest full-day synthesis
- Highlights: new unique signals appended, near-duplicates dropped
- Sources: new unique URLs appended, existing sources never removed

At midnight, news.json is archived to news-YYYY-MM-DD.json and reset for the new day.

*Not financial advice.*
