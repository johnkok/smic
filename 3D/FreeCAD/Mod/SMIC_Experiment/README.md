# SMIC Experiment FreeCAD workbench

This local FreeCAD workbench generates a reversible derived enclosure with:

- a coarse, right-hand 60-degree internal thread;
- optional removal of the original PCB ledge for access from both ends;
- an adjustable rounded vertical-rib/wave exterior texture.

The defaults are a 6 mm pitch, 2 mm thread depth, 128.4 mm minor diameter,
24 exterior waves, and a continuous thread from Z=0.8 to Z=49.2 mm. These
settings allow a bottom cap and separate threaded board-carrier rings to use
the same internal thread.

## Install

Copy or symlink the `SMIC_Experiment` directory into FreeCAD's user `Mod`
directory, normally:

```text
~/.local/share/FreeCAD/Mod/SMIC_Experiment
```

For the Snap build used by this project, `UserAppData` is under the Snap data
directory, so install it at:

```text
~/snap/freecad/common/Mod/SMIC_Experiment
```

Restart FreeCAD, select **SMIC Experiment** from the workbench selector, open
`3D/main_body.FCStd`, select the original `Fillet001` feature, and choose
**Thread and wave experiment**.

The command creates `SMICExperimentalBody` as a separate derived feature and
hides the source. The source remains intact. Change the controls and use
**Preview / update** to compare geometries, then save the document when happy.
