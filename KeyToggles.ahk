; KeyToggles v2.0

; TODO
; add application profiles (https://stackoverflow.com/questions/45190170/how-can-i-make-this-ini-file-into-a-listview-in-autohotkey)
; add overlay
; fix toggles not working when physically holding another toggle key (https://www.reddit.com/r/AutoHotkey/comments/oh65o2/comment/h4phdwu/)
; redo window detection? (https://www.reddit.com/r/AutoHotkey/comments/nmewd1/resize_and_move_a_window_every_time_it_gets/gzoogts)

#Requires Autohotkey v2.0  ; Display an error and quit if this version requirement is not met.
#SingleInstance force      ; Allow only a single instance of the script to run.
#Warn                      ; Enable warnings to assist with detecting common errors.
SetWorkingDir(A_ScriptDir) ; Ensures a consistent starting directory.

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
global bAiming := false
global bCrouching := false
global bSprinting := false
global bAutorunning := false
global bAutofireAiming := false
global bAutofireCrouching := false
global bAutofireSprinting := false
global bRestoreAiming := false
global bRestoreCrouching := false
global bRestoreSprinting := false
global bRestoreAutorunning := false
global bRestoreAutofireAiming := false
global bRestoreAutofireCrouching := false
global bRestoreAutofireSprinting := false
global bToggleKeysSnapshotTaken := false
global nWindowID := 0

; Functors
global fnAutofireAim := 0
global fnAutofireCrouch := 0
global fnAutofireSprint := 0

Init()

; Exit script
ExitFunc(pExitReason, pExitCode)
{
	Output(A_ThisFunc "::pExitReason(" pExitReason ") pExitCode(" pExitCode ")")
	ReleaseAllKeys()
}

; Display an error message and exit
ExitWithErrorMessage(pErrorMessage)
{
	MsgBox(pErrorMessage, "Error", 16)
	ExitApp(1)
}

Init()
{
	ReadConfigFile()
	RestartAsAdminIfNeeded()
	SetTimer(OnFocusChanged, nFocusCheckInterval)
}

HookWindow()
{
	global

	; Make the hotkeys active only for a specific window
	nWindowID := WinGetID(sWindowName . " ahk_exe " . sProcessName)
	Output(A_ThisFunc "::WinGet(" nWindowID ")")
	GroupAdd("windowIDGroup", "ahk_id " nWindowID)

	if (nWindowID && bShowNotifications)
	{
		local lWindowName := WinGetTitle(nWindowID)
		TrayTip("KeyToggles", "The window `"" . lWindowName . "`" has been hooked.")
	}
}

IsMouseButton(pKey)
{
	mouseButtonsList := "LButton MButton RButton XButton1 XButton2"
	return InStr(mouseButtonsList, pKey) != false
}

IsMouseOver(pWinTitle)
{
	MouseGetPos(, , &winID)
	return WinExist(pWinTitle . " ahk_id " . winID)
}

IsMouseOverWindow(pHwnd)
{
	MouseGetPos(, , &mouseWindowID)
	return pHwnd == mouseWindowID
}

KeyAutofire(pAutofireKey)
{
	Output(A_ThisFunc "::begin")

	switch pAutofireKey
	{
		case aimAutofireKey:
			SendKey(aimKey, nKeyDelay)
		case crouchAutofireKey:
			SendKey(crouchKey, nKeyDelay)
		case sprintAutofireKey:
			SendKey(sprintKey, nKeyDelay)
	}

	Output(A_ThisFunc "::end")
}

KeyHold(pKey)
{
	;Output(A_ThisFunc "::begin")
	SendKey(pKey, nKeyDelay)
	KeyWait(pKey)
	SendKey(pKey, nKeyDelay)
	;Output(A_ThisFunc "::end")
}

KeyToggle(pKey, pToggle, pWait := false)
{
	global

	;Output(A_ThisFunc "::begin")

	switch pKey
	{
		case aimKey:
			bAiming := pToggle
		case crouchKey:
			bCrouching := pToggle
		case sprintKey:
			bSprinting := pToggle
		case forwardKey:
			bAutorunning := pToggle
	}

	Output(pKey == aimKey ? A_ThisFunc "::bAiming(" bAiming ")" : pKey == crouchKey ? A_ThisFunc "::bCrouching(" bCrouching ")" : pKey == sprintKey ? A_ThisFunc "::bSprinting(" bSprinting ")" : A_ThisFunc "::bAutorunning(" bAutorunning ")")

	SendInput(pToggle ? "{Blind}{" . pKey . " down}" : "{Blind}{" . pKey . " up}")

	if (pWait)
		KeyWait(pKey)

	;Output(A_ThisFunc "::end")
}

; Hook the window and register hotkeys if necessary, disable toggles on focus lost and optionally restore them on focus
OnFocusChanged()
{
	global

	Output(A_ThisFunc "::WinWaitActive")
	WinWaitActive(sWindowName . " ahk_exe " . sProcessName)
	Sleep(nHookDelay)

	; Make sure to hook the window again if it no longer exists
	if (nWindowID != WinExist(sWindowName . " ahk_exe " . sProcessName))
	{
		HookWindow()
		RegisterHotkeys()

		; That's a different window, don't restore toggle states
		bRestoreAiming := false
		bRestoreCrouching := false
		bRestoreSprinting := false
		bRestoreAutorunning := false
		bRestoreAutofireAiming := false
		bRestoreAutofireCrouching := false
		bRestoreAutofireSprinting := false
	}

	; Restore autofire toggle states
	if (ShouldRestoreAutofiresOnFocus())
	{
		Output(A_ThisFunc "::restoreAutofireToggleStates(" bRestoreAutofireAiming ", " bRestoreAutofireCrouching ", " bRestoreAutofireSprinting ")")

		if (bRestoreAutofireAiming)
			OnKeyPress(aimAutofireKey)
		if (bRestoreAutofireCrouching)
			OnKeyPress(crouchAutofireKey)
		if (bRestoreAutofireSprinting)
			OnKeyPress(sprintAutofireKey)
	}

	; Restore toggle states
	if (ShouldRestoreTogglesOnFocus())
	{
		Output(A_ThisFunc "::restoreToggleStates(" bRestoreAiming ", " bRestoreCrouching ", " bRestoreSprinting ")")

		if (bRestoreAiming)
			KeyToggle(aimKey, true)
		if (bRestoreCrouching)
			KeyToggle(crouchKey, true)
		if (bRestoreSprinting)
			KeyToggle(sprintKey, true)
		if (bRestoreAutorunning)
			KeyToggle(forwardKey, true)
	}

	Output(A_ThisFunc "::WinWaitNotActive")
	WinWaitNotActive(sWindowName " ahk_exe " . sProcessName)

	; Save toggle states
	if (ShouldRestoreTogglesOnFocus())
	{
		; A snapshot of the toggle states was already taken elsewhere, don't take another one
		if (bToggleKeysSnapshotTaken)
			bToggleKeysSnapshotTaken := false
		else
		{
			Output(A_ThisFunc "::saveToggleStates(" bRestoreAiming ", " bRestoreCrouching ", " bRestoreSprinting ")")

			bRestoreAiming := bAiming
			bRestoreCrouching := bCrouching
			bRestoreSprinting := bSprinting
			bRestoreAutorunning := bAutorunning
			bRestoreAutofireAiming := bAutofireAiming
			bRestoreAutofireCrouching := bAutofireCrouching
			bRestoreAutofireSprinting := bAutofireSprinting
		}
	}

	ReleaseAllKeys()
}

OnKeyPress(pThisHotkey)
{
	global

	local lCleanHotkey := LTrim(pThisHotkey, "~*$")
	local lKeyMode := KEY_MODE_DISABLED

	switch lCleanHotkey
	{
		case aimKey, aimAutofireKey:
			lKeyMode := bAimMode
		case crouchKey, crouchAutofireKey:
			lKeyMode := bCrouchMode
		case sprintKey, sprintAutofireKey:
			lKeyMode := bSprintMode
		case autorunKey:
			lKeyMode := bAutorunMode
		; Pressing the forward/backward key disables autorunning
		case forwardKey:
			bAutorunning := false
		case backwardKey:
			if (bAutorunning)
			{
				KeyToggle(forwardKey, false)
				KeyWait(backwardKey)
			}
	}

	;Output(A_ThisFunc "::" pThisHotkey " lKeyMode(" lKeyMode ")")

	switch lKeyMode
	{
		case KEY_MODE_TOGGLE, KEY_MODE_AUTORUN:
			lIsMouseButton := IsMouseButton(lCleanHotkey)
			lIsMouseOverWindow := IsMouseOverWindow(nWindowID)
			; Output(A_ThisFunc "::" lCleanHotkey " lIsMouseButton(" lIsMouseButton ") lIsMouseOverWindow(" lIsMouseOverWindow ")")

			; Fixes an issue where you couldn't click outside the window if the toggle key was a mouse button and toggled
			if (lIsMouseButton && !lIsMouseOverWindow)
			{
				;Output(A_ThisFunc "::" lCleanHotkey " outside window")
				SendClickOutsideWindow(lCleanHotkey)
			}
			; Otherwise toggle the key
			else
			{
				;Output(A_ThisFunc "::" lCleanHotkey " inside window")

				if (lCleanHotkey == aimKey)
					KeyToggle(aimKey, !bAiming, true)
				else if (lCleanHotkey == crouchKey)
					KeyToggle(crouchKey, !bCrouching, true)
				else if (lCleanHotkey == sprintKey)
					KeyToggle(sprintKey, !bSprinting, true)
				else if (lCleanHotkey == autorunKey)
				{
					; Autorun will engage even if the forward/backward key was physically pressed
					if (GetKeyState(backwardKey, "P"))
						SendKey(backwardKey)

					KeyWait(forwardKey)
					KeyToggle(forwardKey, !bAutorunning)
					KeyWait(autorunKey)
				}
			}
		case KEY_MODE_HOLD:
			KeyHold(lCleanHotkey)
		; Based on https://autohotkey.com/board/topic/64576-the-definitive-autofire-thread/?p=407264
		case KEY_MODE_AUTOFIRE:
			if (lCleanHotkey == aimAutofireKey)
			{
				bAutofireAiming := !bAutofireAiming
				SetTimer(fnAutofireAim, bAutofireAiming ? nAutofireKeyInterval : 0)
			}
			else if (lCleanHotkey == crouchAutofireKey)
			{
				bAutofireCrouching := !bAutofireCrouching
				SetTimer(fnAutofireCrouch, bAutofireCrouching ? nAutofireKeyInterval : 0)
			}
			else if (lCleanHotkey == sprintAutofireKey)
			{
				bAutofireSprinting := !bAutofireSprinting
				SetTimer(fnAutofireSprint, bAutofireSprinting ? nAutofireKeyInterval : 0)
			}

			KeyWait(lCleanHotkey)
		case KEY_MODE_AUTOFIRE_HOLD:
			Output(A_ThisFunc "::" lKeyMode " (" lKeyMode ")")
			Output(A_ThisFunc "::" lCleanHotkey " pressed")

			if (lCleanHotkey == aimAutofireKey)
				SetTimer(fnAutofireAim, nAutofireKeyInterval)
			else if (lCleanHotkey == crouchAutofireKey)
				SetTimer(fnAutofireCrouch, nAutofireKeyInterval)
			else if (lCleanHotkey == sprintAutofireKey)
				SetTimer(fnAutofireSprint, nAutofireKeyInterval)

			KeyWait(lCleanHotkey)

			if (lCleanHotkey == aimAutofireKey)
				SetTimer(fnAutofireAim, 0)
			else if (lCleanHotkey == crouchAutofireKey)
				SetTimer(fnAutofireCrouch, 0)
			else if (lCleanHotkey == sprintAutofireKey)
				SetTimer(fnAutofireSprint, 0)

			Output(A_ThisFunc "::" lCleanHotkey " released")
	}
}

Output(pMessage)
{
	if (bDebugMode)
		OutputDebug(pMessage . "`n")
}

ReadConfigFile()
{
	global

	SplitPath(A_ScriptName, , , , &configFileNameTrimmed)
	configFileName := "KeyToggles.ini"

	; Config file is missing, exit
	if (!FileExist(configFileName))
		ExitWithErrorMessage(configFileName . " not found! The script will now exit.")

	; General
	sProcessName := IniRead(configFileName, "General", "processName", "")
	sWindowName := IniRead(configFileName, "General", "windowName", "")
	nAutofireKeyInterval := IniRead(configFileName, "General", "autofireKeyInterval", 100)
	bFixSystemKeys := IniRead(configFileName, "General", "fixSystemKeys", 1)
	nFocusCheckInterval := IniRead(configFileName, "General", "focusCheckInterval", 1000)
	nHookDelay := IniRead(configFileName, "General", "hookDelay", 0)
	nKeyDelay := IniRead(configFileName, "General", "keyDelay", 0)
	bRestoreAutofiresOnFocus := IniRead(configFileName, "General", "restoreAutofiresOnFocus", 0)
	bRestoreTogglesOnFocus := IniRead(configFileName, "General", "restoreTogglesOnFocus", 0)
	bRunAsAdmin := IniRead(configFileName, "General", "runAsAdmin", 0)
	bShowNotifications := IniRead(configFileName, "General", "showNotifications", 0)
	bAimMode := IniRead(configFileName, "General", "aimMode", 0)
	bCrouchMode := IniRead(configFileName, "General", "crouchMode", 0)
	bSprintMode := IniRead(configFileName, "General", "sprintMode", 0)
	bAutorunMode := IniRead(configFileName, "General", "autorunMode", 0)

	; Main keys
	aimKey := IniRead(configFileName, "Keys", "aimKey", "RButton")
	crouchKey := IniRead(configFileName, "Keys", "crouchKey", "LCtrl")
	sprintKey := IniRead(configFileName, "Keys", "sprintKey", "LShift")

	; Autorun keys
	autorunKey := IniRead(configFileName, "Keys", "autorunKey", "F1")
	forwardKey := IniRead(configFileName, "Keys", "forwardKey", "w")
	backwardKey := IniRead(configFileName, "Keys", "backwardKey", "s")

	; Autofire keys
	aimAutofireKey := IniRead(configFileName, "Keys", "aimAutofireKey", "F2")
	crouchAutofireKey := IniRead(configFileName, "Keys", "crouchAutofireKey", "F3")
	sprintAutofireKey := IniRead(configFileName, "Keys", "sprintAutofireKey", "F4")

	; Debug
	bDebugMode := IniRead(configFileName, "Debug", "debugMode", 0)

	if (sProcessName == "")
		ExitWithErrorMessage("You must specify a process name! The script will now exit.")

	; Prevent timers from not working
	if (nAutofireKeyInterval <= 0)
		nAutofireKeyInterval := 1
	if (nFocusCheckInterval <= 0)
		nFocusCheckInterval := 1
}

RegisterHotkeys()
{
	global

	HotIfWinActive("ahk_group windowIDGroup")

	; Enabled only for toggle and hold modes
	Hotkey("*$" aimKey, OnKeyPress, bAimMode == KEY_MODE_TOGGLE || bAimMode == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" crouchKey, OnKeyPress, bCrouchMode == KEY_MODE_TOGGLE || bCrouchMode == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" sprintKey, OnKeyPress, bSprintMode == KEY_MODE_TOGGLE || bSprintMode == KEY_MODE_HOLD ? "On" : "Off")

	; Enabled only for autorun mode
	Hotkey("*$" autorunKey, OnKeyPress, bAutorunMode == KEY_MODE_AUTORUN ? "On" : "Off")
	Hotkey("~*$" forwardKey, OnKeyPress, bAutorunMode == KEY_MODE_AUTORUN ? "On" : "Off")
	Hotkey("~*$" backwardKey, OnKeyPress, bAutorunMode == KEY_MODE_AUTORUN ? "On" : "Off")

	; Enabled only for autofire modes
	Hotkey("*$" aimAutofireKey, OnKeyPress, bAimMode == KEY_MODE_AUTOFIRE || bAimMode == KEY_MODE_AUTOFIRE_HOLD  ? "On" : "Off")
	Hotkey("*$" crouchAutofireKey, OnKeyPress, bCrouchMode == KEY_MODE_AUTOFIRE || bCrouchMode == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")
	Hotkey("*$" sprintAutofireKey, OnKeyPress, bSprintMode == KEY_MODE_AUTOFIRE || bSprintMode == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")

	; Fixes issues when pressing system keys while toggle keys are modifiers and toggled
	Hotkey("*$" "!Tab", SendAltTab, bFixSystemKeys ? "On" : "Off")
	Hotkey("*$" "Escape", SendEscape, bFixSystemKeys ? "On" : "Off")
	Hotkey("*$" "LWin", SendWindows, bFixSystemKeys ? "On" : "Off")
	Hotkey("*$" "RWin", SendWindows, bFixSystemKeys ? "On" : "Off")

	; Bind our functors to actual functions
	fnAutofireAim := KeyAutofire.Bind(aimAutofireKey)
	fnAutofireCrouch := KeyAutofire.Bind(crouchAutofireKey)
	fnAutofireSprint := KeyAutofire.Bind(sprintAutofireKey)

	HotIfWinActive()
}

ReleaseAllKeys()
{
	global

	Output(A_ThisFunc "::states(" bAiming ", " bCrouching ", " bSprinting ", " bAutorunning ")")

	; Release all toggle keys
	if (bAiming)
		KeyToggle(aimKey, false)
	if (bCrouching)
		KeyToggle(crouchKey, false)
	if (bSprinting)
		KeyToggle(sprintKey, false)
	if (bAutorunning)
		KeyToggle(forwardKey, false)

	bAutofireAiming := false
	bAutofireCrouching := false
	bAutofireSprinting := false

	; Delete all autofire timers
	if (fnAutofireAim)
		SetTimer(fnAutofireAim, 0)
	if (fnAutofireCrouch)
		SetTimer(fnAutofireCrouch, 0)
	if (fnAutofireSprint)
		SetTimer(fnAutofireSprint, 0)
}

RestartAsAdminIfNeeded()
{
	; Restart the script as admin
	if (bRunAsAdmin && !A_IsAdmin)
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

SendAltTab(pThisHotkey)
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

SendClickOutsideWindow(pKey)
{
	;Output(A_ThisFunc "::begin")

	; Take a snapshot of the toggle states
	if (ShouldRestoreTogglesOnFocus())
		TakeToggleKeysSnapshot(false)

	ReleaseAllKeys()
	SendKey(pKey, 0, true)

	;Output(A_ThisFunc "::end")
}

SendEscape(pThisHotkey)
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

SendKey(pKey, pSleepMs := 0, pWait := false)
{
	SendInput("{Blind}{" . pKey . " down}")

	if (pSleepMs > 0)
		Sleep(pSleepMs)

	if (pWait)
		KeyWait(pKey)

	SendInput("{Blind}{" . pKey . " up}")
}

SendWindows(pThisHotkey)
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
	return bRestoreAutofiresOnFocus && (bAimMode == KEY_MODE_AUTOFIRE || bCrouchMode == KEY_MODE_AUTOFIRE || bSprintMode == KEY_MODE_AUTOFIRE) && (WinExist("ahk_id " nWindowID) != 0)
}

ShouldRestoreTogglesOnFocus()
{
	return bRestoreTogglesOnFocus && (bAimMode == KEY_MODE_TOGGLE || bCrouchMode == KEY_MODE_TOGGLE || bSprintMode == KEY_MODE_TOGGLE) && (WinExist("ahk_id " nWindowID) != 0)
}

TakeToggleKeysSnapshot(pReleaseKeys := true)
{
	global

	bRestoreAiming := bAiming
	bRestoreCrouching := bCrouching
	bRestoreSprinting := bSprinting
	bRestoreAutorunning := bAutorunning
	bRestoreAutofireAiming := bAutofireAiming
	bRestoreAutofireCrouching := bAutofireCrouching
	bRestoreAutofireSprinting := bAutofireSprinting
	bToggleKeysSnapshotTaken := true

	if (pReleaseKeys)
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
	if (!IsMouseOverWindow(nWindowID))
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
#HotIf bDebugMode
; Exit script
*!F10::ExitApp() ; ALT+F10

; Reload script
*!F11::Reload() ; ALT+F11
#HotIf

; Suspend script (useful when in menus)
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
