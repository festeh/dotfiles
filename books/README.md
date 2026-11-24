# Reading Desktop

Press **Super+B** and choose a book. Reading Desktop opens its reader on workspace
12 and its Codex conversation on workspace 11. Choosing another book switches
both windows. Each book keeps its local copy, reading progress and conversation.

**Super+Shift+B** stops the desktop or reopens the last selection. The application
launcher also offers **Reading Desktop** and **Stop Reading Desktop**. With no
selection yet, starting the desktop opens the Books picker.

```sh
book-desktop select "/path/to/book.pdf"  # select a book and open the pair
book-desktop up                         # open or focus the selected reader
book-desktop chat                       # open or focus its Codex conversation
book-desktop read                       # open or focus its reader
book-desktop prepare                    # prepare the selected book without opening windows
book-desktop status                     # check actual managed windows
book-desktop toggle                     # start or stop
book-desktop down                       # close the pair, including after a partial start
```

The default configuration works without a settings file. To customize the storage
root, adjacent workspaces or toggle shortcut, copy `books.example.toml` to
`~/.config/book-desktop/books.toml`. Existing `[[books]]` entries retain their
reader settings, folders and saved sessions. On upgrade the previous active book
supplies the initial selection.

New books use a path-derived folder under `~/tmp/books`. PDFs open in Alpha,
DjVu uses Zathura with its DjVu plugin, and other library formats use Foliate.
PDF and FB2 books also get a searchable text extract. Once prepared, a book
can reopen from its local copy while pCloud is offline.

The selected path and runtime window identities stay under
`~/.local/state/book-desktop/`. Stop checks each managed window's compositor
instance, address and PID, waits for it to close, then releases the workspace
rules. If a window refuses to close, Stop or the toggle can retry. When invoked
from a reading workspace, Stop returns to the previous workspace if available.
