; KeyToggles v2.0

; TODO
; add application profiles (https://stackoverflow.com/questions/45190170/how-can-i-make-this-ini-file-into-a-listview-in-autohotkey)
; add autofire hold mode
; add cursor lock? (https://www.autohotkey.com/boards/viewtopic.php?t=66966)
; add overlay
; fix toggle off not working when physically holding toggle keys
; implement super global variables
; merge similar functions
; redo window detection? (https://www.reddit.com/r/AutoHotkey/comments/nmewd1/resize_and_move_a_window_every_time_it_gets/gzoogts)

#MaxThreadsPerHotkey 1     ; Prevent accidental double-presses.
#Requires Autohotkey v2.0  ; Display an error and quit if this version requirement is not met.
#SingleInstance force      ; Allow only a single instance of the script to run.
;#UseHook                   ; Allow listening for non-modifier keys.
#Warn                      ; Enable warnings to assist with detecting common errors.
SetWorkingDir(A_ScriptDir) ; Ensures a consistent starting directory.

; Register a function to be called on exit
OnExit(ExitFunc)

; Constants
KEY_MODE_TOGGLE := 1
KEY_MODE_HOLD := 2
KEY_MODE_AUTOFIRE := 3

; Initialize state variables
bAiming := false
bCrouching := false
bSprinting := false
bAutofireAiming := false
bAutofireCrouching := false
bAutofireSprinting := false
bRestoreAiming := false
bRestoreCrouching := false
bRestoreSprinting := false
bToggleKeysSnapshotTaken := false
windowID := 0

init()
return

init()
{
	ReadConfigFile()
	RestartAsAdminIfNeeded()
	SetTimer(OnFocusChanged, nFocusCheckDelay)
}

aimLabel(pThisHotkey)
{
	global

	;OutputDebug(A_ThisFunc "::" A_ThisHotkey " begin")

	switch bAimMode
	{
		case KEY_MODE_TOGGLE:
			lIsMouseButton := IsMouseButton(A_ThisHotkey)
			lIsMouseOverWindow := IsMouseOverWindow(windowID)
			; OutputDebug(A_ThisFunc "::" A_ThisHotkey " lIsMouseButton(" lIsMouseButton ") lIsMouseOverWindow(" lIsMouseOverWindow ")")

			; Fixes an issue where you couldn't click outside the window if the toggle key was a mouse button and was enabled
			if (lIsMouseButton && !lIsMouseOverWindow)
			{
				;OutputDebug(A_ThisFunc "::" A_ThisHotkey " outside window")
				SendClickOutsideWindow(LTrim(A_ThisHotkey, "*$"))
			}
			; Otherwise toggle the key
			else
			{
				;OutputDebug(A_ThisFunc "::" A_ThisHotkey " inside window")
				AimToggle(!bAiming, true)
			}
		case KEY_MODE_HOLD:
			AimHold()
		case KEY_MODE_AUTOFIRE:
			; Based on https://autohotkey.com/board/topic/64576-the-definitive-autofire-thread/?p=407264
			bAutofireAiming := !bAutofireAiming
			SetTimer(AimAutofire,bAutofireAiming ? nAutofireKeyDelay : "Off")
			KeyWait(aimAutofireKey)
	}
}

crouchLabel(pThisHotkey)
{
	global

	;OutputDebug(A_ThisFunc "::" A_ThisHotkey " begin")
	;OutputDebug(A_ThisFunc "::" A_ThisHotkey " bCrouchMode(" bCrouchMode ")")

	switch bCrouchMode
	{
		case KEY_MODE_TOGGLE:
			lIsMouseButton := IsMouseButton(A_ThisHotkey)
			lIsMouseOverWindow := IsMouseOverWindow(windowID)
			OutputDebug(A_ThisFunc "::" A_ThisHotkey " lIsMouseButton(" lIsMouseButton ") lIsMouseOverWindow(" lIsMouseOverWindow ")")

			if (lIsMouseButton && !lIsMouseOverWindow)
			{
				;OutputDebug(A_ThisFunc "::" A_ThisHotkey " outside window")
				SendClickOutsideWindow(LTrim(A_ThisHotkey, "*$"))
			}
			else
			{
				;OutputDebug(A_ThisFunc "::" A_ThisHotkey " inside window")
				CrouchToggle(!bCrouching, true)
			}
		case KEY_MODE_HOLD:
			CrouchHold()
		case KEY_MODE_AUTOFIRE:
			bAutofireCrouching := !bAutofireCrouching
			SetTimer(CrouchAutofire,bAutofireCrouching ? nAutofireKeyDelay : "Off")
			KeyWait(crouchAutofireKey)
	}
}

sprintLabel(pThisHotkey)
{
	global

	;OutputDebug(A_ThisFunc "::" A_ThisHotkey " begin")

	switch bSprintMode
	{
		case KEY_MODE_TOGGLE:
			lIsMouseButton := IsMouseButton(A_ThisHotkey)
			lIsMouseOverWindow := IsMouseOverWindow(windowID)
			; OutputDebug(A_ThisFunc "::" A_ThisHotkey " lIsMouseButton(" lIsMouseButton ") lIsMouseOverWindow(" lIsMouseOverWindow ")")

			if (lIsMouseButton && !lIsMouseOverWindow)
			{
				;OutputDebug(A_ThisFunc "::" A_ThisHotkey " outside window")
				SendClickOutsideWindow(LTrim(A_ThisHotkey, "*$"))
			}
			else
			{
				;OutputDebug(A_ThisFunc "::" A_ThisHotkey " inside window")
				SprintToggle(!bSprinting, true)
			}
		case KEY_MODE_HOLD:
			SprintHold()
		case KEY_MODE_AUTOFIRE:
			bAutofireSprinting := !bAutofireSprinting
			SetTimer(SprintAutofire,bAutofireSprinting ? nAutofireKeyDelay : "Off")
			KeyWait(sprintAutofireKey)
	}
}

AimAutofire()
{
	global

	;OutputDebug(A_ThisFunc "::begin")
	SendKey(aimKey, nKeyDelay)
	;OutputDebug(A_ThisFunc "::end")
}

AimHold()
{
	global

	;OutputDebug(A_ThisFunc "::begin")
	SendKey(aimKey, nKeyDelay)
	KeyWait(aimKey)
	SendKey(aimKey, nKeyDelay)
	;OutputDebug(A_ThisFunc "::end")
}

AimToggle(pAiming, pWait := false)
{
	global

	;OutputDebug(A_ThisFunc "::begin")
	bAiming := pAiming
	;OutputDebug(A_ThisFunc "::bAiming(" bAiming ")")

	SendInput(bAiming ? "{Blind}{" . aimKey . " down}" : "{Blind}{" . aimKey . " up}")

	if (pWait)
		KeyWait(aimKey)

	;OutputDebug(A_ThisFunc "::end")
}


CrouchAutofire()
{
	global

	;OutputDebug(A_ThisFunc "::begin")
	SendKey(crouchKey, nKeyDelay)
	;OutputDebug(A_ThisFunc "::end")
}

CrouchHold()
{
	global

	OutputDebug(A_ThisFunc "::begin")
	SendKey(crouchKey, nKeyDelay)
	OutputDebug(A_ThisFunc "::KeyWait begin")
	KeyWait(crouchKey)
	OutputDebug(A_ThisFunc "::KeyWait end")
	SendKey(crouchKey, nKeyDelay)
	OutputDebug(A_ThisFunc "::end")
}

CrouchToggle(pCrouching, pWait := false)
{
	global

	OutputDebug(A_ThisFunc "::begin")
	bCrouching := pCrouching
	OutputDebug(A_ThisFunc "::bCrouching(" bCrouching ")")

	;SendInput(bCrouching ? "{Blind}{" . crouchKey . " down}" : "{Blind}{" . crouchKey . " up}")
	SendInput(bCrouching ? "{Blind}{" . crouchKey . " down}" : "{Blind}{" . crouchKey . " up}")

	if (pWait)
		KeyWait(crouchKey)

	OutputDebug(A_ThisFunc "::end")
}

HookWindow()
{
	; All the variables below are declared as global so they can be used in the whole script
	global

	; Make the hotkeys active only for a specific window
	windowID := WinGetID(sWindowName)
	OutputDebug(A_ThisFunc "::WinGet(" windowID ")")
	GroupAdd("windowIDGroup", "ahk_id " windowID)

	if (windowID && bShowNotifications)
	{
		local lWindowName := WinGetTitle(windowID)
		TrayTip(configFileNameTrimmed, "The window `"" . lWindowName . "`" has been hooked.")
	}
}

IsMouseButton(pKey)
{
	mouseButtonsList := "LButton MButton RButton XButton1 XButton2 *$LButton *$MButton *$RButton *$XButton1 *$XButton2"
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

; Hook the window and register hotkeys if necessary, disable toggles on focus lost and optionally restore them on focus
OnFocusChanged()
{
	global

	OutputDebug(A_ThisFunc "::WinWaitActive")
	WinWaitActive(sWindowName)
	Sleep(nHookDelay)

	; Make sure to hook the window again if it no longer exists
	if (windowID != WinExist(sWindowName))
	{
		HookWindow()
		RegisterHotkeys()

		; That's a different window, don't restore toggle states
		bRestoreAiming := false
		bRestoreCrouching := false
		bRestoreSprinting := false
	}

	; Restore toggle states
	if (ShouldRestoreTogglesOnFocus())
	{
		OutputDebug(A_ThisFunc "::saveToggleStates(" bRestoreAiming ", " bRestoreCrouching ", " bRestoreSprinting ")")

		if (bRestoreAiming)
			AimToggle(true)
		if (bRestoreCrouching)
			CrouchToggle(true)
		if (bRestoreSprinting)
			SprintToggle(true)
	}

	OutputDebug(A_ThisFunc "::WinWaitNotActive")
	WinWaitNotActive(sWindowName)

	; Save toggle states
	if (ShouldRestoreTogglesOnFocus())
	{
		; A snapshot of the toggle states was already taken elsewhere, don't take another one
		if (bToggleKeysSnapshotTaken)
			bToggleKeysSnapshotTaken := false
		else
		{
			OutputDebug(A_ThisFunc "::saveToggleStates(" bRestoreAiming ", " bRestoreCrouching ", " bRestoreSprinting ")")

			bRestoreAiming := bAiming
			bRestoreCrouching := bCrouching
			bRestoreSprinting := bSprinting
		}
	}

	ReleaseAllKeys()
}

ReadConfigFile()
{
	; All the variables below are declared as global so they can be used in the whole script
	global

	SplitPath(A_ScriptName, , , , &configFileNameTrimmed)
	configFileName := configFileNameTrimmed . ".ini"

	; Config file is missing, exit
	if (!FileExist(configFileName))
		ExitWithErrorMessage(configFileName . " not found! The script will now exit.")

	; General
	sWindowName := IniRead(configFileName, "General", "windowName", "`"put_window_name_here`"")
	bAimMode := IniRead(configFileName, "General", "aimMode", 1)
	bCrouchMode := IniRead(configFileName, "General", "crouchMode", 1)
	bSprintMode := IniRead(configFileName, "General", "sprintMode", 1)
	nAutofireKeyDelay := IniRead(configFileName, "General", "autofireKeyDelay", 100)
	bFixSystemKeys := IniRead(configFileName, "General", "fixSystemKeys", 1)
	nFocusCheckDelay := IniRead(configFileName, "General", "focusCheckDelay", 1000)
	nHookDelay := IniRead(configFileName, "General", "hookDelay", 0)
	nKeyDelay := IniRead(configFileName, "General", "keyDelay", 0)
	bRestoreTogglesOnFocus := IniRead(configFileName, "General", "restoreTogglesOnFocus", 0)
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

	if (sWindowName == "put_window_name_here")
		ExitWithErrorMessage("You must specify a window name! The script will now exit.")
}

RegisterHotkeys()
{
	global

	HotIfWinActive("ahk_group windowIDGroup")
	; Enabled only for toggle and hold modes
	Hotkey("*$" aimKey, aimLabel, bAimMode == KEY_MODE_TOGGLE || bAimMode == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" crouchKey, crouchLabel, bCrouchMode == KEY_MODE_TOGGLE || bCrouchMode == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" sprintKey, sprintLabel, bSprintMode == KEY_MODE_TOGGLE || bSprintMode == KEY_MODE_HOLD ? "On" : "Off")

	; Enabled only for autofire mode
	Hotkey(aimAutofireKey, aimLabel, bAimMode == KEY_MODE_AUTOFIRE ? "On" : "Off")
	Hotkey(crouchAutofireKey, crouchLabel, bCrouchMode == KEY_MODE_AUTOFIRE ? "On" : "Off")
	Hotkey(sprintAutofireKey, sprintLabel, bSprintMode == KEY_MODE_AUTOFIRE ? "On" : "Off")

	; Fixes issues when pressing system keys while toggle keys are modifiers and are enabled
	Hotkey("*$" "!Tab", SendAltTab, bFixSystemKeys ? "On" : "Off")
	Hotkey("*$" "Escape", SendEscape, bFixSystemKeys ? "On" : "Off")
	Hotkey("*$" "LWin", SendWindows, bFixSystemKeys ? "On" : "Off")
	Hotkey("*$" "RWin", SendWindows, bFixSystemKeys ? "On" : "Off")
	HotIfWinActive()
}

ReleaseAllKeys()
{
	global

	OutputDebug(A_ThisFunc "::states(" bAiming ", " bCrouching ", " bSprinting ")")

	if (bAiming)
		AimToggle(false)
	if (bCrouching)
		CrouchToggle(false)
	if (bSprinting)
		SprintToggle(false)

	bAutofireAiming := false
	bAutofireCrouching := false
	bAutofireSprinting := false

	SetTimer(AimAutofire, 0)
	SetTimer(CrouchAutofire, 0)
	SetTimer(SprintAutofire, 0)
}

RestartAsAdminIfNeeded()
{
	global

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
	;OutputDebug(A_ThisFunc "::begin")

	; Take a snapshot of the toggle states
	if (ShouldRestoreTogglesOnFocus())
		TakeToggleKeysSnapshot()

	; Check if modifier keys are physically pressed to handle Ctrl+Alt+Tab, Shift+Alt+Tab and Ctrl+Shift+Alt+Tab
	if (GetKeyState("Control", "P"))
		SendInput("{Blind}{Control down}")
	if (GetKeyState("Shift", "P"))
		SendInput("{Blind}{Shift down}")

	SendInput("{Blind}{Alt down}{Tab}")
	;OutputDebug(A_ThisFunc "::end")
}

SendClickOutsideWindow(pKey)
{
	;OutputDebug(A_ThisFunc "::begin")

	; Take a snapshot of the toggle states
	if (ShouldRestoreTogglesOnFocus())
		TakeToggleKeysSnapshot()

	SendKey(pKey, 0, true)

	;OutputDebug(A_ThisFunc "::end")
}

SendEscape(pThisHotkey)
{
	;OutputDebug(A_ThisFunc "::begin")

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

	;OutputDebug(A_ThisFunc "::end")
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
	;OutputDebug(A_ThisFunc "::begin")

	; Take a snapshot of the toggle states
	if (ShouldRestoreTogglesOnFocus())
		TakeToggleKeysSnapshot()

	; Check if modifier keys are physically pressed to handle Shift+Win
	if (GetKeyState("Shift", "P"))
		SendInput("{Blind}{Shift down}")

	SendInput("{Blind}{LWin}")

	;OutputDebug(A_ThisFunc "::end")
}

ShouldRestoreTogglesOnFocus()
{
	global
	return bRestoreTogglesOnFocus && (bAimMode == KEY_MODE_TOGGLE || bCrouchMode == KEY_MODE_TOGGLE || bSprintMode == KEY_MODE_TOGGLE) && (WinExist("ahk_id " windowID) != 0)
}

SprintAutofire()
{
	global

	;OutputDebug(A_ThisFunc "::begin")
	SendKey(sprintKey, nKeyDelay)
	;OutputDebug(A_ThisFunc "::end")
}

SprintHold()
{
	global

	;OutputDebug(A_ThisFunc "::begin")
	SendKey(sprintKey, nKeyDelay)
	KeyWait(sprintKey)
	SendKey(sprintKey, nKeyDelay)
	;OutputDebug(A_ThisFunc "::end")
}

SprintToggle(pSprinting, pWait := false)
{
	global

	;OutputDebug(A_ThisFunc "::begin")
	bSprinting := pSprinting
	;OutputDebug(A_ThisFunc "::bSprinting(" bSprinting ")")

	SendInput(bSprinting ? "{Blind}{" . sprintKey . " down}" : "{Blind}{" . sprintKey . " up}")

	if (pWait)
		KeyWait(sprintKey)

	;OutputDebug(A_ThisFunc "::end")
}

TakeToggleKeysSnapshot(pReleaseKeys := true)
{
	global

	bRestoreAiming := bAiming
	bRestoreCrouching := bCrouching
	bRestoreSprinting := bSprinting
	bToggleKeysSnapshotTaken := true

	if (pReleaseKeys)
		ReleaseAllKeys()
}

; Exit script
ExitFunc(pExitReason, pExitCode)
{
	OutputDebug(A_ThisFunc "::pExitReason(" pExitReason ") pExitCode(" pExitCode ")")
	ReleaseAllKeys()
}

; Display an error message and exit
ExitWithErrorMessage(pErrorMessage)
{
	MsgBox(pErrorMessage, "Error", 16)
	ExitApp(1)
}

; Fixes an issue where you couldn't click outside the window while toggle keys are mouse buttons and are enabled
#HotIf WinActive("ahk_group windowIDGroup")
*$LButton::
*$MButton::
*$RButton::
*$XButton1::
*$XButton2::
{
	;global

	if (!IsMouseOverWindow(windowID))
	{
		;OutputDebug(A_ThisHotkey "::outside window")
		SendClickOutsideWindow(LTrim(A_ThisHotkey, "*$"))
	}
	else
	{
		;OutputDebug(A_ThisHotkey "::inside window")
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
	global
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
