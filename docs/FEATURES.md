# Feature inventory and boundaries

## Dataset versions

**Seed export:** 30,000 customers, 45,449 accounts, 16,000 loans, 25 branches and 363,592 historical transactions. Historical activity contains only deposits, withdrawals and fees. Operational extension tables are empty, except that every account has a baseline control record.

**Expanded history:** replaces the seed's eight-row pattern with 1–80 transactions per customer per month across all of 2025. It preserves closing balances and original fee totals. It does not create evidence of real customer behavior or introduce fictitious contractual loan payments.

**V2 upgrade:** delivered separately; installation on the project owner's computer is unconfirmed. The demo-specific copy changes only the database name.

## Capability status

| Feature | Status | Evidence / limit |
| --- | --- | --- |
| Customer/accounts/branches/loans relational model | Present in seed | Foreign keys and product columns; no real personal data |
| Deposit, withdrawal, transfer and fee posting | Existing procedures, repaired by V2 | Transaction ID and enum blockers repaired |
| Account locking and insufficient-funds checks | Implemented | Single-session success/failure tested; concurrency not stress-tested |
| Duplicate request rejection | Implemented | Unique request_key; duplicate calls fail rather than returning a cached result |
| Reversals | Implemented | New opposing entries; cannot edit posted history |
| Loan schedule creation | Implemented for explicitly chosen loans | Equal-principal schedule; requires valid approved terms and future first date |
| Installment payment and allocation | Implemented | Interest first, then principal; earliest unpaid installment first |
| Deposit interest processing | Implemented | Completed UTC days, stored account rates and baseline controls |
| Dormancy/activity processing | Implemented | activity_status and account_status are separate concepts; automated activity does not itself authorize reactivation |
| Daily job logging | Implemented | Scheduler execution not verified on the user's machine |
| Double-entry general ledger | Added in V2 | New operations and journal entries commit together |
| Opening balances | Added in V2 | Disclosed migration offset, not verified historical equity/cash |
| Audit of customers/accounts/loans | Added in V2 | Old/new row data, acting database login and timestamp |
| Transfer approval | Added in V2 | Demo per-transfer threshold over AZN 1,000; not AML monitoring or aggregate-limit enforcement |
| Staff roles | Created by V2 | Requires assignment, separate users and login testing |
| Trial balance / GL profit / aging / health checks | Added in V2 | GL profit is limited to implemented post-activation operations |

## Important operational boundaries

- Existing outstanding loans do not automatically acquire historical installment schedules. `Unscheduled` is an honest coverage label.
- The expanded history has no loan-payment or transfer rows. Those are demonstrated as forward operations after installation.
- New customer/account/loan onboarding is not a complete product flow. Inserting nonzero balances directly will break GL reconciliation.
- No cards, payment-network connection, internet banking, mobile application, FX settlement, KYC/AML service, regulatory submission, credit scoring model or loan-loss provisioning is implemented.
- The source branch-profit summary is separate from the new general ledger. It cannot be silently added to new ledger income.
- Audit triggers do not make administrators powerless: root can alter/drop database objects. The session posting flag is not a security boundary.

See the roadmap for a staged path forward rather than a claim that the prototype is a complete banking platform.
