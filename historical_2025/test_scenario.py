"""Behavioural boundary tests against the actual generator, not a second formula copy."""
import unittest
from unittest.mock import patch
from datetime import date
from decimal import Decimal as D
from collections import defaultdict
import build

class Capture:
    def __init__(self): self.rows=defaultdict(list)
    def row(self,t,*values): self.rows[t].append(values)

class Delayed:
    def __init__(self,partial=False): self.n=0; self.partial=partial
    def choices(self,*a,**kw): return ['Long delay']
    def randint(self,*a): return 90
    def choice(self,*a):
        self.n+=1
        return 160 if self.n in [1,7] else 9999
    def random(self): return .1 if self.partial else .9

def fixture(partial=False):
    w=Capture()
    loan=dict(loan_id=1,customer_id=1,branch_id=1,loan_type='Personal',issue_date='2025-01-01',maturity_date='2025-12-31',loan_amount=D('12000'),outstanding_amount=D('12000'),annual_interest_rate=D('12'))
    income={build.monthend(date(2025,m,1)):(500000,100000,False) for m in range(1,13)}
    with patch.object(build.random,'Random',return_value=Delayed(partial)):
        result=build.simulate_loan(loan,income,w,[0],[0],[0])
    return w,result

class ScenarioTests(unittest.TestCase):
    def test_interest_stops_but_delay_continues(self):
        w,s=fixture()
        june=next(x for x in w.rows['loan_month_end'] if x[1]==date(2025,6,30))
        self.assertGreater(june[7],90)
        self.assertEqual(D(june[4]),0)
        self.assertEqual(june[8],90)
        self.assertTrue(june[9])
    def test_cure_restarts_accrual_and_new_episode_has_own_cap(self):
        w,s=fixture()
        self.assertEqual(len(s['episodes']),2)
        self.assertEqual(s['episodes'][0]['closed'],date(2025,7,10))
        self.assertEqual([e['charged'] for e in s['episodes']],[90,90])
        july=next(x for x in w.rows['loan_month_end'] if x[1]==date(2025,7,31))
        self.assertGreater(D(july[4]),0)
    def test_partial_payment_does_not_restart_cap(self):
        w,s=fixture(True)
        self.assertEqual(len(s['episodes']),1)
        self.assertEqual(s['episodes'][0]['charged'],90)
        july=next(x for x in w.rows['loan_month_end'] if x[1]==date(2025,7,31))
        self.assertEqual(D(july[4]),0)
        self.assertTrue(july[9])
    def test_no_future_cash_or_restructuring(self):
        w,s=fixture()
        self.assertTrue(all(x[2]<=build.CUTOFF for x in w.rows['loan_payments']))
        self.assertTrue(all(x[2]<=build.CUTOFF for x in w.rows['restructurings']))
    def test_money_is_conserved(self):
        w,s=fixture()
        principal=sum(D(x[3]) for x in w.rows['loan_payments'])
        self.assertEqual(principal+D(s['principal'])/100,D('12000'))
    def test_twelve_month_date(self):
        self.assertEqual(build.addmonths(date(2025,3,1),12),date(2026,3,1))
    def test_exclusion_restarts_across_other_loans(self):
        w=Capture(); income={1:{}}
        for n in range(18):
            d=build.monthend(build.addmonths(date(2024,7,1),n))
            income[1][d]=(1000000,100000,False)
        states=[(build.monthend(date(2025,m,1)),0,0,0,0,D(12)) for m in range(1,13)]
        severe={'first':date(2024,11,1),'closed':date(2025,3,1),'max':120,'method':'Paid arrears','observations':{date(2025,1,31):91,date(2025,2,28):119}}
        later={'first':date(2025,6,30),'closed':date(2025,7,15),'max':15,'method':'Paid arrears','observations':{}}
        sims=[{'loan':{'customer_id':1},'states':states,'episodes':[severe]}, {'loan':{'customer_id':1},'states':states,'episodes':[later]}]
        build.assess([{'customer_id':1}],income,sims,w)
        dec=w.rows['credit_assessments'][-1]
        self.assertEqual(dec[-1],date(2026,7,15))
        self.assertEqual(dec[-2],'Decline: 12-month exclusion')
        self.assertEqual(D(dec[-3]),0)
    def test_future_arrears_not_used_for_current_decision(self):
        w=Capture();income={1:{}}
        for n in range(18): income[1][build.monthend(build.addmonths(date(2024,7,1),n))]=(1000000,100000,False)
        states=[(build.monthend(date(2025,m,1)),0,0,0,0,D(12)) for m in range(1,13)]
        future={'first':date(2025,6,30),'closed':None,'max':184,'method':'Unresolved','observations':{date(2025,7,31):31,date(2025,8,31):62,date(2025,9,30):92,date(2025,10,31):123,date(2025,11,30):153,date(2025,12,31):184}}
        build.assess([{'customer_id':1}],income,[{'loan':{'customer_id':1},'states':states,'episodes':[future]}],w)
        january=w.rows['credit_assessments'][0]
        self.assertEqual(january[2],0)
        self.assertEqual(january[-2],'Eligible for assessment')
    def test_restructuring_rate_applies_from_effective_day(self):
        class RestructureDelay(Delayed):
            def choice(self,*a):
                self.n+=1
                return 65 if self.n==1 else 9999
        w=Capture()
        loan=dict(loan_id=4,customer_id=1,branch_id=1,loan_type='Personal',issue_date='2025-01-01',maturity_date='2025-12-31',loan_amount=D('12000'),outstanding_amount=D('12000'),annual_interest_rate=D('12'))
        income={build.monthend(date(2025,m,1)):(500000,100000,False) for m in range(1,13)}
        with patch.object(build.random,'Random',return_value=RestructureDelay()):
            build.simulate_loan(loan,income,w,[0],[0],[0])
        r=w.rows['restructurings'][0]
        self.assertEqual(r[2],date(2025,4,1))
        self.assertEqual(r[4],D(13))
        april=next(x for x in w.rows['loan_month_end'] if x[1]==date(2025,4,30))
        self.assertLessEqual(abs(D(april[4])-D('12000')*D('.13')*30/365),D('.01'))

if __name__=='__main__': unittest.main(verbosity=2)
