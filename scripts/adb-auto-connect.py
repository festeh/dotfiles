#!/usr/bin/env python3

"""
ADB Auto-Connect via mDNS
Automatically discovers and connects to Android devices via Wireless Debugging
"""

import subprocess
import sys
import re
from typing import List, Dict, Optional


class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'


def run_command(cmd: List[str], capture=True) -> tuple[bool, str]:
    """Run a command and return success status and output"""
    try:
        if capture:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            return result.returncode == 0, result.stdout + result.stderr
        else:
            result = subprocess.run(cmd, timeout=10)
            return result.returncode == 0, ""
    except subprocess.TimeoutExpired:
        return False, "Command timed out"
    except Exception as e:
        return False, str(e)


def get_mdns_devices() -> List[Dict[str, str]]:
    """Get list of devices from mDNS discovery"""
    success, output = run_command(["adb", "mdns", "services"])

    if not success:
        print(f"{Colors.RED}Failed to query mDNS services{Colors.NC}")
        sys.exit(1)

    devices = []
    for line in output.strip().split('\n'):
        if '_adb-tls-connect._tcp' in line:
            parts = line.split('\t')
            if len(parts) >= 3:
                service_name = parts[0].strip()
                address = parts[2].strip()
                devices.append({
                    'service_name': service_name,
                    'address': address
                })

    return devices


def deduplicate_devices(devices: List[Dict[str, str]]) -> List[Dict[str, str]]:
    """Deduplicate devices by service name, always selecting the address with the smallest port"""
    seen = {}
    all_addresses = {}

    for device in devices:
        service = device['service_name']
        # Remove (n) suffix if present
        clean_service = re.sub(r' \(\d+\)$', '', service)

        # Collect all addresses for this service
        if clean_service not in all_addresses:
            all_addresses[clean_service] = []
        all_addresses[clean_service].append(device['address'])

    # For each unique service, select the address with the smallest port
    result = []
    for clean_service, addresses in all_addresses.items():
        # Sort addresses by port number (extract port from IP:PORT)
        sorted_addresses = sorted(addresses, key=lambda addr: int(addr.split(':')[1]))

        # Select the one with the smallest port
        selected_address = sorted_addresses[0]

        result.append({
            'service_name': clean_service,
            'address': selected_address,
            'all_addresses': sorted_addresses
        })

    return result


def get_device_info(address: str) -> Optional[Dict[str, str]]:
    """Try to get device information after connecting"""
    # Try to connect
    success, _ = run_command(["adb", "connect", address])

    if not success:
        return None

    # Give it a moment to establish connection
    import time
    time.sleep(1)

    # Try to get device properties
    info = {}

    success, model = run_command(["adb", "-s", address, "shell", "getprop", "ro.product.model"])
    if success:
        info['model'] = model.strip()

    success, manufacturer = run_command(["adb", "-s", address, "shell", "getprop", "ro.product.manufacturer"])
    if success:
        info['manufacturer'] = manufacturer.strip()

    success, device_name = run_command(["adb", "-s", address, "shell", "settings", "get", "global", "device_name"])
    if success and device_name.strip() and device_name.strip() != "null":
        info['device_name'] = device_name.strip()

    return info if info else None


def format_device_name(device: Dict[str, str], info: Optional[Dict[str, str]]) -> str:
    """Format a display name for the device"""
    if info:
        if 'device_name' in info:
            return f"{info['device_name']} ({info.get('manufacturer', '')} {info.get('model', '')})"
        elif 'model' in info:
            return f"{info.get('manufacturer', '')} {info['model']}"

    return device['service_name']


def connect_device(address: str) -> bool:
    """Connect to a device"""
    success, output = run_command(["adb", "connect", address])
    print(output)

    return "connected" in output.lower()


def pair_device(ip: str, port: str, code: str) -> bool:
    """Pair with a device using pairing code"""
    print(f"Pairing with {ip}:{port}...")
    success, output = run_command(["adb", "pair", f"{ip}:{port}", code])
    print(output)
    return success


def main():
    print(f"{Colors.BLUE}Discovering Android devices via mDNS...{Colors.NC}")

    devices = get_mdns_devices()

    if not devices:
        print(f"{Colors.RED}No devices found via mDNS.{Colors.NC}")
        print("Make sure:")
        print("  1. Wireless Debugging is enabled on your Android device")
        print("  2. Your device and computer are on the same network")
        print("  3. Your device is Android 11+ with mDNS support")
        sys.exit(1)

    # Deduplicate
    unique_devices = deduplicate_devices(devices)

    print(f"{Colors.GREEN}Found {len(unique_devices)} unique device(s){Colors.NC}\n")

    # Select device
    if len(unique_devices) == 1:
        selected = unique_devices[0]
        print(f"{Colors.GREEN}Device:{Colors.NC} {Colors.BLUE}{selected['service_name']}{Colors.NC}")
        print(f"{Colors.GREEN}Address:{Colors.NC} {Colors.BLUE}{selected['address']}{Colors.NC}")

        # Show all addresses if there are duplicates
        if len(selected.get('all_addresses', [])) > 1:
            print(f"{Colors.BLUE}All available addresses:{Colors.NC}")
            for addr in selected['all_addresses']:
                marker = " (selected)" if addr == selected['address'] else ""
                print(f"  - {addr}{marker}")

        print("Connecting...")
    else:
        print(f"{Colors.BLUE}Multiple devices found:{Colors.NC}\n")
        for i, device in enumerate(unique_devices, 1):
            print(f" {i:2d}) {device['service_name']:<35} {device['address']}")
            # Show additional addresses if any
            if len(device.get('all_addresses', [])) > 1:
                for addr in device['all_addresses']:
                    if addr != device['address']:
                        print(f"     {'':<35} {addr}")

        print()
        try:
            choice = int(input(f"Select device number (1-{len(unique_devices)}): "))
            if choice < 1 or choice > len(unique_devices):
                print(f"{Colors.RED}Invalid selection{Colors.NC}")
                sys.exit(1)
            selected = unique_devices[choice - 1]
            print(f"{Colors.GREEN}Connecting to: {selected['service_name']} ({selected['address']}){Colors.NC}")
        except (ValueError, KeyboardInterrupt):
            print(f"\n{Colors.RED}Invalid selection{Colors.NC}")
            sys.exit(1)

    # Try to connect
    if connect_device(selected['address']):
        print(f"\n{Colors.BLUE}Current ADB devices:{Colors.NC}")
        run_command(["adb", "devices"], capture=False)
        print(f"{Colors.GREEN}✓ Successfully connected!{Colors.NC}")

        # Optional: Start flutter debugging
        import os
        if os.path.exists("pubspec.yaml"):
            response = input("\nStart Flutter debugging? (y/N): ")
            if response.lower() == 'y':
                run_command(["flutter", "run"], capture=False)
    else:
        print(f"\n{Colors.RED}✗ Connection failed. Device needs to be paired first.{Colors.NC}")
        print(f"\n{Colors.BLUE}To pair this device:{Colors.NC}")
        print("1. On your Android device, go to Settings > Developer options > Wireless debugging")
        print("2. Tap 'Pair device with pairing code'")
        print("3. You'll see a pairing code and IP address with port")

        response = input("\nDo you want to pair now? (y/N): ")
        if response.lower() == 'y':
            pair_port = input("Enter pairing port: ")
            pair_code = input("Enter pairing code: ")

            device_ip = selected['address'].split(':')[0]

            if pair_device(device_ip, pair_port, pair_code):
                print(f"\nNow connecting to {selected['address']}...")
                connect_device(selected['address'])

                print(f"\n{Colors.BLUE}Current ADB devices:{Colors.NC}")
                run_command(["adb", "devices"], capture=False)


if __name__ == "__main__":
    main()
