#Requires AutoHotkey v2.0
; Test suite for FavoriteLauncher.ahk.
;
; Run from the repository root:
;   "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tests\FavoriteLauncher.Tests.ahk
;
; Prints one line per test to stdout and exits with the number of failed tests (0 = all passed).
; Uses a temporary ini file, so your own favorites are never touched.
; GUI tests briefly show the launcher, the editor and dialogs.

#Include ..\FavoriteLauncher.ahk

global TestDir := A_Temp "\FavoriteLauncherTests"
global PassedCount := 0, FailedCount := 0
global DialogOwner := 0

DirCreate(TestDir)
ConfigFile := TestDir "\FavoriteLauncher.ini"
try FileDelete(ConfigFile)

RunAllTests([
    ; Search and display helpers
    Test_MatchRank_OrdersPrefixBeforeWordBeforeContains,
    Test_MatchRank_FindsTargetAndShortcut,
    Test_DisplayHotkey_UsesReadableNames,
    Test_IsReservedHotkey_BlocksLauncherShortcut,
    Test_FindDuplicateHotkey_IgnoresItself,
    Test_GetDefaultName_FromLinkFolderAndFile,
    Test_SortFavorites_SortsByName,

    ; Saving and loading
    Test_SaveAndLoad_RoundTrip,
    Test_Load_UnknownTypeBecomesFolder,
    Test_Load_MissingIniCreatesDefaults,

    ; Version numbering
    Test_Version_IsSemanticVersion,
    Test_Version_MatchesCompilerDirective,
    Test_Version_HasChangelogEntry,
    Test_Version_ShownInAboutWindow,

    ; Launcher window
    Test_MainWindow_TitleIsFavoriteLauncher,
    Test_ListIcons_AreSmallIconSize,
    Test_AppIcon_LoadsFromIcoFile,
    Test_WindowIcon_SetOnLauncherEditorAndAbout,
    Test_ListHeight_ShowsAllFavoritesWhenFew,
    Test_ListHeight_ShowsAtLeastThreeRows,
    Test_ListHeight_CappedAt80PercentOfScreen,

    ; Dialogs stay in front
    Test_Editor_IsOwnedByLauncher,
    Test_EditorMessage_IsOwnedByEditor,
    Test_BrowseDialog_IsOwnedByEditor,
    Test_RemoveConfirmation_IsOwnedByLauncher,
])

; ---------------------------------------------------------------------------
; Search and display helpers

Test_MatchRank_OrdersPrefixBeforeWordBeforeContains() {
    favorite := MakeFavorite("My Documents", "C:\Docs")
    AssertEqual(GetMatchRank(favorite, ""), 10, "empty filter")
    AssertEqual(GetMatchRank(favorite, "my"), 1, "name prefix")
    AssertEqual(GetMatchRank(favorite, "doc"), 2, "word prefix")
    AssertEqual(GetMatchRank(favorite, "ume"), 3, "inside name")
    AssertEqual(GetMatchRank(favorite, "zzz"), 100, "no match")
}

Test_MatchRank_FindsTargetAndShortcut() {
    favorite := MakeFavorite("Reports", "D:\Archive\Q4", "folder", "^!r")
    AssertEqual(GetMatchRank(favorite, "archive"), 4, "match in location")
    AssertEqual(GetMatchRank(favorite, "ctrl+alt"), 5, "match in shortcut")
}

Test_DisplayHotkey_UsesReadableNames() {
    AssertEqual(DisplayHotkey(""), "", "no shortcut")
    AssertEqual(DisplayHotkey("^!d"), "Ctrl+Alt+D", "Ctrl+Alt")
    AssertEqual(DisplayHotkey("^+Space"), "Ctrl+Shift+Space", "Space name")
    AssertEqual(DisplayHotkey("<^>!a"), "AltGr+A", "AltGr")
    AssertEqual(DisplayHotkey("#PgDn"), "Win+Page Down", "Page Down")
}

Test_IsReservedHotkey_BlocksLauncherShortcut() {
    AssertTrue(IsReservedHotkey("^!Space"), "Ctrl+Alt+Space is reserved")
    AssertTrue(IsReservedHotkey("^!space"), "case does not matter")
    AssertFalse(IsReservedHotkey("^!d"), "other shortcuts are free")
}

Test_FindDuplicateHotkey_IgnoresItself() {
    global Favorites
    Favorites := [MakeFavorite("A", "C:\A", "folder", "^!a"), MakeFavorite("B", "C:\B")]
    AssertEqual(FindDuplicateHotkey("^!A"), 1, "finds existing shortcut, any case")
    AssertEqual(FindDuplicateHotkey("^!a", 1), 0, "the favorite being edited is ignored")
    AssertEqual(FindDuplicateHotkey("^!z"), 0, "unused shortcut")
}

Test_GetDefaultName_FromLinkFolderAndFile() {
    AssertEqual(GetDefaultName("https://www.example.com/path/", "link"), "www.example.com", "link")
    AssertEqual(GetDefaultName("C:\Work\Projects\", "folder"), "Projects", "folder")
    AssertEqual(GetDefaultName("C:\Work\report.docx", "document"), "report", "document")
}

Test_SortFavorites_SortsByName() {
    global Favorites
    Favorites := [MakeFavorite("Charlie", "C:\C"), MakeFavorite("alpha", "C:\A"), MakeFavorite("Bravo", "C:\B")]
    SortFavorites()
    AssertEqual(Favorites[1].Name "," Favorites[2].Name "," Favorites[3].Name, "alpha,Bravo,Charlie", "sorted")
}

; ---------------------------------------------------------------------------
; Saving and loading

Test_SaveAndLoad_RoundTrip() {
    global Favorites
    Favorites := [
        MakeFavorite("Docs", "C:\Docs", "folder", "^!d"),
        MakeFavorite("Site", "example.com", "link")
    ]
    SaveFavorites()
    Favorites := []
    LoadFavorites()
    AssertEqual(Favorites.Length, 2, "count")
    AssertEqual(Favorites[1].Name "|" Favorites[1].Target "|" Favorites[1].Type "|" Favorites[1].Hotkey,
        "Docs|C:\Docs|folder|^!d", "first favorite")
    AssertEqual(Favorites[2].Type, "link", "second favorite type")
}

Test_Load_UnknownTypeBecomesFolder() {
    global Favorites, ConfigFile
    try FileDelete(ConfigFile)
    IniWrite(1, ConfigFile, "Settings", "Count")
    IniWrite("Odd", ConfigFile, "Favorite1", "Name")
    IniWrite("C:\Odd", ConfigFile, "Favorite1", "Target")
    IniWrite("spaceship", ConfigFile, "Favorite1", "Type")
    LoadFavorites()
    AssertEqual(Favorites[1].Type, "folder", "unknown type")
}

Test_Load_MissingIniCreatesDefaults() {
    global Favorites, ConfigFile
    try FileDelete(ConfigFile)
    LoadFavorites()
    AssertEqual(Favorites.Length, 3, "three default favorites")
    AssertTrue(FileExist(ConfigFile) != "", "ini file created")
}

; ---------------------------------------------------------------------------
; Version numbering

Test_Version_IsSemanticVersion() {
    version := ReadAppVersion()
    AssertTrue(RegExMatch(version, "^\d+\.\d+\.\d+$"), "AppVersion '" version "' should look like 1.2.3")
}

Test_Version_MatchesCompilerDirective() {
    source := FileRead(AppDir "\FavoriteLauncher.ahk")
    RegExMatch(source, "m)^;@Ahk2Exe-SetVersion\s+(\S+)", &match)
    AssertTrue(IsObject(match), ";@Ahk2Exe-SetVersion directive exists")
    AssertEqual(match[1], ReadAppVersion(), "compiler version equals AppVersion")
}

Test_Version_HasChangelogEntry() {
    changelogFile := AppDir "\CHANGELOG.md"
    AssertTrue(FileExist(changelogFile) != "", "CHANGELOG.md exists")
    version := ReadAppVersion()
    AssertTrue(InStr(FileRead(changelogFile), "## [" version "]"), "CHANGELOG.md has a '## [" version "]' section")
}

Test_Version_ShownInAboutWindow() {
    global AboutGui
    ShowAbout()
    try {
        allText := ""
        for control in AboutGui
            allText .= control.Text "`n"
        AssertTrue(InStr(allText, "Version " ReadAppVersion()), "About window shows 'Version " ReadAppVersion() "'")
    } finally {
        AboutGui.Destroy()
        AboutGui := ""
    }
}

; ---------------------------------------------------------------------------
; Launcher window

Test_MainWindow_TitleIsFavoriteLauncher() {
    SetUpLauncher(3)
    AssertEqual(MainGui.Title, "FavoriteLauncher", "window title")
}

Test_ListIcons_AreSmallIconSize() {
    SetUpLauncher(3)
    iconWidth := 0, iconHeight := 0
    DllCall("Comctl32\ImageList_GetIconSize", "Ptr", FavoriteImageList, "Int*", &iconWidth, "Int*", &iconHeight)
    AssertEqual(iconWidth, SysGet(49), "icon width equals system small icon width")
    AssertEqual(iconHeight, SysGet(50), "icon height equals system small icon height")
}

Test_AppIcon_LoadsFromIcoFile() {
    AssertTrue(FileExist(AppIconFile) != "", "FavoriteLauncher.ico exists")
    AssertTrue(GetAppIcon("small"), "small icon loaded")
    AssertTrue(GetAppIcon("big"), "big icon loaded")
}

; AHK gives every window its own default icon, so check the icon is ours, not just present.
Test_WindowIcon_SetOnLauncherEditorAndAbout() {
    global AboutGui
    SetUpLauncher(3)
    AssertEqual(GetWindowIcon(MainGui, "small"), GetAppIcon("small"), "launcher title bar icon")
    AssertEqual(GetWindowIcon(MainGui, "big"), GetAppIcon("big"), "launcher taskbar icon")

    OpenEditor()
    try AssertEqual(GetWindowIcon(EditorGui, "small"), GetAppIcon("small"), "editor icon")
    finally CloseEditor()

    ShowAbout()
    try AssertEqual(GetWindowIcon(AboutGui, "small"), GetAppIcon("small"), "About icon")
    finally {
        AboutGui.Destroy()
        AboutGui := ""
    }
}

Test_ListHeight_ShowsAllFavoritesWhenFew() {
    SetUpLauncher(8)
    AssertTrue(RowsThatFit() >= 8, "all 8 favorites visible without scrolling (fits " RowsThatFit() ")")
    AssertTrue(RowsThatFit() <= 9, "no large empty area below the list (fits " RowsThatFit() ")")
}

Test_ListHeight_ShowsAtLeastThreeRows() {
    SetUpLauncher(1)
    AssertTrue(RowsThatFit() >= 3, "room for at least 3 rows (fits " RowsThatFit() ")")
}

Test_ListHeight_CappedAt80PercentOfScreen() {
    SetUpLauncher(200)
    windowHeight := GetWindowHeight(MainGui.Hwnd)
    limit := Floor(A_ScreenHeight * 0.8)
    AssertTrue(windowHeight <= limit, "window height " windowHeight " <= " limit)
    AssertTrue(windowHeight >= limit - 40, "window uses the space it has (" windowHeight " of " limit ")")
}

; ---------------------------------------------------------------------------
; Dialogs stay in front

Test_Editor_IsOwnedByLauncher() {
    SetUpLauncher(3)
    OpenEditor()
    try AssertEqual(GetOwner(EditorGui.Hwnd), MainGui.Hwnd, "editor owner")
    finally CloseEditor()
}

Test_EditorMessage_IsOwnedByEditor() {
    SetUpLauncher(3)
    OpenEditor()
    try {
        EditorName.Value := ""
        EditorTarget.Value := ""
        WatchForDialog()
        SaveEditor()    ; shows "Enter a name."
        AssertEqual(DialogOwner, EditorGui.Hwnd, "message box owner")
    } finally {
        CloseEditor()
    }
}

Test_BrowseDialog_IsOwnedByEditor() {
    SetUpLauncher(3)
    OpenEditor()
    try {
        EditorType.Choose(1)    ; Folder
        WatchForDialog()
        BrowseEditorTarget()
        AssertEqual(DialogOwner, EditorGui.Hwnd, "folder picker owner")
    } finally {
        CloseEditor()
    }
}

Test_RemoveConfirmation_IsOwnedByLauncher() {
    SetUpLauncher(3)
    MainGui.Show("AutoSize")
    try {
        WatchForDialog("Button2")    ; answer No
        RemoveSelected()
        AssertEqual(DialogOwner, MainGui.Hwnd, "confirmation owner")
        AssertEqual(Favorites.Length, 3, "nothing removed after answering No")
    } finally {
        MainGui.Hide()
    }
}

; ---------------------------------------------------------------------------
; Helpers

MakeFavorite(name, target, type := "folder", hotkeyValue := "") {
    return {Name: name, Target: target, Type: type, Hotkey: hotkeyValue}
}

ReadAppVersion() {
    source := FileRead(AppDir "\FavoriteLauncher.ahk")
    return RegExMatch(source, 'm)^global AppVersion := "([^"]*)"', &match) ? match[1] : ""
}

; Builds a fresh, hidden launcher holding `count` favorites, sized as the user would see it.
SetUpLauncher(count) {
    global MainGui, Favorites, IconCache, ListRowHeight
    if IsObject(MainGui)
        MainGui.Destroy()
    MainGui := ""
    IconCache := Map()
    ListRowHeight := 0

    Favorites := []
    loop count
        Favorites.Push(MakeFavorite(Format("Item {:03}", A_Index), A_WinDir))

    CreateMainGui()
    RefreshList()
    MainGui.Show("AutoSize Hide")
}

RowsThatFit() {
    static LVM_GETCOUNTPERPAGE := 0x1028
    return SendMessage(LVM_GETCOUNTPERPAGE, 0, 0, FavoritesList)
}

GetWindowIcon(guiObj, size) {
    static WM_GETICON := 0x7F
    return DllCall("SendMessageW", "Ptr", guiObj.Hwnd, "UInt", WM_GETICON, "Ptr", size = "small" ? 0 : 1, "Ptr", 0, "Ptr")
}

GetOwner(hwnd) {
    static GW_OWNER := 4
    return DllCall("GetWindow", "Ptr", hwnd, "UInt", GW_OWNER, "Ptr")
}

; Waits (in a timer thread) for this process to show a dialog, records its owner window,
; then closes it: with the given button, or like pressing Cancel/Close.
WatchForDialog(buttonToClick := "") {
    global DialogOwner := 0
    processId := DllCall("GetCurrentProcessId")
    deadline := A_TickCount + 5000

    CheckForDialog() {
        global DialogOwner
        dialog := WinExist("ahk_class #32770 ahk_pid " processId)
        if !dialog {
            if A_TickCount > deadline
                SetTimer(CheckForDialog, 0)
            return
        }
        SetTimer(CheckForDialog, 0)
        DialogOwner := GetOwner(dialog)
        if buttonToClick != ""
            ControlClick(buttonToClick, dialog)
        else
            WinClose(dialog)
    }

    SetTimer(CheckForDialog, 50)
}

AssertEqual(actual, expected, message) {
    if actual !== expected && !(IsNumber(actual) && IsNumber(expected) && actual = expected)
        throw Error(message ": expected [" expected "] but got [" actual "]")
}

AssertTrue(value, message) {
    if !value
        throw Error(message)
}

AssertFalse(value, message) {
    if value
        throw Error(message)
}

RunAllTests(tests) {
    global PassedCount, FailedCount, MainGui

    for test in tests {
        try {
            test()
            PassedCount += 1
            FileAppend("PASS  " test.Name "`n", "*")
        } catch Error as err {
            FailedCount += 1
            where := err.What != "" && err.What != test.Name ? " (in " err.What ", line " err.Line ")" : ""
            FileAppend("FAIL  " test.Name "`n      " err.Message where "`n", "*")
        }
    }

    try FileDelete(ConfigFile)
    if IsObject(MainGui)
        MainGui.Destroy()

    FileAppend("`n" PassedCount " passed, " FailedCount " failed`n", "*")
    ExitApp(FailedCount)
}
