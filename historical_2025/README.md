# Historical bank scenario — 31 December 2025

Prepared for Nihat Şıxəliyev. The bank name remains undecided.

This extension reconstructs all 16,000 original loans from their 2021–2024 issue dates through **31 December 2025 inclusive**, generates customer income histories, applies repayment-history lending limits, models 20 rented and 5 owned branches, and calculates an illustrative 2025 current-tax result. All new records are synthetic.

## What to install

The new reporting database is **`banking_portfolio_2025`**. The existing **`banking_portfolio_demo`** remains the deposit-activity and V2 operational demonstration. This is an isolated historical reporting scenario, not an in-place V2 migration. The new schema's `loans.outstanding_amount` contains the recalculated balances; `source_outstanding` retains the old number for comparison. Do not use the old database's loan balance or profit figures as the new scenario's results.

Why separate? The V2 repayment procedures use the current date, opening GL balances were installed in 2026, and the expanded deposit activity already contains 1–80 transactions per customer per month. Retrofitting historical loan payments into those records would require regenerating account balances and the GL opening together. The historical scenario therefore records loan payments as **external cash settlements**, not debits to those deposit accounts. Its repayment events are not part of the 1–80 deposit-activity count. It does not claim a consolidated, fully reconciled core banking ledger.

### Windows installation

1. Extract the ZIP to a normal folder, not inside the ZIP viewer.
2. Open Command Prompt. Use this command, replacing the file path with the actual extracted SQL location:

```bat
"C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe" -u root -p --default-character-set=utf8mb4 < "C:\YOUR_EXTRACTED_FOLDER\bank_portfolio_github\historical_2025\05_historical_2025.sql"
```

Enter your MySQL password when prompted. This is a **Command Prompt command, not a command to paste at `mysql>`**. The database name must be unused. Do not add `--force`: batch mode should stop on the first SQL error. No `DROP DATABASE` or `DROP TABLE` is included. Do not rerun over a partial import; preserve the error and investigate it first.

3. Run the checks, again from Command Prompt:

```bat
"C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe" -u root -p --default-character-set=utf8mb4 < "C:\YOUR_EXTRACTED_FOLDER\bank_portfolio_github\historical_2025\06_checks.sql"
```

Every `issues` result must be zero. A printed completion message alone is not proof of success. Refresh DbGate's database list and select `banking_portfolio_2025` to inspect the new scenario.

### Useful queries

```sql
USE banking_portfolio_2025;
SELECT * FROM bank_profit_2025;
SELECT * FROM monthly_loan_performance_2025 ORDER BY month_end;
SELECT * FROM customer_average_income_2025 LIMIT 30;
SELECT * FROM lending_limits_2025 WHERE prior_max_dpd > 90 LIMIT 30;
SELECT * FROM restructurings LIMIT 30;
SELECT * FROM premises;
SELECT loan_id, source_outstanding, outstanding_amount,
       outstanding_amount-source_outstanding AS change_in_scenario
FROM loans ORDER BY ABS(outstanding_amount-source_outstanding) DESC LIMIT 30;
```

## Repayment and interest policies

- Dates are calendar dates; reporting stops at the end of 31 December 2025. No cash payment or executed restructuring is recorded after that day.
- Original issue dates, original principal and original annual rates come from the seed. Original paid/overdue labels and remaining balances are superseded by the reconstructed scenario.
- First principal payment is due at the end of the issue month. Thereafter principal is scheduled equally over the inclusive issue-to-maturity months. Interest uses simple **Actual/365** daily interest on unpaid principal, including in leap years. A short first month earns only its actual days of interest. Cent rounding carries fractional cents forward.
- Payments allocate to all due interest first, then oldest due principal. Interest is not compounded. There is no additional penalty-interest rate.
- Reliable, occasional-delay, repeated-delay, long-delay and stops-paying behaviours are deterministic random scenarios. Income shocks can delay payments. Payments are externally funded; affordability does not prove actual cash availability.
- After 90 consecutive days in an unresolved arrears episode, **all new loan interest freezes**, including interest on not-yet-due principal. Existing interest remains payable. Actual days past due continue increasing. This is the owner's chosen simulation rule, not a certified interpretation of Azerbaijani law or IFRS non-accrual rules.
- Partial payment does not reset the episode's 90-day allowance. Clearing all billed arrears closes the episode; normal accrual resumes the following day. An independent later episode has a fresh maximum of 90 charged overdue days. `days_past_due` follows the oldest still-unpaid due item; `charged_days` follows the continuous episode, so they can differ after partial payments.
- Selected 30–60-day arrears can be restructured on a month-start in 2025. Old due items remain visible as rescheduled. Unpaid interest is carried separately, never added to principal. Restructuring is not labelled a cash repayment.
- Rate increases of one percentage point occur only at restructuring. Alternative restructurings reduce the annual rate by one point and extend the remaining term. Their projected equal-principal interest exceeds the old projection if paid on time. This is greater nominal contractual interest, **not guaranteed profit** or a valuation benefit. Projection uses monthly periods; realised interest follows actual days and repayments.
- January 2026 restructuring is a roadmap item only; it is not inserted as an executed transaction. Existing contract maturity dates may be after the cutoff because they were already known.

## Income and credit eligibility

All 30,000 customers have monthly synthetic net-income and essential-expense observations from July 2020 through December 2025. Original annual income is used as an anchor, not as a verified gross-to-net conversion. Variability and income shocks are assumptions, not Azerbaijan population estimates. Transfers or other account deposits are not classified as salary.

Assessments occur at each 2025 month-end using the latest six observed months, actual loan states and arrears known by that date. They are eligibility calculations, not new loan originations. Existing loans are inherited exposures; the new lending policy is not applied retroactively to pretend those loans were approved under it.

| Available repayment history | Maximum total monthly debt / net income |
|---|---:|
| Established, no delays | 35% |
| No previous loan | 25% |
| Occasional delays up to 30 days | 25% |
| Repeated episodes or 31–60-day delay | 15% |
| 61–90-day delay | 10%, manual review |
| Delay exceeding 90 days, exclusion completed | 10%, manual review |
| Active arrears or uncompleted exclusion | No new offer |

After an episode exceeding 90 days, no new loan offer is allowed for **12 calendar months after all arrears are paid**. A new arrears episode during the exclusion restarts the wait once cleared, across all of that customer's loans. Reassessment after expiry is not automatic approval. The 12-month-after-clearance rule and percentage limits are chosen internal policies, not claimed local bank requirements.

Available new monthly payment is the smaller of (income × policy cap − existing debt payments) and (income − essential expenses − existing debt payments), floored at zero. Existing loan obligations use the current equal-principal payment plus a monthly interest estimate. The displayed new principal limit is an **illustrative personal-loan annuity at 18% for 36 months**. It is not a mortgage limit, business underwriting decision, collateral assessment or actual offer. High historical debts may therefore produce zero new eligibility even for timely borrowers.

## Premises and taxation

Branches 1–5 are assumed owned; 6–25 rented. Floor areas and prices are synthetic and are not market quotations. All rents are gross contractual amounts. Individual landlords receive 86% and 14% is withheld. Prior-month withholding is remitted during the next month; December withholding remains payable at the cutoff. Resident-company landlords have no rental withholding in this model. Company landlords are assumed non-VAT-registered; do not apply this assumption to real landlords without checking their status.

Rented locations start five-year leases on 1 January 2025 at an assumed 10% annual discount rate. Right-of-use assets and lease liabilities are initially the present value of 60 monthly payments. Monthly payments reduce liability and include interest; the asset is depreciated over 60 months. Only 2025 activity is emitted. Two-month refundable deposits are disclosed separately and are not rental expenses.

Owned buildings have an assumed 40-year accounting life, no residual value, no land component, and no opening accumulated depreciation. Tax depreciation uses 7% reducing balance for the first model year. Property tax is modelled at 1% of average beginning/end tax carrying value for these five buildings only. This is not a full fixed-asset inventory or complete property-tax return.

The source operating-expense figure has no detailed rent split. To avoid silently adding rent twice, **15% is explicitly treated as a synthetic old premises allowance and removed**, then replaced with the new premises costs. The remaining 85% is carried forward as other operating expenses. Source funding cost, fee income and other income remain model inputs; they are not reconstructed from cash flows.

Interest income is replaced with actual simulated 2025 accruals. A simplified closing credit-loss overlay of 1% / 5% / 50% for <=30 / 31–90 / >90 days past due is charged from an assumed zero opening allowance. It is **not IFRS 9 ECL**, and it is added back in the tax illustration rather than assumed tax deductible.

Tax bridge:

1. Begin with accounting profit before tax.
2. Add back lease depreciation and lease interest; deduct contractual rent under the model's operating-lease tax assumption.
3. Add back owned-building accounting depreciation; deduct model tax depreciation.
4. Add back the illustrative impairment overlay.
5. Apply 20% to positive taxable profit. No prior tax losses are assumed.
6. Subtract explicitly synthetic advance payments to show current tax payable.

Advance payments are demonstration entries (three payments of 15% of annual current tax), not reconstructed Article 151 obligations. Deferred tax, actual tax filing, payroll taxes, full VAT, land tax and a complete bank-wide property-tax calculation are outside this release. The final result is labelled **profit after current tax**, not a fully IFRS-compliant net profit.

## Analysis: what this bank demonstrates

Strengths include traceable repayment history, separation of principal and interest, visible frozen-interest periods, repeat-arrears tracking, income-sensitive lending limits, executed restructuring history, and a clear profit-to-tax reconciliation. Premises records distinguish cash paid from accounting expense and withholding from the bank's own cost.

Weaknesses remain material: balances depend on synthetic behavioural assumptions; old loan approvals are inherited rather than validated; deposit activity and loan cash settlement are separate; funding/other expenses are partly inherited; collateral, regulatory capital/liquidity and production GL consolidation are absent. Neither positive profit nor higher projected restructuring interest establishes that a real bank is safe or viable.

See `results.json` for generated amounts and `VALIDATION.md` for tests actually executed. Original root-level charts and analysis describe the **earlier baseline**, not this scenario. Do not reuse their profit figures for the new reporting date without relabelling them.

Read [BANK_ANALYSIS_2025.md](BANK_ANALYSIS_2025.md) for the new scenario's results, strengths, weaknesses and development priorities, and [SOURCES.md](SOURCES.md) for external references.

## Reproduce

From the repository root:

```bash
python historical_2025/build.py
python historical_2025/test_scenario.py
```

Generation writes SQL, results and no database connections. The source compressed seed remains unchanged. Python 3.10+ standard library only. Run `06_checks.sql` after importing to MySQL 8.0+.

For GitHub, commit the generator, source seed, documentation and validation results. The generated `05_historical_2025.sql` is larger than GitHub's regular per-file limit and is excluded by `.gitignore`; distribute the download ZIP as a Release asset instead of committing the SQL dump. No GitHub repository has been published by this work.

## Future work

January 2026 restructurings; a unified historical cash/GL reconstruction; mortgage collateral and LTV; business cash-flow underwriting; payroll and VAT detail; deferred tax; IFRS 9 staging/ECL; bank-wide fixed assets; external credit bureau data; access control and concurrency tests. The bank name and open-source license still need the owner's decision before publication.
