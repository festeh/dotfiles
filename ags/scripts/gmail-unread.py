#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "google-api-python-client>=2.179.0",
#   "google-auth-httplib2>=0.2.0",
#   "google-auth-oauthlib>=1.2.2",
# ]
# ///

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


SCOPES = [
    "https://www.googleapis.com/auth/gmail.labels",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/calendar.events.readonly",
]
CALENDAR_LOOKBACK_HOURS = 8
CALENDAR_LOOKAHEAD_HOURS = 12


def xdg_config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))


def xdg_cache_home() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))


def default_credentials_path() -> Path:
    return xdg_config_home() / "ags" / "gmail" / "credentials.json"


def default_token_path() -> Path:
    return xdg_cache_home() / "ags-gmail" / "token.json"


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, separators=(",", ":")))


def log(message: str) -> None:
    print(message, file=sys.stderr)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def is_desktop_oauth_credentials(path: Path) -> bool:
    try:
        payload = read_json(path)
    except (OSError, json.JSONDecodeError):
        return False

    installed = payload.get("installed") if isinstance(payload, dict) else None
    if not isinstance(installed, dict):
        return False

    return (
        isinstance(installed.get("client_id"), str)
        and isinstance(installed.get("client_secret"), str)
        and isinstance(installed.get("redirect_uris"), list)
    )


def normalize_scopes(value: Any) -> set[str]:
    if isinstance(value, str):
        return set(value.split())

    if isinstance(value, list):
        return {item for item in value if isinstance(item, str)}

    return set()


def token_has_expected_scopes(token_path: Path) -> bool:
    try:
        payload = read_json(token_path)
    except (OSError, json.JSONDecodeError):
        return False

    return set(SCOPES).issubset(normalize_scopes(payload.get("scopes")))


def find_credentials_candidates() -> list[Path]:
    candidates: list[Path] = []
    seen: set[Path] = set()

    for directory in (Path.cwd(), Path.home() / "Downloads"):
        if not directory.is_dir():
            continue

        for path in directory.glob("*.json"):
            try:
                resolved = path.resolve()
            except OSError:
                continue

            if resolved in seen or not path.is_file():
                continue

            seen.add(resolved)
            if is_desktop_oauth_credentials(path):
                candidates.append(path)

    return sorted(candidates, key=lambda path: path.stat().st_mtime, reverse=True)


def install_credentials(credentials_path: Path, source_path: Path) -> str:
    source_path = source_path.expanduser()
    if not source_path.exists():
        raise FileNotFoundError(f"Credentials source does not exist: {source_path}")

    if not is_desktop_oauth_credentials(source_path):
        raise ValueError(f"Not a Desktop app OAuth credentials JSON: {source_path}")

    credentials_path.parent.mkdir(parents=True, exist_ok=True)
    if source_path.resolve() != credentials_path.resolve():
        shutil.copyfile(source_path, credentials_path)

    credentials_path.chmod(0o600)
    return f"Installed Google OAuth credentials from {source_path}"


def ensure_credentials(credentials_path: Path, source_path: Path | None) -> str:
    if credentials_path.exists():
        if not is_desktop_oauth_credentials(credentials_path):
            raise ValueError(f"Invalid Desktop app OAuth credentials JSON: {credentials_path}")

        credentials_path.chmod(0o600)
        return f"Using Google OAuth credentials at {credentials_path}"

    if source_path is not None:
        return install_credentials(credentials_path, source_path)

    candidates = find_credentials_candidates()
    if candidates:
        return install_credentials(credentials_path, candidates[0])

    raise FileNotFoundError(
        "Missing Google OAuth credentials. Download a Desktop app OAuth JSON from "
        "Google Cloud and rerun with --setup, or pass --credentials-source PATH."
    )


def import_google_libs():
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError

    return Request, Credentials, InstalledAppFlow, build, HttpError


def calendar_setup(message: str) -> dict[str, Any]:
    return {
        "status": "setup",
        "label": "!",
        "title": "",
        "message": message,
    }


def calendar_error(message: str) -> dict[str, Any]:
    return {
        "status": "error",
        "label": "!",
        "title": "",
        "message": message,
    }


def setup_payload(message: str) -> dict[str, Any]:
    return {
        "status": "setup",
        "unread": 0,
        "message": message,
        "calendar": calendar_setup(message),
    }


def error_payload(message: str) -> dict[str, Any]:
    return {
        "status": "error",
        "unread": 0,
        "message": message,
        "calendar": calendar_error(message),
    }


def load_credentials(credentials_path: Path, token_path: Path, authorize: bool):
    if not credentials_path.exists():
        return None, setup_payload(f"Missing Google OAuth credentials at {credentials_path}")

    Request, Credentials, InstalledAppFlow, _build, _HttpError = import_google_libs()

    creds = None
    if token_path.exists():
        if not token_has_expected_scopes(token_path):
            if not authorize:
                return None, {
                    "status": "setup",
                    "unread": 0,
                    "message": "Run with --setup to recreate the Google token with the current scopes",
                    "calendar": calendar_setup("Run with --setup to recreate the Google token with the current scopes"),
                }

            token_path.unlink()
        else:
            creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)

    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())

    if not creds or not creds.valid:
        if not authorize:
            return None, {
                "status": "setup",
                "unread": 0,
                "message": "Run with --setup to create a Google token",
                "calendar": calendar_setup("Run with --setup to create a Google token"),
            }

        flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), SCOPES)
        creds = flow.run_local_server(port=0)

    token_path.parent.mkdir(parents=True, exist_ok=True)
    token_path.write_text(creds.to_json(), encoding="utf-8")
    token_path.chmod(0o600)
    return creds, None


def setup_google(credentials_path: Path, token_path: Path, source_path: Path | None) -> dict[str, Any]:
    try:
        log(ensure_credentials(credentials_path, source_path))
    except (FileNotFoundError, ValueError) as error:
        return setup_payload(str(error))

    if token_path.exists() and not token_has_expected_scopes(token_path):
        token_path.unlink()
        log(f"Removed old Google token missing a current OAuth scope: {token_path}")

    creds, setup_payload = load_credentials(credentials_path, token_path, authorize=True)
    if setup_payload is not None:
        return setup_payload

    return google_status(credentials_path, token_path, authorize=False)


def gmail_unread_count(creds: Any, build: Any) -> int:
    service = build("gmail", "v1", credentials=creds, cache_discovery=False)
    label = service.users().labels().get(userId="me", id="INBOX").execute()
    return int(label.get("messagesUnread", 0))


def parse_event_time(value: Any) -> datetime | None:
    if not isinstance(value, str):
        return None

    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)

    return parsed.astimezone(timezone.utc)


def local_time_label(value: datetime) -> str:
    return value.astimezone().strftime("%H:%M")


def event_title(event: dict[str, Any]) -> str:
    title = event.get("summary")
    return title if isinstance(title, str) and title else "(No title)"


def event_payload(status: str, event: dict[str, Any], start: datetime, end: datetime, label: str) -> dict[str, Any]:
    title = event_title(event)
    payload = {
        "status": status,
        "label": label,
        "title": title,
        "startsAt": start.isoformat(),
        "endsAt": end.isoformat(),
        "message": f"{title} at {label}" if status == "next" else f"{title} until {local_time_label(end)}",
    }

    html_link = event.get("htmlLink")
    if isinstance(html_link, str):
        payload["url"] = html_link

    return payload


def calendar_status(creds: Any, build: Any) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    time_min = now - timedelta(hours=CALENDAR_LOOKBACK_HOURS)
    time_max = now + timedelta(hours=CALENDAR_LOOKAHEAD_HOURS)

    service = build("calendar", "v3", credentials=creds, cache_discovery=False)
    events_result = service.events().list(
        calendarId="primary",
        timeMin=time_min.isoformat(),
        timeMax=time_max.isoformat(),
        singleEvents=True,
        orderBy="startTime",
        maxResults=20,
    ).execute()

    events: list[tuple[dict[str, Any], datetime, datetime]] = []
    for event in events_result.get("items", []):
        if not isinstance(event, dict):
            continue
        if event.get("status") == "cancelled" or event.get("transparency") == "transparent":
            continue

        start = parse_event_time(event.get("start", {}).get("dateTime"))
        end = parse_event_time(event.get("end", {}).get("dateTime"))
        if start is None or end is None or end <= now:
            continue

        events.append((event, start, end))

    current = sorted(
        ((event, start, end) for event, start, end in events if start <= now < end),
        key=lambda item: item[2],
    )
    if current:
        event, start, end = current[0]
        return event_payload("busy", event, start, end, "Now")

    upcoming = sorted(
        ((event, start, end) for event, start, end in events if start >= now),
        key=lambda item: item[1],
    )
    if upcoming:
        event, start, end = upcoming[0]
        return event_payload("next", event, start, end, local_time_label(start))

    return {
        "status": "free",
        "label": "Free",
        "title": "",
        "message": f"No meetings in the next {CALENDAR_LOOKAHEAD_HOURS} hours",
    }


def google_status(credentials_path: Path, token_path: Path, authorize: bool) -> dict[str, Any]:
    creds, setup_payload = load_credentials(credentials_path, token_path, authorize)
    if setup_payload is not None:
        return setup_payload

    _Request, _Credentials, _InstalledAppFlow, build, HttpError = import_google_libs()

    try:
        unread = gmail_unread_count(creds, build)
    except HttpError as error:
        return error_payload(str(error))

    try:
        calendar = calendar_status(creds, build)
    except HttpError as error:
        calendar = calendar_error(str(error))

    return {
        "status": "ok",
        "unread": unread,
        "message": "ok",
        "calendar": calendar,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Print Gmail and Calendar status as JSON.")
    parser.add_argument(
        "--authorize",
        action="store_true",
        help="run browser OAuth flow if a token is missing or invalid",
    )
    parser.add_argument(
        "--setup",
        action="store_true",
        help="install downloaded OAuth credentials if needed, then run browser OAuth",
    )
    parser.add_argument(
        "--credentials-source",
        type=Path,
        help="downloaded Desktop app OAuth credentials JSON to install during --setup",
    )
    parser.add_argument(
        "--credentials",
        type=Path,
        default=Path(os.environ.get("AGS_GMAIL_CREDENTIALS", default_credentials_path())),
        help="OAuth desktop credentials JSON path",
    )
    parser.add_argument(
        "--token",
        type=Path,
        default=Path(os.environ.get("AGS_GMAIL_TOKEN", default_token_path())),
        help="OAuth token cache path",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        credentials = args.credentials.expanduser()
        token = args.token.expanduser()
        source = args.credentials_source.expanduser() if args.credentials_source is not None else None

        if args.setup:
            emit(setup_google(credentials, token, source))
        else:
            emit(google_status(credentials, token, args.authorize))

        return 0
    except Exception as error:
        emit(error_payload(str(error)))
        return 1


if __name__ == "__main__":
    sys.exit(main())
