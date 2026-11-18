# Klipper extras entry point for FLSUN_NFC ([flsun_nfc]).
#
# install.sh links this file into Klipper's klippy/extras directory. The
# code lives in the repository (python/: the FF_NFC core in ffnfc and the
# FLSUN T1 platform in flsunnfc), found through this file's real path.
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import os
import sys

_PACKAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))),
                            "python")
if _PACKAGE_DIR not in sys.path:
    sys.path.insert(0, _PACKAGE_DIR)


def load_config(config):
    # Klipper keeps imported modules across RESTART. Drop the packages each
    # time so an update takes effect on the next RESTART.
    for name in list(sys.modules):
        for package in ("ffnfc", "flsunnfc"):
            if name == package or name.startswith(package + "."):
                del sys.modules[name]
    from flsunnfc import platform
    platform.register()
    from ffnfc import klipper_plugin
    return klipper_plugin.load_config(config, "flsun")
