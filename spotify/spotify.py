#!/usr/bin/env python3
"""Spotify playlist management via Web API."""
import http.server
import urllib.parse
import webbrowser
import json
import sys
import os

import httpx

CLIENT_ID = os.environ["SPOTIFY_CLIENT_ID"]
CLIENT_SECRET = os.environ["SPOTIFY_CLIENT_SECRET"]
REDIRECT_URI = os.environ.get("SPOTIFY_REDIRECT_URI", "http://127.0.0.1:8889/callback")
SCOPES = "playlist-modify-public playlist-modify-private playlist-read-private user-read-private user-read-email"
TOKEN_FILE = os.path.join(os.path.dirname(__file__), ".token.json")

auth_code = None


class _CallbackHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global auth_code
        params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        auth_code = params.get("code", [None])[0]
        self.send_response(200 if auth_code else 400)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(b"<h1>Success! You can close this tab.</h1>" if auth_code else b"Authorization failed.")

    def log_message(self, *_):
        pass


def _token_request(data: dict) -> dict:
    resp = httpx.post("https://accounts.spotify.com/api/token", data=data, auth=(CLIENT_ID, CLIENT_SECRET))
    resp.raise_for_status()
    return resp.json()


def _save_token(data):
    with open(TOKEN_FILE, "w") as f:
        json.dump(data, f)


def _load_token():
    try:
        with open(TOKEN_FILE) as f:
            return json.load(f)
    except FileNotFoundError:
        return None


def authenticate() -> httpx.Client:
    """Authenticate and return an httpx.Client with auth headers set."""
    global auth_code
    saved = _load_token()

    if saved and "refresh_token" in saved:
        print("Refreshing saved token...")
        try:
            token_data = _token_request({"grant_type": "refresh_token", "refresh_token": saved["refresh_token"]})
            token_data.setdefault("refresh_token", saved["refresh_token"])
            _save_token(token_data)
            print(f"Authorized (cached). Scopes: {token_data.get('scope', 'none')}")
            return _client(token_data["access_token"])
        except httpx.HTTPStatusError:
            print("Refresh failed, re-authenticating...")

    auth_url = (
        f"https://accounts.spotify.com/authorize?"
        f"client_id={CLIENT_ID}&response_type=code&redirect_uri={urllib.parse.quote(REDIRECT_URI)}"
        f"&scope={urllib.parse.quote(SCOPES)}&show_dialog=true"
    )
    print("Opening browser for Spotify authorization...")
    webbrowser.open(auth_url)

    port = int(REDIRECT_URI.split(":")[2].split("/")[0])
    http.server.HTTPServer(("127.0.0.1", port), _CallbackHandler).handle_request()

    if not auth_code:
        print("Failed to get authorization code.")
        sys.exit(1)

    token_data = _token_request({"grant_type": "authorization_code", "code": auth_code, "redirect_uri": REDIRECT_URI})
    _save_token(token_data)
    print(f"Authorized. Scopes: {token_data.get('scope', 'none')}")
    return _client(token_data["access_token"])


def _client(token: str) -> httpx.Client:
    return httpx.Client(
        base_url="https://api.spotify.com/v1",
        headers={"Authorization": f"Bearer {token}"},
    )


def search_track(client: httpx.Client, artist: str, title: str):
    for q in [f"artist:{artist} track:{title}", f"{artist} {title}"]:
        resp = client.get("/search", params={"q": q, "type": "track", "limit": 5})
        resp.raise_for_status()
        tracks = resp.json().get("tracks", {}).get("items", [])
        if tracks:
            t = tracks[0]
            return t["uri"], t["name"], t["artists"][0]["name"]
    return None, None, None


def create_playlist(client: httpx.Client, name: str, description: str = "", public: bool = False):
    resp = client.post("/me/playlists", json={"name": name, "description": description, "public": public})
    resp.raise_for_status()
    playlist = resp.json()
    return playlist["id"], playlist["external_urls"]["spotify"]


def add_tracks(client: httpx.Client, playlist_id: str, uris: list[str]):
    resp = client.post(f"/playlists/{playlist_id}/items", json={"uris": uris})
    resp.raise_for_status()


def list_playlists(client: httpx.Client):
    offset = 0
    while True:
        resp = client.get("/me/playlists", params={"limit": 50, "offset": offset})
        resp.raise_for_status()
        data = resp.json()
        items = data.get("items", [])
        if not items:
            break
        for p in items:
            total = (p.get("items") or p.get("tracks") or {}).get("total", -1)
            yield p["id"], p["name"], total
        offset += 50
        if offset >= data.get("total", 0):
            break


def delete_playlist(client: httpx.Client, playlist_id: str):
    resp = client.request("DELETE", f"/playlists/{playlist_id}/followers")
    resp.raise_for_status()


def main():
    if len(sys.argv) < 2:
        print("Usage: spotify-playlist <command>")
        print("Commands: create, list, cleanup")
        sys.exit(1)

    cmd = sys.argv[1]
    client = authenticate()

    if cmd == "create":
        if len(sys.argv) < 3:
            print('Usage: spotify-playlist create <name> [description] ["Artist:Track" ...]')
            sys.exit(1)
        name = sys.argv[2]
        desc = sys.argv[3] if len(sys.argv) > 3 else ""
        tracks = [(a, t) for arg in sys.argv[4:] if ":" in arg for a, t in [arg.split(":", 1)]]

        playlist_id, url = create_playlist(client, name, desc)
        print(f"Created playlist: {name}")

        if tracks:
            uris = []
            for artist, title in tracks:
                uri, found_title, found_artist = search_track(client, artist, title)
                if uri:
                    print(f"  + {found_artist} - {found_title}")
                    uris.append(uri)
                else:
                    print(f"  x NOT FOUND: {artist} - {title}")
            if uris:
                add_tracks(client, playlist_id, uris)
                print(f"\n{len(uris)}/{len(tracks)} tracks added.")

        print(f"Playlist URL: {url}")

    elif cmd == "list":
        for pid, name, total in list_playlists(client):
            print(f"  {name} ({total} tracks) [{pid}]")

    elif cmd == "cleanup":
        deleted = 0
        for pid, name, total in list_playlists(client):
            if total == 0:
                delete_playlist(client, pid)
                print(f"  Deleted: {name} ({pid})")
                deleted += 1
            else:
                print(f"  Keeping: {name} ({total} tracks)")
        print(f"\nDeleted {deleted} empty playlists.")

    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
