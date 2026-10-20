#!/usr/bin/env python3
"""Work Gmail/Calendar provider. Credentials, mail and agenda stay outside Git.

One serialized worker owns authorization, sync and mutations. QML receives only
display data; commands refer to IDs already in the account's current snapshot.
"""
from __future__ import annotations

from collections import deque
from datetime import datetime, time as day_time, timedelta, timezone
from email.utils import parseaddr
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import threading
import time
from urllib.parse import parse_qsl, quote, urlencode, urlsplit, urlunsplit
from zoneinfo import ZoneInfo

GMAIL_SCOPE = "https://www.googleapis.com/auth/gmail.modify"
CALENDAR_SCOPE = "https://www.googleapis.com/auth/calendar.events.readonly"
SCOPES = [GMAIL_SCOPE, CALENDAR_SCOPE]
GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me/"
CALENDAR_API = "https://www.googleapis.com/calendar/v3/calendars/primary/events"


def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return default


def private_json(path, data):
    path = Path(path)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".google-work-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            json.dump(data, output, ensure_ascii=True, separators=(",", ":"))
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def compact(value, limit=240):
    return " ".join(str(value or "").split())[:limit]


def sender_name(value):
    name, address = parseaddr(value)
    return compact(name or address or "Unknown sender", 100)


def sender_group(value):
    address = parseaddr(value)[1]
    domain = address.rpartition("@")[2].casefold().strip(".")
    parts = domain.split(".")
    index = -3 if len(parts) > 2 and len(parts[-1]) == 2 and parts[-2] in {"co", "com", "org", "ac", "gov", "net"} else -2
    return "@" + (parts[index] if len(parts) >= abs(index) else domain or "unknown")


def event_record(event, calendar_zone):
    if event.get("status") == "cancelled" or any(
            person.get("self") and person.get("responseStatus") == "declined"
            for person in event.get("attendees", [])):
        return None
    kind = event.get("eventType", "default")
    if kind not in ("default", "outOfOffice"):
        return None
    if kind != "outOfOffice" and event.get("transparency") == "transparent":
        return None
    def timestamp(value):
        if value.get("dateTime"):
            return datetime.fromisoformat(value["dateTime"].replace("Z", "+00:00"))
        return datetime.combine(datetime.fromisoformat(value["date"]).date(), day_time(),
                                ZoneInfo(value.get("timeZone") or calendar_zone))
    try:
        start, end = timestamp(event["start"]), timestamp(event["end"])
    except (KeyError, ValueError, TypeError):
        return None
    if start.tzinfo is None or end.tzinfo is None or end <= start:
        return None
    return {"id": event["id"], "title": compact(event.get("summary") or "Untitled meeting", 200),
            "start": int(start.timestamp() * 1000), "end": int(end.timestamp() * 1000),
            "allDay": "date" in event["start"], "kind": kind, "url": event.get("htmlLink", "")}


def calendar_link(url, account):
    parts = urlsplit(url)
    if parts.scheme != "https" or not (
            parts.hostname == "calendar.google.com" or
            parts.hostname == "www.google.com" and parts.path.startswith("/calendar/")):
        return ""
    query = [(key, value) for key, value in parse_qsl(parts.query) if key != "authuser"]
    return urlunsplit((parts.scheme, parts.netloc, parts.path,
                      urlencode(query + [("authuser", account)]), parts.fragment))


class GoogleError(Exception):
    def __init__(self, status, message="Could not update. Retry when connected."):
        self.status = status
        super().__init__(message)


class Client:
    def __init__(self, config_dir, state_dir, cache_dir):
        import requests
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        self.config_dir, self.state_dir, self.cache_dir = map(Path, (config_dir, state_dir, cache_dir))
        self.config = read_json(self.config_dir / "config.json", {})
        self.token_path = self.state_dir / "token.json"
        self.token = read_json(self.token_path, {})
        self.credentials = Credentials.from_authorized_user_info(self.token) if self.token.get("refresh_token") else None
        self.session = requests.Session()
        request = Request(session=self.session)
        self.auth_request = lambda *args, **kwargs: request(*args, **dict({"timeout": 15}, **kwargs))
        self.identity_checked = False
        cache = read_json(self.cache_dir / "snapshot.json", {})
        if cache.get("account") != self.config.get("account"):
            cache = {}
        self.ids = list(dict.fromkeys(cache.get("ids", [])))
        self.history = cache.get("history", "")
        self.metadata = cache.get("metadata", {})
        self.events = cache.get("events", [])
        self.categories, self.category_dirty = {}, True
        self.limit, self.mail_visible = 30, False
        self.snapshot = {"type": "snapshot", "authorizing": False,
            "gmail": {"status": "stale" if cache.get("gmailUpdated") else "loading",
                      "unread": len(self.ids) if cache.get("gmailUpdated") else None,
                      "rows": [], "updatedAt": cache.get("gmailUpdated", 0),
                      "message": "", "canMarkRead": self.can_mark_read, "busyIds": [], "hasMore": False},
            "calendar": {"status": "stale" if cache.get("calendarUpdated") else "loading",
                         "rows": self.events, "updatedAt": cache.get("calendarUpdated", 0), "message": ""}}
        self.update_rows()

    @property
    def can_mark_read(self):
        scopes = self.token.get("scopes", [])
        if isinstance(scopes, str): scopes = scopes.split()
        return GMAIL_SCOPE in scopes or "https://mail.google.com/" in scopes

    @property
    def account(self):
        return self.config.get("account", "")

    def save(self):
        private_json(self.cache_dir / "snapshot.json", {
            "account": self.account, "ids": self.ids, "history": self.history,
            "metadata": self.metadata, "events": self.events,
            "gmailUpdated": self.snapshot["gmail"]["updatedAt"],
            "calendarUpdated": self.snapshot["calendar"]["updatedAt"]})

    def ensure_token(self, force=False):
        from google.auth.exceptions import RefreshError
        if not self.credentials:
            raise GoogleError(401, "Connect your work Google account.")
        if force or not self.credentials.valid:
            try:
                self.credentials.refresh(self.auth_request)
            except RefreshError:
                raise GoogleError(401, "Google sign-in expired. Reconnect your work account.") from None
            self.token = json.loads(self.credentials.to_json())
            private_json(self.token_path, self.token)

    def api(self, url, params=None, body=None):
        import requests
        for attempt in range(2):
            self.ensure_token(force=attempt > 0)
            try:
                response = self.session.request("POST" if body is not None else "GET", url,
                    params=params, json=body, headers={"Authorization": "Bearer " + self.credentials.token}, timeout=15)
            except requests.RequestException:
                raise GoogleError(0) from None
            if response.status_code == 401 and not attempt:
                continue
            if response.status_code >= 400:
                text = "Google sign-in expired. Reconnect your work account." if response.status_code == 401 else (
                    "Google denied access. Check your account permissions." if response.status_code == 403 else
                    "Google is temporarily unavailable. Retry shortly.")
                raise GoogleError(response.status_code, text)
            # Field-filtered list requests with no matching messages can have
            # an empty 204 response instead of an empty JSON object.
            return response.json() if response.content else {}
        raise GoogleError(401, "Reconnect your work account.")

    def ensure_identity(self):
        if self.identity_checked:
            return None
        profile = self.api(GMAIL_API + "profile", {"fields": "emailAddress,historyId"})
        account = profile.get("emailAddress", "")
        if not account or self.account and account.casefold() != self.account.casefold():
            raise GoogleError(401, "This sign-in is not the configured work account.")
        if not self.account:
            self.config["account"] = account
            private_json(self.config_dir / "config.json", self.config)
        self.identity_checked = True
        return profile

    def list_ids(self, query=None):
        result, page = [], None
        while True:
            params = {"labelIds": ["INBOX", "UNREAD"], "maxResults": 500,
                      "fields": "messages/id,nextPageToken"}
            if query: params["q"] = query
            if page: params["pageToken"] = page
            data = self.api(GMAIL_API + "messages", params)
            result.extend(item["id"] for item in data.get("messages", []))
            page = data.get("nextPageToken")
            if not page:
                return list(dict.fromkeys(result))

    def sync_gmail(self):
        profile = self.ensure_identity()
        changed = set()
        if self.history:
            page, cursor = None, self.history
            try:
                while True:
                    params = {"startHistoryId": self.history, "maxResults": 500,
                              "fields": "history(messages/id),historyId,nextPageToken"}
                    if page: params["pageToken"] = page
                    data = self.api(GMAIL_API + "history", params)
                    for entry in data.get("history", []):
                        changed.update(item["id"] for item in entry.get("messages", []))
                    cursor = data.get("historyId", cursor)
                    page = data.get("nextPageToken")
                    if not page: break
                ids = list(self.ids)
                for identity in sorted(changed):
                    try:
                        item = self.api(GMAIL_API + "messages/" + quote(identity, safe=""),
                                        {"format": "minimal", "fields": "id,labelIds"})
                        unread = {"INBOX", "UNREAD"}.issubset(item.get("labelIds", []))
                    except GoogleError as error:
                        if error.status != 404: raise
                        unread = False
                    if unread and identity not in ids: ids.insert(0, identity)
                    if not unread and identity in ids: ids.remove(identity)
                self.ids, self.history = ids, cursor
            except GoogleError as error:
                if error.status != 404: raise
                self.history = ""
        if not self.history:
            # Take the cursor before listing, so arrivals during the initial scan
            # are picked up by the following incremental check.
            profile = profile or self.api(GMAIL_API + "profile", {"fields": "historyId"})
            self.ids = self.list_ids()
            self.history = profile["historyId"]
            changed.update(self.ids)
        self.metadata = {identity: row for identity, row in self.metadata.items() if identity in self.ids}
        if changed: self.category_dirty = True
        self.snapshot["gmail"].update(status="ok", unread=len(self.ids), message="",
            updatedAt=int(time.time() * 1000), canMarkRead=self.can_mark_read)
        self.update_rows()
        self.save()

    def update_rows(self):
        rows = [dict(self.metadata[identity], group=self.categories.get(identity) or
                     sender_group(self.metadata[identity].get("from", "")))
                for identity in self.ids[:self.limit] if identity in self.metadata]
        rows.sort(key=lambda row: (-row["date"], row["id"]))
        self.snapshot["gmail"].update(rows=rows, hasMore=len(self.ids) > self.limit)

    def previews(self):
        self.ensure_identity()
        if self.category_dirty:
            categories, remaining = {}, set(self.ids)
            for bucket in self.config.get("buckets", []):
                if not remaining: break
                if not bucket.get("name") or not bucket.get("query"): continue
                matched = set(self.list_ids(bucket["query"])) & remaining
                categories.update((identity, compact(bucket["name"], 32)) for identity in matched)
                remaining -= matched
            self.categories, self.category_dirty = categories, False
        removed = set()
        for identity in self.ids[:self.limit]:
            if identity in self.metadata: continue
            try:
                item = self.api(GMAIL_API + "messages/" + quote(identity, safe=""),
                    {"format": "full", "fields": "id,threadId,labelIds,snippet,internalDate,payload/headers"})
            except GoogleError as error:
                if error.status != 404: raise
                removed.add(identity)
                continue
            if not {"INBOX", "UNREAD"}.issubset(item.get("labelIds", [])):
                removed.add(identity)
                continue
            headers = {header["name"].lower(): header.get("value", "")
                       for header in item.get("payload", {}).get("headers", [])}
            self.metadata[identity] = {"id": identity, "thread": item.get("threadId", identity),
                "from": compact(headers.get("from"), 200), "sender": sender_name(headers.get("from", "")),
                "subject": compact(headers.get("subject") or "(No subject)", 200),
                "preview": compact(item.get("snippet")), "date": int(item.get("internalDate", 0))}
        self.ids = [identity for identity in self.ids if identity not in removed]
        self.snapshot["gmail"]["unread"] = len(self.ids)
        self.update_rows()
        self.save()

    def mark_read(self, identity):
        if not self.can_mark_read:
            raise GoogleError(403, "Enable Mark as read by reconnecting Google.")
        if identity not in self.ids or not re.fullmatch(r"[a-zA-Z0-9_-]+", identity):
            return
        self.api(GMAIL_API + "messages/" + identity + "/modify", body={"removeLabelIds": ["UNREAD"]})
        self.ids.remove(identity)
        self.metadata.pop(identity, None)
        self.categories.pop(identity, None)
        self.snapshot["gmail"]["unread"] = len(self.ids)
        self.update_rows()
        self.save()

    def sync_calendar(self):
        self.ensure_identity()
        now = datetime.now().astimezone()
        start = datetime.combine(now.date(), day_time(), now.tzinfo)
        params = {"timeMin": start.isoformat(), "timeMax": (start + timedelta(days=8)).isoformat(),
                  "singleEvents": "true", "maxResults": 250,
                  "fields": "items(id,summary,start,end,eventType,status,transparency,attendees(self,responseStatus),htmlLink),nextPageToken,timeZone"}
        rows = []
        while True:
            data = self.api(CALENDAR_API, params)
            zone = data.get("timeZone", "UTC")
            for event in data.get("items", []):
                record = event_record(event, zone)
                if record: rows.append(record)
            if not data.get("nextPageToken"): break
            params["pageToken"] = data["nextPageToken"]
        self.events = sorted(rows, key=lambda row: (row["start"], row["end"], row["id"]))
        self.snapshot["calendar"].update(status="ok", rows=self.events, message="",
                                        updatedAt=int(time.time() * 1000))
        self.save()

    def authorize(self):
        from google_auth_oauthlib.flow import InstalledAppFlow
        from google.auth.transport.requests import Request
        import requests
        secrets = read_json(self.config_dir / "credentials.json", {})
        if not secrets.get("installed"):
            raise GoogleError(401, "Install desktop OAuth credentials first. See the README.")
        flow = InstalledAppFlow.from_client_config(secrets, SCOPES, autogenerate_code_verifier=True)
        credentials = flow.run_local_server(host="127.0.0.1", port=0, timeout_seconds=180,
            authorization_prompt_message=None, success_message="Connected to Desktop Work Hub. You can close this tab.",
            access_type="offline", prompt="consent", login_hint=self.account or None)
        # Validate the mailbox before replacing the working token/cache.
        with requests.Session() as session:
            response = session.get(GMAIL_API + "profile", headers={"Authorization": "Bearer " + credentials.token}, timeout=15)
            profile = response.json() if response.ok else {}
        account = profile.get("emailAddress", "")
        if not account or self.account and account.casefold() != self.account.casefold():
            raise GoogleError(401, "Choose the configured work account when signing in.")
        granted = set(credentials.granted_scopes or credentials.scopes or [])
        if not set(SCOPES).issubset(granted):
            raise GoogleError(401, "Google did not grant all requested permissions. Reconnect to enable them.")
        self.credentials = credentials
        self.token = json.loads(credentials.to_json())
        self.token["scopes"] = sorted(granted)
        private_json(self.token_path, self.token)
        self.config["account"] = account
        private_json(self.config_dir / "config.json", self.config)
        self.identity_checked = True
        self.snapshot["gmail"]["canMarkRead"] = self.can_mark_read


class Daemon:
    def __init__(self, client):
        from gi.repository import Gio, GLib
        self.Gio, self.GLib, self.client = Gio, GLib, client
        self.condition = threading.Condition()
        self.jobs, self.pending = deque(), set()
        self.output_lock = threading.Lock()
        self.failures = {"gmail": 0, "calendar": 0}
        self.due = {"gmail": 0, "calendar": 0}
        self.refresh_timer = 0
        self.loop = GLib.MainLoop()
        self.network = Gio.NetworkMonitor.get_default()
        self.network.connect("network-changed", lambda *_: self.request_refresh())
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.bus.signal_subscribe("org.freedesktop.login1", "org.freedesktop.login1.Manager", "PrepareForSleep",
            "/org/freedesktop/login1", None, Gio.DBusSignalFlags.NONE, self.resume)
        GLib.timeout_add_seconds(60, self.tick)

    def publish(self):
        with self.output_lock:
            try:
                print(json.dumps(self.client.snapshot, ensure_ascii=True, separators=(",", ":")), flush=True)
            except BrokenPipeError:
                self.loop.quit()

    def enqueue(self, action, identity=""):
        key = (action, identity)
        with self.condition:
            if key in self.pending: return
            self.pending.add(key)
            self.jobs.append(key)
            self.condition.notify()

    def request_refresh(self):
        if self.refresh_timer: self.GLib.source_remove(self.refresh_timer)
        def refresh():
            self.refresh_timer = 0
            self.enqueue("refresh")
            return self.GLib.SOURCE_REMOVE
        self.refresh_timer = self.GLib.timeout_add(500, refresh)

    def resume(self, _bus, _sender, _path, _interface, _name, parameters):
        if not parameters.unpack()[0]: self.request_refresh()

    def tick(self):
        self.enqueue("sync")
        return self.GLib.SOURCE_CONTINUE

    def error(self, provider, error):
        state = self.client.snapshot[provider]
        auth = isinstance(error, GoogleError) and error.status in (401, 403)
        message = str(error) if isinstance(error, GoogleError) else "Could not update. Retry when connected."
        state.update(status="auth" if auth else "stale" if state.get("updatedAt") else "error", message=message)

    def sync(self, force=False):
        for provider, interval in (("gmail", 60), ("calendar", 180)):
            if not force and time.monotonic() < self.due[provider]: continue
            try:
                getattr(self.client, "sync_" + provider)()
                self.failures[provider] = 0
                self.due[provider] = time.monotonic() + interval
            except Exception as error:
                self.failures[provider] += 1
                self.due[provider] = time.monotonic() + min(900, interval * 2 ** min(self.failures[provider], 4))
                self.error(provider, error)
            self.publish()
        if self.client.mail_visible and self.client.snapshot["gmail"]["status"] == "ok":
            self.enqueue("previews")

    def work(self):
        while True:
            with self.condition:
                while not self.jobs: self.condition.wait()
                action, identity = self.jobs.popleft()
            try:
                if action in ("sync", "refresh"):
                    self.sync(force=action == "refresh")
                elif action == "previews":
                    if self.client.mail_visible:
                        self.client.snapshot["gmail"]["loading"] = True
                        self.publish()
                        self.client.previews()
                elif action == "read":
                    self.client.snapshot["gmail"]["busyIds"] = [identity]
                    self.publish()
                    self.client.mark_read(identity)
                    if self.client.mail_visible: self.enqueue("previews")
                elif action == "authorize":
                    self.client.snapshot["authorizing"] = True
                    self.publish()
                    self.client.authorize()
                    self.enqueue("refresh")
            except Exception as error:
                self.error("gmail", error)
            finally:
                self.client.snapshot["authorizing"] = False
                self.client.snapshot["gmail"].update(loading=False, busyIds=[])
                with self.condition:
                    self.pending.discard((action, identity))
                self.publish()

    def open_browser(self, kind, identity):
        account = self.client.account
        if not account: return
        if kind == "gmail":
            row = self.client.metadata.get(identity) if identity else None
            if identity and not row: return
            fragment = "all/" + quote(row["thread"], safe="") if row else "inbox"
            url = "https://mail.google.com/mail/?" + urlencode({"authuser": account}) + "#" + fragment
        else:
            row = next((row for row in self.client.events if row["id"] == identity), None) if identity else None
            if identity and not row: return
            url = calendar_link(row["url"], account) if row else "https://calendar.google.com/calendar/r?" + urlencode({"authuser": account})
        if url:
            try:
                self.Gio.AppInfo.launch_default_for_uri(url, None)
            except self.GLib.Error:
                self.client.snapshot[kind]["message"] = "Could not open the browser. Try again."
                self.publish()

    def command(self, value):
        action = value.get("action")
        if action == "show":
            self.client.mail_visible = value.get("kind") == "gmail"
            if self.client.mail_visible:
                self.client.limit = 30
                self.enqueue("previews")
            self.enqueue("sync")
        elif action == "hide":
            self.client.mail_visible = False
        elif action == "more" and self.client.mail_visible:
            self.client.limit += 30
            self.enqueue("previews")
        elif action == "read": self.enqueue("read", str(value.get("id", "")))
        elif action == "refresh": self.request_refresh()
        elif action == "authorize": self.enqueue("authorize")
        elif action == "open" and value.get("kind") in ("gmail", "calendar"):
            self.open_browser(value["kind"], str(value.get("id", "")))
        return self.GLib.SOURCE_REMOVE

    def run(self):
        def intake():
            for line in sys.stdin:
                try:
                    value = json.loads(line)
                    if isinstance(value, dict): self.GLib.idle_add(self.command, value)
                except ValueError:
                    pass
            self.GLib.idle_add(self.loop.quit)
        self.publish()
        threading.Thread(target=self.work, daemon=True).start()
        threading.Thread(target=intake, daemon=True).start()
        self.enqueue("refresh")
        self.loop.run()


def directories():
    home = Path.home()
    return (Path(os.environ.get("QS_GOOGLE_CONFIG", Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")) / "quickshell/google-work")),
            Path(os.environ.get("QS_GOOGLE_STATE", Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")) / "quickshell/google-work")),
            Path(os.environ.get("QS_GOOGLE_CACHE", Path(os.environ.get("XDG_CACHE_HOME", home / ".cache")) / "quickshell/google-work")))


def migrate_ags(config, state):
    old_config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "ags/gmail/credentials.json"
    old_token = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "ags-gmail/token.json"
    credentials, token = read_json(old_config, {}), read_json(old_token, {})
    if not credentials.get("installed"):
        raise RuntimeError("No existing desktop OAuth credentials to import.")
    if not (config / "credentials.json").exists():
        private_json(config / "credentials.json", {"installed": credentials["installed"]})
    if not (config / "config.json").exists():
        private_json(config / "config.json", {"account": "", "buckets": credentials.get("buckets", [])})
    if token.get("refresh_token") and not (state / "token.json").exists():
        private_json(state / "token.json", token)


if __name__ == "__main__":
    config, state, cache = directories()
    if "--migrate-ags" in sys.argv:
        migrate_ags(config, state)
        print("Imported existing authorization and private settings.")
    else:
        Daemon(Client(config, state, cache)).run()
