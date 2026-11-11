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
global DialogOwner := 0, DialogText := ""

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
    Test_AddStep1_FolderPickerIsOwnedByEditor,
    Test_RemoveConfirmation_IsOwnedByLauncher,

    ; Add favorite: location first, then name and shortcut
    Test_AddStep1_AsksWhatToAdd,
    Test_AddStep1_PickedLocationGoesToStep2,
    Test_AddStep1_WebAddressGoesToStep2WithoutPicker,
    Test_AddStep2_OrderIsLocationThenNameThenShortcut,
    Test_AddStep2_BackReturnsToStep1,
    Test_AddStep2_AddSavesFavorite,
    Test_Edit_IsOneWindowWithSameOrder,

    ; Checking a shortcut
    Test_CheckShortcut_EmptyAndFree,
    Test_CheckShortcut_ReservedAndDuplicateAreErrors,
    Test_CheckShortcut_AltLetterWarnsAboutMenus,
    Test_CheckShortcut_SingleKeyAndShiftLetterWarn,
    Test_CheckShortcut_CommonCtrlShortcutWarns,
    Test_CheckShortcut_TakenByOtherProgramWarns,
    Test_CheckShortcut_AltGrCharacterWarns,
    Test_TestButton_ShowsResultUnderShortcut,
    Test_Save_RiskyShortcutAsksFirst,

    ; Smaller UI, icons on the Add choices, Command type
    Test_Fonts_AreNinePointEverywhere,
    Test_AddStep1_ListsFiveTypesWithIconsAndHints,
    Test_AddStep1_CommandGoesToStep2WithKeepOpen,
    Test_Edit_CommandShowsSavedKeepOpen,
    Test_Command_SaveAndLoadKeepsKeepOpen,
    Test_Command_RunLineUsesCmd,
    Test_GetDefaultName_FromCommand,

    ; Tray menu
    Test_TrayMenu_ItemsAndSingleClickOpens,

    ; Start with Windows
    Test_StartWithWindows_TrayItemTogglesShortcut,
    Test_Welcome_StartWithWindowsCheckedByDefault,
    Test_Welcome_UncheckedRemovesShortcut,

    ; Update banner
    Test_CompareVersions_ComparesEachNumber,
    Test_ParseLatestRelease_ReadsVersionAndUrl,
    Test_ShouldShowUpdate_OnlyNewerAndNotDismissed,
    Test_UpdateBanner_ShowsAboveSearch,
    Test_UpdateBanner_DismissHidesIt,
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

    AddFavorite()
    try AssertEqual(GetWindowIcon(EditorGui, "small"), GetAppIcon("small"), "Add step 1 icon")
    finally CloseEditor()

    ContinueWithTarget("folder", A_WinDir)
    try AssertEqual(GetWindowIcon(EditorGui, "small"), GetAppIcon("small"), "Add step 2 icon")
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
    AddFavorite()
    try AssertEqual(GetOwner(EditorGui.Hwnd), MainGui.Hwnd, "Add step 1 owner")
    finally CloseEditor()

    ContinueWithTarget("folder", A_WinDir)
    try AssertEqual(GetOwner(EditorGui.Hwnd), MainGui.Hwnd, "Add step 2 owner")
    finally CloseEditor()

    OpenEditor(1)
    try AssertEqual(GetOwner(EditorGui.Hwnd), MainGui.Hwnd, "Edit window owner")
    finally CloseEditor()
}

Test_EditorMessage_IsOwnedByEditor() {
    SetUpLauncher(3)
    ChooseAddType("link")
    try {
        EditorName.Value := ""
        EditorTarget.Value := ""
        WatchForDialog()
        SaveEditor()    ; shows "Enter a web address."
        AssertEqual(DialogOwner, EditorGui.Hwnd, "message box owner")
    } finally {
        CloseEditor()
    }
}

Test_AddStep1_FolderPickerIsOwnedByEditor() {
    SetUpLauncher(3)
    AddFavorite()
    try {
        WatchForDialog()
        ChooseAddType("folder")    ; the picker opens right away; the watcher cancels it
        AssertEqual(DialogOwner, EditorGui.Hwnd, "folder picker owner")
        AssertTrue(InStr(GetGuiText(EditorGui), "What do you want to add?"), "still on step 1 after cancelling the picker")
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
; Add favorite: location first, then name and shortcut

Test_AddStep1_AsksWhatToAdd() {
    SetUpLauncher(3)
    AddFavorite()
    try {
        allText := GetGuiText(EditorGui)
        AssertTrue(InStr(allText, "Step 1 of 2"), "shows 'Step 1 of 2'")
        AssertTrue(InStr(allText, "What do you want to add?"), "asks what to add")
        for label in ["&Folder...", "&Document...", "&Program...", "&Web address", "&Command", "Cancel"]
            AssertTrue(InStr(allText, label "`n"), "has button " label)
        AssertEqual(CountControls(EditorGui, "Edit"), 0, "no text fields before the location is chosen")
    } finally {
        CloseEditor()
    }
}

Test_AddStep1_PickedLocationGoesToStep2() {
    SetUpLauncher(3)
    AddFavorite()
    ContinueWithTarget("folder", "C:\Work\Projects")
    try {
        AssertTrue(InStr(GetGuiText(EditorGui), "Step 2 of 2"), "shows 'Step 2 of 2'")
        AssertEqual(EditorTarget.Value, "C:\Work\Projects", "location filled in")
        AssertEqual(EditorName.Value, "Projects", "name suggested from the location")
        AssertEqual(EditorHotkey.Value, "", "no shortcut yet")
    } finally {
        CloseEditor()
    }
}

Test_AddStep1_WebAddressGoesToStep2WithoutPicker() {
    SetUpLauncher(3)
    AddFavorite()
    WatchForDialog()
    ChooseAddType("link")
    try {
        AssertEqual(DialogOwner, 0, "no picker for a web address")
        AssertTrue(InStr(GetGuiText(EditorGui), "Web address`n"), "location is labelled 'Web address'")
        AssertEqual(EditorTarget.Value, "", "web address starts empty")
        EditorTarget.Value := "https://www.example.com/start"
        SuggestEditorName()
        AssertEqual(EditorName.Value, "www.example.com", "name follows the typed address")
    } finally {
        CloseEditor()
    }
}

Test_AddStep2_OrderIsLocationThenNameThenShortcut() {
    SetUpLauncher(3)
    ContinueWithTarget("folder", A_WinDir)
    try {
        EditorTarget.GetPos(, &targetY)
        EditorName.GetPos(, &nameY)
        EditorHotkey.GetPos(, &hotkeyY)
        AssertTrue(targetY < nameY, "location above name")
        AssertTrue(nameY < hotkeyY, "name above shortcut")
        allText := GetGuiText(EditorGui)
        for label in ["Change...", "Test", "Clear", "< Back", "Add", "Cancel"]
            AssertTrue(InStr(allText, label "`n"), "has button " label)
    } finally {
        CloseEditor()
    }
}

Test_AddStep2_BackReturnsToStep1() {
    SetUpLauncher(3)
    ContinueWithTarget("folder", A_WinDir)
    try {
        GoBackToStep1()
        AssertTrue(InStr(GetGuiText(EditorGui), "What do you want to add?"), "back on step 1")
        AssertEqual(GetOwner(EditorGui.Hwnd), MainGui.Hwnd, "step 1 still owned by the launcher")
    } finally {
        CloseEditor()
    }
}

Test_AddStep2_AddSavesFavorite() {
    SetUpLauncher(3)
    ContinueWithTarget("folder", A_WinDir)
    EditorName.Value := "Windows folder"
    SaveEditor()
    AssertEqual(Favorites.Length, 4, "one favorite added")
    added := FindFavoriteByName("Windows folder")
    AssertTrue(IsObject(added), "added favorite found by name")
    AssertEqual(added.Target "|" added.Type, A_WinDir "|folder", "location and type saved")
    AssertFalse(IsObject(EditorGui) && WinExist("ahk_id " EditorGui.Hwnd), "window closed after Add")
}

Test_Edit_IsOneWindowWithSameOrder() {
    SetUpLauncher(3)
    OpenEditor(1)
    try {
        allText := GetGuiText(EditorGui)
        AssertEqual(EditorName.Value, Favorites[1].Name, "name filled in")
        AssertEqual(EditorTarget.Value, Favorites[1].Target, "location filled in")
        AssertFalse(InStr(allText, "< Back"), "no Back button when editing")
        AssertFalse(InStr(allText, "Step "), "no step text when editing")
        AssertTrue(InStr(allText, "Save`n"), "has Save button")
        EditorTarget.GetPos(, &targetY)
        EditorName.GetPos(, &nameY)
        EditorHotkey.GetPos(, &hotkeyY)
        AssertTrue(targetY < nameY && nameY < hotkeyY, "location, then name, then shortcut")
    } finally {
        CloseEditor()
    }
}

; ---------------------------------------------------------------------------
; Checking a shortcut

Test_CheckShortcut_EmptyAndFree() {
    global Favorites := []
    AssertEqual(CheckShortcut("").Level, "none", "no shortcut")
    result := CheckShortcut("^+!F11")
    AssertEqual(result.Level, "ok", "Ctrl+Alt+Shift+F11 is free (" result.Message ")")
}

Test_CheckShortcut_ReservedAndDuplicateAreErrors() {
    global Favorites := [MakeFavorite("Reports", "C:\R", "folder", "^!r")]
    AssertEqual(CheckShortcut("^!Space").Level, "error", "launcher shortcut")
    result := CheckShortcut("^!R")
    AssertEqual(result.Level, "error", "used by another favorite")
    AssertTrue(InStr(result.Message, "Reports"), "names the other favorite: " result.Message)
    AssertTrue(CheckShortcut("^!r", 1).Level != "error", "a favorite's own shortcut is not a duplicate")
}

Test_CheckShortcut_AltLetterWarnsAboutMenus() {
    global Favorites := []
    result := CheckShortcut("!p")
    AssertEqual(result.Level, "warn", "Alt+P")
    AssertTrue(InStr(result.Message, "menus"), "explains menus: " result.Message)
    AssertTrue(InStr(result.Message, "Try Ctrl+"), "suggests adding Ctrl: " result.Message)
}

Test_CheckShortcut_SingleKeyAndShiftLetterWarn() {
    global Favorites := []
    AssertEqual(CheckShortcut("p").Level, "warn", "P alone")
    AssertEqual(CheckShortcut("+p").Level, "warn", "Shift+P")
    AssertEqual(CheckShortcut("F5").Level, "warn", "F5 alone")
}

Test_CheckShortcut_CommonCtrlShortcutWarns() {
    global Favorites := []
    result := CheckShortcut("^s")
    AssertEqual(result.Level, "warn", "Ctrl+S")
    AssertTrue(InStr(result.Message, "Save"), "says what Ctrl+S does: " result.Message)
}

Test_CheckShortcut_TakenByOtherProgramWarns() {
    static MOD_ALT := 1, MOD_CONTROL := 2, MOD_SHIFT := 4, VK_F10 := 0x79, TestId := 0x1234
    global Favorites := []
    registered := DllCall("RegisterHotKey", "Ptr", 0, "Int", TestId, "UInt", MOD_ALT | MOD_CONTROL | MOD_SHIFT, "UInt", VK_F10)
    AssertTrue(registered, "test setup: claim Ctrl+Alt+Shift+F10 like another program would")
    try {
        result := CheckShortcut("^+!F10")
        AssertEqual(result.Level, "warn", "taken shortcut")
        AssertTrue(InStr(result.Message, "another program"), "says another program uses it: " result.Message)
    } finally {
        DllCall("UnregisterHotKey", "Ptr", 0, "Int", TestId)
    }
}

; On layouts with AltGr (like Norwegian), Ctrl+Alt+2 types "@", so it is a bad shortcut.
Test_CheckShortcut_AltGrCharacterWarns() {
    global Favorites := []
    language := DllCall("GetKeyboardLayout", "UInt", 0, "Ptr") & 0xFFFF
    if language = 0x0414 || language = 0x0814    ; Norwegian Bokmål / Nynorsk
        AssertEqual(GetAltGrCharacter("^!2"), "@", "Ctrl+Alt+2 types @ on a Norwegian keyboard")

    character := GetAltGrCharacter("^!2")
    if character = ""
        return    ; this layout has no AltGr character on 2
    result := CheckShortcut("^!2")
    AssertEqual(result.Level, "warn", "Ctrl+Alt+2")
    AssertTrue(InStr(result.Message, character), "names the character: " result.Message)
}

Test_TestButton_ShowsResultUnderShortcut() {
    SetUpLauncher(3)
    ContinueWithTarget("folder", A_WinDir)
    try {
        EditorHotkey.Value := "!p"
        TestEditorShortcut()
        AssertTrue(InStr(EditorShortcutStatus.Text, "menus"), "status shows the warning: " EditorShortcutStatus.Text)
        EditorHotkey.Value := "^+!F11"
        TestEditorShortcut()
        AssertTrue(InStr(EditorShortcutStatus.Text, "looks free"), "status says it looks free: " EditorShortcutStatus.Text)
    } finally {
        CloseEditor()
    }
}

Test_Save_RiskyShortcutAsksFirst() {
    SetUpLauncher(3)
    ContinueWithTarget("folder", A_WinDir)
    try {
        EditorName.Value := "Risky"
        EditorHotkey.Value := "!p"
        WatchForDialog("Button2")    ; No
        SaveEditor()
        AssertEqual(DialogOwner, EditorGui.Hwnd, "question owned by the editor")
        AssertEqual(Favorites.Length, 3, "not added after answering No")

        WatchForDialog("Button1")    ; Yes
        SaveEditor()
        AssertEqual(Favorites.Length, 4, "added after answering Yes [dialog: " StrReplace(DialogText, "`r`n", " / ") "]")
        AssertEqual(FindFavoriteByName("Risky").Hotkey, "!p", "shortcut kept")
    } finally {
        UnregisterAllHotkeys()
        CloseEditor()
    }
}

; ---------------------------------------------------------------------------
; Smaller UI, icons on the Add choices, Command type

Test_Fonts_AreNinePointEverywhere() {
    global AboutGui
    SetUpLauncher(3)
    AssertEqual(GetFontPoints(SearchBox), 9, "launcher search box")
    AssertEqual(GetFontPoints(FavoritesList), 9, "launcher list")
    AssertEqual(GetFontPoints(AddButton), 9, "launcher Add button")

    AddFavorite()
    try {
        for control in EditorGui {
            if control.Type = "Button" {
                AssertEqual(GetFontPoints(control), 9, "Add step 1 button " control.Text)
                break
            }
        }
    } finally {
        CloseEditor()
    }

    ContinueWithTarget("folder", A_WinDir)
    try {
        AssertEqual(GetFontPoints(EditorName), 9, "name field")
        AssertEqual(GetFontPoints(EditorShortcutStatus), 9, "shortcut status")
    } finally {
        CloseEditor()
    }

    ShowAbout()
    try {
        for control in AboutGui {
            if control.Type = "Button"
                AssertEqual(GetFontPoints(control), 9, "About Close button")
        }
    } finally {
        AboutGui.Destroy()
        AboutGui := ""
    }
}

Test_AddStep1_ListsFiveTypesWithIconsAndHints() {
    static BM_GETIMAGE := 0xF6, IMAGE_ICON := 1
    SetUpLauncher(3)
    AddFavorite()
    try {
        buttons := Map()
        for control in EditorGui {
            if control.Type = "Button"
                buttons[control.Text] := control
        }
        choices := [["&Folder...", "folder"], ["&Document...", "document"], ["&Program...", "program"],
            ["&Web address", "link"], ["&Command", "command"]]
        previousY := -1
        for choice in choices {
            AssertTrue(buttons.Has(choice[1]), "has button " choice[1])
            button := buttons[choice[1]]
            image := SendMessage(BM_GETIMAGE, IMAGE_ICON, 0, button)
            AssertTrue(image != 0, choice[1] " shows an icon")
            AssertEqual(image, GetTypeIcon(choice[2]), choice[1] " shows the " choice[2] " icon")
            button.GetPos(, &buttonY)
            AssertTrue(buttonY > previousY, choice[1] " is below the previous choice (one per row)")
            previousY := buttonY
        }
        allText := GetGuiText(EditorGui)
        AssertTrue(InStr(allText, "ipconfig /all"), "Command has an example hint")
        AssertTrue(InStr(allText, "example.com"), "Web address has an example hint")
    } finally {
        CloseEditor()
    }
}

Test_AddStep1_CommandGoesToStep2WithKeepOpen() {
    SetUpLauncher(3)
    AddFavorite()
    WatchForDialog()
    ChooseAddType("command")
    try {
        AssertEqual(DialogOwner, 0, "no picker for a command")
        allText := GetGuiText(EditorGui)
        AssertTrue(InStr(allText, "Command`n"), "location is labelled 'Command'")
        AssertFalse(InStr(allText, "Change..."), "no Change... button for a command")
        AssertEqual(EditorTarget.Value, "", "command starts empty")
        AssertEqual(EditorKeepOpen.Text, "Keep window open to show output", "checkbox label")
        AssertEqual(EditorKeepOpen.Value, 1, "keeps the window open by default")

        EditorTarget.Value := "ipconfig /all"
        SuggestEditorName()
        EditorKeepOpen.Value := 0
        SaveEditor()
        added := FindFavoriteByName("ipconfig /all")
        AssertTrue(IsObject(added), "command favorite added")
        AssertEqual(added.Type "|" added.Target "|" added.KeepOpen, "command|ipconfig /all|0", "saved command")
    } finally {
        CloseEditor()
    }
}

Test_Edit_CommandShowsSavedKeepOpen() {
    global Favorites
    SetUpLauncher(0)
    Favorites := [MakeFavorite("Ping", "ping localhost", "command", "", false)]
    OpenEditor(1)
    try AssertEqual(EditorKeepOpen.Value, 0, "checkbox shows the saved choice")
    finally CloseEditor()
}

Test_Command_SaveAndLoadKeepsKeepOpen() {
    global Favorites
    Favorites := [
        MakeFavorite("Hidden", "echo hi", "command", "", false),
        MakeFavorite("Shown", "ipconfig", "command", "", true)
    ]
    SaveFavorites()
    Favorites := []
    LoadFavorites()
    AssertEqual(Favorites.Length, 2, "count")
    AssertEqual(Favorites[1].Type "|" Favorites[1].KeepOpen, "command|0", "Hidden runs without a window")
    AssertEqual(Favorites[2].Type "|" Favorites[2].KeepOpen, "command|1", "Shown keeps its window")
}

Test_Command_RunLineUsesCmd() {
    AssertEqual(GetCommandRunLine('git status', true), A_ComSpec ' /k "git status"', "keep open uses /k")
    AssertEqual(GetCommandRunLine('"C:\My Tools\x.exe" -v', false), A_ComSpec ' /c ""C:\My Tools\x.exe" -v"',
        "run and close uses /c, quotes kept")
}

Test_GetDefaultName_FromCommand() {
    AssertEqual(GetDefaultName("ipconfig /all", "command"), "ipconfig /all", "short command")
    long := "powershell -NoProfile -Command Get-ChildItem C:\Temp -Recurse"
    name := GetDefaultName(long, "command")
    AssertTrue(StrLen(name) <= 40, "long command shortened (" StrLen(name) " chars)")
    AssertTrue(StartsWith(name, "powershell -NoProfile"), "starts like the command")
}

; ---------------------------------------------------------------------------
; Tray menu

Test_TrayMenu_ItemsAndSingleClickOpens() {
    ConfigureTrayMenu()
    AssertEqual(GetMenuItemNames(A_TrayMenu.Handle), "Open launcher|-|Start with Windows|-|What's new|About|-|Exit",
        "tray menu items")
    AssertEqual(DllCall("GetMenuDefaultItem", "Ptr", A_TrayMenu.Handle, "UInt", 1, "UInt", 0, "Int"), 0,
        "Open launcher is the default (bold) item")
    AssertEqual(A_TrayMenu.ClickCount, 1, "a single click on the tray icon opens the launcher")
    AssertTrue(InStr(ChangelogUrl, "github.com/kennethaar/FavoriteLauncher") && InStr(ChangelogUrl, "CHANGELOG.md"),
        "What's new opens the changelog on GitHub: " ChangelogUrl)
}

; ---------------------------------------------------------------------------
; Start with Windows (uses a temporary startup folder, never the real one)

Test_StartWithWindows_TrayItemTogglesShortcut() {
    UseTestStartupFolder()
    ConfigureTrayMenu()
    AssertFalse(IsTrayItemChecked("Start with Windows"), "unchecked when there is no startup shortcut")

    ToggleStartWithWindows()
    AssertTrue(FileExist(StartupShortcut), "shortcut created in the startup folder")
    AssertTrue(IsTrayItemChecked("Start with Windows"), "checked after turning it on")
    FileGetShortcut(StartupShortcut, &target, , &arguments)
    AssertEqual(target, A_AhkPath, "script version starts through AutoHotkey")
    AssertTrue(InStr(arguments, AppDir "\FavoriteLauncher.ahk"), "and runs FavoriteLauncher.ahk: " arguments)

    ToggleStartWithWindows()
    AssertFalse(FileExist(StartupShortcut), "shortcut removed")
    AssertFalse(IsTrayItemChecked("Start with Windows"), "unchecked after turning it off")
}

Test_Welcome_StartWithWindowsCheckedByDefault() {
    UseTestStartupFolder()
    SetUpLauncher(3)
    ShowWelcome()
    try {
        AssertEqual(WelcomeGui.Title, "Welcome to Favorite Launcher", "window title")
        AssertTrue(InStr(GetGuiText(WelcomeGui), "Ctrl+Alt+Space"), "tells how to open the launcher")
        AssertEqual(WelcomeStartup.Text, "Start with Windows", "checkbox label")
        AssertEqual(WelcomeStartup.Value, 1, "checked by default")
        AssertEqual(GetWindowIcon(WelcomeGui, "small"), GetAppIcon("small"), "welcome window icon")
        AssertEqual(GetFontPoints(WelcomeStartup), 9, "9pt font")
    } finally {
        WelcomeClose()
    }
    AssertTrue(FileExist(StartupShortcut), "closing with the box checked turns it on")
}

Test_Welcome_UncheckedRemovesShortcut() {
    UseTestStartupFolder()
    SetStartWithWindows(true)
    SetUpLauncher(3)
    ShowWelcome()
    WelcomeStartup.Value := 0
    WelcomeOpenLauncher()
    try {
        AssertFalse(FileExist(StartupShortcut), "unchecked turns it off")
        AssertTrue(DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd), "Open launcher shows the launcher")
    } finally {
        MainGui.Hide()
    }
}

; ---------------------------------------------------------------------------
; Update banner (no network: the GitHub answer is passed in)

Test_CompareVersions_ComparesEachNumber() {
    AssertEqual(CompareVersions("1.10.0", "1.9.0"), 1, "1.10.0 is newer than 1.9.0")
    AssertEqual(CompareVersions("1.3.0", "1.3.0"), 0, "same version")
    AssertEqual(CompareVersions("1.2.9", "1.3.0"), -1, "1.2.9 is older than 1.3.0")
    AssertEqual(CompareVersions("2.0", "1.9.9"), 1, "missing parts count as 0")
}

Test_ParseLatestRelease_ReadsVersionAndUrl() {
    json := '{"url":"x","html_url":"https://github.com/kennethaar/FavoriteLauncher/releases/tag/v1.4.0",'
        . '"tag_name":"v1.4.0","name":"1.4.0"}'
    release := ParseLatestRelease(json)
    AssertEqual(release.Version, "1.4.0", "version without the v")
    AssertEqual(release.Url, "https://github.com/kennethaar/FavoriteLauncher/releases/tag/v1.4.0", "release notes page")
    AssertEqual(ParseLatestRelease('{"message":"Not Found"}').Version, "", "no release")
}

Test_ShouldShowUpdate_OnlyNewerAndNotDismissed() {
    global ConfigFile
    try IniDelete(ConfigFile, "Settings", "DismissedUpdate")
    AssertFalse(ShouldShowUpdate(""), "no answer from GitHub")
    AssertFalse(ShouldShowUpdate(AppVersion), "same version as running")
    AssertTrue(ShouldShowUpdate("99.0.0"), "newer version")
    IniWrite("99.0.0", ConfigFile, "Settings", "DismissedUpdate")
    AssertFalse(ShouldShowUpdate("99.0.0"), "dismissed version stays hidden")
    AssertTrue(ShouldShowUpdate("99.1.0"), "an even newer version shows again")
    IniDelete(ConfigFile, "Settings", "DismissedUpdate")
}

Test_UpdateBanner_ShowsAboveSearch() {
    SetUpLauncher(3)
    SearchBox.GetPos(, &searchYBefore)
    AssertFalse(IsVisibleControl(UpdateBannerText), "no banner before an update is found")

    ShowUpdateBanner("99.0.0", "https://example.com/release")
    MainGui.Show("AutoSize Hide")
    AssertTrue(IsVisibleControl(UpdateBannerText), "banner shown")
    AssertTrue(InStr(UpdateBannerText.Text, "Version 99.0.0 is available"), "says which version: " UpdateBannerText.Text)
    AssertEqual(UpdateBannerLink.Text, "What's new", "link text")
    AssertTrue(IsVisibleControl(UpdateBannerClose), "close button shown")
    UpdateBannerText.GetPos(, &bannerY, , &bannerHeight)
    SearchBox.GetPos(, &searchY)
    AssertTrue(searchY >= bannerY + bannerHeight, "search box is below the banner")
    AssertTrue(searchY > searchYBefore, "search box moved down")
    AssertTrue(RowsThatFit() >= 3, "all favorites still visible (fits " RowsThatFit() ")")
}

Test_UpdateBanner_DismissHidesIt() {
    global ConfigFile
    SetUpLauncher(3)
    SearchBox.GetPos(, &searchYBefore)
    ShowUpdateBanner("99.0.0", "https://example.com/release")
    DismissUpdateBanner()
    try {
        AssertFalse(IsVisibleControl(UpdateBannerText), "banner hidden")
        SearchBox.GetPos(, &searchY)
        AssertEqual(searchY, searchYBefore, "search box back at the top")
        AssertEqual(IniRead(ConfigFile, "Settings", "DismissedUpdate", ""), "99.0.0", "dismissed version remembered")
    } finally {
        try IniDelete(ConfigFile, "Settings", "DismissedUpdate")
    }
}

; ---------------------------------------------------------------------------
; Helpers

IsVisibleControl(control) {
    static WS_VISIBLE := 0x10000000
    return (ControlGetStyle(control) & WS_VISIBLE) != 0
}

UseTestStartupFolder() {
    global StartupShortcut, TestDir
    DirCreate(TestDir "\Startup")
    StartupShortcut := TestDir "\Startup\FavoriteLauncher.lnk"
    try FileDelete(StartupShortcut)
}

IsTrayItemChecked(itemName) {
    static MF_BYPOSITION := 0x400, MF_CHECKED := 0x8
    names := StrSplit(GetMenuItemNames(A_TrayMenu.Handle), "|")
    for index, name in names {
        if name = itemName
            return (DllCall("GetMenuState", "Ptr", A_TrayMenu.Handle, "UInt", index - 1, "UInt", MF_BYPOSITION, "UInt") & MF_CHECKED) != 0
    }
    throw Error("No tray item named " itemName)
}

; Menu item texts joined by "|"; separators are "-".
GetMenuItemNames(menuHandle) {
    names := []
    loop DllCall("GetMenuItemCount", "Ptr", menuHandle, "Int") {
        length := DllCall("GetMenuStringW", "Ptr", menuHandle, "UInt", A_Index - 1, "Ptr", 0, "Int", 0, "UInt", 0x400, "Int")
        text := Buffer((length + 1) * 2, 0)
        DllCall("GetMenuStringW", "Ptr", menuHandle, "UInt", A_Index - 1, "Ptr", text, "Int", length + 1, "UInt", 0x400)
        name := StrGet(text, "UTF-16")
        names.Push(name = "" ? "-" : name)
    }
    result := ""
    for name in names
        result .= (A_Index > 1 ? "|" : "") name
    return result
}

; Font size in points that a control is drawn with.
GetFontPoints(control) {
    static WM_GETFONT := 0x31
    fontHandle := SendMessage(WM_GETFONT, 0, 0, control)
    logFont := Buffer(92, 0)
    DllCall("GetObjectW", "Ptr", fontHandle, "Int", 92, "Ptr", logFont)
    return Round(Abs(NumGet(logFont, 0, "Int")) * 72 / A_ScreenDPI)
}

; All control texts of a window, one per line.
GetGuiText(guiObj) {
    allText := ""
    for control in guiObj {
        try allText .= control.Text "`n"
    }
    return allText
}

CountControls(guiObj, controlType) {
    count := 0
    for control in guiObj {
        if control.Type = controlType
            count += 1
    }
    return count
}

FindFavoriteByName(name) {
    global Favorites
    for favorite in Favorites {
        if favorite.Name = name
            return favorite
    }
    return ""
}

MakeFavorite(name, target, type := "folder", hotkeyValue := "", keepOpen := true) {
    return {Name: name, Target: target, Type: type, Hotkey: hotkeyValue, KeepOpen: keepOpen}
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
        global DialogText
        DialogText := WinGetText(dialog)
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
