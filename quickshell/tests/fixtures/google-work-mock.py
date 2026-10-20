import json
from pathlib import Path
import sys
import time

now = int(time.time() * 1000)
snapshot = {'type': 'snapshot', 'authorizing': False,
    'gmail': {'status': 'ok', 'unread': 2, 'canMarkRead': True, 'busyIds': [], 'rows': [
        {'id': 'one', 'sender': 'Example sender', 'subject': '<b>Literal subject</b>', 'preview': 'A short preview', 'date': now, 'group': 'Example'},
        {'id': 'two', 'sender': 'Another sender', 'subject': 'Second message', 'preview': 'Another preview', 'date': now, 'group': '@example'}]},
    'calendar': {'status': 'ok', 'rows': [
        {'id': 'meeting', 'title': 'Example meeting', 'start': now, 'end': now+3600000, 'allDay': False, 'kind': 'default'}]}}
def emit(): print(json.dumps(snapshot), flush=True)
emit()
for line in sys.stdin:
    command = json.loads(line)
    with Path(__file__).with_name('commands.jsonl').open('a') as output:
        output.write(json.dumps(command)+'\n')
    if command.get('action') == 'read':
        if command['id'] == 'one':
            snapshot['gmail']['rows'] = [row for row in snapshot['gmail']['rows'] if row['id'] != 'one']
            snapshot['gmail']['unread'] = 1
        else:
            snapshot['gmail'].update(status='stale',message='Could not mark this message as read. Retry.')
        emit()
