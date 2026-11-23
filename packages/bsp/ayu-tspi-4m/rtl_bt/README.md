# RTL8922AU Bluetooth firmware

Source: https://gitlab.com/kernel-firmware/linux-firmware

Retrieved on 2026-11-14 from `rtl_bt/` on `main`.
The upstream API reported revision `1399ab86b447b949e71ae9858fbc8f942b7bff4c`.
The files are pinned by these SHA256 values:

| File | SHA256 |
| --- | --- |
| rtl8922au_fw.bin | 112290ca9dc3985034f572594812f0deb8530dd031686461b55cac43a1c35a79 |
| rtl8922au_config.bin | 6c28a3f07c6a30ed208c4b64862a23f02b7d93543ea980edd24df16bab45095f |

`LICENCE.rtlwifi_firmware.txt` accompanies these redistributable binaries.
The board image hook installs both files under `/lib/firmware/rtl_bt/`.
Driver support for RTL8922AU is also required.

## TSPI-4M verification

The RTL8922AE module exposes Wi-Fi over PCIe and Bluetooth over USB.
This board reports USB ID `0bda:8922` and loads the RTL8922AU firmware above.
Kernel `6.1.172-vendor-rk35xx` passes discovery and the ayu Blueman applet power switch test.
Pairing and Bluetooth audio remain untested.

The vendor board DTS disables the empty `bluetooth-platdata` node.
That node has no power GPIO or clock and creates a redundant blocked `bt_default` switch.
The actual USB controller uses `btusb` and its own rfkill switch.

Check `rfkill list` and `bluetoothctl show` when Bluetooth stays off.
Run `sudo rfkill unblock bluetooth` to clear a software block.
Wait for `PowerState` to settle before retrying `bluetoothctl power on`.
The system saves the user's radio state. The SDK does not force Bluetooth on at every boot.
