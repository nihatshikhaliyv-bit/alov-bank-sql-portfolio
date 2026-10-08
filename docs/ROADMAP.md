# Roadmap

| Priority | Deliverable | Why it matters | Acceptance evidence |
| --- | --- | --- | --- |
| 1 | Install and verify the demo and V2 | Make the delivered code observable | Row counts, zero reconciliation differences, genuine screenshots |
| 1 | Separate-user and concurrency tests | Prove controls beyond administrator calls | Teller denied direct writes; second-user approval; parallel transfer tests |
| 1 | Document financial as-of dates | Avoid combining stocks and periods | Explicit balance date and annual reporting boundaries |
| 2 | Contractual loan histories | Replace status labels with traceable aging | Approved schedules, dated payments, oldest-unpaid dates |
| 2 | Collateral and provisioning | Assess credit loss, not only overdue exposure | Valuation dates, LTV, recovery/provision assumptions and reconciliations |
| 2 | Complete accounting and period close | Support a full balance sheet and income statement | Verified opening balances, expense/accrual entries and closed periods |
| 3 | More realistic activity distributions | Improve behavioral analysis | Documented product/customer patterns, holidays, churn and paired transfers |
| 3 | KYC/AML and external settlement design | Define production integration requirements | Clear responsibilities, identifiers, review workflow and test interfaces |
| 3 | Backup/recovery and monitoring | Demonstrate operational resilience | Scheduled backups, verified restore and failure alerts |

Uniform random monthly counts are a user-selected simulation rule, not a measured distribution. Closing adjustments preserve balances but should be excluded or separately shown in behavioral analysis. Neither improvement resolves the need for real contractual history.
