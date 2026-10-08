-- TEST ONLY: run on a disposable, twice-upgraded SEED copy. It changes test data.
-- Not for your working database or the expanded-history scenario.
USE banking_portfolio_fresh;
CREATE TABLE test_results (test_name VARCHAR(100),result VARCHAR(10));
DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE test_assert(IN p_name VARCHAR(100), IN p_ok BOOLEAN)
BEGIN
 IF p_ok IS NULL OR NOT p_ok THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT=p_name; END IF;
 INSERT INTO test_results VALUES(p_name,'PASS');
END$$
CREATE DEFINER=`root`@`localhost` PROCEDURE test_failure(IN p_case INT)
BEGIN
 DECLARE failed BOOLEAN DEFAULT FALSE;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET failed=TRUE;
  CASE p_case
   WHEN 1 THEN CALL sp_post_transaction('TEST:DEPOSIT','Deposit',NULL,@a,10,'duplicate');
   WHEN 2 THEN CALL sp_post_transaction('TEST:NEG','Deposit',NULL,@a,-10,'negative');
   WHEN 3 THEN CALL sp_post_transaction('TEST:ZERO','Deposit',NULL,@a,0,'zero');
   WHEN 4 THEN CALL sp_post_transaction('TEST:FUNDS','Withdrawal',@a,NULL,99999999999,'insufficient');
   WHEN 5 THEN CALL sp_post_transaction('TEST:SAME','Transfer',@a,@a,1,'same');
   WHEN 6 THEN CALL sp_post_transaction('TEST:MISSING','Deposit',NULL,2147483647,1,'missing');
   WHEN 7 THEN CALL sp_post_transaction('TEST:LIMIT','Transfer',@a,@b,1001,'approval needed');
   WHEN 8 THEN CALL sp_reverse_operation('TEST:REVERSE2',@transfer,'twice');
   WHEN 9 THEN UPDATE transactions SET amount=amount+1 WHERE transaction_id=@tx;
   WHEN 10 THEN DELETE FROM transaction_audit WHERE transaction_id=@tx;
   WHEN 11 THEN CALL sp_decide_transfer(@request,TRUE,'self approval');
   WHEN 12 THEN CALL sp_post_transaction('TEST:GLFAIL','Deposit',NULL,@a,10,'force GL error');
   WHEN 13 THEN CALL sp_post_transaction('TEST:FROZEN','Withdrawal',@a,NULL,1,'frozen');
   WHEN 14 THEN CALL sp_accrue_account_interest(@interest_account,UTC_DATE());
   WHEN 15 THEN CALL sp_pay_loan_installment('TEST:OVERPAY',@payer,@installment,99999999999);
   WHEN 16 THEN CALL sp_post_transaction('TEST:CLOSED','Deposit',NULL,@closed,10,'closed');
   WHEN 17 THEN UPDATE bank_gl_journals SET description='change' WHERE journal_key='OPENING-V2';
   WHEN 18 THEN DELETE FROM bank_gl_lines WHERE journal_id=(SELECT journal_id FROM bank_gl_journals WHERE journal_key='OPENING-V2') LIMIT 1;
  END CASE;
 END;
 CALL test_assert(CONCAT('Expected rejection ',p_case),failed);
END$$
DELIMITER ;
CALL test_assert('Restored all customers',(SELECT COUNT(*)=30000 FROM customers));
CALL test_assert('Restored all accounts',(SELECT COUNT(*)=45449 FROM accounts));
CALL test_assert('Restored all transactions',(SELECT COUNT(*)=363592 FROM transactions));
CALL test_assert('Repeat install: one opening journal',(SELECT COUNT(*)=1 FROM bank_gl_journals));
CALL test_assert('Opening account GL reconciliation',(SELECT COUNT(*)=0 FROM bank_gl_account_reconciliation WHERE difference<>0));
CALL test_assert('Opening loan GL reconciliation',(SELECT COUNT(*)=0 FROM bank_gl_loan_reconciliation WHERE difference<>0));
SET @a=(SELECT MIN(account_id) FROM accounts WHERE account_status='Active' AND balance>2000);
SET @b=(SELECT MIN(account_id) FROM accounts WHERE account_status='Active' AND account_id<>@a);
SET @a_start=(SELECT balance FROM accounts WHERE account_id=@a);
SET @b_start=(SELECT balance FROM accounts WHERE account_id=@b);
CALL sp_post_transaction('TEST:DEPOSIT','Deposit',NULL,@a,10,'test deposit');
CALL test_assert('Deposit updates balance',(SELECT balance=@a_start+10 FROM accounts WHERE account_id=@a));
SET @tx=(SELECT MAX(transaction_id) FROM transactions);
CALL test_failure(1);
CALL test_failure(2);
CALL test_failure(3);
CALL test_failure(4);
CALL test_failure(5);
CALL test_failure(6);
CALL test_failure(7);
CALL test_assert('Rejected postings leave balance unchanged',(SELECT balance=@a_start+10 FROM accounts WHERE account_id=@a));
CALL sp_post_transaction('TEST:TRANSFER','Transfer',@a,@b,25,'test transfer');
SET @transfer=(SELECT operation_id FROM bank_operations WHERE request_key='TEST:TRANSFER');
CALL test_assert('Transfer debits source',(SELECT balance=@a_start-15 FROM accounts WHERE account_id=@a));
CALL test_assert('Transfer credits destination',(SELECT balance=@b_start+25 FROM accounts WHERE account_id=@b));
CALL sp_reverse_operation('TEST:REVERSE',@transfer,'test reversal');
CALL test_assert('Reversal restores both balances', (SELECT balance=@a_start+10 FROM accounts WHERE account_id=@a) AND (SELECT balance=@b_start FROM accounts WHERE account_id=@b));
CALL test_failure(8);
CALL test_failure(9);
CALL test_failure(10);
CALL sp_post_transaction('TEST:FEE','Fee',@a,NULL,2,'fee');
CALL sp_post_transaction('TEST:WITHDRAWAL','Withdrawal',@a,NULL,3,'withdrawal');
CALL test_assert('Fee and withdrawal applied',(SELECT balance=@a_start+5 FROM accounts WHERE account_id=@a));
CALL sp_set_account_control(@a,'Active',TRUE,'freeze test');
CALL test_failure(13);
CALL sp_set_account_control(@a,'Active',FALSE,'unfreeze test');
SET @closed=(SELECT MIN(account_id) FROM accounts WHERE account_status='Closed');
CALL test_failure(16);
CALL sp_request_transfer('TEST:REQUEST',@a,@b,1001,'approval workflow test');
SET @request=(SELECT request_id FROM bank_transfer_requests WHERE request_key='TEST:REQUEST');
CALL test_failure(11);
-- Test fixture only: simulate request created by a different login.
-- This checks approval logic, not real login/role authentication.
UPDATE bank_transfer_requests SET requested_by='test_other_user@localhost' WHERE request_id=@request;
CALL sp_decide_transfer(@request,TRUE,'approve test');
CALL test_assert('Approval posts once',(SELECT status='Approved' AND operation_id IS NOT NULL FROM bank_transfer_requests WHERE request_id=@request));
CALL test_failure(11);
SET @pre=(SELECT balance FROM accounts WHERE account_id=@a);
SET @n=(SELECT COUNT(*) FROM transactions);
DELIMITER $$
CREATE DEFINER=`root`@`localhost` TRIGGER test_fail_gl BEFORE INSERT ON bank_gl_journals FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Test injected ledger failure'$$
DELIMITER ;
CALL test_failure(12);
CALL test_assert('GL failure rolls back account',(SELECT balance=@pre FROM accounts WHERE account_id=@a));
CALL test_assert('GL failure rolls back transaction',(SELECT COUNT(*)=@n FROM transactions));
CALL test_assert('GL failure rolls back operation',(SELECT COUNT(*)=0 FROM bank_operations WHERE request_key='TEST:GLFAIL'));
DROP TRIGGER test_fail_gl;
SET @loan=(SELECT MIN(l.loan_id) FROM loans l WHERE outstanding_amount>10 AND maturity_date>UTC_DATE()+INTERVAL 1 MONTH AND EXISTS(SELECT 1 FROM accounts a WHERE a.customer_id=l.customer_id AND a.account_status='Active' AND a.balance>100));
SET @payer=(SELECT MIN(a.account_id) FROM accounts a JOIN loans l ON l.customer_id=a.customer_id WHERE l.loan_id=@loan AND a.account_status='Active' AND a.balance>100);
SET @principal=(SELECT outstanding_amount FROM loans WHERE loan_id=@loan);
CALL sp_create_loan_schedule(@loan,1,UTC_DATE()+INTERVAL 1 DAY);
SET @installment=(SELECT installment_id FROM bank_loan_installments WHERE loan_id=@loan);
CALL sp_pay_loan_installment('TEST:LOANPAY',@payer,@installment,10);
CALL test_assert('Loan allocation totals payment',(SELECT principal_amount+interest_amount=10 FROM bank_loan_payments p JOIN bank_operations o USING(operation_id) WHERE o.request_key='TEST:LOANPAY'));
SET @loan_op=(SELECT operation_id FROM bank_operations WHERE request_key='TEST:LOANPAY');
CALL sp_reverse_operation('TEST:LOANREV',@loan_op,'reverse test payment');
CALL test_assert('Loan reversal restores principal',(SELECT outstanding_amount=@principal FROM loans WHERE loan_id=@loan));
CALL test_assert('Loan reversal clears installment',(SELECT principal_paid+interest_paid=0 FROM bank_loan_installments WHERE installment_id=@installment));
CALL test_failure(15);
SET @interest_account=(SELECT MIN(c.account_id) FROM bank_account_controls c JOIN accounts a USING(account_id) WHERE c.interest_rate>0 AND a.account_status='Active' AND a.balance>1000);
SET @next_day=(SELECT last_interest_day+INTERVAL 1 DAY FROM bank_account_controls WHERE account_id=@interest_account);
-- This backup's last interest day is 2026-10-03; test clock must be after 2026-10-04.
CALL sp_accrue_account_interest(@interest_account,@next_day);
CALL test_assert('Interest writes GL journal',(SELECT COUNT(*)=1 FROM bank_interest_accruals a JOIN bank_gl_journals j USING(operation_id) WHERE a.account_id=@interest_account AND a.accrual_date=@next_day AND j.status='Posted'));
CALL test_failure(14);
CALL test_failure(17);
CALL test_failure(18);
CALL test_assert('All account balances reconcile',(SELECT COUNT(*)=0 FROM bank_balance_reconciliation WHERE difference<>0));
CALL test_assert('All GL account balances reconcile',(SELECT COUNT(*)=0 FROM bank_gl_account_reconciliation WHERE difference<>0));
CALL test_assert('All GL loan balances reconcile',(SELECT COUNT(*)=0 FROM bank_gl_loan_reconciliation WHERE difference<>0));
CALL test_assert('All loan schedules reconcile',(SELECT COUNT(*)=0 FROM bank_loan_reconciliation WHERE difference<>0));
CALL test_assert('Every operation linked to posted journal',(SELECT COUNT(*)=0 FROM bank_operations o LEFT JOIN bank_gl_journals j USING(operation_id) WHERE j.journal_id IS NULL OR j.status<>'Posted'));
CALL test_assert('Trial balance balances',(SELECT SUM(debit_balance)=0 FROM bank_gl_trial_balance));
SELECT test_name,result FROM test_results;
