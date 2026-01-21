; KeyToggles v2.0

; TODO
; add application profiles (https://stackoverflow.com/questions/45190170/how-can-i-make-this-ini-file-into-a-listview-in-autohotkey)
; add cursor lock? (https://www.autohotkey.com/boards/viewtopic.php?t=66966)
; add overlay
; add setTitleWindowMatch
; fix toggles not working when physically holding another toggle key (https://www.reddit.com/r/AutoHotkey/comments/oh65o2/comment/h4phdwu/)
; redo window detection? (https://www.reddit.com/r/AutoHotkey/comments/nmewd1/resize_and_move_a_window_every_time_it_gets/gzoogts)

#Requires Autohotkey v2.0  ; Display an error and quit if this version requirement is not met.
#SingleInstance force      ; Allow only a single instance of the script to run.
;#UseHook                   ; Allow listening for non-modifier keys.
#Warn                      ; Enable warnings to assist with detecting common errors.
SetWorkingDir(A_ScriptDir) ; Ensures a consistent starting directory.

; Register a function to be called on exit
OnExit(ExitFunc)

; Constants
global KEY_MODE_TOGGLE := 1
global KEY_MODE_HOLD := 2
global KEY_MODE_AUTOFIRE := 3
global KEY_MODE_AUTOFIRE_HOLD := 4

; Initialize state variables
global bAiming := false
global bCrouching := false
global bSprinting := false
global bAutofireAiming := false
global bAutofireCrouching := false
global bAutofireSprinting := false
global bRestoreAiming := false
global bRestoreCrouching := false
global bRestoreSprinting := false
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
	SetTimer(OnFocusChanged, nFocusCheckDelay)
}

HookWindow()
{
	global

	; Make the hotkeys active only for a specific window
	nWindowID := WinGetID(sWindowName)
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

KeyToggle(pKey, pToggling, pWait := false)
{
	global

	;Output(A_ThisFunc "::begin")

	switch pKey
	{
		case aimKey:
			bAiming := pToggling
		case crouchKey:
			bCrouching := pToggling
		case sprintKey:
			bSprinting := pToggling
	}

	Output(pKey == aimKey ? A_ThisFunc "::bAiming(" bAiming ")" : pKey == crouchKey ? A_ThisFunc "::bCrouching(" bCrouching ")" : A_ThisFunc "::bSprinting(" bSprinting ")")

	SendInput(pToggling ? "{Blind}{" . pKey . " down}" : "{Blind}{" . pKey . " up}")

	if (pWait)
		KeyWait(pKey)

	;Output(A_ThisFunc "::end")
}

; Hook the window and register hotkeys if necessary, disable toggles on focus lost and optionally restore them on focus
OnFocusChanged()
{
	global

	Output(A_ThisFunc "::WinWaitActive")
	WinWaitActive(sWindowName)
	Sleep(nHookDelay)

	; Make sure to hook the window again if it no longer exists
	if (nWindowID != WinExist(sWindowName))
	{
		HookWindow()
		RegisterHotkeys()

		; That's a different window, don't restore toggle states
		bRestoreAiming := false
		bRestoreCrouching := false
		bRestoreSprinting := false
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
	}

	Output(A_ThisFunc "::WinWaitNotActive")
	WinWaitNotActive(sWindowName)

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
	
	local pThisHotkeyTrimmed := LTrim(pThisHotkey, "*$")
	local lKeyMode := 0

	switch pThisHotkeyTrimmed
	{
		case aimKey, aimAutofireKey:
			lKeyMode := bAimMode
		case crouchKey, crouchAutofireKey:
			lKeyMode := bCrouchMode
		case sprintKey, sprintAutofireKey:
			lKeyMode := bSprintMode
	}

	;Output(A_ThisFunc "::" pThisHotkey " lKeyMode(" lKeyMode ")")

	switch lKeyMode
	{
		case KEY_MODE_TOGGLE:
			lIsMouseButton := IsMouseButton(pThisHotkeyTrimmed)
			lIsMouseOverWindow := IsMouseOverWindow(nWindowID)
			; Output(A_ThisFunc "::" pThisHotkeyTrimmed " lIsMouseButton(" lIsMouseButton ") lIsMouseOverWindow(" lIsMouseOverWindow ")")

			; Fixes an issue where you couldn't click outside the window if the toggle key was a mouse button and was enabled
			if (lIsMouseButton && !lIsMouseOverWindow)
			{
				;Output(A_ThisFunc "::" pThisHotkeyTrimmed " outside window")
				SendClickOutsideWindow(pThisHotkeyTrimmed)
			}
			; Otherwise toggle the key
			else
			{
				;Output(A_ThisFunc "::" pThisHotkeyTrimmed " inside window")

				if (pThisHotkeyTrimmed == aimKey)
					KeyToggle(aimKey, !bAiming, true)
				else if(pThisHotkeyTrimmed == crouchKey)
					KeyToggle(crouchKey, !bCrouching, true)
				else if(pThisHotkeyTrimmed == sprintKey)
					KeyToggle(sprintKey, !bSprinting, true)
			}
		case KEY_MODE_HOLD:
			KeyHold(pThisHotkeyTrimmed)
		; Based on https://autohotkey.com/board/topic/64576-the-definitive-autofire-thread/?p=407264
		case KEY_MODE_AUTOFIRE:
			if (pThisHotkeyTrimmed == aimAutofireKey)
			{
				bAutofireAiming := !bAutofireAiming
				SetTimer(fnAutofireAim, bAutofireAiming ? nAutofireKeyDelay : 0)
			}
			else if (pThisHotkeyTrimmed == crouchAutofireKey)
			{
				bAutofireCrouching := !bAutofireCrouching
				SetTimer(fnAutofireCrouch, bAutofireCrouching ? nAutofireKeyDelay : 0)
			}
			else if (pThisHotkeyTrimmed == sprintAutofireKey)
			{
				bAutofireSprinting := !bAutofireSprinting
				SetTimer(fnAutofireSprint, bAutofireSprinting ? nAutofireKeyDelay : 0)
			}

			KeyWait(pThisHotkeyTrimmed)
		case KEY_MODE_AUTOFIRE_HOLD:
			Output(A_ThisFunc "::" lKeyMode " (" lKeyMode ")")
			Output(A_ThisFunc "::" pThisHotkeyTrimmed " pressed")

			if (pThisHotkeyTrimmed == aimAutofireKey)
				SetTimer(fnAutofireAim, nAutofireKeyDelay)
			else if (pThisHotkeyTrimmed == crouchAutofireKey)
				SetTimer(fnAutofireCrouch, nAutofireKeyDelay)
			else if (pThisHotkeyTrimmed == sprintAutofireKey)
				SetTimer(fnAutofireSprint, nAutofireKeyDelay)

			KeyWait(pThisHotkeyTrimmed)

			if (pThisHotkeyTrimmed == aimAutofireKey)
				SetTimer(fnAutofireAim, 0)
			else if (pThisHotkeyTrimmed == crouchAutofireKey)
				SetTimer(fnAutofireCrouch, 0)
			else if (pThisHotkeyTrimmed == sprintAutofireKey)
				SetTimer(fnAutofireSprint, 0)

			Output(A_ThisFunc "::" pThisHotkeyTrimmed " released")
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
	sWindowName := IniRead(configFileName, "General", "windowName", "")
	bAimMode := IniRead(configFileName, "General", "aimMode", 1)
	bCrouchMode := IniRead(configFileName, "General", "crouchMode", 1)
	bSprintMode := IniRead(configFileName, "General", "sprintMode", 1)
	nAutofireKeyDelay := IniRead(configFileName, "General", "autofireKeyDelay", 100)
	bFixSystemKeys := IniRead(configFileName, "General", "fixSystemKeys", 1)
	nFocusCheckDelay := IniRead(configFileName, "General", "focusCheckDelay", 1000)
	nHookDelay := IniRead(configFileName, "General", "hookDelay", 0)
	nKeyDelay := IniRead(configFileName, "General", "keyDelay", 0)
	bRestoreTogglesOnFocus := IniRead(configFileName, "General", "restoreTogglesOnFocus", 0)
	bRestoreAutofiresOnFocus := IniRead(configFileName, "General", "restoreAutofiresOnFocus", 0)
	bShowNotifications := IniRead(configFileName, "General", "showNotifications", 0)
	bRunAsAdmin := IniRead(configFileName, "General", "runAsAdmin", 0)

	; Keys
	aimKey := IniRead(configFileName, "Keys", "aimKey", "RButton")
	crouchKey := IniRead(configFileName, "Keys", "crouchKey", "LCtrl")
	sprintKey := IniRead(configFileName, "Keys", "sprintKey", "LShift")
	aimAutofireKey := IniRead(configFileName, "Keys", "aimAutofireKey", "F1")
	crouchAutofireKey := IniRead(configFileName, "Keys", "crouchAutofireKey", "F2")
	sprintAutofireKey := IniRead(configFileName, "Keys", "sprintAutofireKey", "F3")

	; Debug
	bDebugMode := IniRead(configFileName, "Debug", "debugMode", 0)

	if (sWindowName == "" || sWindowName == "put_window_name_here")
		ExitWithErrorMessage("You must specify a window name! The script will now exit.")
}

RegisterHotkeys()
{
	global

	HotIfWinActive("ahk_group windowIDGroup")
	; Enabled only for toggle and hold modes
	Hotkey("*$" aimKey, OnKeyPress, bAimMode == KEY_MODE_TOGGLE || bAimMode == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" crouchKey, OnKeyPress, bCrouchMode == KEY_MODE_TOGGLE || bCrouchMode == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" sprintKey, OnKeyPress, bSprintMode == KEY_MODE_TOGGLE || bSprintMode == KEY_MODE_HOLD ? "On" : "Off")

	; Enabled only for autofire mode
	Hotkey("*$" aimAutofireKey, OnKeyPress, bAimMode == KEY_MODE_AUTOFIRE || bAimMode == KEY_MODE_AUTOFIRE_HOLD  ? "On" : "Off")
	Hotkey("*$" crouchAutofireKey, OnKeyPress, bCrouchMode == KEY_MODE_AUTOFIRE || bCrouchMode == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")
	Hotkey("*$" sprintAutofireKey, OnKeyPress, bSprintMode == KEY_MODE_AUTOFIRE || bSprintMode == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")

	; Fixes issues when pressing system keys while toggle keys are modifiers and are enabled
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

	Output(A_ThisFunc "::states(" bAiming ", " bCrouching ", " bSprinting ")")

	if (bAiming)
		KeyToggle(aimKey, false)
	if (bCrouching)
		KeyToggle(crouchKey, false)
	if (bSprinting)
		KeyToggle(sprintKey, false)

	bAutofireAiming := false
	bAutofireCrouching := false
	bAutofireSprinting := false

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
				Run("*RunAs `"" A_ScriptFullPath "`" /restart")
			else
				Run("*RunAs `"" A_AhkPath "`" /restart `"" A_ScriptFullPath "`"")

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
		TakeToggleKeysSnapshot()

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
