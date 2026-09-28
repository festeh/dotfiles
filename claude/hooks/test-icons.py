#!/usr/bin/env python3
"""Standalone test to verify Claude status icons render in GTK4."""

import sys
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gdk

ICONS = {
    "running": "system-run-symbolic",
    "waiting": "dialog-warning-symbolic",
    "idle": "object-select-symbolic",
}


class TestWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Claude Icons Test")
        self.set_default_size(300, 120)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, margin_top=12, margin_bottom=12, margin_start=12, margin_end=12)
        self.set_child(box)

        for state, icon_name in ICONS.items():
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            img = Gtk.Image.new_from_icon_name(icon_name)
            img.set_icon_size(Gtk.IconSize.LARGE)
            row.append(img)
            row.append(Gtk.Label(label=f"{state}: {icon_name}"))
            box.append(row)


def on_activate(app):
    win = TestWindow(app)
    win.present()


app = Gtk.Application(application_id="com.example.icon-test")
app.connect("activate", on_activate)
app.run(sys.argv)
