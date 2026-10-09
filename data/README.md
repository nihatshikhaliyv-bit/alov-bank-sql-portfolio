# Data and provenance

`portfolio_snapshot.sql.gz` contains the original synthetic export supplied by the project owner. It is a lossless gzip of the original bytes, with 30,000 customers, 45,449 accounts and 363,592 transactions. The export was produced on 4 October 2026; its financial rows are labeled 2025.

The original data-generation script was not supplied. The source rows, schema, procedures and export footer are the evidence available; exact generation formulas should not be claimed without qualification.

`analysis/generate_history.py` expands customer activity according to the owner's later requirement: an independent uniform integer from 1 through 80 for every customer-month in 2025, distributed across that customer's accounts. It preserves balances using clearly labeled synthetic closing-reconciliation entries and preserves the original one-per-account fee amounts. Non-fee amounts are sampled from a bounded lognormal distribution; withdrawals are capped to avoid negative balances. This is a reproducible scenario, not observed bank behavior.

The expanded restore selects `banking_portfolio_demo` and replaces tables there. Both synthetic databases are now published in this repository. Download the [snapshot](portfolio_snapshot.sql.gz) directly. The 143,913,163-byte expanded archive is stored losslessly in 14 parts under [expanded/](expanded/README.md); its downloader rejoins and verifies them. It can also be reproduced with the included generator.

All figures are AZN. Customer names are synthetic. Do not add real customer records, national IDs, passwords, connection files or private banking data to this public portfolio.

Use `analysis/snapshot_metrics.json` for the seed and `analysis/expanded_metrics.json` for the expanded version. Financial totals are intentionally unchanged; transaction totals and coverage differ. Hashes and byte sizes identify the exact payloads.
