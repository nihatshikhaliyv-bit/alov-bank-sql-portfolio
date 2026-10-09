# Install the final Alov Bank database

You are permitted to import this synthetic dataset for education and personal practice; no separate approval is needed. See [PERMISSIONS.md](../PERMISSIONS.md).

1. Download the repository ZIP and extract it to a normal folder.
2. Follow [data/README.md](../data/README.md) to reconstruct `alov_bank_final_2025.sql.gz` with SHA-256 verification. Python 3.10+ is required only for the downloader; no extra packages are needed.
3. Extract the archive with 7-Zip. It contains `alov_bank_final_2025.sql` (about 296 MB uncompressed).
4. Use an unused `banking_portfolio_2025` database name. Open Windows Command Prompt in the extracted SQL folder and run:

```bat
mysql --default-character-set=utf8mb4 -u root -p < alov_bank_final_2025.sql
```

Use the full path to mysql.exe if it is not on PATH. Enter the password when prompted. Do not paste the command at the mysql> SQL prompt. Do not use --force or repeat an import over a partially created schema.

5. Import `historical_2025/06_checks.sql` using the same client. Every issues count must be zero.
6. Review the views and tables in DbGate. MySQL 8.4 was used for the recorded full-dataset validation; a new clean-server import was not rerun during this publication.

Allow several GB of free disk for SQL extraction, database files and indexes. This is a fictional educational dataset. It contains no production bank records.

Optional regeneration: from the repository root run `py historical_2025/build.py`, then `py historical_2025/test_scenario.py`. The generator uses an internal source seed and creates the same final scenario; the source seed is not another release.
