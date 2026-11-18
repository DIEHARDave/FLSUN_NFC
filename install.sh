#!/bin/bash
# FLSUN_NFC installer for the FLSun T1 / T1 Pro.
# Run as the pi user from the cloned repo: ~/FLSUN_NFC/install.sh
# Safe to re-run, e.g. after a FLSun firmware update.

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/printer_data/config"
PRINTER_CFG="${CONFIG_DIR}/printer.cfg"
MOONRAKER_CONF="${CONFIG_DIR}/moonraker.conf"
UDEV_RULE="/etc/udev/rules.d/99-flsun-nfc.rules"
INCLUDE="[include flsun_nfc.cfg]"
SAVE_MARK="#*# <---------------------- SAVE_CONFIG ---------------------->"

msg() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "run as the pi user, not root (sudo is used where needed)"
# The Klipper links point into this path.
[ "$REPO_DIR" = "${HOME}/FLSUN_NFC" ] \
    || die "clone the repo to ${HOME}/FLSUN_NFC (it is at $REPO_DIR)"
[ -f "$PRINTER_CFG" ] || die "$PRINTER_CFG not found"
[ -f "$MOONRAKER_CONF" ] || die "$MOONRAKER_CONF not found"

msg "Linking the Klipper module"
linked=0
# Upstream Klipper (FLSUN_klipper) and FLSun's own; printer.cfg is shared,
# so both need the module.
for klipper in "${HOME}/klipper-upstream" "${HOME}/klipper"; do
    extras="${klipper}/klippy/extras"
    [ -d "$extras" ] || continue
    ln -sfn "${REPO_DIR}/extras/flsun_nfc.py" "${extras}/flsun_nfc.py"
    linked=1
    # Keeps Moonraker from calling a Klipper git checkout dirty.
    exclude="${klipper}/.git/info/exclude"
    if [ -d "$(dirname "$exclude")" ] && ! grep -qx "klippy/extras/flsun_nfc.py" "$exclude" 2> /dev/null; then
        echo "klippy/extras/flsun_nfc.py" >> "$exclude"
    fi
done
[ "$linked" = 1 ] || die "no Klipper found in ${HOME}/klipper-upstream or ${HOME}/klipper"

msg "Including flsun_nfc.cfg in printer.cfg"
ln -sfn "${REPO_DIR}/flsun_nfc.cfg" "${CONFIG_DIR}/flsun_nfc.cfg"
if ! grep -qF "$INCLUDE" "$PRINTER_CFG"; then
    cp "$PRINTER_CFG" "${PRINTER_CFG}.flsun_nfc.bak"
    # Above the SAVE_CONFIG block, which must stay last.
    awk -v inc="$INCLUDE" -v mark="$SAVE_MARK" '
        !done && index($0, mark) == 1 { print inc; print ""; done = 1 }
        { print }
        END { if (!done) { print ""; print inc } }' "${PRINTER_CFG}.flsun_nfc.bak" > "$PRINTER_CFG"
fi

msg "Giving Klipper (user pi) access to USB readers"
sudo install -m 644 "${REPO_DIR}/system/99-flsun-nfc.rules" "$UDEV_RULE"
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --action=add
for group in dialout plugdev; do
    id -nG | tr ' ' '\n' | grep -qx "$group" || sudo usermod -aG "$group" "$USER"
done

msg "Adding the Moonraker update manager entry"
if [ ! -f "${CONFIG_DIR}/flsun_nfc.conf" ]; then
    cp "${REPO_DIR}/config/flsun_nfc.conf" "${CONFIG_DIR}/flsun_nfc.conf"
fi
if ! grep -q '^\[include flsun_nfc\.conf\]' "$MOONRAKER_CONF"; then
    cp "$MOONRAKER_CONF" "${MOONRAKER_CONF}.flsun_nfc.bak"
    printf '\n[include flsun_nfc.conf]\n' >> "$MOONRAKER_CONF"
fi

msg "Restarting Moonraker and Klipper"
sudo systemctl restart moonraker
state=$(curl -s -m 5 "http://127.0.0.1:7125/printer/objects/query?print_stats=state" \
    | sed -n 's/.*"state": *"\([a-z]*\)".*/\1/p')
case "$state" in
    printing|paused) echo "A print is $state; FLSUN_NFC starts at Klipper's next restart." ;;
    # Not RESTART: upstream Klipper reads printer.cfg's includes in its
    # service's ExecStartPre (FLSUN_klipper).
    *) sudo systemctl restart klipper ;;
esac

msg "Done. Plug in a reader and run NFC_STATUS in the console."
