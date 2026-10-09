# Final Alov Bank database

After repeated refinements, **banking_portfolio_2025** is the selected final database for this portfolio. The reporting cutoff is 31 December 2025. Its uncompressed SQL is 295,732,741 bytes; the verified gzip archive is 50,915,104 bytes and is published in five binary parts. Do not extract the parts individually.

## Download

1. Download this repository with **Code → Download ZIP** and extract it.
2. From the repository root run `py data/download_final.py --local` (Windows, Python 3.10+) or `python3 data/download_final.py --local` (macOS/Linux). This rejoins the included parts and verifies every SHA-256.
3. Alternatively, download only [download_final.py](download_final.py) and [manifest.json](manifest.json) into one folder and run `py download_final.py`. It fetches the five parts automatically.
4. Extract `alov_bank_final_2025.sql.gz` using 7-Zip. The SQL output is `alov_bank_final_2025.sql`. Import it following [SETUP.md](../docs/SETUP.md).

The downloader requires no third-party Python packages and preserves an existing output file. Use `--output` to choose another destination.

Archive SHA-256: `f6b60d890ecb658a1eb090b9738b847255e4993219cf443e231021a15f9fd44f`

Uncompressed SQL SHA-256: `ff2e1ea47a7ad04056209e1b6ada4948997cf498e5076f74223234f4761e0770` (matches historical_2025/results.json).

Superseded database downloads have been removed from the current branch. The small seed under `historical_2025/source/` is an internal generator dependency, not another database option.

All customer records are synthetic. This is an educational model, not a production banking system.
