import FreeCAD as App
import FreeCADGui as Gui
from PySide import QtCore, QtWidgets

from smic_geometry import Parameters, add_properties, build


class ExperimentDialog(QtWidgets.QDialog):
    def __init__(self):
        super().__init__(Gui.getMainWindow())
        self.setWindowTitle("SMIC enclosure experiment")
        self.setMinimumWidth(430)
        self._make_ui()
        self._load_existing()

    def _length(self, value, minimum=0.0, maximum=500.0):
        box = QtWidgets.QDoubleSpinBox()
        box.setRange(minimum, maximum)
        box.setDecimals(2)
        box.setSingleStep(0.25)
        box.setSuffix(" mm")
        box.setValue(value)
        return box

    def _make_ui(self):
        layout = QtWidgets.QVBoxLayout(self)
        note = QtWidgets.QLabel(
            "Select the original enclosure solid, then Preview. The generated "
            "feature is separate, so the source body remains editable."
        )
        note.setWordWrap(True)
        layout.addWidget(note)

        form = QtWidgets.QFormLayout()
        self.pitch = self._length(6.0, 1.0, 30.0)
        self.depth = self._length(2.0, 0.2, 10.0)
        self.bore = self._length(128.4, 1.0, 300.0)
        self.thread_start = self._length(0.8, 0.0, 300.0)
        self.thread_end = self._length(49.2, 0.0, 300.0)
        self.open_bottom = QtWidgets.QCheckBox("Open ledge for two-sided access")
        self.open_bottom.setChecked(True)
        self.wave_count = QtWidgets.QSpinBox()
        self.wave_count.setRange(0, 128)
        self.wave_count.setValue(24)
        self.wave_radius = self._length(3.0, 0.2, 20.0)
        self.wave_center = self._length(69.0, 1.0, 300.0)
        self.wave_start = self._length(1.0, 0.0, 300.0)
        self.wave_end = self._length(49.0, 0.0, 300.0)

        form.addRow("Coarse thread pitch", self.pitch)
        form.addRow("Thread depth", self.depth)
        form.addRow("Bore/minor diameter", self.bore)
        form.addRow("Thread start Z", self.thread_start)
        form.addRow("Thread end Z", self.thread_end)
        form.addRow("Bottom access", self.open_bottom)
        form.addRow("Vertical wave count", self.wave_count)
        form.addRow("Wave/rib radius", self.wave_radius)
        form.addRow("Wave center radius", self.wave_center)
        form.addRow("Wave start Z", self.wave_start)
        form.addRow("Wave end Z", self.wave_end)
        layout.addLayout(form)

        self.status = QtWidgets.QLabel("")
        self.status.setWordWrap(True)
        layout.addWidget(self.status)

        buttons = QtWidgets.QDialogButtonBox()
        preview = buttons.addButton("Preview / update", QtWidgets.QDialogButtonBox.ActionRole)
        close = buttons.addButton(QtWidgets.QDialogButtonBox.Close)
        preview.clicked.connect(self.preview)
        close.clicked.connect(self.accept)
        layout.addWidget(buttons)

    def _load_existing(self):
        doc = App.ActiveDocument
        feature = doc.getObject("SMICExperimentalBody") if doc else None
        if feature is None:
            return
        mapping = (
            (self.pitch, "Pitch"),
            (self.depth, "ThreadDepth"),
            (self.bore, "BoreDiameter"),
            (self.thread_start, "ThreadStartZ"),
            (self.thread_end, "ThreadEndZ"),
            (self.wave_count, "WaveCount"),
            (self.wave_radius, "WaveRadius"),
            (self.wave_center, "WaveCenterRadius"),
            (self.wave_start, "WaveStartZ"),
            (self.wave_end, "WaveEndZ"),
        )
        for widget, name in mapping:
            if name in feature.PropertiesList:
                value = getattr(feature, name)
                widget.setValue(value.Value if hasattr(value, "Value") else value)
        if "OpenBottom" in feature.PropertiesList:
            self.open_bottom.setChecked(feature.OpenBottom)

    def parameters(self):
        return Parameters(
            pitch=self.pitch.value(),
            thread_depth=self.depth.value(),
            bore_diameter=self.bore.value(),
            thread_start_z=self.thread_start.value(),
            thread_end_z=self.thread_end.value(),
            open_bottom=self.open_bottom.isChecked(),
            wave_count=self.wave_count.value(),
            wave_radius=self.wave_radius.value(),
            wave_center_radius=self.wave_center.value(),
            wave_start_z=self.wave_start.value(),
            wave_end_z=self.wave_end.value(),
        )

    def _source(self, doc):
        selected = Gui.Selection.getSelection()
        if selected and hasattr(selected[0], "Shape") and not selected[0].Shape.isNull():
            return selected[0]
        for name in ("Fillet001", "Body"):
            obj = doc.getObject(name)
            if obj is not None and hasattr(obj, "Shape") and not obj.Shape.isNull():
                return obj
        raise RuntimeError("Select the original enclosure solid first")

    @QtCore.Slot()
    def preview(self):
        doc = App.ActiveDocument
        if doc is None:
            self.status.setText("Open main_body.FCStd first.")
            return
        try:
            source = self._source(doc)
            if source.Name == "SMICExperimentalBody":
                raise RuntimeError("Select the original Body or Fillet001, not the preview")
            p = self.parameters()
            result = build(source.Shape, p)
            feature = doc.getObject("SMICExperimentalBody")
            if feature is None:
                feature = doc.addObject("Part::Feature", "SMICExperimentalBody")
                feature.Label = "SMIC threaded + wave enclosure"
            feature.Shape = result
            if "BaseSourceName" not in feature.PropertiesList:
                feature.addProperty("App::PropertyString", "BaseSourceName", "Source")
            feature.BaseSourceName = source.Name
            add_properties(feature, p)
            source.Visibility = False
            feature.Visibility = True
            doc.recompute()
            Gui.activeDocument().activeView().fitAll()
            self.status.setText(
                "Preview updated. Save the FreeCAD document to keep it; select the "
                "source again and change values for another version."
            )
        except Exception as error:
            self.status.setText(str(error))


class SMICEnclosureExperimentCommand:
    def GetResources(self):
        return {
            "MenuText": "Thread and wave experiment",
            "ToolTip": "Adjust the SMIC internal thread and exterior vertical waves",
        }

    def Activated(self):
        ExperimentDialog().exec()

    def IsActive(self):
        return App.ActiveDocument is not None


Gui.addCommand("SMIC_EnclosureExperiment", SMICEnclosureExperimentCommand())

