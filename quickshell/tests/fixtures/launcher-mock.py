import json
from pathlib import Path
import sys

rows = {
 'apps':[{'id':'app:alpha-editor','title':'Alpha Editor','detail':'Text editor'},
         {'id':'app:alpha-viewer','title':'Alpha Viewer','detail':'Viewer'},
         {'id':'app:beta','title':'Beta','detail':'Other app'}],
 'books':[{'id':'book:alpha','title':'Alpha Book','detail':'Example author · epub'},
          {'id':'book:alpha2','title':'Alpha Book Two','detail':'Example author · pdf'}],
 'clipboard':[{'id':'clip:1','title':'Example clipboard fixture','detail':'','clipboardKind':'text'}],
 'widgets':[{'id':'profile:balanced','title':'Balanced','detail':'Power profile','selected':True},
            {'id':'idle:auto','title':'Sleep after 25 min','detail':'Suspend after 25 minutes of inactivity.','selected':True,'known':True,'blockedByOther':True},
            {'id':'idle:awake','title':'Stay awake','detail':'Pause automatic sleep until you switch back or log out.','selected':False,'known':True,'blockedByOther':True}],
 'shortcuts':[], 'power':[]}
def emit(value): print(json.dumps(value),flush=True)
def publish(category): emit({'type':'catalog','category':category,'rows':rows[category],'loading':False,'message':''})
publish('apps')
for line in sys.stdin:
    command=json.loads(line)
    with Path(__file__).with_name('commands.jsonl').open('a') as stream: stream.write(json.dumps(command)+'\n')
    if command['action']=='show': publish(command['category'])
    elif command['action']=='activate':
        if command['category']=='widgets':
            rows['widgets'][1]['selected']=command['id']=='idle:auto'
            rows['widgets'][2]['selected']=command['id']=='idle:awake'
            publish('widgets')
        emit({'type':'activated','id':command['id']})
    elif command['action']=='covers':
        emit({'type':'cover','id':'book:alpha','source':''})
