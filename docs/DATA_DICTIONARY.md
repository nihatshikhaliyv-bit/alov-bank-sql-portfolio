# Data dictionary

Money columns use AZN; annual_interest_rate and interest_rate use percentage points (3.5 means 3.5%). SQL types below are taken from the supplied export. Fields are not proof of populated operational histories.
## accounts

Customer accounts; opening_balance plus signed historical movements reconciles to balance. account_status is a servicing restriction, while activity_status is a separate usage flag.

| Column | Source definition |
| --- | --- |
| `account_id` | `int NOT NULL` |
| `customer_id` | `int NOT NULL` |
| `branch_id` | `int NOT NULL` |
| `account_type` | `enum('Current','Savings','Salary','Business') NOT NULL` |
| `opened_date` | `date NOT NULL` |
| `balance` | `decimal(14,2) NOT NULL` |
| `opening_balance` | `decimal(14,2) NOT NULL` |
| `annual_interest_rate` | `decimal(5,2) NOT NULL` |
| `account_status` | `enum('Active','Dormant','Closed') NOT NULL` |
| `activity_status` | `varchar(10) NOT NULL DEFAULT 'Active'` |

## bank_account_controls

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `account_id` | `int NOT NULL` |
| `baseline_balance` | `decimal(14,2) NOT NULL` |
| `activated_on` | `date NOT NULL` |
| `frozen` | `tinyint(1) NOT NULL DEFAULT '0'` |
| `interest_rate` | `decimal(5,2) NOT NULL` |
| `last_interest_day` | `date NOT NULL` |

## bank_control_audit

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `audit_id` | `bigint unsigned NOT NULL AUTO_INCREMENT` |
| `account_id` | `int NOT NULL` |
| `action_name` | `varchar(30) NOT NULL` |
| `detail` | `varchar(255) NOT NULL` |
| `changed_by` | `varchar(288) NOT NULL` |
| `changed_at` | `timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP` |

## bank_entry_links

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `transaction_id` | `int NOT NULL` |
| `operation_id` | `bigint unsigned NOT NULL` |
| `signed_amount` | `decimal(14,2) NOT NULL` |

## bank_interest_accruals

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `account_id` | `int NOT NULL` |
| `accrual_date` | `date NOT NULL` |
| `closing_balance` | `decimal(14,2) NOT NULL` |
| `annual_rate` | `decimal(5,2) NOT NULL` |
| `interest_amount` | `decimal(14,2) NOT NULL` |
| `operation_id` | `bigint unsigned DEFAULT NULL` |

## bank_job_log

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `job_id` | `bigint unsigned NOT NULL AUTO_INCREMENT` |
| `job_name` | `varchar(80) NOT NULL` |
| `finished_at` | `timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP` |
| `outcome` | `varchar(10) NOT NULL` |
| `detail` | `text NOT NULL` |

## bank_loan_installments

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `installment_id` | `bigint unsigned NOT NULL AUTO_INCREMENT` |
| `loan_id` | `int NOT NULL` |
| `installment_no` | `int NOT NULL` |
| `due_date` | `date NOT NULL` |
| `principal_due` | `decimal(14,2) NOT NULL` |
| `interest_due` | `decimal(14,2) NOT NULL` |
| `principal_paid` | `decimal(14,2) NOT NULL DEFAULT '0.00'` |
| `interest_paid` | `decimal(14,2) NOT NULL DEFAULT '0.00'` |

## bank_loan_payments

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `operation_id` | `bigint unsigned NOT NULL` |
| `installment_id` | `bigint unsigned NOT NULL` |
| `principal_amount` | `decimal(14,2) NOT NULL` |
| `interest_amount` | `decimal(14,2) NOT NULL` |

## bank_loan_schedules

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `loan_id` | `int NOT NULL` |
| `opening_principal` | `decimal(14,2) NOT NULL` |
| `scheduled_at` | `timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP` |
| `scheduled_by` | `varchar(288) NOT NULL` |

## bank_operations

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `operation_id` | `bigint unsigned NOT NULL AUTO_INCREMENT` |
| `request_key` | `varchar(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL` |
| `operation_type` | `varchar(20) NOT NULL` |
| `from_account` | `int DEFAULT NULL` |
| `to_account` | `int DEFAULT NULL` |
| `amount` | `decimal(14,2) NOT NULL` |
| `reversal_of` | `bigint unsigned DEFAULT NULL` |
| `description` | `varchar(150) NOT NULL` |
| `posted_at` | `timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)` |
| `posted_by` | `varchar(288) NOT NULL` |

## bank_upgrade_version

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `version` | `int NOT NULL` |
| `installed_at` | `timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP` |

## branch_financials

Modeled annual summary. loan_amount matches remaining loan principal, not original loan_amount in loans. net_profit is revenue minus recorded expenses, without separately modeled tax/provisions.

| Column | Source definition |
| --- | --- |
| `financial_id` | `int NOT NULL AUTO_INCREMENT` |
| `branch_id` | `int NOT NULL` |
| `reporting_year` | `year NOT NULL` |
| `interest_income` | `decimal(16,2) NOT NULL` |
| `fee_income` | `decimal(16,2) NOT NULL` |
| `other_income` | `decimal(16,2) NOT NULL` |
| `total_revenue` | `decimal(16,2) NOT NULL` |
| `interest_expense` | `decimal(16,2) NOT NULL` |
| `operating_expense` | `decimal(16,2) NOT NULL` |
| `total_expenses` | `decimal(16,2) NOT NULL` |
| `net_profit` | `decimal(16,2) NOT NULL` |
| `loan_amount` | `decimal(16,2) NOT NULL` |
| `deposit_amount` | `decimal(16,2) NOT NULL` |
| `loan_to_deposit_ratio` | `decimal(8,4) NOT NULL` |

## branches

Branch footprint and aggregate employee count.

| Column | Source definition |
| --- | --- |
| `branch_id` | `int NOT NULL` |
| `branch_name` | `varchar(100) NOT NULL` |
| `city` | `varchar(100) NOT NULL` |
| `region` | `varchar(100) NOT NULL` |
| `opened_date` | `date NOT NULL` |
| `employee_count` | `int NOT NULL` |

## customers

Synthetic customer profiles. risk_rating is a stored label without a supplied scoring method.

| Column | Source definition |
| --- | --- |
| `customer_id` | `int NOT NULL` |
| `forename` | `varchar(50) NOT NULL` |
| `surname` | `varchar(50) NOT NULL` |
| `date_of_birth` | `date NOT NULL` |
| `gender` | `enum('Female','Male') NOT NULL` |
| `city` | `varchar(100) NOT NULL` |
| `employment_status` | `enum('Employed','Self-employed','Student','Retired','Unemployed') NOT NULL` |
| `annual_income` | `decimal(12,2) NOT NULL` |
| `risk_rating` | `enum('Low','Medium','High') NOT NULL` |
| `registered_date` | `date NOT NULL` |
| `home_branch_id` | `int NOT NULL` |

## loans

Original loan amount and remaining principal. loan_status alone does not measure days past due.

| Column | Source definition |
| --- | --- |
| `loan_id` | `int NOT NULL` |
| `customer_id` | `int NOT NULL` |
| `branch_id` | `int NOT NULL` |
| `loan_type` | `enum('Personal','Mortgage','Auto','Business','Education') NOT NULL` |
| `loan_amount` | `decimal(14,2) NOT NULL` |
| `outstanding_amount` | `decimal(14,2) NOT NULL` |
| `annual_interest_rate` | `decimal(5,2) NOT NULL` |
| `issue_date` | `date NOT NULL` |
| `maturity_date` | `date NOT NULL` |
| `loan_status` | `enum('Active','Paid','Overdue') NOT NULL` |

## transaction_audit

Operational/support table; see FEATURES.md for activation and coverage limits.

| Column | Source definition |
| --- | --- |
| `audit_id` | `bigint unsigned NOT NULL AUTO_INCREMENT` |
| `transaction_id` | `bigint DEFAULT NULL` |
| `action_type` | `varchar(10) NOT NULL` |
| `changed_at` | `timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP` |
| `changed_by` | `varchar(288) NOT NULL` |
| `old_data` | `json DEFAULT NULL` |
| `new_data` | `json DEFAULT NULL` |

## transactions

Positive magnitudes; transaction_type determines direction. Historical seed types are Deposit, Withdrawal and Fee. V2 extends types and makes transaction_id AUTO_INCREMENT.

| Column | Source definition |
| --- | --- |
| `transaction_id` | `int NOT NULL` |
| `account_id` | `int NOT NULL` |
| `customer_id` | `int NOT NULL` |
| `branch_id` | `int NOT NULL` |
| `transaction_date` | `date NOT NULL` |
| `transaction_type` | `enum('Deposit','Withdrawal','Transfer In','Transfer Out','Loan Payment','Fee') NOT NULL` |
| `amount` | `decimal(14,2) NOT NULL` |
| `description` | `varchar(150) NOT NULL` |

## V2 additions

| Table | Purpose | Main keys and measures |
| --- | --- | --- |
| bank_gl_accounts | Chart of accounts | gl_code; category |
| bank_gl_journals | Posting headers | journal_id; unique operation_id and journal_key; date; status |
| bank_gl_lines | Debit/credit amounts | line_id; journal_id; gl_code; optional account_id/loan_id; debit/credit |
| bank_change_audit | Customer/account/loan changes | audit_id; table_name; row_id; old/new JSON; login/time |
| bank_transfer_requests | Approval workflow | request_id; unique request_key; parties; amount; requester/approver; operation_id |

The chart of accounts contains cash movements, loan principal, customer deposit liabilities, a migration opening offset, interest/fee income and deposit-interest expense. It is deliberately incomplete for statutory reporting.
