; KeyToggles v2.1

; TODO
; add application profiles (https://stackoverflow.com/questions/45190170/how-can-i-make-this-ini-file-into-a-listview-in-autohotkey)
; add overlay
; fix toggles not working when physically holding another toggle key (https://www.reddit.com/r/AutoHotkey/comments/oh65o2/comment/h4phdwu/)
; redo window detection? (https://www.reddit.com/r/AutoHotkey/comments/nmewd1/resize_and_move_a_window_every_time_it_gets/gzoogts)

#Requires Autohotkey v2.0  ; Display an error and quit if this version requirement is not met.
#SingleInstance force      ; Allow only a single instance of the script to run.
#Warn                      ; Enable warnings to assist with detecting common errors.

; Register a function to be called on exit
OnExit(ExitFunc)

; Constants
global KEY_MODE_DISABLED := 0
global KEY_MODE_TOGGLE := 1
global KEY_MODE_HOLD := 2
global KEY_MODE_AUTOFIRE := 3
global KEY_MODE_AUTOFIRE_HOLD := 4
global KEY_MODE_AUTORUN := 5

; Initialize state variables
global g_bAiming := false
global g_bCrouching := false
global g_bSprinting := false
global g_bAutorunning := false
global g_bAutofireAiming := false
global g_bAutofireCrouching := false
global g_bAutofireSprinting := false
global g_bRestoreAiming := false
global g_bRestoreCrouching := false
global g_bRestoreSprinting := false
global g_bRestoreAutorunning := false
global g_bRestoreAutofireAiming := false
global g_bRestoreAutofireCrouching := false
global g_bRestoreAutofireSprinting := false
global g_bToggleKeysSnapshotTaken := false
global g_nWindowID := 0

; Functors
global g_fnAutofireAim := 0
global g_fnAutofireCrouch := 0
global g_fnAutofireSprint := 0

Init()

; Exit script
ExitFunc(p_sExitReason, p_nExitCode)
{
	Output(A_ThisFunc "::pExitReason(" p_sExitReason ") pExitCode(" p_nExitCode ")")
	ReleaseAllKeys()
	TrayTip()
}

; Display an error message and exit
ExitWithErrorMessage(p_sErrorMessage)
{
	MsgBox(p_sErrorMessage, "Error", 16)
	ExitApp(1)
}

Init()
{
	ReadConfigFile()
	RestartAsAdminIfNeeded()
	SetTimer(OnFocusChanged, g_nFocusCheckInterval)
}

HookWindow()
{
	global

	; Make the hotkeys active only for a specific window
	g_nWindowID := WinGetID(g_sWindowName " ahk_exe " g_sProcessName)
	Output(A_ThisFunc "::WinGet(" g_nWindowID ")")
	GroupAdd("windowIDGroup", "ahk_id " g_nWindowID)

	if (g_nWindowID)
		ShowNotification("The window `"" WinGetTitle(g_nWindowID) "`" has been hooked.")
}

IsMouseButton(p_sKey)
{
	mouseButtonsList := "LButton MButton RButton XButton1 XButton2"
	return InStr(mouseButtonsList, p_sKey) != false
}

IsMouseOver(p_sWinTitle)
{
	MouseGetPos(, , &l_nWinID)
	return WinExist(p_sWinTitle " ahk_id " l_nWinID)
}

IsMouseOverWindow(p_nHwnd)
{
	MouseGetPos(, , &l_nMouseWindowID)
	return p_nHwnd == l_nMouseWindowID
}

KeyAutofire(p_sAutofireKey)
{
	Output(A_ThisFunc "::begin")

	switch p_sAutofireKey
	{
		case g_sAimAutofireKey:
			SendKey(g_sAimKey, g_nKeyDelay)
		case g_sCrouchAutofireKey:
			SendKey(g_sCrouchKey, g_nKeyDelay)
		case g_sSprintAutofireKey:
			SendKey(g_sSprintKey, g_nKeyDelay)
	}

	Output(A_ThisFunc "::end")
}

KeyHold(p_sKey)
{
	;Output(A_ThisFunc "::begin")
	SendKey(p_sKey, g_nKeyDelay)
	KeyWait(p_sKey)
	SendKey(p_sKey, g_nKeyDelay)
	;Output(A_ThisFunc "::end")
}

KeyToggle(p_sKey, p_bToggle, p_bWait := false)
{
	global

	Output(A_ThisFunc "::begin")

	switch p_sKey
	{
		case g_sAimKey:
			g_bAiming := p_bToggle
		case g_sCrouchKey:
			g_bCrouching := p_bToggle
		case g_sSprintKey:
			g_bSprinting := p_bToggle
		case g_sForwardKey:
			g_bAutorunning := p_bToggle
	}

	Output(p_sKey == g_sAimKey ? A_ThisFunc "::bAiming(" g_bAiming ")" : p_sKey == g_sCrouchKey ? A_ThisFunc "::bCrouching(" g_bCrouching ")" : p_sKey == g_sSprintKey ? A_ThisFunc "::bSprinting(" g_bSprinting ")" : A_ThisFunc "::bAutorunning(" g_bAutorunning ")")
	SendInput(p_bToggle ? "{Blind}{" p_sKey " down}" : "{Blind}{" p_sKey " up}")

	if (p_bWait)
		KeyWait(p_sKey)

	Output(A_ThisFunc "::end")
}

; Hook the window and register hotkeys if necessary, disable toggles on focus lost and optionally restore them on focus
OnFocusChanged()
{
	global

	ShowNotification("Waiting for the process `"" g_sProcessName "`" to become active.")

	Output(A_ThisFunc "::WinWaitActive")
	WinWaitActive(g_sWindowName " ahk_exe " g_sProcessName)
	Sleep(g_nHookDelay)

	; Make sure to hook the window again if it no longer exists
	if (g_nWindowID != WinExist(g_sWindowName " ahk_exe " g_sProcessName))
	{
		HookWindow()
		RegisterHotkeys()

		; That's a different window, don't restore toggle states
		g_bRestoreAiming := false
		g_bRestoreCrouching := false
		g_bRestoreSprinting := false
		g_bRestoreAutorunning := false
		g_bRestoreAutofireAiming := false
		g_bRestoreAutofireCrouching := false
		g_bRestoreAutofireSprinting := false
	}

	; Restore autofire toggle states
	if (ShouldRestoreAutofiresOnFocus())
	{
		Output(A_ThisFunc "::restoreAutofireToggleStates(" g_bRestoreAutofireAiming ", " g_bRestoreAutofireCrouching ", " g_bRestoreAutofireSprinting ")")

		if (g_bRestoreAutofireAiming)
			OnKeyPress(g_sAimAutofireKey)
		if (g_bRestoreAutofireCrouching)
			OnKeyPress(g_sCrouchAutofireKey)
		if (g_bRestoreAutofireSprinting)
			OnKeyPress(g_sSprintAutofireKey)
	}

	; Restore toggle states
	if (ShouldRestoreTogglesOnFocus())
	{
		Output(A_ThisFunc "::restoreToggleStates(" g_bRestoreAiming ", " g_bRestoreCrouching ", " g_bRestoreSprinting ")")

		if (g_bRestoreAiming)
			KeyToggle(g_sAimKey, true)
		if (g_bRestoreCrouching)
			KeyToggle(g_sCrouchKey, true)
		if (g_bRestoreSprinting)
			KeyToggle(g_sSprintKey, true)
		if (g_bRestoreAutorunning)
			KeyToggle(g_sForwardKey, true)
	}

	Output(A_ThisFunc "::WinWaitNotActive")
	WinWaitNotActive(g_sWindowName " ahk_exe " g_sProcessName)

	; Save toggle states
	if (ShouldRestoreTogglesOnFocus())
	{
		; A snapshot of the toggle states was already taken elsewhere, don't take another one
		if (g_bToggleKeysSnapshotTaken)
			g_bToggleKeysSnapshotTaken := false
		else
		{
			Output(A_ThisFunc "::saveToggleStates(" g_bRestoreAiming ", " g_bRestoreCrouching ", " g_bRestoreSprinting ")")

			g_bRestoreAiming := g_bAiming
			g_bRestoreCrouching := g_bCrouching
			g_bRestoreSprinting := g_bSprinting
			g_bRestoreAutorunning := g_bAutorunning
			g_bRestoreAutofireAiming := g_bAutofireAiming
			g_bRestoreAutofireCrouching := g_bAutofireCrouching
			g_bRestoreAutofireSprinting := g_bAutofireSprinting
		}
	}

	ReleaseAllKeys()
}

OnKeyPress(p_sThisHotkey)
{
	global

	local l_sCleanHotkey := LTrim(p_sThisHotkey, "~*$")
	local l_nKeyMode := KEY_MODE_DISABLED

	switch l_sCleanHotkey
	{
		case g_sAimKey, g_sAimAutofireKey:
			l_nKeyMode := g_bAimMode
		case g_sCrouchKey, g_sCrouchAutofireKey:
			l_nKeyMode := g_bCrouchMode
		case g_sSprintKey, g_sSprintAutofireKey:
			l_nKeyMode := g_bSprintMode
		case g_autorunKey:
			l_nKeyMode := g_bAutorunMode
		; Pressing the forward/backward key disables autorunning
		case g_sForwardKey:
			g_bAutorunning := false
		case g_sBackwardKey:
			if (g_bAutorunning)
			{
				KeyToggle(g_sForwardKey, false)
				KeyWait(g_sBackwardKey)
			}
	}

	;Output(A_ThisFunc "::" pThisHotkey " lKeyMode(" lKeyMode ")")

	switch l_nKeyMode
	{
		case KEY_MODE_TOGGLE, KEY_MODE_AUTORUN:
			l_bIsMouseButton := IsMouseButton(l_sCleanHotkey)
			l_bIsMouseOverWindow := IsMouseOverWindow(g_nWindowID)
			; Output(A_ThisFunc "::" l_sCleanHotkey " l_bIsMouseButton(" l_bIsMouseButton ") l_bIsMouseOverWindow(" l_bIsMouseOverWindow ")")

			; Fixes an issue where you couldn't click outside the window if the toggle key was a mouse button and toggled
			if (l_bIsMouseButton && !l_bIsMouseOverWindow)
			{
				;Output(A_ThisFunc "::" l_sCleanHotkey " outside window")
				SendClickOutsideWindow(l_sCleanHotkey)
			}
			; Otherwise toggle the key
			else
			{
				;Output(A_ThisFunc "::" l_sCleanHotkey " inside window")

				if (l_sCleanHotkey == g_sAimKey)
					KeyToggle(g_sAimKey, !g_bAiming, true)
				else if (l_sCleanHotkey == g_sCrouchKey)
					KeyToggle(g_sCrouchKey, !g_bCrouching, true)
				else if (l_sCleanHotkey == g_sSprintKey)
					KeyToggle(g_sSprintKey, !g_bSprinting, true)
				else if (l_sCleanHotkey == g_autorunKey)
				{
					; Autorun will engage even if the forward/backward key was physically pressed
					if (GetKeyState(g_sBackwardKey, "P"))
						SendKey(g_sBackwardKey)

					KeyWait(g_sForwardKey)
					KeyToggle(g_sForwardKey, !g_bAutorunning)
					KeyWait(g_autorunKey)
				}
			}
		case KEY_MODE_HOLD:
			KeyHold(l_sCleanHotkey)
		; Based on https://autohotkey.com/board/topic/64576-the-definitive-autofire-thread/?p=407264
		case KEY_MODE_AUTOFIRE:
			if (l_sCleanHotkey == g_sAimAutofireKey)
			{
				g_bAutofireAiming := !g_bAutofireAiming
				SetTimer(g_fnAutofireAim, g_bAutofireAiming ? g_nAutofireKeyInterval : 0)
			}
			else if (l_sCleanHotkey == g_sCrouchAutofireKey)
			{
				g_bAutofireCrouching := !g_bAutofireCrouching
				SetTimer(g_fnAutofireCrouch, g_bAutofireCrouching ? g_nAutofireKeyInterval : 0)
			}
			else if (l_sCleanHotkey == g_sSprintAutofireKey)
			{
				g_bAutofireSprinting := !g_bAutofireSprinting
				SetTimer(g_fnAutofireSprint, g_bAutofireSprinting ? g_nAutofireKeyInterval : 0)
			}

			KeyWait(l_sCleanHotkey)

			; Fixes a weird bug where the autofire key would stay permanently pressed after holding it down for a few seconds
			SendInput("{Blind}{" l_sCleanHotkey " up}")
		case KEY_MODE_AUTOFIRE_HOLD:
			if (l_sCleanHotkey == g_sAimAutofireKey)
				SetTimer(g_fnAutofireAim, g_nAutofireKeyInterval)
			else if (l_sCleanHotkey == g_sCrouchAutofireKey)
				SetTimer(g_fnAutofireCrouch, g_nAutofireKeyInterval)
			else if (l_sCleanHotkey == g_sSprintAutofireKey)
				SetTimer(g_fnAutofireSprint, g_nAutofireKeyInterval)

			KeyWait(l_sCleanHotkey)

			if (l_sCleanHotkey == g_sAimAutofireKey)
				SetTimer(g_fnAutofireAim, 0)
			else if (l_sCleanHotkey == g_sCrouchAutofireKey)
				SetTimer(g_fnAutofireCrouch, 0)
			else if (l_sCleanHotkey == g_sSprintAutofireKey)
				SetTimer(g_fnAutofireSprint, 0)

			; Fixes a weird bug where the autofire key would stay permanently pressed after holding it down for a few seconds
			SendInput("{Blind}{" l_sCleanHotkey " up}")
	}
}

Output(p_sMessage)
{
	if (g_bDebugMode)
		OutputDebug(p_sMessage "`n")
}

ReadConfigFile()
{
	global

	l_sConfigFileName := "KeyToggles.ini"

	; Config file is missing, exit
	if (!FileExist(l_sConfigFileName))
		ExitWithErrorMessage(l_sConfigFileName " not found! The script will now exit.")

	; General
	g_sProcessName := IniRead(l_sConfigFileName, "General", "processName", "")
	g_sWindowName := IniRead(l_sConfigFileName, "General", "windowName", "")
	g_nAutofireKeyInterval := IniRead(l_sConfigFileName, "General", "autofireKeyInterval", 100)
	g_bFixSystemKeys := IniRead(l_sConfigFileName, "General", "fixSystemKeys", 1)
	g_nFocusCheckInterval := IniRead(l_sConfigFileName, "General", "focusCheckInterval", 1000)
	g_nHookDelay := IniRead(l_sConfigFileName, "General", "hookDelay", 0)
	g_nKeyDelay := IniRead(l_sConfigFileName, "General", "keyDelay", 0)
	g_bRestoreAutofiresOnFocus := IniRead(l_sConfigFileName, "General", "restoreAutofiresOnFocus", 0)
	g_bRestoreTogglesOnFocus := IniRead(l_sConfigFileName, "General", "restoreTogglesOnFocus", 0)
	g_bRunAsAdmin := IniRead(l_sConfigFileName, "General", "runAsAdmin", 0)
	g_nShowNotifications := IniRead(l_sConfigFileName, "General", "showNotifications", 0)
	g_bAimMode := IniRead(l_sConfigFileName, "General", "aimMode", 0)
	g_bCrouchMode := IniRead(l_sConfigFileName, "General", "crouchMode", 0)
	g_bSprintMode := IniRead(l_sConfigFileName, "General", "sprintMode", 0)
	g_bAutorunMode := IniRead(l_sConfigFileName, "General", "autorunMode", 0)

	; Main keys
	g_sAimKey := IniRead(l_sConfigFileName, "Keys", "aimKey", "RButton")
	g_sCrouchKey := IniRead(l_sConfigFileName, "Keys", "crouchKey", "LCtrl")
	g_sSprintKey := IniRead(l_sConfigFileName, "Keys", "sprintKey", "LShift")

	; Autorun keys
	g_autorunKey := IniRead(l_sConfigFileName, "Keys", "autorunKey", "F1")
	g_sForwardKey := IniRead(l_sConfigFileName, "Keys", "forwardKey", "w")
	g_sBackwardKey := IniRead(l_sConfigFileName, "Keys", "backwardKey", "s")

	; Autofire keys
	g_sAimAutofireKey := IniRead(l_sConfigFileName, "Keys", "aimAutofireKey", "F2")
	g_sCrouchAutofireKey := IniRead(l_sConfigFileName, "Keys", "crouchAutofireKey", "F3")
	g_sSprintAutofireKey := IniRead(l_sConfigFileName, "Keys", "sprintAutofireKey", "F4")

	; Debug
	g_bDebugMode := IniRead(l_sConfigFileName, "Debug", "debugMode", 0)

	; Prevent timers from not working
	if (g_nAutofireKeyInterval <= 0)
		g_nAutofireKeyInterval := 1
	if (g_nFocusCheckInterval <= 0)
		g_nFocusCheckInterval := 1

	if (g_sProcessName == "")
		ExitWithErrorMessage("You must specify a process name! The script will now exit.")
}

RegisterHotkeys()
{
	global

	HotIfWinActive("ahk_group windowIDGroup")

	; Enabled only for toggle and hold modes
	Hotkey("*$" g_sAimKey, OnKeyPress, g_bAimMode == KEY_MODE_TOGGLE || g_bAimMode == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" g_sCrouchKey, OnKeyPress, g_bCrouchMode == KEY_MODE_TOGGLE || g_bCrouchMode == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" g_sSprintKey, OnKeyPress, g_bSprintMode == KEY_MODE_TOGGLE || g_bSprintMode == KEY_MODE_HOLD ? "On" : "Off")

	; Enabled only for autorun mode
	Hotkey("*$" g_autorunKey, OnKeyPress, g_bAutorunMode == KEY_MODE_AUTORUN ? "On" : "Off")
	Hotkey("~*$" g_sForwardKey, OnKeyPress, g_bAutorunMode == KEY_MODE_AUTORUN ? "On" : "Off")
	Hotkey("~*$" g_sBackwardKey, OnKeyPress, g_bAutorunMode == KEY_MODE_AUTORUN ? "On" : "Off")

	; Enabled only for autofire modes
	Hotkey("*$" g_sAimAutofireKey, OnKeyPress, g_bAimMode == KEY_MODE_AUTOFIRE || g_bAimMode == KEY_MODE_AUTOFIRE_HOLD  ? "On" : "Off")
	Hotkey("*$" g_sCrouchAutofireKey, OnKeyPress, g_bCrouchMode == KEY_MODE_AUTOFIRE || g_bCrouchMode == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")
	Hotkey("*$" g_sSprintAutofireKey, OnKeyPress, g_bSprintMode == KEY_MODE_AUTOFIRE || g_bSprintMode == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")

	; Fixes issues when pressing system keys while toggle keys are modifiers and toggled
	Hotkey("*$" "!Tab", SendAltTab, g_bFixSystemKeys ? "On" : "Off")
	Hotkey("*$" "Escape", SendEscape, g_bFixSystemKeys ? "On" : "Off")
	Hotkey("*$" "LWin", SendWindows, g_bFixSystemKeys ? "On" : "Off")
	Hotkey("*$" "RWin", SendWindows, g_bFixSystemKeys ? "On" : "Off")

	; Bind our functors to actual functions
	g_fnAutofireAim := KeyAutofire.Bind(g_sAimAutofireKey)
	g_fnAutofireCrouch := KeyAutofire.Bind(g_sCrouchAutofireKey)
	g_fnAutofireSprint := KeyAutofire.Bind(g_sSprintAutofireKey)

	HotIfWinActive()
}

ReleaseAllKeys()
{
	global

	Output(A_ThisFunc "::states(" g_bAiming ", " g_bCrouching ", " g_bSprinting ", " g_bAutorunning ")")

	; Release all toggle keys
	if (g_bAiming)
		KeyToggle(g_sAimKey, false)
	if (g_bCrouching)
		KeyToggle(g_sCrouchKey, false)
	if (g_bSprinting)
		KeyToggle(g_sSprintKey, false)
	if (g_bAutorunning)
		KeyToggle(g_sForwardKey, false)

	g_bAutofireAiming := false
	g_bAutofireCrouching := false
	g_bAutofireSprinting := false

	; Delete all autofire timers
	if (g_fnAutofireAim)
		SetTimer(g_fnAutofireAim, 0)
	if (g_fnAutofireCrouch)
		SetTimer(g_fnAutofireCrouch, 0)
	if (g_fnAutofireSprint)
		SetTimer(g_fnAutofireSprint, 0)
}

RestartAsAdminIfNeeded()
{
	; Restart the script as admin
	if (g_bRunAsAdmin && !A_IsAdmin)
	{
		try
		{
			if A_IsCompiled
				Run("*RunAs " A_ScriptFullPath " /restart")
			else
				Run("*RunAs " A_AhkPath " /restart " A_ScriptFullPath)

			ExitApp()
		}
	}
}

SendAltTab(p_sThisHotkey)
{
	;Output(A_ThisFunc "::begin")

	; Take a snapshot of the toggle states
	if (ShouldRestoreTogglesOnFocus())
		TakeToggleKeysSnapshot()

	; Check if modifier keys are physically pressed to handle Ctrl+Alt+Tab, Shift+Alt+Tab and Ctrl+Shift+Alt+Tab
	if (GetKeyState("Control", "P"))
		SendInput("{Blind}{Control down}")
	if (GetKeyState("Shift", "P"))
		SendInput("{Blind}{Shift down}")

	SendInput("{Blind}{Alt down}{Tab}")
	;Output(A_ThisFunc "::end")
}

SendClickOutsideWindow(p_sKey)
{
	;Output(A_ThisFunc "::begin")

	; Take a snapshot of the toggle states
	if (ShouldRestoreTogglesOnFocus())
		TakeToggleKeysSnapshot(false)

	ReleaseAllKeys()
	SendKey(p_sKey, 0, true)

	;Output(A_ThisFunc "::end")
}

SendEscape(p_sThisHotkey)
{
	;Output(A_ThisFunc "::begin")

	; Take a snapshot of the toggle states
	if (ShouldRestoreTogglesOnFocus())
		TakeToggleKeysSnapshot()

	; Check if modifier keys are physically pressed to handle Ctrl+Escape and Ctrl+Shift+Escape
	if (GetKeyState("Control", "P"))
		SendInput("{Blind}{Control down}")
	if (GetKeyState("Shift", "P"))
		SendInput("{Blind}{Shift down}")

	SendInput("{Blind}{Escape}")

	; Fixes an issue where the window wouldn't receive key up events when pressing Ctrl+Shift+Escape
	ControlSend("{Blind}{Control up}{Shift up}")

	;Output(A_ThisFunc "::end")
}

SendKey(p_sKey, p_nHoldDuration := 0, p_bWait := false)
{
	SendInput("{Blind}{" p_sKey " down}")

	if (p_nHoldDuration > 0)
		Sleep(p_nHoldDuration)

	if (p_bWait)
		KeyWait(p_sKey)

	SendInput("{Blind}{" p_sKey " up}")
}

SendWindows(p_sThisHotkey)
{
	;Output(A_ThisFunc "::begin")

	; Take a snapshot of the toggle states
	if (ShouldRestoreTogglesOnFocus())
		TakeToggleKeysSnapshot()

	; Check if modifier keys are physically pressed to handle Shift+Win
	if (GetKeyState("Shift", "P"))
		SendInput("{Blind}{Shift down}")

	SendInput("{Blind}{LWin}")

	;Output(A_ThisFunc "::end")
}

ShouldRestoreAutofiresOnFocus()
{
	return g_bRestoreAutofiresOnFocus && (g_bAimMode == KEY_MODE_AUTOFIRE || g_bCrouchMode == KEY_MODE_AUTOFIRE || g_bSprintMode == KEY_MODE_AUTOFIRE) && (WinExist("ahk_id " g_nWindowID) != 0)
}

ShouldRestoreTogglesOnFocus()
{
	return g_bRestoreTogglesOnFocus && (g_bAimMode == KEY_MODE_TOGGLE || g_bCrouchMode == KEY_MODE_TOGGLE || g_bSprintMode == KEY_MODE_TOGGLE) && (WinExist("ahk_id " g_nWindowID) != 0)
}

ShowNotification(p_sMessage)
{
	switch g_nShowNotifications
	{
		case 1:
			 ; Make sure to clear any existing traytip
			TrayTip()
			TrayTip(p_sMessage)
		case 2:
			ToolTip(p_sMessage)
			SetTimer(() => ToolTip(), -5000)
	}
}

TakeToggleKeysSnapshot(p_bReleaseKeys := true)
{
	global

	g_bRestoreAiming := g_bAiming
	g_bRestoreCrouching := g_bCrouching
	g_bRestoreSprinting := g_bSprinting
	g_bRestoreAutorunning := g_bAutorunning
	g_bRestoreAutofireAiming := g_bAutofireAiming
	g_bRestoreAutofireCrouching := g_bAutofireCrouching
	g_bRestoreAutofireSprinting := g_bAutofireSprinting
	g_bToggleKeysSnapshotTaken := true

	if (p_bReleaseKeys)
		ReleaseAllKeys()
}

; Fixes an issue where you couldn't click outside the window while toggle keys are mouse buttons and are enabled
#HotIf WinActive("ahk_group windowIDGroup")
*$LButton::
*$MButton::
*$RButton::
*$XButton1::
*$XButton2::
{
	if (!IsMouseOverWindow(g_nWindowID))
	{
		;Output(A_ThisHotkey "::outside window")
		SendClickOutsideWindow(LTrim(A_ThisHotkey, "*$"))
	}
	else
	{
		;Output(A_ThisHotkey "::inside window")
		SendKey(LTrim(A_ThisHotkey, "*$"), 0, true)
	}
}
#HotIf

#SuspendExempt
#HotIf g_bDebugMode
; Exit script
*!F10::ExitApp() ; ALT+F10

; Reload script
*!F11::Reload() ; ALT+F11
#HotIf

; Suspend script (useful in menus)
*!F12:: ; ALT+F12
{
	Suspend()

	; Single beep when suspended
	if (A_IsSuspended)
	{
		SoundBeep(1000)
		ReleaseAllKeys()
	}
	; Double beep when resumed
	else
	{
		SoundBeep(1000)
		SoundBeep(1000)
	}
}
#SuspendExempt False
