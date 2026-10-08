"""Stream-decompress a .sql.gz file; never execute its SQL."""
import gzip, shutil, sys
from pathlib import Path
p=Path(sys.argv[1]);out=p.with_suffix('')
if out.exists():raise SystemExit(f'Refusing to overwrite existing file: {out}')
with gzip.open(p,'rb') as i,out.open('wb') as o:shutil.copyfileobj(i,o)
print(out.resolve())
