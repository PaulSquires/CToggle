# CToggle — design notes

Written alongside the control (2026-07-22). The `README.md` says how to *use* it; this says
why it is shaped the way it is, and what the build turned up.

## Where it came from

There was no toggle switch in the family. `CToggle` was written from a reference screenshot
of a dark settings pane: a steel-blue pill with a light knob at the right for ON, a
near-background pill with a lighter outline and a grey knob at the left for OFF.

Seeded by copying **CSelectBar** — the nearest sibling in shape: static, capture-backed
press/cancel, a built-in painter that one callback can replace wholesale. Every inherited
comment was audited, which is the discipline the family learned the hard way (a copied
rationale that no longer holds is the most repeated bug in these controls).

Callback prefix `TOG_`, verified unused family-wide.

## Decisions

Taken in an interview before any code, so they are choices and not accidents.

| Decision | Chosen | Why not the alternative |
|---|---|---|
| Caption | **none — pill only** | The reference has no text. With no text there is nothing to measure, so the font, `SetFont`/`GetFont` and the measuring pass all disappear — and `LayoutToggle` becomes the only one in the family that never takes a DC. |
| Rendering | **pure GDI supersample** | GDI+ would be three calls, but it is a heavier dependency than any sibling carries. Plain aliased GDI was rejected on sight: the pill's shoulders and the knob's rim are exactly where the eye goes. |
| Animation | **none — the knob snaps** | No sibling animates. It also keeps `rcKnob` a pure function of state rather than of time, which is what lets the self-test assert it at all. |
| Keyboard | **focusable, Space/Enter** | The family's first. A toggle in a settings pane that cannot be reached by Tab is a real accessibility gap, and it was worth the one new pattern. |
| Geometry | **intrinsic size, placed by justification** | "Fill the client" would have made the aspect ratio the host's problem: a badly-shaped window would give a badly-shaped pill. The pill now always looks right whatever the host does. |
| Hit area | **whole client rect** | A bigger, more forgiving target, and it lets a host give the control a full row cell that is clickable end to end. The cost is that `HitTest` becomes pointless, so it does not exist. |
| State name | **Checked** | Win32's own vocabulary for a two-state control (`BM_GETCHECK`), and the `SetChecked`-is-silent rule then reads as the direct analogue of `BM_SETCHECK` vs `BN_CLICKED`. |
| Colours | **flat 20-field struct** | Matches `CSELECTBAR_COLORS`. Nested per-state structs would read more tidily but would be the only nested colour struct in the family. |

### Why `CS_DBLCLKS` is OFF — reversing the sibling default

`CSelectBar` and `CSplitter` both enable it; `CToggle` must not. With `CS_DBLCLKS` the second
of two rapid clicks arrives as `WM_LBUTTONDBLCLK` **instead of** a second `WM_LBUTTONDOWN` —
it substitutes, it is not an extra message. A control that flips once per click would
therefore drop every second rapid click, and the switch would appear to ignore half the
user's input. `CIconPanel` reached the same conclusion for its toggle items; here the control
*is* a toggle, so the case is stronger. This is the single most likely thing for a future
copy-paste to get wrong, which is why it is commented at both the `WndProc` header and the
`Create` site.

### Why `SetEnabled` calls `EnableWindow`

The siblings disable cosmetically and then test a flag on every input path. `CToggle` goes
through `EnableWindow` instead, so Windows stops delivering mouse input and the dialog
manager's Tab skips the control — the disable is enforced by the system rather than by
remembering to check a flag in each handler. `WM_ENABLE` syncs the flag back, which also
covers a host that calls `EnableWindow` itself. The flag checks remain as belt-and-braces.

### Why the focus band is reserved unconditionally

`rcVisual` is `rcTrack` inflated by `focusGap + focusThickness` whether or not the control has
focus, and `GetIdealSize` returns the *visual* size. Reserving it only when focused would make
the pill jump sideways the moment it was tabbed to.

## What the build turned up

**Member-name shadowing, again.** `dim as long ringPad = this.RingPad()` inside
`LayoutToggle` fails with `error 4: Duplicated definition, ringPad` — FreeBASIC is
case-insensitive, so a local sharing a name with a member procedure collides, and the error
points at the `DIM` and never names the method. Same family as the `hFont`/`HFONT` shadowing
already in `Learnings.md`. The local is `nRingPad`, with a comment saying why.

## Verification

- **Builds clean**, zero warnings:
  `fbc64.exe -i "C:\dev" main.bas` from the repo root.
- **`CTOGGLE_SELFTEST=1` — 32 assertions, 0 failures.** Geometry is asserted, never
  eyeballed: DPI scaling of the defaults (and the *absence* of scaling on the two
  thicknesses), vertical centring at odd and even client heights, all three justifications
  plus the overflow degrade-to-LEFT, knob diameter and symmetric insets, the OFF and ON knob
  positions and their mirror symmetry about the track centre, `rcVisual`'s inflation on all
  four sides, `GetIdealSize` matching it and being valid before the control is ever sized,
  re-layout after every mutator, `SetChecked` firing no callback, and `SetEnabled` actually
  disabling the window. Expectations are computed from what the control reports for its own
  defaults, so a high-DPI display cannot produce a false failure.
- **The antialiasing is asserted, not assumed.** The whole rendering design rests on HALFTONE
  *averaging* the supersampled tile rather than dropping pixels — and if a driver behaved
  like `COLORONCOLOR` the control would still draw perfectly plausible output, just with hard
  edges, and no other assertion would notice. So the self-test drives the shipped renderer
  into an offscreen buffer and counts distinct colours over the knob's bounding box: a
  circle's diagonals guarantee partially-covered blocks. Aliased would be exactly 2. It
  measures 64 (the counter's cap).
- **The real `WM_PAINT` path was confirmed by capture**, since the assertion above calls the
  renderer directly and would not have caught a broken paint handler. One in-process
  `PrintWindow(PW_RENDERFULLCONTENT)` of the demo showed all eight rows rendering correctly:
  both default states, the custom green switch, the disabled-but-still-ON switch, the
  callback-painted square switch, and the three justifications visibly differing.

### Not verified

- **The entire interactive pass**: hover in/out, the press/cancel slide-off, focus-ring
  appearance, Tab navigation between switches, and Space/Enter. Nothing here was driven by
  real input.
- **High-DPI appearance.** The self-test asserts the scaling arithmetic, but the control was
  only ever rendered at 100%.
- **The message callback's suppression paths** (returning TRUE) — the demo's callback always
  returns FALSE.

## Possible future work

- An animated knob, if a host ever wants one. It would make `rcKnob` time-dependent, so the
  self-test would have to assert the endpoints rather than the current position.
- A `TOG_JUSTIFY_*` equivalent for the vertical axis. Nothing has asked for it; the pill is
  always centred.
- If HALFTONE ever disappoints on some display, the drop-in replacement is a manual
  box-average over the DIB bits — same tile, same structure, one loop instead of the
  `StretchBlt`.
