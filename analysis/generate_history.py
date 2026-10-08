"""Deterministic synthetic 2025 history: independently sample 1..80 rows per customer/month.
Preserves original closing balances and exactly one original fee per account.
Writes a separate banking_portfolio_demo restore (never connects to a database).
Python 3.10+, standard library. Full build ~14.6m rows; allow several GB free disk.
"""
import argparse, calendar, gzip, hashlib, json, random, re, time
from collections import defaultdict, Counter
from decimal import Decimal
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--seed',type=int,default=20251005)
ap.add_argument('--output',type=Path,default=ROOT.parent/'bank_portfolio_expanded_2025.sql.gz')
ap.add_argument('--metrics',type=Path,default=ROOT/'analysis/expanded_metrics.json')
args=ap.parse_args()
source=ROOT/'data/portfolio_snapshot.sql.gz'
s=gzip.decompress(source.read_bytes()).decode('utf-8')
tok=re.compile(r"'(?:\\.|[^'\\])*'|NULL|-?\d+(?:\.\d+)?")
rowpat=re.compile(r"\((?:'(?:\\.|[^'\\])*'|[^()'])*\)")
def rows(table):
 for val in re.findall(r'^INSERT INTO `'+table+r'` VALUES (.*);$',s,re.M):
  for r in rowpat.finditer(val):yield [v[1:-1] if v.startswith("'") else v for v in tok.findall(r[0])]
def cents(v):return int(Decimal(v)*100)
accounts={};bycustomer=defaultdict(list)
for r in rows('accounts'):
 aid,cid,bid=map(int,r[:3]);accounts[aid]={'customer':cid,'branch':bid,'closing':cents(r[5]),'opening':cents(r[6])};bycustomer[cid].append(aid)
fees={}
for r in rows('transactions'):
 if r[5]=='Fee':
  aid=int(r[1]);assert aid not in fees;fees[aid]=cents(r[6])
assert len(bycustomer)==30000 and len(accounts)==45449 and set(fees)==set(accounts)
rng=random.Random(args.seed);monthly=defaultdict(lambda:[0,0]);bytype=defaultdict(lambda:[0,0]);mtypes=defaultdict(lambda:[0,0]);firsttype={};lasttype={}
account_n=Counter();monthly_counts=[];customer_totals=[];correct_n=0;correct_amount=0;zero_floor=0;txid=0
fee_actual=Counter();signed=Counter();min_day='9999';max_day='';buffers=[];written=0;payload_hash=hashlib.sha256();start=time.time()
# Preserve all original definitions and non-transaction data, replacing only the historical inserts.
first=s.index('INSERT INTO `transactions` VALUES ')
last=first
for match in re.finditer(r'^INSERT INTO `transactions` VALUES .*;\n?',s,re.M):last=match.end()
prefix=s[:first];suffix=s[last:]
# Do not replay final dump date as if it described this newly generated history.
suffix=re.sub(r'-- Dump completed on .*','-- Original baseline export: 2026-10-04. Expanded history generated separately; see manifest.',suffix)
args.output.parent.mkdir(parents=True,exist_ok=True)
def cash(v):return f'{v//100}.{v%100:02d}'
with args.output.open('wb') as raw, gzip.GzipFile(filename='',mode='wb',fileobj=raw,compresslevel=5,mtime=0) as out:
 def emit(text):
  global written
  b=text.encode('utf-8');out.write(b);payload_hash.update(b);written+=len(b)
 emit('-- SYNTHETIC EXPANDED HISTORY: 1-80 transactions per customer per month, 2025.\n-- Recreates tables in banking_portfolio_demo. Do not point this at a live bank database.\nCREATE DATABASE IF NOT EXISTS banking_portfolio_demo;\nUSE banking_portfolio_demo;\n')
 emit(prefix.replace('banking_portfolio_fresh','banking_portfolio_demo'))
 for ordinal,(cid,aids) in enumerate(sorted(bycustomer.items()),1):
  dates=[]
  for month in range(1,13):
   n=rng.randint(1,80);monthly_counts.append(n)
   dates.extend(f'2025-{month:02d}-{rng.randint(1,calendar.monthrange(2025,month)[1]):02d}' for _ in range(n))
  dates.sort();customer_totals.append(len(dates))
  # Seed two slots/account so each can carry its preserved fee and closing adjustment.
  assert len(dates)>=2*len(aids)
  assign=aids*2+[rng.choice(aids) for _ in range(len(dates)-2*len(aids))];rng.shuffle(assign)
  positions={a:[i for i,x in enumerate(assign) if x==a] for a in aids}
  fee_slot={a:rng.choice(positions[a][:-1]) for a in aids};last_slot={a:positions[a][-1] for a in aids}
  bal={a:accounts[a]['opening'] for a in aids};fee_pending=set(aids);history=[]
  for i,(day,aid) in enumerate(zip(dates,assign)):
   description='Synthetic customer activity'
   if i==fee_slot[aid]:
    typ='Fee';amount=fees[aid];assert bal[aid]>=amount;(fee_pending.remove(aid));change=-amount
   elif i==last_slot[aid]:
    change=accounts[aid]['closing']-bal[aid]
    if change==0:
     # Shift an earlier non-fee entry by one cent, making a nonzero closing entry.
     prior=next((r for r in reversed(history) if r[0]==aid and r[2]!='Fee'),None)
     assert prior is not None,'Closing matches exactly with no adjustable preceding entry'
     if prior[2]=='Deposit':prior[3]+=1;bal[aid]+=1
     else:prior[3]+=1;bal[aid]-=1
     change=accounts[aid]['closing']-bal[aid]
    typ='Deposit' if change>0 else 'Withdrawal';amount=abs(change)
    description='Synthetic closing-balance reconciliation';correct_n+=1;correct_amount+=amount
   else:
    amount=max(100,min(500000,round(rng.lognormvariate(8.7,0.9))))
    reserve=fees[aid] if aid in fee_pending else 0
    if rng.random()<0.5 and bal[aid]-reserve>100:
     typ='Withdrawal';amount=min(amount,(bal[aid]-reserve)//2);change=-amount
    else:typ='Deposit';change=amount
   assert amount>0
   bal[aid]+=change;assert bal[aid]>=0
   history.append([aid,day,typ,amount,description])
  assert all(bal[a]==accounts[a]['closing'] for a in aids)
  # Independent per-account replay catches any edited prior entry, including the 1-cent edge case.
  replay={a:accounts[a]['opening'] for a in aids}
  for aid,day,typ,amount,desc in history:
   replay[aid]+=amount if typ=='Deposit' else -amount;assert replay[aid]>=0
   txid+=1;mo=day[:7];monthly[mo][0]+=1;monthly[mo][1]+=amount;bytype[typ][0]+=1;bytype[typ][1]+=amount;mtypes[(mo,typ)][0]+=1;mtypes[(mo,typ)][1]+=amount
   firsttype[typ]=min(firsttype.get(typ,day),day);lasttype[typ]=max(lasttype.get(typ,day),day);min_day=min(min_day,day);max_day=max(max_day,day)
   account_n[aid]+=1;signed[aid]+=amount if typ=='Deposit' else -amount
   if typ=='Fee':fee_actual[aid]+=amount
   buffers.append(f"({txid},{aid},{cid},{accounts[aid]['branch']},'{day}','{typ}',{cash(amount)},'{desc}')")
   if len(buffers)>=500:
    emit('INSERT INTO `transactions` VALUES '+','.join(buffers)+';\n');buffers=[]
  assert all(replay[a]==accounts[a]['closing'] for a in aids)
  if ordinal%3000==0:print(f'{ordinal:,}/30,000 customers; {txid:,} rows; {time.time()-start:.0f}s',flush=True)
 if buffers:emit('INSERT INTO `transactions` VALUES '+','.join(buffers)+';\n')
 emit(suffix.replace('banking_portfolio_fresh','banking_portfolio_demo'))
assert all(fee_actual[a]==fees[a] for a in accounts)
assert all(accounts[a]['opening']+signed[a]==accounts[a]['closing'] for a in accounts)
assert len(monthly_counts)==360000 and min(monthly_counts)>=1 and max(monthly_counts)<=80
base=json.loads((ROOT/'analysis/snapshot_metrics.json').read_text());base['counts']['transactions']=txid
base.update({'dataset_version':'expanded-2025-v1','source_sha256':payload_hash.hexdigest(),'source_file':args.output.name,'original_source_sha256':hashlib.sha256(s.encode()).hexdigest(),'generation_seed':args.seed,'transaction_count_scope':'1-80 per CUSTOMER per month; distributed across that customer accounts','snapshot_exported_at':'Baseline exported 2026-10-04 12:30:23; expanded history generated on request for all of 2025','monthly_transactions':[{'month':mo,'transactions':v[0],'gross_amount':v[1]/100} for mo,v in sorted(monthly.items())],'product_transactions':[{'transaction_type':typ,'transactions':v[0],'gross_amount':v[1]/100} for typ,v in sorted(bytype.items())],'monthly_types':[{'month':mo,'transaction_type':typ,'transactions':v[0],'gross_amount':v[1]/100} for (mo,typ),v in sorted(mtypes.items())],'last_activity_by_type':[{'transaction_type':typ,'earliest':firsttype[typ],'latest':lasttype[typ]} for typ in sorted(bytype)],'account_transaction_pattern':[{'min_transactions':min(account_n.values()),'max_transactions':max(account_n.values()),'accounts_with_transactions':len(account_n)}],'patterns_by_account':[]})
base['date_ranges'][0]={'entity':'transactions','earliest':min_day,'latest':max_day}
base['generation_validation']={'customer_months':len(monthly_counts),'min_transactions_per_customer_month':min(monthly_counts),'max_transactions_per_customer_month':max(monthly_counts),'min_transactions_per_customer_year':min(customer_totals),'max_transactions_per_customer_year':max(customer_totals),'closing_balance_mismatches':0,'negative_running_balances':0,'account_fee_total_mismatches':0,'nonpositive_amounts':0,'closing_reconciliation_entries':correct_n,'closing_reconciliation_gross_amount':correct_amount/100,'raw_sql_bytes':written,'gzip_bytes':args.output.stat().st_size,'generated_transactions':txid,'elapsed_seconds':round(time.time()-start,2)}
args.metrics.parent.mkdir(parents=True,exist_ok=True);args.metrics.write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(base['generation_validation'],indent=2),flush=True)
