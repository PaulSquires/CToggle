'    PsToggle - reusable owner-drawn toggle switch control
'    Copyright (C) 2016-2026 Paul Squires, PlanetSquires Software
'
'    This program is free software: you can redistribute it and/or modify
'    it under the terms of the GNU General Public License as published by
'    the Free Software Foundation, either version 3 of the License, or
'    (at your option) any later version.
'
'    This program is distributed in the hope that it will be useful,
'    but WITHOUT any WARRANTY; without even the implied warranty of
'    MERCHANTABILITY or FITNESS for A PARTICULAR PURPOSE.  See the
'    GNU General Public License for more details.

#pragma once

' The demo lays the toggles out as a settings pane: one per row, label on the left, switch
' on the right, a hairline between rows -- the arrangement the control was drawn for.
#define TOGGLE_COUNT   8

#define IDC_FRMMAIN_TOGGLE_FIRST   1000
#define IDC_FRMMAIN_TOGGLE_TEST    1099   ' the throwaway control the self-test measures

declare function frmMain_Show( byval hWndParent as HWND ) as LRESULT
