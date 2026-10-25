# BlueZ, for Bluetooth LE receivers such as blugw-mqtt that talk to
# bluetoothd over the system D-Bus. Every client has an adapter (hci0).
{ ... }:
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
