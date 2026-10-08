"""Prepare a disposable MySQL initialization-runner input; never starts a server.
Usage: python historical_2025/validate_mysql.py /absolute/scratch/output-directory
The directory must be outside the repository. MySQL --initialize-insecure
--init-file can run this against a NEW data directory without a listening socket.
"""
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
with (out/'init.sql').open('w') as f:
    pending=[]
    for line in (HERE/'05_historical_2025.sql').open():
        if line.startswith('--'): continue
        pending.append(line.strip())
        if line.rstrip().endswith(';'):
            statement=' '.join(pending)
            # Bootstrap has no logged-in definer; normal CLI imports do.
            statement=statement.replace('CREATE VIEW ', 'CREATE DEFINER=`root`@`localhost` VIEW ')
            f.write(statement+'\n');pending=[]
    assert not any(pending)
    checks=(HERE/'06_checks.sql').read_text().split(';')[1].strip()
    f.write('CREATE TABLE validation_results AS '+checks.replace('\n',' ')+';\n')
    f.write("SELECT check_name,issues INTO OUTFILE '"+str(out/'checks.tsv')+"' FROM validation_results;\n")
    f.write("SELECT COUNT(*),SUM(issues) INTO OUTFILE '"+str(out/'summary.tsv')+"' FROM validation_results;\n")
print(out/'init.sql')
