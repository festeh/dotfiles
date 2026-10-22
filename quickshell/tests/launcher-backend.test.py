import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location('launcher', Path(__file__).resolve().parents[1] / 'launcher_backend.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class ProviderTests(unittest.TestCase):
    def test_launcher_retries_zero_exit_not_ready_response(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            executable=root/'quickshell'
            counter=root/'counter'
            executable.write_text('#!/usr/bin/python3\nimport sys\nfrom pathlib import Path\np=Path('+repr(str(counter))+')\nif "ipc" in sys.argv:\n n=int(p.read_text())+1 if p.exists() else 1\n p.write_text(str(n))\n if n<3: print("Not ready to accept queries yet.")\n')
            executable.chmod(0o755)
            env=dict(os.environ,PATH=str(root)+os.pathsep+os.environ['PATH'])
            result=subprocess.run([str(Path(launcher.__file__).with_name('launcher')),'apps'],env=env,capture_output=True,timeout=5)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(counter.read_text(),'3')
            background=subprocess.run([str(Path(launcher.__file__).with_name('launcher')),'--start'],env=env,capture_output=True,timeout=5)
            self.assertEqual(background.returncode,0,background.stderr)
            self.assertEqual(counter.read_text(),'3','Background startup sent a popup-open request')

    def test_books_metadata_and_cover_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            shelf = root / '_Priority'
            shelf.mkdir()
            book = shelf / 'Example Author - Example Book.FB2.ZIP'
            book.write_bytes(b'fixture')
            record = launcher.book_record(book, root, root/'covers')
            self.assertEqual(record['row']['title'], 'Example Book')
            self.assertIn('Example Author', record['row']['detail'])
            self.assertEqual(record['order'][0], 0)
            self.assertNotIn(temporary, json.dumps(record['row']))
            before = record['cover']
            book.write_bytes(b'changed fixture')
            self.assertNotEqual(before, launcher.book_record(book, root, root/'covers')['cover'])

    def test_fb2_uses_embedded_cover_for_plain_and_zipped_books(self):
        import base64
        import pymupdf
        import zipfile
        image = pymupdf.Pixmap(pymupdf.csRGB, pymupdf.IRect(0, 0, 40, 60), False)
        image.set_rect(image.irect, (20, 40, 180))
        image.set_rect(pymupdf.IRect(0, 0, 40, 30), (180, 40, 20))
        encoded = base64.b64encode(image.tobytes('png')).decode()
        book_data = ('<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" '
            'xmlns:l="http://www.w3.org/1999/xlink"><description><title-info>'
            '<book-title>Fixture</book-title><coverpage><image l:href="#cover"/>'
            '</coverpage></title-info></description><body><section><p>Body text</p>'
            '</section></body><binary id="cover" content-type="image/png">'
            + encoded + '</binary></FictionBook>').encode()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for extension in ('.fb2', '.fb2.zip'):
                with self.subTest(extension=extension):
                    book, target = root/('book'+extension), root/'cover.png'
                    if extension.endswith('.zip'):
                        with zipfile.ZipFile(book, 'w') as archive:
                            archive.writestr('book.fb2', book_data)
                    else:
                        book.write_bytes(book_data)
                    launcher.render_cover(book, target)
                    preview = pymupdf.Pixmap(str(target))
                    self.assertEqual((preview.width, preview.height), (120, 180))
                    self.assertEqual(preview.pixel(60, 30), (180, 40, 20))
                    self.assertEqual(preview.pixel(60, 150), (20, 40, 180))

    def test_blank_page_is_not_cached_as_a_cover(self):
        import pymupdf
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, target = root/'blank.pdf', root/'cover.png'
            with pymupdf.open() as document:
                document.new_page()
                document.save(source)
            with self.assertRaisesRegex(ValueError, 'Blank cover'):
                launcher.render_cover(source, target)
            self.assertFalse(target.exists())
            self.assertEqual(launcher.book_record(source, root, root)['row']['cover'], '')

    def test_clipboard_ids_and_binary_copy(self):
        rows = launcher.clipboard_rows('42\tSome text\n43\t[[ binary data 40 KiB png ]]\nbad\tno\n')
        self.assertEqual([row['id'] for row in rows], ['clip:42', 'clip:43'])
        self.assertEqual([row['clipboardKind'] for row in rows], ['text', 'image'])
        self.assertTrue(all(row['detail'] == '' for row in rows))
        raw = b'\x89PNG\x00\xff\x80\n'
        with patch.object(launcher, 'run', return_value=subprocess.CompletedProcess([], 0, raw, b'')) as decode, \
             patch.object(launcher.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as copy:
            launcher.copy_clipboard('43')
            self.assertEqual(decode.call_args.args[0], ['cliphist', 'decode', '43'])
            self.assertEqual(copy.call_args.kwargs['input'], raw)
            self.assertEqual(copy.call_args.args[0], ['wl-copy'])
            with self.assertRaises(ValueError): launcher.copy_clipboard('43;shutdown')

    def test_copy_finishes_while_forked_clipboard_owner_keeps_stderr_open(self):
        # wl-copy's parent exits after acquiring the selection, while its child
        # retains stderr for the lifetime of the clipboard. Waiting for pipe EOF
        # reports a timeout even though the copy already succeeded.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            command = root / 'wl-copy'
            owner, copied = root / 'owner', root / 'copied'
            command.write_text('#!/usr/bin/python3\nimport os,signal,sys\nfrom pathlib import Path\n'
                'data=sys.stdin.buffer.read()\n'
                'if os.fork(): os._exit(0)\n'
                'Path(' + repr(str(copied)) + ').write_bytes(data)\n'
                'Path(' + repr(str(owner)) + ').write_text(str(os.getpid()))\n'
                'signal.pause()\n')
            command.chmod(0o755)
            raw = b'\x89PNG\x00\xff\x80\n'
            try:
                with patch.dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH']), \
                        patch.object(launcher, 'run', return_value=subprocess.CompletedProcess([], 0, raw, b'')):
                    launcher.copy_clipboard('43')
                import time
                for _ in range(100):
                    if owner.exists(): break
                    time.sleep(.01)
                pid = int(owner.read_text())
                os.kill(pid, 0)
                self.assertEqual(copied.read_bytes(), raw)
            finally:
                if owner.exists():
                    try: os.kill(int(owner.read_text()), signal.SIGTERM)
                    except ProcessLookupError: pass

    def test_shortcuts_group_and_ignore_mouse(self):
        binds = [dict(has_description=True, mouse=False, description='Close "window"', modmask=64, key='C'),
                 dict(has_description=True, mouse=False, description='Close "window"', modmask=65, key='Q'),
                 dict(has_description=True, mouse=True, description='Mouse', modmask=64, key='272')]
        rows = launcher.shortcut_rows(binds)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['detail'], 'Super + C, Super + Shift + Q')

    def backend(self, category, rows):
        backend = launcher.Backend.__new__(launcher.Backend)
        backend.rows = {category: rows}
        backend.emit = Mock()
        backend.remember = Mock()
        backend.publish = Mock()
        backend.load_widgets = Mock()
        backend.widget_busy = False
        backend.messages = {}
        backend.usage = {}
        def background(work, done, error=None):
            try: result = work()
            except Exception as exception:
                if error: error(str(exception))
                else: raise
            else: done(result)
        backend.background = background
        return backend

    def test_stale_or_disabled_ids_never_dispatch(self):
        backend = self.backend('power', [{'id':'power:shutdown', 'enabled':False}])
        with patch.object(launcher.subprocess, 'Popen') as spawn:
            backend.activate({'category':'power', 'id':'power:shutdown'})
            backend.activate({'category':'power', 'id':'power:unknown'})
            spawn.assert_not_called()

    def test_desktop_activation_uses_full_gio_app_info(self):
        backend = self.backend('apps', [{'id':'app:example.desktop'}])
        app = Mock()
        app.launch.return_value = True
        backend.apps = {'app:example.desktop':app}
        with patch.object(launcher.subprocess, 'Popen') as spawn:
            backend.activate({'category':'apps', 'id':'app:example.desktop'})
            app.launch.assert_called_once_with([], None)
            spawn.assert_not_called()
            backend.remember.assert_called_once_with('app:example.desktop')

    def test_real_desktop_launch_preserves_field_codes_and_working_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            working=root/'working'
            working.mkdir()
            output=root/'output.json'
            script=root/'record.py'
            script.write_text('import json,os,sys\nfrom pathlib import Path\nPath('+repr(str(output))+').write_text(json.dumps([os.getcwd(),sys.argv[1:]]))\n')
            desktop=root/'fixture.desktop'
            desktop.write_text('[Desktop Entry]\nType=Application\nName=Fixture App\nExec=/usr/bin/python3 '+str(script)+' %c %k %%\nPath='+str(working)+'\n')
            app=launcher.GioUnix.DesktopAppInfo.new_from_filename(str(desktop))
            self.assertIsNotNone(app)
            backend=self.backend('apps',[{'id':'app:fixture.desktop'}])
            backend.apps={'app:fixture.desktop':app}
            backend.activate({'category':'apps','id':'app:fixture.desktop'})
            import time
            for _ in range(100):
                if output.exists(): break
                time.sleep(.01)
            self.assertEqual(json.loads(output.read_text()),[str(working),['Fixture App',str(desktop),'%']])

    def test_paste_is_addressed_and_aborts_after_focus_changes(self):
        backend = self.backend('clipboard', [{'id':'clip:42'}])
        with patch.object(launcher, 'copy_clipboard') as copy, \
             patch.object(launcher, 'focused_window', return_value={'address':'0xabcd','class':'example'}), \
             patch.object(launcher, 'run', return_value=subprocess.CompletedProcess([],0)) as dispatch:
            backend.activate({'category':'clipboard','id':'clip:42','paste':True,'target':'0xabcd'})
            copy.assert_called_once_with('42')
            self.assertIn('window="address:0xabcd"', dispatch.call_args.args[0][2])
        with patch.object(launcher, 'copy_clipboard'), \
             patch.object(launcher, 'focused_window', return_value=None), patch.object(launcher, 'run') as dispatch:
            backend.activate({'category':'clipboard','id':'clip:42','paste':True,'target':'0xabcd'})
            dispatch.assert_not_called()
            self.assertIn('Previous window', backend.emit.call_args.args[0]['message'])

    def test_text_paste_uses_kitty_binding_and_images_keep_application_binding(self):
        for window, kind, modifiers in (
                ({'class':'kitty'}, 'text', 'CTRL SHIFT'),
                ({'class':'custom','initialClass':'kitty'}, 'text', 'CTRL SHIFT'),
                ({'class':'net.kovidgoyal.kitty'}, 'text', 'CTRL SHIFT'),
                ({'class':'kitty'}, 'image', 'CTRL'),
                ({'class':'org.example.Editor'}, 'text', 'CTRL')):
            with self.subTest(window=window, kind=kind):
                backend = self.backend('clipboard', [{'id':'clip:42','clipboardKind':kind}])
                with patch.object(launcher, 'copy_clipboard'), \
                        patch.object(launcher, 'focused_window', return_value=window), \
                        patch.object(launcher, 'run', return_value=subprocess.CompletedProcess([],0)) as dispatch:
                    backend.activate({'category':'clipboard','id':'clip:42','paste':True,'target':'0xabcd'})
                    code = dispatch.call_args.args[0][2]
                    self.assertIn('mods="' + modifiers + '"', code)
                    self.assertIn('window="address:0xabcd"', code)
                    self.assertEqual(backend.emit.call_args.args[0]['type'], 'activated')

    def test_focused_window_waits_for_exact_target_and_returns_its_metadata(self):
        target = {'address':'0xabcd','class':'kitty','pid':123}
        responses = [subprocess.CompletedProcess([],0,json.dumps({'address':'0x1234'}).encode()),
            subprocess.CompletedProcess([],0,json.dumps(target).encode())]
        with patch.object(launcher, 'run', side_effect=responses) as query, \
                patch.object(launcher.time, 'sleep'):
            self.assertEqual(launcher.focused_window('0xabcd'), target)
            self.assertEqual(query.call_count, 2)
            self.assertIsNone(launcher.focused_window('invalid-address'))
            self.assertEqual(query.call_count, 2)

    def test_idle_lease_is_read_back_before_success(self):
        backend = self.backend('widgets', [{'id':'idle:auto','selected':True}, {'id':'idle:awake','selected':False}])
        backend.login_call = Mock(return_value=([('idle',launcher.INHIBITOR,'Keep awake','block',os.getuid(),123)],))
        with patch.object(launcher, 'run', return_value=subprocess.CompletedProcess([],0)) as execute:
            backend.activate({'category':'widgets','id':'idle:awake'})
            execute.assert_called_once_with(['systemctl','--user','start',launcher.KEEP_AWAKE])
            self.assertFalse(backend.widget_busy)
            self.assertEqual(backend.emit.call_args.args[0]['type'], 'activated')
            backend.rows['widgets'][1]['selected'] = True
            backend.activate({'category':'widgets','id':'idle:awake'})
            self.assertEqual(execute.call_args.args[0], ['systemctl','--user','start',launcher.KEEP_AWAKE])
            backend.login_call.return_value = ([('idle','Another app','Playback','block',os.getuid(),456)],)
            backend.activate({'category':'widgets','id':'idle:auto'})
            self.assertEqual(execute.call_args.args[0], ['systemctl','--user','stop',launcher.KEEP_AWAKE])
            self.assertFalse(backend.widget_busy)
            self.assertEqual(backend.emit.call_args.args[0]['type'], 'activated')

    def test_failed_profile_write_does_not_report_success(self):
        backend = self.backend('widgets', [{'id':'profile:quiet'}])
        with tempfile.TemporaryDirectory() as directory:
            profile = Path(directory)/'profile'
            profile.write_text('balanced')
            with patch.object(launcher,'PROFILE_PATH', profile), \
                 patch.object(launcher,'run',return_value=subprocess.CompletedProcess([],126)):
                backend.activate({'category':'widgets','id':'profile:quiet'})
            self.assertFalse(backend.widget_busy)
            self.assertIn('Authorization', backend.messages['widgets'])
            self.assertEqual(profile.read_text(), 'balanced')

    def test_incremental_book_change_scans_only_changed_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for shelf in ('A','B'): (root/shelf).mkdir()
            (root/'A/First.pdf').write_bytes(b'fixture')
            (root/'B/Second.epub').write_bytes(b'fixture')
            backend = self.backend('books', [])
            backend.library, backend.covers = root, root/'covers'
            backend.books, backend.book_dirs, backend.book_pending = {},set(),set()
            backend.book_busy, backend.book_loaded, backend.book_timer = False,False,0
            backend.loading = set()
            backend.watch_books = Mock()
            backend.refresh_books()
            self.assertEqual(len(backend.books),2)
            (root/'A/First.pdf').unlink()
            (root/'A/Third.pdf').write_bytes(b'fixture')
            backend.book_pending = {root/'A'}
            with patch.object(launcher.os,'walk',side_effect=AssertionError('Unexpected full rescan')):
                backend.refresh_books()
            self.assertEqual(sorted(item['row']['title'] for item in backend.books.values()), ['Second','Third'])


if __name__ == '__main__': unittest.main()
