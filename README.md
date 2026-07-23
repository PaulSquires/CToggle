# CToggle

A reusable owner-drawn **toggle switch** for FreeBASIC / Win32: a rounded pill whose fill
changes with state, and a circular knob that sits at the left end when OFF and the right end
when ON.

The twelfth control in the family (`CListBox`, `CVScrollBar`, `CHScrollBar`, `CStatusBar`,
`CTabBar`, `CTextBox`, `CMenuBar`, `CPopupMenu`, `CSplitter`, `CIconPanel`, `CSelectBar`), and
it follows the same template: one real `HWND`, per-instance state in a `TYPE` in the `CWindow`
UserData area, one `WndProc`, host callbacks for painting and messages, one `CBufferPaint`
per `WM_PAINT`, no host globals, rects derived and never set.

**One deliberate departure from the family:** it is the **only focusable control**.
`WS_TABSTOP`, real focus tracking, a painted focus ring, and Space/Enter activation.

There used to be a second. This control shipped its own supersampled renderer — a 4x
offscreen tile downscaled with a HALFTONE `StretchBlt` — because plain GDI left a pill and a
circle visibly jagged at ~40x20 px, and GDI+ was rejected at the time to keep the dependency
list identical to its siblings'. That reasoning expired in 2026-07: `CBufferPaint` renders
geometry through GDI+ for **every** control now, so the dependency argument no longer applies
and the tile is gone. See [Rendering](#rendering).

## Files

| File | Role |
|---|---|
| `CToggle.bi` | the control: defines, colours, paint/message info, callback typedefs, the `CTOGGLE` type, `LayoutToggle`, and the documented public API |
| `CToggle.inc` | implementation: the built-in painter, the `WndProc`, `Create`, and the API bodies |
| `CBufferPaint.bi` / `.inc` | the family's shared double-buffer helper (vendored copy) |
| `main.bas`, `frmMain.bi`, `frmMain.inc` | demo harness — a settings pane of eight switches — plus the geometry self-test |

Build (the toolchain is not on `PATH`, and AfxNova resolves relative to the workspace root):

```
C:\dev\tiko_editor\toolchains\FreeBASIC-1.10.1-winlibs-gcc-9.3.0\fbc64.exe -i "C:\dev" main.bas
```

Run the self-test with `CTOGGLE_SELFTEST=1` — 35 assertions: geometry, a check that the
antialiasing is genuinely happening, and three that the dialog manager can actually reach the
control by Tab.

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

`CToggle_RenderDefault` is three calls into `CBufferPaint`, which draws geometry with GDI+
and antialiases the curves:

| part | call | note |
|---|---|---|
| track | `PaintRoundBorderRect( rcTrack, ell, nBorderThick )` | `ell` = the track's **height**, so both ends become exact semicircles — that, and only that, is what makes a rounded rect a pill. Curvature is a *diameter*; the buffer halves it internally. |
| knob | `PaintEllipse( rcKnob, 0 )` | filled, no rim |
| focus ring | `PaintRoundOutline( rcVisual, fell, nFocusThick )` | **outline, never filled** — it is drawn over the pill, and a filled round rect would erase it |

Nothing in the renderer touches a GDI object or a device context. That is the point: the
control owns geometry and state, `CBufferPaint` owns rendering. This control was the one
sibling that broke that rule.

### What the old renderer was paying for

Until 2026-07 this drew into a 4x offscreen tile and downscaled it with a HALFTONE
`StretchBlt`, because plain GDI has no antialiasing. Both of its traps are gone with it, and
are recorded here only so nobody reintroduces them:

- **The tile had to be pre-filled with `BackColor`.** A fresh DIB section is zeroed — black —
  and the downscale averaged edge blocks against whatever was underneath, so an unfilled tile
  blended every curve toward black and the pill wore a dark fringe that read as a drop shadow.
- **The `RoundRect` had to be deflated by half the pen width**, because GDI pens are centred
  on the path. GDI+ pens are centred too, but `CBufferPaint` now applies that correction
  once, for every control, instead of each one hand-rolling it.

The replacement is not merely equivalent: the self-test's rim probe reports **57 distinct
tones** where a 4x4 block average could produce at most ~17.

**Setting a paint callback still replaces the built-in painter entirely** — but it now
inherits the same antialiased primitives through the buffer it is handed, rather than having
to hand-roll smoothing the way a callback replacing the supersampler did.

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
- **Give one of your controls the focus at startup.** `IsDialogMessage` only acts when the
  focused window is a *descendant* of the window you pass it, and when your form opens the focus
  is on the form itself — so the **first Tab does nothing**, which reads exactly like broken
  tabstops. A real dialog does this in `WM_INITDIALOG`; an ordinary `CWindow` host calls
  `SetFocus( hFirstControl )` after `ShowWindow`.
- The focus ring is drawn whenever the control has focus, including focus arriving by mouse.

> **Fixed 2026-07-23 — Tab navigation never actually worked before that.** `CWindow.Create`
> defaults its `dwExStyle` parameter to `WS_EX_CONTROLPARENT OR WS_EX_WINDOWEDGE`, and
> `CToggle_Create` passed only `dwStyle` — so the control declared itself a *container*, the
> dialog manager descended into it looking for tabstops, found no children, and skipped it. The
> control's own comment said "there is no `WS_EX_CONTROLPARENT`", which was the intent and not
> what the code did. Now passed explicitly as `0`, and asserted three ways in the self-test.
> Note this fix is **wrong** for `CListBox`/`CTextBox`/`CNumericUpDown`/`CScrollPanel`, which
> genuinely need the flag; see `C:\dev\Learnings.md`.

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
