-- Read-only MySQL analysis. Expanded restore uses banking_portfolio_demo.
-- For the original snapshot only, change USE to banking_portfolio_fresh.
USE banking_portfolio_demo;

-- 1. Reported annual financial results (do not sum balance stocks across years).
SELECT reporting_year,
 SUM(total_revenue) AS gross_revenue_azn,
 SUM(interest_income-interest_expense) AS net_interest_income_azn,
 SUM(operating_expense) AS operating_expense_azn,
 SUM(net_profit) AS reported_model_profit_azn,
 ROUND(100*SUM(net_profit)/NULLIF(SUM(total_revenue),0),2) AS profit_margin_pct,
 ROUND(100*SUM(operating_expense)/NULLIF(SUM(interest_income-interest_expense+fee_income+other_income),0),2) AS operating_cost_to_income_pct,
 ROUND(100*SUM(interest_income)/NULLIF(SUM(total_revenue),0),2) AS interest_revenue_share_pct
FROM branch_financials GROUP BY reporting_year;

-- 2. Funding measure: remaining principal, not original lending.
SELECT l.outstanding_azn,a.deposits_azn,
 ROUND(100*l.outstanding_azn/NULLIF(a.deposits_azn,0),2) AS loan_to_deposit_pct
FROM (SELECT SUM(outstanding_amount) outstanding_azn FROM loans) l
CROSS JOIN (SELECT SUM(balance) deposits_azn FROM accounts) a;

-- 3. Product concentration and overdue exposure (not a verified 90-day NPL ratio).
SELECT loan_type,COUNT(*) AS loan_records,SUM(outstanding_amount) AS outstanding_azn,
 ROUND(100*SUM(outstanding_amount)/NULLIF((SELECT SUM(outstanding_amount) FROM loans),0),2) AS principal_share_pct,
 SUM(CASE WHEN loan_status='Overdue' THEN outstanding_amount ELSE 0 END) AS overdue_principal_azn,
 ROUND(100*SUM(CASE WHEN loan_status='Overdue' THEN outstanding_amount ELSE 0 END)/NULLIF(SUM(outstanding_amount),0),2) AS overdue_exposure_pct
FROM loans GROUP BY loan_type ORDER BY outstanding_azn DESC;

-- 4. Deposit product mix.
SELECT account_type,COUNT(*) AS accounts,SUM(balance) AS balance_azn,
 ROUND(100*SUM(balance)/NULLIF((SELECT SUM(balance) FROM accounts),0),2) AS balance_share_pct
FROM accounts GROUP BY account_type ORDER BY balance_azn DESC;

-- 5. Regional profit contribution. Dataset region grouping, not city grouping.
SELECT f.reporting_year,b.region,COUNT(*) AS branches,SUM(f.net_profit) AS profit_azn,
 ROUND(100*SUM(f.net_profit)/NULLIF(SUM(SUM(f.net_profit)) OVER(PARTITION BY f.reporting_year),0),2) AS profit_share_pct
FROM branch_financials f JOIN branches b ON b.branch_id=f.branch_id
GROUP BY f.reporting_year,b.region ORDER BY f.reporting_year,profit_azn DESC;

-- 6. Branch ranking: absolute profit and margin are different measures.
SELECT b.branch_name,b.city,b.employee_count,f.reporting_year,f.net_profit,
 ROUND(100*f.net_profit/NULLIF(f.total_revenue,0),2) AS margin_pct,
 DENSE_RANK() OVER(PARTITION BY f.reporting_year ORDER BY f.net_profit DESC) AS profit_rank
FROM branches b JOIN branch_financials f ON f.branch_id=b.branch_id;

-- 7. Monthly throughput, with synthetic closing adjustments shown separately.
SELECT DATE_FORMAT(transaction_date,'%Y-%m') AS month,COUNT(*) AS transaction_count,
 SUM(amount) AS gross_amount_azn,
 SUM(CASE WHEN description='Synthetic closing-balance reconciliation' THEN amount ELSE 0 END) AS reconciliation_amount_azn,
 SUM(CASE WHEN description<>'Synthetic closing-balance reconciliation' THEN amount ELSE 0 END) AS other_generated_activity_azn
FROM transactions GROUP BY month ORDER BY month;

-- 8. Verify requested monthly count rule INCLUDING missing customer-months.
-- Full calendar is necessary: checking only existing transaction groups misses zero-row months.
WITH RECURSIVE months AS (
 SELECT DATE('2025-01-01') AS month_start
 UNION ALL SELECT month_start+INTERVAL 1 MONTH FROM months WHERE month_start<'2025-12-01'
), activity AS (
 SELECT customer_id,DATE_FORMAT(transaction_date,'%Y-%m') AS month,COUNT(*) AS n
 FROM transactions WHERE transaction_date>='2025-01-01' AND transaction_date<'2026-01-01'
 GROUP BY customer_id,month
)
SELECT COUNT(*) AS customer_months,
 MIN(COALESCE(a.n,0)) AS min_monthly_transactions,
 MAX(COALESCE(a.n,0)) AS max_monthly_transactions,
 SUM(CASE WHEN COALESCE(a.n,0) BETWEEN 1 AND 80 THEN 0 ELSE 1 END) AS rule_violations
FROM customers c CROSS JOIN months m
LEFT JOIN activity a ON a.customer_id=c.customer_id AND a.month=DATE_FORMAT(m.month_start,'%Y-%m');

-- 9. Historical balance replay. Valid for supplied historical types before new V2 postings.
SELECT a.account_id,a.balance,
 a.opening_balance+COALESCE(t.net_movement,0) AS expected_balance,
 a.balance-a.opening_balance-COALESCE(t.net_movement,0) AS difference
FROM accounts a LEFT JOIN (
 SELECT account_id,SUM(CASE WHEN transaction_type IN ('Deposit','Transfer In','Interest','Reversal In') THEN amount ELSE -amount END) AS net_movement
 FROM transactions GROUP BY account_id
) t ON t.account_id=a.account_id
WHERE a.balance<>a.opening_balance+COALESCE(t.net_movement,0);

-- 10. Check branch rollups using separate aggregates to avoid join multiplication.
SELECT f.branch_id,f.reporting_year,
 f.deposit_amount-COALESCE(a.account_balance,0) AS deposit_difference,
 f.loan_amount-COALESCE(l.outstanding_balance,0) AS loan_difference
FROM branch_financials f
LEFT JOIN (SELECT branch_id,SUM(balance) account_balance FROM accounts GROUP BY branch_id) a ON a.branch_id=f.branch_id
LEFT JOIN (SELECT branch_id,SUM(outstanding_amount) outstanding_balance FROM loans GROUP BY branch_id) l ON l.branch_id=f.branch_id;

-- 11. Customer risk labels: exposure-weighted, with no claim of validated scoring.
SELECT c.risk_rating,COUNT(DISTINCT c.customer_id) AS customers,COUNT(l.loan_id) AS loans,
 SUM(COALESCE(l.outstanding_amount,0)) AS outstanding_azn,
 SUM(CASE WHEN l.loan_status='Overdue' THEN l.outstanding_amount ELSE 0 END) AS overdue_azn
FROM customers c LEFT JOIN loans l ON l.customer_id=c.customer_id GROUP BY c.risk_rating;

-- 12. Investigate annual modeling: near-equality is evidence, not proof of collection.
SELECT loan_status,ROUND(SUM(outstanding_amount*annual_interest_rate/100),2) AS simple_annualized_interest
FROM loans GROUP BY loan_status;
SELECT ROUND(SUM(balance*annual_interest_rate/100),2) AS simple_annualized_deposit_cost FROM accounts;

-- 13. Deliberately avoid a fake growth rate for gross transactions vs the small seed.
-- These are different generated scenarios, not two observed business periods.
