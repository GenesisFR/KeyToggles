; KeyToggles v1.4

;TODO
; add application profiles (https://stackoverflow.com/questions/45190170/how-can-i-make-this-ini-file-into-a-listview-in-autohotkey)
; add overlay/notifications

#MaxThreadsPerHotkey 1           ; Prevent accidental double-presses.
#NoEnv                           ; Recommended for performance and compatibility with future AutoHotkey releases.
#Persistent                      ; Keep the script permanently running since we use a timer.
#Requires AutoHotkey v1.1.33.02+ ; Display an error and quit if this version requirement is not met.
#SingleInstance force            ; Allow only a single instance of the script to run.
#UseHook                         ; Allow listening for non-modifier keys.
#Warn                            ; Enable warnings to assist with detecting common errors.
SendMode Input                   ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%      ; Ensures a consistent starting directory.

; Register a function to be called on exit
OnExit("ExitFunc")

; Constants
AIM_MODE_TOGGLE := 1
AIM_MODE_HOLD := 2
AIM_MODE_AUTOFIRE := 3

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
windowID := 0

configFileNameTrimmed := RTrim(A_ScriptName, A_IsCompiled ? ".exe" : ".ahk")
configFileName := configFileNameTrimmed . ".ini"
OutputDebug, init::configFileName %configFileName%

; Config file is missing, exit
if (!FileExist(configFileName))
	ExitWithErrorMessage(configFileName . " not found! The script will now exit.")

ReadConfigFile()
SetTimer, OnFocusChanged, %focusCheckDelay%

return

aimLabel:

;OutputDebug, %A_ThisLabel%::%A_ThisHotkey% begin

switch bAimMode
{
	case AIM_MODE_TOGGLE:
		AimToggle(!bAiming, true)
		return
	case AIM_MODE_HOLD:
		AimHold()
		return
	case AIM_MODE_AUTOFIRE:
		; Based on https://autohotkey.com/board/topic/64576-the-definitive-autofire-thread/?p=407264
		bAutofireAiming := !bAutofireAiming
		SetTimer, AimAutofire, % bAutofireAiming ? autofireKeyDelay : "Off"
		KeyWait, %aimAutofireKey%
		return
}

;OutputDebug, %A_ThisLabel%::%A_ThisHotkey% end

return

crouchLabel:

;OutputDebug, %A_ThisLabel%::%A_ThisHotkey% begin

switch bCrouchMode
{
	case AIM_MODE_TOGGLE:
		CrouchToggle(!bCrouching, true)
		return
	case AIM_MODE_HOLD:
		CrouchHold()
		return
	case AIM_MODE_AUTOFIRE:
		bAutofireCrouching := !bAutofireCrouching
		SetTimer, CrouchAutofire, % bAutofireCrouching ? autofireKeyDelay : "Off"
		KeyWait, %crouchAutofireKey%
		return
}

;OutputDebug, %A_ThisLabel%::%A_ThisHotkey% end

return

sprintLabel:

;OutputDebug, %A_ThisLabel%::%A_ThisHotkey% begin

switch bSprintMode
{
	case AIM_MODE_TOGGLE:
		SprintToggle(!bSprinting, true)
		return
	case AIM_MODE_HOLD:
		SprintHold()
		return
	case AIM_MODE_AUTOFIRE:
		bAutofireSprinting := !bAutofireSprinting
		SetTimer, SprintAutofire, % bAutofireSprinting ? autofireKeyDelay : "Off"
		KeyWait, %sprintAutofireKey%
		return
}

;OutputDebug, %A_ThisLabel%::%A_ThisHotkey% end

return

AimAutofire()
{
	global

	;OutputDebug, %A_ThisFunc%::begin

	SendInput % "{" . aimKey . " down}"
	Sleep, %keyDelay%
	SendInput % "{" . aimKey . " up}"

	;OutputDebug, %A_ThisFunc%::end
}

AimHold()
{
	global

	;OutputDebug, %A_ThisFunc%::begin
	;OutputDebug, %A_ThisFunc%::press

	SendInput % "{" . aimKey . " down}"
	Sleep, %keyDelay%
	SendInput % "{" . aimKey . " up}"

	KeyWait, %aimKey%

	;OutputDebug, %A_ThisFunc%::release
	SendInput % "{" . aimKey . " down}"
	Sleep, %keyDelay%
	SendInput % "{" . aimKey . " up}"

	;OutputDebug, %A_ThisFunc%::end
}

AimToggle(pAiming, pWait := false)
{
	global

	;OutputDebug, %A_ThisFunc%::begin
	bAiming := pAiming
	;OutputDebug, %A_ThisFunc%::bAiming %bAiming%

	SendInput % bAiming ? "{" . aimKey . " down}" : "{" . aimKey . " up}"

	if (pWait)
		KeyWait, %aimKey%

	;OutputDebug, %A_ThisFunc%::end
}

CrouchAutofire()
{
	global

	;OutputDebug, %A_ThisFunc%::begin

	SendInput % "{" . crouchKey . " down}"
	Sleep, %keyDelay%
	SendInput % "{" . crouchKey . " up}"

	;OutputDebug, %A_ThisFunc%::end
}

CrouchHold()
{
	global

	;OutputDebug, %A_ThisFunc%::begin
	;OutputDebug, %A_ThisFunc%::press

	SendInput % "{" . crouchKey . " down}"
	Sleep, %keyDelay%
	SendInput % "{" . crouchKey . " up}"

	KeyWait, %crouchKey%

	;OutputDebug, %A_ThisFunc%::release
	SendInput % "{" . crouchKey . " down}"
	Sleep, %keyDelay%
	SendInput % "{" . crouchKey . " up}"

	;OutputDebug, %A_ThisFunc%::end
}

CrouchToggle(pCrouching, pWait := true)
{
	global

	;OutputDebug, %A_ThisFunc%::begin
	bCrouching := pCrouching
	;OutputDebug, %A_ThisFunc%::bCrouching %bCrouching%

	SendInput % bCrouching ? "{" . crouchKey . " down}" : "{" . crouchKey . " up}"

	if (pWait)
		KeyWait, %crouchKey%

	;OutputDebug, %A_ThisFunc%::end
}

ReleaseAllKeys()
{
	global

	AimToggle(false)
	CrouchToggle(false)
	SprintToggle(false)

	bAutofireAiming := false
	bAutofireCrouching := false
	bAutofireSprinting := false

	SetTimer, AimAutofire, Off
	SetTimer, CrouchAutofire, Off
	SetTimer, SprintAutofire, Off
}

HookWindow()
{
	; All the variables below are declared as global so they can be used in the whole script
	global

	; Make the hotkeys active only for a specific window
	OutputDebug, %A_ThisFunc%::begin
	WinGet, windowID, ID, %windowName%
	OutputDebug, %A_ThisFunc%::WinGet %windowID%
	GroupAdd, windowIDGroup, ahk_id %windowID%
	Hotkey, IfWinActive, ahk_group windowIDGroup
	OutputDebug, %A_ThisFunc%::end
}

; Disable toggles on focus lost and optionally restore them on focus
OnFocusChanged()
{
	global

	OutputDebug, %A_ThisFunc%::begin

	OutputDebug, %A_ThisFunc%::WinWaitActive
	WinWaitActive, %windowName%
	Sleep, %hookDelay%

	; Make sure to hook the window again if it no longer exists
	if (windowID != WinExist(windowName))
	{
		HookWindow()
		RegisterHotkeys()

		; That's a different window, don't restore toggle states
		bRestoreAiming := false
		bRestoreCrouching := false
		bRestoreSprinting := false
	}

	; Restore toggle states
	if (bRestoreTogglesOnFocus && bAimMode == AIM_MODE_TOGGLE)
	{
		OutputDebug, %A_ThisFunc%::restoreToggleStates

		if (bRestoreAiming)
			AimToggle(true)
		if (bRestoreCrouching)
			CrouchToggle(true)
		if (bRestoreSprinting)
			SprintToggle(true)
	}

	OutputDebug, %A_ThisFunc%::WinWaitNotActive
	WinWaitNotActive, %windowName%

	; Save toggle states
	if (bRestoreTogglesOnFocus && bAimMode == AIM_MODE_TOGGLE && WinExist(windowName))
	{
		OutputDebug, %A_ThisFunc%::saveToggleStates

		bRestoreAiming := bAiming
		bRestoreCrouching := bCrouching
		bRestoreSprinting := bSprinting
	}

	ReleaseAllKeys()

	OutputDebug, %A_ThisFunc%::end
}

ReadConfigFile()
{
	; All the variables below are declared as global so they can be used in the whole script
	global

	; General
	IniRead, windowName, %configFileName%, General, windowName, "put_window_name_here"

	IniRead, bRestoreTogglesOnFocus, %configFileName%, General, bRestoreTogglesOnFocus, 0
	IniRead, bAimMode, %configFileName%, General, bAimMode, 1
	IniRead, bCrouchMode, %configFileName%, General, bCrouchMode, 1
	IniRead, bSprintMode, %configFileName%, General, bSprintMode, 1
	IniRead, autofireKeyDelay, %configFileName%, General, autofireKeyDelay, 100
	IniRead, focusCheckDelay, %configFileName%, General, focusCheckDelay, 1000
	IniRead, hookDelay, %configFileName%, General, hookDelay, 0
	IniRead, keyDelay, %configFileName%, General, keyDelay, 0

	; Keys
	IniRead, aimKey, %configFileName%, Keys, aimKey, RButton
	IniRead, crouchKey, %configFileName%, Keys, crouchKey, LCtrl
	IniRead, sprintKey, %configFileName%, Keys, sprintKey, LShift
	IniRead, aimAutofireKey, %configFileName%, Keys, aimAutofireKey, F1
	IniRead, crouchAutofireKey, %configFileName%, Keys, crouchAutofireKey, F2
	IniRead, sprintAutofireKey, %configFileName%, Keys, sprintAutofireKey, F3

	if (windowName == "put_window_name_here")
		ExitWithErrorMessage("You must specify a window name! The script will now exit.")
}

RegisterHotkeys()
{
	global

	; Enabled only for toggle and hold modes
	Hotkey, %aimKey%, aimLabel, % bAimMode > 0 && bAimMode < AIM_MODE_AUTOFIRE ? "On" : "Off"
	Hotkey, %crouchKey%, crouchLabel, % bCrouchMode > 0 && bCrouchMode < AIM_MODE_AUTOFIRE ? "On" : "Off"
	Hotkey, %sprintKey%, sprintLabel, % bSprintMode > 0 && bSprintMode < AIM_MODE_AUTOFIRE ? "On" : "Off"

	; Enabled only for autofire mode
	Hotkey, %aimAutofireKey%, aimLabel, % bAimMode == AIM_MODE_AUTOFIRE ? "On" : "Off"
	Hotkey, %crouchAutofireKey%, crouchLabel, % bCrouchMode == AIM_MODE_AUTOFIRE ? "On" : "Off"
	Hotkey, %sprintAutofireKey%, sprintLabel, % bSprintMode == AIM_MODE_AUTOFIRE ? "On" : "Off"
}

SprintAutofire()
{
	global

	;OutputDebug, %A_ThisFunc%::begin

	SendInput % "{" . sprintKey . " down}"
	Sleep, %keyDelay%
	SendInput % "{" . sprintKey . " up}"

	;OutputDebug, %A_ThisFunc%::end
}

SprintHold()
{
	global

	;OutputDebug, %A_ThisFunc%::begin
	;OutputDebug, %A_ThisFunc%::press

	SendInput % "{" . sprintKey . " down}"
	Sleep, %keyDelay%
	SendInput % "{" . sprintKey . " up}"

	KeyWait, %sprintKey%

	;OutputDebug, %A_ThisFunc%::release
	SendInput % "{" . sprintKey . " down}"
	Sleep, %keyDelay%
	SendInput % "{" . sprintKey . " up}"

	;OutputDebug, %A_ThisFunc%::end
}

SprintToggle(pSprinting, pWait := true)
{
	global

	;OutputDebug, %A_ThisFunc%::begin
	bSprinting := pSprinting
	;OutputDebug, %A_ThisFunc%::bSprinting %bSprinting%

	SendInput % bSprinting ? "{" . sprintKey . " down}" : "{" . sprintKey . " up}"

	if (pWait)
		KeyWait, %sprintKey%

	;OutputDebug, %A_ThisFunc%::end
}

; Exit script
ExitFunc(ExitReason, ExitCode)
{
	ReleaseAllKeys()
}

; Display an error message and exit
ExitWithErrorMessage(ErrorMessage)
{
	MsgBox, 16, Error, %ErrorMessage%
	ExitApp, 1
}

; Suspend script (useful when in menus)
!F12:: ; ALT+F12
Suspend

; Single beep when suspended
if (A_IsSuspended)
	SoundBeep, 1000
; Double beep when resumed
else
{
	SoundBeep, 1000
	SoundBeep, 1000
}

ReleaseAllKeys()
return
