-- HOW TO RUN IN DBGATE
-- 1. Keep the portfolio backup you exported.
-- 2. Connect as your database administrator and select banking_portfolio_demo.
-- 3. Open this .sql file in the SQL editor and execute the WHOLE script.
--    Use the same full-script execution mode that you used for your original SQL.
-- 4. Install while no other users/jobs are posting transactions. Keep both daily
--    events paused during installation and restore their prior states afterward.
-- 5. Check the result from sp_bank_health_check at the end. Zero is expected for
--    reconciliation issues. Outstanding loans without schedules is a separate
--    coverage warning, not evidence that their balances are wrong.
--
-- WHAT WAS FOUND IN YOUR EXPORT
-- 30,000 customers; 45,449 accounts; 16,000 loans; 363,592 transactions.
-- Transfers, reversals, repayments, interest and schedules already existed.
-- The transaction ID lacked AUTO_INCREMENT, and the transaction type ENUM lacked
-- Interest/Reversal In/Reversal Out. Those defects are repaired here.
-- Existing accounts, balances, historical transactions and financial reports stay.
--
-- WHAT THIS UPGRADE ADDS
-- Balanced general-ledger journals, linked atomically to new bank operations;
-- account/loan reconciliation; trial balance; monthly ledger income/expenses;
-- loan aging (unscheduled loans are explicitly labeled); expanded change auditing;
-- immutable transaction and journal records; two-user transfer approval;
-- named teller/manager/auditor roles and a health-check procedure.
-- The AZN 1,000 per-transfer approval threshold is a DEMO POLICY, not a legal rule.
-- Splitting transfers can bypass a per-transfer threshold; no daily aggregate
-- transaction-monitoring policy is claimed.
--
-- READ-ONLY QUERIES AFTER INSTALLATION
-- CALL sp_bank_health_check();
-- SELECT * FROM bank_gl_trial_balance;
-- SELECT * FROM bank_gl_monthly_profit;
-- SELECT * FROM bank_loan_aging LIMIT 100;
-- SELECT * FROM bank_change_audit ORDER BY audit_id DESC LIMIT 100;
--
-- EXAMPLES (COMMENTED: they are NOT executed by installing this file)
-- Use your actual IDs and a NEW request key for each distinct operation.
-- CALL sp_post_transaction('my-deposit-001','Deposit',NULL,1,100,'Cash deposit');
-- CALL sp_post_transaction('my-transfer-001','Transfer',1,2,50,'Customer transfer');
-- CALL sp_request_transfer('my-transfer-002',1,2,1500,'Needs approval');
-- Log in as a DIFFERENT authorized database user, then:
-- CALL sp_decide_transfer(<request_id>,TRUE,'Approved after review');
-- CALL sp_reverse_operation('my-reversal-001',<operation_id>,'Correction reason');
-- CALL sp_create_loan_schedule(<loan_id>,12,<future_first_due_date>);
-- CALL sp_pay_loan_installment('my-payment-001',<account_id>,<installment_id>,100);
-- Posting procedures own their transactions: call them outside a caller-managed
-- transaction. A repeated request key is rejected, not silently posted twice.
--
-- PERMISSIONS: ROLES ARE CREATED, BUT ARE NOT ASSIGNED TO YOUR EXISTING USERS.
-- Administrator examples, after creating separate authenticated users:
-- GRANT 'bp2_teller' TO 'your_teller'@'localhost';
-- SET DEFAULT ROLE 'bp2_teller' TO 'your_teller'@'localhost';
-- GRANT 'bp2_manager' TO 'your_manager'@'localhost';
-- SET DEFAULT ROLE 'bp2_manager' TO 'your_manager'@'localhost';
-- Do not give staff global EXECUTE, direct table writes, DDL, or root rights.
-- The @bp_posting flag is an accidental-write guard, NOT a security boundary.
-- Administrators can bypass/drop controls. Roles do not revoke earlier grants.
--
-- VALIDATION: 45 checks passed on a complete restored copy using MySQL 8.4.11.
-- Used MySQL's initialization SQL runner because normal local socket connections
-- were unavailable. Test-only explicit root definers replaced implicit definers.
-- Covered two successive installations, original row counts, opening balances,
-- transfers, deposits, fees, withdrawals, reversals, insufficient funds, frozen
-- and missing accounts, zero/negative amounts, duplicate keys, loan allocation,
-- interest, immutable records, approval logic and injected GL-failure rollback.
-- All resulting account/loan/GL reconciliations and trial balance matched.
-- Real separate-user authentication, concurrent sessions, scheduler execution,
-- DbGate's script runner and your specific MySQL 26.7 server were NOT tested.
--
-- SCOPE AND ACCOUNTING LIMITS
-- This is an educational banking-operations upgrade, not a complete production
-- banking system. KYC/AML integrations, loan origination/disbursement, FX,
-- accrual-based loan income, tax/provisions, payroll/operating-expense posting,
-- period close, disaster recovery and external settlement are not implemented.
-- Opening GL balances use a disclosed migration offset. That offset must not be
-- presented as verified equity, and cash starts as post-activation movements.
-- Monthly GL profit covers only newly posted supported operations. It is NOT
-- a complete company P&L and does not replace your historical branch_financials.
-- Loan interest income is recognized when paid in this demonstration.
-- Schedules are NOT invented for the 16,000 historical loans: actual remaining
-- terms and approved due dates are needed. Existing equal-principal schedule
-- logic is retained. Read bank_loan_aging to distinguish unscheduled loans.
-- New account/loan onboarding with nonzero balances needs a corresponding GL
-- migration/origination operation; do not manually add such balances and assume
-- they will reconcile. This file targets the uploaded existing portfolio.
-- Daily processing retains UTC day boundaries. Server event_scheduler is not
-- enabled by this file. Backup scheduling is an external operational task.
-- Keep a backup: schema changes implicitly commit and cannot be rolled back
-- as one SQL transaction. On an error, stop, keep the exact error, and do not
-- continue posting until installation is repaired. The file supports reruns.
--
-- Banking portfolio upgrade 2: MySQL 8.0.16+ / MySQL 26.7.
-- RUN THIS WHOLE FILE on your EXISTING banking_portfolio_demo database.
-- Maintenance window: stop other writers and daily jobs while installing.
-- Does not delete/reload customer data. DDL is NOT transactionally reversible.
-- Existing customer balances are preserved; opening GL uses a disclosed migration offset.
-- Run using an administrator. Roles are created but no users/passwords are created.
-- UTC dates match your existing procedures. AZN-only educational implementation.
USE banking_portfolio_demo;
SET NAMES utf8mb4;
SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION,ONLY_FULL_GROUP_BY';
-- Repair blockers in supplied backup.
DROP PROCEDURE IF EXISTS bp2_prepare_transaction_id;
DELIMITER $$
CREATE PROCEDURE bp2_prepare_transaction_id()
BEGIN
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema=DATABASE()
  AND table_name='transactions' AND column_name='transaction_id' AND extra LIKE '%auto_increment%') THEN
  IF EXISTS(SELECT 1 FROM information_schema.referential_constraints WHERE constraint_schema=DATABASE()
   AND table_name='bank_entry_links' AND constraint_name='bank_entry_links_ibfk_1') THEN
   ALTER TABLE bank_entry_links DROP FOREIGN KEY bank_entry_links_ibfk_1;
  END IF;
  ALTER TABLE transactions MODIFY transaction_id INT NOT NULL AUTO_INCREMENT;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.referential_constraints WHERE constraint_schema=DATABASE()
  AND table_name='bank_entry_links' AND constraint_name='bank_entry_links_ibfk_1') THEN
  ALTER TABLE bank_entry_links ADD CONSTRAINT bank_entry_links_ibfk_1 FOREIGN KEY(transaction_id) REFERENCES transactions(transaction_id);
 END IF;
END$$
DELIMITER ;
CALL bp2_prepare_transaction_id();
DROP PROCEDURE bp2_prepare_transaction_id;
ALTER TABLE transactions MODIFY transaction_type ENUM('Deposit','Withdrawal','Transfer In','Transfer Out','Loan Payment','Fee','Interest','Reversal In','Reversal Out') NOT NULL;

CREATE TABLE IF NOT EXISTS bank_gl_accounts (
 gl_code VARCHAR(20) PRIMARY KEY,
 gl_name VARCHAR(100) NOT NULL,
 category ENUM('Asset','Liability','Equity','Income','Expense') NOT NULL
) ENGINE=InnoDB;
INSERT IGNORE INTO bank_gl_accounts VALUES
 ('1000','Cash movements since GL activation','Asset'),
 ('1100','Loan principal receivable','Asset'),
 ('2000','Customer deposit liability','Liability'),
 ('3000','Migration opening offset - requires accounting review','Equity'),
 ('4000','Loan interest receipts','Income'),
 ('4100','Fee income','Income'),
 ('5000','Deposit interest expense','Expense');
CREATE TABLE IF NOT EXISTS bank_gl_journals (
 journal_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 operation_id BIGINT UNSIGNED NULL UNIQUE,
 journal_key VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
 journal_date DATE NOT NULL,
 description VARCHAR(255) NOT NULL,
 status ENUM('Draft','Posted') NOT NULL DEFAULT 'Draft',
 created_by VARCHAR(288) NOT NULL,
 created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 FOREIGN KEY(operation_id) REFERENCES bank_operations(operation_id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS bank_gl_lines (
 line_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 journal_id BIGINT UNSIGNED NOT NULL,
 gl_code VARCHAR(20) NOT NULL,
 account_id INT NULL,
 loan_id INT NULL,
 debit DECIMAL(18,2) NOT NULL DEFAULT 0,
 credit DECIMAL(18,2) NOT NULL DEFAULT 0,
 FOREIGN KEY(journal_id) REFERENCES bank_gl_journals(journal_id),
 FOREIGN KEY(gl_code) REFERENCES bank_gl_accounts(gl_code),
 FOREIGN KEY(account_id) REFERENCES accounts(account_id),
 FOREIGN KEY(loan_id) REFERENCES loans(loan_id),
 CHECK((debit>0 AND credit=0) OR (credit>0 AND debit=0))
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS bank_change_audit (
 audit_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 table_name VARCHAR(64) NOT NULL,
 row_id INT NOT NULL,
 action_name VARCHAR(10) NOT NULL,
 old_data JSON NULL,
 new_data JSON NULL,
 changed_by VARCHAR(288) NOT NULL,
 changed_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 KEY(table_name,row_id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS bank_transfer_requests (
 request_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 request_key VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
 from_account INT NOT NULL,
 to_account INT NOT NULL,
 amount DECIMAL(14,2) NOT NULL,
 description VARCHAR(150) NOT NULL,
 status ENUM('Pending','Approved','Rejected') NOT NULL DEFAULT 'Pending',
 requested_by VARCHAR(288) NOT NULL,
 requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 decided_by VARCHAR(288) NULL,
 decided_at TIMESTAMP NULL,
 decision_reason VARCHAR(150) NULL,
 operation_id BIGINT UNSIGNED NULL UNIQUE,
 FOREIGN KEY(from_account) REFERENCES accounts(account_id),
 FOREIGN KEY(to_account) REFERENCES accounts(account_id),
 FOREIGN KEY(operation_id) REFERENCES bank_operations(operation_id),
 CHECK(amount>0 AND from_account<>to_account)
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS bp2_gl_post_check;
DELIMITER $$
CREATE TRIGGER bp2_gl_post_check BEFORE UPDATE ON bank_gl_journals FOR EACH ROW
BEGIN
 DECLARE v_count INT;
 DECLARE v_net DECIMAL(20,2);
 IF OLD.status='Posted' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Posted journals are immutable'; END IF;
 IF NEW.status='Posted' THEN
  SELECT COUNT(*),COALESCE(SUM(debit-credit),0) INTO v_count,v_net
  FROM bank_gl_lines WHERE journal_id=OLD.journal_id;
  IF v_count<2 OR v_net<>0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Journal must have balanced debit and credit entries'; END IF;
 END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_gl_header_insert;
DELIMITER $$
CREATE TRIGGER bp2_gl_header_insert BEFORE INSERT ON bank_gl_journals FOR EACH ROW
BEGIN IF NEW.status<>'Draft' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Create draft then validate and post'; END IF; END$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_gl_line_insert;
DELIMITER $$
CREATE TRIGGER bp2_gl_line_insert BEFORE INSERT ON bank_gl_lines FOR EACH ROW
BEGIN
 DECLARE v_status VARCHAR(10) DEFAULT NULL;
 SELECT status INTO v_status FROM bank_gl_journals WHERE journal_id=NEW.journal_id FOR UPDATE;
 IF v_status IS NULL OR v_status<>'Draft' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Lines require a draft journal'; END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_bank_gl_lines_update;
DELIMITER $$
CREATE TRIGGER bp2_bank_gl_lines_update BEFORE UPDATE ON bank_gl_lines FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Immutable record: post a reversal or correction instead'$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_bank_gl_lines_delete;
DELIMITER $$
CREATE TRIGGER bp2_bank_gl_lines_delete BEFORE DELETE ON bank_gl_lines FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Immutable record: post a reversal or correction instead'$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_bank_change_audit_update;
DELIMITER $$
CREATE TRIGGER bp2_bank_change_audit_update BEFORE UPDATE ON bank_change_audit FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Immutable record: post a reversal or correction instead'$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_bank_change_audit_delete;
DELIMITER $$
CREATE TRIGGER bp2_bank_change_audit_delete BEFORE DELETE ON bank_change_audit FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Immutable record: post a reversal or correction instead'$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_transaction_audit_update;
DELIMITER $$
CREATE TRIGGER bp2_transaction_audit_update BEFORE UPDATE ON transaction_audit FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Immutable record: post a reversal or correction instead'$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_transaction_audit_delete;
DELIMITER $$
CREATE TRIGGER bp2_transaction_audit_delete BEFORE DELETE ON transaction_audit FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Immutable record: post a reversal or correction instead'$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_transactions_update;
DELIMITER $$
CREATE TRIGGER bp2_transactions_update BEFORE UPDATE ON transactions FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Immutable record: post a reversal or correction instead'$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_transactions_delete;
DELIMITER $$
CREATE TRIGGER bp2_transactions_delete BEFORE DELETE ON transactions FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Immutable record: post a reversal or correction instead'$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_gl_header_delete;
DELIMITER $$
CREATE TRIGGER bp2_gl_header_delete BEFORE DELETE ON bank_gl_journals FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Journal history cannot be deleted'$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_tx_validate;
DELIMITER $$
CREATE TRIGGER bp2_tx_validate BEFORE INSERT ON transactions FOR EACH ROW
BEGIN
 IF NEW.amount IS NULL OR NEW.amount<=0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transaction amount must be positive'; END IF;
 IF NOT EXISTS(SELECT 1 FROM accounts a WHERE a.account_id=NEW.account_id
  AND a.customer_id=NEW.customer_id AND a.branch_id=NEW.branch_id) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transaction customer/branch must match account';
 END IF;
 IF COALESCE(@bp_posting,0)<>1 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use banking posting procedures; direct transaction inserts disabled';
 END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_accounts_audit_insert;
DELIMITER $$
CREATE TRIGGER bp2_accounts_audit_insert AFTER INSERT ON accounts FOR EACH ROW
INSERT INTO bank_change_audit(table_name,row_id,action_name,old_data,new_data,changed_by) VALUES('accounts',NEW.account_id,'INSERT',NULL,JSON_OBJECT('account_id',NEW.`account_id`,'customer_id',NEW.`customer_id`,'branch_id',NEW.`branch_id`,'account_type',NEW.`account_type`,'opened_date',NEW.`opened_date`,'balance',NEW.`balance`,'opening_balance',NEW.`opening_balance`,'annual_interest_rate',NEW.`annual_interest_rate`,'account_status',NEW.`account_status`,'activity_status',NEW.`activity_status`),USER())$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_accounts_audit_update;
DELIMITER $$
CREATE TRIGGER bp2_accounts_audit_update AFTER UPDATE ON accounts FOR EACH ROW
INSERT INTO bank_change_audit(table_name,row_id,action_name,old_data,new_data,changed_by) VALUES('accounts',NEW.account_id,'UPDATE',JSON_OBJECT('account_id',OLD.`account_id`,'customer_id',OLD.`customer_id`,'branch_id',OLD.`branch_id`,'account_type',OLD.`account_type`,'opened_date',OLD.`opened_date`,'balance',OLD.`balance`,'opening_balance',OLD.`opening_balance`,'annual_interest_rate',OLD.`annual_interest_rate`,'account_status',OLD.`account_status`,'activity_status',OLD.`activity_status`),JSON_OBJECT('account_id',NEW.`account_id`,'customer_id',NEW.`customer_id`,'branch_id',NEW.`branch_id`,'account_type',NEW.`account_type`,'opened_date',NEW.`opened_date`,'balance',NEW.`balance`,'opening_balance',NEW.`opening_balance`,'annual_interest_rate',NEW.`annual_interest_rate`,'account_status',NEW.`account_status`,'activity_status',NEW.`activity_status`),USER())$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_accounts_audit_delete;
DELIMITER $$
CREATE TRIGGER bp2_accounts_audit_delete AFTER DELETE ON accounts FOR EACH ROW
INSERT INTO bank_change_audit(table_name,row_id,action_name,old_data,new_data,changed_by) VALUES('accounts',OLD.account_id,'DELETE',JSON_OBJECT('account_id',OLD.`account_id`,'customer_id',OLD.`customer_id`,'branch_id',OLD.`branch_id`,'account_type',OLD.`account_type`,'opened_date',OLD.`opened_date`,'balance',OLD.`balance`,'opening_balance',OLD.`opening_balance`,'annual_interest_rate',OLD.`annual_interest_rate`,'account_status',OLD.`account_status`,'activity_status',OLD.`activity_status`),NULL,USER())$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_loans_audit_insert;
DELIMITER $$
CREATE TRIGGER bp2_loans_audit_insert AFTER INSERT ON loans FOR EACH ROW
INSERT INTO bank_change_audit(table_name,row_id,action_name,old_data,new_data,changed_by) VALUES('loans',NEW.loan_id,'INSERT',NULL,JSON_OBJECT('loan_id',NEW.`loan_id`,'customer_id',NEW.`customer_id`,'branch_id',NEW.`branch_id`,'loan_type',NEW.`loan_type`,'loan_amount',NEW.`loan_amount`,'outstanding_amount',NEW.`outstanding_amount`,'annual_interest_rate',NEW.`annual_interest_rate`,'issue_date',NEW.`issue_date`,'maturity_date',NEW.`maturity_date`,'loan_status',NEW.`loan_status`),USER())$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_loans_audit_update;
DELIMITER $$
CREATE TRIGGER bp2_loans_audit_update AFTER UPDATE ON loans FOR EACH ROW
INSERT INTO bank_change_audit(table_name,row_id,action_name,old_data,new_data,changed_by) VALUES('loans',NEW.loan_id,'UPDATE',JSON_OBJECT('loan_id',OLD.`loan_id`,'customer_id',OLD.`customer_id`,'branch_id',OLD.`branch_id`,'loan_type',OLD.`loan_type`,'loan_amount',OLD.`loan_amount`,'outstanding_amount',OLD.`outstanding_amount`,'annual_interest_rate',OLD.`annual_interest_rate`,'issue_date',OLD.`issue_date`,'maturity_date',OLD.`maturity_date`,'loan_status',OLD.`loan_status`),JSON_OBJECT('loan_id',NEW.`loan_id`,'customer_id',NEW.`customer_id`,'branch_id',NEW.`branch_id`,'loan_type',NEW.`loan_type`,'loan_amount',NEW.`loan_amount`,'outstanding_amount',NEW.`outstanding_amount`,'annual_interest_rate',NEW.`annual_interest_rate`,'issue_date',NEW.`issue_date`,'maturity_date',NEW.`maturity_date`,'loan_status',NEW.`loan_status`),USER())$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_loans_audit_delete;
DELIMITER $$
CREATE TRIGGER bp2_loans_audit_delete AFTER DELETE ON loans FOR EACH ROW
INSERT INTO bank_change_audit(table_name,row_id,action_name,old_data,new_data,changed_by) VALUES('loans',OLD.loan_id,'DELETE',JSON_OBJECT('loan_id',OLD.`loan_id`,'customer_id',OLD.`customer_id`,'branch_id',OLD.`branch_id`,'loan_type',OLD.`loan_type`,'loan_amount',OLD.`loan_amount`,'outstanding_amount',OLD.`outstanding_amount`,'annual_interest_rate',OLD.`annual_interest_rate`,'issue_date',OLD.`issue_date`,'maturity_date',OLD.`maturity_date`,'loan_status',OLD.`loan_status`),NULL,USER())$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_customers_audit_insert;
DELIMITER $$
CREATE TRIGGER bp2_customers_audit_insert AFTER INSERT ON customers FOR EACH ROW
INSERT INTO bank_change_audit(table_name,row_id,action_name,old_data,new_data,changed_by) VALUES('customers',NEW.customer_id,'INSERT',NULL,JSON_OBJECT('customer_id',NEW.`customer_id`,'forename',NEW.`forename`,'surname',NEW.`surname`,'date_of_birth',NEW.`date_of_birth`,'gender',NEW.`gender`,'city',NEW.`city`,'employment_status',NEW.`employment_status`,'annual_income',NEW.`annual_income`,'risk_rating',NEW.`risk_rating`,'registered_date',NEW.`registered_date`,'home_branch_id',NEW.`home_branch_id`),USER())$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_customers_audit_update;
DELIMITER $$
CREATE TRIGGER bp2_customers_audit_update AFTER UPDATE ON customers FOR EACH ROW
INSERT INTO bank_change_audit(table_name,row_id,action_name,old_data,new_data,changed_by) VALUES('customers',NEW.customer_id,'UPDATE',JSON_OBJECT('customer_id',OLD.`customer_id`,'forename',OLD.`forename`,'surname',OLD.`surname`,'date_of_birth',OLD.`date_of_birth`,'gender',OLD.`gender`,'city',OLD.`city`,'employment_status',OLD.`employment_status`,'annual_income',OLD.`annual_income`,'risk_rating',OLD.`risk_rating`,'registered_date',OLD.`registered_date`,'home_branch_id',OLD.`home_branch_id`),JSON_OBJECT('customer_id',NEW.`customer_id`,'forename',NEW.`forename`,'surname',NEW.`surname`,'date_of_birth',NEW.`date_of_birth`,'gender',NEW.`gender`,'city',NEW.`city`,'employment_status',NEW.`employment_status`,'annual_income',NEW.`annual_income`,'risk_rating',NEW.`risk_rating`,'registered_date',NEW.`registered_date`,'home_branch_id',NEW.`home_branch_id`),USER())$$
DELIMITER ;

DROP TRIGGER IF EXISTS bp2_customers_audit_delete;
DELIMITER $$
CREATE TRIGGER bp2_customers_audit_delete AFTER DELETE ON customers FOR EACH ROW
INSERT INTO bank_change_audit(table_name,row_id,action_name,old_data,new_data,changed_by) VALUES('customers',OLD.customer_id,'DELETE',JSON_OBJECT('customer_id',OLD.`customer_id`,'forename',OLD.`forename`,'surname',OLD.`surname`,'date_of_birth',OLD.`date_of_birth`,'gender',OLD.`gender`,'city',OLD.`city`,'employment_status',OLD.`employment_status`,'annual_income',OLD.`annual_income`,'risk_rating',OLD.`risk_rating`,'registered_date',OLD.`registered_date`,'home_branch_id',OLD.`home_branch_id`),NULL,USER())$$
DELIMITER ;

DROP PROCEDURE IF EXISTS bp2_post_gl;
DELIMITER $$
CREATE PROCEDURE bp2_post_gl(IN p_op BIGINT UNSIGNED)
BEGIN
 DECLARE v_j BIGINT UNSIGNED;
 DECLARE v_original BIGINT UNSIGNED;
 DECLARE v_original_j BIGINT UNSIGNED;
 DECLARE v_type VARCHAR(20);
 DECLARE v_from INT;
 DECLARE v_to INT;
 DECLARE v_amount DECIMAL(14,2);
 DECLARE v_pp DECIMAL(14,2);
 DECLARE v_ip DECIMAL(14,2);
 DECLARE v_loan INT;
 DECLARE v_desc VARCHAR(150);
 IF NOT EXISTS(SELECT 1 FROM bank_gl_journals WHERE journal_key='OPENING-V2' AND status='Posted') THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Opening general ledger has not been initialized';
 END IF;
 SELECT operation_type,from_account,to_account,amount,reversal_of,description
 INTO v_type,v_from,v_to,v_amount,v_original,v_desc FROM bank_operations WHERE operation_id=p_op;
 IF v_type IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Operation not found'; END IF;
 INSERT INTO bank_gl_journals(operation_id,journal_key,journal_date,description,created_by)
 VALUES(p_op,CONCAT('OP:',p_op),UTC_DATE(),v_desc,USER());
 SET v_j=LAST_INSERT_ID();
 IF v_type='Reversal' THEN
  IF NOT EXISTS(SELECT 1 FROM bank_gl_journals WHERE operation_id=v_original AND status='Posted') THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pre-GL operation reversal needs accountant migration treatment';
  END IF;
  SELECT journal_id INTO v_original_j FROM bank_gl_journals WHERE operation_id=v_original AND status='Posted';
  INSERT INTO bank_gl_lines(journal_id,gl_code,account_id,loan_id,debit,credit)
  SELECT v_j,l.gl_code,l.account_id,l.loan_id,l.credit,l.debit FROM bank_gl_lines l
  WHERE l.journal_id=v_original_j;
 ELSE
  IF v_from IS NOT NULL THEN INSERT INTO bank_gl_lines(journal_id,gl_code,account_id,debit) VALUES(v_j,'2000',v_from,v_amount); END IF;
  IF v_to IS NOT NULL THEN INSERT INTO bank_gl_lines(journal_id,gl_code,account_id,credit) VALUES(v_j,'2000',v_to,v_amount); END IF;
  CASE v_type
   WHEN 'Deposit' THEN INSERT INTO bank_gl_lines(journal_id,gl_code,debit) VALUES(v_j,'1000',v_amount);
   WHEN 'Withdrawal' THEN INSERT INTO bank_gl_lines(journal_id,gl_code,credit) VALUES(v_j,'1000',v_amount);
   WHEN 'Fee' THEN INSERT INTO bank_gl_lines(journal_id,gl_code,credit) VALUES(v_j,'4100',v_amount);
   WHEN 'Interest' THEN INSERT INTO bank_gl_lines(journal_id,gl_code,debit) VALUES(v_j,'5000',v_amount);
   WHEN 'Loan Payment' THEN
    SELECT p.principal_amount,p.interest_amount,i.loan_id INTO v_pp,v_ip,v_loan
    FROM bank_loan_payments p JOIN bank_loan_installments i USING(installment_id) WHERE p.operation_id=p_op;
    IF v_pp IS NULL OR v_pp+v_ip<>v_amount THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Loan allocation missing or inconsistent'; END IF;
    IF v_pp>0 THEN INSERT INTO bank_gl_lines(journal_id,gl_code,loan_id,credit) VALUES(v_j,'1100',v_loan,v_pp); END IF;
    IF v_ip>0 THEN INSERT INTO bank_gl_lines(journal_id,gl_code,loan_id,credit) VALUES(v_j,'4000',v_loan,v_ip); END IF;
   WHEN 'Transfer' THEN BEGIN END;
   ELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unsupported GL operation';
  END CASE;
 END IF;
 UPDATE bank_gl_journals SET status='Posted' WHERE journal_id=v_j;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_initialize_general_ledger;
DELIMITER $$
CREATE PROCEDURE sp_initialize_general_ledger()
main: BEGIN
 DECLARE v_j BIGINT UNSIGNED;
 DECLARE v_net DECIMAL(20,2);
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 IF EXISTS(SELECT 1 FROM bank_gl_journals WHERE journal_key='OPENING-V2' AND status='Posted') THEN COMMIT; LEAVE main; END IF;
 INSERT INTO bank_gl_journals(journal_key,journal_date,description,created_by)
 VALUES('OPENING-V2',UTC_DATE(),'Opening balances: counterpart is migration offset, not reconstructed cash/equity',USER());
 SET v_j=LAST_INSERT_ID();
 INSERT INTO bank_gl_lines(journal_id,gl_code,account_id,debit,credit)
 SELECT v_j,'2000',account_id,GREATEST(-balance,0),GREATEST(balance,0) FROM accounts WHERE balance<>0;
 INSERT INTO bank_gl_lines(journal_id,gl_code,loan_id,debit)
 SELECT v_j,'1100',loan_id,outstanding_amount FROM loans WHERE outstanding_amount>0;
 SELECT COALESCE(SUM(debit-credit),0) INTO v_net FROM bank_gl_lines WHERE journal_id=v_j;
 IF v_net<>0 THEN INSERT INTO bank_gl_lines(journal_id,gl_code,debit,credit) VALUES(v_j,'3000',GREATEST(-v_net,0),GREATEST(v_net,0)); END IF;
 UPDATE bank_gl_journals SET status='Posted' WHERE journal_id=v_j;
 COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS bp_check_account;
DELIMITER $$
CREATE PROCEDURE bp_check_account(IN p_account INT, IN p_mode VARCHAR(12), IN p_amount DECIMAL(14,2))
BEGIN
 DECLARE v_balance DECIMAL(14,2);
 DECLARE v_status VARCHAR(10);
 DECLARE v_frozen BOOLEAN;
 SELECT a.balance,a.account_status,c.frozen INTO v_balance,v_status,v_frozen
 FROM accounts a JOIN bank_account_controls c USING(account_id) WHERE a.account_id=p_account;
 IF v_status IS NULL OR p_mode IS NULL OR p_mode NOT IN ('System','Correction','Debit','Credit') OR p_amount IS NULL OR p_amount<0 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Missing account controls or invalid check parameters';
 END IF;
 IF v_status='Closed' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Closed account: posting rejected';
 END IF;
 IF p_mode NOT IN ('System','Correction') AND (v_frozen OR v_status<>'Active') THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Account is frozen or dormant; authorized reactivation required';
 END IF;
 IF p_mode IN ('Debit','Correction') AND v_balance<p_amount THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Insufficient funds; no overdraft configured';
 END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_pay_loan_installment;
DELIMITER $$
CREATE PROCEDURE sp_pay_loan_installment(IN p_key VARCHAR(100),IN p_account INT,
 IN p_installment BIGINT UNSIGNED,IN p_amount DECIMAL(14,2))
BEGIN
 DECLARE v_loan INT DEFAULT NULL;
 DECLARE v_owner INT;
 DECLARE v_no INT;
 DECLARE v_outstanding DECIMAL(14,2);
 DECLARE v_principal DECIMAL(14,2);
 DECLARE v_interest DECIMAL(14,2);
 DECLARE v_pp DECIMAL(14,2);
 DECLARE v_ip DECIMAL(14,2);
 DECLARE v_op BIGINT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @bp_posting=NULL; RESIGNAL; END;
 IF p_key IS NULL OR CHAR_LENGTH(TRIM(p_key))=0 OR p_key LIKE 'SYS:%' OR p_amount IS NULL OR p_amount<=0 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Positive amount and unique non-SYS request key required';
 END IF;
 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
 START TRANSACTION;
 CALL bp_lock_account(p_account); CALL bp_check_account(p_account,'Debit',p_amount);
 SELECT loan_id INTO v_loan FROM bank_loan_installments WHERE installment_id=p_installment;
 IF v_loan IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Installment not found'; END IF;
 SELECT customer_id,outstanding_amount INTO v_owner,v_outstanding FROM loans WHERE loan_id=v_loan FOR UPDATE;
 IF v_owner<>(SELECT customer_id FROM accounts WHERE account_id=p_account) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment account must belong to the borrower';
 END IF;
 SELECT installment_no,principal_due-principal_paid,interest_due-interest_paid
 INTO v_no,v_principal,v_interest FROM bank_loan_installments WHERE installment_id=p_installment FOR UPDATE;
 IF EXISTS(SELECT 1 FROM bank_loan_installments WHERE loan_id=v_loan AND installment_no<v_no
  AND principal_due+interest_due>principal_paid+interest_paid) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pay the earliest unpaid installment first';
 END IF;
 IF p_amount>v_principal+v_interest THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment exceeds remaining installment; split payments by installment';
 END IF;
 SET v_ip=LEAST(v_interest,p_amount); SET v_pp=p_amount-v_ip;
 IF v_pp>v_outstanding THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Principal exceeds loan outstanding balance'; END IF;
 INSERT INTO bank_operations(request_key,operation_type,from_account,amount,description,posted_by)
 VALUES(p_key,'Loan Payment',p_account,p_amount,CONCAT('Installment ',p_installment),USER());
 SET v_op=LAST_INSERT_ID();
 CALL bp_add_entry(v_op,p_account,-p_amount,'Loan Payment',UTC_DATE(),CONCAT('Installment ',p_installment),TRUE);
 INSERT INTO bank_loan_payments VALUES(v_op,p_installment,v_pp,v_ip);
 UPDATE bank_loan_installments SET principal_paid=principal_paid+v_pp,interest_paid=interest_paid+v_ip
 WHERE installment_id=p_installment;
 UPDATE loans SET outstanding_amount=outstanding_amount-v_pp WHERE loan_id=v_loan;
 CALL bp_refresh_loan(v_loan);
 CALL bp2_post_gl(v_op);
 COMMIT;
 SELECT v_op AS operation_id,'Posted' AS result;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_reverse_operation;
DELIMITER $$
CREATE PROCEDURE sp_reverse_operation(IN p_key VARCHAR(100),IN p_original BIGINT UNSIGNED,IN p_reason VARCHAR(150))
BEGIN
 DECLARE v_from INT;
 DECLARE v_to INT;
 DECLARE v_type VARCHAR(20) DEFAULT NULL;
 DECLARE v_amount DECIMAL(14,2);
 DECLARE v_op BIGINT UNSIGNED;
 DECLARE v_inst BIGINT UNSIGNED;
 DECLARE v_loan INT;
 DECLARE v_pp DECIMAL(14,2);
 DECLARE v_ip DECIMAL(14,2);
 DECLARE v_dummy INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @bp_posting=NULL; RESIGNAL; END;
 IF p_key IS NULL OR CHAR_LENGTH(TRIM(p_key))=0 OR p_key LIKE 'SYS:%' OR p_reason IS NULL OR TRIM(p_reason)='' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unique non-SYS request key and reversal reason required';
 END IF;
 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
 START TRANSACTION;
 SELECT from_account,to_account,operation_type,amount INTO v_from,v_to,v_type,v_amount
 FROM bank_operations WHERE operation_id=p_original;
 IF v_type IS NULL OR v_type IN ('Reversal','Interest') THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only customer/fee operations from this upgrade may be reversed';
 END IF;
 IF v_from IS NOT NULL AND v_to IS NOT NULL THEN
  CALL bp_lock_account(LEAST(v_from,v_to)); CALL bp_lock_account(GREATEST(v_from,v_to));
 ELSE CALL bp_lock_account(COALESCE(v_from,v_to)); END IF;
 -- A correction may bypass dormant/frozen status, but never Closed or funds checks.
 IF v_to IS NOT NULL THEN CALL bp_check_account(v_to,'Correction',v_amount); END IF;
 IF v_from IS NOT NULL THEN CALL bp_check_account(v_from,'System',0); END IF;
 INSERT INTO bank_operations(request_key,operation_type,from_account,to_account,amount,reversal_of,description,posted_by)
 VALUES(p_key,'Reversal',v_to,v_from,v_amount,p_original,p_reason,USER());
 SET v_op=LAST_INSERT_ID();
 IF v_to IS NOT NULL THEN CALL bp_add_entry(v_op,v_to,-v_amount,'Reversal Out',UTC_DATE(),p_reason,FALSE); END IF;
 IF v_from IS NOT NULL THEN CALL bp_add_entry(v_op,v_from,v_amount,'Reversal In',UTC_DATE(),p_reason,FALSE); END IF;
 IF v_type='Loan Payment' THEN
  SELECT p.installment_id,i.loan_id,p.principal_amount,p.interest_amount INTO v_inst,v_loan,v_pp,v_ip
  FROM bank_loan_payments p JOIN bank_loan_installments i USING(installment_id) WHERE p.operation_id=p_original;
  SELECT loan_id INTO v_dummy FROM loans WHERE loan_id=v_loan FOR UPDATE;
  UPDATE bank_loan_installments SET principal_paid=principal_paid-v_pp,interest_paid=interest_paid-v_ip WHERE installment_id=v_inst;
  UPDATE loans SET outstanding_amount=outstanding_amount+v_pp WHERE loan_id=v_loan;
  CALL bp_refresh_loan(v_loan);
 END IF;
 CALL bp2_post_gl(v_op);
 COMMIT;
 SELECT v_op AS reversal_operation_id,'Reversed' AS result;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_accrue_account_interest;
DELIMITER $$
CREATE PROCEDURE sp_accrue_account_interest(IN p_account INT,IN p_day DATE)
BEGIN
 DECLARE v_last DATE;
 DECLARE v_start DATE;
 DECLARE v_rate DECIMAL(5,2);
 DECLARE v_base DECIMAL(14,2);
 DECLARE v_closing DECIMAL(14,2);
 DECLARE v_interest DECIMAL(14,2);
 DECLARE v_op BIGINT UNSIGNED DEFAULT NULL;
 DECLARE v_status VARCHAR(10);
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @bp_posting=NULL; RESIGNAL; END;
 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
 START TRANSACTION;
 CALL bp_lock_account(p_account);
 SELECT c.last_interest_day,c.activated_on,c.interest_rate,c.baseline_balance,a.account_status
 INTO v_last,v_start,v_rate,v_base,v_status FROM bank_account_controls c
 JOIN accounts a USING(account_id) WHERE c.account_id=p_account;
 IF p_day IS NULL OR p_day>=UTC_DATE() OR p_day<>v_last+INTERVAL 1 DAY OR p_day<v_start THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Accrue the next unprocessed completed UTC day only';
 END IF;
 SELECT v_base+COALESCE(SUM(e.signed_amount),0) INTO v_closing FROM bank_entry_links e
 JOIN transactions t USING(transaction_id) WHERE t.account_id=p_account AND t.transaction_date<=p_day;
 SET v_interest=IF(v_status='Closed',0,ROUND(GREATEST(v_closing,0)*v_rate/36500,2));
 IF v_interest>0 THEN
  INSERT INTO bank_operations(request_key,operation_type,to_account,amount,description,posted_by)
  VALUES(CONCAT('SYS:INT:',p_account,':',p_day),'Interest',p_account,v_interest,CONCAT('Interest for ',p_day),USER());
  SET v_op=LAST_INSERT_ID();
  CALL bp_add_entry(v_op,p_account,v_interest,'Interest',p_day,CONCAT('Interest for ',p_day),FALSE);
 END IF;
 INSERT INTO bank_interest_accruals VALUES(p_account,p_day,v_closing,v_rate,v_interest,v_op);
 UPDATE bank_account_controls SET last_interest_day=p_day WHERE account_id=p_account;
 IF v_op IS NOT NULL THEN CALL bp2_post_gl(v_op); END IF;
 COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS bp2_post_core;
DELIMITER $$
CREATE PROCEDURE bp2_post_core(IN p_key VARCHAR(100),IN p_type VARCHAR(20),
 IN p_from INT,IN p_to INT,IN p_amount DECIMAL(14,2),IN p_description VARCHAR(150), OUT v_op BIGINT UNSIGNED)
BEGIN
 IF p_key IS NULL OR CHAR_LENGTH(TRIM(p_key))=0 OR p_key LIKE 'SYS:%'
 OR p_amount IS NULL OR p_amount<=0 OR p_description IS NULL THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Provide positive amount, description and unique non-SYS request key';
 END IF;
 IF p_type IS NULL OR p_type NOT IN ('Deposit','Withdrawal','Transfer','Fee') THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use Deposit, Withdrawal, Transfer or Fee';
 END IF;
 IF (p_type='Deposit' AND (p_from IS NOT NULL OR p_to IS NULL))
 OR (p_type IN ('Withdrawal','Fee') AND (p_from IS NULL OR p_to IS NOT NULL))
 OR (p_type='Transfer' AND (p_from IS NULL OR p_to IS NULL OR p_from=p_to)) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid source/destination combination';
 END IF;
 -- Deterministic account lock order prevents opposite transfers deadlocking.
 IF p_from IS NOT NULL AND p_to IS NOT NULL THEN
  CALL bp_lock_account(LEAST(p_from,p_to)); CALL bp_lock_account(GREATEST(p_from,p_to));
 ELSE CALL bp_lock_account(COALESCE(p_from,p_to)); END IF;
 IF p_from IS NOT NULL THEN CALL bp_check_account(p_from,'Debit',p_amount); END IF;
 IF p_to IS NOT NULL THEN CALL bp_check_account(p_to,'Credit',p_amount); END IF;
 INSERT INTO bank_operations(request_key,operation_type,from_account,to_account,amount,description,posted_by)
 VALUES(p_key,p_type,p_from,p_to,p_amount,p_description,USER());
 SET v_op=LAST_INSERT_ID();
 IF p_from IS NOT NULL THEN
  CALL bp_add_entry(v_op,p_from,-p_amount,IF(p_type='Transfer','Transfer Out',p_type),UTC_DATE(),p_description,p_type<>'Fee');
 END IF;
 IF p_to IS NOT NULL THEN
  CALL bp_add_entry(v_op,p_to,p_amount,IF(p_type='Transfer','Transfer In','Deposit'),UTC_DATE(),p_description,TRUE);
 END IF;
 CALL bp2_post_gl(v_op);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_post_transaction;
DELIMITER $$
CREATE PROCEDURE sp_post_transaction(IN p_key VARCHAR(100),IN p_type VARCHAR(20),IN p_from INT,IN p_to INT,IN p_amount DECIMAL(14,2),IN p_description VARCHAR(150))
BEGIN
 DECLARE v_op BIGINT UNSIGNED;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @bp_posting=NULL; RESIGNAL; END;
 -- Demonstration policy, not a legal threshold: transfers over AZN 1,000 require two users.
 IF p_type='Transfer' AND p_amount>1000 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Submit sp_request_transfer; transfers over 1000 require a different approver'; END IF;
 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
 START TRANSACTION;
 CALL bp2_post_core(p_key,p_type,p_from,p_to,p_amount,p_description,v_op);
 COMMIT;
 SELECT v_op AS operation_id,'Posted' AS result;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_request_transfer;
DELIMITER $$
CREATE PROCEDURE sp_request_transfer(IN p_key VARCHAR(100),IN p_from INT,IN p_to INT,IN p_amount DECIMAL(14,2),IN p_description VARCHAR(150))
BEGIN
 IF p_key IS NULL OR TRIM(p_key)='' OR p_key LIKE 'SYS:%' OR p_amount IS NULL OR p_amount<=0
 OR p_from IS NULL OR p_to IS NULL OR p_from=p_to OR p_description IS NULL THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Provide unique non-SYS key, different accounts, positive amount and description';
 END IF;
 INSERT INTO bank_transfer_requests(request_key,from_account,to_account,amount,description,requested_by)
 VALUES(p_key,p_from,p_to,p_amount,p_description,USER());
 SELECT LAST_INSERT_ID() AS request_id,'Pending - no money moved' AS result;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_decide_transfer;
DELIMITER $$
CREATE PROCEDURE sp_decide_transfer(IN p_request BIGINT UNSIGNED,IN p_approve BOOLEAN,IN p_reason VARCHAR(150))
BEGIN
 DECLARE v_maker VARCHAR(288) DEFAULT NULL;
 DECLARE v_status VARCHAR(10);
 DECLARE v_key VARCHAR(100);
 DECLARE v_from INT;
 DECLARE v_to INT;
 DECLARE v_amount DECIMAL(14,2);
 DECLARE v_description VARCHAR(150);
 DECLARE v_op BIGINT UNSIGNED DEFAULT NULL;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @bp_posting=NULL; RESIGNAL; END;
 IF p_approve IS NULL OR p_approve NOT IN(0,1) OR p_reason IS NULL OR TRIM(p_reason)='' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Approval flag and reason required'; END IF;
 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
 START TRANSACTION;
 SELECT requested_by,status,request_key,from_account,to_account,amount,description
 INTO v_maker,v_status,v_key,v_from,v_to,v_amount,v_description
 FROM bank_transfer_requests WHERE request_id=p_request FOR UPDATE;
 IF v_maker IS NULL OR v_status<>'Pending' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Request missing or already decided'; END IF;
 IF SUBSTRING_INDEX(v_maker,'@',1)=SUBSTRING_INDEX(USER(),'@',1) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A different database user must approve or reject'; END IF;
 IF p_approve THEN CALL bp2_post_core(v_key,'Transfer',v_from,v_to,v_amount,v_description,v_op); END IF;
 UPDATE bank_transfer_requests SET status=IF(p_approve,'Approved','Rejected'),decided_by=USER(),
 decided_at=CURRENT_TIMESTAMP,decision_reason=p_reason,operation_id=v_op WHERE request_id=p_request;
 COMMIT;
 SELECT p_request AS request_id,v_op AS operation_id,IF(p_approve,'Approved','Rejected') AS result;
END$$
DELIMITER ;

-- Consolidate the older event so it uses the same customer-activity definition.
ALTER EVENT mark_inactive_accounts_daily DO CALL sp_refresh_account_activity();
-- Initialize once. Existing baseline controls remain unchanged.
CALL sp_initialize_general_ledger();

CREATE OR REPLACE VIEW bank_gl_trial_balance AS
 SELECT a.gl_code,a.gl_name,a.category,COALESCE(SUM(l.debit),0) AS debits,
 COALESCE(SUM(l.credit),0) AS credits,COALESCE(SUM(l.debit-l.credit),0) AS debit_balance
 FROM bank_gl_accounts a LEFT JOIN
 (SELECT x.* FROM bank_gl_lines x JOIN bank_gl_journals j USING(journal_id) WHERE j.status='Posted') l
 ON l.gl_code=a.gl_code GROUP BY a.gl_code,a.gl_name,a.category;
CREATE OR REPLACE VIEW bank_gl_monthly_profit AS
 SELECT DATE_FORMAT(j.journal_date,'%Y-%m') AS month,
 SUM(CASE WHEN a.category='Income' THEN l.credit-l.debit ELSE 0 END) AS income,
 SUM(CASE WHEN a.category='Expense' THEN l.debit-l.credit ELSE 0 END) AS expenses,
 SUM(l.credit-l.debit) AS net_profit
 FROM bank_gl_lines l JOIN bank_gl_journals j USING(journal_id)
 JOIN bank_gl_accounts a USING(gl_code)
 WHERE j.status='Posted' AND a.category IN ('Income','Expense')
 GROUP BY DATE_FORMAT(j.journal_date,'%Y-%m');
CREATE OR REPLACE VIEW bank_gl_account_reconciliation AS
 SELECT a.account_id,a.balance,COALESCE(g.gl_balance,0) AS gl_balance,
 a.balance-COALESCE(g.gl_balance,0) AS difference
 FROM accounts a LEFT JOIN
 (SELECT l.account_id,SUM(l.credit-l.debit) AS gl_balance FROM bank_gl_lines l
 JOIN bank_gl_journals j USING(journal_id) WHERE j.status='Posted' AND l.gl_code='2000'
 GROUP BY l.account_id) g ON g.account_id=a.account_id;
CREATE OR REPLACE VIEW bank_gl_loan_reconciliation AS
 SELECT a.loan_id,a.outstanding_amount,COALESCE(g.gl_balance,0) AS gl_balance,
 a.outstanding_amount-COALESCE(g.gl_balance,0) AS difference
 FROM loans a LEFT JOIN
 (SELECT l.loan_id,SUM(l.debit-l.credit) AS gl_balance FROM bank_gl_lines l
 JOIN bank_gl_journals j USING(journal_id) WHERE j.status='Posted' AND l.gl_code='1100'
 GROUP BY l.loan_id) g ON g.loan_id=a.loan_id;
CREATE OR REPLACE VIEW bank_loan_aging AS
 SELECT l.loan_id,l.customer_id,l.outstanding_amount,
 CASE WHEN s.loan_id IS NULL THEN 'Unscheduled'
      WHEN COALESCE(i.days_overdue,0)=0 THEN 'Current'
      WHEN i.days_overdue<=30 THEN '1-30 days'
      WHEN i.days_overdue<=60 THEN '31-60 days'
      WHEN i.days_overdue<=90 THEN '61-90 days' ELSE '90+ days' END AS aging_bucket,
 COALESCE(i.overdue_amount,0) AS overdue_installments
 FROM loans l LEFT JOIN bank_loan_schedules s ON s.loan_id=l.loan_id
 LEFT JOIN (SELECT loan_id,MAX(days_past_due) AS days_overdue,
 SUM(IF(days_past_due>0,amount_remaining,0)) AS overdue_amount FROM bank_installment_status GROUP BY loan_id) i
 ON i.loan_id=l.loan_id;

DROP PROCEDURE IF EXISTS sp_bank_health_check;
DELIMITER $$
CREATE PROCEDURE sp_bank_health_check()
BEGIN
 SELECT 'Account balance mismatches' AS check_name,COUNT(*) AS issues FROM bank_balance_reconciliation WHERE difference<>0
 UNION ALL SELECT 'GL account mismatches',COUNT(*) FROM bank_gl_account_reconciliation WHERE difference<>0
 UNION ALL SELECT 'GL loan mismatches',COUNT(*) FROM bank_gl_loan_reconciliation WHERE difference<>0
 UNION ALL SELECT 'Loan schedule mismatches',COUNT(*) FROM bank_loan_reconciliation WHERE difference<>0
 UNION ALL SELECT 'Operation entry mismatches',COUNT(*) FROM bank_operation_integrity WHERE check_result<>'OK'
 UNION ALL SELECT 'Unbalanced posted journals',COUNT(*) FROM
 (SELECT j.journal_id FROM bank_gl_journals j LEFT JOIN bank_gl_lines l USING(journal_id)
 WHERE j.status='Posted' GROUP BY j.journal_id HAVING COUNT(l.line_id)<2 OR COALESCE(SUM(l.debit-l.credit),0)<>0) bad
 UNION ALL SELECT 'Draft journals',COUNT(*) FROM bank_gl_journals WHERE status='Draft'
 UNION ALL SELECT 'Accounts not enrolled',COUNT(*) FROM accounts a LEFT JOIN bank_account_controls c USING(account_id) WHERE c.account_id IS NULL;
 SELECT @@event_scheduler AS event_scheduler,UTC_TIMESTAMP() AS checked_at_utc;
 SELECT COUNT(*) AS outstanding_loans_without_schedule FROM loans l
 LEFT JOIN bank_loan_schedules s USING(loan_id) WHERE l.outstanding_amount>0 AND s.loan_id IS NULL;
END$$
DELIMITER ;

-- Role setup. Assign to separate, non-root database users outside this file.
-- Existing users with direct write or global EXECUTE rights must have those reviewed separately.
CREATE ROLE IF NOT EXISTS 'bp2_teller', 'bp2_manager', 'bp2_auditor';
GRANT EXECUTE ON PROCEDURE banking_portfolio_demo.sp_post_transaction TO 'bp2_teller';
GRANT EXECUTE ON PROCEDURE banking_portfolio_demo.sp_request_transfer TO 'bp2_teller';
GRANT EXECUTE ON PROCEDURE banking_portfolio_demo.sp_pay_loan_installment TO 'bp2_teller';
GRANT EXECUTE ON PROCEDURE banking_portfolio_demo.sp_decide_transfer TO 'bp2_manager';
GRANT EXECUTE ON PROCEDURE banking_portfolio_demo.sp_reverse_operation TO 'bp2_manager';
GRANT EXECUTE ON PROCEDURE banking_portfolio_demo.sp_set_account_control TO 'bp2_manager';
GRANT EXECUTE ON PROCEDURE banking_portfolio_demo.sp_create_loan_schedule TO 'bp2_manager';
GRANT EXECUTE ON PROCEDURE banking_portfolio_demo.sp_bank_health_check TO 'bp2_manager', 'bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_transfer_requests TO 'bp2_teller','bp2_manager','bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_installment_status TO 'bp2_teller','bp2_manager','bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_gl_trial_balance TO 'bp2_manager','bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_gl_monthly_profit TO 'bp2_manager','bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_gl_account_reconciliation TO 'bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_gl_loan_reconciliation TO 'bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_loan_aging TO 'bp2_manager','bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_change_audit TO 'bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.transaction_audit TO 'bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_control_audit TO 'bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_gl_journals TO 'bp2_auditor';
GRANT SELECT ON banking_portfolio_demo.bank_gl_lines TO 'bp2_auditor';
-- Rerun-safe migration marker; success is recorded only after all definitions above.
INSERT IGNORE INTO bank_upgrade_version(version) VALUES(2);
CALL sp_bank_health_check();
SELECT 'Upgrade 2 installed. Review health checks and README before posting.' AS result;
