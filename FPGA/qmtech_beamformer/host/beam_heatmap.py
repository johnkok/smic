#!/usr/bin/env python3
"""Predict the SMIC far-field delay-and-sum response and write CSV/SVG maps."""

import argparse
import cmath
import csv
import math
from pathlib import Path

CHANNELS = 32
SAMPLE_RATE = 48_000.0


def read_geometry(path, keep_kicad_y=False):
    points = [None] * CHANNELS
    with path.open(newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            channel = int(row["reference"].removeprefix("MK")) - 1
            y = float(row["y_mm"])
            points[channel] = [float(row["x_mm"]) / 1000.0,
                               y / 1000.0 if keep_kicad_y else -y / 1000.0,
                               0.0]
    if any(point is None for point in points):
        raise ValueError("geometry must contain MK1 through MK32")
    center = [sum(point[axis] for point in points) / CHANNELS
              for axis in range(3)]
    return [[point[axis] - center[axis] for axis in range(3)]
            for point in points]


def read_calibration(path):
    calibration = [[1.0, 0.0, False] for _ in range(CHANNELS)]
    if path is None:
        return calibration
    with path.open(newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            channel = int(row["channel"])
            if not 0 <= channel < CHANNELS:
                raise ValueError(f"invalid calibration channel {channel}")
            calibration[channel] = [float(row["gain_linear"]),
                                    float(row["delay_samples"]),
                                    bool(int(row["invert"]))]
    return calibration


def unit_vector(azimuth_deg, elevation_deg):
    azimuth = math.radians(azimuth_deg)
    elevation = math.radians(elevation_deg)
    return (math.cos(elevation) * math.cos(azimuth),
            math.cos(elevation) * math.sin(azimuth),
            math.sin(elevation))


def dot(left, right):
    return sum(a * b for a, b in zip(left, right))


def steering_delays(points, calibration, azimuth, elevation, sound_speed):
    direction = unit_vector(azimuth, elevation)
    raw = [-dot(point, direction) / sound_speed * SAMPLE_RATE + cal[1]
           for point, cal in zip(points, calibration)]
    minimum = min(raw)
    return [(value - minimum) / SAMPLE_RATE for value in raw]


def response(points, calibration, delays, frequency, azimuth, elevation,
             sound_speed):
    direction = unit_vector(azimuth, elevation)
    total = 0j
    normalization = 0.0
    for point, cal, delay in zip(points, calibration, delays):
        gain = -cal[0] if cal[2] else cal[0]
        phase = -2.0 * math.pi * frequency * (
            dot(point, direction) / sound_speed + delay)
        total += gain * cmath.exp(1j * phase)
        normalization += abs(gain)
    return abs(total) / normalization if normalization else 0.0


def color(db):
    value = max(0.0, min(1.0, (db + 40.0) / 40.0))
    hue = (1.0 - value) * 240.0
    return f"hsl({hue:.1f},100%,50%)"


def write_svg(path, values, az_step, el_step, title):
    rows, columns = len(values), len(values[0])
    cell_w, cell_h, margin = 4, 4, 42
    width, height = columns * cell_w, rows * cell_h
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" '
             f'width="{width + 2 * margin}" height="{height + 2 * margin + 22}" '
             f'viewBox="0 0 {width + 2 * margin} {height + 2 * margin + 22}">',
             '<rect width="100%" height="100%" fill="white"/>',
             f'<text x="{margin}" y="18" font-family="sans-serif" '
             f'font-size="13">{title}</text>']
    for row, line in enumerate(values):
        for column, db in enumerate(line):
            parts.append(f'<rect x="{margin + column * cell_w}" '
                         f'y="{margin + row * cell_h}" width="{cell_w}" '
                         f'height="{cell_h}" fill="{color(db)}"/>')
    parts.extend([
        f'<text x="{margin}" y="{margin + height + 16}" '
        'font-family="sans-serif" font-size="11">azimuth 0° → 360°</text>',
        f'<text x="5" y="{margin + height // 2}" font-family="sans-serif" '
        'font-size="11" transform="rotate(-90 5 '
        f'{margin + height // 2})">elevation +90° → -90°</text>',
        '</svg>'])
    path.write_text("\n".join(parts), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--geometry", type=Path, required=True)
    parser.add_argument("--calibration", type=Path)
    parser.add_argument("--frequency", type=float, default=3000.0)
    parser.add_argument("--steer-az", type=float, default=0.0)
    parser.add_argument("--steer-el", type=float, default=0.0)
    parser.add_argument("--sound-speed", type=float, default=343.0)
    parser.add_argument("--az-step", type=int, default=2)
    parser.add_argument("--el-step", type=int, default=2)
    parser.add_argument("--keep-kicad-y", action="store_true")
    parser.add_argument("--output", type=Path, default=Path("beam_heatmap"))
    args = parser.parse_args()
    if args.frequency <= 0 or args.sound_speed <= 0 or args.az_step <= 0 or args.el_step <= 0:
        parser.error("frequency, sound speed, and grid steps must be positive")

    points = read_geometry(args.geometry, args.keep_kicad_y)
    calibration = read_calibration(args.calibration)
    delays = steering_delays(points, calibration, args.steer_az, args.steer_el,
                             args.sound_speed)
    azimuths = list(range(0, 361, args.az_step))
    elevations = list(range(90, -91, -args.el_step))
    values = []
    for elevation in elevations:
        line = []
        for azimuth in azimuths:
            magnitude = response(points, calibration, delays, args.frequency,
                                 azimuth, elevation, args.sound_speed)
            line.append(max(-80.0, 20.0 * math.log10(max(magnitude, 1e-4))))
        values.append(line)

    csv_path = args.output.with_suffix(".csv")
    svg_path = args.output.with_suffix(".svg")
    with csv_path.open("w", newline="", encoding="utf-8") as target:
        writer = csv.writer(target)
        writer.writerow(["elevation_deg", *azimuths])
        for elevation, line in zip(elevations, values):
            writer.writerow([elevation, *(f"{db:.3f}" for db in line)])
    write_svg(svg_path, values, args.az_step, args.el_step,
              f"SMIC {args.frequency:g} Hz, steer az={args.steer_az:g}°, el={args.steer_el:g}°")
    print(f"wrote {csv_path} and {svg_path}")


if __name__ == "__main__":
    main()
