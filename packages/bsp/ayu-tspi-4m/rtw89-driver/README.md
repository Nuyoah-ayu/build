# RTL8922AE vendor kernel backport

Source: https://github.com/lwfinger/rtw89

Commit: `d1fced1b8a741dc9f92b47c69489c24385945f6e`.

Archive SHA256: `4195581ee75497f96702b4b1f72de65353822b423bbf76e3eb0075106133b86e`.

The archive contains the upstream GPLv2 license and source files.
The board hook checks the archive before extraction.
The hook runs only for the TSPI vendor kernel.
The hook retains the native Kconfig and replaces the rtw89 build sources.
The archive checksum participates in the kernel artifact version.

The modules compile against Rockchip 6.1.115 and 6.1.172.
The compatibility patch restores HE capability assignment before Linux 6.7.
The patch converts receive GI values when matching PPDU reports on Linux 5.18 through 6.2.
Without this conversion, unmatched reports leave signal strength at zero.
RTL8922AE testing on 6.1.172 restores negative dBm readings and access point signal bars.
The patch selects firmware for the nearest supported chip cut.
The RTL8922AE cut C card scans access points on the test board.
The RTL8922AU USB Bluetooth identifiers use a separate vendor kernel patch.
