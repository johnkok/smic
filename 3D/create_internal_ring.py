"""Create the 10 mm SMIC board-carrier ring with a compatible male thread.

Run from the repository root with:
    snap run freecad.cmd 3D/create_internal_ring.py
"""

import math
from pathlib import Path

import FreeCAD as App
import Part


OUTPUT = Path("/home/johnkokko/Documents/GitHub/smic/3D/internal_ring_10mm.FCStd")
BODY_MODEL = Path("/home/johnkokko/Documents/GitHub/smic/3D/main_body.FCStd")

HEIGHT = 10.0
INNER_DIAMETER = 124.0
PITCH = 6.0
FEMALE_MINOR_DIAMETER = 128.4
FEMALE_MAJOR_DIAMETER = 132.4
RADIAL_CLEARANCE = 0.2
FLANK_CLEARANCE = 0.2
THREAD_START_Z = 0.4
THREAD_END_Z = 9.6

INNER_RADIUS = INNER_DIAMETER / 2.0
MALE_MINOR_RADIUS = FEMALE_MINOR_DIAMETER / 2.0 - RADIAL_CLEARANCE
MALE_MAJOR_RADIUS = FEMALE_MAJOR_DIAMETER / 2.0 - RADIAL_CLEARANCE
THREAD_DEPTH = MALE_MAJOR_RADIUS - MALE_MINOR_RADIUS


def make_male_thread():
    overlap_radius = MALE_MINOR_RADIUS - 0.15
    height = THREAD_END_Z - THREAD_START_Z + PITCH
    helix = Part.makeHelix(PITCH, height, overlap_radius)
    helix.translate(App.Vector(0.0, 0.0, THREAD_START_Z))

    half_width = THREAD_DEPTH * math.tan(math.radians(30.0)) - FLANK_CLEARANCE
    if half_width <= 0:
        raise RuntimeError("Flank clearance is too large for the thread depth")
    z = THREAD_START_Z
    points = [
        App.Vector(overlap_radius, 0.0, z - half_width),
        App.Vector(MALE_MAJOR_RADIUS, 0.0, z),
        App.Vector(overlap_radius, 0.0, z + half_width),
    ]
    profile = Part.Wire(Part.makePolygon(points + [points[0]]).Edges)
    ridge = Part.Wire(helix.Edges).makePipeShell([profile], True, False)
    clip = Part.makeCylinder(
        MALE_MAJOR_RADIUS + 0.5,
        THREAD_END_Z - THREAD_START_Z,
        App.Vector(0.0, 0.0, THREAD_START_Z),
    )
    return ridge.common(clip)


doc = App.newDocument("internal_ring_10mm", "SMIC internal carrier ring")

outer = Part.makeCylinder(MALE_MINOR_RADIUS, HEIGHT)
inner = Part.makeCylinder(INNER_RADIUS, HEIGHT)
core_shape = outer.cut(inner)
thread_shape = make_male_thread()
ring_shape = core_shape.fuse(thread_shape)

if ring_shape.isNull() or not ring_shape.isValid() or len(ring_shape.Solids) != 1:
    raise RuntimeError("Ring generation did not produce one valid solid")

core = doc.addObject("Part::Feature", "CoreRing")
core.Label = "124 mm ID carrier core"
core.Shape = core_shape
core.Visibility = False

ridge = doc.addObject("Part::Feature", "MaleThreadRidge")
ridge.Label = "6 mm pitch male thread ridge"
ridge.Shape = thread_shape
ridge.Visibility = False

ring = doc.addObject("Part::Feature", "InternalRing10mm")
ring.Label = "SMIC 10 mm internal threaded ring"
ring.Shape = ring_shape

properties = (
    ("App::PropertyLength", "Height", "Ring", HEIGHT),
    ("App::PropertyLength", "InnerDiameter", "Ring", INNER_DIAMETER),
    ("App::PropertyLength", "Pitch", "Thread", PITCH),
    ("App::PropertyLength", "MaleMinorDiameter", "Thread", MALE_MINOR_RADIUS * 2.0),
    ("App::PropertyLength", "MaleMajorDiameter", "Thread", MALE_MAJOR_RADIUS * 2.0),
    ("App::PropertyLength", "ThreadStartZ", "Thread", THREAD_START_Z),
    ("App::PropertyLength", "ThreadEndZ", "Thread", THREAD_END_Z),
    ("App::PropertyLength", "RadialClearance", "Printing tolerance", RADIAL_CLEARANCE),
    ("App::PropertyLength", "FlankClearance", "Printing tolerance", FLANK_CLEARANCE),
    ("App::PropertyString", "MatesWith", "Thread", "main_body.SMICExperimentalBody"),
)
for property_type, name, group, value in properties:
    ring.addProperty(property_type, name, group)
    setattr(ring, name, value)

doc.recompute()
doc.recompute()

# At Z=0.4 mm the male and female helix origins both land at Z=0.8 mm and
# angle zero. Confirm the printed-clearance model has no volume interference.
body_doc = App.openDocument(str(BODY_MODEL))
body_feature = body_doc.getObject("SMICExperimentalBody")
if body_feature is None or body_feature.Shape.isNull():
    raise RuntimeError("SMICExperimentalBody was not found in main_body.FCStd")
fit_shape = ring.Shape.copy()
fit_shape.translate(App.Vector(0.0, 0.0, 0.4))
interference = body_feature.Shape.common(fit_shape).Volume
if interference > 0.001:
    raise RuntimeError(f"Ring/body interference is {interference:.6f} mm^3")

doc.saveAs(str(OUTPUT))

print("SMIC_RING_MODEL=", OUTPUT)
print("SMIC_RING_VALID=", ring.Shape.isValid())
print("SMIC_RING_SOLIDS=", len(ring.Shape.Solids))
print("SMIC_RING_HEIGHT_MM=", ring.Height.Value)
print("SMIC_RING_ID_MM=", ring.InnerDiameter.Value)
print("SMIC_RING_PITCH_MM=", ring.Pitch.Value)
print("SMIC_RING_MINOR_DIAMETER_MM=", ring.MaleMinorDiameter.Value)
print("SMIC_RING_MAJOR_DIAMETER_MM=", ring.MaleMajorDiameter.Value)
print("SMIC_RING_RADIAL_CLEARANCE_MM=", ring.RadialClearance.Value)
print("SMIC_RING_FLANK_CLEARANCE_MM=", ring.FlankClearance.Value)
print("SMIC_RING_BODY_INTERFERENCE_MM3=", interference)
