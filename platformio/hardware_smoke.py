#!/usr/bin/env python3

# Copyright 2026 PULP Platform contributors
# SPDX-License-Identifier: Apache-2.0

import argparse
import fcntl
import os
import select
import shlex
import signal
import subprocess
import sys
import termios
import tempfile
import time
import tty


TESTS = (
    {
        "name": "hello",
        "expected": b"Hello !\n",
    },
    {
        "name": "gpio-blink",
        "expected": b"GPIO blink complete\n",
    },
    {
        "name": "uart-echo",
        "prompt": b"enter q to quit.\n",
        "send": b"abcq",
        "expected": b"abcq\nUART echo complete\n",
    },
    {
        "name": "uart-buffered",
        "prompt": b"returned as one block.\n",
        "send": b"0123456789abcdef0123456789abcdef",
        "expected": (
            b"0123456789abcdef0123456789abcdef\n"
            b"Buffered UART transfer PASS\n"
        ),
    },
    {
        "name": "performance",
        "expected": b"Result             PASS\n",
    },
    {
        "name": "performance-events",
        "expected": b"Performance event sweep PASS\n",
    },
    {
        "name": "timer-interrupt",
        "expected": b"Received 5 timer interrupts\nTimer interrupt test PASS\n",
    },
    {
        "name": "memory-benchmark",
        "expected": b"Memory benchmark PASS\n",
    },
)


def configure_serial(port):
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        tty.setraw(fd, termios.TCSANOW)
        attributes = termios.tcgetattr(fd)
        attributes[0] &= ~(
            termios.IGNCR
            | termios.ICRNL
            | termios.INLCR
            | termios.IXON
            | termios.IXOFF
            | termios.IXANY
        )
        attributes[2] |= termios.CLOCAL | termios.CREAD
        attributes[2] &= ~(termios.HUPCL | termios.CSTOPB | termios.PARENB)
        if hasattr(termios, "CRTSCTS"):
            attributes[2] &= ~termios.CRTSCTS
        attributes[4] = termios.B115200
        attributes[5] = termios.B115200
        termios.tcsetattr(fd, termios.TCSANOW, attributes)
        if hasattr(termios, "TIOCEXCL"):
            fcntl.ioctl(fd, termios.TIOCEXCL)
    except Exception:
        os.close(fd)
        raise
    return fd


def write_all(fd, data, deadline):
    offset = 0
    while offset < len(data):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError("timed out while writing UART test data")
        _, writable, _ = select.select([], [fd], [], min(remaining, 0.1))
        if writable:
            offset += os.write(fd, data[offset:])


def upload_command(pio, project):
    return shlex.split(pio) + [
        "run",
        "--project-dir",
        project,
        "--target",
        "upload",
    ]


def stop_process_group(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        process.poll()
        return

    if process.poll() is None:
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass

    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        try:
            os.killpg(process.pid, 0)
        except ProcessLookupError:
            process.poll()
            return
        time.sleep(0.05)

    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        process.poll()
        return
    if process.poll() is None:
        process.wait(timeout=5)
    else:
        process.poll()


def run_test(root, fd, pio, test, timeout):
    project = os.path.join(root, "platformio", "examples", test["name"])
    command = upload_command(pio, project)
    output = bytearray()
    sent = "send" not in test
    passed = False
    test_error = None
    deadline = time.monotonic() + timeout

    try:
        termios.tcflush(fd, termios.TCIFLUSH)
    except OSError as error:
        print("[FAIL] %s: cannot flush UART: %s" % (test["name"], error))
        return False

    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as upload_log:
        try:
            process = subprocess.Popen(
                command,
                cwd=root,
                stdout=upload_log,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                start_new_session=True,
            )
        except OSError as error:
            print("[FAIL] %s: %s" % (test["name"], error))
            return False

        try:
            try:
                while time.monotonic() < deadline:
                    readable, _, _ = select.select([fd], [], [], 0.05)
                    if readable:
                        try:
                            output.extend(os.read(fd, 4096))
                        except BlockingIOError:
                            pass

                    if not sent and test["prompt"] in output:
                        write_all(fd, test["send"], deadline)
                        sent = True

                    if sent and test["expected"] in output:
                        passed = True
                        break

                    if process.poll() not in (None, 0):
                        break
            except (OSError, RuntimeError) as error:
                test_error = error

            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                stop_process_group(process)
        finally:
            stop_process_group(process)

        upload_log.seek(0)
        upload_output = upload_log.read()

    if process.returncode != 0 or not passed or test_error is not None:
        print("[FAIL] %s" % test["name"])
        if test_error is not None:
            print("UART error: %s" % test_error)
        if output:
            print(output.decode("utf-8", "replace"), end="")
        if upload_output:
            print(upload_output, end="")
        return False

    print("[PASS] %s" % test["name"])
    return True


def program_bitstream(root, pio, timeout):
    project = os.path.join(root, "platformio", "examples", "hello")
    command = shlex.split(pio) + [
        "run",
        "--project-dir",
        project,
        "--target",
        "upload_bitstream",
    ]
    process = subprocess.Popen(command, cwd=root, start_new_session=True)
    try:
        try:
            returncode = process.wait(timeout=max(timeout, 120))
        except subprocess.TimeoutExpired:
            stop_process_group(process)
            raise RuntimeError("FPGA programming timed out")
    finally:
        stop_process_group(process)
    if returncode != 0:
        raise subprocess.CalledProcessError(returncode, command)


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Run PULPissimo PlatformIO hardware smoke tests"
    )
    parser.add_argument(
        "--port",
        default=os.environ.get("UART_PORT", ""),
        help="Digilent USB-UART device (or set UART_PORT)",
    )
    parser.add_argument(
        "--pio",
        default=os.environ.get("PIO", "pio"),
        help="PlatformIO Core command",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=30,
        help="per-example timeout in seconds",
    )
    parser.add_argument(
        "--example",
        action="append",
        choices=[test["name"] for test in TESTS],
        help="run only this example; may be repeated",
    )
    parser.add_argument(
        "--upload-bitstream",
        action="store_true",
        help="program the FPGA before running tests",
    )
    return parser.parse_args()


def main():
    args = parse_arguments()
    if not args.port:
        print("error: set UART_PORT or pass --port", file=sys.stderr)
        return 2
    if not os.path.exists(args.port):
        print("error: UART port does not exist: %s" % args.port, file=sys.stderr)
        return 2

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    selected = set(args.example or [])
    tests = [test for test in TESTS if not selected or test["name"] in selected]

    if args.upload_bitstream:
        try:
            program_bitstream(root, args.pio, args.timeout)
        except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
            print("error: FPGA programming failed: %s" % error, file=sys.stderr)
            return 1

    try:
        fd = configure_serial(args.port)
    except OSError as error:
        print("error: cannot configure UART: %s" % error, file=sys.stderr)
        return 2
    try:
        failures = sum(
            not run_test(root, fd, args.pio, test, args.timeout)
            for test in tests
        )
    finally:
        os.close(fd)

    print("%d/%d hardware smoke tests passed" % (len(tests) - failures, len(tests)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
