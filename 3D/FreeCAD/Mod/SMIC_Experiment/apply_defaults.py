"""Apply the default SMIC experiment to the repository model headlessly.

Usage from the repository root:
    snap run freecad.cmd \
      3D/FreeCAD/Mod/SMIC_Experiment/apply_defaults.py
"""

from pathlib import Path
import sys

import FreeCAD as App


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from smic_geometry import Parameters, add_properties, build  # noqa: E402


MODEL = Path("/home/johnkokko/Documents/GitHub/smic/3D/main_body.FCStd")
doc = App.openDocument(str(MODEL))
source = doc.getObject("Fillet001")
if source is None or source.Shape.isNull():
    raise RuntimeError("Fillet001 source feature was not found")

for name in ("InternalThread", "SMICExperimentalBody"):
    old = doc.getObject(name)
    if old is not None:
        doc.removeObject(old.Name)
doc.recompute()

parameters = Parameters()
shape = build(source.Shape, parameters)
feature = doc.addObject("Part::Feature", "SMICExperimentalBody")
feature.Label = "SMIC coarse thread + vertical waves"
feature.Shape = shape
feature.addProperty("App::PropertyString", "BaseSourceName", "Source")
feature.BaseSourceName = source.Name
add_properties(feature, parameters)

body = doc.getObject("Body")
if body is not None:
    body.Visibility = False
source.Visibility = False
feature.Visibility = True
doc.recompute()
doc.saveAs(str(MODEL))

print("SMIC_EXPERIMENT_FEATURE=", feature.Name)
print("SMIC_SHAPE_VALID=", feature.Shape.isValid())
print("SMIC_SOLID_COUNT=", len(feature.Shape.Solids))
print("SMIC_THREAD_PITCH_MM=", feature.Pitch.Value)
print("SMIC_THREAD_RANGE_MM=", feature.ThreadStartZ.Value, feature.ThreadEndZ.Value)
print("SMIC_WAVE_COUNT=", feature.WaveCount)
print("SMIC_VOLUME_MM3=", feature.Shape.Volume)
