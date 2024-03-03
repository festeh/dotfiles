# Main workstation

## Gigabyte mainboard issues with instant wakeup
Use ./disable-USB-wakeup.service 

## Gigabyte mainboard bluetoth issue 
Use bluetooth dongle.
To disable onboard bluetooth add ./81-bluetooth-hci.rules to /etc/udev/rules.d/
To find the idVendor and idProduct search /sys/bus/usb/devices/ for the culprit device.
