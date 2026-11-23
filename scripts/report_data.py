#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
"""Turn the traces that Run42 recorded into the data of the report: key figures, and one plot per case.

It reads build/traces/<case>/*.csv (written by scripts/verify.sh) and the design parameters from the model, and writes
build/results.md and build/figures/<case>.svg, which model/80_documents/Documents.sysml includes. Nothing here is
committed: CI regenerates it from the traces on every run. Standard library only.
"""
from __future__ import annotations

import csv
import math
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BUILD = REPO / "build"
KELVIN = 273.15
TEAL, ORANGE, GREY, BAND = "#0b7181", "#963d15", "#5b7280", "#dbeff2"


def read_trace(case: str) -> dict[str, list[float]]:
    files = sorted((BUILD / "traces" / case).glob("*.csv"))
    if not files:
        sys.exit(f"no trace for {case}: run scripts/verify.sh first")
    with files[0].open() as handle:
        rows = list(csv.DictReader(handle))
    return {name: [float(row[name]) for row in rows] for name in rows[0]}


def celsius(values):
    return [v - KELVIN for v in values]


def first_time(times, values, predicate):
    for t, v in zip(times, values):
        if predicate(v):
            return t
    return None


def parameters() -> list[tuple[str, str, str]]:
    """The design parameters, read from the model so the report cannot disagree with it."""
    sysml = (REPO / "model" / "CupWarmer.sysml").read_text()
    modelica = (REPO / "model" / "Warmer.mo").read_text()

    def sysml_default(name):
        return re.search(rf"attribute {name} : \w+ default = ([0-9.]+) \[([^\]]+)\]", sysml).groups()

    def modelica_default(name):
        return re.search(rf"parameter Real {name}\(unit=\"([^\"]+)\"\) = ([0-9.]+)", modelica).groups()[::-1]

    power, power_unit = sysml_default("heaterPower")
    capacity, capacity_unit = sysml_default("capacity")
    loss, loss_unit = modelica_default("loss")
    ambient, ambient_unit = modelica_default("ambient")
    return [
        ("Heater power", power, power_unit),
        ("Heat capacity of plate and cup", capacity, capacity_unit.replace(" ", "")),
        ("Heat loss to the air", loss, loss_unit),
        ("Ambient temperature", f"{float(ambient) - KELVIN:.0f}", "degC"),
        ("Thermostat band", "60 to 65", "degC"),
        ("Cutout temperature", "85", "degC"),
    ]


# ---------------------------------------------------------------------------------------------------------- plotting
def nice_ticks(low, high, count=6):
    step = (high - low) / count
    magnitude = 10 ** math.floor(math.log10(step))
    for factor in (1, 2, 5, 10):
        if factor * magnitude >= step:
            step = factor * magnitude
            break
    first = math.ceil(low / step) * step
    ticks, value = [], first
    while value <= high + 1e-9:
        ticks.append(round(value, 6))
        value += step
    return ticks


def chart(title, series, x_range, y_range, y_label, hlines=(), vlines=(), band=None, notes=()):
    """An SVG line chart. series: (label, colour, xs, ys, dashed); hlines/vlines: (value, label, colour)."""
    width, height = 760, 360
    left, right, top, bottom = 62, 150, 38, 48
    plot_w, plot_h = width - left - right, height - top - bottom
    x0, x1 = x_range
    y0, y1 = y_range

    def px(x):
        return left + (x - x0) / (x1 - x0) * plot_w

    def py(y):
        return top + plot_h - (y - y0) / (y1 - y0) * plot_h

    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" role="img" aria-labelledby="t">',
        "  <!-- SPDX-FileCopyrightText: 2026 Elan8 -->",
        "  <!-- SPDX-License-Identifier: MIT -->",
        f'  <title id="t">{title}</title>',
        f'  <rect width="{width}" height="{height}" fill="#fff"/>',
        '  <g font-family="DejaVu Sans, Arial, sans-serif" font-size="12" fill="#173143">',
        f'    <text x="{left}" y="22" font-size="15" font-weight="700">{title}</text>',
    ]
    if band:
        out.append(f'    <rect x="{left}" y="{py(band[1]):.1f}" width="{plot_w}" height="{py(band[0]) - py(band[1]):.1f}" fill="{BAND}"/>')
    for tick in nice_ticks(y0, y1):
        out.append(f'    <line x1="{left}" x2="{left + plot_w}" y1="{py(tick):.1f}" y2="{py(tick):.1f}" stroke="#e3eaee"/>')
        out.append(f'    <text x="{left - 8}" y="{py(tick) + 4:.1f}" text-anchor="end">{tick:g}</text>')
    for tick in nice_ticks(x0, x1):
        out.append(f'    <line x1="{px(tick):.1f}" x2="{px(tick):.1f}" y1="{top}" y2="{top + plot_h}" stroke="#eef3f5"/>')
        out.append(f'    <text x="{px(tick):.1f}" y="{top + plot_h + 18}" text-anchor="middle">{tick:g}</text>')
    out.append(f'    <text x="{left + plot_w / 2}" y="{height - 8}" text-anchor="middle">Time (s)</text>')
    out.append(f'    <text transform="translate(16 {top + plot_h / 2}) rotate(-90)" text-anchor="middle">{y_label}</text>')
    out.append(f'    <rect x="{left}" y="{top}" width="{plot_w}" height="{plot_h}" fill="none" stroke="#9fb3bd"/>')
    for value, label, colour in hlines:
        out.append(f'    <line x1="{left}" x2="{left + plot_w}" y1="{py(value):.1f}" y2="{py(value):.1f}" stroke="{colour}" stroke-dasharray="6 4"/>')
        out.append(f'    <text x="{left + plot_w + 6}" y="{py(value) + 4:.1f}" fill="{colour}">{label}</text>')
    for value, label, colour in vlines:
        out.append(f'    <line x1="{px(value):.1f}" x2="{px(value):.1f}" y1="{top}" y2="{top + plot_h}" stroke="{colour}" stroke-dasharray="6 4"/>')
        out.append(f'    <text x="{px(value) - 4:.1f}" y="{top + 12}" text-anchor="end" fill="{colour}">{label}</text>')
    for label, colour, xs, ys, dashed in series:
        points = " ".join(f"{px(x):.1f},{py(y):.1f}" for x, y in zip(xs, ys))
        dash = ' stroke-dasharray="5 4"' if dashed else ""
        out.append(f'    <polyline points="{points}" fill="none" stroke="{colour}" stroke-width="2"{dash}/>')
    for index, (label, colour, _, _, dashed) in enumerate(series):
        y = height - bottom - 22 - index * 18
        dash = ' stroke-dasharray="5 4"' if dashed else ""
        out.append(f'    <line x1="{left + plot_w + 6}" x2="{left + plot_w + 30}" y1="{y}" y2="{y}" stroke="{colour}" stroke-width="2"{dash}/>')
        out.append(f'    <text x="{left + plot_w + 36}" y="{y + 4}">{label}</text>')
    for index, note in enumerate(notes):
        out.append(f'    <text x="{left + 8}" y="{top + plot_h - 10 - index * 16}" fill="{GREY}">{note}</text>')
    out += ["  </g>", "</svg>", ""]
    return "\n".join(out)


def main() -> int:
    (BUILD / "figures").mkdir(parents=True, exist_ok=True)

    # CW-001: warming up
    w = read_trace("warms-up")
    wt, wp = w["t"], celsius(w["plate.temperature"])
    reach = first_time(wt, wp, lambda v: v >= 62.0)
    (BUILD / "figures" / "warms-up.svg").write_text(chart(
        "Warming up: plate temperature", [("Plate", TEAL, wt, wp, False)], (0, 300), (15, 80), "Temperature (degC)",
        hlines=[(62.0, "62 degC target", ORANGE)], vlines=[(300, "300 s limit", ORANGE)],
        notes=[f"Reaches 62 degC at {reach:.0f} s"] if reach is not None else ["Does not reach 62 degC"]))

    # CW-002: holding
    h = read_trace("holds-temperature")
    ht, hp = h["t"], celsius(h["probe.reading"])
    warmed = first_time(ht, hp, lambda v: v >= 62.0)
    after = [v for t, v in zip(ht, hp) if warmed is not None and t >= warmed]
    hold_low, hold_high = (min(after), max(after)) if after else (float("nan"),) * 2
    (BUILD / "figures" / "holds-temperature.svg").write_text(chart(
        "Holding: plate temperature under the thermostat", [("Plate", TEAL, ht, hp, False)], (0, 900), (15, 80),
        "Temperature (degC)", hlines=[(67.0, "67 degC", ORANGE), (58.0, "58 degC", ORANGE)], band=(58.0, 67.0),
        notes=[f"After warm-up: {hold_low:.1f} to {hold_high:.1f} degC"]))

    # CW-003: sensor fault
    f = read_trace("sensor-fault")
    ft, fplate, fsensor, fcommand = f["t"], celsius(f["plate.temperature"]), celsius(f["probe.reading"]), f["command"]
    tripped_at = first_time(ft, fcommand, lambda v: v == 0.0)
    peak = max(fplate)
    (BUILD / "figures" / "sensor-fault.svg").write_text(chart(
        "Sensor fault: plate temperature and what the thermostat sees",
        [("Plate (true)", TEAL, ft, fplate, False), ("Control sensor", GREY, ft, fsensor, True)], (0, 480), (-20, 100),
        "Temperature (degC)", hlines=[(90.0, "90 degC limit", ORANGE), (85.0, "85 degC cutout", ORANGE)],
        vlines=[(tripped_at, "heater off", GREY)] if tripped_at is not None else [],
        notes=[f"Peak plate temperature {peak:.1f} degC"]))

    rows = parameters()
    parameter_lines = ["Table 2: The design parameters, read from the model.", "", "| Parameter | Value | Unit |", "| --- | ---: | --- |"]
    parameter_lines += [f"| {name} | {value} | {unit} |" for name, value, unit in rows] + [""]
    (BUILD / "parameters.md").write_text("\n".join(parameter_lines))
    lines = [
        "Table 3: Key figures of each case, measured on the recorded traces (one sample per second).", "",
        "| ID | Figure | Requirement | Result |", "| --- | --- | --- | ---: |",
        f"| CW-001 | Time to reach 62 degC | at most 300 s | {reach:.0f} s |" if reach is not None else "| CW-001 | Time to reach 62 degC | at most 300 s | not reached |",
        f"| CW-002 | Lowest temperature after warm-up | at least 58 degC | {hold_low:.1f} degC |",
        f"| CW-002 | Highest temperature after warm-up | at most 67 degC | {hold_high:.1f} degC |",
        f"| CW-003 | Time the heater is switched off | not given | {tripped_at:.0f} s |" if tripped_at is not None else "| CW-003 | Time the heater is switched off | not given | never |",
        f"| CW-003 | Peak plate temperature | at most 90 degC | {peak:.1f} degC |",
        f"| CW-003 | Control sensor error | not given | {fsensor[0] - fplate[0]:.1f} K |",
        "",
    ]
    (BUILD / "results.md").write_text("\n".join(lines))
    print("wrote build/parameters.md, build/results.md and three figures")
    return 0


if __name__ == "__main__":
    sys.exit(main())
