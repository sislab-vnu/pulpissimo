# Copyright 2014-present PlatformIO <contact@platformio.org>
# Copyright 2026 PULP Platform contributors
#
# SPDX-License-Identifier: Apache-2.0

import os

from platformio.public import PlatformBase


class PulpissimoPlatform(PlatformBase):
    def is_embedded(self):
        return True

    def _get_pulpissimo_root(self):
        project_dir = os.path.dirname(self.config.path)
        root = os.environ.get("PULPISSIMO_ROOT", "")
        if self.project_env:
            root = self.config.get(
                "env:%s" % self.project_env, "custom_pulpissimo_root", root
            )
        if root:
            if not os.path.isabs(root):
                root = os.path.join(project_dir, root)
            return os.path.abspath(root)

        candidate = project_dir
        while candidate != os.path.dirname(candidate):
            if os.path.isfile(os.path.join(candidate, "Bender.yml")):
                return candidate
            candidate = os.path.dirname(candidate)
        raise RuntimeError(
            "Cannot locate PULPissimo; set custom_pulpissimo_root or PULPISSIMO_ROOT"
        )

    def get_boards(self, id_=None):
        result = super().get_boards(id_)
        if not result:
            return result
        if id_:
            return self._add_arty_debug_tool(result)
        for board_id in result:
            result[board_id] = self._add_arty_debug_tool(result[board_id])
        return result

    def _add_arty_debug_tool(self, board):
        if board.id != "pulpissimo_arty_a7_100t":
            return board

        openocd = os.environ.get("OPENOCD", "")
        if self.project_env:
            openocd = self.config.get(
                "env:%s" % self.project_env, "custom_openocd", openocd
            )
        project_dir = os.path.dirname(self.config.path)
        if openocd and not os.path.isabs(openocd) and os.sep in openocd:
            openocd = os.path.abspath(os.path.join(project_dir, openocd))
        if openocd and os.path.isdir(openocd):
            openocd = os.path.join(openocd, "bin", "openocd")
        elif not openocd:
            openocd = "openocd"

        repo_root = self._get_pulpissimo_root()
        openocd_config = os.path.join(
            repo_root,
            "target",
            "fpga",
            "pulpissimo-arty",
            "openocd-arty-olimex.cfg",
        )

        debug = board.manifest.setdefault("debug", {})
        tools = debug.setdefault("tools", {})
        tools["olimex-arm-usb-ocd-h"] = {
            "default": True,
            "init_cmds": [
                "define pio_reset_halt_target",
                "  monitor halt",
                "  $LOAD_CMDS",
                "  set $pc = _start",
                "end",
                "define pio_reset_run_target",
                "  pio_reset_halt_target",
                "  monitor resume",
                "end",
                "set mem inaccessible-by-default off",
                "set arch riscv:rv32",
                "set remotetimeout 250",
                "target extended-remote $DEBUG_PORT",
                "pio_reset_halt_target",
                "$INIT_BREAK",
            ],
            "load_cmds": ["load"],
            "server": {
                "executable": openocd,
                "arguments": ["-f", openocd_config],
            },
        }
        return board
