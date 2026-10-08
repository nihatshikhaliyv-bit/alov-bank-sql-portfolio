# Data quality and interpretation

## What reconciles

In the original seed, account closing balances exactly equal opening balances plus signed historical deposits/withdrawals/fees. All 25 branch deposit totals and outstanding-loan totals match the underlying account and loan tables. Annual revenue, expense and profit identities have no mismatches. Historical fees match reported fee income.

The expanded generator preserves those closing balances and fees. It validates 360,000 customer-month counts, positive transaction amounts, customer/account/branch ownership and nonnegative running balances. The independent streaming validator reads the actual serialized SQL, checks IDs and replays the balances again; see `analysis/expanded_validation.json` for its result.

## Data that remains modeled or missing

| Issue | Treatment in this project |
| --- | --- |
| Original source has eight transactions per account | Retained as the reproducible seed, not presented as behavioral evidence |
| Expanded counts are uniformly random from 1 through 80 | Explicit owner-selected simulation rule, not an estimated banking distribution |
| Final balances are specified in advance | One clearly labeled closing reconciliation entry per account; show separately in analysis |
| Dates and period boundaries differ | Annual summary is labeled 2025; balance as-of is not explicitly stored; original export is October 2026 |
| New random activity could appear to imply new profit | Financial summaries are deliberately preserved; throughput is not revenue |
| Interest income lacks historical cash receipts | Describe as modeled annual income; no claim of audited collection |
| No original installment history | Do not convert Overdue labels into a verified NPL or days-past-due measure |
| risk_rating has no supplied scoring method | Treat as a stored category, not validated underwriting |
| activity_status differs from account_status | Separate behavioral and servicing flags; 939 Dormant accounts also have activity_status Active in the seed |
| No total assets/equity/provisions/tax schedule | Do not calculate verified ROA, ROE, capital ratios or after-tax income |
| No external benchmark | Strengths refer to the internal scenario, not superiority to real banks |

The earlier `branch_performance` view labels loan-to-deposit bands as a liquidity position. This report does not adopt that as a regulatory liquidity assessment; a single stock ratio is insufficient.

Money is parsed as integer cents during analysis/generation. Source MySQL tables use DECIMAL. Displayed chart values are rounded; sums and percentage denominators use the unrounded amounts. Some annual-interest checks differ by a few cents because rounding each branch and rounding the total are not equivalent.
