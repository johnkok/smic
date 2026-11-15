"""Geometry engine for the SMIC enclosure experiment workbench."""

from dataclasses import dataclass
import math

import FreeCAD as App
import Part


@dataclass
class Parameters:
    pitch: float = 6.0
    thread_depth: float = 2.0
    bore_diameter: float = 128.4
    thread_start_z: float = 0.8
    thread_end_z: float = 49.2
    open_bottom: bool = True
    wave_count: int = 24
    wave_radius: float = 3.0
    wave_center_radius: float = 69.0
    wave_start_z: float = 1.0
    wave_end_z: float = 49.0


def _validate(p: Parameters):
    if p.pitch <= 0:
        raise ValueError("Thread pitch must be positive")
    if p.thread_depth <= 0:
        raise ValueError("Thread depth must be positive")
    if p.bore_diameter <= 0:
        raise ValueError("Bore diameter must be positive")
    if p.thread_end_z <= p.thread_start_z:
        raise ValueError("Thread end must be above thread start")
    if p.wave_count < 0:
        raise ValueError("Wave count cannot be negative")
    if p.wave_count and p.wave_radius <= 0:
        raise ValueError("Wave radius must be positive")
    if p.wave_end_z <= p.wave_start_z:
        raise ValueError("Wave end must be above wave start")


def make_internal_thread_cutter(p: Parameters):
    """Create a right-hand, 60-degree helical cutter."""
    minor_radius = p.bore_diameter / 2.0
    overlap_radius = minor_radius - 0.15
    root_radius = minor_radius + p.thread_depth
    height = p.thread_end_z - p.thread_start_z + p.pitch
    helix = Part.makeHelix(p.pitch, height, overlap_radius)
    helix.translate(App.Vector(0.0, 0.0, p.thread_start_z))

    half_width = min(
        p.thread_depth * math.tan(math.radians(30.0)),
        p.pitch * 0.45,
    )
    z = p.thread_start_z
    points = [
        App.Vector(overlap_radius, 0.0, z - half_width),
        App.Vector(root_radius, 0.0, z),
        App.Vector(overlap_radius, 0.0, z + half_width),
    ]
    profile = Part.Wire(Part.makePolygon(points + [points[0]]).Edges)
    swept = Part.Wire(helix.Edges).makePipeShell([profile], True, False)
    clip = Part.makeCylinder(
        root_radius + 0.5,
        p.thread_end_z - p.thread_start_z,
        App.Vector(0.0, 0.0, p.thread_start_z),
    )
    return swept.common(clip)


def make_vertical_waves(p: Parameters):
    """Create overlapping round vertical ribs for an adjustable wave texture."""
    if p.wave_count == 0:
        return None
    height = p.wave_end_z - p.wave_start_z
    ribs = []
    for index in range(p.wave_count):
        angle = 2.0 * math.pi * index / p.wave_count
        center = App.Vector(
            p.wave_center_radius * math.cos(angle),
            p.wave_center_radius * math.sin(angle),
            p.wave_start_z,
        )
        ribs.append(Part.makeCylinder(p.wave_radius, height, center))
    return ribs[0].multiFuse(ribs[1:]) if len(ribs) > 1 else ribs[0]


def build(base_shape, p: Parameters):
    """Return the experimental enclosure as one checked solid."""
    _validate(p)
    result = base_shape.copy()
    minor_radius = p.bore_diameter / 2.0

    if p.open_bottom:
        # Remove the original 2 mm PCB ledge so caps and board-carrier rings can
        # enter from either end and engage the same continuous thread.
        bounds = result.BoundBox
        result = result.cut(
            Part.makeCylinder(
                minor_radius,
                bounds.ZLength + 0.2,
                App.Vector(0.0, 0.0, bounds.ZMin - 0.1),
            )
        )

    result = result.cut(make_internal_thread_cutter(p))
    waves = make_vertical_waves(p)
    if waves is not None:
        result = result.fuse(waves)

    # OCC's removeSplitter() corrupts this model's pre-existing compound
    # fillet topology, so retain the valid fused solid as produced.

    if result.isNull() or not result.isValid() or len(result.Solids) != 1:
        raise RuntimeError("Parameters did not produce one valid enclosure solid")
    return result


def add_properties(feature, p: Parameters):
    values = (
        ("App::PropertyLength", "Pitch", "Internal thread", p.pitch),
        ("App::PropertyLength", "ThreadDepth", "Internal thread", p.thread_depth),
        ("App::PropertyLength", "BoreDiameter", "Internal thread", p.bore_diameter),
        ("App::PropertyLength", "ThreadStartZ", "Internal thread", p.thread_start_z),
        ("App::PropertyLength", "ThreadEndZ", "Internal thread", p.thread_end_z),
        ("App::PropertyBool", "OpenBottom", "Internal thread", p.open_bottom),
        ("App::PropertyInteger", "WaveCount", "External waves", p.wave_count),
        ("App::PropertyLength", "WaveRadius", "External waves", p.wave_radius),
        ("App::PropertyLength", "WaveCenterRadius", "External waves", p.wave_center_radius),
        ("App::PropertyLength", "WaveStartZ", "External waves", p.wave_start_z),
        ("App::PropertyLength", "WaveEndZ", "External waves", p.wave_end_z),
    )
    for property_type, name, group, value in values:
        if name not in feature.PropertiesList:
            feature.addProperty(property_type, name, group)
        setattr(feature, name, value)

