# Alov Bank — Bank profile

## Positioning

Alov Bank is a fictional Azerbaijani bank serving individuals and smaller business customers through a modeled network of 25 branches. Its core business is gathering customer deposits and providing mortgage, personal, vehicle, business and education loans. All balances are represented in AZN; the dataset does not implement foreign exchange.

The most defensible description is **a retail-focused, mortgage-heavy bank with a substantial savings and salary-account base**. This positioning follows the product mix in the data. It is not a claim about a real bank, a banking license or market share.

## Customer proposition

The modeled product range brings everyday accounts, savings and borrowing into one customer relationship. Salary and current accounts support basic account activity; savings accounts receive modeled interest; business accounts cover a smaller share of balances. Lending extends from household purchases to business funding and education.

These are database products. The repository does not include a mobile app, card network, payments integration or evidence of service quality. It therefore does not claim digital leadership, fast loan approval, low prices or high customer satisfaction.

## Operating footprint

| Attribute | Modeled scope |
| --- | --- |
| Customers | 30,000 |
| Accounts | 45,449; approximately 1.51 per customer |
| Loan records | 16,000, including paid loans |
| Expanded history | 14,585,400 transactions; 1–80 per customer per month in 2025 |
| Customers with any loan record | 11,292; 37.64% of customers |
| Branches | 25 across 14 cities |
| Employees | 613 in branch-level employee counts; no individual employee table |
| Baku customer share | 57.14% |
| Reporting currency | AZN |

Loan-record penetration includes past borrowers with paid loans. It is not the share of customers currently borrowing.

## How the bank earns money

The financial summary labels interest income, fees and other income as revenue. It deducts deposit-interest expense and operating expense. For the 2025 scenario, that produces AZN 35.77 million in the field called net_profit.

Interest income is dominant. It closely matches annualized interest on Active loans at the stored rates; deposit-interest expense closely matches annualized cost on account balances. This is evidence of a financial simulation, not proof that the amounts were collected or paid during a complete accounting year. Tax and loan-loss provisions are not separately recorded.

## What it does well within the scenario

The bank maintains a broad account base, a positive modeled contribution from every branch and a loan book funded below the total deposit balance. Account-level amounts reconcile to the branch summaries, and the upgrade makes future money movements traceable through both customer transactions and balanced accounting entries.

These are strengths of the scenario and its implementation. No peer-bank benchmark has been supplied, so the project cannot establish that Alov Bank outperforms the Azerbaijani banking market.

## Where it needs development

Mortgage concentration, regional concentration and dependence on interest earnings limit diversification. Historical transaction behavior is generated under explicit random-volume rules, and the absence of complete repayment histories restricts delinquency analysis. The system also needs broader product operations and infrastructure before it could resemble a production bank.

## Short description for the repository

> A synthetic Azerbaijani banking case study combining financial analysis with a MySQL operations model. It examines profitability, funding, credit concentration and branch performance, then connects new transactions to accounting, audit and approval controls.

The project is named **Alov Bank**. No founding year, headquarters address, ownership, market ranking, customer promise or regulatory status has been invented.
