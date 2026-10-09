"""Reproducible historical lending/premises scenario. Python 3.10+, no dependencies.
Reads the original seed as DATA; never connects to or modifies a database.
All financial arithmetic uses integer AZN cents with Decimal rate calculations.
"""
import calendar, csv, gzip, hashlib, json, math, random, re, os
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
CUTOFF = date(2025, 12, 31)
START = date(2020, 7, 1)
D = Decimal

def rnd(x):
    return int(D(x).quantize(D('1'), rounding=ROUND_HALF_UP))

def monthend(d):
    return date(d.year, d.month, calendar.monthrange(d.year, d.month)[1])

def addmonths(d, n):
    y, m = divmod(d.year * 12 + d.month - 1 + n, 12)
    return date(y, m + 1, min(d.day, calendar.monthrange(y, m + 1)[1]))

def money(n):
    return f'{D(n)/100:.2f}'

def source_rows():
    raw = gzip.decompress((HERE / 'source/source_seed.sql.gz').read_bytes())
    text = raw.decode('utf-8')
    tables = {}
    tok = re.compile(r"'(?:\\.|[^'\\])*'|NULL|-?\d+(?:\.\d+)?")
    rowpat = re.compile(r"\((?:'(?:\\.|[^'\\])*'|[^()'])*\)")
    for table in ['customers', 'branches', 'loans', 'branch_financials']:
        body = re.search(r'CREATE TABLE `' + table + r'` \((.*?)\n\) ENGINE', text, re.S)[1]
        cols = re.findall(r'^  `([^`]+)` ([^\n]+)', body, re.M)
        rows = []
        for values in re.findall(r'^INSERT INTO `' + table + r'` VALUES (.*);$', text, re.M):
            for match in rowpat.finditer(values):
                tokens = tok.findall(match[0])
                assert len(tokens) == len(cols)
                row = {}
                for (name, typ), val in zip(cols, tokens):
                    if val == 'NULL': v = None
                    elif val.startswith("'"): v = re.sub(r'\\(.)', r'\1', val[1:-1])
                    elif typ.startswith('decimal'): v = D(val)
                    else: v = int(val)
                    row[name] = v
                rows.append(row)
        tables[table] = rows
    return tables, hashlib.sha256(raw).hexdigest()

SCHEMA = {
 'branches': 'branch_id INT PRIMARY KEY, branch_name VARCHAR(100), city VARCHAR(100), employees INT',
 'customers': 'customer_id INT PRIMARY KEY, forename VARCHAR(50), surname VARCHAR(50), employment_status VARCHAR(30), source_annual_income DECIMAL(14,2)',
 'customer_income': 'customer_id INT, month_end DATE, net_income DECIMAL(14,2), essential_expenses DECIMAL(14,2), income_shock BOOLEAN, PRIMARY KEY(customer_id,month_end)',
 'loans': 'loan_id INT PRIMARY KEY, customer_id INT, branch_id INT, loan_type VARCHAR(20), issue_date DATE, original_maturity DATE, original_rate DECIMAL(7,4), loan_amount DECIMAL(16,2), source_outstanding DECIMAL(16,2), outstanding_amount DECIMAL(16,2), interest_receivable DECIMAL(16,2), current_rate DECIMAL(7,4), current_maturity DATE, loan_status VARCHAR(20), days_past_due INT, behaviour VARCHAR(30)',
 'loan_due_items': 'loan_id INT, due_date DATE, principal_due DECIMAL(16,2), interest_due DECIMAL(16,2), principal_paid DECIMAL(16,2), interest_paid DECIMAL(16,2), rescheduled BOOLEAN, PRIMARY KEY(loan_id,due_date)',
 'loan_payments': 'payment_id INT PRIMARY KEY, loan_id INT, paid_on DATE, principal_paid DECIMAL(16,2), interest_paid DECIMAL(16,2), total_paid DECIMAL(16,2), settlement_channel VARCHAR(40), INDEX(loan_id,paid_on)',
 'loan_month_end': 'loan_id INT, month_end DATE, outstanding_principal DECIMAL(16,2), interest_receivable DECIMAL(16,2), interest_accrued DECIMAL(16,2), principal_paid DECIMAL(16,2), interest_paid DECIMAL(16,2), days_past_due INT, charged_overdue_days INT, interest_frozen BOOLEAN, rate DECIMAL(7,4), contractual_next_principal DECIMAL(16,2), PRIMARY KEY(loan_id,month_end)',
 'arrears_episodes': 'episode_id INT PRIMARY KEY, loan_id INT, customer_id INT, first_missed_due DATE, closed_on DATE NULL, cure_method VARCHAR(30), max_days_past_due INT, charged_days INT, charged_interest DECIMAL(16,2), INDEX(customer_id,first_missed_due)',
 'restructurings': 'restructure_id INT PRIMARY KEY, loan_id INT, effective_date DATE, old_rate DECIMAL(7,4), new_rate DECIMAL(7,4), old_remaining_months INT, new_remaining_months INT, principal DECIMAL(16,2), carried_interest DECIMAL(16,2), old_projected_interest DECIMAL(16,2), new_projected_interest DECIMAL(16,2), strategy VARCHAR(40)',
 'credit_assessments': 'customer_id INT, assessed_on DATE, prior_max_dpd INT, prior_episodes INT, average_net_income DECIMAL(14,2), existing_monthly_debt DECIMAL(14,2), debt_income_cap DECIMAL(6,4), available_monthly_payment DECIMAL(14,2), illustrative_personal_limit DECIMAL(14,2), decision VARCHAR(60), blocked_until DATE NULL, PRIMARY KEY(customer_id,assessed_on)',
 'premises': 'branch_id INT PRIMARY KEY, tenure VARCHAR(10), landlord_type VARCHAR(30), area_sqm INT, monthly_gross_rent DECIMAL(16,2), lease_start DATE NULL, lease_end DATE NULL, refundable_deposit DECIMAL(16,2), discount_rate DECIMAL(7,4), initial_rou_asset DECIMAL(16,2), initial_lease_liability DECIMAL(16,2), owned_opening_cost DECIMAL(16,2)',
 'premises_monthly': 'branch_id INT, month_end DATE, gross_rent DECIMAL(16,2), landlord_cash DECIMAL(16,2), withholding DECIMAL(16,2), withholding_remitted DECIMAL(16,2), withholding_payable DECIMAL(16,2), lease_interest DECIMAL(16,2), lease_principal DECIMAL(16,2), closing_lease_liability DECIMAL(16,2), depreciation DECIMAL(16,2), closing_asset DECIMAL(16,2), PRIMARY KEY(branch_id,month_end)',
 'branch_financials': 'branch_id INT PRIMARY KEY, interest_income DECIMAL(16,2), fee_income DECIMAL(16,2), other_income DECIMAL(16,2), funding_cost DECIMAL(16,2), source_opex DECIMAL(16,2), source_premises_allowance_removed DECIMAL(16,2), other_opex DECIMAL(16,2), premises_book_cost DECIMAL(16,2), property_tax DECIMAL(16,2), impairment_expense DECIMAL(16,2), profit_before_tax DECIMAL(16,2)',
 'tax_reconciliation': 'tax_year INT PRIMARY KEY, profit_before_tax DECIMAL(18,2), lease_book_cost_added_back DECIMAL(18,2), contractual_rent_deducted DECIMAL(18,2), owned_book_depreciation_added_back DECIMAL(18,2), owned_tax_depreciation_deducted DECIMAL(18,2), impairment_added_back DECIMAL(18,2), taxable_profit_before_losses DECIMAL(18,2), current_tax DECIMAL(18,2), advances_paid DECIMAL(18,2), tax_payable DECIMAL(18,2), profit_after_current_tax DECIMAL(18,2)',
 'tax_payments': 'payment_id INT PRIMARY KEY, paid_on DATE, tax_type VARCHAR(40), amount DECIMAL(16,2)',
 'scenario_metadata': 'item VARCHAR(80) PRIMARY KEY, value TEXT',
}

class Writer:
    def __init__(self):
        self.path = HERE / '05_historical_2025.sql'
        self.temporary = HERE / ('05_historical_2025.sql.'+str(os.getpid())+'.building')
        self.f = self.temporary.open('w', encoding='utf-8', newline='\n')
        self.buffers = defaultdict(list)
        self.counts = defaultdict(int)
        self.f.write('-- Synthetic historical reporting scenario. Not a live-banking migration.\n'
                     '-- A fresh schema name is required. Do not use mysql --force.\n'
                     'CREATE DATABASE banking_portfolio_2025 CHARACTER SET utf8mb4;\n'
                     'USE banking_portfolio_2025;\nSET NAMES utf8mb4;\n')
        for t, ddl in SCHEMA.items():
            self.f.write(f'CREATE TABLE {t} ({ddl}) ENGINE=InnoDB;\n')
        self.f.write('START TRANSACTION;\n')
    def row(self, table, *values):
        def quote(v):
            if v is None: return 'NULL'
            if isinstance(v, bool): return str(int(v))
            if isinstance(v, (int, D)): return str(v)
            return "'" + str(v).replace('\\', '\\\\').replace("'", "''") + "'"
        self.buffers[table].append('(' + ','.join(map(quote, values)) + ')')
        self.counts[table] += 1
        if len(self.buffers[table]) >= 500: self.flush(table)
    def flush(self, table):
        if self.buffers[table]:
            self.f.write(f'INSERT INTO {table} VALUES\n' + ',\n'.join(self.buffers[table]) + ';\n')
            self.buffers[table].clear()
    def finish(self):
        for t in SCHEMA: self.flush(t)
        self.f.write('COMMIT;\n')
        self.f.write((HERE / 'views.sql').read_text())
        self.f.write("\nSELECT 'Historical data loaded. Run 06_checks.sql; all issues must be zero.' AS next_step;\n")
        self.f.close()
        self.temporary.replace(self.path)

def incomes(customers, w):
    result = {}
    for c in customers:
        cid = c['customer_id']; rng = random.Random(701000 + cid)
        base = rnd(c['annual_income'] * 100 / 12)
        variable = c['employment_status'] in ['Self-employed', 'Student', 'Unemployed']
        shock_start = rng.randint(1, 60) if rng.random() < .20 else -100
        shock_len = rng.randint(2, 5)
        months = {}; d = START; i = 0
        while d <= CUTOFF:
            shock = shock_start <= i < shock_start + shock_len
            # Existing income is a synthetic anchor, not calibrated population statistics.
            factor = D(str(rng.uniform(.70, 1.30) if variable else rng.uniform(.94, 1.06)))
            if shock: factor *= D('.55')
            net = max(0, rnd(base * factor))
            essential = max(25000, rnd(base * D('.45')))
            day = monthend(d); months[day] = (net, essential, shock)
            w.row('customer_income', cid, day, money(net), money(essential), shock)
            d = addmonths(d, 1); i += 1
        result[cid] = months
    return result

def simulate_loan(l, income, w, payment_counter, episode_counter, restructure_counter):
    lid = l['loan_id']; cid = l['customer_id']; rng = random.Random(905000 + lid)
    issued = date.fromisoformat(l['issue_date']); maturity = date.fromisoformat(l['maturity_date'])
    principal = rnd(l['loan_amount'] * 100); original = principal; rate = l['annual_interest_rate']
    periods = (maturity.year-issued.year)*12 + maturity.month-issued.month + 1
    scheduled = math.ceil(principal / periods)
    behaviour = rng.choices(['Reliable','Occasional delay','Repeated delays','Long delay','Stops paying'], [64,17,10,6,3])[0]
    never_after = issued + timedelta(days=rng.randint(90, 730))
    day = issued; dues = []; unbilled = 0; carry = D(0); total_interest = 0
    month_interest = month_p = month_i = 0; paid_p = paid_i = 0
    episode = None; episodes = []; states = []; restructured = False; planned_payments = set()
    current_maturity = monthend(maturity); since = None; interest_2025 = 0
    while day <= CUTOFF:
        unpaid = [x for x in dues if not x['rescheduled'] and x['p']+x['i']>0]
        oldest = min((x['date'] for x in unpaid), default=None)
        dpd = (day-oldest).days if oldest else 0
        if dpd > 0 and episode is None:
            episode = {'first': oldest, 'max': 0, 'charged': 0, 'interest': 0, 'closed': None, 'method': 'Unresolved', 'observations': {}}
        if episode:
            episode['max'] = max(episode['max'], dpd)
        # Episode duration does not reset when partial payments move the oldest due date.
        episode_day = (day-episode['first']).days if episode else 0
        freeze = episode_day > 90
        # Once during 2025, selected 30-60 day arrears are restructured at a month start.
        if day.year == 2025 and day.day == 1 and 30 <= dpd <= 60 and not restructured and lid % 4 == 0:
            oldmonths = max(1, (current_maturity.year-day.year)*12 + current_maturity.month-day.month+1)
            oldprojected = rnd(D(principal)*rate*D(oldmonths+1)/2400)
            oldrate = rate
            if lid % 8 == 0:
                rate = max(D('1'), rate-D('1'))
                newmonths = max(oldmonths+12, math.ceil(D(oldmonths+1)*oldrate/rate)+1)
                strategy = 'Longer term lower rate'
            else:
                rate += D('1'); newmonths = oldmonths; strategy = 'Rate increase at restructuring'
            projected = rnd(D(principal)*rate*D(newmonths+1)/2400)
            carried = unbilled + sum(x['i'] for x in unpaid)
            unbilled = carried
            for x in unpaid: x['rescheduled'] = True
            scheduled = math.ceil(principal/newmonths)
            current_maturity = monthend(addmonths(day, newmonths-1))
            restructure_counter[0] += 1
            w.row('restructurings', restructure_counter[0], lid, day, oldrate, rate, oldmonths, newmonths,
                  money(principal), money(carried), money(oldprojected), money(projected), strategy)
            assert projected > oldprojected
            if episode:
                episode.update(closed=day, method='Restructured'); episodes.append(episode); episode=None
            restructured = True; dpd=0
        # Apply the rate effective today before today's accrual.
        episode_day = (day-episode['first']).days if episode else 0
        freeze = episode_day > 90
        accrued = 0
        if not freeze and principal:
            carry += D(principal) * rate / D(36500)
            accrued = rnd(carry); carry -= accrued
            unbilled += accrued; month_interest += accrued; total_interest += accrued
            if day.year == 2025: interest_2025 += accrued
        if episode and episode_day <= 90:
            episode['charged'] += 1; episode['interest'] += accrued
        if day == monthend(day) and (principal or unbilled):
            outstanding_due = sum(x['p'] for x in dues if not x['rescheduled'])
            p = min(scheduled, max(0, principal-outstanding_due))
            if day >= current_maturity: p = max(0, principal-outstanding_due)
            dues.append({'date':day,'p':p,'i':unbilled,'op':p,'oi':unbilled,'pp':0,'pi':0,'rescheduled':False})
            unbilled=0
            lag = 0
            if behaviour == 'Occasional delay': lag = rng.choice([0,0,0,0,7,20,35])
            elif behaviour == 'Repeated delays': lag = rng.choice([0,0,15,35,65,95])
            elif behaviour == 'Long delay': lag = rng.choice([0,0,40,65,120,160])
            elif behaviour == 'Stops paying' and day >= never_after: lag = 9999
            if income[day][2] and lag < 9999: lag += 30
            if lag < 9999: planned_payments.add(day+timedelta(days=lag))
        if day in planned_payments:
            due = [x for x in dues if not x['rescheduled'] and x['date']<=day and x['p']+x['i']>0]
            amount = sum(x['p']+x['i'] for x in due)
            if behaviour in ['Repeated delays','Long delay'] and rng.random()<.20:
                amount //= 2
            ppaid=ipaid=0; budget=amount
            # Global interest first, then oldest principal; never pay more than due.
            for x in due:
                take=min(budget,x['i']); x['i']-=take; x['pi']+=take; ipaid+=take; budget-=take
            for x in due:
                take=min(budget,x['p']); x['p']-=take; x['pp']+=take; ppaid+=take; budget-=take
            if amount:
                principal-=ppaid; paid_p+=ppaid; paid_i+=ipaid; month_p+=ppaid; month_i+=ipaid
                payment_counter[0]+=1
                w.row('loan_payments',payment_counter[0],lid,day,money(ppaid),money(ipaid),money(amount),'External settlement simulation')
            if episode and not any(x['p']+x['i']>0 and not x['rescheduled'] for x in dues):
                episode.update(closed=day,method='Paid arrears'); episodes.append(episode); episode=None
        if day == monthend(day):
            oldest=min((x['date'] for x in dues if not x['rescheduled'] and x['p']+x['i']>0),default=None)
            dpd=(day-oldest).days if oldest else 0
            rec=unbilled+sum(x['i'] for x in dues if not x['rescheduled'])
            state=(day,principal,rec,dpd,scheduled,rate)
            states.append(state)
            if episode: episode['observations'][day] = episode['max']
            w.row('loan_month_end',lid,day,money(principal),money(rec),money(month_interest),money(month_p),money(month_i),dpd,
                  episode['charged'] if episode else 0,bool(episode and (day-episode['first']).days>90),rate,money(min(principal,scheduled)))
            month_interest=month_p=month_i=0
        day+=timedelta(days=1)
    if episode: episodes.append(episode)
    for ep in episodes:
        assert ep['charged']<=90
        episode_counter[0]+=1
        w.row('arrears_episodes',episode_counter[0],lid,cid,ep['first'],ep['closed'],ep['method'],ep['max'],ep['charged'],money(ep['interest']))
    for x in dues:
        w.row('loan_due_items',lid,x['date'],money(x['op']),money(x['oi']),money(x['pp']),money(x['pi']),x['rescheduled'])
    assert original-paid_p==principal
    rec=unbilled+sum(x['i'] for x in dues if not x['rescheduled'])
    assert total_interest-paid_i==rec, (lid,total_interest,paid_i,rec)
    dpd=states[-1][3]
    status='Paid' if principal+rec==0 else ('Overdue' if dpd>0 else 'Active')
    w.row('loans',lid,cid,l['branch_id'],l['loan_type'],issued,maturity,l['annual_interest_rate'],money(original),l['outstanding_amount'],
          money(principal),money(rec),rate,current_maturity,status,dpd,behaviour)
    return {'loan':l,'states':states,'episodes':episodes,'interest_2025':interest_2025,'principal':principal,'receivable':rec,'dpd':dpd}

def assess(customers, income, simulations, w):
    bycustomer=defaultdict(list)
    for s in simulations: bycustomer[s['loan']['customer_id']].append(s)
    decisions=defaultdict(int)
    for c in customers:
        cid=c['customer_id']; loans=bycustomer[cid]
        for month in range(1,13):
            day=monthend(date(2025,month,1))
            recent=[v for d,v in income[cid].items() if addmonths(day,-6)<d<=day]
            avg=rnd(D(sum(x[0] for x in recent))/len(recent)); expenses=rnd(D(sum(x[1] for x in recent))/len(recent))
            maxdpd=0; episodes=0; active=False; blocked=None; severe_unresolved=False; debt=0
            history=[]
            for s in loans:
                state=next((x for x in s['states'] if x[0]==day),None)
                if state and state[1]+state[2]>0:
                    debt+=state[4]+rnd(D(state[1])*state[5]/1200)
                    active |= state[3]>0
                for ep in s['episodes']:
                    if ep['first']>=day: continue
                    age=ep['max'] if ep['closed'] and ep['closed']<=day else ep['observations'].get(day,0)
                    maxdpd=max(maxdpd,age); episodes+=1
                    history.append((ep,age))
            # Across ALL of a customer's loans: a later episode inside the ban restarts it.
            for ep,age in sorted(history,key=lambda x:x[0]['first']):
                relevant=age>90 or (blocked is not None and ep['first']<blocked)
                if relevant:
                    if not ep['closed'] or ep['closed']>day or ep['method']!='Paid arrears':
                        severe_unresolved=True
                    else:
                        until=addmonths(ep['closed'],12)
                        blocked=max(blocked or until,until)
            cap=D('.35') if loans else D('.25')
            if maxdpd>90: cap=D('.10')
            elif maxdpd>60: cap=D('.10')
            elif maxdpd>30 or episodes>=3: cap=D('.15')
            elif maxdpd>0: cap=D('.25')
            decision='Eligible for assessment'
            if active or severe_unresolved: decision='Decline: unresolved arrears'; cap=D(0)
            elif blocked and day<blocked: decision='Decline: 12-month exclusion'; cap=D(0)
            elif maxdpd>60: decision='Manual review required'
            available=max(0,min(rnd(D(avg)*cap)-debt,avg-expenses-debt))
            limit=rnd(D(available)*(1-(1+D('.18')/12)**(-36))/(D('.18')/12)) if available else 0
            if not available and cap>0: decision='Decline: affordability'
            w.row('credit_assessments',cid,day,maxdpd,episodes,money(avg),money(debt),cap,money(available),money(limit),decision,blocked)
            if month==12: decisions[decision]+=1
    return dict(decisions)

def premises(branches,w):
    costs={}; leasebook=rent=ownbook=owntax=0
    for b in branches:
        bid=b['branch_id']; rng=random.Random(3000+bid); owned=bid<=5
        area=rng.randint(100,300); monthly=area*rng.randint(12,35)*100
        depreciation=0; taxdep=0; propertytax=0; totalcost=0
        if owned:
            cost=area*rng.randint(1200,2500)*100
            depreciation=rnd(D(cost)/40); taxdep=rnd(D(cost)*D('.07'))
            propertytax=rnd(D(cost+cost-taxdep)/2*D('.01'))
            ownbook+=depreciation; owntax+=taxdep
            w.row('premises',bid,'Owned','None',area,money(0),None,None,money(0),0,money(0),money(0),money(cost))
            depsofar=0
            for m in range(1,13):
                dep=rnd(D(depreciation)*m/12)-depsofar;depsofar+=dep
                w.row('premises_monthly',bid,monthend(date(2025,m,1)),money(0),money(0),money(0),money(0),money(0),money(0),money(0),money(0),money(dep),money(cost-depsofar))
            totalcost=depreciation
        else:
            individual=bid%2==0; rate=D('.10')/12
            pv=rnd(D(monthly)*(1-(1+rate)**(-60))/rate); liability=pv; asset=pv; depsofar=0; previouswh=0
            w.row('premises',bid,'Rented','Resident individual' if individual else 'Resident company',area,money(monthly),date(2025,1,1),date(2029,12,31),money(monthly*2),10,money(pv),money(pv),money(0))
            for m in range(1,13):
                interest=rnd(D(liability)*rate); p=monthly-interest; liability-=p
                dep=rnd(D(pv)*m/60)-depsofar;depsofar+=dep;asset-=dep
                wh=rnd(D(monthly)*D('.14')) if individual else 0
                # Prior month's withholding remitted during current month; December stays payable.
                w.row('premises_monthly',bid,monthend(date(2025,m,1)),money(monthly),money(monthly-wh),money(wh),money(previouswh),money(wh),money(interest),money(p),money(liability),money(dep),money(asset))
                previouswh=wh; totalcost+=interest+dep; rent+=monthly
            leasebook+=totalcost
        costs[bid]=(totalcost,propertytax)
    return costs,(leasebook,rent,ownbook,owntax)

def financials(source,simulations,costs,taxparts,w):
    accrued=defaultdict(int); impair=defaultdict(int)
    for s in simulations:
        bid=s['loan']['branch_id'];accrued[bid]+=s['interest_2025']
        # Transparent portfolio overlay, NOT IFRS 9 ECL or regulatory provisioning.
        pct=D('.01') if s['dpd']<=30 else D('.05') if s['dpd']<=90 else D('.50')
        impair[bid]+=rnd(D(s['principal']+s['receivable'])*pct)
    profit=0
    for f in source:
        bid=f['branch_id']; fee=rnd(f['fee_income']*100); other=rnd(f['other_income']*100)
        funding=rnd(f['interest_expense']*100); opex=rnd(f['operating_expense']*100)
        removed=rnd(D(opex)*D('.15')); otheropex=opex-removed
        book,prop=costs[bid]
        p=accrued[bid]+fee+other-funding-otheropex-book-prop-impair[bid];profit+=p
        w.row('branch_financials',bid,*map(money,[accrued[bid],fee,other,funding,opex,removed,otheropex,book,prop,impair[bid],p]))
    leasebook,rent,ownbook,owntax=taxparts
    adjustment=sum(impair.values())
    taxable=profit+leasebook-rent+ownbook-owntax+adjustment
    tax=rnd(D(max(0,taxable))*D('.20'))
    # Demonstration instalments, not a claimed reconstruction of Article 151 payments.
    advances=0
    for i,day in enumerate([date(2025,4,15),date(2025,7,15),date(2025,10,15)],1):
        amount=rnd(D(tax)*D('.15'));advances+=amount
        w.row('tax_payments',i,day,'Synthetic corporate tax advance',money(amount))
    w.row('tax_reconciliation',2025,*map(money,[profit,leasebook,rent,ownbook,owntax,adjustment,taxable,tax,advances,tax-advances,profit-tax]))
    return {k:money(v) for k,v in {'profit_before_tax':profit,'taxable_profit':taxable,'current_tax':tax,'advances':advances,'tax_payable':tax-advances,'profit_after_current_tax':profit-tax,'impairment_overlay':adjustment}.items()}

def main():
    source,sha=source_rows();w=Writer()
    for b in source['branches']: w.row('branches',b['branch_id'],b['branch_name'],b['city'],b['employee_count'])
    for c in source['customers']: w.row('customers',c['customer_id'],c['forename'],c['surname'],c['employment_status'],c['annual_income'])
    print('Generating income history...',flush=True)
    income=incomes(source['customers'],w)
    pay=[0];ep=[0];res=[0];sims=[]
    for i,l in enumerate(source['loans'],1):
        sims.append(simulate_loan(l,income[l['customer_id']],w,pay,ep,res))
        if i%2000==0: print(f'Replayed {i} loans',flush=True)
    decisions=assess(source['customers'],income,sims,w)
    costs,taxparts=premises(source['branches'],w)
    finance=financials(source['branch_financials'],sims,costs,taxparts,w)
    metadata={'as_of':'2025-12-31','source_sha256':sha,'version':'historical-2025-v1','interest_policy':'Actual/365 simple daily; freeze ALL new interest after 90 consecutive arrears days; no penalty interest; no compounding',
              'scope':'Standalone reporting scenario. External loan settlements; no debit to legacy accounts. Not a live V2 migration.',
              'tax_scope':'Illustrative current corporate tax, rental withholding and premises property tax. No deferred tax, payroll tax, full VAT or regulatory return.',
              'source_operating_expense_bridge':'15% assumed legacy premises allowance removed before replacement; synthetic allocation, not observed.',
              'status':'COMPLETE_GENERATION_NOT_SERVER_VALIDATION'}
    for k,v in metadata.items(): w.row('scenario_metadata',k,v)
    w.finish()
    results={'as_of':str(CUTOFF),'counts':dict(w.counts),'finance_azn':finance,'decisions_december':decisions,
             'outstanding_principal_azn':money(sum(s['principal'] for s in sims)),
             'original_source_sha256':sha,'sql_sha256':hashlib.sha256(w.path.read_bytes()).hexdigest(),
             'assertions':'All-loan principal and interest conservation; <=90 charged days per episode; restructuring projected interest higher.'}
    (HERE/'results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results,indent=2),flush=True)

if __name__=='__main__':
    lock=HERE/'build.lock'
    try:
        handle=lock.open('x')
    except FileExistsError:
        raise SystemExit('Another build may be running. Wait for it. If a previous build crashed, remove build.lock only after confirming it has stopped.')
    try:
        handle.write(str(os.getpid()));handle.close();main()
    finally:
        lock.unlink(missing_ok=True)
