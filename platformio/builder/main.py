# Copyright 2014-present PlatformIO <contact@platformio.org>
# Copyright 2026 PULP Platform contributors
#
# SPDX-License-Identifier: Apache-2.0

import os
import shutil
import socket
import subprocess
import threading

from SCons.Script import (
    AlwaysBuild,
    Builder,
    Default,
    DefaultEnvironment,
)


env = DefaultEnvironment()
platform = env.PioPlatform()
board_config = env.BoardConfig()


def _get_pulpissimo_root():
    project_dir = env.subst("$PROJECT_DIR")
    root = env.GetProjectOption(
        "custom_pulpissimo_root", os.environ.get("PULPISSIMO_ROOT", "")
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


repo_root = _get_pulpissimo_root()


def _tool_from_prefix(option, environment_names, executable):
    prefix = env.GetProjectOption(option, "")
    if not prefix:
        for name in environment_names:
            prefix = os.environ.get(name, "")
            if prefix:
                break
    if prefix:
        if os.path.isdir(prefix):
            candidate = os.path.join(prefix, "bin", executable)
        elif os.path.isfile(prefix) or os.sep not in prefix:
            candidate = prefix
        else:
            raise RuntimeError("Cannot find %s at %s" % (executable, prefix))
        return candidate
    return executable


toolchain_prefix = env.GetProjectOption("custom_toolchain", "")
if not toolchain_prefix:
    toolchain_prefix = os.environ.get(
        "PULP_RISCV_GCC_TOOLCHAIN_CI",
        os.environ.get("PULP_RISCV_GCC_TOOLCHAIN", ""),
    )


def _toolchain_executable(name):
    if not toolchain_prefix:
        return name
    candidate = os.path.join(toolchain_prefix, "bin", name)
    if not os.path.isfile(candidate):
        raise RuntimeError("Cannot find %s at %s" % (name, candidate))
    return candidate


env.Replace(
    AR=_toolchain_executable("riscv32-unknown-elf-gcc-ar"),
    AS=_toolchain_executable("riscv32-unknown-elf-as"),
    CC=_toolchain_executable("riscv32-unknown-elf-gcc"),
    CXX=_toolchain_executable("riscv32-unknown-elf-g++"),
    GDB=_toolchain_executable("riscv32-unknown-elf-gdb"),
    OBJCOPY=_toolchain_executable("riscv32-unknown-elf-objcopy"),
    OBJDUMP=_toolchain_executable("riscv32-unknown-elf-objdump"),
    RANLIB=_toolchain_executable("riscv32-unknown-elf-gcc-ranlib"),
    SIZETOOL=_toolchain_executable("riscv32-unknown-elf-size"),
    ARFLAGS=["rc"],
    PROGNAME="firmware",
    PROGSUFFIX=".elf",
    SIZEPRINTCMD="$SIZETOOL -d $SOURCES",
)

env.Append(
    BUILDERS={
        "ElfToBin": Builder(
            action=env.VerboseAction(
                "$OBJCOPY -O binary $SOURCE $TARGET", "Building $TARGET"
            ),
            suffix=".bin",
        )
    }
)

frameworks = env.get("PIOFRAMEWORK", [])
if frameworks != ["pulp-runtime"]:
    raise RuntimeError("The PULPissimo platform requires framework = pulp-runtime")

target_elf = env.BuildProgram()
target_bin = env.ElfToBin(os.path.join("$BUILD_DIR", "firmware"), target_elf)
target_dis = env.Command(
    os.path.join("$BUILD_DIR", "firmware.dis"),
    target_elf,
    env.VerboseAction("$OBJDUMP -d $SOURCE > $TARGET", "Generating $TARGET"),
)
target_build = env.Alias("buildprog", [target_elf, target_bin, target_dis])

target_size = env.AddPlatformTarget(
    "size",
    target_elf,
    env.VerboseAction("$SIZEPRINTCMD", "Calculating size $SOURCE"),
    "Program Size",
    "Calculate program size",
)


def _program_bitstream(target, source, env):
    xc3sprog = _tool_from_prefix("custom_xc3sprog", ("XC3SPROG",), "xc3sprog")
    resolved = shutil.which(xc3sprog, path=env["ENV"].get("PATH"))
    if not resolved:
        raise RuntimeError("Cannot find xc3sprog; set XC3SPROG or add it to PATH")
    subprocess.run([resolved, "-c", "nexys4", source[0].get_abspath()], check=True)


bitstream = env.GetProjectOption("custom_bitstream", "")
if bitstream:
    if not os.path.isabs(bitstream):
        bitstream = os.path.join(env.subst("$PROJECT_DIR"), bitstream)
else:
    bitstream = board_config.get("upload.bitstream_file")
    if not os.path.isabs(bitstream):
        bitstream = os.path.join(repo_root, bitstream)

target_bitstream = env.AddPlatformTarget(
    "upload_bitstream",
    env.File(bitstream),
    env.VerboseAction(_program_bitstream, "Programming $SOURCE"),
    "Upload Bitstream",
    "Program the Arty FPGA through the onboard Digilent JTAG adapter",
)
AlwaysBuild(target_bitstream)


def _unused_local_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def _capture_openocd_output(process, log_file, ready, gdb_port):
    ready_message = ("Listening on port %d for gdb connections" % gdb_port).encode()
    for line in iter(process.stdout.readline, b""):
        log_file.write(line.decode("utf-8", "replace"))
        log_file.flush()
        if ready_message in line:
            ready.set()


def _upload_firmware(target, source, env):
    openocd = _tool_from_prefix("custom_openocd", ("OPENOCD",), "openocd")
    openocd = shutil.which(openocd, path=env["ENV"].get("PATH"))
    if not openocd:
        raise RuntimeError("Cannot find OpenOCD; set OPENOCD or add it to PATH")

    gdb = env.subst("$GDB")
    gdb = shutil.which(gdb, path=env["ENV"].get("PATH")) or gdb
    openocd_config = os.path.join(
        repo_root,
        "target",
        "fpga",
        "pulpissimo-arty",
        "openocd-arty-olimex.cfg",
    )
    log_path = os.path.join(env.subst("$BUILD_DIR"), "openocd-upload.log")
    gdb_port = _unused_local_port()

    with open(log_path, "w", encoding="utf-8") as log_file:
        process = subprocess.Popen(
            [
                openocd,
                "-c",
                "gdb_port %d" % gdb_port,
                "-c",
                "tcl_port disabled",
                "-c",
                "telnet_port disabled",
                "-f",
                openocd_config,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        ready = threading.Event()
        reader = threading.Thread(
            target=_capture_openocd_output,
            args=(process, log_file, ready, gdb_port),
        )
        reader.daemon = True
        reader.start()
        try:
            if not ready.wait(30):
                raise RuntimeError(
                    "OpenOCD did not open GDB port %d; see %s"
                    % (gdb_port, log_path)
                )
            subprocess.run(
                [
                    gdb,
                    "--batch",
                    "-ex",
                    "target remote localhost:%d" % gdb_port,
                    "-ex",
                    "monitor halt",
                    "-ex",
                    "load",
                    "-ex",
                    "set $pc = _start",
                    "-ex",
                    "monitor resume",
                    "-ex",
                    "detach",
                    source[0].get_abspath(),
                ],
                check=True,
            )
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            reader.join(timeout=5)


target_upload = env.AddPlatformTarget(
    "upload",
    target_elf,
    env.VerboseAction(_upload_firmware, "Uploading $SOURCE"),
    "Upload",
    "Load and run the ELF through the Olimex PULPissimo JTAG connection",
)
AlwaysBuild(target_upload)

Default([target_build, target_size])
