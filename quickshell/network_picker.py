#!/usr/bin/env python3
"""Wi-Fi picker transport. JSON on stdio; libnm events, no polling loop."""

import hashlib
import json
import os
import sys

import gi

gi.require_version("NM", "1.0")
from gi.repository import GLib, GObject, NM

AP_SECURITY = getattr(NM, "80211ApSecurityFlags")
AP_FLAGS = getattr(NM, "80211ApFlags")


def security(ap):
    flags = int(ap.get_rsn_flags()) | int(ap.get_wpa_flags())
    if flags & (AP_SECURITY.KEY_MGMT_PSK | AP_SECURITY.KEY_MGMT_SAE):
        return "personal", "WPA3" if not flags & AP_SECURITY.KEY_MGMT_PSK else "WPA / WPA2", "wpa-psk" if flags & AP_SECURITY.KEY_MGMT_PSK else "sae"
    if flags & (AP_SECURITY.KEY_MGMT_802_1X | AP_SECURITY.KEY_MGMT_EAP_SUITE_B_192):
        return "enterprise", "Enterprise", None
    if flags & (AP_SECURITY.KEY_MGMT_OWE | AP_SECURITY.KEY_MGMT_OWE_TM):
        return "owe", "Enhanced open", "owe"
    if int(ap.get_flags()) & AP_FLAGS.PRIVACY:
        return "wep", "WEP", None
    return "open", "Open", None


def network_key(ssid, family):
    return hashlib.sha256(ssid + b"\0" + family.encode()).hexdigest()


def grouped(candidates):
    """Keep active AP strength truthful; otherwise prefer the strongest AP."""
    selected = {}
    for item in candidates:
        previous = selected.get(item["id"])
        if previous is None or (item["connected"], item["connecting"], item["signal"]) > (
                previous["connected"], previous["connecting"], previous["signal"]):
            selected[item["id"]] = item
    return sorted(selected.values(), key=lambda row: (
        not row["connected"], not row["connecting"], -row["signal"], row["name"].casefold(), row["id"]))


def connection_for(ssid, name, key_management, password=None, profile=None):
    connection = NM.SimpleConnection.new_clone(profile) if profile else NM.SimpleConnection.new()
    if not profile:
        settings = NM.SettingConnection.new()
        settings.set_property("id", name)
        settings.set_property("uuid", NM.utils_uuid_generate())
        settings.set_property("type", "802-11-wireless")
        settings.add_permission("user", GLib.get_user_name(), None)
        connection.add_setting(settings)
        wireless = NM.SettingWireless.new()
        wireless.set_property("ssid", GLib.Bytes.new(ssid))
        wireless.set_property("mode", "infrastructure")
        connection.add_setting(wireless)
        for kind in (NM.SettingIP4Config, NM.SettingIP6Config):
            ip = kind.new()
            ip.set_property("method", "auto")
            connection.add_setting(ip)
    if key_management:
        secure = connection.get_setting_wireless_security()
        if secure is None:
            secure = NM.SettingWirelessSecurity.new()
            secure.set_property("key-mgmt", key_management)
            connection.add_setting(secure)
        elif not profile:
            secure.set_property("key-mgmt", key_management)
        if password is not None:
            secure.set_property("psk", password)
            secure.set_property("psk-flags", NM.SettingSecretFlags.NONE)
    connection.verify()
    connection.verify_secrets()
    return connection


class Picker:
    def __init__(self, emit, loop):
        self.emit = emit
        self.loop = loop
        self.client = None
        self.device = None
        self.targets = {}
        self.watches = {}
        self.pending_publish = 0
        self.scan_timeout = 0
        self.scan_started = -1
        self.scan_device = None
        self.auto_scan = True
        self.pending = ""
        self.busy = False
        self.message = ""
        self.last_snapshot = None
        self.initialized = False
        NM.Client.new_async(None, self.client_ready)

    def client_ready(self, _source, result, *_args):
        try:
            self.client = NM.Client.new_finish(result)
        except GLib.Error:
            self.message = "Cannot reach NetworkManager. Close and reopen to retry."
        self.initialized = True
        self.changed()

    def watch(self, obj, signal, callback=None):
        key = (obj, signal)
        self.wanted.add(key)
        if key not in self.watches:
            self.watches[key] = obj.connect(signal, callback or self.changed)

    def changed(self, *_args):
        if not self.pending_publish:
            self.pending_publish = GLib.idle_add(self.publish)

    def snapshot(self):
        self.wanted = set()
        self.targets = {}
        candidates = []
        available = bool(self.client and self.client.get_nm_running())
        enabled = bool(available and self.client.wireless_get_enabled())
        hardware = bool(available and self.client.wireless_hardware_get_enabled())
        if self.client:
            self.watch(self.client, "notify")
        devices = [device for device in self.client.get_devices() if isinstance(device, NM.DeviceWifi)] if available else []
        devices.sort(key=lambda device: (not device.get_state() == NM.DeviceState.ACTIVATED, not device.get_managed(), device.get_iface()))
        self.device = devices[0] if devices else None
        if self.device:
            device = self.device
            self.watch(device, "notify")
            self.watch(device, "access-point-added")
            self.watch(device, "access-point-removed")
            self.watch(device, "state-changed", self.state_changed)
            if self.scan_device == device and device.get_last_scan() > self.scan_started:
                self.finish_scan()
            active = device.get_active_access_point()
            profiles = [profile for profile in self.client.get_connections() if profile.get_setting_connection()]
            for profile in profiles:
                self.watch(profile, "changed")
            for ap in device.get_access_points():
                self.watch(ap, "notify")
                ssid = ap.get_ssid()
                if not ssid or not ssid.get_size() or int(ap.get_mode()) != 2:
                    continue
                raw = bytes(ssid.get_data())
                family, label, key_management = security(ap)
                compatible = [profile for profile in profiles if device.connection_valid(profile) and ap.connection_valid(profile)]
                compatible.sort(key=lambda profile: (
                    -profile.get_setting_connection().get_timestamp(), profile.get_uuid()))
                profile = compatible[0] if compatible else None
                key = network_key(raw, family)
                is_active = ap == active
                connected = is_active and device.get_state() == NM.DeviceState.ACTIVATED
                connecting = is_active and 40 <= int(device.get_state()) <= 90
                row = {"id": key, "name": raw.decode("utf-8", "replace"), "security": label,
                       "personal": family == "personal", "supported": family in ("open", "personal", "owe") or bool(profile),
                       "known": bool(profile), "connected": connected, "connecting": connecting or key == self.pending,
                       "signal": int(ap.get_strength())}
                candidates.append(row | {"target": (device, ap, profile, raw, key_management)})
        rows = []
        for candidate in grouped(candidates):
            self.targets[candidate["id"]] = candidate.pop("target")
            rows.append(candidate)
        if self.pending and any(row["id"] == self.pending and row["connected"] for row in rows):
            self.busy = False
            self.pending = ""
            self.message = "Connected"
        if not available:
            self.auto_scan = True
            self.busy = False
            self.pending = ""
            self.finish_scan()
        for key in list(self.watches):
            if key not in self.wanted:
                GObject.signal_handler_disconnect(key[0], self.watches.pop(key))
        return {"type": "snapshot", "ready": self.initialized, "available": available,
                "wifiEnabled": enabled, "hardwareEnabled": hardware,
                "hasWifi": bool(devices), "managed": bool(self.device and self.device.get_managed()),
                "scanning": bool(self.scan_timeout), "busy": self.busy,
                "interfaceName": self.device.get_iface() if self.device else "",
                "message": self.message, "rows": rows if enabled and hardware else []}

    def publish(self):
        self.pending_publish = 0
        snapshot = self.snapshot()
        if snapshot != self.last_snapshot:
            self.last_snapshot = snapshot
            self.emit(snapshot)
        if self.auto_scan and snapshot["wifiEnabled"] and snapshot["hardwareEnabled"] and snapshot["managed"]:
            self.auto_scan = False
            self.scan(False)
        return GLib.SOURCE_REMOVE

    def finish_scan(self):
        if self.scan_timeout:
            GLib.source_remove(self.scan_timeout)
            self.scan_timeout = 0
        self.scan_device = None

    def scan(self, manual=True):
        if self.scan_timeout or not self.device or not self.client.wireless_get_enabled():
            return
        self.scan_device = self.device
        self.scan_started = self.device.get_last_scan()
        self.scan_timeout = GLib.timeout_add_seconds(12, self.scan_expired)
        if manual:
            self.message = ""
        def complete(device, result, *_args):
            try:
                device.request_scan_finish(result)
            except GLib.Error:
                self.finish_scan()
                if manual:
                    self.message = "Scan unavailable right now. Showing the latest results."
            self.changed()
        self.device.request_scan_async(None, complete)
        self.changed()

    def scan_expired(self):
        self.scan_timeout = 0
        self.scan_device = None
        self.changed()
        return GLib.SOURCE_REMOVE

    def error(self, message):
        self.busy = False
        self.pending = ""
        self.message = message
        self.changed()

    def state_changed(self, _device, state, _old, reason):
        if self.pending and int(state) == int(NM.DeviceState.FAILED):
            key = self.pending
            target = self.targets.get(key)
            self.error("Connection failed. Check the password or signal and try again.")
            if target and security(target[1])[0] == "personal":
                self.emit({"type": "password", "id": key, "retry": True})
        elif self.pending and int(state) == int(NM.DeviceState.DISCONNECTED) and 40 <= int(_old) <= 90:
            self.error("Connection cancelled. Choose a network to try again.")
        self.changed()

    def activate(self, key, password=None):
        self.snapshot()
        target = self.targets.get(key)
        if not target:
            return self.error("This network is no longer available. Refresh and try again.")
        device, ap, profile, raw, key_management = target
        family, _label, _key = security(ap)
        if device.get_state() == NM.DeviceState.ACTIVATED and device.get_active_access_point() == ap:
            return
        if family not in ("open", "owe", "personal") and (not profile or password is not None):
            return self.error("This network needs a configured NetworkManager profile.")
        if family == "personal" and not profile and password is None:
            self.emit({"type": "password", "id": key, "retry": False})
            return
        connection = None
        if password is not None or not profile:
            try:
                connection = connection_for(raw, raw.decode("utf-8", "replace"), key_management, password, profile)
            except (GLib.Error, ValueError, TypeError):
                self.error("Invalid password. WPA/WPA2 needs 8–63 bytes or a 64-digit hexadecimal key.")
                self.emit({"type": "password", "id": key, "retry": True})
                return
        self.pending = key
        self.busy = True
        self.message = "Connecting…"
        self.changed()

        def complete(client, result, adding=False):
            try:
                if adding:
                    client.add_and_activate_connection_finish(result)
                else:
                    client.activate_connection_finish(result)
            except GLib.Error:
                self.error("Could not connect. Check the password and NetworkManager permissions.")
                if family == "personal":
                    self.emit({"type": "password", "id": key, "retry": True})

        if profile and password is not None:
            def saved(remote, result, *_args):
                try:
                    remote.update2_finish(result)
                    self.client.activate_connection_async(remote, device, ap.get_path(), None, complete)
                except GLib.Error:
                    self.error("Could not save the new password. Check NetworkManager permissions.")
            profile.update2(connection.to_dbus(NM.ConnectionSerializationFlags(0)),
                            NM.SettingsUpdate2Flags.TO_DISK, None, None, saved)
        elif profile:
            self.client.activate_connection_async(profile, device, ap.get_path(), None, complete)
        else:
            self.client.add_and_activate_connection_async(connection, device, ap.get_path(), None,
                lambda client, result, *_args: complete(client, result, True))

    def command(self, command):
        action = command.get("action")
        if not self.client or not self.client.get_nm_running():
            return self.error("NetworkManager unavailable")
        if action == "scan":
            self.scan()
        elif action == "wifi" and not self.busy and self.client.wireless_hardware_get_enabled():
            enabled = command.get("enabled") is True
            self.auto_scan = enabled
            self.busy = True
            self.message = "Turning Wi-Fi on…" if enabled else "Turning Wi-Fi off…"
            def complete(client, result, *_args):
                try:
                    client.dbus_set_property_finish(result)
                    self.message = ""
                except GLib.Error:
                    self.auto_scan = False
                    self.message = "Could not change Wi-Fi. Check NetworkManager permissions."
                self.busy = False
                self.changed()
            self.client.dbus_set_property("/org/freedesktop/NetworkManager",
                "org.freedesktop.NetworkManager", "WirelessEnabled", GLib.Variant("b", enabled),
                -1, None, complete)
            self.changed()
        elif action == "connect" and not self.busy:
            self.activate(str(command.get("id", "")), command.get("password"))
        elif action == "disconnect" and not self.busy and self.device:
            self.busy = True
            self.message = "Disconnecting…"
            def complete(device, result, *_args):
                try:
                    device.disconnect_finish(result)
                    self.message = "Disconnected"
                except GLib.Error:
                    self.message = "Could not disconnect. Check NetworkManager permissions."
                self.busy = False
                self.changed()
            self.device.disconnect_async(None, complete)
            self.changed()


def main():
    loop = GLib.MainLoop()
    def emit(value):
        try:
            print(json.dumps(value, ensure_ascii=True), flush=True)
        except BrokenPipeError:
            loop.quit()
    picker = Picker(emit, loop)
    os.set_blocking(sys.stdin.fileno(), False)
    buffer = bytearray()
    def receive(fd, condition):
        nonlocal buffer
        chunk = os.read(fd, 65536)
        if not chunk:
            loop.quit()
            return GLib.SOURCE_REMOVE
        buffer.extend(chunk)
        while b"\n" in buffer:
            line, _, buffer = buffer.partition(b"\n")
            try:
                command = json.loads(line)
                if isinstance(command, dict):
                    picker.command(command)
            except (ValueError, TypeError, GLib.Error):
                picker.error("Could not complete the network action.")
        return GLib.SOURCE_CONTINUE
    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, receive)
    loop.run()


if __name__ == "__main__":
    main()
