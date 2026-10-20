#!/usr/bin/env python3
"""Exercise picker selection and actions without contacting NetworkManager."""

import importlib.util
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("network_picker", Path(__file__).resolve().parents[1] / "network_picker.py")
picker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(picker)
NM, GLib = picker.NM, picker.GLib


class AccessPoint:
    def __init__(self, ssid, strength, protected=True):
        self.ssid, self.strength, self.protected = ssid, strength, protected

    def get_ssid(self): return GLib.Bytes.new(self.ssid)
    def get_mode(self): return 2
    def get_rsn_flags(self): return picker.AP_SECURITY.KEY_MGMT_PSK if self.protected else 0
    def get_wpa_flags(self): return 0
    def get_flags(self): return picker.AP_FLAGS.PRIVACY if self.protected else 0
    def get_strength(self): return self.strength
    def get_path(self): return "/mock/AccessPoint/" + str(id(self))

    def connection_valid(self, connection):
        ssid = connection.get_setting_wireless().get_ssid()
        return bytes(ssid.get_data()) == self.ssid and bool(connection.get_setting_wireless_security()) == self.protected


class Device:
    def __init__(self, aps, active=None):
        self.aps, self.active = aps, active
        self.state = NM.DeviceState.ACTIVATED if active else NM.DeviceState.DISCONNECTED

    def get_state(self): return self.state
    def get_managed(self): return True
    def get_iface(self): return "mock-wifi"
    def get_last_scan(self): return -1
    def get_active_access_point(self): return self.active
    def get_access_points(self): return self.aps
    def connection_valid(self, connection): return True


class Client:
    def __init__(self, device, profiles=()):
        self.device, self.profiles = device, profiles
        self.activate_connection_async = Mock()
        self.add_and_activate_connection_async = Mock()
        self.dbus_set_property = Mock()

    def get_nm_running(self): return True
    def wireless_get_enabled(self): return True
    def wireless_hardware_get_enabled(self): return True
    def get_devices(self): return [self.device]
    def get_connections(self): return self.profiles


def controller(device, profiles=()):
    p = picker.Picker.__new__(picker.Picker)
    p.client = Client(device, profiles)
    p.device = device
    p.targets, p.watches = {}, {}
    p.pending, p.message = "", ""
    p.busy = False
    p.initialized = True
    p.scan_device, p.scan_timeout = None, 0
    p.watch = Mock()
    p.changed = Mock()
    p.emit = Mock()
    return p


class PickerTests(unittest.TestCase):
    def setUp(self):
        self.patch = patch.object(NM, "DeviceWifi", Device)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def test_active_ap_strength_and_live_ordering(self):
        active, alternate = AccessPoint(b"Example", 20), AccessPoint(b"Example", 90)
        first, second = AccessPoint(b"First", 60), AccessPoint(b"Second", 40)
        p = controller(Device([alternate, active, first, second], active))
        rows = p.snapshot()["rows"]
        self.assertEqual([(r["name"], r["signal"]) for r in rows], [("Example", 20), ("First", 60), ("Second", 40)])
        second.strength = 80
        self.assertEqual([r["name"] for r in p.snapshot()["rows"]], ["Example", "Second", "First"])

    def test_security_and_raw_ssid_identity_cannot_merge(self):
        p = controller(Device([AccessPoint(b"Same", 20), AccessPoint(b"Same", 50, False),
            AccessPoint(b"Cafe\xff", 60), AccessPoint(b"Cafe\xfe", 70), AccessPoint(b"", 90)]))
        rows = p.snapshot()["rows"]
        self.assertEqual(len(rows), 4)
        self.assertEqual(len({r["id"] for r in rows}), 4)
        self.assertEqual(sum(r["name"] == "Same" for r in rows), 2)
        json.dumps(rows)

    def test_saved_profile_is_selected_by_compatibility_and_recency(self):
        ap = AccessPoint(b"Example", 70)
        old = picker.connection_for(b"Example", "Old profile", "wpa-psk", "example-password")
        recent = picker.connection_for(b"Example", "Different label", "wpa-psk", "example-password")
        recent.get_setting_connection().set_property("timestamp", 100)
        unrelated = picker.connection_for(b"Other", "Example", "wpa-psk", "example-password")
        p = controller(Device([ap]), [old, recent, unrelated])
        row = p.snapshot()["rows"][0]
        self.assertTrue(row["known"])
        p.activate(row["id"])
        args = p.client.activate_connection_async.call_args.args
        self.assertIs(args[0], recent)
        self.assertEqual(args[2], ap.get_path())
        p.client.add_and_activate_connection_async.assert_not_called()
        self.assertTrue(p.busy)

    def test_unsaved_personal_network_requests_a_password_without_activating(self):
        p = controller(Device([AccessPoint(b"Example", 70)]))
        row = p.snapshot()["rows"][0]
        p.activate(row["id"])
        self.assertEqual(p.emit.call_args.args[0]["type"], "password")
        p.client.activate_connection_async.assert_not_called()
        p.client.add_and_activate_connection_async.assert_not_called()
        p.activate(row["id"], "short")
        p.client.add_and_activate_connection_async.assert_not_called()
        self.assertFalse(p.busy)

    def test_valid_password_is_only_given_to_networkmanager(self):
        p = controller(Device([AccessPoint(b"Example", 70)]))
        row = p.snapshot()["rows"][0]
        p.activate(row["id"], "example-password")
        connection = p.client.add_and_activate_connection_async.call_args.args[0]
        self.assertEqual(connection.get_setting_wireless_security().get_psk(), "example-password")
        self.assertNotIn("example-password", json.dumps(p.snapshot()))

    def test_open_network_needs_no_password_and_active_click_does_nothing(self):
        ap = AccessPoint(b"Open", 70, False)
        p = controller(Device([ap]))
        p.activate(p.snapshot()["rows"][0]["id"])
        self.assertIsNone(p.client.add_and_activate_connection_async.call_args.args[0].get_setting_wireless_security())
        p = controller(Device([ap], ap))
        p.activate(p.snapshot()["rows"][0]["id"])
        p.client.add_and_activate_connection_async.assert_not_called()

    def test_failure_releases_busy_state_and_offers_password_retry(self):
        p = controller(Device([AccessPoint(b"Example", 70)]))
        key = p.snapshot()["rows"][0]["id"]
        p.activate(key, "example-password")
        p.state_changed(p.device, NM.DeviceState.FAILED, NM.DeviceState.CONFIG, NM.DeviceStateReason.NO_SECRETS)
        self.assertFalse(p.busy)
        self.assertEqual(p.emit.call_args.args[0], {"type": "password", "id": key, "retry": True})

    def test_changed_password_preserves_profile_identity_and_rejects_bad_keys(self):
        original = picker.connection_for(b"Example", "Existing name", "wpa-psk", "example-password")
        updated = picker.connection_for(b"Example", "Ignored new name", "wpa-psk", "changed-password", original)
        self.assertEqual(updated.get_uuid(), original.get_uuid())
        self.assertEqual(updated.get_id(), original.get_id())
        self.assertEqual(original.get_setting_wireless_security().get_psk(), "example-password")
        wpa3 = picker.connection_for(b"Example", "WPA3 profile", "sae", "example-password")
        preserved = picker.connection_for(b"Example", "Ignored", "wpa-psk", "changed-password", wpa3)
        self.assertEqual(preserved.get_setting_wireless_security().get_key_mgmt(), "sae")
        for password in ["short", "z" * 64]:
            with self.assertRaises(GLib.Error):
                picker.connection_for(b"Example", "Example", "wpa-psk", password)
        picker.connection_for(b"Example", "Example", "wpa-psk", "a" * 64)

    def test_radio_action_uses_an_async_property_write(self):
        p = controller(Device([]))
        p.command({"action": "wifi", "enabled": False})
        args = p.client.dbus_set_property.call_args.args
        self.assertEqual(args[0:3], ("/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", "WirelessEnabled"))
        self.assertFalse(args[3].unpack())
        self.assertTrue(p.busy)


if __name__ == "__main__":
    unittest.main()
