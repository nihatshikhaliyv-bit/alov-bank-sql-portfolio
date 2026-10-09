"""Download or join Alov Bank's synthetic final database; verify SHA-256."""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen

BASE = "https://raw.githubusercontent.com/nihatshikhaliyv-bit/alov-bank-sql-portfolio/main/data/"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--local", action="store_true", help="Join parts beside this script without downloading")
    parser.add_argument("--output", type=Path, default=Path("alov_bank_final_2025.sql.gz"))
    args = parser.parse_args()
    folder = Path(__file__).resolve().parent
    manifest = json.loads((folder / "manifest.json").read_text())
    temp = args.output.with_name(args.output.name + ".downloading")
    if args.output.exists() or temp.exists():
        raise SystemExit("Output already exists; choose another --output path.")
    total_hash = hashlib.sha256()
    total_size = 0
    try:
        with temp.open("xb") as dest:
            for part in manifest["parts"]:
                source = (folder / part["filename"]).open("rb") if args.local else urlopen(BASE + part["filename"], timeout=120)
                part_hash = hashlib.sha256()
                part_size = 0
                with source:
                    while chunk := source.read(1024 * 1024):
                        dest.write(chunk)
                        total_hash.update(chunk)
                        part_hash.update(chunk)
                        part_size += len(chunk)
                if part_size != part["size_bytes"] or part_hash.hexdigest() != part["sha256"]:
                    raise ValueError("Integrity check failed: " + part["filename"])
                total_size += part_size
                print("Verified " + part["filename"])
        if total_size != manifest["size_bytes"] or total_hash.hexdigest() != manifest["sha256"]:
            raise ValueError("Combined database integrity check failed")
        temp.rename(args.output)
    except BaseException:
        temp.unlink(missing_ok=True)
        raise
    print("Saved verified database: " + str(args.output.resolve()))

if __name__ == "__main__":
    main()
