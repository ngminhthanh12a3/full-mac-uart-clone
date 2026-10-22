#!/usr/bin/env python3
"""Keithley 2280S-32-6 core-voltage sweep and current logging.

SCPI commands checked against Keithley Series 2280 Reference Manual 077085503
(March 2019), especially sections 5.1 and 7.

Prerequisites:
    python -m pip install pyvisa pyvisa-py

Preview settings WITHOUT contacting the instrument:
    python keithley_2280s_lan_sweep.py \
        --ip 192.168.1.100 --voltages 0.9 1.0 1.1 \
        --max-voltage 1.1 --current-limit 0.02

Run ONLY after verifying the chip voltage and current limits, wiring,
power sequencing and I/O back-powering risks:
    python keithley_2280s_lan_sweep.py \
        --ip 192.168.1.100 --voltages 0.9 1.0 1.1 \
        --max-voltage 1.1 --current-limit 0.02 --run

192.168.1.100 is a placeholder. Substitute the actual Keithley IP address.
For old firmware try --port 5050 instead of the default 5025.

The numeric voltage and current values above are ILLUSTRATIVE ONLY.
Specify limits independently verified for the device under test.

The Keithley supplies pin 28 (UART_VDD) referenced to pin 26 (UART_VSS).
The script does NOT control the ADCMT 6541, global 1.8 V rails, external
clock, UART traffic, or reset. Coordinate safe sequencing externally.
"""

from __future__ import annotations

import argparse
import csv
from datetime import datetime
import math
from pathlib import Path
import re
import statistics
import sys
import time
from typing import Sequence

NUMBER_RE = re.compile(r"^\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?)")


def parse_number(value: str) -> float:
    """Parse a SCPI numeric field, optionally followed by units (e.g. 'A')."""
    match = NUMBER_RE.match(value)
    if match is None:
        raise ValueError(f"No numeric value in instrument response: {value!r}")
    result = float(match.group(1))
    if not math.isfinite(result):
        raise ValueError(f"Non-finite instrument response: {value!r}")
    return result


def parse_current_and_mode(response: str) -> tuple[float, str]:
    """Parse :READ? with :FORM:ELEM 'READ,MODE' (e.g. '+1.23E-03,CV')."""
    fields = response.strip().split(",")
    if len(fields) != 2:
        raise ValueError(
            "Expected two SCPI fields (READ,MODE), received " + repr(response)
        )
    current_a = parse_number(fields[0])
    mode = fields[1].strip().strip('"\'').upper()
    if mode not in {"CV", "CC", "OFF"}:
        raise ValueError(f"Unexpected supply mode {mode!r} in {response!r}")
    return current_a, mode


def check_scpi_errors(device, context: str) -> None:
    """Read and report instrument-side error queue entries."""
    errors: list[str] = []
    for _ in range(16):
        answer = device.query(":SYST:ERR?").strip()
        code = answer.split(",", 1)[0].strip()
        try:
            if int(code) == 0:
                break
        except ValueError:
            pass
        errors.append(answer)
    else:
        errors.append("SCPI error queue could not be fully drained")
    if errors:
        raise RuntimeError(f"Instrument errors after {context}: " + "; ".join(errors))


def check_parameters(args: argparse.Namespace) -> None:
    if not args.resource and not args.ip:
        raise ValueError("specify --ip or --resource")
    if not args.voltages:
        raise ValueError("--voltages requires one or more setpoints")
    if not (1 <= args.port <= 65535):
        raise ValueError("--port must be in 1..65535")
    if args.max_voltage is None or not math.isfinite(args.max_voltage):
        raise ValueError("--max-voltage must specify your verified chip voltage ceiling")
    if args.current_limit is None or not math.isfinite(args.current_limit):
        raise ValueError("--current-limit must specify your verified safe current limit")
    if not (0 < args.max_voltage <= 32):
        raise ValueError("--max-voltage must be >0 and <=32 V (instrument capability)")
    if not (0 < args.current_limit <= 6):
        raise ValueError("--current-limit must be >0 and <=6 A (instrument capability)")
    if any(not math.isfinite(v) or v <= 0 or v > args.max_voltage
           for v in args.voltages):
        raise ValueError("All voltage points must be >0 and <=--max-voltage")
    if args.samples < 1:
        raise ValueError("--samples must be at least 1")
    if args.settle < 0 or args.sample_interval < 0:
        raise ValueError("--settle and --sample-interval must be nonnegative")
    if not (0.002 <= args.nplc <= 12):
        raise ValueError("--nplc must be in [0.002, 12] (valid for 50/60 Hz)")


def configure_instrument(device, args: argparse.Namespace) -> None:
    # *RST removes unknown settings and turns output OFF. Do this only when
    # safe for the surrounding chip, supply domains, and test fixture.
    device.write("*RST")
    device.write("*CLS")
    device.write(":OUTP OFF")
    device.write(f":VOLT:LIM {args.max_voltage:.6f}")
    device.write(f":CURR {args.current_limit:.6f}")
    device.write(f":VOLT {args.voltages[0]:.6f}")
    device.write(':SENS:FUNC "CURR"')
    device.write(":SENS:CURR:RANG:AUTO ON")
    device.write(f":SENS:CURR:NPLC {args.nplc:.6f}")
    device.write(":SENS:CURR:AVER OFF")  # No filter spanning voltage points
    device.write(":SYST:AZER ON")       # Higher precision, slower readings
    device.write(':FORM:ELEM "READ,MODE"')
    device.write(":INIT:CONT OFF")
    check_scpi_errors(device, "initial configuration")
    # Verify programmable ceiling before applying the first voltage.
    limit_set = parse_number(device.query(":VOLT:LIM?"))
    if limit_set > args.max_voltage + 0.001:
        raise RuntimeError(
            f"Instrument voltage ceiling is {limit_set:g} V, "
            f"above configured max {args.max_voltage:g} V"
        )


def timestamp() -> str:
    return datetime.now().astimezone().isoformat(timespec="milliseconds")


def sweep(device, args: argparse.Namespace, identity: str) -> tuple[Path, Path]:
    prefix = Path(args.output_prefix)
    prefix.parent.mkdir(parents=True, exist_ok=True)
    raw_path = prefix.parent / (prefix.name + str(datetime.now()) +  "_raw.csv")
    summary_path = prefix.parent / (prefix.name + str(datetime.now())  + "_summary.csv")

    with raw_path.open("w", newline="", encoding="utf-8") as raw_file, \
         summary_path.open("w", newline="", encoding="utf-8") as summary_file:
        raw_writer = csv.DictWriter(raw_file, fieldnames=[
            "timestamp", "instrument_id", "voltage_set_V", "sample_index",
            "current_A", "current_mA", "estimated_core_power_mW", "mode"
        ])
        summary_writer = csv.DictWriter(summary_file, fieldnames=[
            "timestamp", "instrument_id", "voltage_set_V", "sample_count",
            "mean_current_A", "mean_current_mA", "std_current_mA",
            "min_current_mA", "max_current_mA", "estimated_mean_power_mW",
            "mode", "settle_s", "nplc"
        ])
        raw_writer.writeheader()
        summary_writer.writeheader()
        raw_file.flush()
        summary_file.flush()

        device.write(":OUTP ON")
        check_scpi_errors(device, "enabling output")
        for voltage in args.voltages:
            device.write(f":VOLT {voltage:.6f}")
            voltage_programmed = parse_number(device.query(":VOLT?"))
            if abs(voltage_programmed - voltage) > 0.002:
                raise RuntimeError(
                    f"Voltage setpoint mismatch: requested {voltage:g}, "
                    f"instrument reports {voltage_programmed:g} V"
                )
            check_scpi_errors(device, f"setting {voltage:g} V")
            time.sleep(args.settle)

            readings: list[float] = []
            for k in range(1, args.samples + 1):
                answer = device.query(":READ?")
                current_a, mode = parse_current_and_mode(answer)
                readings.append(current_a)
                raw_writer.writerow({
                    "timestamp": timestamp(),
                    "instrument_id": identity,
                    "voltage_set_V": f"{voltage:.6f}",
                    "sample_index": k,
                    "current_A": f"{current_a:.12g}",
                    "current_mA": f"{current_a * 1e3:.9g}",
                    # Nominal estimate using setpoint, NOT a voltage readback.
                    "estimated_core_power_mW": f"{voltage * current_a * 1e3:.9g}",
                    "mode": mode,
                })
                raw_file.flush()
                if mode != "CV":
                    raise RuntimeError(
                        f"Supply is in {mode} mode at {voltage:g} V; "
                        "nominal-voltage current reading is not valid. "
                        "Stop and inspect DUT current draw/current limit."
                    )
                if k < args.samples:
                    time.sleep(args.sample_interval)

            mean_a = statistics.mean(readings)
            std_a = statistics.stdev(readings) if len(readings) > 1 else 0.0
            summary_writer.writerow({
                "timestamp": timestamp(),
                "instrument_id": identity,
                "voltage_set_V": f"{voltage:.6f}",
                "sample_count": len(readings),
                "mean_current_A": f"{mean_a:.12g}",
                "mean_current_mA": f"{mean_a * 1e3:.9g}",
                "std_current_mA": f"{std_a * 1e3:.9g}",
                "min_current_mA": f"{min(readings) * 1e3:.9g}",
                "max_current_mA": f"{max(readings) * 1e3:.9g}",
                "estimated_mean_power_mW": f"{voltage * mean_a * 1e3:.9g}",
                "mode": "CV",
                "settle_s": args.settle,
                "nplc": args.nplc,
            })
            summary_file.flush()
            print(f"{voltage:7.3f} V | {mean_a * 1e3:11.6f} mA "
                  f"+/- {std_a * 1e3:.6f} mA | "
                  f"estimated {voltage * mean_a * 1e3:.6f} mW | CV")
    return raw_path, summary_path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Keithley 2280S-32-6 SCPI voltage sweep with current logging"
    )
    parser.add_argument("--list", action="store_true", help="List VISA resources and exit")
    parser.add_argument("--resource", help="Explicit VISA resource, overrides --ip and --port")
    parser.add_argument("--ip", help="LAN IP address of the Keithley (not the PC)")
    parser.add_argument("--port", type=int, default=5025,
                        help="Raw TCP port: normally 5025; older firmware 5050")
    parser.add_argument("--backend", default="@py",
                        help="VISA backend, default @py (pyvisa-py)")
    parser.add_argument("--voltages", nargs="+", type=float,
                        help="One or more DUT-validated voltage setpoints in V")
    parser.add_argument("--max-voltage", type=float, help="DUT-validated maximum source voltage in V")
    parser.add_argument("--current-limit", type=float, help="DUT-validated output current limit in A")
    parser.add_argument("--settle", type=float, default=2.0,
                        help="Wait in seconds after each voltage change (default: 2)")
    parser.add_argument("--samples", type=int, default=5,
                        help="Current measurements at each voltage (default: 5)")
    parser.add_argument("--sample-interval", type=float, default=0.2,
                        help="Wait in seconds between current readings (default: 0.2)")
    parser.add_argument("--nplc", type=float, default=1.0,
                        help="Power-line cycles per reading (default: 1)")
    parser.add_argument("--output-prefix", default="keithley_core_sweep",
                        help="Prefix for *_raw.csv and *_summary.csv")
    parser.add_argument("--run", action="store_true",
                        help="Actually communicate with DUT and ENABLE PSU output")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.list:
        try:
            import pyvisa
            rm = pyvisa.ResourceManager(args.backend)
            try:
                for resource in rm.list_resources():
                    print(resource)
            finally:
                rm.close()
            return 0
        except Exception as exc:
            print(f"Could not enumerate VISA resources: {exc}", file=sys.stderr)
            return 1

    try:
        check_parameters(args)
    except ValueError as exc:
        parser.error(str(exc))

    print("Planned voltage points:", ", ".join(f"{v:g} V" for v in args.voltages))
    print(f"Maximum permitted voltage: {args.max_voltage:g} V")
    print(f"Current limit: {args.current_limit:g} A")
    print(f"Samples per point: {args.samples}, NPLC: {args.nplc:g}, "
          f"settle: {args.settle:g} s")
    print("CAUTION: This does not sequence the ADCMT supply, UART, reset or clock.")
    if not args.run:
        print("PREVIEW ONLY: Output remains untouched. Add --run to execute.")
        return 0

    device = None
    manager = None
    verified = False
    try:
        import pyvisa
        manager = pyvisa.ResourceManager(args.backend)
        address = args.resource or f"TCPIP0::{args.ip}::{args.port}::SOCKET"
        print("LAN VISA resource:", address)
        device = manager.open_resource(address)
        device.timeout = 10000
        device.write_termination = "\n"
        device.read_termination = "\n"
        identity = device.query("*IDN?").strip()
        print("Connected:", identity)
        if "2280S-32-6" not in identity.upper():
            raise RuntimeError("Expected Keithley 2280S-32-6; refusing to control " + identity)
        verified = True
        configure_instrument(device, args)
        raw_path, summary_path = sweep(device, args, identity)
        print(f"Raw CSV: {raw_path.resolve()}")
        print(f"Summary CSV: {summary_path.resolve()}")
        return 0
    except (Exception, KeyboardInterrupt) as exc:
        print(f"SWEEP STOPPED: {exc}", file=sys.stderr)
        return 1
    finally:
        if device is not None:
            if verified:
                try:
                    device.write(":OUTP OFF")
                    print("Keithley output disabled (:OUTP OFF).")
                except Exception as exc:
                    print("WARNING: Could not confirm output OFF. "
                          f"Check the front panel manually: {exc}", file=sys.stderr)
            try:
                device.close()
            except Exception:
                pass
        if manager is not None:
            try:
                manager.close()
            except Exception:
                pass


if __name__ == "__main__":
    raise SystemExit(main())
