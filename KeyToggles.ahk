; KeyToggles v2.4

/*
TODO
add application profiles (https://stackoverflow.com/questions/45190170/how-can-i-make-this-ini-file-into-a-listview-in-autohotkey)
add support for hotkey modifiers (e.g., Ctrl+F1) https://www.autohotkey.com/docs/v2/Hotkeys.htm#Symbols
add text/tooltips when mousing over GUI controls to explain what they do
add update checker (https://www.reddit.com/r/AutoHotkey/comments/1rio81z/github_repo_update_checker_for_ahk_any_anything)
fix "Error: Target window not found: g_iWindowID := WinGetID(l_sWinTitle)" in OnFocusChanged()
fix modifiers still toggled while clicking outside the window
fix toggles not working when physically holding another toggle key (https://www.reddit.com/r/AutoHotkey/comments/oh65o2/comment/h4phdwu)
redo window detection (https://www.reddit.com/r/AutoHotkey/comments/nmewd1/resize_and_move_a_window_every_time_it_gets/gzoogts)
refactor the project to use classes (https://www.reddit.com/r/AutoHotkey/comments/1sumsfy/comment/ok3us2f)
replace "ahk_id " g_iWindowID with window name and process name
replace sleeps with timers or SetKeyDelay (SendEvent only)
replace ternary operators with coalescing ?? operators where possible
simpler solution for system keys? https://www.reddit.com/r/AutoHotkey/comments/1t5r12b/comment/okcfvod
https://dev.to/manikandan/how-to-use-ai-models-locally-in-vs-code-with-the-continue-plugin-with-multi-model-switching-3na0
*/

#Requires Autohotkey v2.0 ; Display an error and quit if this version requirement is not met.
#SingleInstance force     ; Allow only a single instance of the script to run.
#Warn                     ; Enable warnings to assist with detecting common errors.

; Register a function to be called on exit
OnExit(ExitFunc)

; Constants
KEY_MODE_DISABLED        := 0
KEY_MODE_TOGGLE          := 1
KEY_MODE_HOLD            := 2
KEY_MODE_AUTOFIRE_TOGGLE := 3
KEY_MODE_AUTOFIRE_HOLD   := 4

SEND_MODE_EVENT          := 0
SEND_MODE_INPUT          := 1
SEND_MODE_PLAY           := 2
SEND_MODE_INPUTTHENPLAY  := 3

; Maps
g_mapControls := Map()
g_mapSettings := Map()
g_mapStates := Map(
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
g_fnAutofireAim    := 0
g_fnAutofireCrouch := 0
g_fnAutofireSprint := 0

; Arrays
g_arrExtraKeys := ["None", "LButton", "RButton", "MButton", "XButton1", "XButton2", "Space", "Tab", "Enter", "Backspace"]
g_arrKeyModes := ["Disabled", "Toggle", "Hold", "Autofire toggle", "Autofire hold"]
g_arrMouseButtons := ["LButton", "MButton", "RButton", "XButton1", "XButton2"]
g_arrNotificationTypes := ["Disabled", "System notifications", "Tooltips"]
g_arrSendModes := ["Event", "Input", "Play", "InputThenPlay"]

; UI
g_guiBackColor := "White"
g_guiTextColor := "CBlack"

; Others
g_bToggleKeysSnapshotTaken := false
g_iWindowID := 0
g_sConfigFileName := "KeyToggles.ini"

Init()

; Exit script
ExitFunc(p_sExitReason, p_iExitCode)
{
	Output(A_ThisFunc "::pExitReason(" p_sExitReason ") pExitCode(" p_iExitCode ")")
	ReleaseAllKeys()
	TrayTip()

	; Store the GUI position
	if (g_mapControls["cbRememberWindowPosition"].Value)
	{
		try
		{
			g_guiSettings.GetPos(&l_iWinX, &l_iWinY)
			IniWrite(l_iWinX, "KeyToggles.ini", "UI", "windowX")
			IniWrite(l_iWinY, "KeyToggles.ini", "UI", "windowY")
		}
		catch as e
			MsgBox(Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}", type(e), e.Message, e.File, e.Line, e.What, e.Stack), , "Icon!")
	}
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

GuiApplyTheme()
{
	; Set theme to dark mode
	if (g_mapSettings["bDarkMode"])
	{
		global g_guiBackColor := "1F1F1F"
		global g_guiTextColor := "CWhite"
	}
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
		SplitPath(l_sSelectedFile, &l_sFileName)
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
		global g_iWindowID := 0
		ReadConfigFile()
		StartFocusCheck()
		MsgBox("Settings saved!", , "Iconi")
	}
}

GuiButtonSelect_Click(*)
{
	; Turn the window selector GUI into a modal
	g_guiSettings.Opt("+Disabled")

	; Create the window selector GUI if it doesn't exist
	if (!IsSet(g_guiWindowSelector))
	{
		; Gui
		global g_guiWindowSelector := Gui.Call("+Owner" g_guiSettings.Hwnd " -MinimizeBox -MaximizeBox", "Window selector")
		g_guiWindowSelector.BackColor := g_guiBackColor
		g_guiWindowSelector.SetFont("s10")
		g_guiWindowSelector.OnEvent("Close", (*) => g_guiSettings.Opt("-Disabled"))

		; Button
		g_guiWindowSelector.AddButton("Background" g_guiBackColor " Default w100", "&Refresh").OnEvent("Click", (*) => GuiLV_ReloadProcesses())

		; Checkbox
		g_guiWindowSelector.SetFont(g_guiTextColor)
		g_mapControls["cbExcludeProcesses"] := g_guiWindowSelector.AddCheckbox("Checked", "Exclude common processes")
		g_mapControls["cbExcludeProcesses"].OnEvent("Click", (*) => GuiLV_ReloadProcesses())

		; ListView
		l_iLvWidth := A_ScreenWidth * .41
		g_mapControls["lvWindowPicker"] := g_guiWindowSelector.AddListView("Background" g_guiBackColor " -Multi ReadOnly Sort Tile w" l_iLvWidth)
		g_mapControls["lvWindowPicker"].OnEvent("DoubleClick", GuiLV_DoubleClick)
	}

	; 0x00000011 = WDA_EXCLUDEFROMCAPTURE
	DllCall("user32\SetWindowDisplayAffinity", "Int", g_guiWindowSelector.Hwnd, "Int", 0x00000011 * g_mapControls["cbHideFromCapture"].Value)

	GuiLV_ReloadProcesses()
	g_guiWindowSelector.Show()
}

GuiButtonViewLog_Click(*)
{
	g_guiLog.Show()
	ControlSend("^{End}", g_mapControls["editLog"])
}

GuiCB_Click(p_guiCtrl, *)
{
	switch p_guiCtrl
	{
		case g_mapControls["cbAlwaysOnTop"]:
			WinSetAlwaysOnTop(g_mapControls["cbAlwaysOnTop"].Value, "ahk_id" g_guiSettings.Hwnd)
		case g_mapControls["cbCloseToTray"]:
			g_mapSettings["bCloseToTray"] := g_mapControls["cbCloseToTray"].Value
		case g_mapControls["cbDarkMode"]:
			; Turn MsgBox into a modal
			g_guiSettings.Opt("+OwnDialogs")

			; We reuse the variable to avoid showing the MsgBox multiple times
			if (g_mapSettings["bDarkMode"] != -1)
			{
				g_mapSettings["bDarkMode"] := -1
				MsgBox("Please restart the script to apply the new theme.", , "Icon!")
			}
		case g_mapControls["cbMinimizeToTray"]:
			g_mapSettings["bMinimizeToTray"] := g_mapControls["cbMinimizeToTray"].Value
		case g_mapControls["cbRememberWindowPosition"]:
			g_mapSettings["bRememberWindowPosition"] := g_mapControls["cbRememberWindowPosition"].Value
		default:
			return
	}

	; We save the changes immediately to avoid having to hit Save
	try
	{
		IniWrite(g_mapControls["cbAlwaysOnTop"].Value, "KeyToggles.ini", "UI", "alwaysOnTop")
		IniWrite(g_mapControls["cbCloseToTray"].Value, "KeyToggles.ini", "UI", "closeToTray")
		IniWrite(g_mapControls["cbDarkMode"].Value, "KeyToggles.ini", "UI", "darkMode")
		IniWrite(g_mapControls["cbHideFromCapture"].Value, "KeyToggles.ini", "UI", "hideFromCapture")
		IniWrite(g_mapControls["cbMinimizeToTray"].Value, "KeyToggles.ini", "UI", "minimizeToTray")
		IniWrite(g_mapControls["cbRememberWindowPosition"].Value, "KeyToggles.ini", "UI", "rememberWindowPosition")
	}
	catch as e
		MsgBox(Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}", type(e), e.Message, e.File, e.Line, e.What, e.Stack), , "Icon!")
}

GuiCreate()
{
	; Safety check
	if IsSet(g_guiSettings)
		return

	global g_guiSettings := Gui.Call("+OwnDialogs", "Settings", )
	g_guiSettings.BackColor := g_guiBackColor
	g_guiSettings.MarginX := 20
	g_guiSettings.MarginY := 10
	g_guiSettings.OnEvent("Close", (*) => g_mapSettings["bCloseToTray"] ? g_guiSettings.Hide() : ExitApp())
	g_guiSettings.OnEvent("Size", GuiOnSize)
	g_guiSettings.SetFont("s10 " g_guiTextColor)

	; Layout constants
	l_iCurrentRow := 0
	l_iSpacingX := 10
	l_iSpacingY := 25
	l_iTopY := 10
	; Leftmost controls
	l_iLeftWidth := 170
	l_iLeftX := 25
	; Middle controls
	l_iMiddleX := l_iLeftX + l_iLeftWidth + l_iSpacingX
	l_iMiddleWidth := 170
	; Rightmost controls
	l_iRightX := l_iMiddleX + l_iMiddleWidth + l_iSpacingX
	l_iRightWidth := 100

	; General
	g_guiSettings.AddGroupBox("x" l_iLeftX - 5 " y" l_iTopY " h" 7*29 " w" (l_iLeftWidth + l_iMiddleWidth + l_iRightWidth + l_iSpacingX * 4), "General")

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Process name")
	g_mapControls["editProcessName"] := g_guiSettings.AddEdit("CBlack r1 x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	;g_mapSettings["editProcessName"].OnEvent("Focus", (*) => ToolTip("Enter the name of the target process executable (e.g., game.exe)."))
	;g_mapSettings["editProcessName"].OnEvent("LoseFocus", (*) => ToolTip())
	g_guiSettings.AddButton("Background" g_guiBackColor " x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " h23 w" l_iRightWidth, "Browse").OnEvent("Click",
	                        GuiButtonBrowse_Click)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Window name")
	g_mapControls["editWindowName"] := g_guiSettings.AddEdit("CBlack r1 x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_guiSettings.AddButton("Background" g_guiBackColor " x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " h23 w" l_iRightWidth, "Select").OnEvent("Click",
	                        GuiButtonSelect_Click)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Autofire key interval")
	g_mapControls["editAutofireKeyInterval"] := g_guiSettings.AddEdit("CBlack Number x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["udAutofireKeyInterval"] := g_guiSettings.AddUpDown("Range1-10000 0x80")

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Focus check interval")
	g_mapControls["editFocusCheckInterval"] := g_guiSettings.AddEdit("CBlack Number x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["udFocusCheckInterval"] := g_guiSettings.AddUpDown("Range1-10000 0x80")

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Hook delay")
	g_mapControls["editHookDelay"] := g_guiSettings.AddEdit("CBlack Number x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["udHookDelay"] := g_guiSettings.AddUpDown("Range0-10000 0x80")

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Key delay")
	g_mapControls["editKeyDelay"] := g_guiSettings.AddEdit("CBlack Number x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["udKeyDelay"] := g_guiSettings.AddUpDown("Range0-1000 0x80")

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Send mode")
	g_mapControls["ddlSendMode"] := g_guiSettings.AddDropDownList("x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth, g_arrSendModes)

	; Save states
	g_guiSettings.AddGroupBox("x" l_iLeftX - 5 " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow + 5 " h" 2*35 " w" (l_iLeftWidth + l_iMiddleWidth + l_iRightWidth + (l_iSpacingX * 4)),
	                          "Save states")

	g_mapControls["cbRestoreAutofiresOnFocus"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23,
	                                                                        "Restore autofires on focus  ")
	g_mapControls["cbRestoreTogglesOnFocus"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23,
	                                                                      "Restore toggles on focus  ")

	; Key modes
	g_guiSettings.AddGroupBox("x" l_iLeftX - 5 " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " h" 4*31 " w" (l_iLeftWidth + l_iMiddleWidth + l_iRightWidth + (l_iSpacingX * 4)),
	                          "Key modes")

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Aim")
	g_mapControls["ddlAimMode"] := g_guiSettings.AddDropDownList("x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth, g_arrKeyModes)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Crouch")
	g_mapControls["ddlCrouchMode"] := g_guiSettings.AddDropDownList("x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth, g_arrKeyModes)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Sprint")
	g_mapControls["ddlSprintMode"] := g_guiSettings.AddDropDownList("x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth, g_arrKeyModes)

	g_mapControls["cbAutorun"] := g_guiSettings.AddCheckBox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23, "Autorun  ")

	; Hotkeys
	g_guiSettings.AddGroupBox("x" l_iLeftX - 5 " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " h" 9*28 + 3 " w" (l_iLeftWidth + l_iMiddleWidth + l_iRightWidth + (l_iSpacingX * 4)),
	                          "Hotkeys")

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Aim")
	g_mapControls["hkAimKey"] := g_guiSettings.AddHotkey("vhkAimKey x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["ddlAimKey"] := g_guiSettings.AddDropDownList("vddlAimKey x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iRightWidth, g_arrExtraKeys)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Crouch")
	g_mapControls["hkCrouchKey"] := g_guiSettings.AddHotkey("vhkCrouchKey x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["ddlCrouchKey"] := g_guiSettings.AddDropDownList("vddlCrouchKey x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iRightWidth, g_arrExtraKeys)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Sprint")
	g_mapControls["hkSprintKey"] := g_guiSettings.AddHotkey("vhkSprintKey x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["ddlSprintKey"] := g_guiSettings.AddDropDownList("vddlSprintKey x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iRightWidth, g_arrExtraKeys)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Autorun")
	g_mapControls["hkAutorunKey"] := g_guiSettings.AddHotkey("vhkAutorunKey x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["ddlAutorunKey"] := g_guiSettings.AddDropDownList("vddlAutorunKey x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iRightWidth, g_arrExtraKeys)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Forward")
	g_mapControls["hkForwardKey"] := g_guiSettings.AddHotkey("vhkForwardKey x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["ddlForwardKey"] := g_guiSettings.AddDropDownList("vddlForwardKey x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iRightWidth, g_arrExtraKeys)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Backward")
	g_mapControls["hkBackwardKey"] := g_guiSettings.AddHotkey("vhkBackwardKey x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["ddlBackwardKey"] := g_guiSettings.AddDropDownList("vddlBackwardKey x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iRightWidth,
	                                                                 g_arrExtraKeys)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Aim autofire")
	g_mapControls["hkAimAutofireKey"] := g_guiSettings.AddHotkey("vhkAimAutofireKey x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["ddlAimAutofireKey"] := g_guiSettings.AddDropDownList("vddlAimAutofireKey x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iRightWidth,
	                                                                 g_arrExtraKeys)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Crouch autofire")
	g_mapControls["hkCrouchAutofireKey"] := g_guiSettings.AddHotkey("vhkCrouchAutofireKey x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["ddlCrouchAutofireKey"] := g_guiSettings.AddDropDownList("vddlCrouchAutofireKey x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iRightWidth,
	                                                                       g_arrExtraKeys)

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Sprint autofire")
	g_mapControls["hkSprintAutofireKey"] := g_guiSettings.AddHotkey("vhkSprintAutofireKey x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth)
	g_mapControls["ddlSprintAutofireKey"] := g_guiSettings.AddDropDownList("vddlSprintAutofireKey x" l_iRightX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iRightWidth,
	                                                                       g_arrExtraKeys)

	; Misc
	g_guiSettings.AddGroupBox("x" l_iLeftX - 5 " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow + 5 " h" 3*33 " w" (l_iLeftWidth + l_iMiddleWidth + l_iRightWidth + (l_iSpacingX * 4)),
	                          "Misc")

	g_mapControls["cbDebugMode"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23, "Debug mode  ")
	g_mapControls["cbFixSystemKeys"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23, "Fix system keys  ")
	g_mapControls["cbRunAsAdmin"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23, "Run as admin  ")

	; UI
	g_guiSettings.AddGroupBox("x" l_iLeftX - 5 " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow + 5 " h" 7*29 " w" (l_iLeftWidth + l_iMiddleWidth + l_iRightWidth + (l_iSpacingX * 4)), "UI")

	g_mapControls["cbAlwaysOnTop"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23, "Always on top  ")
	g_mapControls["cbCloseToTray"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23, "Close to tray  ")
	g_mapControls["cbDarkMode"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23, "Dark mode  ")
	g_mapControls["cbHideFromCapture"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23, "Hide window from capture  ")
	g_mapControls["cbMinimizeToTray"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23, "Minimize to tray  ")
	g_mapControls["cbRememberWindowPosition"] := g_guiSettings.AddCheckbox("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth + 23, "Remember window position  ")

	g_guiSettings.AddText("Right x" l_iLeftX " y" l_iTopY + l_iSpacingY * ++l_iCurrentRow " w" l_iLeftWidth, "Notifications")
	g_mapControls["ddlNotifications"] := g_guiSettings.AddDropDownList("x" l_iMiddleX " y" l_iTopY + l_iSpacingY * l_iCurrentRow - 5 " w" l_iMiddleWidth, g_arrNotificationTypes)

	g_guiSettings.AddButton("Background" g_guiBackColor " x140 y" l_iTopY + l_iSpacingY * ++l_iCurrentRow + 15 " w100", "Reload").OnEvent("Click", GuiButtonReload_Click)
	g_guiSettings.AddButton("Background" g_guiBackColor " x260 y" l_iTopY + l_iSpacingY * l_iCurrentRow + 15 " w100", "Save").OnEvent("Click", GuiButtonSave_Click)
	g_guiSettings.AddButton("Background" g_guiBackColor " x380 y" l_iTopY + l_iSpacingY * l_iCurrentRow + 15 " w100", "View log").OnEvent("Click", GuiButtonViewLog_Click)

	; Event handlers
	for l_guiCtrl in g_guiSettings
	{
		switch l_guiCtrl.Type
		{
			case "Edit":
				l_guiCtrl.OnEvent("Change", GuiEdit_Change)
			case "Hotkey":
				l_guiCtrl.OnEvent("Change", GuiHK_Change)
			case "DDL":
				l_guiCtrl.OnEvent("Change", GuiDDL_Change)
			case "CheckBox":
				l_guiCtrl.OnEvent("Click", GuiCB_Click)
		}
	}

	GuiUpdate()
}

; Set hotkey controls text based on selected DDL extra keys
GuiDDL_Change(p_guiCtrl, *)
{
	switch p_guiCtrl
	{
		case g_mapControls["ddlAimMode"]:
		case g_mapControls["ddlCrouchMode"]:
		case g_mapControls["ddlSprintMode"]:
			return
		case g_mapControls["ddlSendMode"]:
			SendMode(g_mapControls["ddlSendMode"].Text)
		; Hotkey DDLs
		default:
			; Set the corresponding hotkey control's text to the selected DDL value
			l_sHkControlName := StrReplace(p_guiCtrl.Name, "ddl", "hk", , , 1)
			l_hkControl := g_mapControls[l_sHkControlName]
			l_hkControl.Value := p_guiCtrl.Value == 1 ? "" : p_guiCtrl.Text
	}
}

; Prevent intervals from being out-of-bounds, otherwise timers won't work
GuiEdit_Change(p_guiCtrl, *)
{
	switch p_guiCtrl
	{
		case g_mapControls["editAutofireKeyInterval"]:
			l_iMinValue := 1
			l_iMaxValue := 10000
			l_udControl := g_mapControls["udAutofireKeyInterval"]
		case g_mapControls["editFocusCheckInterval"]:
			l_iMinValue := 1
			l_iMaxValue := 10000
			l_udControl := g_mapControls["udFocusCheckInterval"]
		case g_mapControls["editHookDelay"]:
			l_iMinValue := 0
			l_iMaxValue := 10000
			l_udControl := g_mapControls["udHookDelay"]
		case g_mapControls["editKeyDelay"]:
			l_iMinValue := 0
			l_iMaxValue := 1000
			l_udControl := g_mapControls["udKeyDelay"]
		default:
			return
	}

	if (p_guiCtrl.Value == "")
		p_guiCtrl.Text := l_iMinValue
	else
	{
		l_iValue := Integer(p_guiCtrl.Value)

		; The UpDown control will automatically clamp the value within its range
		if (l_iValue < l_iMinValue || l_iValue > l_iMaxValue)
			l_udControl.Value := l_iValue
	}
}

; Prevent modified keys from being used in hotkey controls (could be changed to allow them in the future)
GuiHK_Change(p_guiCtrl, *)
{
	; Turn MsgBox into a modal
	g_guiSettings.Opt("+OwnDialogs")

	l_sHotkey := p_guiCtrl.Value
	l_sHotkeyLength := StrLen(l_sHotkey)
	l_bShift := InStr(p_guiCtrl.Value, "+")
	l_bControl := InStr(p_guiCtrl.Value, "^")
	l_bAlt := InStr(p_guiCtrl.Value, "!")

	Output("l_sHotkey(" l_sHotkey ") l_bShift(" l_bShift ") l_bControl(" l_bControl ") l_bAlt(" l_bAlt ")")

	if (l_bShift && !l_bControl && !l_bAlt && l_sHotkeyLength == 1)
		p_guiCtrl.Value := "LShift"
	else if (!l_bShift && l_bControl && !l_bAlt && l_sHotkeyLength == 1)
		p_guiCtrl.Value := "LControl"
	else if (!l_bShift && !l_bControl && l_bAlt && l_sHotkeyLength == 1)
		p_guiCtrl.Value := "LAlt"
	else if (l_bShift || l_bControl || l_bAlt && l_sHotkeyLength > 1)
	{
		p_guiCtrl.Value := ""
		MsgBox("You can't use modified keys!", , "Icon!")
		return
	}

	; Clear the corresponding DDL control if a hotkey is set
	l_sDDLControlName := StrReplace(p_guiCtrl.Name, "hk", "ddl", , , 1)
	g_mapControls[l_sDDLControlName].Choose(1)
}

GuiLogCreate()
{
	; Safety check
	if IsSet(g_guiLog)
		return

	global g_guiLog := Gui.Call("Owner" g_guiSettings.Hwnd " -MinimizeBox -MaximizeBox", "Log Viewer")
	g_guiLog.BackColor := g_guiBackColor
	g_guiLog.SetFont("s10 " g_guiTextColor)
	g_mapControls["editLog"] := g_guiLog.AddEdit((g_mapSettings["bDarkMode"] ? "Background" g_guiBackColor : "cBlack") " r25 w600 h400")
	g_guiLog.AddButton("Background" g_guiBackColor " x515 y425 w100", "Clear").OnEvent("Click", (*) => g_mapControls["editLog"].Text := "")
}

GuiLV_DoubleClick(p_guiCtrl, p_iPosItem)
{
	g_guiSettings.Opt("-Disabled")
	g_guiWindowSelector.Show("Hide")

	; Retrieve the text from the selected row in the ListView
	l_sItemText := p_guiCtrl.GetText(p_iPosItem)
	l_arr := StrSplit(l_sItemText, " | ", , 2)

	; Update controls in the main window
	g_mapControls["editProcessName"].Text := l_arr[1]
	g_mapControls["editWindowName"].Text := l_arr.Length > 1 ? l_arr[2] : ""
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
		Output("class: "   l_sWinClass, true)
		*/

		g_mapControls["lvWindowPicker"].Add("Icon" IL_Add(g_mapControls["ilWindowPicker"], l_sProcPath), l_sProcName (l_sWinTitle != "" ? " | " l_sWinTitle : ""))
	}

	g_mapControls["lvWindowPicker"].Opt("+Redraw")
}

GuiOnSize(GuiObj, MinMax, *)
{
	switch GuiObj
	{
		case g_guiSettings:
			if (MinMax == -1 && g_mapControls["cbMinimizeToTray"].Value)
				g_guiSettings.Hide()
			else if (MinMax == 0)
				WinSetAlwaysOnTop(g_mapControls["cbAlwaysOnTop"].Value, "ahk_id" g_guiSettings.Hwnd)
	}
}

GuiShow()
{
	g_guiSettings.Show(g_mapControls["cbRememberWindowPosition"].Value ? "x" g_mapSettings["iWindowX"] " y" g_mapSettings["iWindowY"] : "")
}

; Update GUI controls based on current settings
GuiUpdate()
{
	g_mapControls["cbAlwaysOnTop"].Value             := g_mapSettings["bAlwaysOnTop"]
	g_mapControls["cbAutorun"].Value                 := g_mapSettings["bAutorunMode"]
	g_mapControls["cbCloseToTray"].Value             := g_mapSettings["bCloseToTray"]
	g_mapControls["cbDarkMode"].Value                := g_mapSettings["bDarkMode"]
	g_mapControls["cbDebugMode"].Value               := g_mapSettings["bDebugMode"]
	g_mapControls["cbFixSystemKeys"].Value           := g_mapSettings["bFixSystemKeys"]
	g_mapControls["cbHideFromCapture"].Value         := g_mapSettings["bHideFromCapture"]
	g_mapControls["cbMinimizeToTray"].Value          := g_mapSettings["bMinimizeToTray"]
	g_mapControls["cbRememberWindowPosition"].Value  := g_mapSettings["bRememberWindowPosition"]
	g_mapControls["cbRestoreAutofiresOnFocus"].Value := g_mapSettings["bRestoreAutofiresOnFocus"]
	g_mapControls["cbRestoreTogglesOnFocus"].Value   := g_mapSettings["bRestoreTogglesOnFocus"]
	g_mapControls["cbRunAsAdmin"].Value              := g_mapSettings["bRunAsAdmin"]
	g_mapControls["ddlAimAutofireKey"].Text          := IsExtraOption(g_mapSettings["sAimAutofireKey"])    ? g_mapSettings["sAimAutofireKey"] : "None"
	g_mapControls["ddlAimKey"].Text                  := IsExtraOption(g_mapSettings["sAimKey"])            ? g_mapSettings["sAimKey"] : "None"
	g_mapControls["ddlAimMode"].Value                := g_mapSettings["iAimMode"] + 1
	g_mapControls["ddlAutorunKey"].Text              := IsExtraOption(g_mapSettings["sAutorunKey"])        ? g_mapSettings["sAutorunKey"] : "None"
	g_mapControls["ddlBackwardKey"].Text             := IsExtraOption(g_mapSettings["sBackwardKey"])       ? g_mapSettings["sBackwardKey"] : "None"
	g_mapControls["ddlCrouchAutofireKey"].Text       := IsExtraOption(g_mapSettings["sCrouchAutofireKey"]) ? g_mapSettings["sCrouchAutofireKey"] : "None"
	g_mapControls["ddlCrouchKey"].Text               := IsExtraOption(g_mapSettings["sCrouchKey"])         ? g_mapSettings["sCrouchKey"] : "None"
	g_mapControls["ddlCrouchMode"].Value             := g_mapSettings["iCrouchMode"] + 1
	g_mapControls["ddlForwardKey"].Text              := IsExtraOption(g_mapSettings["sForwardKey"])        ? g_mapSettings["sForwardKey"] : "None"
	g_mapControls["ddlNotifications"].Value          := g_mapSettings["iShowNotifications"] + 1
	g_mapControls["ddlSendMode"].Value               := g_mapSettings["iSendMode"] + 1
	g_mapControls["ddlSprintAutofireKey"].Text       := IsExtraOption(g_mapSettings["sSprintAutofireKey"]) ? g_mapSettings["sSprintAutofireKey"] : "None"
	g_mapControls["ddlSprintKey"].Text               := IsExtraOption(g_mapSettings["sSprintKey"])         ? g_mapSettings["sSprintKey"] : "None"
	g_mapControls["ddlSprintMode"].Value             := g_mapSettings["iSprintMode"] + 1
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
	g_mapControls["udAutofireKeyInterval"].Value     := g_mapSettings["iAutofireKeyInterval"]
	g_mapControls["udFocusCheckInterval"].Value      := g_mapSettings["iFocusCheckInterval"]
	g_mapControls["udHookDelay"].Value               := g_mapSettings["iHookDelay"]
	g_mapControls["udKeyDelay"].Value                := g_mapSettings["iKeyDelay"]
}

IniReadType(p_sFile, p_sSection, p_sKey, p_sDefault, p_sType)
{
	l_sValue := IniRead(p_sFile, p_sSection, p_sKey, p_sDefault)

	switch p_sType
	{
		case "int":
			try
			{
				l_iValue := l_sValue + 0
				return Max(0, l_iValue) ; no negative integer
			}
			catch TypeError ; not an integer
			{
				return p_sDefault
			}
		case "keyMode":
			try
			{
				l_iValue := l_sValue + 0
				return (l_iValue >= KEY_MODE_DISABLED && l_iValue <= KEY_MODE_AUTOFIRE_HOLD) ? l_iValue : p_sDefault
			}
			catch TypeError ; not an integer
			{
				return p_sDefault
			}
		case "sendMode":
			try
			{
				l_iValue := l_sValue + 0
				return (l_iValue >= SEND_MODE_INPUT && l_iValue <= SEND_MODE_PLAY) ? l_iValue : p_sDefault
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
	GuiApplyTheme()
	GuiCreate()
	GuiLogCreate()
	SendMode(g_mapControls["ddlSendMode"].Text)
	StartFocusCheck()
	A_TrayMenu.Insert("&Suspend Hotkeys", "&Settings", (*) => GuiShow())
	A_TrayMenu.ClickCount := 1
	A_TrayMenu.Default := "&Settings"
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
	; https://www.autohotkey.com/docs/v2/lib/If.htm#ExIfInContains
	return StrLower(p_sProcessName) ~= l_sCommonProcesses
}

IsExtraOption(p_sKey)
{
	; https://www.autohotkey.com/docs/v2/lib/If.htm#ExIfInContains
	return StrLower(p_sKey) ~= "i)\A(lbutton|mbutton|rbutton|xbutton1|xbutton2|space|tab|enter|backspace)\z"
}

IsMouseButton(p_sKey)
{
	; https://www.autohotkey.com/docs/v2/lib/If.htm#ExIfInContains
	return StrLower(p_sKey) ~= "i)\A(lbutton|mbutton|rbutton|xbutton1|xbutton2)\z"
}

IsMouseOver(p_sWinTitle)
{
	MouseGetPos(, , &l_iWinID)
	return WinExist(p_sWinTitle " ahk_id " l_iWinID)
}

IsMouseOverWindow(p_iHwnd)
{
	MouseGetPos(, , &l_iMouseWindowID)
	return p_iHwnd == l_iMouseWindowID
}

IsProcessNameValid(p_sProcessName)
{
	p_sProcessName := Trim(p_sProcessName)

	if (p_sProcessName == "")
		return -1

	SplitPath(p_sProcessName, , , &l_sExt)
	return l_sExt == "exe"
}

IsWindowVisible(p_hwnd)
{
	;return DllCall("IsWindowVisible", "Ptr", p_hwnd)
	return WinGetStyle("ahk_id " p_hwnd) & 0x10000000 ; WS_VISIBLE
}

KeyAutofire(p_sAutofireKey)
{
	Output(A_ThisFunc "::begin")

	switch p_sAutofireKey
	{
		case g_mapSettings["sAimAutofireKey"]:
			SendKey(g_mapSettings["sAimKey"], g_mapSettings["iKeyDelay"])
		case g_mapSettings["sCrouchAutofireKey"]:
			SendKey(g_mapSettings["sCrouchKey"], g_mapSettings["iKeyDelay"])
		case g_mapSettings["sSprintAutofireKey"]:
			SendKey(g_mapSettings["sSprintKey"], g_mapSettings["iKeyDelay"])
	}

	Output(A_ThisFunc "::end")
}

KeyHold(p_sKey)
{
	;Output(A_ThisFunc "::begin")
	SendKey(p_sKey, g_mapSettings["iKeyDelay"])
	KeyWait(p_sKey)
	SendKey(p_sKey, g_mapSettings["iKeyDelay"])
	;Output(A_ThisFunc "::end")
}

KeyToggle(p_sKey, p_bToggle, p_bWait := false)
{
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
	Send("{Blind}{" p_sKey (p_bToggle ? " down}" : " up}"))

	if (p_bWait)
		KeyWait(p_sKey)

	Output(A_ThisFunc "::end")
}

Log(p_sMessage, p_bSeparator := false)
{
	if (g_mapControls["cbDebugMode"].Value)
	{
		l_sFormattedTime := FormatTime(, "HH:mm:ss")
		l_sMilliseconds := SubStr(A_TickCount, -3)
		g_mapControls["editLog"].Text .= l_sFormattedTime "." l_sMilliseconds ": " p_sMessage "`r`n"
		ControlSend("^{End}", g_mapControls["editLog"])

		if (p_bSeparator)
			g_mapControls["editLog"].Text .= "--------------------------------------------------`r`n"
	}
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
	Output(A_ThisFunc "::WinWaitActive")

	; We need to store this until the function completes as the user could update the process/window name before WinWaitActive times out
	l_sWinTitle := g_mapSettings["sWindowName"] " ahk_exe " g_mapSettings["sProcessName"]
	l_iTimeout := g_mapSettings["iFocusCheckInterval"] * 0.001

	if (WinWaitActive(l_sWinTitle,, l_iTimeout))
	{
		if (g_mapSettings["iHookDelay"] > 0)
			Sleep(g_mapSettings["iHookDelay"])

		; Make sure to hook the window again if it no longer exists
		if (g_iWindowID != WinExist(l_sWinTitle))
		{
			global g_iWindowID := WinGetID(l_sWinTitle)
			Output(A_ThisFunc "::WinGet(" g_iWindowID ")")
			RegisterHotkeys()

			if (g_iWindowID)
				ShowNotification('The window "' WinGetTitle(g_iWindowID) '" has been hooked.')

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
				global g_bToggleKeysSnapshotTaken := false
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
	l_sCleanHotkey := LTrim(p_sThisHotkey, "~*$")
	;l_sCleanHotkeyNoModifiers := LTrim(p_sThisHotkey, "~*$#!^+")
	l_iKeyMode := KEY_MODE_DISABLED

	switch l_sCleanHotkey
	{
		case g_mapSettings["sAimKey"], g_mapSettings["sAimAutofireKey"]:
			l_iKeyMode := g_mapSettings["iAimMode"]
		case g_mapSettings["sCrouchKey"], g_mapSettings["sCrouchAutofireKey"]:
			l_iKeyMode := g_mapSettings["iCrouchMode"]
		case g_mapSettings["sSprintKey"], g_mapSettings["sSprintAutofireKey"]:
			l_iKeyMode := g_mapSettings["iSprintMode"]
		case g_mapSettings["sAutorunKey"]:
			l_iKeyMode := g_mapSettings["bAutorunMode"]
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

	switch l_iKeyMode
	{
		case KEY_MODE_TOGGLE:
			l_bIsMouseButton := IsMouseButton(l_sCleanHotkey)
			l_bIsMouseOverWindow := IsMouseOverWindow(g_iWindowID)
			; Output(A_ThisFunc "::" l_sCleanHotkey " l_bIsMouseButton(" l_bIsMouseButton ") l_bIsMouseOverWindow(" l_bIsMouseOverWindow ")")

			; Fixes an issue where you couldn't click outside the window if the toggle key was a mouse button and toggled
			if (l_bIsMouseButton && !l_bIsMouseOverWindow)
			{
				Output(A_ThisFunc "::" l_sCleanHotkey " outside window")
				SendClickOutsideWindow(l_sCleanHotkey)
			}
			; Otherwise toggle the key
			else
			{
				if (l_bIsMouseButton)
					Output(A_ThisFunc "::" l_sCleanHotkey " inside window")

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
				SetTimer(g_fnAutofireAim, g_mapStates["bAutofireAiming"] ? g_mapSettings["iAutofireKeyInterval"] : 0)
			}
			else if (l_sCleanHotkey == g_mapSettings["sCrouchAutofireKey"])
			{
				g_mapStates["bAutofireCrouching"] := !g_mapStates["bAutofireCrouching"]
				SetTimer(g_fnAutofireCrouch, g_mapStates["bAutofireCrouching"] ? g_mapSettings["iAutofireKeyInterval"] : 0)
			}
			else if (l_sCleanHotkey == g_mapSettings["sSprintAutofireKey"])
			{
				g_mapStates["bAutofireSprinting"] := !g_mapStates["bAutofireSprinting"]
				SetTimer(g_fnAutofireSprint, g_mapStates["bAutofireSprinting"] ? g_mapSettings["iAutofireKeyInterval"] : 0)
			}

			KeyWait(l_sCleanHotkey)

			; Fixes a weird bug where the autofire key would stay permanently pressed after holding it down for a few seconds
			Send("{Blind}{" l_sCleanHotkey " up}")
		case KEY_MODE_AUTOFIRE_HOLD:
			if (l_sCleanHotkey == g_mapSettings["sAimAutofireKey"])
				SetTimer(g_fnAutofireAim, g_mapSettings["iAutofireKeyInterval"])
			else if (l_sCleanHotkey == g_mapSettings["sCrouchAutofireKey"])
				SetTimer(g_fnAutofireCrouch, g_mapSettings["iAutofireKeyInterval"])
			else if (l_sCleanHotkey == g_mapSettings["sSprintAutofireKey"])
				SetTimer(g_fnAutofireSprint, g_mapSettings["iAutofireKeyInterval"])

			KeyWait(l_sCleanHotkey)

			if (l_sCleanHotkey == g_mapSettings["sAimAutofireKey"])
				SetTimer(g_fnAutofireAim, 0)
			else if (l_sCleanHotkey == g_mapSettings["sCrouchAutofireKey"])
				SetTimer(g_fnAutofireCrouch, 0)
			else if (l_sCleanHotkey == g_mapSettings["sSprintAutofireKey"])
				SetTimer(g_fnAutofireSprint, 0)

			; Fixes a weird bug where the autofire key would stay permanently pressed after holding it down for a few seconds
			Send("{Blind}{" l_sCleanHotkey " up}")
	}
}

Output(p_sMessage, p_bSeparator := false)
{
	Log(p_sMessage, p_bSeparator)

	if (g_mapControls["cbDebugMode"].Value)
	{
		OutputDebug(p_sMessage "`r`n")

		if (p_bSeparator)
			OutputDebug("--------------------------------------------------`r`n")
	}
}

ReadConfigFile()
{
	; General
	g_mapSettings["sProcessName"]             :=     IniRead(g_sConfigFileName, "General", "processName", "")
	g_mapSettings["sWindowName"]              :=     IniRead(g_sConfigFileName, "General", "windowName", "")
	g_mapSettings["iAutofireKeyInterval"]     := IniReadType(g_sConfigFileName, "General", "autofireKeyInterval", 100, "int")
	g_mapSettings["bFixSystemKeys"]           :=     IniRead(g_sConfigFileName, "General", "fixSystemKeys", true) == true
	g_mapSettings["iFocusCheckInterval"]      := IniReadType(g_sConfigFileName, "General", "focusCheckInterval", 1000, "int")
	g_mapSettings["iHookDelay"]               := IniReadType(g_sConfigFileName, "General", "hookDelay", 0, "int")
	g_mapSettings["iKeyDelay"]                := IniReadType(g_sConfigFileName, "General", "keyDelay", 0, "int")
	g_mapSettings["bRestoreAutofiresOnFocus"] :=     IniRead(g_sConfigFileName, "General", "restoreAutofiresOnFocus", false) == true
	g_mapSettings["bRestoreTogglesOnFocus"]   :=     IniRead(g_sConfigFileName, "General", "restoreTogglesOnFocus", false) == true
	g_mapSettings["bRunAsAdmin"]              :=     IniRead(g_sConfigFileName, "General", "runAsAdmin", false) == true
	g_mapSettings["iSendMode"]                := IniReadType(g_sConfigFileName, "General", "sendMode", SEND_MODE_INPUT, "sendMode")
	g_mapSettings["iShowNotifications"]       := IniReadType(g_sConfigFileName, "General", "showNotifications", 0, "int")
	g_mapSettings["iAimMode"]                 := IniReadType(g_sConfigFileName, "General", "aimMode", 0, "keyMode")
	g_mapSettings["iCrouchMode"]              := IniReadType(g_sConfigFileName, "General", "crouchMode", 0, "keyMode")
	g_mapSettings["iSprintMode"]              := IniReadType(g_sConfigFileName, "General", "sprintMode", 0, "keyMode")
	g_mapSettings["bAutorunMode"]             :=     IniRead(g_sConfigFileName, "General", "autorunMode", false) == true

	; Keys
	g_mapSettings["sAimKey"]    := IniRead(g_sConfigFileName, "Keys", "aimKey", "RButton")
	g_mapSettings["sCrouchKey"] := IniRead(g_sConfigFileName, "Keys", "crouchKey", "LCtrl")
	g_mapSettings["sSprintKey"] := IniRead(g_sConfigFileName, "Keys", "sprintKey", "LShift")
	g_mapSettings["sAutorunKey"]  := IniRead(g_sConfigFileName, "Keys", "autorunKey", "F1")
	g_mapSettings["sForwardKey"]  := IniRead(g_sConfigFileName, "Keys", "forwardKey", "w")
	g_mapSettings["sBackwardKey"] := IniRead(g_sConfigFileName, "Keys", "backwardKey", "s")
	g_mapSettings["sAimAutofireKey"]    := IniRead(g_sConfigFileName, "Keys", "aimAutofireKey", "F2")
	g_mapSettings["sCrouchAutofireKey"] := IniRead(g_sConfigFileName, "Keys", "crouchAutofireKey", "F3")
	g_mapSettings["sSprintAutofireKey"] := IniRead(g_sConfigFileName, "Keys", "sprintAutofireKey", "F4")

	; UI
	g_mapSettings["bAlwaysOnTop"]            := IniRead(g_sConfigFileName, "UI", "alwaysOnTop", false) == true
	g_mapSettings["bCloseToTray"]            := IniRead(g_sConfigFileName, "UI", "closeToTray", false) == true
	g_mapSettings["bDarkMode"]               := IniRead(g_sConfigFileName, "UI", "darkMode", true) == true
	g_mapSettings["bHideFromCapture"]        := IniRead(g_sConfigFileName, "UI", "hideFromCapture", false) == true
	g_mapSettings["bMinimizeToTray"]         := IniRead(g_sConfigFileName, "UI", "minimizeToTray", false) == true
	g_mapSettings["bRememberWindowPosition"] := IniRead(g_sConfigFileName, "UI", "rememberWindowPosition", false) == true
	g_mapSettings["iWindowX"]                := IniReadType(g_sConfigFileName, "UI", "windowX", 0, "int")
	g_mapSettings["iWindowY"]                := IniReadType(g_sConfigFileName, "UI", "windowY", 0, "int")

	; Debug
	g_mapSettings["bDebugMode"] := IniRead(g_sConfigFileName, "Debug", "debugMode", false) == true

	; Prevent intervals from being set to 0, otherwise timers won't work
	g_mapSettings["iAutofireKeyInterval"] := Max(g_mapSettings["iAutofireKeyInterval"], 1)
	g_mapSettings["iFocusCheckInterval"]  := Max(g_mapSettings["iFocusCheckInterval"], 1)
}

RegisterHotkeys()
{
	l_sWinTitle := g_mapSettings["sWindowName"] " ahk_exe " g_mapSettings["sProcessName"]
	HotIf((*) => WinActive(l_sWinTitle))

	; Enabled only for toggle and hold modes
	Hotkey("*$" g_mapSettings["sAimKey"], OnKeyPress, g_mapSettings["iAimMode"] == KEY_MODE_TOGGLE ||
	       g_mapSettings["iAimMode"] == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" g_mapSettings["sCrouchKey"], OnKeyPress, g_mapSettings["iCrouchMode"] == KEY_MODE_TOGGLE ||
	       g_mapSettings["iCrouchMode"] == KEY_MODE_HOLD ? "On" : "Off")
	Hotkey("*$" g_mapSettings["sSprintKey"], OnKeyPress, g_mapSettings["iSprintMode"] == KEY_MODE_TOGGLE ||
	       g_mapSettings["iSprintMode"] == KEY_MODE_HOLD ? "On" : "Off")

	; Enabled only for autorun mode
	Hotkey("*$"   g_mapSettings["sAutorunKey"], OnKeyPress, g_mapSettings["bAutorunMode"] == KEY_MODE_TOGGLE ? "On" : "Off")
	Hotkey("~*$"  g_mapSettings["sForwardKey"], OnKeyPress, g_mapSettings["bAutorunMode"] == KEY_MODE_TOGGLE ? "On" : "Off")
	Hotkey("~*$" g_mapSettings["sBackwardKey"], OnKeyPress, g_mapSettings["bAutorunMode"] == KEY_MODE_TOGGLE ? "On" : "Off")

	; Enabled only for autofire modes
	Hotkey("*$" g_mapSettings["sAimAutofireKey"], OnKeyPress, g_mapSettings["iAimMode"] == KEY_MODE_AUTOFIRE_TOGGLE ||
	       g_mapSettings["iAimMode"] == KEY_MODE_AUTOFIRE_HOLD  ? "On" : "Off")
	Hotkey("*$" g_mapSettings["sCrouchAutofireKey"], OnKeyPress, g_mapSettings["iCrouchMode"] == KEY_MODE_AUTOFIRE_TOGGLE ||
	       g_mapSettings["iCrouchMode"] == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")
	Hotkey("*$" g_mapSettings["sSprintAutofireKey"], OnKeyPress, g_mapSettings["iSprintMode"] == KEY_MODE_AUTOFIRE_TOGGLE ||
	       g_mapSettings["iSprintMode"] == KEY_MODE_AUTOFIRE_HOLD ? "On" : "Off")

	; Fixes issues when pressing system keys while toggle keys are modifiers and toggled
	; See https://en.wikipedia.org/wiki/Table_of_keyboard_shortcuts#System_navigation
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

	for l_sValue in g_arrMouseButtons
	{
		; Don't register a mouse hotkey if it's already been registered, otherwise it'll override its action
		if (!l_mapHotkeys.Has(l_sValue))
		{
			Output(A_ThisFunc "::" l_sValue)
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
	if (g_mapSettings["bRunAsAdmin"] && !A_IsAdmin)
	{
		try
		{
			; Restart the script as admin
			if A_IsCompiled
				Run("*RunAs " A_ScriptFullPath " /restart")
			else
				Run("*RunAs " A_AhkPath " /restart " A_ScriptFullPath)

			ExitApp()
		}
	}
}

SendAltTab(*)
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
		Send("{Blind}{Control down}")
	if (l_bIsShiftPressed)
		Send("{Blind}{Shift down}")

	Send("{Blind}{Tab down}")
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

SendEscape(*)
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

SendKey(p_sKey, p_iHoldDuration := 0, p_bWait := false)
{
	Send("{Blind}{" p_sKey " down}")

	if (p_iHoldDuration > 0)
		Sleep(p_iHoldDuration)

	if (p_bWait)
		KeyWait(p_sKey)

	Send("{Blind}{" p_sKey " up}")
}

SendWindows(*)
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
	return g_mapSettings["bRestoreAutofiresOnFocus"] && (g_mapSettings["iAimMode"] == KEY_MODE_AUTOFIRE_TOGGLE || g_mapSettings["iCrouchMode"] == KEY_MODE_AUTOFIRE_TOGGLE ||
	       g_mapSettings["iSprintMode"] == KEY_MODE_AUTOFIRE_TOGGLE) && WinExist("ahk_id " g_iWindowID)
}

ShouldRestoreTogglesOnFocus()
{
	return g_mapSettings["bRestoreTogglesOnFocus"] && (g_mapSettings["iAimMode"] == KEY_MODE_TOGGLE || g_mapSettings["iCrouchMode"] == KEY_MODE_TOGGLE ||
	       g_mapSettings["iSprintMode"] == KEY_MODE_TOGGLE || g_mapSettings["bAutorunMode"] == KEY_MODE_TOGGLE) && WinExist("ahk_id " g_iWindowID)
}

ShowNotification(p_sMessage)
{
	switch g_mapSettings["iShowNotifications"]
	{
		case 1:
			; Make sure to clear any existing TrayTip
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

	; Validate process name
	g_mapSettings["sProcessName"] := Trim(g_mapSettings["sProcessName"], '" `t')
	l_bIsProcessNameValid := IsProcessNameValid(g_mapSettings["sProcessName"])
	if (l_bIsProcessNameValid != 1)
		l_sMsgBoxText := l_bIsProcessNameValid == -1 ? "You must specify a process name." : "The process name `"" g_mapSettings["sProcessName"] '" must end with ".exe".'

	; Validate hotkeys (no duplicates allowed)
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
		GuiShow()
		return
	}

	if (g_mapSettings["sWindowName"] == "")
		ShowNotification('Waiting for the process "' g_mapSettings["sProcessName"] '" to become active.')
	else
		ShowNotification('Waiting for the window "' g_mapSettings["sWindowName"] '" of the process "' g_mapSettings["sProcessName"] '" to become active.')

	Output(A_ThisFunc "::WinWaitActive")
	SetTimer(OnFocusChanged, g_mapSettings["iFocusCheckInterval"])
}

TakeToggleKeysSnapshot()
{
	g_mapStates["bRestoreAiming"]            := g_mapStates["bAiming"]
	g_mapStates["bRestoreCrouching"]         := g_mapStates["bCrouching"]
	g_mapStates["bRestoreSprinting"]         := g_mapStates["bSprinting"]
	g_mapStates["bRestoreAutorunning"]       := g_mapStates["bAutorunning"]
	g_mapStates["bRestoreAutofireAiming"]    := g_mapStates["bAutofireAiming"]
	g_mapStates["bRestoreAutofireCrouching"] := g_mapStates["bAutofireCrouching"]
	g_mapStates["bRestoreAutofireSprinting"] := g_mapStates["bAutofireSprinting"]

	global g_bToggleKeysSnapshotTaken := true
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
		IniWrite(g_mapControls["ddlSendMode"].Value - 1,           "KeyToggles.ini", "General", "sendMode")
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
		IniWrite(g_mapControls["cbAlwaysOnTop"].Value,             "KeyToggles.ini", "UI",      "alwaysOnTop")
		IniWrite(g_mapControls["cbCloseToTray"].Value,             "KeyToggles.ini", "UI",      "closeToTray")
		IniWrite(g_mapControls["cbDarkMode"].Value,                "KeyToggles.ini", "UI",      "darkMode")
		IniWrite(g_mapControls["cbHideFromCapture"].Value,         "KeyToggles.ini", "UI",      "hideFromCapture")
		IniWrite(g_mapControls["cbMinimizeToTray"].Value,          "KeyToggles.ini", "UI",      "minimizeToTray")
		IniWrite(g_mapControls["cbRememberWindowPosition"].Value,  "KeyToggles.ini", "UI",      "rememberWindowPosition")
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
#HotIf g_mapControls["cbDebugMode"].Value
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
