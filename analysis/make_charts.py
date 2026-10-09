"""Charts for the final Alov Bank scenario. Python 3.10+, matplotlib."""
from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter
R=Path(__file__).resolve().parents[1]
m=json.loads((R/'historical_2025/results.json').read_text())
t=json.loads((R/'analysis/chart_data.json').read_text())['monthly']
A=R/'assets';A.mkdir(exist_ok=True)
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.spines.top':False,'axes.spines.right':False,'figure.facecolor':'#f5f3ee','axes.facecolor':'#f5f3ee','text.color':'#25343c','axes.labelcolor':'#25343c'})
def finish(fig,name,note):
 fig.text(.07,.035,'Synthetic educational data | Final scenario: 31 Dec 2025\n'+note,fontsize=9,color='#52646e')
 fig.savefig(A/name,dpi=180,bbox_inches='tight');plt.close(fig)
f={k:float(v)/1e6 for k,v in m['finance_azn'].items()}
fig,ax=plt.subplots(figsize=(11,6));fig.subplots_adjust(left=.26,bottom=.2,top=.82,right=.88)
labels=['Taxable profit','Impairment expense','Profit before tax','Current tax','Profit after current tax'];values=[f['taxable_profit'],f['impairment_overlay'],f['profit_before_tax'],f['current_tax'],f['profit_after_current_tax']]
ax.barh(labels[::-1],values[::-1],color=['#dc662e','#8197a4','#253f4e','#8197a4','#253f4e']);ax.set_xlim(0,62);ax.set_xlabel('AZN millions');ax.grid(axis='x',alpha=.15);ax.set_axisbelow(True)
for i,v in enumerate(values[::-1]):ax.text(v+.7,i,f'{v:,.2f}',va='center',fontweight='bold')
fig.suptitle('ALOV BANK | Financial results',x=.07,y=.97,ha='left',fontsize=22,fontweight='bold')
finish(fig,'financial_overview.png','Measures are distinct, not additive. Illustrative impairment and current-tax model; no deferred tax.')
fig,ax=plt.subplots(figsize=(11,6));fig.subplots_adjust(left=.34,bottom=.2,top=.82,right=.88)
pairs=list(m['decisions_december'].items());labels=[x[0].replace('Decline: ','Declined: ') for x in pairs];values=[x[1] for x in pairs]
ax.barh(labels[::-1],values[::-1],color=['#8197a4','#dc662e','#dc662e','#dc662e','#253f4e']);ax.set_xlim(0,26000);ax.set_xlabel('Customers');ax.xaxis.set_major_formatter(FuncFormatter(lambda x,_:f'{x:,.0f}'));ax.grid(axis='x',alpha=.15);ax.set_axisbelow(True)
for i,v in enumerate(values[::-1]):ax.text(v+350,i,f'{v:,} ({v/30000:.1%})',va='center',fontsize=10)
fig.suptitle('ALOV BANK | Lending assessments',x=.07,y=.97,ha='left',fontsize=22,fontweight='bold')
finish(fig,'lending_assessments.png','30,000 customers assessed at year-end. Eligibility means further assessment, not credit approval.')
fig,(ax,bx)=plt.subplots(2,1,figsize=(11,8),sharex=True);fig.subplots_adjust(left=.1,bottom=.16,top=.86,hspace=.35,right=.94)
x=list(range(12));ax.plot(x,[r['outstanding_principal']/1e9 for r in t],color='#253f4e',linewidth=2.5,marker='o');ax.set_ylabel('Outstanding principal\nAZN billions');ax.grid(alpha=.15)
bx.plot(x,[r['loans_over_90_days'] for r in t],color='#dc662e',linewidth=2,marker='o',label='Over 90 days overdue');bx.plot(x,[r['loans_with_frozen_interest'] for r in t],color='#253f4e',linewidth=2,marker='o',label='Frozen interest');bx.set_ylabel('Loan count');bx.set_xticks(x,[r['month'][:3] for r in t]);bx.legend(frameon=False,loc='upper left');bx.grid(alpha=.15)
fig.suptitle('ALOV BANK | Loan book through 2025',x=.07,y=.97,ha='left',fontsize=22,fontweight='bold')
finish(fig,'loan_trends.png','Inherited loan book; no new originations. Counts are not a balance-weighted NPL ratio.')
print('Created three final-scenario charts')
