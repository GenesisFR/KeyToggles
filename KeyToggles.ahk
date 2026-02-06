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
global g_guiSettings := 0
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

; Browse for process executable
GuiButtonBrowse_Click(GuiCtrlObj, Info)
{
	global g_editProcName

	; Turn FileSelect into a modal
	g_guiSettings.Opt("+OwnDialogs")

	; Only allow selecting executables by default
	l_sSelectedFile := FileSelect("3", , "Select the target executable file", "Executable Files (*.exe)")
	if (l_sSelectedFile != "")
	{
		l_sFileName := RegExReplace(l_sSelectedFile, "^.+[\\/]")
		g_editProcName.Value := l_sFileName
	}
}

; Validate and save settings to the config file
GuiButtonSave_Click(GuiCtrlObj, Info)
{
	; Strip double quotes
	l_procNameClean := Trim(g_editProcName.Value, "`"")
	l_windowNameClean := Trim(g_editWndName.Value, "`"")

	; Validate process name
	l_procNameExt := SubStr(l_procNameClean, -4)
	if (l_procNameExt != ".exe")
	{
		MsgBox("The process name doesn't end with `".exe`".", "Error", 16)
		return
	}

	; Surround with double quotes
	l_procNameClean := "`"" l_procNameClean "`""
	l_windowNameClean := "`"" l_windowNameClean "`""
	
	; Validate hotkeys (no duplicates allowed)
	l_arrHotkeys := [g_hkAimKey.Value, g_hkCrouchKey.Value, g_hkSprintKey.Value, g_hkAutorunKey.Value, g_hkForwardKey.Value,
					g_hkBackwardKey.Value , g_hkAimAutofireKey.Value, g_hkCrouchAutofireKey.Value, g_hkSprintAutofireKey.Value]
	l_mapHotkeys := Map()

	for l_sKey, l_sValue in l_arrHotkeys
	{
		if (l_sValue != "")
		{
			if (l_mapHotkeys.Has(l_sValue))
			{
				MsgBox("Duplicate hotkey detected: " l_sValue, "Error", 16)
				return
			}
			else
			{
				l_mapHotkeys[l_sValue] := true
			}
		}
	}

	; Everything ok, save settings
	IniWrite(l_procNameClean, "KeyToggles.ini", "General", "processName")
	IniWrite(l_windowNameClean, "KeyToggles.ini", "General", "windowName")
	IniWrite(g_upDownAutofireKeyInterval.Value, "KeyToggles.ini", "General", "autofireKeyInterval")
	IniWrite(g_cbxFixSystemKeys.Value, "KeyToggles.ini", "General", "fixSystemKeys")
	IniWrite(g_upDownFocusCheckInterval.Value, "KeyToggles.ini", "General", "focusCheckInterval")
	IniWrite(g_upDownHookDelay.Value, "KeyToggles.ini", "General", "hookDelay")
	IniWrite(g_upDownKeyDelay.Value, "KeyToggles.ini", "General", "keyDelay")
	IniWrite(g_cbxRestoreTogglesOnFocus.Value, "KeyToggles.ini", "General", "restoreTogglesOnFocus")
	IniWrite(g_cbxRestoreAutofiresOnFocus.Value, "KeyToggles.ini", "General", "restoreAutofiresOnFocus")
	IniWrite(g_cbxRunAsAdmin.Value, "KeyToggles.ini", "General", "runAsAdmin")
	IniWrite(g_ddlNotifications.Value - 1, "KeyToggles.ini", "General", "showNotifications")
	IniWrite(g_ddlAimMode.Value - 1, "KeyToggles.ini", "General", "aimMode")
	IniWrite(g_ddlCrouchMode.Value - 1, "KeyToggles.ini", "General", "crouchMode")
	IniWrite(g_ddlSprintMode.Value - 1, "KeyToggles.ini", "General", "sprintMode")
	IniWrite(g_cbxAutorun.Value == 1 ? 5 : 0, "KeyToggles.ini", "General", "autorunMode")
	
	IniWrite(g_hkAimKey.Value, "KeyToggles.ini", "Keys", "aimKey")
	IniWrite(g_hkCrouchKey.Value, "KeyToggles.ini", "Keys", "crouchKey")
	IniWrite(g_hkSprintKey.Value, "KeyToggles.ini", "Keys", "sprintKey")
	IniWrite(g_hkAutorunKey.Value, "KeyToggles.ini", "Keys", "autorunKey")
	IniWrite(g_hkForwardKey.Value, "KeyToggles.ini", "Keys", "forwardKey")
	IniWrite(g_hkBackwardKey.Value, "KeyToggles.ini", "Keys", "backwardKey")
	IniWrite(g_hkAimAutofireKey.Value, "KeyToggles.ini", "Keys", "aimAutofireKey")
	IniWrite(g_hkCrouchAutofireKey.Value, "KeyToggles.ini", "Keys", "crouchAutofireKey")
	IniWrite(g_hkSprintAutofireKey.Value, "KeyToggles.ini", "Keys", "sprintAutofireKey")

	MsgBox("Settings saved! Please restart the script to apply changes.", "Info", 64)
}

GuiCreate()
{
	global

	if (g_guiSettings)
		g_guiSettings.Destroy()
	
	g_guiSettings := Gui.Call("+OwnDialogs", "Configure settings", )
	g_guiSettings.BackColor := "353434"
	g_guiSettings.MarginX := 20
	g_guiSettings.MarginY := 10
	g_guiSettings.SetFont("s10 CWhite")

	; Layout constants
	local l_nCurrentRow := 0
	local l_nSpacingX := 10
	local l_nSpacingY := 25
	local l_nTopY := 10
	; Leftmost controls
	local l_nLeftWidth := 170
	local l_nLeftX := 25
	; Middle controls
	local l_nMiddleX := l_nLeftX + l_nLeftWidth + l_nSpacingX
	local l_nMiddleWidth := 170
	; Rightmost controls
	local l_nRightX := l_nMiddleX + l_nMiddleWidth + l_nSpacingX
	local l_nRightWidth := 100

	local l_arrKeyModes := ["Disabled", "Toggle", "Hold", "Autofire toggle", "Autofire hold"]
	local l_arrExtraKeys := ["None", "LButton", "RButton", "MButton", "XButton1", "XButton2", "Space", "Tab", "Enter", "Escape", "Backspace"]

	; General
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY " h" 6*29 " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "General")

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Process name")
	g_editProcName := g_guiSettings.AddEdit("vMyGuiProcessNameEdit CBlack x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_sProcessName)
	g_guiSettings.AddButton("vMyGuiBrowseButton x" l_nRightX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " h23 w" l_nRightWidth, "Browse").OnEvent("Click", GuiButtonBrowse_Click)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Window name")
	g_editWndName := g_guiSettings.AddEdit("vMyGuiWindowNameEdit CBlack x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_sWindowName)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Autofire key interval")
	g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth)
	g_upDownAutofireKeyInterval := g_guiSettings.AddUpDown("vMyGuiAutofireKeyIntervalUpDown Range0-10000", g_nAutofireKeyInterval)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Focus check interval")
	g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth)
	g_upDownFocusCheckInterval := g_guiSettings.AddUpDown("vMyGuiFocusCheckIntervalUpDown Range0-10000", g_nFocusCheckInterval)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Hook delay")
	g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth)
	g_upDownHookDelay := g_guiSettings.AddUpDown("vMyGuiHookDelayUpDown Range0-30000", g_nHookDelay)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Key delay")
	g_editKeyDelay := g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth)
	g_upDownKeyDelay := g_guiSettings.AddUpDown("vMyGuiKeyDelayUpDown Range0-1000", g_nKeyDelay)

	; Save states
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) + 3 " h" 2*35 " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Save states")
	g_cbxRestoreAutofiresOnFocus := g_guiSettings.AddCheckbox("vRestoreAutofiresOnFocus Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth + 23 " Checked" g_bRestoreAutofiresOnFocus, "Restore autofires on focus  ")
	g_cbxRestoreTogglesOnFocus := g_guiSettings.AddCheckbox("vRestoreTogglesOnFocusCheckBox Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth + 23 " Checked" g_bRestoreTogglesOnFocus, "Restore toggles on focus  ")

	; Key modes
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) + 3 " h" 4*30 " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Key modes")
	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Aim")
	g_ddlAimMode := g_guiSettings.AddDropDownList("vAimModeDropDownList x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth " Choose" g_nAimMode + 1, l_arrKeyModes)
	
	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Crouch")
	g_ddlCrouchMode := g_guiSettings.AddDropDownList("vCrouchModeDropDownList x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth " Choose" g_nCrouchMode + 1, l_arrKeyModes)
	
	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Sprint")
	g_ddlSprintMode := g_guiSettings.AddDropDownList("vSprintModeDropDownList x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth " Choose" g_nSprintMode + 1, l_arrKeyModes)

	g_cbxAutorun := g_guiSettings.AddCheckBox("vAutorunModeCheckBox Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth + 23 " Checked" (g_bAutorunMode == KEY_MODE_AUTORUN ? "1" : "0"), "Autorun  ")

	; Hotkeys
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) + 3 " h" 9*28 " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Hotkeys")

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Aim")
	g_hkAimKey := g_guiSettings.AddHotkey("vAimKeyHotkey x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_sAimKey)
	g_hkAimKey.OnEvent("Change", GuiHK_Change)

	g_ddlAimKey := g_guiSettings.AddDropDownList("vAimKeyDropDownList x" l_nRightX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nRightWidth, l_arrExtraKeys)
	g_ddlAimKey.OnEvent("Change", GuiDDLExtra_Change)
	g_ddlAimKey.Text := IsExtraOption(g_sAimKey) ? g_sAimKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Crouch")
	g_hkCrouchKey := g_guiSettings.AddHotkey("vCrouchKeyHotkey x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_sCrouchKey)
	g_hkCrouchKey.OnEvent("Change", GuiHK_Change)

	g_ddlCrouchKey := g_guiSettings.AddDropDownList("vCrouchKeyDropDownList x" l_nRightX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nRightWidth, l_arrExtraKeys)
	g_ddlCrouchKey.OnEvent("Change", GuiDDLExtra_Change)
	g_ddlCrouchKey.Text := IsExtraOption(g_sCrouchKey) ? g_sCrouchKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Sprint")
	g_hkSprintKey := g_guiSettings.AddHotkey("vSprintKeyHotkey x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_sSprintKey)
	g_hkSprintKey.OnEvent("Change", GuiHK_Change)

	g_ddlSprintKey := g_guiSettings.AddDropDownList("vSprintKeyDropDownList x" l_nRightX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nRightWidth, l_arrExtraKeys)
	g_ddlSprintKey.OnEvent("Change", GuiDDLExtra_Change)
	g_ddlSprintKey.Text := IsExtraOption(g_sSprintKey) ? g_sSprintKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Autorun")
	g_hkAutorunKey := g_guiSettings.AddHotkey("vAutorunKeyHotkey x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_autorunKey)
	g_hkAutorunKey.OnEvent("Change", GuiHK_Change)

	g_ddlAutorunKey := g_guiSettings.AddDropDownList("vAutorunKeyDropDownList x" l_nRightX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nRightWidth, l_arrExtraKeys)
	g_ddlAutorunKey.OnEvent("Change", GuiDDLExtra_Change)
	g_ddlAutorunKey.Text := IsExtraOption(g_autorunKey) ? g_autorunKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Forward")
	g_hkForwardKey := g_guiSettings.AddHotkey("vForwardKeyHotkey x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_sForwardKey)
	g_hkForwardKey.OnEvent("Change", GuiHK_Change)

	g_ddlForwardKey := g_guiSettings.AddDropDownList("vForwardKeyDropDownList x" l_nRightX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nRightWidth, l_arrExtraKeys)
	g_ddlForwardKey.OnEvent("Change", GuiDDLExtra_Change)
	g_ddlForwardKey.Text := IsExtraOption(g_sForwardKey) ? g_sForwardKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Backward")
	g_hkBackwardKey := g_guiSettings.AddHotkey("vBackwardKeyHotkey x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_sBackwardKey)
	g_hkBackwardKey.OnEvent("Change", GuiHK_Change)

	g_ddlBackwardKey := g_guiSettings.AddDropDownList("vBackwardKeyDropDownList x" l_nRightX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nRightWidth, l_arrExtraKeys)
	g_ddlBackwardKey.OnEvent("Change", GuiDDLExtra_Change)
	g_ddlBackwardKey.Text := IsExtraOption(g_sBackwardKey) ? g_sBackwardKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Aim autofire")
	g_hkAimAutofireKey := g_guiSettings.AddHotkey("vAimAutofireKeyHotkey x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_sAimAutofireKey)
	g_hkAimAutofireKey.OnEvent("Change", GuiHK_Change)

	g_ddlAimAutofireKey := g_guiSettings.AddDropDownList("vAimAutofireKeyDropDownList x" l_nRightX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nRightWidth, l_arrExtraKeys)
	g_ddlAimAutofireKey.OnEvent("Change", GuiDDLExtra_Change)
	g_ddlAimAutofireKey.Text := IsExtraOption(g_sAimAutofireKey) ? g_sAimAutofireKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Crouch autofire")
	g_hkCrouchAutofireKey := g_guiSettings.AddHotkey("vCrouchAutofireHotkey x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_sCrouchAutofireKey)
	g_hkCrouchAutofireKey.OnEvent("Change", GuiHK_Change)

	g_ddlCrouchAutofireKey := g_guiSettings.AddDropDownList("vCrouchAutofireKeyDropDownList x" l_nRightX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nRightWidth, l_arrExtraKeys)
	g_ddlCrouchAutofireKey.OnEvent("Change", GuiDDLExtra_Change)
	g_ddlCrouchAutofireKey.Text := IsExtraOption(g_sCrouchAutofireKey) ? g_sCrouchAutofireKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Sprint autofire")
	g_hkSprintAutofireKey := g_guiSettings.AddHotkey("vSprintAutofireHotkey x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth, g_sSprintAutofireKey)
	g_hkSprintAutofireKey.OnEvent("Change", GuiHK_Change)

	g_ddlSprintAutofireKey := g_guiSettings.AddDropDownList("vSprintAutofireKeyDropDownList x" l_nRightX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nRightWidth, l_arrExtraKeys)
	g_ddlSprintAutofireKey.OnEvent("Change", GuiDDLExtra_Change)
	g_ddlSprintAutofireKey.Text := IsExtraOption(g_sSprintAutofireKey) ? g_sSprintAutofireKey : "None"

	; Misc
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) + 10 " h" 3*32 " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Misc")

	g_cbxFixSystemKeys := g_guiSettings.AddCheckbox("vFixSystemKeysCheckBox Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth + 23 " Checked" g_bFixSystemKeys, "Fix system keys  ")
	g_cbxRunAsAdmin := g_guiSettings.AddCheckbox("vRunAsAdmin Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth + 23 " Checked" g_bRunAsAdmin, "Run as admin  ")

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + (l_nSpacingY * ++l_nCurrentRow) " w" l_nLeftWidth, "Notifications")
	g_ddlNotifications := g_guiSettings.AddDropDownList("vNotificationsDropDownList x" l_nMiddleX " y" l_nTopY + (l_nSpacingY * l_nCurrentRow) - 5 " w" l_nMiddleWidth " Choose" g_nShowNotifications + 1, ["Disabled", "System notifications", "Tooltips"])

	g_guiSettings.AddButton("vMyGuiSave x200 w100", "Save").OnEvent("Click", GuiButtonSave_Click)
}

; Enable/disable and set hotkey controls text based on selected DDL extra keys
GuiDDLExtra_Change(GuiCtrlObj, Info)
{
	switch GuiCtrlObj
	{
		case g_ddlAimKey:
			g_hkAimKey.Value := g_ddlAimKey.Value == 1 ? "" : g_ddlAimKey.Text
		case g_ddlCrouchKey:
			g_hkCrouchKey.Value := g_ddlCrouchKey.Value == 1 ? "" : g_ddlCrouchKey.Text
		case g_ddlSprintKey:
			g_hkSprintKey.Value := g_ddlSprintKey.Value == 1 ? "" : g_ddlSprintKey.Text
		case g_ddlAutorunKey:
			g_hkAutorunKey.Value := g_ddlAutorunKey.Value == 1 ? "" : g_ddlAutorunKey.Text
		case g_ddlForwardKey:
			g_hkForwardKey.Value := g_ddlForwardKey.Value == 1 ? "" : g_ddlForwardKey.Text
		case g_ddlBackwardKey:
			g_hkBackwardKey.Value := g_ddlBackwardKey.Value == 1 ? "" : g_ddlBackwardKey.Text
		case g_ddlAimAutofireKey:
			g_hkAimAutofireKey.Value := g_ddlAimAutofireKey.Value == 1 ? "" : g_ddlAimAutofireKey.Text
		case g_ddlCrouchAutofireKey:
			g_hkCrouchAutofireKey.Value := g_ddlCrouchAutofireKey.Value == 1 ? "" : g_ddlCrouchAutofireKey.Text
		case g_ddlSprintAutofireKey:
			g_hkSprintAutofireKey.Value := g_ddlSprintAutofireKey.Value == 1 ? "" : g_ddlSprintAutofireKey.Text
	}
}

; Prevent modified keys from being used in hotkey controls 
GuiHK_Change(GuiCtrlObj, Info)
{
	; Turn MsgBox into a modal
	g_guiSettings.Opt("+OwnDialogs")

	l_sHotkey := GuiCtrlObj.Value
	l_sHotkeyLength := StrLen(l_sHotkey)
	l_bShift := InStr(GuiCtrlObj.Value, "+")
	l_bControl := InStr(GuiCtrlObj.Value, "^")
	l_bAlt := InStr(GuiCtrlObj.Value, "!")

	Output("l_hotkey(" l_sHotkey ") l_bShift(" l_bShift ") l_bControl(" l_bControl ") l_bAlt(" l_bAlt ")")

	if (l_bShift && !l_bControl && !l_bAlt && l_sHotkeyLength == 1)
		GuiCtrlObj.Value := "LShift"
	else if (!l_bShift && l_bControl && !l_bAlt && l_sHotkeyLength == 1)
		GuiCtrlObj.Value := "LControl"
	else if (!l_bShift && !l_bControl && l_bAlt && l_sHotkeyLength == 1)
		GuiCtrlObj.Value := "LAlt"
	else if (l_bShift || l_bControl || l_bAlt && l_sHotkeyLength > 1)
	{
		GuiCtrlObj.Value := ""
		MsgBox("You can't use modified keys!", "Error", 16)
	}
}

Init()
{
	global g_guiSettings

	ReadConfigFile()
	RestartAsAdminIfNeeded()
	SetTimer(OnFocusChanged, g_nFocusCheckInterval)
	GuiCreate()
	A_TrayMenu.Insert("&Suspend Hotkeys", "Configure settings", (*) => 	g_guiSettings.Show())
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

IsExtraOption(p_sKey)
{
	l_ddlExtraList := Map("LButton", "", "MButton", "", "RButton", "", "XButton1", "", "XButton2", "", "Space", "", "Tab", "", "Enter", "", "Escape", "", "Backspace", "")
	return l_ddlExtraList.Has(p_sKey)
}

IsMouseButton(p_sKey)
{
	l_mouseButtonList := "LButton MButton RButton XButton1 XButton2"
	return InStr(l_mouseButtonList, p_sKey) != false
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
			l_nKeyMode := g_nAimMode
		case g_sCrouchKey, g_sCrouchAutofireKey:
			l_nKeyMode := g_nCrouchMode
		case g_sSprintKey, g_sSprintAutofireKey:
			l_nKeyMode := g_nSprintMode
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
	g_nAimMode := IniRead(l_sConfigFileName, "General", "aimMode", 0)
	g_nCrouchMode := IniRead(l_sConfigFileName, "General", "crouchMode", 0)
	g_nSprintMode := IniRead(l_sConfigFileName, "General", "sprintMode", 0)
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

	; Prevent timers from not working if set to 0
	g_nAutofireKeyInterval := Max(1, g_nAutofireKeyInterval)
	g_nFocusCheckInterval := Max(1, g_nFocusCheckInterval)

	if (g_sProcessName == "")
		ExitWithErrorMessage("You must specify a process name! The script will now exit.")
}

RegisterHotkeys()
{
	global

	HotIfWinActive("ahk_group windowIDGroup")

	; Enabled only for toggle and hold modes
	Hotkey("*$" g_sAimKey, OnKeyPress, g_nAimMode == KEY_MODE_TOGGLE || g_nAimMode == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" g_sCrouchKey, OnKeyPress, g_nCrouchMode == KEY_MODE_TOGGLE || g_nCrouchMode == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" g_sSprintKey, OnKeyPress, g_nSprintMode == KEY_MODE_TOGGLE || g_nSprintMode == KEY_MODE_HOLD ? "On" : "Off")

	; Enabled only for autorun mode
	Hotkey("*$" g_autorunKey, OnKeyPress, g_bAutorunMode == KEY_MODE_AUTORUN ? "On" : "Off")
	Hotkey("~*$" g_sForwardKey, OnKeyPress, g_bAutorunMode == KEY_MODE_AUTORUN ? "On" : "Off")
	Hotkey("~*$" g_sBackwardKey, OnKeyPress, g_bAutorunMode == KEY_MODE_AUTORUN ? "On" : "Off")

	; Enabled only for autofire modes
	Hotkey("*$" g_sAimAutofireKey, OnKeyPress, g_nAimMode == KEY_MODE_AUTOFIRE || g_nAimMode == KEY_MODE_AUTOFIRE_HOLD  ? "On" : "Off")
	Hotkey("*$" g_sCrouchAutofireKey, OnKeyPress, g_nCrouchMode == KEY_MODE_AUTOFIRE || g_nCrouchMode == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")
	Hotkey("*$" g_sSprintAutofireKey, OnKeyPress, g_nSprintMode == KEY_MODE_AUTOFIRE || g_nSprintMode == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")

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
	return g_bRestoreAutofiresOnFocus && (g_nAimMode == KEY_MODE_AUTOFIRE || g_nCrouchMode == KEY_MODE_AUTOFIRE || g_nSprintMode == KEY_MODE_AUTOFIRE) && (WinExist("ahk_id " g_nWindowID) != 0)
}

ShouldRestoreTogglesOnFocus()
{
	return g_bRestoreTogglesOnFocus && (g_nAimMode == KEY_MODE_TOGGLE || g_nCrouchMode == KEY_MODE_TOGGLE || g_nSprintMode == KEY_MODE_TOGGLE) && (WinExist("ahk_id " g_nWindowID) != 0)
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
