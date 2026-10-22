import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock

spec = importlib.util.spec_from_file_location('work', Path(__file__).resolve().parents[1] / 'google_work.py')
work = importlib.util.module_from_spec(spec)
spec.loader.exec_module(work)


class WorkTests(unittest.TestCase):
    def client(self):
        client = work.Client.__new__(work.Client)
        client.config = {'account': 'work@example.invalid', 'buckets': []}
        client.token = {'scopes': [work.GMAIL_SCOPE, work.CALENDAR_SCOPE]}
        client.ids, client.metadata, client.events, client.categories = [], {}, [], {}
        client.history, client.category_dirty, client.limit = '', True, 30
        client.snapshot = {'gmail': {'updatedAt': 0, 'rows': []}, 'calendar': {'updatedAt': 0, 'rows': []}}
        client.ensure_identity = Mock(return_value={'historyId': '100'})
        client.save = Mock()
        return client

    def test_exact_unread_inbox_scan_paginates_and_takes_cursor_before_scan(self):
        client = self.client()
        replies = [{'messages': [{'id': 'a'}], 'nextPageToken': 'next'}, {'messages': [{'id': 'b'}]}]
        client.api = Mock(side_effect=replies)
        client.sync_gmail()
        self.assertEqual(client.ids, ['a', 'b'])
        self.assertEqual(client.history, '100')
        self.assertEqual(client.snapshot['gmail']['unread'], 2)
        self.assertEqual(client.api.call_args_list[0].args[1]['labelIds'], ['INBOX', 'UNREAD'])
        self.assertEqual(client.api.call_args_list[1].args[1]['pageToken'], 'next')

    def test_no_matching_messages_can_return_empty_204(self):
        client = self.client()
        client.credentials = Mock(token='fixture')
        client.ensure_token = Mock()
        client.session = Mock()
        client.session.request.return_value = Mock(status_code=204, content=b'')
        self.assertEqual(client.api(work.GMAIL_API+'messages'), {})

    def test_incremental_history_updates_only_changed_ids(self):
        client = self.client()
        client.ids, client.history = ['read-now', 'unchanged'], '100'
        def api(url, params):
            if url.endswith('history'):
                return {'history': [{'messages': [{'id': 'read-now'}, {'id': 'new'}, {'id': 'new'}]}], 'historyId': '102'}
            return {'id': url.rsplit('/', 1)[1], 'labelIds': ['INBOX', 'UNREAD'] if url.endswith('/new') else ['INBOX']}
        client.api = Mock(side_effect=api)
        client.sync_gmail()
        self.assertEqual(client.ids, ['new', 'unchanged'])
        self.assertEqual(client.history, '102')
        self.assertEqual(client.api.call_count, 3)
        self.assertFalse(any('unchanged' in call.args[0] for call in client.api.call_args_list))

    def test_expired_history_cursor_rebuilds_without_false_zero(self):
        client = self.client()
        client.ids, client.history = ['existing'], 'old'
        client.api = Mock(side_effect=[work.GoogleError(404), {'messages': [{'id': 'existing'}, {'id': 'new'}]}])
        client.sync_gmail()
        self.assertEqual(client.ids, ['existing', 'new'])
        self.assertEqual(client.history, '100')

    def test_mark_read_removes_only_unread_after_server_success(self):
        client = self.client()
        client.ids = ['message']
        client.api = Mock(side_effect=work.GoogleError(503))
        with self.assertRaises(work.GoogleError): client.mark_read('message')
        self.assertEqual(client.ids, ['message'])
        client.api = Mock(return_value={})
        client.mark_read('message')
        self.assertEqual(client.ids, [])
        self.assertEqual(client.snapshot['gmail']['unread'], 0)
        self.assertEqual(client.api.call_args.kwargs['body'], {'removeLabelIds': ['UNREAD']})
        self.assertTrue(client.api.call_args.args[0].endswith('/message/modify'))
        client.mark_read('unknown')
        self.assertEqual(client.api.call_count, 1)

    def test_readonly_grant_never_dispatches_a_write(self):
        client = self.client()
        client.ids = ['message']
        client.token = {'scopes': ['https://www.googleapis.com/auth/gmail.readonly']}
        client.api = Mock()
        with self.assertRaises(work.GoogleError): client.mark_read('message')
        client.api.assert_not_called()
        self.assertEqual(client.ids, ['message'])

    def test_previews_are_partial_plain_text_and_reuse_cache(self):
        client = self.client()
        client.ids = ['message']
        client.config['buckets'] = [{'name': 'Example group', 'query': 'from:example.invalid'}]
        def api(url, params):
            if url.endswith('/messages'): return {'messages': [{'id': 'message'}]}
            self.assertNotIn('body', params['fields'])
            return {'id': 'message', 'labelIds': ['UNREAD', 'INBOX'], 'internalDate': '1000',
                    'snippet': 'Short\npreview', 'payload': {'headers': [
                        {'name': 'From', 'value': 'Example <hello@example.invalid>'},
                        {'name': 'Subject', 'value': '<b>Literal subject</b>'}]}}
        client.api = Mock(side_effect=api)
        client.previews()
        self.assertEqual(client.snapshot['gmail']['rows'][0]['preview'], 'Short preview')
        self.assertEqual(client.snapshot['gmail']['rows'][0]['subject'], '<b>Literal subject</b>')
        self.assertEqual(client.snapshot['gmail']['rows'][0]['group'], 'Example group')
        count = client.api.call_count
        client.previews()
        self.assertEqual(client.api.call_count, count)

    def test_out_of_office_all_day_uses_exclusive_end_and_dst_zone(self):
        event = {'id': 'leave', 'eventType': 'outOfOffice', 'summary': 'Away',
                 'start': {'date': '2026-10-25'}, 'end': {'date': '2026-10-26'}}
        row = work.event_record(event, 'Europe/Berlin')
        self.assertTrue(row['allDay'])
        self.assertEqual(row['kind'], 'outOfOffice')
        self.assertEqual(row['end'] - row['start'], 25 * 60 * 60 * 1000)

    def test_declined_cancelled_and_working_location_are_not_meetings(self):
        base = {'id': 'event', 'start': {'dateTime': '2026-10-20T10:00:00+02:00'},
                'end': {'dateTime': '2026-10-20T11:00:00+02:00'}}
        for extra in ({'status': 'cancelled'}, {'eventType': 'workingLocation'},
                      {'attendees': [{'self': True, 'responseStatus': 'declined'}]}):
            self.assertIsNone(work.event_record(dict(base, **extra), 'Europe/Berlin'))
        self.assertIsNotNone(work.event_record(base, 'Europe/Berlin'))

    def test_calendar_reads_all_pages_instead_of_first_twenty(self):
        client = self.client()
        def event(n):
            return {'id': str(n), 'start': {'dateTime': '2026-10-20T10:00:00+02:00'},
                    'end': {'dateTime': '2026-10-20T11:00:00+02:00'}}
        replies = [{'items': [event(n) for n in range(25)], 'nextPageToken': 'more'},
                   {'items': [event(n) for n in range(25, 30)]}]
        client.api = Mock(side_effect=replies)
        client.sync_calendar()
        self.assertEqual(len(client.events), 30)
        self.assertEqual(client.api.call_args.args[1]['pageToken'], 'more')

    def test_calendar_links_pin_work_account_and_reject_other_hosts(self):
        self.assertEqual(work.calendar_link('https://example.invalid/event', 'work@example.invalid'), '')
        url = work.calendar_link('https://calendar.google.com/calendar/event?eid=fixture&authuser=0', 'work@example.invalid')
        self.assertIn('authuser=work%40example.invalid', url)
        self.assertNotIn('authuser=0', url)

    def test_opening_browser_keeps_its_output_out_of_the_snapshot_transport(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apps = root / 'data/applications'
            apps.mkdir(parents=True)
            config = root / 'config'
            config.mkdir()
            browser, opened = root / 'browser.py', root / 'opened'
            browser.write_text('import sys\nfrom pathlib import Path\n'
                'print("Browser opened existing session",flush=True)\n'
                'print("Browser diagnostic",file=sys.stderr,flush=True)\n'
                'Path(' + repr(str(opened)) + ').touch()\n')
            (apps / 'fixture.desktop').write_text('[Desktop Entry]\nType=Application\nName=Fixture browser\n'
                'Exec=' + sys.executable + ' ' + str(browser) + ' %u\nMimeType=x-scheme-handler/https;\n')
            (config / 'mimeapps.list').write_text('[Default Applications]\nx-scheme-handler/https=fixture.desktop\n')
            env = dict(os.environ, XDG_DATA_HOME=str(root / 'data'), XDG_CONFIG_HOME=str(config),
                XDG_DATA_DIRS=str(root / 'empty'), XDG_CONFIG_DIRS=str(root / 'empty'))
            program = '''import importlib.util,json,sys,time
from pathlib import Path
from types import SimpleNamespace
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio,GLib
spec=importlib.util.spec_from_file_location("work",sys.argv[1])
work=importlib.util.module_from_spec(spec)
spec.loader.exec_module(work)
daemon=work.Daemon.__new__(work.Daemon)
daemon.Gio,daemon.GLib=Gio,GLib
daemon.client=SimpleNamespace(account="work@example.invalid",metadata={"message":{"thread":"fixture"}},
    snapshot={"gmail":{"status":"ok"}},events=[])
daemon.publish=lambda: print(json.dumps(daemon.client.snapshot),flush=True)
daemon.open_browser("gmail","message")
for _ in range(100):
    if Path(sys.argv[2]).exists(): break
    time.sleep(.01)
assert Path(sys.argv[2]).exists(),"Browser was not launched"
print(json.dumps(dict(type="snapshot",**daemon.client.snapshot)),flush=True)
'''
            result = subprocess.run([sys.executable, '-c', program, work.__file__, str(opened)],
                env=env, capture_output=True, text=True, timeout=5, check=True)
            self.assertEqual([json.loads(line) for line in result.stdout.splitlines()],
                [{'type':'snapshot','gmail':{'status':'ok'}}])
            self.assertEqual(result.stderr, '')

    def test_private_state_atomic_replace_remains_private(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'state' / 'token.json'
            work.private_json(path, {'fixture': 1})
            work.private_json(path, {'fixture': 2})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(path.parent.stat().st_mode & 0o777, 0o700)
            self.assertEqual(json.loads(path.read_text()), {'fixture': 2})
            self.assertEqual(len(list(path.parent.iterdir())), 1)


if __name__ == '__main__': unittest.main()
