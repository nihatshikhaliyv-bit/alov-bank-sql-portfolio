CREATE VIEW customer_average_income_2025 AS
SELECT customer_id, ROUND(AVG(net_income),2) AS average_monthly_net_income,
       SUM(net_income) AS annual_net_income
FROM customer_income WHERE YEAR(month_end)=2025 GROUP BY customer_id;

CREATE VIEW loan_reconciliation AS
SELECT l.loan_id, l.loan_amount, l.outstanding_amount,
       COALESCE(p.principal_paid,0) AS principal_paid,
       l.loan_amount-l.outstanding_amount-COALESCE(p.principal_paid,0) AS principal_difference,
       COALESCE(a.interest_accrued,0)-COALESCE(p.interest_paid,0)-l.interest_receivable AS interest_difference
FROM loans l
LEFT JOIN (SELECT loan_id,SUM(principal_paid) principal_paid,SUM(interest_paid) interest_paid FROM loan_payments GROUP BY loan_id) p USING(loan_id)
LEFT JOIN (SELECT loan_id,SUM(interest_accrued) interest_accrued FROM loan_month_end GROUP BY loan_id) a USING(loan_id);

CREATE VIEW lending_limits_2025 AS
SELECT a.*,c.forename,c.surname FROM credit_assessments a JOIN customers c USING(customer_id)
WHERE assessed_on='2025-12-31';

CREATE VIEW monthly_loan_performance_2025 AS
SELECT month_end, SUM(outstanding_principal) outstanding_principal,
 SUM(interest_accrued) interest_income,SUM(principal_paid) principal_collections,
 SUM(interest_paid) interest_collections,SUM(days_past_due>90) loans_over_90_days,
 SUM(interest_frozen) frozen_interest_loans
FROM loan_month_end WHERE YEAR(month_end)=2025 GROUP BY month_end;

CREATE VIEW bank_profit_2025 AS
SELECT t.*, 'Current-tax-only scenario; deferred tax excluded' AS reporting_basis
FROM tax_reconciliation t;
