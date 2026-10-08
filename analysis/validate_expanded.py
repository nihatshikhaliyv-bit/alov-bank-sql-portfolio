"""Independently read the serialized expanded SQL and validate counts and money.
Usage: python analysis/validate_expanded.py ../bank_portfolio_expanded_2025.sql.gz
Does not connect to MySQL. Standard library only.
"""
from pathlib import Path
import re,gzip,json,sys,hashlib,time
from decimal import Decimal
from collections import Counter
R=Path(__file__).resolve().parents[1];src=Path(sys.argv[1]) if len(sys.argv)>1 else R.parent/'bank_portfolio_expanded_2025.sql.gz'
s=gzip.decompress((R/'data/portfolio_snapshot.sql.gz').read_bytes()).decode()
accounts={};balances={};closing={};expected_fees=Counter()
for v in re.findall(r'^INSERT INTO `accounts` VALUES (.*);$',s,re.M):
 for r in re.findall(r'\(([^()]*)\)',v):
  x=r.split(',');a=int(x[0]);accounts[a]=(int(x[1]),int(x[2]));balances[a]=int(Decimal(x[6])*100);closing[a]=int(Decimal(x[5])*100)
for v in re.findall(r'^INSERT INTO `transactions` VALUES (.*);$',s,re.M):
 for r in re.findall(r"\((\d+),(\d+),(\d+),(\d+),'([^']+)','Fee',(\d+\.\d+),'[^']*'\)",v):expected_fees[int(r[1])]+=int(Decimal(r[5])*100)
pat=re.compile(r"\((\d+),(\d+),(\d+),(\d+),'(\d{4}-\d{2}-\d{2})','([^']+)',(\d+)\.(\d{2}),'([^']*)'\)")
counts=Counter();fees=Counter();lastdate={};tx=0;digest=hashlib.sha256();size=0;start=time.time()
with gzip.open(src,'rb') as f:
 for line in f:
  digest.update(line);size+=len(line)
  if not line.startswith(b'INSERT INTO `transactions` VALUES '):continue
  st=line.decode();matches=list(pat.finditer(st));assert matches,'Unparsed transaction INSERT'
  # Ensure the entire VALUES payload was recognized, not merely matching fragments.
  payload=st.split(' VALUES ',1)[1].strip().rstrip(';');assert ','.join(x[0] for x in matches)==payload
  for z in matches:
   tid,a,c,b,day,typ,whole,frac,desc=z.groups();tx+=1;a=int(a);c=int(c);b=int(b);amount=int(whole)*100+int(frac)
   assert int(tid)==tx and amount>0 and accounts[a]==(c,b)
   assert '2025-01-01'<=day<='2025-12-31' and day>=lastdate.get(a,'');lastdate[a]=day
   assert typ in ('Deposit','Withdrawal','Fee')
   counts[c,day[:7]]+=1;balances[a]+=amount if typ=='Deposit' else -amount
   assert balances[a]>=0
   if typ=='Fee':fees[a]+=amount
assert len(counts)==30000*12 and min(counts.values())>=1 and max(counts.values())<=80
assert balances==closing and fees==expected_fees
manifest=json.loads((R/'analysis/expanded_metrics.json').read_text())
assert tx==manifest['counts']['transactions'] and digest.hexdigest()==manifest['source_sha256']
result={'status':'PASS','validation':'Independent streaming replay of the serialized SQL payload','transactions':tx,'customer_months':len(counts),'monthly_min':min(counts.values()),'monthly_max':max(counts.values()),'closing_balance_mismatches':0,'fee_total_mismatches':0,'negative_running_balances':0,'id_gaps_or_duplicates':0,'owner_branch_mismatches':0,'payload_sha256':digest.hexdigest(),'payload_bytes':size,'elapsed_seconds':round(time.time()-start,2),'mysql_restore_tested':False}
(R/'analysis/expanded_validation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
