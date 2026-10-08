USE banking_portfolio_2025;
SELECT 'Principal conservation' check_name,COUNT(*) issues FROM loan_reconciliation WHERE principal_difference<>0
UNION ALL SELECT 'Interest conservation',COUNT(*) FROM loan_reconciliation WHERE interest_difference<>0
UNION ALL SELECT 'Negative loan amounts',COUNT(*) FROM loans WHERE outstanding_amount<0 OR interest_receivable<0 OR outstanding_amount>loan_amount
UNION ALL SELECT 'Interest cap',COUNT(*) FROM arrears_episodes WHERE charged_days>90
UNION ALL SELECT 'Future payments',COUNT(*) FROM loan_payments WHERE paid_on>'2025-12-31'
UNION ALL SELECT 'Future restructuring',COUNT(*) FROM restructurings WHERE effective_date>'2025-12-31'
UNION ALL SELECT 'Wrong payment components',COUNT(*) FROM loan_payments WHERE total_paid<>principal_paid+interest_paid OR total_paid<=0
UNION ALL SELECT 'Wrong restructuring projection',COUNT(*) FROM restructurings WHERE new_projected_interest<=old_projected_interest
UNION ALL SELECT 'Unapproved rate changes',COUNT(*) FROM loans l WHERE current_rate<>original_rate AND NOT EXISTS(SELECT 1 FROM restructurings r WHERE r.loan_id=l.loan_id)
UNION ALL SELECT 'Missing income months',COUNT(*) FROM (SELECT customer_id,COUNT(*) n FROM customer_income WHERE YEAR(month_end)=2025 GROUP BY customer_id HAVING n<>12) x
UNION ALL SELECT 'Customer count',ABS(COUNT(*)-30000) FROM customers
UNION ALL SELECT 'Loan count',ABS(COUNT(*)-16000) FROM loans
UNION ALL SELECT 'Rented branch count',ABS(COUNT(*)-20) FROM premises WHERE tenure='Rented'
UNION ALL SELECT 'Owned branch count',ABS(COUNT(*)-5) FROM premises WHERE tenure='Owned'
UNION ALL SELECT 'Rent split',COUNT(*) FROM premises_monthly WHERE gross_rent<>landlord_cash+withholding
UNION ALL SELECT 'Lease payment split',COUNT(*) FROM premises_monthly WHERE gross_rent<>lease_interest+lease_principal
UNION ALL SELECT 'Tax payable',COUNT(*) FROM tax_reconciliation WHERE tax_payable<>current_tax-advances_paid
UNION ALL SELECT 'Tax rate',COUNT(*) FROM tax_reconciliation WHERE current_tax<>ROUND(GREATEST(taxable_profit_before_losses,0)*0.20,2)
UNION ALL SELECT 'Tax reconciliation',COUNT(*) FROM tax_reconciliation WHERE taxable_profit_before_losses<>profit_before_tax+lease_book_cost_added_back-contractual_rent_deducted+owned_book_depreciation_added_back-owned_tax_depreciation_deducted+impairment_added_back
UNION ALL SELECT 'Profit reconciliation',COUNT(*) FROM tax_reconciliation WHERE profit_after_current_tax<>profit_before_tax-current_tax
UNION ALL SELECT 'Blocked lending limits',COUNT(*) FROM credit_assessments WHERE decision LIKE 'Decline:%' AND illustrative_personal_limit<>0
UNION ALL SELECT 'Loan balance month-end tie',COUNT(*) FROM loans l JOIN loan_month_end m ON m.loan_id=l.loan_id AND m.month_end='2025-12-31' WHERE l.outstanding_amount<>m.outstanding_principal OR l.interest_receivable<>m.interest_receivable
UNION ALL SELECT 'Orphan loan',COUNT(*) FROM loans l LEFT JOIN customers c USING(customer_id) WHERE c.customer_id IS NULL
UNION ALL SELECT 'Orphan payment',COUNT(*) FROM loan_payments p LEFT JOIN loans l USING(loan_id) WHERE l.loan_id IS NULL
UNION ALL SELECT 'Premises liability rollforward',COUNT(*) FROM premises p JOIN (SELECT branch_id,SUM(lease_principal) paid FROM premises_monthly GROUP BY branch_id) x USING(branch_id) JOIN premises_monthly m ON m.branch_id=p.branch_id AND m.month_end='2025-12-31' WHERE p.tenure='Rented' AND p.initial_lease_liability-x.paid<>m.closing_lease_liability
UNION ALL SELECT 'Premises asset rollforward',COUNT(*) FROM premises p JOIN (SELECT branch_id,SUM(depreciation) dep FROM premises_monthly GROUP BY branch_id) x USING(branch_id) JOIN premises_monthly m ON m.branch_id=p.branch_id AND m.month_end='2025-12-31' WHERE p.initial_rou_asset+p.owned_opening_cost-x.dep<>m.closing_asset
UNION ALL SELECT 'Withholding rollforward',COUNT(*) FROM (SELECT branch_id,SUM(withholding)-SUM(withholding_remitted) owed FROM premises_monthly GROUP BY branch_id) x JOIN premises_monthly m ON m.branch_id=x.branch_id AND m.month_end='2025-12-31' WHERE x.owed<>m.withholding_payable
UNION ALL SELECT 'Branch profit totals',COUNT(*) FROM tax_reconciliation WHERE profit_before_tax<>(SELECT SUM(profit_before_tax) FROM branch_financials)
UNION ALL SELECT 'Branch interest totals',COUNT(*) FROM (SELECT SUM(interest_income) n FROM branch_financials) x WHERE x.n<>(SELECT SUM(interest_accrued) FROM loan_month_end WHERE YEAR(month_end)=2025)
UNION ALL SELECT 'Tax advance totals',COUNT(*) FROM tax_reconciliation WHERE advances_paid<>(SELECT SUM(amount) FROM tax_payments)
UNION ALL SELECT 'Expired exclusion offered early',COUNT(*) FROM credit_assessments WHERE assessed_on<blocked_until AND illustrative_personal_limit<>0
UNION ALL SELECT 'Income orphan',COUNT(*) FROM customer_income i LEFT JOIN customers c USING(customer_id) WHERE c.customer_id IS NULL;

SELECT * FROM bank_profit_2025;
SELECT * FROM monthly_loan_performance_2025 ORDER BY month_end;
