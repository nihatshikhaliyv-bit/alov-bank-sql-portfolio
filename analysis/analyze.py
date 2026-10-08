"""Read the supplied MySQL dump as data (never execute it); reproduce snapshot metrics.
Python 3.10+, standard library only. Money is stored in SQLite as integer AZN cents.
Usage: python analysis/analyze.py [path/to/portfolio_snapshot.sql]
"""
from pathlib import Path
from decimal import Decimal
import re, sqlite3, json, sys, hashlib, gzip
ROOT=Path(__file__).resolve().parents[1]
src=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'data/portfolio_snapshot.sql.gz'
payload=gzip.decompress(src.read_bytes()) if src.suffix=='.gz' else src.read_bytes()
s=payload.decode('utf-8')
con=sqlite3.connect(':memory:');con.row_factory=sqlite3.Row
schema={}; money={}
for name,body in re.findall(r'CREATE TABLE `([^`]+)` \((.*?)\n\) ENGINE',s,re.S):
 cols=re.findall(r'^  `([^`]+)` ([^\n]+)',body,re.M)
 schema[name]=[x[0] for x in cols];money[name]=set()
 definitions=[]
 for col,typ in cols:
  if re.match(r'decimal\(\d+,2\)',typ,re.I):money[name].add(col);dtype='INTEGER'
  elif re.match(r'(bigint|int|tinyint|year)',typ,re.I):dtype='INTEGER'
  elif typ.startswith('decimal'):dtype='REAL'
  else:dtype='TEXT'
  definitions.append(f'"{col}" {dtype}')
 con.execute(f'CREATE TABLE "{name}" ({",".join(definitions)})')
token=re.compile(r"'(?:\\.|[^'\\])*'|NULL|-?\d+(?:\.\d+)?",re.S)
row_pattern=re.compile(r"\((?:'(?:\\.|[^'\\])*'|[^()'])*\)")
unescape={'0':'\0','n':'\n','r':'\r','t':'\t','b':'\b','Z':'\x1a'}
for name,values in re.findall(r'^INSERT INTO `([^`]+)` VALUES (.*);$',s,re.M):
 rows=[]
 for match in row_pattern.finditer(values):
  vals=token.findall(match[0]);assert len(vals)==len(schema[name]),(name,len(vals))
  row=[]
  for col,v in zip(schema[name],vals):
   if v=='NULL':row.append(None)
   elif v.startswith("'"):row.append(re.sub(r'\\(.)',lambda m:unescape.get(m[1],m[1]),v[1:-1]))
   elif col in money[name]:row.append(int(Decimal(v)*100))
   elif '.' in v:row.append(float(v))
   else:row.append(int(v))
  rows.append(row)
 con.executemany(f'INSERT INTO "{name}" VALUES ({",".join("?" for _ in schema[name])})',rows)
def q(sql):return [dict(r) for r in con.execute(sql)]
M={'source_sha256':hashlib.sha256(payload).hexdigest(),'snapshot_exported_at':'2026-10-04 12:30:23 (export footer; timezone not recorded)','monetary_units':'AZN except fields explicitly ending _cents; rates/ratios labeled separately',
'counts':{t:con.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0] for t in schema}}
queries={
'financial_totals':'''SELECT reporting_year,COUNT(*) branches, SUM(interest_income)/100.0 interest_income,SUM(fee_income)/100.0 fee_income,SUM(other_income)/100.0 other_income,SUM(total_revenue)/100.0 total_revenue,SUM(interest_expense)/100.0 interest_expense,SUM(operating_expense)/100.0 operating_expense,SUM(total_expenses)/100.0 total_expenses,SUM(net_profit)/100.0 net_profit,SUM(loan_amount)/100.0 reported_loan_amount,SUM(deposit_amount)/100.0 reported_deposit_amount FROM branch_financials GROUP BY reporting_year''',
'accounts':'''SELECT account_type,COUNT(*) accounts,SUM(balance)/100.0 balance,AVG(balance)/100.0 avg_balance,SUM(balance*annual_interest_rate)/100.0/NULLIF(SUM(balance),0) balance_weighted_rate_percent FROM accounts GROUP BY account_type ORDER BY balance DESC''',
'account_status':'''SELECT account_status,activity_status,COUNT(*) accounts,SUM(balance)/100.0 balance FROM accounts GROUP BY account_status,activity_status''',
'loans':'''SELECT loan_type,COUNT(*) loans,SUM(loan_amount)/100.0 original_amount,SUM(outstanding_amount)/100.0 outstanding, SUM(CASE WHEN loan_status='Overdue' THEN outstanding_amount ELSE 0 END)/100.0 overdue_outstanding,SUM(CASE WHEN loan_status='Overdue' THEN 1 ELSE 0 END) overdue_loans,SUM(outstanding_amount*annual_interest_rate)/100.0/NULLIF(SUM(outstanding_amount),0) outstanding_weighted_rate_percent FROM loans GROUP BY loan_type ORDER BY outstanding DESC''',
'loan_status':'''SELECT loan_status,COUNT(*) loans,SUM(loan_amount)/100.0 original_amount,SUM(outstanding_amount)/100.0 outstanding FROM loans GROUP BY loan_status''',
'risk_mix':'''SELECT c.risk_rating,COUNT(DISTINCT c.customer_id) customers,COUNT(l.loan_id) loans,SUM(COALESCE(l.outstanding_amount,0))/100.0 outstanding,SUM(CASE WHEN l.loan_status='Overdue' THEN l.outstanding_amount ELSE 0 END)/100.0 overdue_outstanding FROM customers c LEFT JOIN loans l USING(customer_id) GROUP BY c.risk_rating''',
'customer_employment':'''SELECT employment_status,COUNT(*) customers,AVG(annual_income)/100.0 avg_income FROM customers GROUP BY employment_status ORDER BY customers DESC''',
'customer_cities':'''SELECT city,COUNT(*) customers FROM customers GROUP BY city ORDER BY customers DESC''',
'branches':'''SELECT b.branch_id,b.branch_name,b.city,b.region,b.employee_count,f.reporting_year,f.total_revenue/100.0 total_revenue,f.net_profit/100.0 net_profit,f.operating_expense/100.0 operating_expense,f.loan_amount/100.0 reported_loan_amount,f.deposit_amount/100.0 reported_deposit_amount FROM branches b JOIN branch_financials f USING(branch_id) ORDER BY net_profit DESC''',
'regions':'''SELECT b.region,COUNT(*) branches,SUM(f.total_revenue)/100.0 total_revenue,SUM(f.net_profit)/100.0 net_profit,SUM(f.loan_amount)/100.0 reported_loan_amount,SUM(f.deposit_amount)/100.0 reported_deposit_amount FROM branches b JOIN branch_financials f USING(branch_id) GROUP BY b.region ORDER BY net_profit DESC''',
'monthly_transactions':'''SELECT substr(transaction_date,1,7) month,COUNT(*) transactions,SUM(amount)/100.0 gross_amount FROM transactions GROUP BY month ORDER BY month''',
'monthly_types':'''SELECT substr(transaction_date,1,7) month,transaction_type,COUNT(*) transactions,SUM(amount)/100.0 gross_amount FROM transactions GROUP BY month,transaction_type ORDER BY month,transaction_type''',
'date_ranges':'''SELECT 'transactions' entity,MIN(transaction_date) earliest,MAX(transaction_date) latest FROM transactions UNION ALL SELECT 'loan issue',MIN(issue_date),MAX(issue_date) FROM loans UNION ALL SELECT 'account opening',MIN(opened_date),MAX(opened_date) FROM accounts UNION ALL SELECT 'customer registration',MIN(registered_date),MAX(registered_date) FROM customers''',
'branch_balance_reconciliation':'''SELECT b.branch_id,b.branch_name,f.deposit_amount/100.0 reported_deposits,COALESCE(a.bal,0)/100.0 account_balance, f.loan_amount/100.0 reported_loans,COALESCE(l.original,0)/100.0 original_loans,COALESCE(l.outstanding,0)/100.0 outstanding_loans FROM branches b JOIN branch_financials f USING(branch_id) LEFT JOIN (SELECT branch_id,SUM(balance) bal FROM accounts GROUP BY branch_id) a USING(branch_id) LEFT JOIN (SELECT branch_id,SUM(loan_amount) original,SUM(outstanding_amount) outstanding FROM loans GROUP BY branch_id) l USING(branch_id)''',
'concentration':'''SELECT 'top_10_deposit_customers' metric,SUM(x)/100.0 amount FROM (SELECT customer_id,SUM(balance) x FROM accounts GROUP BY customer_id ORDER BY x DESC LIMIT 10) UNION ALL SELECT 'top_10_borrowers',SUM(x)/100.0 FROM (SELECT customer_id,SUM(outstanding_amount) x FROM loans GROUP BY customer_id ORDER BY x DESC LIMIT 10)''',
'coverage':'''SELECT COUNT(DISTINCT customer_id) borrowers FROM loans''',
'profit_checks':'''SELECT SUM(CASE WHEN total_revenue<>interest_income+fee_income+other_income THEN 1 ELSE 0 END) revenue_mismatches,SUM(CASE WHEN total_expenses<>interest_expense+operating_expense THEN 1 ELSE 0 END) expense_mismatches,SUM(CASE WHEN net_profit<>total_revenue-total_expenses THEN 1 ELSE 0 END) profit_mismatches,MIN(net_profit)/100.0 min_branch_profit FROM branch_financials''',
'data_quality':'''SELECT 'transactions_nonpositive' check_name,COUNT(*) issues FROM transactions WHERE amount<=0 UNION ALL SELECT 'transaction_owner_or_branch_mismatch',COUNT(*) FROM transactions t JOIN accounts a USING(account_id) WHERE t.customer_id<>a.customer_id OR t.branch_id<>a.branch_id UNION ALL SELECT 'negative_account_balances',COUNT(*) FROM accounts WHERE balance<0 UNION ALL SELECT 'loan_outstanding_outside_original',COUNT(*) FROM loans WHERE outstanding_amount<0 OR outstanding_amount>loan_amount UNION ALL SELECT 'paid_loans_with_balance',COUNT(*) FROM loans WHERE loan_status='Paid' AND outstanding_amount<>0 UNION ALL SELECT 'transactions_after_snapshot_date',COUNT(*) FROM transactions WHERE transaction_date>'2026-10-04' UNION ALL SELECT 'transactions_before_account_opening',COUNT(*) FROM transactions t JOIN accounts a USING(account_id) WHERE t.transaction_date<a.opened_date UNION ALL SELECT 'loans_before_customer_registration',COUNT(*) FROM loans l JOIN customers c USING(customer_id) WHERE l.issue_date<c.registered_date UNION ALL SELECT 'accounts_before_customer_registration',COUNT(*) FROM accounts a JOIN customers c USING(customer_id) WHERE a.opened_date<c.registered_date''',
'legacy_balance_reconciliation':'''SELECT COUNT(*) mismatches, COALESCE(SUM(ABS(a.balance-a.opening_balance-COALESCE(t.net,0))),0)/100.0 absolute_difference FROM accounts a LEFT JOIN (SELECT account_id,SUM(CASE WHEN transaction_type IN ('Deposit','Transfer In') THEN amount ELSE -amount END) net FROM transactions GROUP BY account_id) t USING(account_id) WHERE a.balance<>a.opening_balance+COALESCE(t.net,0)''',
'loan_dates':'''SELECT SUM(CASE WHEN issue_date>maturity_date THEN 1 ELSE 0 END) invalid_terms,SUM(CASE WHEN loan_status='Active' AND maturity_date<'2026-10-04' AND outstanding_amount>0 THEN 1 ELSE 0 END) active_past_maturity FROM loans''',
'customer_age':'''SELECT MIN((julianday('2026-10-04')-julianday(date_of_birth))/365.2425) min_age,MAX((julianday('2026-10-04')-julianday(date_of_birth))/365.2425) max_age FROM customers''',
'product_transactions':'''SELECT transaction_type,COUNT(*) transactions,SUM(amount)/100.0 gross_amount FROM transactions GROUP BY transaction_type'''
}
queries.update({
'annual_interest_by_status':"SELECT loan_status,ROUND(SUM(outstanding_amount*annual_interest_rate)/1000000.0,2) annualized_interest FROM loans GROUP BY loan_status",
'patterns_by_account':"SELECT MIN(d) min_deposits,MAX(d) max_deposits,MIN(w) min_withdrawals,MAX(w) max_withdrawals,MIN(f) min_fees,MAX(f) max_fees FROM (SELECT account_id,SUM(transaction_type='Deposit') d,SUM(transaction_type='Withdrawal') w,SUM(transaction_type='Fee') f FROM transactions GROUP BY account_id)",
'annual_interest_model':"SELECT ROUND(SUM(outstanding_amount*annual_interest_rate)/1000000.0,2) annualized_loan_interest FROM loans",
'annual_deposit_model':"SELECT ROUND(SUM(balance*annual_interest_rate)/1000000.0,2) annualized_deposit_interest FROM accounts",
'account_transaction_pattern':"SELECT min(n) min_transactions,max(n) max_transactions,count(*) accounts_with_transactions FROM (SELECT account_id,count(*) n FROM transactions GROUP BY account_id)",
'last_activity_by_type':"SELECT transaction_type,MIN(transaction_date) earliest,MAX(transaction_date) latest FROM transactions GROUP BY transaction_type",
'branch_interest_model':"SELECT f.branch_id,f.interest_income/100.0 reported_interest,ROUND(x.model/1000000.0,2) annualized_interest FROM branch_financials f JOIN (SELECT branch_id,SUM(outstanding_amount*annual_interest_rate) model FROM loans GROUP BY branch_id) x USING(branch_id)",
'foreign_key_checks':"SELECT 'orphan_accounts_customer' check_name,COUNT(*) issues FROM accounts a LEFT JOIN customers c USING(customer_id) WHERE c.customer_id IS NULL UNION ALL SELECT 'orphan_accounts_branch',COUNT(*) FROM accounts a LEFT JOIN branches b USING(branch_id) WHERE b.branch_id IS NULL UNION ALL SELECT 'orphan_loans_customer',COUNT(*) FROM loans l LEFT JOIN customers c USING(customer_id) WHERE c.customer_id IS NULL UNION ALL SELECT 'orphan_transactions_account',COUNT(*) FROM transactions t LEFT JOIN accounts a USING(account_id) WHERE a.account_id IS NULL"
})
for name,sql in queries.items():M[name]=q(sql)
f=M['financial_totals'][0]
rev=f['total_revenue'];nii=f['interest_income']-f['interest_expense'];operating_income=nii+f['fee_income']+f['other_income']
outstanding=sum(x['outstanding'] for x in M['loans']);deposits=sum(x['balance'] for x in M['accounts']);overdue=sum(x['overdue_outstanding'] for x in M['loans'])
M['derived']={'net_interest_income':nii,'operating_income_net_of_interest_cost':operating_income,'profit_margin_percent':f['net_profit']/rev*100,'operating_cost_to_income_percent':f['operating_expense']/operating_income*100,'total_expense_to_gross_revenue_percent':f['total_expenses']/rev*100,'outstanding_loans':outstanding,'account_balances':deposits,'outstanding_loan_to_deposit_percent':outstanding/deposits*100,'reported_loan_to_deposit_percent':f['reported_loan_amount']/f['reported_deposit_amount']*100,'overdue_outstanding':overdue,'overdue_exposure_percent':overdue/outstanding*100,'borrower_penetration_percent':M['coverage'][0]['borrowers']/M['counts']['customers']*100,'accounts_per_customer':M['counts']['accounts']/M['counts']['customers'],'top5_branch_profit_share_percent':sum(x['net_profit'] for x in M['branches'][:5])/f['net_profit']*100,'staff':sum(x['employee_count'] for x in M['branches'])}
(ROOT/'analysis/snapshot_metrics.json').write_text(json.dumps(M,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:M[k] for k in ['counts','financial_totals','derived','date_ranges','profit_checks','data_quality','legacy_balance_reconciliation','loan_dates']},indent=2))
