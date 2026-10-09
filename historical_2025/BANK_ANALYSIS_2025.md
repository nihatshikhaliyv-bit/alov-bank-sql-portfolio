# Bank analysis — historical scenario at 31 December 2025

This is a fictional Azerbaijani bank with 30,000 customers, 25 branches and 16,000 inherited loan contracts. Its name is **Alov Bank**. The scenario describes a retail-led lender that assesses both affordability and repayment history, offers selective restructuring, and separates cash collection from interest earned.

## Results

| Measure | Scenario result |
|---|---:|
| Outstanding principal | AZN 1,018,104,629.34 |
| Reconstructed loan payments, inception–2025 | 654,730 |
| Executed restructurings during 2025 | 930 |
| Profit before tax | AZN 22,836,777.83 |
| Taxable profit before any prior losses | AZN 53,465,361.48 |
| Current corporate profit tax | AZN 10,693,072.30 |
| Synthetic tax advances paid | AZN 4,811,882.55 |
| Current tax payable at year-end | AZN 5,881,189.75 |
| Profit after current tax | AZN 12,143,705.53 |
| Illustrative impairment expense | AZN 30,525,628.50 |
| Rented / owned branches | 20 / 5 |

All 16,000 loan contracts are replayed: original principal minus reconstructed principal payments equals final outstanding principal.

Taxable profit exceeds accounting profit largely because the illustrative impairment overlay is added back in the tax model. Consequently, current tax is more than 20% of accounting profit, although it remains 20% of positive model taxable profit. No deferred-tax benefit is recognised here. These results are not an audited statement or a complete IFRS financial report.

## Lending assessment at year-end

| Assessment result | Customers |
|---|---:|
| Eligible for further assessment | 22,745 |
| Declined: affordability | 4,693 |
| Declined: unresolved arrears | 1,562 |
| Declined: 12-month exclusion | 941 |
| Manual review required | 59 |

Eligibility is not approval, demand or loan origination. Customers without existing loans can appear in the first group. The reported personal-loan limit is an illustrative 18%, 36-month annuity, while the existing loan book uses equal-principal schedules. Mortgage collateral, down payments and business cash flows are not included in that personal-loan limit.

## What the bank excels at in this demonstration

**Repayment risk is visible.** The scenario preserves due dates, payments, arrears episodes, accrued interest and month-end balances. A loan can remain 160 days overdue while its new interest has stopped accumulating after the permitted 90-day episode allowance.

**Credit decisions respond to behaviour and capacity.** Past severe arrears impose a 12-month exclusion after clearance; recurrence during that period restarts it. Other customers receive lower payment allowances after repeated or longer delays. Income and essential expenses prevent a high salary alone from guaranteeing new credit.

**Restructuring is traceable.** Original rates remain available, changed terms have effective dates, and rescheduled due items remain visible. Reduced-rate extensions are compared with the old remaining schedule. The model distinguishes greater projected interest from actual collected income.

**Premises and tax costs are explicit.** Rented and owned locations are separated; gross rent, landlord cash, withholding, lease liabilities and depreciation have distinct records. A tax bridge explains why taxable profit differs from accounting profit.

## Weaknesses and what they mean

**The book is synthetic and inherited.** Old approvals were not made under the new rules. The model does not claim every existing borrower would qualify today. Behaviour proportions, income shocks, essential expenses, property prices and the allocation of old premises costs are chosen assumptions.

**Collections are externally settled.** Loan payments are external settlements. Deposit-account debits are outside this database, so it cannot be presented as a consolidated cash ledger. A unified cash and GL rebuild is a future project.

**Profit remains sensitive to assumptions.** Funding cost, fees and other expenses partly come from the original model. The 15% old-premises allocation and 1%/5%/50% loss overlay materially affect results. The loss overlay is not IFRS 9 ECL; no claim is made about regulatory provisioning, capital or liquidity.

**Tax coverage is incomplete.** Current corporate tax, rental withholding and the five owned buildings' property tax are illustrated. Deferred tax, payroll taxes, detailed VAT, land and other fixed assets remain outside the scope. Real deductions and actual advance payments would require further evidence.

**The interest cap is a project policy.** The owner's 90-day freeze of all new interest is implemented and disclosed. It is not presented as a verified statement of Azerbaijani law.

## Next development priorities

1. Reconstruct a unified loan/deposit cash ledger and reconcile its GL opening balances.
2. Add January 2026 restructuring as a separate future-period extension.
3. Introduce collateral and product-specific underwriting, then replace the simple credit-loss overlay with a documented ECL model.
4. Replace inherited expense totals with payroll, supplier and funding schedules; complete the tax model.
5. Add sensitivity analysis for defaults, income shocks, funding costs and restructuring recoveries.

For GitHub, present this report alongside the assumptions, source references, generator and validation record. The project's strongest claim is **transparent and reproducible financial modelling**, not production banking readiness.

