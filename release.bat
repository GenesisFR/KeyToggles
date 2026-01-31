if exist AHKBatchScriptCompiler.exe (
	AHKBatchScriptCompiler.exe KeyToggles.ahk
)

powershell -Command Compress-Archive -Path "KeyToggles.ahk", "KeyToggles.exe", "KeyToggles.ini", "README.md" -Update -DestinationPath "KeyToggles.zip"