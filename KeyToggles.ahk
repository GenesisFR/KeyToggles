; KeyToggles v2.3

/*
TODO
add a light theme
add application profiles (https://stackoverflow.com/questions/45190170/how-can-i-make-this-ini-file-into-a-listview-in-autohotkey)
add loops when adding events
add support for hotkey modifiers (e.g., Ctrl+F1) https://www.autohotkey.com/docs/v2/Hotkeys.htm#Symbols
add text/tooltips when mousing over GUI controls to explain what they do
fix "Error: Target window not found: g_nWindowID := WinGetID(l_sWinTitle)" in OnFocusChanged()
fix modifiers still toggled while clicking outside the window
fix toggles not working when physically holding another toggle key (https://www.reddit.com/r/AutoHotkey/comments/oh65o2/comment/h4phdwu/)
increase default key delay to 25ms to improve compatibility with more games
redo window detection (https://www.reddit.com/r/AutoHotkey/comments/nmewd1/resize_and_move_a_window_every_time_it_gets/gzoogts)
replace IniReadType for bools
replace sleeps with timers
replace ternary operators with coalescing ?? operators where possible
shorten lines below 180 characters
https://dev.to/manikandan/how-to-use-ai-models-locally-in-vs-code-with-the-continue-plugin-with-multi-model-switching-3na0
*/

#Requires Autohotkey v2.0 ; Display an error and quit if this version requirement is not met.
#SingleInstance force     ; Allow only a single instance of the script to run.
#Warn                     ; Enable warnings to assist with detecting common errors.

; Register a function to be called on exit
OnExit(ExitFunc)

; Constants
global KEY_MODE_DISABLED        := 0
global KEY_MODE_TOGGLE          := 1
global KEY_MODE_HOLD            := 2
global KEY_MODE_AUTOFIRE_TOGGLE := 3
global KEY_MODE_AUTOFIRE_HOLD   := 4

; Maps
global g_mapControls := Map()
global g_mapSettings := Map(
	"sProcessName",             "",
	"sWindowName",              "",
	"nAutofireKeyInterval",     100,
	"bFixSystemKeys",           true,
	"nFocusCheckInterval",      1000,
	"nHookDelay",               0,
	"nKeyDelay",                0,
	"bRestoreAutofiresOnFocus", false,
	"bRestoreTogglesOnFocus",   false,
	"bRunAsAdmin",              false,
	"nShowNotifications",       0,
	"nAimMode",                 0,
	"nCrouchMode",              0,
	"nSprintMode",              0,
	"bAutorunMode",             0,
	"sAimKey",                  "RButton",
	"sCrouchKey",               "LCtrl",
	"sSprintKey",               "LShift",
	"sAutorunKey",              "F1",
	"sForwardKey",              "w",
	"sBackwardKey",             "s",
	"sAimAutofireKey",          "F2",
	"sCrouchAutofireKey",       "F3",
	"sSprintAutofireKey",       "F4",
	"bDebugMode",               false
)
global g_mapStates := Map(
	"bAiming",                   false,
	"bCrouching",                false,
	"bSprinting",                false,
	"bAutofireAiming",           false,
	"bAutofireCrouching",        false,
	"bAutofireSprinting",        false,
	"bAutorunning",              false,
	"bRestoreAiming",            false,
	"bRestoreAutofireAiming",    false,
	"bRestoreAutofireCrouching", false,
	"bRestoreAutofireSprinting", false,
	"bRestoreAutorunning",       false,
	"bRestoreCrouching",         false,
	"bRestoreSprinting",         false,
)

; Functors
global g_fnAutofireAim    := 0
global g_fnAutofireCrouch := 0
global g_fnAutofireSprint := 0

; Arrays
global g_arrExtraKeys := ["None", "LButton", "RButton", "MButton", "XButton1", "XButton2", "Space", "Tab", "Enter", "Escape", "Backspace"]
global g_arrKeyModes := ["Disabled", "Toggle", "Hold", "Autofire toggle", "Autofire hold"]

; Others
global g_bToggleKeysSnapshotTaken := false
global g_guiSettings := 0
global g_guiWindowSelector := 0
global g_nWindowID := 0
global g_sConfigFileName := "KeyToggles.ini"

Init()

; Exit script
ExitFunc(p_sExitReason, p_nExitCode)
{
	Output(A_ThisFunc "::pExitReason(" p_sExitReason ") pExitCode(" p_nExitCode ")")
	ReleaseAllKeys()
	TrayTip()
}

GetDuplicateHotkeys(p_bFromGUI := true)
{
	l_arrHotkeys := [
		p_bFromGUI ? g_mapControls["hkAimKey"].Value            : g_mapSettings["sAimKey"],
		p_bFromGUI ? g_mapControls["hkCrouchKey"].Value         : g_mapSettings["sCrouchKey"],
		p_bFromGUI ? g_mapControls["hkSprintKey"].Value         : g_mapSettings["sSprintKey"],
		p_bFromGUI ? g_mapControls["hkAutorunKey"].Value        : g_mapSettings["sAutorunKey"],
		p_bFromGUI ? g_mapControls["hkForwardKey"].Value        : g_mapSettings["sForwardKey"],
		p_bFromGUI ? g_mapControls["hkBackwardKey"].Value       : g_mapSettings["sBackwardKey"],
		p_bFromGUI ? g_mapControls["hkAimAutofireKey"].Value    : g_mapSettings["sAimAutofireKey"],
		p_bFromGUI ? g_mapControls["hkCrouchAutofireKey"].Value : g_mapSettings["sCrouchAutofireKey"],
		p_bFromGUI ? g_mapControls["hkSprintAutofireKey"].Value : g_mapSettings["sSprintAutofireKey"] 
	]

	l_mapHotkeys := Map()
	l_sDuplicateHotkeys := ""

	for l_sValue in l_arrHotkeys
	{
		if (l_sValue != "")
		{
			; That's a duplicate
			if (l_mapHotkeys.Has(l_sValue))
			{
				if (++l_mapHotkeys[l_sValue] == 2)
					l_sDuplicateHotkeys .= l_sDuplicateHotkeys ? ", " l_sValue : l_sValue
			}
			else
				l_mapHotkeys[l_sValue] := 1
		}
	}

	return l_sDuplicateHotkeys
}

; Browse for process executable
GuiButtonBrowse_Click(*)
{
	; Turn FileSelect and MsgBox into modals
	g_guiSettings.Opt("+OwnDialogs")

	; Only allow selecting executables by default
	l_sSelectedFile := FileSelect("3", , "Select the target executable file", "Executable Files (*.exe)")

	if (l_sSelectedFile != "")
	{
		l_sFileName := RegExReplace(l_sSelectedFile, "^.+[\\/]")
		l_bIsProcessNameValid := IsProcessNameValid(l_sFileName)

		; Process name not valid, do nothing
		if (l_bIsProcessNameValid != 1)
		{
			MsgBox('"' l_sFileName '" is not an executable file.', , "Icon!")
			return
		}

		g_mapControls["editProcessName"].Value := l_sFileName
		g_mapControls["editWindowName"].Value := ""
	}
}

; Update the GUI controls with the values from the config file
GuiButtonReload_Click(*)
{
	ReadConfigFile()
	GuiUpdate()
	;StartFocusCheck()
}

; Validate and save settings to the config file
GuiButtonSave_Click(*)
{
	; Turn MsgBoxes into modals
	g_guiSettings.Opt("+OwnDialogs")

	if (WriteConfigFile())
	{
		UnregisterHotkeys()
		; Force the hotkeys to be re-registered
		global g_nWindowID := 0
		ReadConfigFile()
		StartFocusCheck()
		MsgBox("Settings saved!", , "Iconi")
	}
}

GuiButtonSelect_Click(*)
{
	global g_guiWindowSelector

	; Turn the window selector GUI into a modal
	g_guiSettings.Opt("+Disabled")

	; Create the window selector GUI if it doesn't exist
	if (!g_guiWindowSelector)
	{
		; Gui
		g_guiWindowSelector := Gui.Call("+Owner" g_guiSettings.Hwnd " -MinimizeBox -MaximizeBox", "Window selector")
		g_guiWindowSelector.BackColor := "353434"
		g_guiWindowSelector.SetFont("s10")
		g_guiWindowSelector.OnEvent("Close", (*) => g_guiSettings.Opt("-Disabled"))

		; Button
		g_guiWindowSelector.AddButton("Background353434 Default w100", "&Refresh").OnEvent("Click", (*) => GuiLV_ReloadProcesses())

		; Checkbox
		g_guiWindowSelector.SetFont("CWhite")
		g_mapControls["cbExcludeProcesses"] := g_guiWindowSelector.AddCheckbox("Checked", "Exclude common processes")
		g_mapControls["cbExcludeProcesses"].OnEvent("Click", (*) => GuiLV_ReloadProcesses())

		; ListView
		g_mapControls["lvWindowPicker"] := g_guiWindowSelector.AddListView("Background353434 -Multi ReadOnly Sort Tile w1045" , ["Icon", "Process"])
		g_mapControls["lvWindowPicker"].OnEvent("DoubleClick", GuiLV_DoubleClick)
	}

	GuiLV_ReloadProcesses()
	g_guiWindowSelector.Show()
}

GuiCreate()
{
	global

	; Safety check
	if (g_guiSettings)
		return

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
	g_mapControls["editProcessName"] := g_guiSettings.AddEdit("CBlack r1 x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth,
	                                                          g_mapSettings["sProcessName"])
	;g_mapSettings["editProcessName"].OnEvent("Focus", (*) => ToolTip("Enter the name of the target process executable (e.g., game.exe)."))
	;g_mapSettings["editProcessName"].OnEvent("LoseFocus", (*) => ToolTip())

	g_guiSettings.AddButton("Background353434 x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " h23 w" l_nRightWidth, "Browse").OnEvent("Click", GuiButtonBrowse_Click)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Window name")
	g_mapControls["editWindowName"] := g_guiSettings.AddEdit("CBlack r1 x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth,
	                                                         g_mapSettings["sWindowName"])

	g_guiSettings.AddButton("Background353434 x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " h23 w" l_nRightWidth, "Select").OnEvent("Click", GuiButtonSelect_Click)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Autofire key interval")
	g_mapControls["editAutofireKeyInterval"] := g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth)
	g_mapControls["udAutofireKeyInterval"] := g_guiSettings.AddUpDown("Range1-10000 0x80", g_mapSettings["nAutofireKeyInterval"])

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Focus check interval")
	g_mapControls["editFocusCheckInterval"] := g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth)
	g_mapControls["udFocusCheckInterval"] := g_guiSettings.AddUpDown("Range1-10000 0x80", g_mapSettings["nFocusCheckInterval"])

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Hook delay")
	g_mapControls["editHookDelay"] := g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth)
	g_mapControls["udHookDelay"] := g_guiSettings.AddUpDown("Range0-10000 0x80", g_mapSettings["nHookDelay"])

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Key delay")
	g_mapControls["editKeyDelay"] := g_guiSettings.AddEdit("CBlack Number x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth)
	g_mapControls["udKeyDelay"] := g_guiSettings.AddUpDown("Range0-1000 0x80", g_mapSettings["nKeyDelay"])

	; Save states
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow + 5 " h" 2*35
	                          " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Save states")
	g_mapControls["cbRestoreAutofiresOnFocus"] := g_guiSettings.AddCheckbox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth + 23
	                                                                        " Checked" g_mapSettings["bRestoreAutofiresOnFocus"], "Restore autofires on focus  ")
	g_mapControls["cbRestoreTogglesOnFocus"] := g_guiSettings.AddCheckbox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth + 23
	                                                                      " Checked" g_mapSettings["bRestoreTogglesOnFocus"], "Restore toggles on focus  ")

	; Key modes
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " h" 4*31
	                          " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Key modes")
	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Aim")
	g_mapControls["ddlAimMode"] := g_guiSettings.AddDropDownList("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth
	                                                             " Choose" g_mapSettings["nAimMode"] + 1, g_arrKeyModes)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Crouch")
	g_mapControls["ddlCrouchMode"] := g_guiSettings.AddDropDownList("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth
	                                                                " Choose" g_mapSettings["nCrouchMode"] + 1, g_arrKeyModes)

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Sprint")
	g_mapControls["ddlSprintMode"] := g_guiSettings.AddDropDownList("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth
	                                                                " Choose" g_mapSettings["nSprintMode"] + 1, g_arrKeyModes)

	g_mapControls["cbAutorun"] := g_guiSettings.AddCheckBox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth + 23
	                                                        " Checked" g_mapSettings["bAutorunMode"], "Autorun  ")

	; Hotkeys
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " h" 9*28 + 3
	                          " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Hotkeys")

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Aim")
	g_mapControls["hkAimKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth,
		                                                 g_mapSettings["sAimKey"])
	g_mapControls["ddlAimKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlAimKey"].Text := IsExtraOption(g_mapSettings["sAimKey"]) ? g_mapSettings["sAimKey"] : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Crouch")
	g_mapControls["hkCrouchKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth,
	                                                        g_mapSettings["sCrouchKey"])
	g_mapControls["ddlCrouchKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth,
	                                                               g_arrExtraKeys)
	g_mapControls["ddlCrouchKey"].Text := IsExtraOption(g_mapSettings["sCrouchKey"]) ? g_mapSettings["sCrouchKey"] : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Sprint")
	g_mapControls["hkSprintKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth,
	                                                        g_mapSettings["sSprintKey"])
	g_mapControls["ddlSprintKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth,
	                                                               g_arrExtraKeys)
	g_mapControls["ddlSprintKey"].Text := IsExtraOption(g_mapSettings["sSprintKey"]) ? g_mapSettings["sSprintKey"] : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Autorun")
	g_mapControls["hkAutorunKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth,
	g_mapSettings["sAutorunKey"])
	g_mapControls["ddlAutorunKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth,
	                                                                g_arrExtraKeys)
	g_mapControls["ddlAutorunKey"].Text := IsExtraOption(g_mapSettings["sAutorunKey"]) ? g_mapSettings["sAutorunKey"] : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Forward")
	g_mapControls["hkForwardKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth,
	                                                         g_mapSettings["sForwardKey"])
	g_mapControls["ddlForwardKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth,
	                                                                g_arrExtraKeys)
	g_mapControls["ddlForwardKey"].Text := IsExtraOption(g_mapSettings["sForwardKey"]) ? g_mapSettings["sForwardKey"] : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Backward")
	g_mapControls["hkBackwardKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth,
	                                                          g_mapSettings["sBackwardKey"])
	g_mapControls["ddlBackwardKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nRightWidth,
	                                   g_arrExtraKeys)
	g_mapControls["ddlBackwardKey"].Text := IsExtraOption(g_mapSettings["sBackwardKey"]) ? g_mapSettings["sBackwardKey"] : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Aim autofire")
	g_mapControls["hkAimAutofireKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                             " w" l_nMiddleWidth, g_mapSettings["sAimAutofireKey"])
	g_mapControls["ddlAimAutofireKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                                    " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlAimAutofireKey"].Text := IsExtraOption(g_mapSettings["sAimAutofireKey"]) ? g_mapSettings["sAimAutofireKey"] : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Crouch autofire")
	g_mapControls["hkCrouchAutofireKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                                " w" l_nMiddleWidth, g_mapSettings["sCrouchAutofireKey"])
	g_mapControls["ddlCrouchAutofireKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                                       " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlCrouchAutofireKey"].Text := IsExtraOption(g_mapSettings["sCrouchAutofireKey"]) ? g_mapSettings["sCrouchAutofireKey"] : "None"

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Sprint autofire")
	g_mapControls["hkSprintAutofireKey"] := g_guiSettings.AddHotkey("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                                " w" l_nMiddleWidth, g_mapSettings["sSprintAutofireKey"])
	g_mapControls["ddlSprintAutofireKey"] := g_guiSettings.AddDropDownList("x" l_nRightX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5
	                                                                       " w" l_nRightWidth, g_arrExtraKeys)
	g_mapControls["ddlSprintAutofireKey"].Text := IsExtraOption(g_mapSettings["sSprintAutofireKey"]) ? g_mapSettings["sSprintAutofireKey"] : "None"

	; Misc
	g_guiSettings.AddGroupBox("x" l_nLeftX - 5 " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow + 5 " h" 4*31
	                          " w" (l_nLeftWidth + l_nMiddleWidth + l_nRightWidth + (l_nSpacingX * 4)), "Misc")

	g_mapControls["cbDebugMode"] := g_guiSettings.AddCheckbox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth + 23
                                                              " Checked" g_mapSettings["bDebugMode"], "Debug mode  ")
	g_mapControls["cbFixSystemKeys"] := g_guiSettings.AddCheckbox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth + 23
	                                                              " Checked" g_mapSettings["bFixSystemKeys"], "Fix system keys  ")
	g_mapControls["cbRunAsAdmin"] := g_guiSettings.AddCheckbox("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth + 23
	                                                           " Checked" g_mapSettings["bRunAsAdmin"], "Run as admin  ")

	g_guiSettings.AddText("Right x" l_nLeftX " y" l_nTopY + l_nSpacingY * ++l_nCurrentRow " w" l_nLeftWidth, "Notifications")
	g_mapControls["ddlNotifications"] := g_guiSettings.AddDropDownList("x" l_nMiddleX " y" l_nTopY + l_nSpacingY * l_nCurrentRow - 5 " w" l_nMiddleWidth " Choose"
	                                                                   g_mapSettings["nShowNotifications"] + 1, ["Disabled", "System notifications", "Tooltips"])

	g_guiSettings.AddButton("Background353434 x140 y" l_nTopY + l_nSpacingY * ++l_nCurrentRow + 13 " w100", "Reload").OnEvent("Click", GuiButtonReload_Click)
	g_guiSettings.AddButton("Background353434 x260 y" l_nTopY + l_nSpacingY * l_nCurrentRow + 13 " w100", "Save").OnEvent("Click", GuiButtonSave_Click)

	; Event handlers
	g_mapControls["editAutofireKeyInterval"].OnEvent("Change", GuiEdit_Change)
	g_mapControls["editFocusCheckInterval"].OnEvent( "Change", GuiEdit_Change)
	g_mapControls["editHookDelay"].OnEvent(          "Change", GuiEdit_Change)
	g_mapControls["editKeyDelay"].OnEvent(           "Change", GuiEdit_Change)
	g_mapControls["hkAimKey"].OnEvent(               "Change", GuiHK_Change)
	g_mapControls["hkCrouchKey"].OnEvent(            "Change", GuiHK_Change)
	g_mapControls["hkSprintKey"].OnEvent(            "Change", GuiHK_Change)
	g_mapControls["hkAutorunKey"].OnEvent(           "Change", GuiHK_Change)
	g_mapControls["hkForwardKey"].OnEvent(           "Change", GuiHK_Change)
	g_mapControls["hkBackwardKey"].OnEvent(          "Change", GuiHK_Change)
	g_mapControls["hkAimAutofireKey"].OnEvent(       "Change", GuiHK_Change)
	g_mapControls["hkCrouchAutofireKey"].OnEvent(    "Change", GuiHK_Change)
	g_mapControls["hkSprintAutofireKey"].OnEvent(    "Change", GuiHK_Change)
	g_mapControls["ddlAimKey"].OnEvent(              "Change", GuiDDLExtra_Change)
	g_mapControls["ddlCrouchKey"].OnEvent(           "Change", GuiDDLExtra_Change)
	g_mapControls["ddlSprintKey"].OnEvent(           "Change", GuiDDLExtra_Change)
	g_mapControls["ddlAutorunKey"].OnEvent(          "Change", GuiDDLExtra_Change)
	g_mapControls["ddlForwardKey"].OnEvent(          "Change", GuiDDLExtra_Change)
	g_mapControls["ddlBackwardKey"].OnEvent(         "Change", GuiDDLExtra_Change)
	g_mapControls["ddlAimAutofireKey"].OnEvent(      "Change", GuiDDLExtra_Change)
	g_mapControls["ddlCrouchAutofireKey"].OnEvent(   "Change", GuiDDLExtra_Change)
	g_mapControls["ddlSprintAutofireKey"].OnEvent(   "Change", GuiDDLExtra_Change)
}

; Set hotkey controls text based on selected DDL extra keys
GuiDDLExtra_Change(GuiCtrlObj, Info)
{
	switch GuiCtrlObj
	{
		case g_mapControls["ddlAimKey"]:
			g_mapControls["hkAimKey"].Value            := g_mapControls["ddlAimKey"].Value == 1 ? ""            : g_mapControls["ddlAimKey"].Text
		case g_mapControls["ddlCrouchKey"]:
			g_mapControls["hkCrouchKey"].Value         := g_mapControls["ddlCrouchKey"].Value == 1 ? ""         : g_mapControls["ddlCrouchKey"].Text
		case g_mapControls["ddlSprintKey"]:
			g_mapControls["hkSprintKey"].Value         := g_mapControls["ddlSprintKey"].Value == 1 ? ""         : g_mapControls["ddlSprintKey"].Text
		case g_mapControls["ddlAutorunKey"]:
			g_mapControls["hkAutorunKey"].Value        := g_mapControls["ddlAutorunKey"].Value == 1 ? ""        : g_mapControls["ddlAutorunKey"].Text
		case g_mapControls["ddlForwardKey"]:
			g_mapControls["hkForwardKey"].Value        := g_mapControls["ddlForwardKey"].Value == 1 ? ""        : g_mapControls["ddlForwardKey"].Text
		case g_mapControls["ddlBackwardKey"]:
			g_mapControls["hkBackwardKey"].Value       := g_mapControls["ddlBackwardKey"].Value == 1 ? ""       : g_mapControls["ddlBackwardKey"].Text
		case g_mapControls["ddlAimAutofireKey"]:
			g_mapControls["hkAimAutofireKey"].Value    := g_mapControls["ddlAimAutofireKey"].Value == 1 ? ""    : g_mapControls["ddlAimAutofireKey"].Text
		case g_mapControls["ddlCrouchAutofireKey"]:
			g_mapControls["hkCrouchAutofireKey"].Value := g_mapControls["ddlCrouchAutofireKey"].Value == 1 ? "" : g_mapControls["ddlCrouchAutofireKey"].Text
		case g_mapControls["ddlSprintAutofireKey"]:
			g_mapControls["hkSprintAutofireKey"].Value := g_mapControls["ddlSprintAutofireKey"].Value == 1 ? "" : g_mapControls["ddlSprintAutofireKey"].Text
	}
}

; Prevent intervals from being out-of-bounds, otherwise timers won't work
GuiEdit_Change(GuiCtrlObj, Info)
{
	switch GuiCtrlObj
	{
		case g_mapControls["editAutofireKeyInterval"]:
			l_nMinValue := 1
			l_nMaxValue := 10000
			l_udControl := g_mapControls["udAutofireKeyInterval"]
		case g_mapControls["editFocusCheckInterval"]:
			l_nMinValue := 1
			l_nMaxValue := 10000
			l_udControl := g_mapControls["udFocusCheckInterval"]
		case g_mapControls["editHookDelay"]:
			l_nMinValue := 0
			l_nMaxValue := 10000
			l_udControl := g_mapControls["udHookDelay"]
		case g_mapControls["editKeyDelay"]:
			l_nMinValue := 0
			l_nMaxValue := 1000
			l_udControl := g_mapControls["udKeyDelay"]
	}

	if (GuiCtrlObj.Value == "")
		GuiCtrlObj.Text := l_nMinValue
	else
	{
		l_nValue := Integer(GuiCtrlObj.Value)

		; The UpDown control will automatically clamp the value within its range
		if (l_nValue < l_nMinValue || l_nValue > l_nMaxValue)
			l_udControl.Value := l_nValue
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
		MsgBox("You can't use modified keys!", , "Icon!")
	}
}

GuiLV_DoubleClick(GuiCtrlObj, Info)
{
	; Retrieve the text from the selected row in the ListView
	l_sItemText := GuiCtrlObj.GetText(Info)
	l_arr := StrSplit(l_sItemText, " | ", , 2)

	; Update controls in the main window
	g_mapControls["editProcessName"].Text := l_arr[1]
	g_mapControls["editWindowName"].Text := l_arr.Length > 1 ? l_arr[2] : ""

	g_guiWindowSelector.Hide()
	g_guiSettings.Opt("-Disabled")

	; Needed to bring the main window back to the foreground since it was disabled
	g_guiSettings.Show()
}

GuiLV_ReloadProcesses()
{
	; Get a list of all windows
	l_arrHwnds := WinGetList()
	l_arrHwndsLength := l_arrHwnds.Length

	; Create an ImageList to hold large icons and assign it to the ListView
	g_mapControls["ilWindowPicker"] := IL_Create(l_arrHwndsLength, , true)
	l_ilPrev := g_mapControls["lvWindowPicker"].SetImageList(g_mapControls["ilWindowPicker"])

	; Free up memory used by the previous ImageList
	if (l_ilPrev)
		IL_Destroy(l_ilPrev)

	; Don't redraw until all the rows are added
	g_mapControls["lvWindowPicker"].Opt("-Redraw")

	; Delete all rows
	g_mapControls["lvWindowPicker"].Delete()

	; Create all rows
	for l_hwnd in l_arrHwnds
	{
		; Retrieve process info
		l_sProcName := WinGetProcessName("ahk_id" l_hwnd)
		l_sProcPath := WinGetProcessPath("ahk_id" l_hwnd)
		l_sWinClass := WinGetClass("ahk_id" l_hwnd)
		l_sWinTitle := WinGetTitle("ahk_id" l_hwnd)

		; Skip this iteration if the process is in the exclusion list
		if (g_mapControls["cbExcludeProcesses"].Value && IsCommonProcess(l_sProcName))
			continue

		/*
		Output("process: " l_sProcName)
		Output("path: "    l_sProcPath)
		Output("title: "   l_sWinTitle)
		Output("class: "   l_sWinClass)
		Output("--------------------------------------------------")
		*/

		g_mapControls["lvWindowPicker"].Add("Icon" IL_Add(g_mapControls["ilWindowPicker"], l_sProcPath), l_sProcName (l_sWinTitle != "" ? " | " l_sWinTitle : ""))
	}

	g_mapControls["lvWindowPicker"].Opt("+Redraw")
}

; Update GUI controls based on current settings
GuiUpdate()
{
	g_mapControls["cbAutorun"].Value                 := g_mapSettings["bAutorunMode"]
	g_mapControls["cbDebugMode"].Value               := g_mapSettings["bDebugMode"]
	g_mapControls["cbFixSystemKeys"].Value           := g_mapSettings["bFixSystemKeys"]
	g_mapControls["cbRestoreAutofiresOnFocus"].Value := g_mapSettings["bRestoreAutofiresOnFocus"]
	g_mapControls["cbRestoreTogglesOnFocus"].Value   := g_mapSettings["bRestoreTogglesOnFocus"]
	g_mapControls["cbRunAsAdmin"].Value              := g_mapSettings["bRunAsAdmin"]
	g_mapControls["ddlAimAutofireKey"].Text          := IsExtraOption(g_mapSettings["sAimAutofireKey"])    ? g_mapSettings["sAimAutofireKey"] : "None"
	g_mapControls["ddlAimKey"].Text                  := IsExtraOption(g_mapSettings["sAimKey"])            ? g_mapSettings["sAimKey"] : "None"
	g_mapControls["ddlAimMode"].Value                := g_mapSettings["nAimMode"] + 1
	g_mapControls["ddlAutorunKey"].Text              := IsExtraOption(g_mapSettings["sAutorunKey"])        ? g_mapSettings["sAutorunKey"] : "None"
	g_mapControls["ddlBackwardKey"].Text             := IsExtraOption(g_mapSettings["sBackwardKey"])       ? g_mapSettings["sBackwardKey"] : "None"
	g_mapControls["ddlCrouchAutofireKey"].Text       := IsExtraOption(g_mapSettings["sCrouchAutofireKey"]) ? g_mapSettings["sCrouchAutofireKey"] : "None"
	g_mapControls["ddlCrouchKey"].Text               := IsExtraOption(g_mapSettings["sCrouchKey"])         ? g_mapSettings["sCrouchKey"] : "None"
	g_mapControls["ddlCrouchMode"].Value             := g_mapSettings["nCrouchMode"] + 1
	g_mapControls["ddlForwardKey"].Text              := IsExtraOption(g_mapSettings["sForwardKey"])        ? g_mapSettings["sForwardKey"] : "None"
	g_mapControls["ddlNotifications"].Value          := g_mapSettings["nShowNotifications"] + 1
	g_mapControls["ddlSprintAutofireKey"].Text       := IsExtraOption(g_mapSettings["sSprintAutofireKey"]) ? g_mapSettings["sSprintAutofireKey"] : "None"
	g_mapControls["ddlSprintKey"].Text               := IsExtraOption(g_mapSettings["sSprintKey"])         ? g_mapSettings["sSprintKey"] : "None"
	g_mapControls["ddlSprintMode"].Value             := g_mapSettings["nSprintMode"] + 1
	g_mapControls["editProcessName"].Value           := g_mapSettings["sProcessName"]
	g_mapControls["editWindowName"].Value            := g_mapSettings["sWindowName"]
	g_mapControls["hkAimAutofireKey"].Value          := g_mapSettings["sAimAutofireKey"]
	g_mapControls["hkAimKey"].Value                  := g_mapSettings["sAimKey"]
	g_mapControls["hkAutorunKey"].Value              := g_mapSettings["sAutorunKey"]
	g_mapControls["hkBackwardKey"].Value             := g_mapSettings["sBackwardKey"]
	g_mapControls["hkCrouchAutofireKey"].Value       := g_mapSettings["sCrouchAutofireKey"]
	g_mapControls["hkCrouchKey"].Value               := g_mapSettings["sCrouchKey"]
	g_mapControls["hkForwardKey"].Value              := g_mapSettings["sForwardKey"]
	g_mapControls["hkSprintAutofireKey"].Value       := g_mapSettings["sSprintAutofireKey"]
	g_mapControls["hkSprintKey"].Value               := g_mapSettings["sSprintKey"]
	g_mapControls["udAutofireKeyInterval"].Value     := g_mapSettings["nAutofireKeyInterval"]
	g_mapControls["udFocusCheckInterval"].Value      := g_mapSettings["nFocusCheckInterval"]
	g_mapControls["udHookDelay"].Value               := g_mapSettings["nHookDelay"]
	g_mapControls["udKeyDelay"].Value                := g_mapSettings["nKeyDelay"]
}

IniReadType(p_sFile, p_sSection, p_sKey, p_sDefault, p_sType)
{
	l_sValue := IniRead(p_sFile, p_sSection, p_sKey, p_sDefault)

	switch p_sType
	{
		case "int":
			try
			{
				l_nValue := l_sValue + 0
				return Max(0, l_nValue) ; no negative integer
			}
			catch TypeError ; not an integer
			{
				return p_sDefault
			}
		case "str":
			; Validate process name
			l_bIsProcessNameValid := IsProcessNameValid(l_sValue) == 1
			return l_bIsProcessNameValid ? l_sValue : p_sDefault
		case "bool":
			return l_sValue == "1" ? true : l_sValue == "0" ? false : p_sDefault
		case "mode":
			try
			{
				l_nValue := l_sValue + 0
				return (l_nValue >= KEY_MODE_DISABLED && l_nValue <= KEY_MODE_AUTOFIRE_HOLD) ? l_nValue : p_sDefault
			}
			catch TypeError ; not an integer
			{
				return p_sDefault
			}
		default:
			return l_sValue
	}
}

Init()
{
	ReadConfigFile()
	RestartAsAdminIfNeeded()
	GuiCreate()
	StartFocusCheck()
	A_TrayMenu.Insert("&Suspend Hotkeys", "Configure Settings", (*) => g_guiSettings.Show())
	A_TrayMenu.ClickCount := 1
	A_TrayMenu.Default := "Configure Settings"
}

IsCommonProcess(p_sProcessName)
{
	l_sCommonProcesses := "
	( Join| ; AHK | Game launchers | Misc | Web browsers | Windows
		autohotkey.exe|autohotkey32.exe|autohotkey64.exe|autohotkeyux.exe|keytoggles.exe
		amazon games ui.exe|battle.net launcher.exe|eadesktop.exe|epicgameslauncher.exe|galaxyclient.exe|launcher.exe|steam.exe|steamwebhelper.exe|upc.exe
		7zfm.exe|discord.exe|msiafterburner.exe|notepad++.exe|nvcplui.exe|obs.exe|obs64.exe|rtss.exe|vlc.exe|winamp.exe|winrar.exe|wmplayer.exe
		brave.exe|chrome.exe|firefox.exe|iexplore.exe|msedge.exe|opera.exe|safari.exe
		applicationframehost.exe|calc.exe|cmd.exe|control.exe|explorer.exe|eventvwr.exe|hh.exe|notepad.exe|mspaint.exe|powershell.exe|regedit.exe
		rundll32.exe|svchost.exe|taskmgr.exe|windowsterminal.exe
	)"
	return StrLower(p_sProcessName) ~= l_sCommonProcesses
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

IsProcessNameValid(p_sProcessName)
{
	p_sProcessName := Trim(p_sProcessName)

	if (p_sProcessName == "")
		return -1

	return RegExMatch(p_sProcessName, ".*.exe$")
}

IsWindowVisible(p_hwnd)
{
	return WinGetStyle("ahk_id " p_hwnd) & 0x10000000
}

KeyAutofire(p_sAutofireKey)
{
	Output(A_ThisFunc "::begin")

	switch p_sAutofireKey
	{
		case g_mapSettings["sAimAutofireKey"]:
			SendKey(g_mapSettings["sAimKey"], g_mapSettings["nKeyDelay"])
		case g_mapSettings["sCrouchAutofireKey"]:
			SendKey(g_mapSettings["sCrouchKey"], g_mapSettings["nKeyDelay"])
		case g_mapSettings["sSprintAutofireKey"]:
			SendKey(g_mapSettings["sSprintKey"], g_mapSettings["nKeyDelay"])
	}

	Output(A_ThisFunc "::end")
}

KeyHold(p_sKey)
{
	;Output(A_ThisFunc "::begin")
	SendKey(p_sKey, g_mapSettings["nKeyDelay"])
	KeyWait(p_sKey)
	SendKey(p_sKey, g_mapSettings["nKeyDelay"])
	;Output(A_ThisFunc "::end")
}

KeyToggle(p_sKey, p_bToggle, p_bWait := false)
{
	global

	Output(A_ThisFunc "::begin")

	switch p_sKey
	{
		case g_mapSettings["sAimKey"]:
			g_mapStates["bAiming"] := p_bToggle
		case g_mapSettings["sCrouchKey"]:
			g_mapStates["bCrouching"] := p_bToggle
		case g_mapSettings["sSprintKey"]:
			g_mapStates["bSprinting"] := p_bToggle
		case g_mapSettings["sForwardKey"]:
			g_mapStates["bAutorunning"] := p_bToggle
	}

	Output(
		p_sKey == g_mapSettings["sAimKey"] ? A_ThisFunc "::bAiming(" g_mapStates["bAiming"] ")" : p_sKey == g_mapSettings["sCrouchKey"] ?
		A_ThisFunc "::bCrouching(" g_mapStates["bCrouching"] ")" : p_sKey == g_mapSettings["sSprintKey"] ? A_ThisFunc "::bSprinting("
		g_mapStates["bSprinting"] ")" : A_ThisFunc "::bAutorunning(" g_mapStates["bAutorunning"] ")"
	)
	SendInput(p_bToggle ? "{Blind}{" p_sKey " down}" : "{Blind}{" p_sKey " up}")

	if (p_bWait)
		KeyWait(p_sKey)

	Output(A_ThisFunc "::end")
}

; Handle clicking outside the window while a mouse button is toggled
OnClickOutsideWindow(p_sThisHotkey)
{
	l_sCleanHotkey := LTrim(p_sThisHotkey, "*$")
	Output(A_ThisFunc "::" l_sCleanHotkey)
	SendClickOutsideWindow(l_sCleanHotkey)
}

; Hook the window and register hotkeys if necessary, disable toggles on focus lost and optionally restore them on focus
OnFocusChanged()
{
	global

	Output(A_ThisFunc "::WinWaitActive")

	; We need to store this until the function completes as the user could update the process/window name before WinWaitActive times out
	local l_sWinTitle := g_mapSettings["sWindowName"] " ahk_exe " g_mapSettings["sProcessName"]
	local l_nTimeout := g_mapSettings["nFocusCheckInterval"] * 0.001

	if (WinWaitActive(l_sWinTitle,, l_nTimeout))
	{
		if (g_mapSettings["nHookDelay"] > 0)
			Sleep(g_mapSettings["nHookDelay"])

		; Make sure to hook the window again if it no longer exists
		if (g_nWindowID != WinExist(l_sWinTitle))
		{
			g_nWindowID := WinGetID(l_sWinTitle)
			Output(A_ThisFunc "::WinGet(" g_nWindowID ")")
			RegisterHotkeys()

			if (g_nWindowID)
				ShowNotification('The window "' WinGetTitle(g_nWindowID) '" has been hooked.')

			; That's a different window, don't restore toggle states
			g_mapStates["bRestoreAiming"]            := false
			g_mapStates["bRestoreCrouching"]         := false
			g_mapStates["bRestoreSprinting"]         := false
			g_mapStates["bRestoreAutorunning"]       := false
			g_mapStates["bRestoreAutofireAiming"]    := false
			g_mapStates["bRestoreAutofireCrouching"] := false
			g_mapStates["bRestoreAutofireSprinting"] := false
		}

		; Restore autofire toggle states
		if (ShouldRestoreAutofiresOnFocus())
		{
			Output(
				A_ThisFunc "::restoreAutofireToggleStates(" g_mapStates["bRestoreAutofireAiming"] ", " g_mapStates["bRestoreAutofireCrouching"] ", "
				g_mapStates["bRestoreAutofireSprinting"] ")"
			)

			if (g_mapStates["bRestoreAutofireAiming"])
				OnKeyPress(g_mapSettings["sAimAutofireKey"])
			if (g_mapStates["bRestoreAutofireCrouching"])
				OnKeyPress(g_mapSettings["sCrouchAutofireKey"])
			if (g_mapStates["bRestoreAutofireSprinting"])
				OnKeyPress(g_mapSettings["sSprintAutofireKey"])
		}

		; Restore toggle states
		if (ShouldRestoreTogglesOnFocus())
		{
			Output(A_ThisFunc "::restoreToggleStates(" g_mapStates["bRestoreAiming"] ", " g_mapStates["bRestoreCrouching"] ", " g_mapStates["bRestoreSprinting"] ")")

			if (g_mapStates["bRestoreAiming"])
				KeyToggle(g_mapSettings["sAimKey"], true)
			if (g_mapStates["bRestoreCrouching"])
				KeyToggle(g_mapSettings["sCrouchKey"], true)
			if (g_mapStates["bRestoreSprinting"])
				KeyToggle(g_mapSettings["sSprintKey"], true)
			if (g_mapStates["bRestoreAutorunning"])
				KeyToggle(g_mapSettings["sForwardKey"], true)
		}

		Output(A_ThisFunc "::WinWaitNotActive")
		WinWaitNotActive(l_sWinTitle)

		; Save toggle states
		if (ShouldRestoreTogglesOnFocus())
		{
			; A snapshot of the toggle states was already taken elsewhere, don't take another one
			if (g_bToggleKeysSnapshotTaken)
				g_bToggleKeysSnapshotTaken := false
			else
			{
				Output(A_ThisFunc "::saveToggleStates(" g_mapStates["bRestoreAiming"] ", " g_mapStates["bRestoreCrouching"] ", " g_mapStates["bRestoreSprinting"] ")")

				g_mapStates["bRestoreAiming"]            := g_mapStates["bAiming"]
				g_mapStates["bRestoreCrouching"]         := g_mapStates["bCrouching"]
				g_mapStates["bRestoreSprinting"]         := g_mapStates["bSprinting"]
				g_mapStates["bRestoreAutorunning"]       := g_mapStates["bAutorunning"]
				g_mapStates["bRestoreAutofireAiming"]    := g_mapStates["bAutofireAiming"]
				g_mapStates["bRestoreAutofireCrouching"] := g_mapStates["bAutofireCrouching"]
				g_mapStates["bRestoreAutofireSprinting"] := g_mapStates["bAutofireSprinting"]
			}
		}

		ReleaseAllKeys()
	}
}

OnKeyPress(p_sThisHotkey)
{
	global

	local l_sCleanHotkey := LTrim(p_sThisHotkey, "~*$")
	;local l_sCleanHotkeyNoModifiers := LTrim(p_sThisHotkey, "~*$#!^+")
	local l_nKeyMode := KEY_MODE_DISABLED

	switch l_sCleanHotkey
	{
		case g_mapSettings["sAimKey"], g_mapSettings["sAimAutofireKey"]:
			l_nKeyMode := g_mapSettings["nAimMode"]
		case g_mapSettings["sCrouchKey"], g_mapSettings["sCrouchAutofireKey"]:
			l_nKeyMode := g_mapSettings["nCrouchMode"]
		case g_mapSettings["sSprintKey"], g_mapSettings["sSprintAutofireKey"]:
			l_nKeyMode := g_mapSettings["nSprintMode"]
		case g_mapSettings["sAutorunKey"]:
			l_nKeyMode := g_mapSettings["bAutorunMode"]
		; Pressing the forward/backward key disables autorunning
		case g_mapSettings["sForwardKey"]:
			g_mapStates["bAutorunning"] := false
		case g_mapSettings["sBackwardKey"]:
			if (g_mapStates["bAutorunning"])
			{
				KeyToggle(g_mapSettings["sForwardKey"], false)
				KeyWait(g_mapSettings["sBackwardKey"])
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

				if (l_sCleanHotkey == g_mapSettings["sAimKey"])
					KeyToggle(g_mapSettings["sAimKey"], !g_mapStates["bAiming"], true)
				else if (l_sCleanHotkey == g_mapSettings["sCrouchKey"])
					KeyToggle(g_mapSettings["sCrouchKey"], !g_mapStates["bCrouching"], true)
				else if (l_sCleanHotkey == g_mapSettings["sSprintKey"])
					KeyToggle(g_mapSettings["sSprintKey"], !g_mapStates["bSprinting"], true)
				else if (l_sCleanHotkey == g_mapSettings["sAutorunKey"])
				{
					; Autorun will engage even if the forward/backward key was physically pressed
					if (GetKeyState(g_mapSettings["sBackwardKey"], "P"))
						SendKey(g_mapSettings["sBackwardKey"])

					KeyWait(g_mapSettings["sForwardKey"])
					KeyToggle(g_mapSettings["sForwardKey"], !g_mapStates["bAutorunning"])
					KeyWait(g_mapSettings["sAutorunKey"])
					;KeyWait(l_sCleanHotkeyNoModifiers)
				}
			}
		case KEY_MODE_HOLD:
			KeyHold(l_sCleanHotkey)
		; Based on https://autohotkey.com/board/topic/64576-the-definitive-autofire-thread/?p=407264
		case KEY_MODE_AUTOFIRE_TOGGLE:
			if (l_sCleanHotkey == g_mapSettings["sAimAutofireKey"])
			{
				g_mapStates["bAutofireAiming"] := !g_mapStates["bAutofireAiming"]
				SetTimer(g_fnAutofireAim, g_mapStates["bAutofireAiming"] ? g_mapSettings["nAutofireKeyInterval"] : 0)
			}
			else if (l_sCleanHotkey == g_mapSettings["sCrouchAutofireKey"])
			{
				g_mapStates["bAutofireCrouching"] := !g_mapStates["bAutofireCrouching"]
				SetTimer(g_fnAutofireCrouch, g_mapStates["bAutofireCrouching"] ? g_mapSettings["nAutofireKeyInterval"] : 0)
			}
			else if (l_sCleanHotkey == g_mapSettings["sSprintAutofireKey"])
			{
				g_mapStates["bAutofireSprinting"] := !g_mapStates["bAutofireSprinting"]
				SetTimer(g_fnAutofireSprint, g_mapStates["bAutofireSprinting"] ? g_mapSettings["nAutofireKeyInterval"] : 0)
			}

			KeyWait(l_sCleanHotkey)

			; Fixes a weird bug where the autofire key would stay permanently pressed after holding it down for a few seconds
			SendInput("{Blind}{" l_sCleanHotkey " up}")
		case KEY_MODE_AUTOFIRE_HOLD:
			if (l_sCleanHotkey == g_mapSettings["sAimAutofireKey"])
				SetTimer(g_fnAutofireAim, g_mapSettings["nAutofireKeyInterval"])
			else if (l_sCleanHotkey == g_mapSettings["sCrouchAutofireKey"])
				SetTimer(g_fnAutofireCrouch, g_mapSettings["nAutofireKeyInterval"])
			else if (l_sCleanHotkey == g_mapSettings["sSprintAutofireKey"])
				SetTimer(g_fnAutofireSprint, g_mapSettings["nAutofireKeyInterval"])

			KeyWait(l_sCleanHotkey)

			if (l_sCleanHotkey == g_mapSettings["sAimAutofireKey"])
				SetTimer(g_fnAutofireAim, 0)
			else if (l_sCleanHotkey == g_mapSettings["sCrouchAutofireKey"])
				SetTimer(g_fnAutofireCrouch, 0)
			else if (l_sCleanHotkey == g_mapSettings["sSprintAutofireKey"])
				SetTimer(g_fnAutofireSprint, 0)

			; Fixes a weird bug where the autofire key would stay permanently pressed after holding it down for a few seconds
			SendInput("{Blind}{" l_sCleanHotkey " up}")
	}
}

Output(p_sMessage, p_bSeparator := false)
{
	if (g_mapSettings["bDebugMode"])
	{
		OutputDebug(p_sMessage "`n")

		if (p_bSeparator)
			OutputDebug("--------------------------------------------------`n")
	}
}

ReadConfigFile()
{
	global

	; General
	g_mapSettings["sProcessName"]             :=     IniRead(g_sConfigFileName, "General", "processName", "")
	g_mapSettings["sWindowName"]              :=     IniRead(g_sConfigFileName, "General", "windowName", "")
	g_mapSettings["nAutofireKeyInterval"]     := IniReadType(g_sConfigFileName, "General", "autofireKeyInterval", 100, "int")
	g_mapSettings["bFixSystemKeys"]           := IniReadType(g_sConfigFileName, "General", "fixSystemKeys", 1, "bool")
	g_mapSettings["nFocusCheckInterval"]      := IniReadType(g_sConfigFileName, "General", "focusCheckInterval", 1000, "int")
	g_mapSettings["nHookDelay"]               := IniReadType(g_sConfigFileName, "General", "hookDelay", 0, "int")
	g_mapSettings["nKeyDelay"]                := IniReadType(g_sConfigFileName, "General", "keyDelay", 0, "int")
	g_mapSettings["bRestoreAutofiresOnFocus"] := IniReadType(g_sConfigFileName, "General", "restoreAutofiresOnFocus", false, "bool")
	g_mapSettings["bRestoreTogglesOnFocus"]   := IniReadType(g_sConfigFileName, "General", "restoreTogglesOnFocus", false, "bool")
	g_mapSettings["bRunAsAdmin"]              := IniReadType(g_sConfigFileName, "General", "runAsAdmin", false, "bool")
	g_mapSettings["nShowNotifications"]       := IniReadType(g_sConfigFileName, "General", "showNotifications", 0, "int")
	g_mapSettings["nAimMode"]                 := IniReadType(g_sConfigFileName, "General", "aimMode", 0, "mode")
	g_mapSettings["nCrouchMode"]              := IniReadType(g_sConfigFileName, "General", "crouchMode", 0, "mode")
	g_mapSettings["nSprintMode"]              := IniReadType(g_sConfigFileName, "General", "sprintMode", 0, "mode")
	g_mapSettings["bAutorunMode"]             := IniReadType(g_sConfigFileName, "General", "autorunMode", false, "bool")

	; Main keys
	g_mapSettings["sAimKey"]    := IniRead(g_sConfigFileName, "Keys", "aimKey", "RButton")
	g_mapSettings["sCrouchKey"] := IniRead(g_sConfigFileName, "Keys", "crouchKey", "LCtrl")
	g_mapSettings["sSprintKey"] := IniRead(g_sConfigFileName, "Keys", "sprintKey", "LShift")

	; Autorun keys
	g_mapSettings["sAutorunKey"]  := IniRead(g_sConfigFileName, "Keys", "autorunKey", "F1")
	g_mapSettings["sForwardKey"]  := IniRead(g_sConfigFileName, "Keys", "forwardKey", "w")
	g_mapSettings["sBackwardKey"] := IniRead(g_sConfigFileName, "Keys", "backwardKey", "s")

	; Autofire keys
	g_mapSettings["sAimAutofireKey"]    := IniRead(g_sConfigFileName, "Keys", "aimAutofireKey", "F2")
	g_mapSettings["sCrouchAutofireKey"] := IniRead(g_sConfigFileName, "Keys", "crouchAutofireKey", "F3")
	g_mapSettings["sSprintAutofireKey"] := IniRead(g_sConfigFileName, "Keys", "sprintAutofireKey", "F4")

	; Debug
	g_mapSettings["bDebugMode"] := IniReadType(g_sConfigFileName, "Debug", "debugMode", false, "bool")

	; Prevent intervals from being set to 0, otherwise timers won't work
	g_mapSettings["nAutofireKeyInterval"] := Max(g_mapSettings["nAutofireKeyInterval"], 1)
	g_mapSettings["nFocusCheckInterval"]  := Max(g_mapSettings["nFocusCheckInterval"], 1)
}

RegisterHotkeys()
{
	l_sWinTitle := g_mapSettings["sWindowName"] " ahk_exe " g_mapSettings["sProcessName"]
	HotIf((*) => WinActive(l_sWinTitle))

	; Enabled only for toggle and hold modes
	Hotkey("*$" g_mapSettings["sAimKey"], OnKeyPress, g_mapSettings["nAimMode"] == KEY_MODE_TOGGLE ||
	       g_mapSettings["nAimMode"] == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" g_mapSettings["sCrouchKey"], OnKeyPress, g_mapSettings["nCrouchMode"] == KEY_MODE_TOGGLE ||
	       g_mapSettings["nCrouchMode"] == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" g_mapSettings["sSprintKey"], OnKeyPress, g_mapSettings["nSprintMode"] == KEY_MODE_TOGGLE ||
	       g_mapSettings["nSprintMode"] == KEY_MODE_HOLD ? "On" : "Off")

	; Enabled only for autorun mode
	Hotkey("*$"   g_mapSettings["sAutorunKey"], OnKeyPress, g_mapSettings["bAutorunMode"] == KEY_MODE_TOGGLE ? "On" : "Off")
	Hotkey("~*$"  g_mapSettings["sForwardKey"], OnKeyPress, g_mapSettings["bAutorunMode"] == KEY_MODE_TOGGLE ? "On" : "Off")
	Hotkey("~*$" g_mapSettings["sBackwardKey"], OnKeyPress, g_mapSettings["bAutorunMode"] == KEY_MODE_TOGGLE ? "On" : "Off")

	; Enabled only for autofire modes
	Hotkey("*$" g_mapSettings["sAimAutofireKey"], OnKeyPress, g_mapSettings["nAimMode"] == KEY_MODE_AUTOFIRE_TOGGLE ||
	       g_mapSettings["nAimMode"] == KEY_MODE_AUTOFIRE_HOLD  ? "On" : "Off")
	Hotkey("*$" g_mapSettings["sCrouchAutofireKey"], OnKeyPress, g_mapSettings["nCrouchMode"] == KEY_MODE_AUTOFIRE_TOGGLE ||
	       g_mapSettings["nCrouchMode"] == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")
	Hotkey("*$" g_mapSettings["sSprintAutofireKey"], OnKeyPress, g_mapSettings["nSprintMode"] == KEY_MODE_AUTOFIRE_TOGGLE ||
	       g_mapSettings["nSprintMode"] == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")

	; See https://en.wikipedia.org/wiki/Table_of_keyboard_shortcuts#System_navigation
	; Fixes issues when pressing system keys while toggle keys are modifiers and toggled
	Hotkey("*$" "!Tab",   SendAltTab,  g_mapSettings["bFixSystemKeys"] ? "On" : "Off")
	Hotkey("*$" "Escape", SendEscape,  g_mapSettings["bFixSystemKeys"] ? "On" : "Off")
	Hotkey("*$" "LWin",   SendWindows, g_mapSettings["bFixSystemKeys"] ? "On" : "Off")
	Hotkey("*$" "RWin",   SendWindows, g_mapSettings["bFixSystemKeys"] ? "On" : "Off")

	; Bind our functors to actual functions
	global g_fnAutofireAim    := KeyAutofire.Bind(g_mapSettings["sAimAutofireKey"])
	global g_fnAutofireCrouch := KeyAutofire.Bind(g_mapSettings["sCrouchAutofireKey"])
	global g_fnAutofireSprint := KeyAutofire.Bind(g_mapSettings["sSprintAutofireKey"])

	HotIf((*) => WinActive(l_sWinTitle) && !IsMouseOver(l_sWinTitle))

	RegisterMouseHotkeys()

	HotIf()
}

RegisterMouseHotkeys()
{
	l_mapHotkeys := Map(
		g_mapSettings["sAimKey"], 1,
		g_mapSettings["sCrouchKey"], 1,
		g_mapSettings["sSprintKey"], 1,
		g_mapSettings["sAutorunKey"], 1,
		g_mapSettings["sForwardKey"], 1,
		g_mapSettings["sBackwardKey"], 1,
		g_mapSettings["sAimAutofireKey"], 1,
		g_mapSettings["sCrouchAutofireKey"], 1,
		g_mapSettings["sSprintAutofireKey"], 1
	)

	for l_sValue in ["LButton", "MButton", "RButton", "XButton1", "XButton2"]
	{
		; Don't register a mouse hotkey if it's already been registered, otherwise it'll override its action
		if (!l_mapHotkeys.Has(l_sValue))
{
			Output(A_ThisFunc ":: " l_sValue)
			Hotkey("*$" l_sValue, OnClickOutsideWindow, "On")
		}
	}
}

ReleaseAllKeys()
{
	Output(A_ThisFunc "::states(" g_mapStates["bAiming"] ", " g_mapStates["bCrouching"] ", " g_mapStates["bSprinting"] ", " g_mapStates["bAutorunning"] ")")

	; Release all toggle keys
	if (g_mapStates["bAiming"])
		KeyToggle(g_mapSettings["sAimKey"], false)
	if (g_mapStates["bCrouching"])
		KeyToggle(g_mapSettings["sCrouchKey"], false)
	if (g_mapStates["bSprinting"])
		KeyToggle(g_mapSettings["sSprintKey"], false)
	if (g_mapStates["bAutorunning"])
		KeyToggle(g_mapSettings["sForwardKey"], false)

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
	if (g_mapSettings["bRunAsAdmin"] && !A_IsAdmin)
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

	ReleaseAllKeys()
	Suspend()

	; Check if modifier keys are physically pressed to handle modifiers + Tab correctly
	l_bIsControlPressed := GetKeyState("Control", "P")
	l_bIsShiftPressed := GetKeyState("Shift", "P")
	if (l_bIsControlPressed)
		SendInput("{Blind}{Control down}")
	if (l_bIsShiftPressed)
		SendInput("{Blind}{Shift down}")

	SendInput("{Blind}{Tab down}")
	SendKey("Alt", , true)
	Suspend()

	;Output(A_ThisFunc "::end")
}

SendClickOutsideWindow(p_sKey)
{
	;Output(A_ThisFunc "::begin")

	; Take a snapshot of the toggle states
	if (ShouldRestoreTogglesOnFocus())
		TakeToggleKeysSnapshot()

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

	ReleaseAllKeys()
	Suspend()
	SendKey("Escape", , true)

	; Fixes an issue where the window wouldn't receive key up events when pressing Ctrl+Shift+Escape
	ControlSend("{Blind}{Alt up}{Control up}{Shift up}")

	Suspend()

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

	ReleaseAllKeys()
	Suspend()
	SendKey("LWin", , true)
	Suspend()
	;Output(A_ThisFunc "::end")
}

ShouldRestoreAutofiresOnFocus()
{
	return g_mapSettings["bRestoreAutofiresOnFocus"] && (g_mapSettings["nAimMode"] == KEY_MODE_AUTOFIRE_TOGGLE ||
	       g_mapSettings["nCrouchMode"] == KEY_MODE_AUTOFIRE_TOGGLE || g_mapSettings["nSprintMode"] == KEY_MODE_AUTOFIRE_TOGGLE)
	       && WinExist("ahk_id " g_nWindowID)
}

ShouldRestoreTogglesOnFocus()
{
	return g_mapSettings["bRestoreTogglesOnFocus"] && (g_mapSettings["nAimMode"] == KEY_MODE_TOGGLE || g_mapSettings["nCrouchMode"] == KEY_MODE_TOGGLE ||
	       g_mapSettings["nSprintMode"] == KEY_MODE_TOGGLE || g_mapSettings["bAutorunMode"] == KEY_MODE_TOGGLE) && WinExist("ahk_id " g_nWindowID)
}

ShowNotification(p_sMessage)
{
	switch g_mapSettings["nShowNotifications"]
	{
		case 1:
			; Make sure to clear any existing traytip
			TrayTip()
			TrayTip(p_sMessage)
		case 2:
			ToolTip(p_sMessage)
			SoundPlay("*64")
			SetTimer(() => ToolTip(), -5000)
	}
}

StartFocusCheck()
{
	l_sMsgBoxText := ""

	g_mapSettings["sProcessName"] := Trim(g_mapSettings["sProcessName"], '" `t')
	l_bIsProcessNameValid := IsProcessNameValid(g_mapSettings["sProcessName"])
	if (l_bIsProcessNameValid != 1)
		l_sMsgBoxText := l_bIsProcessNameValid == -1 ? "You must specify a process name." : "The process name `"" g_mapSettings["sProcessName"] '" must end with ".exe".'

	l_sDuplicateHotkeys := GetDuplicateHotkeys(false)
	if (l_sDuplicateHotkeys)
	{
		l_sMsgBoxText .= l_sMsgBoxText ? "`n`n" : ""
		l_sMsgBoxText .= "Duplicate hotkeys detected: " l_sDuplicateHotkeys
	}

	; Process name not valid or duplicate hotkeys, show the settings configurator
	if (l_sMsgBoxText)
	{
		MsgBox(l_sMsgBoxText, , "Icon!")
		g_guiSettings.Show()
		return
	}

	if (g_mapSettings["sWindowName"] == "")
		ShowNotification('Waiting for the process "' g_mapSettings["sProcessName"] '" to become active.')
	else
		ShowNotification('Waiting for the window "' g_mapSettings["sWindowName"] '" of the process "' g_mapSettings["sProcessName"] '" to become active.')

	Output(A_ThisFunc "::WinWaitActive")
	SetTimer(OnFocusChanged, g_mapSettings["nFocusCheckInterval"])
}

TakeToggleKeysSnapshot()
{
	global

	g_mapStates["bRestoreAiming"]            := g_mapStates["bAiming"]
	g_mapStates["bRestoreCrouching"]         := g_mapStates["bCrouching"]
	g_mapStates["bRestoreSprinting"]         := g_mapStates["bSprinting"]
	g_mapStates["bRestoreAutorunning"]       := g_mapStates["bAutorunning"]
	g_mapStates["bRestoreAutofireAiming"]    := g_mapStates["bAutofireAiming"]
	g_mapStates["bRestoreAutofireCrouching"] := g_mapStates["bAutofireCrouching"]
	g_mapStates["bRestoreAutofireSprinting"] := g_mapStates["bAutofireSprinting"]
	g_bToggleKeysSnapshotTaken := true
}

UnregisterHotkeys()
{
	l_sWinTitle := g_mapSettings["sWindowName"] " ahk_exe " g_mapSettings["sProcessName"]
	HotIf((*) => WinActive(l_sWinTitle))

	Hotkey("*$" g_mapSettings["sAimKey"], OnKeyPress, "Off")
	Hotkey("*$" g_mapSettings["sCrouchKey"], OnKeyPress, "Off")
	Hotkey("*$" g_mapSettings["sSprintKey"], OnKeyPress, "Off")
	Hotkey("*$" g_mapSettings["sAutorunKey"], OnKeyPress, "Off")
	Hotkey("~*$" g_mapSettings["sForwardKey"], OnKeyPress, "Off")
	Hotkey("~*$" g_mapSettings["sBackwardKey"], OnKeyPress, "Off")
	Hotkey("*$" g_mapSettings["sAimAutofireKey"], OnKeyPress, "Off")
	Hotkey("*$" g_mapSettings["sCrouchAutofireKey"], OnKeyPress, "Off")
	Hotkey("*$" g_mapSettings["sSprintAutofireKey"], OnKeyPress, "Off")

	Hotkey("*$" "!Tab", SendAltTab, "Off")
	Hotkey("*$" "Escape", SendEscape, "Off")
	Hotkey("*$" "LWin", SendWindows, "Off")
	Hotkey("*$" "RWin", SendWindows, "Off")

	global g_fnAutofireAim := 0
	global g_fnAutofireCrouch := 0
	global g_fnAutofireSprint := 0

	HotIf((*) => WinActive(l_sWinTitle) && !IsMouseOver(l_sWinTitle))

	Hotkey("*$LButton", OnClickOutsideWindow, "Off")
	Hotkey("*$MButton", OnClickOutsideWindow, "Off")
	Hotkey("*$RButton", OnClickOutsideWindow, "Off")
	Hotkey("*$XButton1", OnClickOutsideWindow, "Off")
	Hotkey("*$XButton2", OnClickOutsideWindow, "Off")

	HotIf()
}

WriteConfigFile()
{
	; Strip double quotes and spaces/tabs
	l_procNameClean := Trim(g_mapControls["editProcessName"].Value, '" `t')
	l_windowNameClean := Trim(g_mapControls["editWindowName"].Value, '" `t')
	l_sMsgBoxText := ""

	; Validate process name
	l_bIsProcessNameValid := IsProcessNameValid(l_procNameClean)
	if (l_bIsProcessNameValid != 1)
		l_sMsgBoxText := l_bIsProcessNameValid == -1 ? "You must specify a process name." : 'The process name "' l_procNameClean '" must end with ".exe".'

	; Validate hotkeys (no duplicates allowed)
	l_sDuplicateHotkeys := GetDuplicateHotkeys()
	if (l_sDuplicateHotkeys)
	{
		l_sMsgBoxText .= l_sMsgBoxText ? "`n`n" : ""
		l_sMsgBoxText .= "Duplicate hotkeys detected: " l_sDuplicateHotkeys
	}

	if (l_sMsgBoxText)
	{
		MsgBox(l_sMsgBoxText, , "Icon!")
		return false
	}

	; Surround with double quotes
	l_procNameClean := '"' l_procNameClean '"'
	l_windowNameClean := '"' l_windowNameClean '"'

	; Everything ok, save settings
	try
	{
		IniWrite(l_procNameClean,                                  "KeyToggles.ini", "General", "processName")
		IniWrite(l_windowNameClean,                                "KeyToggles.ini", "General", "windowName")
		IniWrite(g_mapControls["cbAutorun"].Value,                 "KeyToggles.ini", "General", "autorunMode")
		IniWrite(g_mapControls["cbFixSystemKeys"].Value,           "KeyToggles.ini", "General", "fixSystemKeys")
		IniWrite(g_mapControls["cbRestoreAutofiresOnFocus"].Value, "KeyToggles.ini", "General", "restoreAutofiresOnFocus")
		IniWrite(g_mapControls["cbRestoreTogglesOnFocus"].Value,   "KeyToggles.ini", "General", "restoreTogglesOnFocus")
		IniWrite(g_mapControls["cbRunAsAdmin"].Value,              "KeyToggles.ini", "General", "runAsAdmin")
		IniWrite(g_mapControls["ddlAimMode"].Value - 1,            "KeyToggles.ini", "General", "aimMode")
		IniWrite(g_mapControls["ddlCrouchMode"].Value - 1,         "KeyToggles.ini", "General", "crouchMode")
		IniWrite(g_mapControls["ddlNotifications"].Value - 1,      "KeyToggles.ini", "General", "showNotifications")
		IniWrite(g_mapControls["ddlSprintMode"].Value - 1,         "KeyToggles.ini", "General", "sprintMode")
		IniWrite(g_mapControls["udAutofireKeyInterval"].Value,     "KeyToggles.ini", "General", "autofireKeyInterval")
		IniWrite(g_mapControls["udFocusCheckInterval"].Value,      "KeyToggles.ini", "General", "focusCheckInterval")
		IniWrite(g_mapControls["udHookDelay"].Value,               "KeyToggles.ini", "General", "hookDelay")
		IniWrite(g_mapControls["udKeyDelay"].Value,                "KeyToggles.ini", "General", "keyDelay")
		IniWrite(g_mapControls["hkAimAutofireKey"].Value,          "KeyToggles.ini", "Keys",    "aimAutofireKey")
		IniWrite(g_mapControls["hkAimKey"].Value,                  "KeyToggles.ini", "Keys",    "aimKey")
		IniWrite(g_mapControls["hkAutorunKey"].Value,              "KeyToggles.ini", "Keys",    "autorunKey")
		IniWrite(g_mapControls["hkBackwardKey"].Value,             "KeyToggles.ini", "Keys",    "backwardKey")
		IniWrite(g_mapControls["hkCrouchAutofireKey"].Value,       "KeyToggles.ini", "Keys",    "crouchAutofireKey")
		IniWrite(g_mapControls["hkCrouchKey"].Value,               "KeyToggles.ini", "Keys",    "crouchKey")
		IniWrite(g_mapControls["hkForwardKey"].Value,              "KeyToggles.ini", "Keys",    "forwardKey")
		IniWrite(g_mapControls["hkSprintAutofireKey"].Value,       "KeyToggles.ini", "Keys",    "sprintAutofireKey")
		IniWrite(g_mapControls["hkSprintKey"].Value,               "KeyToggles.ini", "Keys",    "sprintKey")
		IniWrite(g_mapControls["cbDebugMode"].Value,               "KeyToggles.ini", "Debug",   "debugMode")
	}
	catch as e
	{
		MsgBox(Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}", type(e), e.Message, e.File, e.Line, e.What, e.Stack), , "Icon!")
		return false
	}

	return true
}

#SuspendExempt
#HotIf g_mapSettings["bDebugMode"]
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
	SoundBeep(1000)

	if (A_IsSuspended)
		ReleaseAllKeys()
	; Double beep when resumed
	else
		SoundBeep(1000)
}
#SuspendExempt False
