"""Render report visuals from snapshot_metrics.json. Requires matplotlib."""
from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
R=Path(__file__).resolve().parents[1];m=json.loads((R/('analysis/expanded_metrics.json' if (R/'analysis/expanded_metrics.json').exists() else 'analysis/snapshot_metrics.json')).read_text());f=m['financial_totals'][0];d=m['derived']
navy='#142B45';teal='#147D83';gold='#C58124';gray='#647589';bg='#F6F8FB';red='#B65D46'
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'axes.labelcolor':navy,'text.color':navy,'axes.edgecolor':'#D2DCE5','xtick.color':gray,'ytick.color':navy,'figure.facecolor':bg,'axes.facecolor':bg,'savefig.facecolor':bg})
def footer(fig,t):fig.text(.055,.025,t,fontsize=9,color=gray)
def save(fig,name):fig.savefig(R/'assets'/name,dpi=170,bbox_inches='tight');plt.close(fig)
fig,axs=plt.subplots(2,2,figsize=(13,9));fig.subplots_adjust(top=.83,bottom=.13,hspace=.47,wspace=.4)
fig.suptitle('BANK PORTFOLIO  /  Financial snapshot',x=.055,y=.97,ha='left',fontsize=23,fontweight='bold')
fig.text(.055,.91,'30,000 customers     •     25 branches     •     AZN 1.140bn deposits     •     AZN 885.5m outstanding loans',fontsize=12)
a=axs[0,0];labels=['Interest income','Other income','Fee income'];vals=[f[x]/1e6 for x in ['interest_income','other_income','fee_income']];a.barh(labels,vals,color=[teal,gray,gold]);a.invert_yaxis();a.set_title('97.4% of revenue comes from interest',loc='left',fontweight='bold');a.set_xlabel('AZN million');a.set_xlim(0,102)
for i,v in enumerate(vals):a.text(v+1,i,f'{v:,.2f}',va='center')
a=axs[0,1];labs=['Revenue','Interest\nexpense','Operating\nexpense','Reported\nprofit'];vs=[f[x]/1e6 for x in ['total_revenue','interest_expense','operating_expense','net_profit']];a.bar(labs,vs,color=[teal,gray,gray,navy]);a.set_ylim(0,105);a.set_ylabel('AZN million');a.tick_params(axis='x',labelsize=8);a.set_title('AZN 35.77m reported model profit',loc='left',fontweight='bold')
for i,v in enumerate(vs):a.text(i,v+2,f'{v:.2f}',ha='center')
a=axs[1,0];ls=m['loans'];a.barh([r['loan_type'] for r in ls],[r['outstanding']/1e6 for r in ls],color=[navy,teal,teal,teal,gold]);a.invert_yaxis();a.set_xlim(0,780);a.set_xlabel('Outstanding principal · AZN million');a.set_title('Mortgages account for 73.5% of loans',loc='left',fontweight='bold')
for i,r in enumerate(ls):a.text(r['outstanding']/1e6+9,i,f"{r['outstanding']/d['outstanding_loans']:.1%}",va='center')
a=axs[1,1];ac=m['accounts'];a.barh([r['account_type'] for r in ac],[r['balance']/1e6 for r in ac],color=[teal,navy,gray,gold]);a.invert_yaxis();a.set_xlabel('Account balances · AZN million');a.set_title('Savings hold 52.9% of deposits',loc='left',fontweight='bold')
footer(fig,'Synthetic data • Financial table labeled 2025; balances from exported snapshot • Profit excludes unmodeled tax/provision adjustments.\nSource: branch_financials, accounts and loans. No comparison with real banks is implied.')
save(fig,'financial_overview.png')
fig,axs=plt.subplots(1,2,figsize=(13,5.6));fig.subplots_adjust(top=.77,bottom=.22,wspace=.45);fig.suptitle('RISK & CONCENTRATION  /  Where to focus',x=.055,y=.95,ha='left',fontsize=21,fontweight='bold')
a=axs[0];ls=sorted(m['loans'],key=lambda r:r['overdue_outstanding']/r['outstanding'],reverse=True);vals=[100*r['overdue_outstanding']/r['outstanding'] for r in ls];a.barh([r['loan_type'] for r in ls],vals,color=gold);a.invert_yaxis();a.set_xlim(0,7.4);a.axvline(d['overdue_exposure_percent'],color=navy,linestyle='--',label='Whole portfolio: 4.46%');a.set_xlabel('Overdue-labeled principal / product outstanding (%)');a.legend(loc='lower right',fontsize=8);a.set_title('Relative delinquency differs by product',loc='left',fontweight='bold')
for i,v in enumerate(vals):a.text(v+.08,i,f'{v:.2f}%',va='center')
a=axs[1];regions=m['regions'];a.barh([r['region'] for r in regions],[r['net_profit']/f['net_profit']*100 for r in regions],color=[navy]+[teal]*7);a.invert_yaxis();a.set_xlim(0,87);a.set_xlabel('Share of reported profit (%)');a.set_title('Absheron contributes 75.4% of profit',loc='left',fontweight='bold')
for i,r in enumerate(regions):a.text(r['net_profit']/f['net_profit']*100+1,i,f"{r['net_profit']/f['net_profit']:.1%}",va='center')
footer(fig,'Synthetic snapshot • “Overdue” is a stored label, not a verified 90-day NPL classification.\nAbsheron is the dataset’s region grouping; its branch composition is documented in the report.')
save(fig,'risk_concentration.png')
fig,a=plt.subplots(figsize=(13,5.6));fig.subplots_adjust(top=.76,bottom=.23);fig.suptitle('TRANSACTION HISTORY  /  Expanded 2025 simulation',x=.055,y=.96,ha='left',fontsize=20,fontweight='bold')
months=[x['month'] for x in m['monthly_transactions']];bottom=[0]*12
for typ,col in [('Deposit',teal),('Withdrawal',navy),('Fee',gold)]:
 vals=[sum(x['gross_amount'] for x in m['monthly_types'] if x['month']==mo and x['transaction_type']==typ)/1e6 for mo in months];a.bar(range(12),vals,bottom=bottom,color=col,label=typ);bottom=[a+b for a,b in zip(bottom,vals)]
a.set_xticks(range(12),[x[-2:] for x in months]);a.set_xlabel('2025 month');a.set_ylabel('Gross recorded amount · AZN million');a.legend(ncol=3,loc='upper right');a.set_ylim(0,220);a.text(.015,.95,'14,585,400 rows · 1–80 per customer/month',transform=a.transAxes,va='top',fontsize=10)
footer(fig,'Synthetic scenario • Includes AZN 83.57m of labeled closing-balance reconciliation entries; total activity is not revenue.\nAll 2025 months are covered. Original balances and fee totals are preserved; no real growth or seasonality is implied.')
save(fig,'transaction_pattern.png')
print('Created three charts.')
