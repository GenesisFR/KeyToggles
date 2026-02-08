; KeyToggles v2.2

; TODO
; add application profiles (https://stackoverflow.com/questions/45190170/how-can-i-make-this-ini-file-into-a-listview-in-autohotkey)
; add overlay
; add support for hotkey modifiers (e.g., Ctrl+F1)
; add text/tooltips when mousing over GUI controls to explain what they do
; replace sleeps with timers
; replace ternary operators with coalescing ?? operators where possible
; show window name on top of process name during WinWaitActive
; validate process name at startup and show error if not valid
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
global KEY_MODE_AUTOFIRE_TOGGLE := 3
global KEY_MODE_AUTOFIRE_HOLD := 4

; Maps
global g_mapControls := Map()
global g_mapStates := Map()

; Functors
global g_fnAutofireAim := 0
global g_fnAutofireCrouch := 0
global g_fnAutofireSprint := 0

; Arrays
global g_arrKeyModes := ["Disabled", "Toggle", "Hold", "Autofire toggle", "Autofire hold"]
global g_arrExtraKeys := ["None", "LButton", "RButton", "MButton", "XButton1", "XButton2", "Space", "Tab", "Enter", "Escape", "Backspace"]

; Others
global g_guiSettings := 0
global g_nWindowID := 0

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
		g_mapControls["editProcessName"].Value := l_sFileName
	}
}

; Validate and save settings to the config file
GuiButtonSave_Click(GuiCtrlObj, Info)
{
	; Strip double quotes
	l_procNameClean := Trim(g_mapControls["editProcessName"].Value, "`"")
	l_windowNameClean := Trim(g_mapControls["editWindowName"].Value, "`"")

	; Validate process name
	l_procNameExt := SubStr(l_procNameClean, -4)
	if (Trim(l_procNameExt) == "")
	{
		MsgBox("You must specify a process name.", "Error", 16)
		return
	}
	else if (l_procNameExt != ".exe")
	{
		MsgBox("The process name doesn't end with `".exe`".", "Error", 16)
		return
	}

	; Surround with double quotes
	l_procNameClean := "`"" l_procNameClean "`""
	l_windowNameClean := "`"" l_windowNameClean "`""

	; Validate hotkeys (no duplicates allowed)
	l_arrHotkeys := [
		g_mapControls["hkAimKey"].Value,
		g_mapControls["hkCrouchKey"].Value,
		g_mapControls["hkSprintKey"].Value,
		g_mapControls["hkAutorunKey"].Value,
		g_mapControls["hkForwardKey"].Value,
		g_mapControls["hkBackwardKey"].Value,
		g_mapControls["hkAimAutofireKey"].Value,
		g_mapControls["hkCrouchAutofireKey"].Value,
		g_mapControls["hkSprintAutofireKey"].Value
	]
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
				l_mapHotkeys[l_sValue] := true
		}
	}

	; Everything ok, save settings
	IniWrite(l_procNameClean, "KeyToggles.ini", "General", "processName")
	IniWrite(l_windowNameClean, "KeyToggles.ini", "General", "windowName")
	IniWrite(g_mapControls["udAutofireKeyInterval"].Value, "KeyToggles.ini", "General", "autofireKeyInterval")
	IniWrite(g_mapControls["cbAutorun"].Value, "KeyToggles.ini", "General", "autorunMode")
	IniWrite(g_mapControls["ddlAimMode"].Value - 1, "KeyToggles.ini", "General", "aimMode")
	IniWrite(g_mapControls["ddlCrouchMode"].Value - 1, "KeyToggles.ini", "General", "crouchMode")
	IniWrite(g_mapControls["ddlNotifications"].Value - 1, "KeyToggles.ini", "General", "showNotifications")
	IniWrite(g_mapControls["ddlSprintMode"].Value - 1, "KeyToggles.ini", "General", "sprintMode")
	IniWrite(g_mapControls["cbFixSystemKeys"].Value, "KeyToggles.ini", "General", "fixSystemKeys")
	IniWrite(g_mapControls["udFocusCheckInterval"].Value, "KeyToggles.ini", "General", "focusCheckInterval")
	IniWrite(g_mapControls["udHookDelay"].Value, "KeyToggles.ini", "General", "hookDelay")
	IniWrite(g_mapControls["udKeyDelay"].Value, "KeyToggles.ini", "General", "keyDelay")
	IniWrite(g_mapControls["cbRestoreTogglesOnFocus"].Value, "KeyToggles.ini", "General", "restoreTogglesOnFocus")
	IniWrite(g_mapControls["cbRestoreAutofiresOnFocus"].Value, "KeyToggles.ini", "General", "restoreAutofiresOnFocus")
	IniWrite(g_mapControls["cbRunAsAdmin"].Value, "KeyToggles.ini", "General", "runAsAdmin")
	IniWrite(g_mapControls["hkAimAutofireKey"].Value, "KeyToggles.ini", "Keys", "aimAutofireKey")
	IniWrite(g_mapControls["hkAimKey"].Value, "KeyToggles.ini", "Keys", "aimKey")
	IniWrite(g_mapControls["hkAutorunKey"].Value, "KeyToggles.ini", "Keys", "autorunKey")
	IniWrite(g_mapControls["hkBackwardKey"].Value, "KeyToggles.ini", "Keys", "backwardKey")
	IniWrite(g_mapControls["hkCrouchAutofireKey"].Value, "KeyToggles.ini", "Keys", "crouchAutofireKey")
	IniWrite(g_mapControls["hkCrouchKey"].Value, "KeyToggles.ini", "Keys", "crouchKey")
	IniWrite(g_mapControls["hkForwardKey"].Value, "KeyToggles.ini", "Keys", "forwardKey")
	IniWrite(g_mapControls["hkSprintAutofireKey"].Value, "KeyToggles.ini", "Keys", "sprintAutofireKey")
	IniWrite(g_mapControls["hkSprintKey"].Value, "KeyToggles.ini", "Keys", "sprintKey")

	if (MsgBox("Settings saved! Would you like to restart the script to apply changes?", "Info", 68) == "Yes")
		Reload()
}

GuiCreate()
{
	global

	; Safety check
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

	; General
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY " h" 6*30 " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + l_nSpacingX * 4), "General")

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Process name")
	g_mapControls["editProcessName"] := g_guiSettings.AddEdit("CBlack x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                        " w" l_nMiddleWidth, g_sProcessName)
	;g_mapSettings["editProcessName"].OnEvent("Focus", (*) => ToolTip("Enter the name of the target process executable (e.g., game.exe)."))
	;g_mapSettings["editProcessName"].OnEvent("LoseFocus", (*) => ToolTip())

	g_guiSettings.AddButton("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " h23 w" l_nRightWidth, "Browse").OnEvent("Click", GuiButtonBrowse_Click)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Window name")
	g_mapControls["editWindowName"] := g_guiSettings.AddEdit("CBlack x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                     " w" l_nMiddleWidth, g_sWindowName)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Autofire key interval")
	g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth)
	g_mapControls["udAutofireKeyInterval"] := g_guiSettings.AddUpDown("Range0-10000", g_nAutofireKeyInterval)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Focus check interval")
	g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth)
	g_mapControls["udFocusCheckInterval"] := g_guiSettings.AddUpDown("Range0-10000", g_nFocusCheckInterval)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Hook delay")
	g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth)
	g_mapControls["udHookDelay"] := g_guiSettings.AddUpDown("Range0-30000", g_nHookDelay)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Key delay")
	g_editKeyDelay := g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth)
	g_mapControls["udKeyDelay"] := g_guiSettings.AddUpDown("Range0-1000", g_nKeyDelay)

	; Save states
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow + 5 " h" 2*35
	                          " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Save states")
	g_mapControls["cbRestoreAutofiresOnFocus"] := g_guiSettings.AddCheckbox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow
	                                                                        " w" l_nLeftWidth + 23 " Checked" g_bRestoreAutofiresOnFocus,
	                                                                        "Restore autofires on focus  ")
	g_mapControls["cbRestoreTogglesOnFocus"] := g_guiSettings.AddCheckbox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow
	                                                                      " w" l_nLeftWidth + 23 " Checked" g_bRestoreTogglesOnFocus,
	                                                                      "Restore toggles on focus  ")

	; Key modes
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " h" 4*31
	                          " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Key modes")
	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Aim")
	g_mapControls["ddlAimMode"] := g_guiSettings.AddDropDownList("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                          " w" l_nMiddleWidth " Choose" g_nAimMode + 1, g_arrKeyModes)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Crouch")
	g_mapControls["ddlCrouchMode"] := g_guiSettings.AddDropDownList("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                             " w" l_nMiddleWidth " Choose" g_nCrouchMode + 1, g_arrKeyModes)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Sprint")
	g_mapControls["ddlSprintMode"] := g_guiSettings.AddDropDownList("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                             " w" l_nMiddleWidth " Choose" g_nSprintMode + 1, g_arrKeyModes)

	g_mapControls["cbAutorun"] := g_guiSettings.AddCheckBox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth + 23
	                                                      " Checked" g_bAutorunMode, "Autorun  ")

	; Hotkeys
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " h" 9*28 + 3
	                          " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Hotkeys")

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Aim")
	g_mapControls["hkAimKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth, g_sAimKey)
	g_mapControls["ddlAimKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlAimKey"].Text := IsExtraOption(g_sAimKey) ? g_sAimKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Crouch")
	g_mapControls["hkCrouchKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth, g_sCrouchKey)
	g_mapControls["ddlCrouchKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlCrouchKey"].Text := IsExtraOption(g_sCrouchKey) ? g_sCrouchKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Sprint")
	g_mapControls["hkSprintKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth, g_sSprintKey)
	g_mapControls["ddlSprintKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlSprintKey"].Text := IsExtraOption(g_sSprintKey) ? g_sSprintKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Autorun")
	g_mapControls["hkAutorunKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth, g_sAutorunKey)
	g_mapControls["ddlAutorunKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlAutorunKey"].Text := IsExtraOption(g_sAutorunKey) ? g_sAutorunKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Forward")
	g_mapControls["hkForwardKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth, g_sForwardKey)
	g_mapControls["ddlForwardKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlForwardKey"].Text := IsExtraOption(g_sForwardKey) ? g_sForwardKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Backward")
	g_mapControls["hkBackwardKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth, g_sBackwardKey)
	g_mapControls["ddlBackwardKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                                 " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlBackwardKey"].Text := IsExtraOption(g_sBackwardKey) ? g_sBackwardKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Aim autofire")
	g_mapControls["hkAimAutofireKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                           " w" l_nMiddleWidth, g_sAimAutofireKey)
	g_mapControls["ddlAimAutofireKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                                    " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlAimAutofireKey"].Text := IsExtraOption(g_sAimAutofireKey) ? g_sAimAutofireKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Crouch autofire")
	g_mapControls["hkCrouchAutofireKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                 " w" l_nMiddleWidth, g_sCrouchAutofireKey)
	g_mapControls["ddlCrouchAutofireKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                                " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlCrouchAutofireKey"].Text := IsExtraOption(g_sCrouchAutofireKey) ? g_sCrouchAutofireKey : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Sprint autofire")
	g_mapControls["hkSprintAutofireKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                              " w" l_nMiddleWidth, g_sSprintAutofireKey)
	g_mapControls["ddlSprintAutofireKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                                       " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlSprintAutofireKey"].Text := IsExtraOption(g_sSprintAutofireKey) ? g_sSprintAutofireKey : "None"

	; Misc
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow + 5 " h" 3*33
	                          " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Misc")

	g_mapControls["cbFixSystemKeys"] := g_guiSettings.AddCheckbox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow
	                                                            " w" l_nLeftWidth + 23 " Checked" g_bFixSystemKeys, "Fix system keys  ")
	g_mapControls["cbRunAsAdmin"] := g_guiSettings.AddCheckbox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth + 23
	                                                           " Checked" g_bRunAsAdmin, "Run as admin  ")

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Notifications")
	g_mapControls["ddlNotifications"] := g_guiSettings.AddDropDownList("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                                   " w" l_nMiddleWidth " Choose" g_nShowNotifications + 1,
	                                                                   ["Disabled", "System notifications", "Tooltips"])

	g_guiSettings.AddButton("x200 w100", "Save").OnEvent("Click", GuiButtonSave_Click)

	; Event handlers
	g_mapControls["hkAimKey"].OnEvent("Change", GuiHK_Change)
	g_mapControls["hkCrouchKey"].OnEvent("Change", GuiHK_Change)
	g_mapControls["hkSprintKey"].OnEvent("Change", GuiHK_Change)
	g_mapControls["hkAutorunKey"].OnEvent("Change", GuiHK_Change)
	g_mapControls["hkForwardKey"].OnEvent("Change", GuiHK_Change)
	g_mapControls["hkBackwardKey"].OnEvent("Change", GuiHK_Change)
	g_mapControls["hkAimAutofireKey"].OnEvent("Change", GuiHK_Change)
	g_mapControls["hkCrouchAutofireKey"].OnEvent("Change", GuiHK_Change)
	g_mapControls["hkSprintAutofireKey"].OnEvent("Change", GuiHK_Change)
	g_mapControls["ddlAimKey"].OnEvent("Change", GuiDDLExtra_Change)
	g_mapControls["ddlCrouchKey"].OnEvent("Change", GuiDDLExtra_Change)
	g_mapControls["ddlSprintKey"].OnEvent("Change", GuiDDLExtra_Change)
	g_mapControls["ddlAutorunKey"].OnEvent("Change", GuiDDLExtra_Change)
	g_mapControls["ddlForwardKey"].OnEvent("Change", GuiDDLExtra_Change)
	g_mapControls["ddlBackwardKey"].OnEvent("Change", GuiDDLExtra_Change)
	g_mapControls["ddlAimAutofireKey"].OnEvent("Change", GuiDDLExtra_Change)
	g_mapControls["ddlCrouchAutofireKey"].OnEvent("Change", GuiDDLExtra_Change)
	g_mapControls["ddlSprintAutofireKey"].OnEvent("Change", GuiDDLExtra_Change)
}

; Set hotkey controls text based on selected DDL extra keys
GuiDDLExtra_Change(GuiCtrlObj, Info)
{
	switch GuiCtrlObj
	{
		case g_mapControls["ddlAimKey"]:
			g_mapControls["hkAimKey"].Value := g_mapControls["ddlAimKey"].Value == 1 ? "" : g_mapControls["ddlAimKey"].Text
		case g_mapControls["ddlCrouchKey"]:
			g_mapControls["hkCrouchKey"].Value := g_mapControls["ddlCrouchKey"].Value == 1 ? "" : g_mapControls["ddlCrouchKey"].Text
		case g_mapControls["ddlSprintKey"]:
			g_mapControls["hkSprintKey"].Value := g_mapControls["ddlSprintKey"].Value == 1 ? "" : g_mapControls["ddlSprintKey"].Text
		case g_mapControls["ddlAutorunKey"]:
			g_mapControls["hkAutorunKey"].Value := g_mapControls["ddlAutorunKey"].Value == 1 ? "" : g_mapControls["ddlAutorunKey"].Text
		case g_mapControls["ddlForwardKey"]:
			g_mapControls["hkForwardKey"].Value := g_mapControls["ddlForwardKey"].Value == 1 ? "" : g_mapControls["ddlForwardKey"].Text
		case g_mapControls["ddlBackwardKey"]:
			g_mapControls["hkBackwardKey"].Value := g_mapControls["ddlBackwardKey"].Value == 1 ? "" : g_mapControls["ddlBackwardKey"].Text
		case g_mapControls["ddlAimAutofireKey"]:
			g_mapControls["hkAimAutofireKey"].Value := g_mapControls["ddlAimAutofireKey"].Value == 1 ? "" : g_mapControls["ddlAimAutofireKey"].Text
		case g_mapControls["ddlCrouchAutofireKey"]:
			g_mapControls["hkCrouchAutofireKey"].Value := g_mapControls["ddlCrouchAutofireKey"].Value == 1 ? "" : g_mapControls["ddlCrouchAutofireKey"].Text
		case g_mapControls["ddlSprintAutofireKey"]:
			g_mapControls["hkSprintAutofireKey"].Value := g_mapControls["ddlSprintAutofireKey"].Value == 1 ? "" : g_mapControls["ddlSprintAutofireKey"].Text
	}
}

; Prevent modified keys from being used in hotkey controls (could be changed to allow them in the future)
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

; Update GUI controls based on current settings
GuiUpdate()
{
	g_mapControls["cbAutorun"].Value := g_bAutorunMode
	g_mapControls["cbFixSystemKeys"].Value := g_bFixSystemKeys
	g_mapControls["cbRestoreAutofiresOnFocus"].Value := g_bRestoreAutofiresOnFocus
	g_mapControls["cbRestoreTogglesOnFocus"].Value := g_bRestoreTogglesOnFocus
	g_mapControls["cbRunAsAdmin"].Value := g_bRunAsAdmin
	g_mapControls["ddlAimAutofireKey"].Text := IsExtraOption(g_sAimAutofireKey) ? g_sAimAutofireKey : "None"
	g_mapControls["ddlAimKey"].Text := IsExtraOption(g_sAimKey) ? g_sAimKey : "None"
	g_mapControls["ddlAimMode"].Value := g_nAimMode + 1
	g_mapControls["ddlAutorunKey"].Text := IsExtraOption(g_sAutorunKey) ? g_sAutorunKey : "None"
	g_mapControls["ddlBackwardKey"].Text := IsExtraOption(g_sBackwardKey) ? g_sBackwardKey : "None"
	g_mapControls["ddlCrouchAutofireKey"].Text := IsExtraOption(g_sCrouchAutofireKey) ? g_sCrouchAutofireKey : "None"
	g_mapControls["ddlCrouchKey"].Text := IsExtraOption(g_sCrouchKey) ? g_sCrouchKey : "None"
	g_mapControls["ddlCrouchMode"].Value := g_nCrouchMode + 1
	g_mapControls["ddlForwardKey"].Text := IsExtraOption(g_sForwardKey) ? g_sForwardKey : "None"
	g_mapControls["ddlNotifications"].Value := g_nShowNotifications + 1
	g_mapControls["ddlSprintAutofireKey"].Text := IsExtraOption(g_sSprintAutofireKey) ? g_sSprintAutofireKey : "None"
	g_mapControls["ddlSprintKey"].Text := IsExtraOption(g_sSprintKey) ? g_sSprintKey : "None"
	g_mapControls["ddlSprintMode"].Value := g_nSprintMode + 1
	g_mapControls["editProcessName"].Value := g_sProcessName
	g_mapControls["editWindowName"].Value := g_sWindowName
	g_mapControls["hkAimAutofireKey"].Value := g_sAimAutofireKey
	g_mapControls["hkAimKey"].Value := g_sAimKey
	g_mapControls["hkAutorunKey"].Value := g_sAutorunKey
	g_mapControls["hkBackwardKey"].Value := g_sBackwardKey
	g_mapControls["hkCrouchAutofireKey"].Value := g_sCrouchAutofireKey
	g_mapControls["hkCrouchKey"].Value := g_sCrouchKey
	g_mapControls["hkForwardKey"].Value := g_sForwardKey
	g_mapControls["hkSprintAutofireKey"].Value := g_sSprintAutofireKey
	g_mapControls["hkSprintKey"].Value := g_sSprintKey
	g_mapControls["udAutofireKeyInterval"].Value := g_nAutofireKeyInterval
	g_mapControls["udFocusCheckInterval"].Value := g_nFocusCheckInterval
	g_mapControls["udHookDelay"].Value := g_nHookDelay
	g_mapControls["udKeyDelay"].Value := g_nKeyDelay
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

IniReadEnforceType(p_sFile, p_sSection, p_sKey, p_sDefault, p_sType)
{
	l_sValue := IniRead(p_sFile, p_sSection, p_sKey, p_sDefault)

	switch p_sType
	{
		case Number:
			try {
				l_nValue := l_sValue + 0
				return l_nValue
			} catch TypeError {
				return p_sDefault
			}
		case String:
				return l_sValue
		case "bool":
			return l_sValue == "1" ? true : l_sValue == "0" ? false : p_sDefault
		case "key mode":
			try {
				l_nValue := l_sValue + 0
				return (l_nValue >= KEY_MODE_DISABLED && l_nValue <= KEY_MODE_AUTOFIRE_HOLD) ? l_nValue : p_sDefault
			} catch TypeError {
				return p_sDefault
			}
		default:
			return l_sValue
	}
}

Init()
{
	global g_guiSettings

	ReadConfigFile()
	RestartAsAdminIfNeeded()
	SetTimer(OnFocusChanged, g_nFocusCheckInterval)
	GuiCreate()
	A_TrayMenu.Insert("&Suspend Hotkeys", "Configure Settings", (*) => g_guiSettings.Show())
}

IsExtraOption(p_sKey)
{
	; https://www.autohotkey.com/docs/v2/lib/If.htm#ExIfInContains
	return StrLower(p_sKey) ~= "i)\A(lbutton|mbutton|rbutton|xbutton1|xbutton2|space|tab|enter|escape|backspace)\z"
}

IsMouseButton(p_sKey)
{
	return StrLower(p_sKey) ~= "i)\A(lbutton|mbutton|rbutton|xbutton1|xbutton2)\z"
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
			g_mapStates["bAiming"] := p_bToggle
		case g_sCrouchKey:
			g_mapStates["bCrouching"] := p_bToggle
		case g_sSprintKey:
			g_mapStates["bSprinting"] := p_bToggle
		case g_sForwardKey:
			g_mapStates["bAutorunning"] := p_bToggle
	}

	Output(p_sKey == g_sAimKey ? A_ThisFunc "::bAiming(" g_mapStates["bAiming"] ")" : p_sKey == g_sCrouchKey ? A_ThisFunc "::bCrouching(" g_mapStates["bCrouching"] ")" :
	       p_sKey == g_sSprintKey ? A_ThisFunc "::bSprinting(" g_mapStates["bSprinting"] ")" : A_ThisFunc "::bAutorunning(" g_mapStates["bAutorunning"] ")")
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
		g_mapStates["bRestoreAiming"] := false
		g_mapStates["bRestoreCrouching"] := false
		g_mapStates["bRestoreSprinting"] := false
		g_mapStates["bRestoreAutorunning"] := false
		g_mapStates["bRestoreAutofireAiming"] := false
		g_mapStates["bRestoreAutofireCrouching"] := false
		g_mapStates["bRestoreAutofireSprinting"] := false
	}

	; Restore autofire toggle states
	if (ShouldRestoreAutofiresOnFocus())
	{
		Output(A_ThisFunc "::restoreAutofireToggleStates(" g_mapStates["bRestoreAutofireAiming"] ", " g_mapStates["bRestoreAutofireCrouching"] ", " g_mapStates["bRestoreAutofireSprinting"] ")")

		if (g_mapStates["bRestoreAutofireAiming"])
			OnKeyPress(g_sAimAutofireKey)
		if (g_mapStates["bRestoreAutofireCrouching"])
			OnKeyPress(g_sCrouchAutofireKey)
		if (g_mapStates["bRestoreAutofireSprinting"])
			OnKeyPress(g_sSprintAutofireKey)
	}

	; Restore toggle states
	if (ShouldRestoreTogglesOnFocus())
	{
		Output(A_ThisFunc "::restoreToggleStates(" g_mapStates["bRestoreAiming"] ", " g_mapStates["bRestoreCrouching"] ", " g_mapStates["bRestoreSprinting"] ")")

		if (g_mapStates["bRestoreAiming"])
			KeyToggle(g_sAimKey, true)
		if (g_mapStates["bRestoreCrouching"])
			KeyToggle(g_sCrouchKey, true)
		if (g_mapStates["bRestoreSprinting"])
			KeyToggle(g_sSprintKey, true)
		if (g_mapStates["bRestoreAutorunning"])
			KeyToggle(g_sForwardKey, true)
	}

	Output(A_ThisFunc "::WinWaitNotActive")
	WinWaitNotActive(g_sWindowName " ahk_exe " g_sProcessName)

	; Save toggle states
	if (ShouldRestoreTogglesOnFocus())
	{
		; A snapshot of the toggle states was already taken elsewhere, don't take another one
		if (g_mapStates["bToggleKeysSnapshotTaken"])
			g_mapStates["bToggleKeysSnapshotTaken"] := false
		else
		{
			Output(A_ThisFunc "::saveToggleStates(" g_mapStates["bRestoreAiming"] ", " g_mapStates["bRestoreCrouching"] ", " g_mapStates["bRestoreSprinting"] ")")

			g_mapStates["bRestoreAiming"] := g_mapStates["bAiming"]
			g_mapStates["bRestoreCrouching"] := g_mapStates["bCrouching"]
			g_mapStates["bRestoreSprinting"] := g_mapStates["bSprinting"]
			g_mapStates["bRestoreAutorunning"] := g_mapStates["bAutorunning"]
			g_mapStates["bRestoreAutofireAiming"] := g_mapStates["bAutofireAiming"]
			g_mapStates["bRestoreAutofireCrouching"] := g_mapStates["bAutofireCrouching"]
			g_mapStates["bRestoreAutofireSprinting"] := g_mapStates["bAutofireSprinting"]
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
		case g_sAutorunKey:
			l_nKeyMode := g_bAutorunMode
		; Pressing the forward/backward key disables autorunning
		case g_sForwardKey:
			g_mapStates["bAutorunning"] := false
		case g_sBackwardKey:
			if (g_mapStates["bAutorunning"])
			{
				KeyToggle(g_sForwardKey, false)
				KeyWait(g_sBackwardKey)
			}
	}

	;Output(A_ThisFunc "::" pThisHotkey " lKeyMode(" lKeyMode ")")

	switch l_nKeyMode
	{
		case KEY_MODE_TOGGLE:
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
					KeyToggle(g_sAimKey, !g_mapStates["bAiming"], true)
				else if (l_sCleanHotkey == g_sCrouchKey)
					KeyToggle(g_sCrouchKey, !g_mapStates["bCrouching"], true)
				else if (l_sCleanHotkey == g_sSprintKey)
					KeyToggle(g_sSprintKey, !g_mapStates["bSprinting"], true)
				else if (l_sCleanHotkey == g_sAutorunKey)
				{
					; Autorun will engage even if the forward/backward key was physically pressed
					if (GetKeyState(g_sBackwardKey, "P"))
						SendKey(g_sBackwardKey)

					KeyWait(g_sForwardKey)
					KeyToggle(g_sForwardKey, !g_mapStates["bAutorunning"])
					KeyWait(g_sAutorunKey)
				}
			}
		case KEY_MODE_HOLD:
			KeyHold(l_sCleanHotkey)
		; Based on https://autohotkey.com/board/topic/64576-the-definitive-autofire-thread/?p=407264
		case KEY_MODE_AUTOFIRE_TOGGLE:
			if (l_sCleanHotkey == g_sAimAutofireKey)
			{
				g_mapStates["bAutofireAiming"] := !g_mapStates["bAutofireAiming"]
				SetTimer(g_fnAutofireAim, g_mapStates["bAutofireAiming"] ? g_nAutofireKeyInterval : 0)
			}
			else if (l_sCleanHotkey == g_sCrouchAutofireKey)
			{
				g_mapStates["bAutofireCrouching"] := !g_mapStates["bAutofireCrouching"]
				SetTimer(g_fnAutofireCrouch, g_mapStates["bAutofireCrouching"] ? g_nAutofireKeyInterval : 0)
			}
			else if (l_sCleanHotkey == g_sSprintAutofireKey)
			{
				g_mapStates["bAutofireSprinting"] := !g_mapStates["bAutofireSprinting"]
				SetTimer(g_fnAutofireSprint, g_mapStates["bAutofireSprinting"] ? g_nAutofireKeyInterval : 0)
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
	g_sProcessName := IniReadEnforceType(l_sConfigFileName, "General", "processName", "", String)
	g_sWindowName := IniReadEnforceType(l_sConfigFileName, "General", "windowName", "", String)
	g_nAutofireKeyInterval := IniReadEnforceType(l_sConfigFileName, "General", "autofireKeyInterval", 100, Number)
	g_bFixSystemKeys := IniReadEnforceType(l_sConfigFileName, "General", "fixSystemKeys", 1, "bool")
	g_nFocusCheckInterval := IniReadEnforceType(l_sConfigFileName, "General", "focusCheckInterval", 1000, Number)
	g_nHookDelay := IniReadEnforceType(l_sConfigFileName, "General", "hookDelay", 0, Number)
	g_nKeyDelay := IniReadEnforceType(l_sConfigFileName, "General", "keyDelay", 0, Number)
	g_bRestoreAutofiresOnFocus := IniReadEnforceType(l_sConfigFileName, "General", "restoreAutofiresOnFocus", 0, "bool")
	g_bRestoreTogglesOnFocus := IniReadEnforceType(l_sConfigFileName, "General", "restoreTogglesOnFocus", 0, "bool")
	g_bRunAsAdmin := IniReadEnforceType(l_sConfigFileName, "General", "runAsAdmin", 0, "bool")
	g_nShowNotifications := IniReadEnforceType(l_sConfigFileName, "General", "showNotifications", 0, Number)
	g_nAimMode := IniReadEnforceType(l_sConfigFileName, "General", "aimMode", 0, "key mode")
	g_nCrouchMode := IniReadEnforceType(l_sConfigFileName, "General", "crouchMode", 0, "key mode")
	g_nSprintMode := IniReadEnforceType(l_sConfigFileName, "General", "sprintMode", 0, "key mode")
	g_bAutorunMode := IniReadEnforceType(l_sConfigFileName, "General", "autorunMode", 0, "bool")

	; Main keys
	g_sAimKey := IniRead(l_sConfigFileName, "Keys", "aimKey", "RButton")
	g_sCrouchKey := IniRead(l_sConfigFileName, "Keys", "crouchKey", "LCtrl")
	g_sSprintKey := IniRead(l_sConfigFileName, "Keys", "sprintKey", "LShift")

	; Autorun keys
	g_sAutorunKey := IniRead(l_sConfigFileName, "Keys", "autorunKey", "F1")
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
	Hotkey("*$" g_sAutorunKey, OnKeyPress, g_bAutorunMode == KEY_MODE_TOGGLE ? "On" : "Off")
	Hotkey("~*$" g_sForwardKey, OnKeyPress, g_bAutorunMode == KEY_MODE_TOGGLE ? "On" : "Off")
	Hotkey("~*$" g_sBackwardKey, OnKeyPress, g_bAutorunMode == KEY_MODE_TOGGLE ? "On" : "Off")

	; Enabled only for autofire modes
	Hotkey("*$" g_sAimAutofireKey, OnKeyPress, g_nAimMode == KEY_MODE_AUTOFIRE_TOGGLE || g_nAimMode == KEY_MODE_AUTOFIRE_HOLD  ? "On" : "Off")
	Hotkey("*$" g_sCrouchAutofireKey, OnKeyPress, g_nCrouchMode == KEY_MODE_AUTOFIRE_TOGGLE || g_nCrouchMode == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")
	Hotkey("*$" g_sSprintAutofireKey, OnKeyPress, g_nSprintMode == KEY_MODE_AUTOFIRE_TOGGLE || g_nSprintMode == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")

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

	Output(A_ThisFunc "::states(" g_mapStates["bAiming"] ", " g_mapStates["bCrouching"] ", " g_mapStates["bSprinting"] ", " g_mapStates["bAutorunning"] ")")

	; Release all toggle keys
	if (g_mapStates["bAiming"])
		KeyToggle(g_sAimKey, false)
	if (g_mapStates["bCrouching"])
		KeyToggle(g_sCrouchKey, false)
	if (g_mapStates["bSprinting"])
		KeyToggle(g_sSprintKey, false)
	if (g_mapStates["bAutorunning"])
		KeyToggle(g_sForwardKey, false)

	g_mapStates["bAutofireAiming"] := false
	g_mapStates["bAutofireCrouching"] := false
	g_mapStates["bAutofireSprinting"] := false

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
	return g_bRestoreAutofiresOnFocus && (g_nAimMode == KEY_MODE_AUTOFIRE_TOGGLE || g_nCrouchMode == KEY_MODE_AUTOFIRE_TOGGLE ||
	       g_nSprintMode == KEY_MODE_AUTOFIRE_TOGGLE) && WinExist("ahk_id " g_nWindowID)
}

ShouldRestoreTogglesOnFocus()
{
	return g_bRestoreTogglesOnFocus && (g_nAimMode == KEY_MODE_TOGGLE || g_nCrouchMode == KEY_MODE_TOGGLE || g_nSprintMode == KEY_MODE_TOGGLE
	       || g_bAutorunMode == KEY_MODE_TOGGLE) && WinExist("ahk_id " g_nWindowID)
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

	g_mapStates["bRestoreAiming"] := g_mapStates["bAiming"]
	g_mapStates["bRestoreCrouching"] := g_mapStates["bCrouching"]
	g_mapStates["bRestoreSprinting"] := g_mapStates["bSprinting"]
	g_mapStates["bRestoreAutorunning"] := g_mapStates["bAutorunning"]
	g_mapStates["bRestoreAutofireAiming"] := g_mapStates["bAutofireAiming"]
	g_mapStates["bRestoreAutofireCrouching"] := g_mapStates["bAutofireCrouching"]
	g_mapStates["bRestoreAutofireSprinting"] := g_mapStates["bAutofireSprinting"]
	g_mapStates["bToggleKeysSnapshotTaken"] := true

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
