# Reading desktop

`book-desktop up` opens the configured readers on workspace 12 and one Codex
terminal on workspace 11. Both use monocle. Focusing a different reader closes
the previous Codex terminal and resumes the selected book's saved conversation.
The other readers stay open. No message is sent to Codex when focus changes.

```sh
book-desktop prepare # copy books, extract searchable text, reuse/create sessions
book-desktop up      # open missing windows; safe to run repeatedly
book-desktop down    # close only this setup's windows and remove its workspace rules
book-desktop toggle  # start/stop
book-desktop status
book-desktop read    # jump to the selected reader (starts the setup if needed)
book-desktop chat    # jump to its Codex conversation
```

Keyboard controls:

- Super+Shift+B: start/stop.
- Super+Left/Right: previous/next existing workspace globally. The Codex and books
  workspaces remain adjacent, and entering Codex selects the book's conversation.
- Super+Up/Down in the books workspace: previous/next reader.
- Swipes and bar clicks into the Codex workspace also select the current book's
  conversation. There is one Codex terminal shared by the reading workflow;
  every book keeps a separate saved conversation.

Book titles, source paths, notes, and optional session IDs belong only in the local
`~/.config/book-desktop/books.toml`. This file is a regular file outside the
repository. The Installer links only the generic Hyprland integration and launcher
entries; it never installs or overwrites populated book settings.

On a new machine, after applying the host's Installer config:

```sh
mkdir -p ~/.config/book-desktop
cp -n ~/dotfiles/books/books.example.toml ~/.config/book-desktop/books.toml
chmod 600 ~/.config/book-desktop/books.toml
```

Fill in your local book details, then run `book-desktop up`. To apply later
settings changes, run `book-desktop down` followed by `book-desktop up`. Workspace
IDs must be adjacent, with Codex first; startup refuses to use a workspace
containing unrelated windows. Book files, extracts, session references, and runtime
state stay outside the repository. `books/books.toml` is also ignored as a guard
against accidentally adding a populated copy to the checkout. The existing
Super+B pCloud book picker remains available.

Each `~/tmp/books/<id>/` contains a copied original, `book.txt`, a short
`AGENTS.md`, and `session.id`. Existing local books and instructions are preserved;
a differing pCloud copy produces an error instead of overwriting the local book.
The session's working directory is the book folder; Codex maintains its history in
the normal `~/.codex` store. Removing the desktop never archives or deletes it.
New sessions start empty and wait for a question.

The application launcher (Super+D in the Hyprland config) also offers **Reading
Desktop** to start/resume and **Stop Reading Desktop** for teardown. Search for
`reading`, `books`, or `codex`. These are standard desktop entries installed by the host's Installer
config. Selecting Reading Desktop while it is already open returns to the reader.

Window identities and the last selected book are kept in
`~/.local/state/book-desktop/`. Teardown checks both window address and process
ID, closes reader windows normally so their applications save progress, and
returns to the previous workspace when called from the reading desktop. It does
not terminate the shared Codex daemon. A compositor restart invalidates old window
identities; run `up` to open them again. Books are copied locally for offline use.
Book switches are serialized, and the previous terminal must finish closing before
another opens. Rapid reader changes settle on the most recently focused book;
queued synchronization events after teardown never restart the desktop.

The host's Installer config registers the command/config links. The Hyprland
template optionally loads `hyprland.lua`; with the desktop stopped, it only adds
the start/stop shortcut. Teardown restores the standard Up/Down window-focus bindings.

Implementation references: [Hyprland monocle](https://wiki.hypr.land/0.56.0/Configuring/Layouts/Monocle-Layout/),
[Lua events](https://wiki.hypr.land/configuring/core/advanced-configuration/events/),
[Codex App Server](https://developers.openai.com/codex/app-server/),
[Codex session resume](https://learn.chatgpt.com/docs/cli/reference#codex-resume).
