#Requires AutoHotkey v2.0
; Builds FavoriteLauncher.exe: runs the test suite, and only if every test passes,
; compiles FavoriteLauncher.ahk and checks the result.
;
; Run from a terminal (output on stdout, exit code 0 = success):
;   "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut build.ahk
; Or double-click build.ahk: the result is shown in a message box.

global RepoDir := A_ScriptDir
global ScriptFile := RepoDir "\FavoriteLauncher.ahk"
global ExeFile := RepoDir "\FavoriteLauncher.exe"
global Compiler := A_ProgramFiles "\AutoHotkey\Compiler\Ahk2Exe.exe"
global LogText := ""

ExitApp(Build())

Build() {
    global ExeFile

    version := ReadAppVersion()
    Log("FavoriteLauncher " version)

    Log("`n== Tests ==")
    if !RunTests()
        return Finish(false, "Tests failed. No exe was built.")

    Log("`n== Compile ==")
    wasRunning := CloseRunningExe()
    compileError := Compile()
    if compileError != ""
        return Finish(false, compileError)

    Log("`n== Check exe ==")
    checkError := CheckExe(version)
    if checkError != ""
        return Finish(false, checkError)

    if wasRunning {
        Run('"' ExeFile '"', RepoDir)
        Log("Restarted FavoriteLauncher.exe")
    }

    return Finish(true, "Built FavoriteLauncher.exe " version)
}

; Runs the test suite and copies its output into the build log.
RunTests() {
    global RepoDir
    outputFile := A_Temp "\FavoriteLauncher-test-output.txt"
    try FileDelete(outputFile)

    exitCode := RunWait(
        A_ComSpec ' /c ""' A_AhkPath '" /ErrorStdOut "' RepoDir '\tests\FavoriteLauncher.Tests.ahk" > "' outputFile '" 2>&1"',
        RepoDir,
        "Hide"
    )
    Log(FileExist(outputFile) ? RTrim(FileRead(outputFile), "`r`n") : "(no test output)")
    return exitCode = 0
}

; The exe cannot be overwritten while it runs. Returns true if it was running.
CloseRunningExe() {
    global ExeFile
    wasRunning := false
    for process in ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, ExecutablePath FROM Win32_Process WHERE Name = 'FavoriteLauncher.exe'") {
        if process.ExecutablePath != ExeFile
            continue
        ProcessClose(process.ProcessId)
        ProcessWaitClose(process.ProcessId, 5)
        wasRunning := true
        Log("Closed running FavoriteLauncher.exe")
    }
    return wasRunning
}

; Returns "" on success, otherwise what went wrong.
Compile() {
    global Compiler, ScriptFile, ExeFile
    if !FileExist(Compiler)
        return "Ahk2Exe not found at " Compiler ". Install the compiler from the AutoHotkey Dash (Compile)."

    try FileDelete(ExeFile)
    if FileExist(ExeFile)
        return "Could not replace FavoriteLauncher.exe. Close it and build again."

    exitCode := RunWait(
        '"' Compiler '" /in "' ScriptFile '" /out "' ExeFile '" /base "' A_AhkPath '" /silent',
        RepoDir,
        "Hide"
    )
    if exitCode != 0
        return "Ahk2Exe failed with exit code " exitCode "."

    Log("Compiled " ExeFile)
    return ""
}

; Checks that the exe exists, carries the app version, and has the app icon.
CheckExe(version) {
    global ExeFile, RepoDir
    if !FileExist(ExeFile)
        return "FavoriteLauncher.exe was not created."

    fileVersion := FileGetVersion(ExeFile)
    if fileVersion != version ".0"
        return "Exe version is " fileVersion ", expected " version ".0."
    Log("PASS  exe version " fileVersion)

    exeIcon := GetIconSignature(ExeFile)
    if exeIcon = "" || exeIcon != GetIconSignature(RepoDir "\FavoriteLauncher.ico")
        return "Exe icon is not FavoriteLauncher.ico."
    Log("PASS  exe icon is FavoriteLauncher.ico")

    return ""
}

; Pixels of the file's 32x32 icon as hex, to compare icons. "" if none.
GetIconSignature(file) {
    try handle := LoadPicture(file, "w32 h32", &imageType)
    catch
        return ""

    hdc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
    bitmapInfo := Buffer(40, 0)
    NumPut("UInt", 40, "Int", 32, "Int", -32, "UShort", 1, "UShort", 32, bitmapInfo)
    bits := 0
    dib := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bitmapInfo, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", dib, "Ptr")
    DllCall("DrawIconEx", "Ptr", hdc, "Int", 0, "Int", 0, "Ptr", handle, "Int", 32, "Int", 32, "UInt", 0, "Ptr", 0, "UInt", 3)

    signature := ""
    loop 32 * 32
        signature .= Format("{:08X}", NumGet(bits, (A_Index - 1) * 4, "UInt"))

    DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
    DllCall("DeleteObject", "Ptr", dib)
    DllCall("DeleteDC", "Ptr", hdc)
    DllCall(imageType = 1 ? "DestroyIcon" : "DeleteObject", "Ptr", handle)
    return signature
}

ReadAppVersion() {
    global ScriptFile
    RegExMatch(FileRead(ScriptFile), 'm)^global AppVersion := "([^"]*)"', &match)
    return IsObject(match) ? match[1] : "(unknown version)"
}

Log(text) {
    global LogText
    LogText .= text "`n"
    try FileAppend(text "`n", "*")
}

Finish(success, message) {
    global LogText
    Log("`n" (success ? "BUILD OK: " : "BUILD FAILED: ") message)

    ; Double-clicked (no console attached): show the result.
    if !DllCall("GetStdHandle", "Int", -11, "Ptr")
        MsgBox(LogText, "FavoriteLauncher build", (success ? "Iconi" : "Iconx") " 0x40000")

    return success ? 0 : 1
}
