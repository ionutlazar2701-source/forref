# App-in-viewport contract

The hardware shell and the FORREF application are different widgets.

```
DeviceShellStage
  └── display aperture clip
        └── WatchReferenceApp
```

The shell paints the case, straps, and control marks. It does not own the child's hit testing. Bezel, strap, and dead-corner pointers are not sporting actions.

`WatchReferenceApp` is a live widget subtree. It is not a screenshot and it is not a preview placed beside the shell.

The same widget class is mounted for every seed profile. Profile facts change clip shape, aperture size, and the degraded viewport label. They do not change football actions.

A viewport that is not the native logical viewport is labeled `DEGRADED`. An aperture that cannot hold the 48px actions shows `LAYOUT NOT FIT FOR THIS PROFILE` instead of shrinking those actions.

A press that is still down when focus is lost, or when the selected profile changes, does not commit. The research runtime remains the writer of research cautions, send-offs, and substitutions.

Shell fidelity for the four seed profiles is schematic. The aperture is not a measured opening and not a safe area.
