# CToggle

A reusable owner-drawn **toggle switch** for FreeBASIC / Win32: a rounded pill whose fill
changes with state, and a circular knob that sits at the left end when OFF and the right end
when ON.

The twelfth control in the family (`CListBox`, `CVScrollBar`, `CHScrollBar`, `CStatusBar`,
`CTabBar`, `CTextBox`, `CMenuBar`, `CPopupMenu`, `CSplitter`, `CIconPanel`, `CSelectBar`), and
it follows the same template: one real `HWND`, per-instance state in a `TYPE` in the `CWindow`
UserData area, one `WndProc`, host callbacks for painting and messages, one `clsDoubleBuffer`
per `WM_PAINT`, no host globals, rects derived and never set.

**Two deliberate departures from the family**, both agreed up front rather than drifted into:

1. **It is the only focusable control in the family.** `WS_TABSTOP`, real focus tracking, a
   painted focus ring, and Space/Enter activation.
2. **It supersamples its own rendering.** A pill and a circle drawn with plain GDI are
   visibly jagged at ~40x20 px. GDI+ was considered and rejected so that this control's
   dependency list stays identical to its siblings' — `clsDoubleBuffer` and nothing else.

## Files

| File | Role |
|---|---|
| `CToggle.bi` | the control: defines, colours, paint/message info, callback typedefs, the `CTOGGLE` type, `LayoutToggle`, and the documented public API |
| `CToggle.inc` | implementation: the supersampling renderer, the built-in painter, the `WndProc`, `Create`, and the API bodies |
| `clsDoubleBuffer.bi` / `.inc` | the family's shared double-buffer helper (vendored copy) |
| `main.bas`, `frmMain.bi`, `frmMain.inc` | demo harness — a settings pane of eight switches — plus the geometry self-test |

Build (the toolchain is not on `PATH`, and AfxNova resolves relative to the workspace root):

```
C:\dev\tiko_editor\toolchains\FreeBASIC-1.10.1-winlibs-gcc-9.3.0\fbc64.exe -i "C:\dev" main.bas
```

Run the self-test with `CTOGGLE_SELFTEST=1` — 32 assertions, geometry plus a check that the
antialiasing is genuinely happening.

## Quick start

```freebasic
dim as HWND hToggle = CToggle_Create( hWndParent, IDC_MYTOGGLE )

CToggle_SetCheckChangedCallback( hToggle, @MyCheckChanged )

' Size it to the switch's own ideal size -- that includes the focus-ring band, so a
' focused switch is never clipped. Valid BEFORE the control has ever been sized.
dim as long iw, ih
CToggle_GetIdealSize( hToggle, iw, ih )
SetWindowPos( hToggle, 0, x, y, iw, ih, SWP_NOZORDER )
ShowWindow( hToggle, SW_SHOW )

CToggle_SetChecked( hToggle, true )      ' silent: fires no callback
```

```freebasic
sub MyCheckChanged( byval hToggle as HWND, byval isChecked as boolean )
    ' Only user action gets here -- a completed click, or Space/Enter.
end sub
```

## The layout

Everything derives from the client rect plus a few authored scalars. `LayoutToggle()` is the
only producer; painting and every rect query consume it.

```
  ringPad      = focusGap + focusThickness
  knobDia      = trackHeight - 2*knobInset

  rcTrack.top  = clientTop + (clientH - trackHeight) \ 2        ALWAYS v-centred
  rcTrack.left = LEFT   -> clientLeft  + ringPad
                 CENTER -> clientLeft  + (clientW - trackWidth) \ 2
                 RIGHT  -> clientRight - ringPad - trackWidth

  rcKnob.top   = rcTrack.top + knobInset            (w = h = knobDia)
  rcKnob.left  = OFF -> rcTrack.left  + knobInset
                 ON  -> rcTrack.right - knobInset - knobDia

  rcVisual     = rcTrack inflated by ringPad on all four sides   ( = GetIdealSize )
```

The pill has an **intrinsic size** and is placed inside whatever client rect it is given —
it does not stretch to fill. `TOG_JUSTIFY_LEFT/CENTER/RIGHT` decides where horizontally;
vertically it is always centred. On overflow the justification degrades to LEFT and the tail
clips at the client edge: rects are computed honestly rather than squeezed, so the pill keeps
its shape and only what is past the edge is lost.

Alone in the family, **`LayoutToggle` never takes a DC** — there is no text and no font, so
nothing here is measured.

All setters take **raw pixels**; the caller DPI-scales. Only the Create-time defaults are
scaled for you — and the two *thickness* values are never scaled at all, because a hairline
should stay a hairline.

## Rendering

The built-in painter draws into an offscreen tile at `CTOGGLE_SUPERSAMPLE` (4x) and scales it
back down with a **HALFTONE `StretchBlt`**. The averaging *is* the antialiasing.

Two traps the renderer pays for, both worth knowing if you ever touch it:

- **The tile must be filled with `BackColor` first.** A fresh DIB section is black, and the
  downscale averages edge blocks against whatever is underneath — so an unfilled tile blends
  every curve toward black and the pill grows a dark fringe that reads as a drop shadow.
- **GDI pens are centred on the path.** A border of width W straddles the track's edge, half
  of it outside, so the `RoundRect` is deflated by `W\2` to keep the whole border inside
  `rcTrack`.

The tile is created and destroyed per paint rather than cached: at 4x a typical visual is
~19 KB, and a toggle repaints only on hover in/out, press, focus change and flip. Caching it
would trade a real resource-leak surface for an optimisation nothing is asking for.

**Setting a paint callback replaces the supersampling pass along with everything else.** That
is a legitimate choice, but it is a choice — it is not free antialiasing you inherit.

## Colours

`CTOGGLE_COLORS` is a flat struct of `COLORREF` fields with defaults: three drawn parts
(track fill, track border, knob) × two states (checked / unchecked) × three moods (idle / hot
/ disabled), plus `BackColor` and `FocusRingColor`. Read-modify-write is Get, assign, Set.

The **ON pill looks borderless** by default because `TrackBorderColorOn*` is defaulted equal
to the matching `TrackColorOn*`; the **OFF pill is outlined** instead, its fill close to the
background and its border markedly lighter. That asymmetry is the look the control was drawn
for, and a host that wants a visible ON border just sets the field.

**There are no pressed colours** — a live press renders as hot. `isPressed` is still handed to
the paint callback, so a host that wants a distinct pressed look can draw one.

Disabled colours are per-state on purpose: a disabled ON toggle must still read as ON.

## Focus and keyboard

- `WS_TABSTOP` on the control's own window. A click anywhere in the client focuses it.
- **Space and Enter** flip the state and notify, exactly as a completed click does.
- `WM_GETDLGCODE` claims `DLGC_WANTALLKEYS` **only** for those two keys, and only when asked
  about a specific message. Claiming unconditionally would swallow Tab and break the very
  navigation the control opted into by being a tabstop; claiming nothing would let a host's
  `IsDialogMessage` route Enter to the dialog's default button first.
- Tab *navigation* needs `IsDialogMessage` in the host's pump. Without it you still get full
  mouse behaviour and, once the control has focus, Space and Enter.
- The focus ring is drawn whenever the control has focus, including focus arriving by mouse.

## Callbacks

| Callback | Fires |
|---|---|
| `TOG_CheckChangedCallbackSub` | the **user** flipped it — click, Space or Enter. `CToggle_SetChecked` is silent. |
| `TOG_MessageCallbackFunc` | mouse, focus and key messages. Return TRUE to suppress default handling. |
| `TOG_PaintCallbackSub` | draw the whole control instead of the built-in painter. |

**The message callback's result is IGNORED for three messages.** `WM_LBUTTONUP`, because the
control holds capture across a press and the up-message is what releases it — suppressing it
would strand capture. `WM_SETFOCUS` and `WM_KILLFOCUS`, because focus is a fact the system
reports, not an action to veto.

## Two traps worth knowing

**`CS_DBLCLKS` is deliberately NOT set** — the opposite call from `CSelectBar` and
`CSplitter`. With it, the second of two rapid clicks arrives as `WM_LBUTTONDBLCLK` *instead
of* a second `WM_LBUTTONDOWN`; for a control whose whole job is to flip on every click, that
would silently swallow every second rapid click. `CIconPanel` omits it for the same reason on
its toggle items — here the control *is* a toggle, so the reasoning is stronger still.

**`CToggle_SetEnabled` calls `EnableWindow`**, not just a cosmetic flag. A disabled window
receives no mouse input and the dialog manager's Tab skips it, so there is no way for a click
or a keystroke to sneak past the greyed appearance. `WM_ENABLE` keeps the control's own flag
true to the window's real state, so a host that reaches for `EnableWindow` directly still gets
the greyed rendering.

## Not implemented, deliberately

- **No animation** — the knob snaps. No sibling animates anything, and it keeps the knob rect
  a pure function of state rather than of time.
- **No caption and no font.** The control draws only the pill; a host that wants a label puts
  one beside it. This is why there is no `SetFont` and no measuring pass.
- **No tooltips** — no tooltip window is created. A host can add its own tool over the HWND.
- **No `CToggle_HitTest`.** The whole client rect is the hit area, so a hit test could only
  ever be `PtInRect(client)`.
- **No tri-state / indeterminate**, and **no arrow-key handling** (Left=off / Right=on would
  mean claiming the arrows away from the dialog manager's navigation).
