# Expanded synthetic database

This fictional educational dataset is published as 14 binary parts because the complete gzip archive is 143,913,163 bytes. The parts preserve the original archive exactly; do not decompress them individually.

## Download and restore

1. Download [download_expanded.py](download_expanded.py) and [manifest.json](manifest.json) into the same folder.
2. Run `python download_expanded.py` (Windows: `py download_expanded.py`). It downloads every part, verifies each SHA-256, and saves `bank_portfolio_expanded_2025.sql.gz`.
3. Extract that gzip archive and follow [SETUP.md](../../docs/SETUP.md) to import the resulting SQL into MySQL.

If you downloaded or cloned all parts already, use `python data/expanded/download_expanded.py --local` from the repository root. No third-party Python packages are required. An existing output file is preserved; select a different path with `--output`.

**Archive SHA-256:** `e62827dcb6e040e609f5ae57a7bc5b4983b65530d55f96d5ed8f451a7b0f0ad2`

All customer records are synthetic. This is an educational portfolio, not a production banking system.
