' ========================================================================================
' CToggle - demo harness
' ========================================================================================

#define UNICODE
#define _WIN32_WINNT &h0602

#include once "windows.bi"
#include once "AfxNova\CWindow.inc"
#include once "AfxNova\AfxStr.inc"
#include once "AfxNova\AfxGdiplus.inc"

using AfxNova


#define APPNAME          wstr("Custom Toggle")
#define APPCLASSNAME     wstr("custom_toggle_class")

#DEFINE GUIFONT          wstr("Segoe UI")

#DEFINE GUIFONT_9        0
#DEFINE GUIFONT_10       1
#DEFINE GUIFONTBOLD_10   2
#DEFINE MAXFONTS         3

dim shared ghFont(MAXFONTS) as HFONT

dim shared as HWND HWND_FRMMAIN

' One instance per settings row: the control is per-instance in every respect, so hovering
' or focusing one must never light up another.
#include once "frmMain.bi"
dim shared as HWND ghToggle(0 to TOGGLE_COUNT - 1)


type THEME_TYPE
    ForeColor             as COLORREF = BGR(190,196,206)
    ForeColorDisabled     as COLORREF = BGR( 90, 96,106)
    BackColor             as COLORREF = BGR( 33, 37, 43)
    ForeColorHot          as COLORREF = BGR(215,218,224)
    BackColorHot          as COLORREF = BGR( 44, 49, 58)
    ForeColorSelect       as COLORREF = BGR(255,255,255)
    BackColorSelect       as COLORREF = BGR( 38, 79,120)
    FocusAccent           as COLORREF = BGR( 86,156,214)
    Divider               as COLORREF = BGR( 55, 60, 69)
end type
dim shared theme as THEME_TYPE



#include once "clsDoubleBuffer.inc"
#include once "CToggle.inc"
#include once "frmMain.inc"


' ========================================================================================
' WinMain
' ========================================================================================
function WinMain( _
            byval hInstance     as HINSTANCE, _
            byval hPrevInstance as HINSTANCE, _
            byval szCmdLine     as zstring ptr, _
            byval nCmdShow      as long _
            ) as long


    ' Initialize the COM library
    CoInitialize(null)

    ' Initialize GDI+ (clsDoubleBuffer's rendering backend -- see DBUF_GDIPLUS). Must be
    ' running before the first WM_PAINT builds a buffer, and must outlive every one of
    ' them, so it brackets frmMain_Show.
    dim as ULONG_PTR gdipToken = AfxGdipInit()

    ' Show the main form
    function = frmMain_Show( 0 )

    ' Every window is destroyed and every clsDoubleBuffer has run its destructor by here,
    ' so no CGp* object can still be alive. Precedes CoUninitialize: GDI+ leans on COM.
    AfxGdipShutdown( gdipToken )

    ' Uninitialize the COM library
    CoUninitialize


end function


' ========================================================================================
' Main program entry point
' ========================================================================================
end WinMain( GetModuleHandle(null), null, command(), SW_NORMAL )
