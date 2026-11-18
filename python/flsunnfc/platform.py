"""FLSUN T1 / T1 Pro: one toolhead, no filament changer.

A scanned spool is the spool on the printer, so there is no slot prompt:
the tag's spool becomes Moonraker's active spool (Spoolman tracks its
usage), its UID is linked to the spool in Spoolman, and lane_data slot 1
gets its material and color for slicers and screens that read it.

A tag with no Spoolman spool clears the active spool (option
clear_active_spool), so usage isn't booked on the spool that was loaded
before.

The T1's mainboard is a CH340 USB serial chip (1a86:7523, no serial
number). A second CH340, such as a PN532 board, gets the same
/dev/serial/by-id name, so neither port is safe to probe: CH340 ports are
only opened when [flsun_nfc] names one with device:."""

import logging

from ffnfc.lane_data import LaneData
from ffnfc.spoolman import is_bound
from ffnfc.tag import normalize_color
from ffnfc.transport.serial_port import usb_serial_ports

LOGGER = logging.getLogger("ff_nfc")

CH340_VID = "1a86"
# nginx serves the camera (mjpg-streamer) under /webcam/.
QR_URL = "http://127.0.0.1/webcam/?action=snapshot"
QR_WIDTH = 1024
# The [flsun_nfc] options only this platform reads.
OPTIONS = ("filament_sensor", "clear_active_spool")


class Ch340Excluded(list):
    """The configured excluded ports, plus every CH340 tty present at the
    moment the reader search iterates it (readers are looked for again
    every retry_interval, so a board plugged in later is skipped too)."""

    def __iter__(self):
        ports = list(list.__iter__(self))
        for path, vid, _pid, _product in usb_serial_ports():
            if vid == CH340_VID:
                ports.append(path)
        return iter(ports)


class FlsunPlatform(object):
    name = "flsun"
    lane_data_class = LaneData
    qr_url = QR_URL
    qr_width = QR_WIDTH

    def __init__(self, core, config):
        self.core = core
        self.printer = core.printer
        self.sensor_name = config.get("filament_sensor", "filament_sensor")
        self.clear_active_spool = config.getboolean("clear_active_spool", True)
        self.sensor = None
        self.current = {"material": "", "color": ""}

    def connect(self):
        pass

    def ready(self):
        self.sensor = self.printer.lookup_object(
            "filament_switch_sensor %s" % self.sensor_name, None)
        if not self.core.device and not isinstance(self.core.excluded_ports, Ch340Excluded):
            self.core.excluded_ports = Ch340Excluded(self.core.excluded_ports)

    def _loaded(self):
        helper = getattr(self.sensor, "runout_helper", None)
        return bool(getattr(helper, "filament_present", False))

    def slots(self):
        return {"toolchanger": False, "current": 1, "valid_types": [], "palette": [],
                "presence": False,
                "slots": {1: {"material": self.current["material"],
                              "color": self.current["color"],
                              "loaded": self._loaded()}}}

    def slot_label(self, slots, n):
        return "The toolhead"

    def slot_word(self, slots):
        return "toolhead"

    def assign(self, scan, slot_number, slots, label, respond, run_gcode):
        core = self.core
        spool = scan.spool
        material = scan.material() or ""
        color = normalize_color(scan.color()) or ""
        self.current = {"material": material, "color": color}
        core._write_lane_data(1, core._lane_info(scan, material or None, color or None))
        if spool is not None:
            core._set_active_spool(spool["id"])
            if core.bind_card_uid and scan.uid and core.spoolman is not None \
                    and not is_bound(spool, scan.uid):
                core._in_background(core.spoolman.bind_uid, spool, scan.uid, scan.tag_format)
            respond("NFC: %s now has %s (Spoolman spool %d, now the active spool)"
                    % (label, scan.title(), spool["id"]))
            return
        text = " ".join(p for p in (material, "#" + color if color else "") if p) or scan.title()
        if self.clear_active_spool:
            core._set_active_spool(None)
            respond("NFC: %s now has %s; not in Spoolman, so no spool is active"
                    % (label, text))
        else:
            respond("NFC: %s now has %s (not in Spoolman)" % (label, text))

    def status_lines(self):
        if self.sensor is None:
            return []
        return ["Filament sensor: %s" % ("filament present" if self._loaded() else "empty")]

    def qr_args(self):
        return []


def register():
    """Add this platform to the vendored FF_NFC core, which knows only zmod
    and kiln."""
    import sys
    from ffnfc import platforms
    platforms.MODULES["flsun"] = sys.modules[__name__]
    platforms.CLASSES["flsun"] = FlsunPlatform
