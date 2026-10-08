# Setup and reproduction

## Which file should I use?

| Situation | Action |
| --- | --- |
| You already have banking_portfolio_fresh and want the existing upgrade | Run sql/02_banking_upgrade_v2.sql after the checks in its header. Do not restore the baseline over it. |
| You want the new random 2025 history | Restore bank_portfolio_expanded_2025.sql.gz into the separate banking_portfolio_demo database; then use sql/02_demo_upgrade_v2.sql. |
| You only want to review the bank | Open README.md, docs/BANK_ANALYSIS.md and the charts. No server is necessary. |
| You want to reproduce the original source metrics | Run python analysis/analyze.py. |
| You want to regenerate the expanded dataset | Run python analysis/generate_history.py. It writes SQL, not a live database. |

The two database names intentionally separate your existing work from the expanded historical scenario. Neither is the final branding of the fictional bank.

## Restore the expanded dataset

1. Keep your current backup. The restore file contains DROP TABLE statements **inside banking_portfolio_demo**, so use an empty demo schema or fresh server. Restoring over an upgraded demo is unsupported because additional V2 foreign keys may exist.
2. Extract the `.sql.gz` file using 7-Zip or `python analysis/extract_sql.py path/to/bank_portfolio_expanded_2025.sql.gz`. Allow several GB of free disk for the extracted SQL, indexes, database files and import logs.
3. Use MySQL 8.0.16+ (8.4 recommended for reproduction). The earlier test used 8.4.11; the owner's 26.7/DbGate runtime has not been independently tested.
4. Prefer the MySQL command-line client for this multi-million-row restore. From Windows **Command Prompt**, in the directory containing the extracted file:

```bat
mysql --default-character-set=utf8mb4 -u root -p < bank_portfolio_expanded_2025.sql
```

The password is prompted. Do not put it in the repository or command text. Add your actual host/port if not local. If Windows cannot find `mysql`, use the full path to your installed `mysql.exe`.

5. The file selects banking_portfolio_demo itself. It first loads entities and historical transactions, then restores routines/triggers. Do not apply V2 before importing the history: V2 intentionally blocks direct transaction inserts.
6. Install `sql/02_demo_upgrade_v2.sql` as an administrator while no users or jobs are posting. Read its instructions about pausing/restoring the two daily events.
7. Run the read-only checks. Confirm the transaction count against `analysis/expanded_metrics.json`, compare balances and inspect the health-check output.

DbGate can be used to inspect the result. Avoid pasting millions of INSERT rows into a query editor: use its large-file workflow or the MySQL client. The small V2 script can be opened in a SQL editor and executed in full.

The original dump carries `root@localhost` definers. Restoring on a hosted service without that account may need a controlled definer rewrite or administrator help. Do not assume the dump is portable to a restricted cloud user.

## Original baseline, if needed

`data/portfolio_snapshot.sql.gz` is the untouched seed export. Its database is named banking_portfolio_fresh, but the original dump does not include CREATE DATABASE or USE. To reproduce it, first create/select an empty banking_portfolio_fresh in an isolated test instance, then import the extracted seed. Do not run this over the already-upgraded database.

## Reproduce analysis and charts

```bash
python analysis/analyze.py
python analysis/generate_history.py
python -m pip install -r requirements.txt
python analysis/make_charts.py
```

The first step verifies the original seed. The second builds the requested random history and writes expanded metrics, preserving customer, account, loan and branch financial records. Charts use expanded_metrics.json when present. Generation can take several minutes and produces a large compressed SQL artifact outside the repository folder. Check the printed completion summary before using that artifact.

## Account roles and daily jobs

The upgrade creates roles, but does not create users or assign roles to existing users. Use separate authenticated teller/manager/auditor logins and review existing broad privileges. The root account is for administration, not proof of staff access control. Transfer approval requires a different username.

The event scheduler is not enabled globally by the upgrade. Verify its state and test daily jobs in a disposable environment before scheduling them. Do not run a year's interest catch-up merely to populate empty tables.
