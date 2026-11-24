# FLSUN_NFC

NFC/RFID filament tags on the FLSUN T1 / T1 Pro. Scan a spool's tag and:

- the spool becomes Moonraker's **active spool** in Spoolman, so its filament use is tracked,
- the tag's UID is linked to the Spoolman spool, so plain tags work next time,
- the spool's material, color and temperatures go to Moonraker's **lane_data** (lane 1), which OrcaSlicer and HelixScreen read, plus `filament_id` from the Spoolman filament's `orca_filament_id` extra field, so OrcaSlicer picks that exact filament preset.

The T1 has one toolhead, so there's no slot prompt: whatever you scan is the spool on the printer. A tag with no Spoolman spool clears the active spool, so filament isn't booked on the spool that was loaded before (`clear_active_spool: False` turns that off).

FLSUN_NFC is the T1 version of [FF_NFC](https://github.com/DIEHARDave/FF_NFC) (Flashforge AD5X / Creator 5 Pro). It carries a pinned copy of FF_NFC's reader and tag code, so it reads the same tags: Spoolman, OpenPrintTag, OpenTag3D, OpenSpool, SpoolEase, Bambu, Creality, Snapmaker, TigerTag, Anycubic, Elegoo, Qidi and plain text (`PLA:FF0000`). It also reads spool QR labels with the printer camera (`SCAN_QR_LABEL`).

## Readers

| Reader | How it connects | Notes |
|---|---|---|
| ACR122U, ACR1552U and other USB CCID readers | USB | Found automatically |
| PN532 board with a CH340, CP2102, PL2303 or FTDI USB adapter | USB serial | Found automatically |
| ESP32 / RP2040 running [rfidnfc2usb_bridge](https://github.com/DIEHARDave/rfidnfc2usb_bridge) (PN532, RC522, PN5180) | USB serial | Found automatically |
| [LaneTag](https://github.com/DIEHARDave/LaneTag) Wi-Fi reader | Network | Nothing to set up on the printer |

**CH340 readers:** the T1's mainboard is a CH340 too, and a CH340 reader gets the same `/dev/serial/by-id` name as the mainboard (`usb-1a86_USB_Serial-if00-port0`). Without a fix, that name would point to whichever was plugged in last, and Klipper would open the reader as the mainboard at its next restart. install.sh adds a udev rule that keeps the name on the mainboard's internal USB port. FLSUN_NFC never probes that port. On a printer whose mainboard isn't on that port, FLSUN_NFC probes no CH340 at all, and a CH340 reader needs `device:` set to its `/dev/serial/by-path` name.

## Install

With [FLSUN_Updater](https://github.com/DIEHARDave/FLSUN_Updater): run `PLUGINS` in the console, turn on FLSUN_NFC and click Save.

By hand, as the pi user:

```sh
git clone https://github.com/DIEHARDave/FLSUN_NFC.git ~/FLSUN_NFC
~/FLSUN_NFC/install.sh
```

The installer:

- links the Klipper module into upstream Klipper (FLSUN_klipper) and FLSun's own Klipper,
- adds `[include flsun_nfc.cfg]` to printer.cfg (above the SAVE_CONFIG block),
- installs udev rules: one so Klipper (user pi) can open USB readers, one that keeps the mainboard's serial name on the mainboard,
- adds the Moonraker update manager entry (`flsun_nfc.conf`).

It then restarts Moonraker and Klipper, unless a print is running.

Updates come through Mainsail / Fluidd (Software Updates); Klipper restarts afterwards. Plug in a reader and run `NFC_STATUS`.

## Settings

Put your own settings in `flsun_nfc_user.cfg` next to printer.cfg (create it):

```ini
[flsun_nfc]
spoolman_auto_create: True
```

Both Klippers read it, and updates never touch it. Upstream Klipper doesn't read the rest of printer.cfg, so a `[flsun_nfc]` section there would be ignored. All options are listed in [flsun_nfc.cfg](flsun_nfc.cfg).

## Commands

| Command | |
|---|---|
| `NFC_STATUS` | Reader state, last tag, filament sensor |
| `NFC_DUMP` | Everything read from the last tag (`RAW=1` adds the memory) |
| `NFC_RESCAN` | Read the tag on the reader again |
| `NFC_CREATE_SPOOL` | Add the last tag's filament to Spoolman |
| `NFC_TEST_SCAN TEXT=PLA:FF0000` | Simulate a scan without a reader (`SPOOL=<id>` for a Spoolman spool) |
| `NFC_QR_SCAN` / `SCAN_QR_LABEL` | Read a QR label with the camera |
| `NFC_ENABLE` / `NFC_DISABLE` | Turn scan handling on and off |

`NFC_TEST_SCAN` links its made-up UID (04A1B2C3D4E5F6, or `UID=`) to a Spoolman spool like a real tag. Remove it from the spool afterwards.

## Uninstall

```sh
~/FLSUN_NFC/uninstall.sh
rm -rf ~/FLSUN_NFC
```

## Development

`python/ffnfc` is FF_NFC's code at the release in [FFNFC_VERSION](FFNFC_VERSION). Don't edit it here: fix FF_NFC, then run `tools/sync_ffnfc.sh <tag>`. FLSUN_NFC's own code is `python/flsunnfc` (the T1 platform) and `extras/flsun_nfc.py` (the Klipper entry).

Run the tests with `python3 -m unittest discover -s tests`. On Windows, run them in WSL: the reader code needs `fcntl`.

## License

GPLv3, like FF_NFC.
