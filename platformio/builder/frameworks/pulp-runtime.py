# Copyright 2014-present PlatformIO <contact@platformio.org>
# Copyright 2026 PULP Platform contributors
#
# SPDX-License-Identifier: Apache-2.0

import os

from SCons.Script import DefaultEnvironment


env = DefaultEnvironment()
platform = env.PioPlatform()
board_config = env.BoardConfig()
project_dir = env.subst("$PROJECT_DIR")
repo_root = env.GetProjectOption(
    "custom_pulpissimo_root", os.environ.get("PULPISSIMO_ROOT", "")
)
if repo_root:
    if not os.path.isabs(repo_root):
        repo_root = os.path.join(project_dir, repo_root)
    repo_root = os.path.abspath(repo_root)
else:
    repo_root = project_dir
    while repo_root != os.path.dirname(repo_root):
        if os.path.isfile(os.path.join(repo_root, "Bender.yml")):
            break
        repo_root = os.path.dirname(repo_root)

runtime_dir = os.path.join(repo_root, "sw", "pulp-runtime")

if not os.path.isfile(os.path.join(runtime_dir, "kernel", "crt0.S")):
    raise RuntimeError(
        "PULP runtime is unavailable; initialize the sw/pulp-runtime submodule"
    )

machine_flags = [
    "-march=%s" % board_config.get("build.march"),
    "-mabi=%s" % board_config.get("build.mabi"),
    "-mno-pulp-hwloop",
]

env.Append(
    ASFLAGS=machine_flags,
    ASPPFLAGS=machine_flags
    + [
        "-x",
        "assembler-with-cpp",
        "-DLANGUAGE_ASSEMBLY",
        "-include",
        "chips/pulpissimo/config.h",
    ],
    CCFLAGS=machine_flags
    + [
        "-Os",
        "-fdata-sections",
        "-ffunction-sections",
        "-fno-jump-tables",
        "-fno-tree-loop-distribute-patterns",
        "-include",
        "chips/pulpissimo/config.h",
        "-U__riscv__",
        "-UARCHI_CORE_HAS_PULPV2",
    ],
    CPPDEFINES=[
        "__cv32e40p__",
        ("__PLATFORM__", "ARCHI_PLATFORM_FPGA"),
        ("CONFIG_IO_UART", 1),
        ("CONFIG_IO_UART_BAUDRATE", 115200),
        ("CONFIG_IO_UART_ITF", 0),
    ],
    CPPPATH=[
        os.path.join(runtime_dir, "include", "chips", "pulpissimo"),
        os.path.join(runtime_dir, "include"),
        os.path.join(runtime_dir, "kernel"),
        os.path.join(runtime_dir, "drivers", "gpio", "include"),
        os.path.join(
            runtime_dir,
            "drivers",
            "pulpissimo",
            "rtl_sim",
            "io_mux",
            "include",
        ),
        os.path.join(runtime_dir, "lib", "libc", "minimal", "include"),
    ],
    LINKFLAGS=machine_flags
    + [
        "-nostartfiles",
        "-nostdlib",
        "-Wl,--gc-sections",
    ],
)

env.Replace(
    LDSCRIPT_PATH=os.path.join(runtime_dir, "kernel", "chips", "pulpissimo", "link.ld")
)

runtime_sources = [
    "kernel/crt0.S",
    "kernel/irq_asm.S",
    "kernel/init.c",
    "kernel/kernel.c",
    "kernel/alloc.c",
    "kernel/alloc_pool.c",
    "kernel/irq.c",
    "kernel/soc_event.c",
    "kernel/bench.c",
    "kernel/fll-v1.c",
    "kernel/freq-domains.c",
    "kernel/chips/pulpissimo/soc.c",
    "drivers/uart.c",
    "drivers/gpio/gpio.c",
    "lib/libc/minimal/io.c",
    "lib/libc/minimal/fprintf.c",
    "lib/libc/minimal/prf.c",
    "lib/libc/minimal/sprintf.c",
]

runtime = env.BuildLibrary(
    os.path.join("$BUILD_DIR", "pulp-runtime"),
    runtime_dir,
    src_filter=["-<*>"] + ["+<%s>" % source for source in runtime_sources],
)
compatibility = env.BuildLibrary(
    os.path.join("$BUILD_DIR", "pulp-runtime-compatibility"),
    os.path.join(platform.get_dir(), "builder", "frameworks", "pulp-runtime"),
)
env.Append(LIBS=[runtime, compatibility, "gcc"])
