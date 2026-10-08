-- Run on the expanded demo after restore. No data is changed.
USE banking_portfolio_demo;
SELECT 'customers' AS entity,COUNT(*) AS rows_found FROM customers
UNION ALL SELECT 'accounts',COUNT(*) FROM accounts
UNION ALL SELECT 'loans',COUNT(*) FROM loans
UNION ALL SELECT 'transactions',COUNT(*) FROM transactions;
-- Expected initial expanded counts: 30000 / 45449 / 16000 / 14585400.
-- Counts change if you subsequently post new transactions.
SELECT MIN(transaction_date) AS first_date,MAX(transaction_date) AS last_date FROM transactions;
SELECT COUNT(*) AS invalid_amounts FROM transactions WHERE amount<=0;
SELECT COUNT(*) AS ownership_or_branch_mismatches FROM transactions t
JOIN accounts a ON a.account_id=t.account_id
WHERE t.customer_id<>a.customer_id OR t.branch_id<>a.branch_id;
SELECT reporting_year,
 SUM(total_revenue-interest_income-fee_income-other_income) AS revenue_difference,
 SUM(total_expenses-interest_expense-operating_expense) AS expense_difference,
 SUM(net_profit-total_revenue+total_expenses) AS profit_difference
FROM branch_financials GROUP BY reporting_year;
-- Run the following only AFTER the demo-specific V2 upgrade has completed:
CALL sp_bank_health_check();
SELECT * FROM bank_gl_trial_balance;
SELECT * FROM bank_gl_account_reconciliation WHERE difference<>0;
SELECT * FROM bank_gl_loan_reconciliation WHERE difference<>0;
