import json, sys
from pathlib import Path
snapshot = {'type': 'snapshot', 'ready': True, 'available': True, 'wifiEnabled': True, 'hardwareEnabled': True, 'hasWifi': True, 'managed': True, 'busy': False, 'scanning': False, 'message': '', 'rows': [{'id': 'new', 'name': 'Example <Wi-Fi>', 'security': 'WPA / WPA2', 'personal': True, 'supported': True, 'known': False, 'connected': False, 'connecting': False, 'signal': 80}, {'id': 'saved', 'name': 'Saved network', 'security': 'WPA / WPA2', 'personal': True, 'supported': True, 'known': True, 'connected': False, 'connecting': False, 'signal': 60}]}
print(json.dumps(snapshot), flush=True)
for line in sys.stdin:
 command=json.loads(line)
 with open(Path(__file__).with_name('commands.jsonl'),'a') as log: log.write(json.dumps(command)+'\n')
 if command.get('action')=='connect': print(json.dumps({'type':'password','id':command['id'],'retry':True}),flush=True)
