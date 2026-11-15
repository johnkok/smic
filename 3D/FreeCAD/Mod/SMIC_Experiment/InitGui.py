import FreeCADGui as Gui


class SMICExperimentWorkbench(Workbench):
    MenuText = "SMIC Experiment"
    ToolTip = "Experiment with SMIC enclosure threads and vertical textures"

    def Initialize(self):
        import smic_command  # noqa: F401

        self.appendToolbar("SMIC Experiment", ["SMIC_EnclosureExperiment"])
        self.appendMenu("SMIC Experiment", ["SMIC_EnclosureExperiment"])

    def GetClassName(self):
        return "Gui::PythonWorkbench"


Gui.addWorkbench(SMICExperimentWorkbench())

