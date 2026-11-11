#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetVersion 1.2.0
;@Ahk2Exe-SetMainIcon FavoriteLauncher.ico
;@Ahk2Exe-SetDescription FavoriteLauncher
;@Ahk2Exe-SetProductName FavoriteLauncher

SendMode("Input")

; Semantic version (MAJOR.MINOR.PATCH). Keep in sync with ;@Ahk2Exe-SetVersion and CHANGELOG.md.
global AppVersion := "1.2.0"

; Folder of this file, also when the test suite includes it from tests\.
global AppDir := A_IsCompiled ? A_ScriptDir : RegExReplace(A_LineFile, "\\[^\\]+$")
global ConfigFile := AppDir "\FavoriteLauncher.ini"
global Favorites := []
global VisibleFavorites := []
global RegisteredHotkeys := Map()
global MainGui := "", SearchBox := "", FavoritesList := "", FooterText := ""
global AddButton := "", ListRowHeight := 0
global AboutGui := ""
global EditorGui := "", EditorName := "", EditorTypeValue := "folder", EditorTarget := ""
global EditorHotkey := "", EditorShortcutStatus := "", EditorAutoName := "", EditorReplacedGui := ""
global EditingIndex := 0, SelectedRow := 0
global FavoriteImageList := 0, IconCache := Map()
global AppIconFile := AppDir "\FavoriteLauncher.ico"

; Start only when run directly. The test suite includes this file without starting the app.
if A_IsCompiled || A_LineFile = A_ScriptFullPath
    StartLauncher()

^!Space::ShowLauncher()

StartLauncher() {
    global AppDir, AppIconFile

    SetWorkingDir(AppDir)

    if FileExist(AppIconFile) {
        try TraySetIcon(AppIconFile)
        catch Error as err
            TrayTip("Could not load FavoriteLauncher.ico:`n" err.Message, "Favorite Launcher", "Iconx")
    }

    A_IconTip := "Favorite Launcher " AppVersion

    ConfigureTrayMenu()
    LoadFavorites()
    RegisterAllHotkeys()
    CreateMainGui()
    ShowOnboardingIfNeeded()
}

ConfigureTrayMenu() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Open", ShowLauncher)
    A_TrayMenu.Default := "Open"
    A_TrayMenu.Add()
    A_TrayMenu.Add("About", ShowAbout)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit", ExitLauncher)
}

ShowAbout(*) {
    global AboutGui

    if IsObject(AboutGui) {
        try {
            AboutGui.Show("AutoSize Center")
            return
        }
    }

    AboutGui := Gui(
        "+AlwaysOnTop -MaximizeBox -MinimizeBox",
        "About Favorite Launcher"
    )
    AboutGui.SetFont("s10", "Segoe UI")
    AboutGui.MarginX := 22
    AboutGui.MarginY := 20

    AboutGui.SetFont("s15 w600", "Segoe UI")
    AboutGui.AddText("xm ym", "Favorite Launcher")

    AboutGui.SetFont("s10 norm", "Segoe UI")
    AboutGui.AddText("xm y+2 c666666", "Version " AppVersion)
    AboutGui.AddText(
        "xm y+12 w380",
        "Open folders, files, programs and websites without searching through menus."
    )
    AboutGui.AddText(
        "xm y+16 w380",
        "Ctrl+Alt+Space  Open launcher`n"
        "Type  Find a favorite`n"
        "Enter  Open selected favorite`n"
        "F2  Edit selected favorite`n"
        "Delete  Remove selected favorite"
    )
    AboutGui.AddText(
        "xm y+16 w380 c666666",
        "Favorites are stored locally in FavoriteLauncher.ini."
    )

    closeButton := AboutGui.AddButton("xm y+20 w90 h30 Default", "Close")
    closeButton.OnEvent("Click", CloseAbout)
    AboutGui.OnEvent("Escape", CloseAbout)
    AboutGui.OnEvent("Close", CloseAbout)
    SetWindowIcon(AboutGui)
    AboutGui.Show("AutoSize Center")
}

CloseAbout(*) {
    global AboutGui
    if IsObject(AboutGui)
        AboutGui.Hide()
}

ExitLauncher(*) {
    ExitApp()
}

CreateMainGui() {
    global MainGui, SearchBox, FavoritesList, FooterText, FavoriteImageList, AddButton

    MainGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", "FavoriteLauncher")
    MainGui.SetFont("s10", "Segoe UI")
    MainGui.MarginX := 14
    MainGui.MarginY := 14

    SearchBox := MainGui.AddEdit("xm ym w540 h34")
    SetEditPlaceholder(SearchBox, "Type to search...")
    SearchBox.OnEvent("Change", FilterFavorites)

    FavoritesList := MainGui.AddListView(
        "xm y+9 w540 h370 -Multi NoSortHdr +LV0x20",
        ["Name", "Shortcut"]
    )
    FavoritesList.ModifyCol(1, 375)
    FavoritesList.ModifyCol(2, 135)

    FavoriteImageList := IL_Create(10, 10, false)
    FavoritesList.SetImageList(FavoriteImageList, 1)
    FavoritesList.OnEvent("Click", ListItemClicked)
    FavoritesList.OnEvent("DoubleClick", OpenSelected)
    FavoritesList.OnEvent("ItemFocus", ListItemFocused)
    FavoritesList.OnEvent("ContextMenu", ShowItemContextMenu)

    AddButton := MainGui.AddButton("xm y+10 w90 h30", "+ Add")
    AddButton.OnEvent("Click", AddFavorite)

    FooterText := MainGui.AddText(
        "x+12 yp+6 w430 c666666 Right",
        "Enter to open"
    )

    MainGui.OnEvent("Escape", HideLauncher)
    MainGui.OnEvent("Close", HideLauncher)
    SetWindowIcon(MainGui)
}

; Puts FavoriteLauncher.ico on a window's title bar and taskbar button.
SetWindowIcon(guiObj) {
    static WM_SETICON := 0x80, ICON_SMALL := 0, ICON_BIG := 1

    smallIcon := GetAppIcon("small")
    if !smallIcon
        return

    ; DllCall instead of SendMessage(): the window may still be hidden.
    DllCall("SendMessageW", "Ptr", guiObj.Hwnd, "UInt", WM_SETICON, "Ptr", ICON_SMALL, "Ptr", smallIcon)
    DllCall("SendMessageW", "Ptr", guiObj.Hwnd, "UInt", WM_SETICON, "Ptr", ICON_BIG, "Ptr", GetAppIcon("big"))
}

; Icon handle from FavoriteLauncher.ico at the system size ("small" or "big"); 0 if it cannot be loaded.
; Loaded once and kept for the life of the app, because windows keep using the handle.
GetAppIcon(size) {
    global AppIconFile
    static icons := Map()

    if icons.Has(size)
        return icons[size]

    width := size = "small" ? SysGet(49) : SysGet(11)
    height := size = "small" ? SysGet(50) : SysGet(12)
    handle := 0
    ; Passing &imageType keeps the result an icon instead of a bitmap.
    if FileExist(AppIconFile)
        try handle := LoadPicture(AppIconFile, "w" width " h" height, &imageType)

    icons[size] := handle
    return handle
}

; Sizes the list to fit all favorites, capping the window at 80% of the screen height.
FitListToFavorites() {
    global MainGui, FavoritesList, AddButton, FooterText, Favorites, ListRowHeight
    static LVM_GETHEADER := 0x101F, LVM_GETITEMRECT := 0x100E
    static MinRows := 3, GapBelowList := 10, ButtonHeight := 30

    scale := A_ScreenDPI / 96

    ; Row height in pixels; measured from the first row and remembered.
    if FavoritesList.GetCount() > 0 {
        itemRect := Buffer(16, 0)
        if SendMessage(LVM_GETITEMRECT, 0, itemRect.Ptr, FavoritesList)
            ListRowHeight := NumGet(itemRect, 12, "Int") - NumGet(itemRect, 4, "Int")
    }
    rowHeight := ListRowHeight > 0 ? ListRowHeight : Round(20 * scale)

    headerHeight := 0
    headerHwnd := SendMessage(LVM_GETHEADER, 0, 0, FavoritesList)
    if headerHwnd
        headerHeight := GetWindowHeight(headerHwnd)

    borderHeight := GetWindowHeight(FavoritesList.Hwnd) - GetClientHeight(FavoritesList.Hwnd)
    rows := Max(Favorites.Length, MinRows)
    wantedPx := borderHeight + headerHeight + rows * rowHeight

    ; Everything in the window that is not the list, in pixels.
    FavoritesList.GetPos(, &listY)
    frameHeight := GetFrameHeight(MainGui.Hwnd)
    otherPx := frameHeight + Round((listY + GapBelowList + ButtonHeight + MainGui.MarginY) * scale)
    maxListPx := Floor(A_ScreenHeight * 0.8) - otherPx - Ceil(scale)
    minListPx := borderHeight + headerHeight + MinRows * rowHeight

    listHeight := Ceil(Max(minListPx, Min(wantedPx, maxListPx)) / scale)

    FavoritesList.GetPos(, , , &currentHeight)
    if currentHeight = listHeight
        return

    FavoritesList.Move(, , , listHeight)
    buttonY := listY + listHeight + GapBelowList
    AddButton.Move(, buttonY)
    FooterText.Move(, buttonY + 6)

    if DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd)
        MainGui.Show("AutoSize NA")
}

GetWindowHeight(hwnd) {
    rect := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect.Ptr)
    return NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
}

; Title bar + borders, from the window style (works before the window is first shown).
GetFrameHeight(hwnd) {
    static GWL_STYLE := -16, GWL_EXSTYLE := -20
    rect := Buffer(16, 0)
    style := DllCall("GetWindowLongPtrW", "Ptr", hwnd, "Int", GWL_STYLE, "Ptr")
    exStyle := DllCall("GetWindowLongPtrW", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr")
    DllCall("AdjustWindowRectEx", "Ptr", rect.Ptr, "UInt", style, "Int", false, "UInt", exStyle)
    return NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
}

GetClientHeight(hwnd) {
    rect := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rect.Ptr)
    return NumGet(rect, 12, "Int")
}

SetEditPlaceholder(editControl, placeholder) {
    static EM_SETCUEBANNER := 0x1501
    try DllCall(
        "SendMessageW",
        "Ptr", editControl.Hwnd,
        "UInt", EM_SETCUEBANNER,
        "Ptr", true,
        "Str", placeholder
    )
}

ShowLauncher(*) {
    global MainGui, SearchBox
    SearchBox.Value := ""
    RefreshList()
    MainGui.Show("AutoSize Center")
    SearchBox.Focus()
}

HideLauncher(*) {
    global MainGui
    MainGui.Hide()
}

FilterFavorites(*) {
    global SearchBox
    RefreshList(SearchBox.Value)
}

RefreshList(filter := "") {
    global Favorites, VisibleFavorites, FavoritesList, SelectedRow

    VisibleFavorites := []
    FavoritesList.Delete()
    filter := StrLower(Trim(filter))
    rankedItems := []

    for originalIndex, favorite in Favorites {
        rank := GetMatchRank(favorite, filter)
        if rank < 100 {
            rankedItems.Push({
                Rank: rank,
                OriginalIndex: originalIndex,
                Favorite: favorite
            })
        }
    }

    SortRankedItems(rankedItems)

    for item in rankedItems {
        favorite := item.Favorite
        iconNumber := GetFavoriteIcon(favorite)
        VisibleFavorites.Push({
            OriginalIndex: item.OriginalIndex,
            Favorite: favorite
        })
        FavoritesList.Add(
            "Icon" iconNumber,
            favorite.Name,
            DisplayHotkey(favorite.Hotkey)
        )
    }

    if VisibleFavorites.Length > 0 {
        SelectedRow := 1
        UpdateSelectedRow()
    } else {
        SelectedRow := 0
    }

    UpdateFooter()
    FitListToFavorites()
}

GetMatchRank(favorite, filter) {
    if filter = ""
        return 10

    name := StrLower(favorite.Name)
    target := StrLower(favorite.Target)
    hotkeyText := StrLower(DisplayHotkey(favorite.Hotkey))

    if StartsWith(name, filter)
        return 1

    words := StrSplit(RegExReplace(name, "[^a-z0-9æøå]+", " "), " ")
    for word in words {
        if word != "" && StartsWith(word, filter)
            return 2
    }

    if InStr(name, filter)
        return 3
    if InStr(target, filter)
        return 4
    if InStr(hotkeyText, filter)
        return 5

    return 100
}

StartsWith(text, prefix) {
    return prefix = "" || SubStr(text, 1, StrLen(prefix)) = prefix
}

SortRankedItems(items) {
    if items.Length < 2
        return

    itemIndex := 2
    while itemIndex <= items.Length {
        currentItem := items[itemIndex]
        compareIndex := itemIndex - 1

        while compareIndex >= 1 {
            previousItem := items[compareIndex]
            if !RankedItemComesBefore(currentItem, previousItem)
                break
            items[compareIndex + 1] := previousItem
            compareIndex -= 1
        }

        items[compareIndex + 1] := currentItem
        itemIndex += 1
    }
}

RankedItemComesBefore(firstItem, secondItem) {
    if firstItem.Rank < secondItem.Rank
        return true
    if firstItem.Rank > secondItem.Rank
        return false
    return StrCompare(firstItem.Favorite.Name, secondItem.Favorite.Name) < 0
}

GetFavoriteIcon(favorite) {
    global IconCache
    cacheKey := GetIconCacheKey(favorite)

    if IconCache.Has(cacheKey)
        return IconCache[cacheKey]

    iconNumber := AddShellIcon(favorite.Target, favorite.Type)
    if iconNumber <= 0
        iconNumber := AddFallbackIcon(favorite.Type)

    IconCache[cacheKey] := iconNumber
    return iconNumber
}

GetIconCacheKey(favorite) {
    if favorite.Type = "folder"
        return "folder"
    if favorite.Type = "link"
        return "link"

    SplitPath(favorite.Target, , , &extension)
    extension := StrLower(extension)
    return extension != ""
        ? favorite.Type ":" extension
        : favorite.Type ":" StrLower(favorite.Target)
}

AddShellIcon(target, type) {
    global FavoriteImageList

    static SHGFI_ICON := 0x100
    static SHGFI_SMALLICON := 0x1
    static SHGFI_USEFILEATTRIBUTES := 0x10
    static FILE_ATTRIBUTE_NORMAL := 0x80
    static FILE_ATTRIBUTE_DIRECTORY := 0x10

    shellTarget := target
    fileAttributes := FILE_ATTRIBUTE_NORMAL
    flags := SHGFI_ICON | SHGFI_SMALLICON

    if type = "folder" {
        fileAttributes := FILE_ATTRIBUTE_DIRECTORY
        if !DirExist(target)
            flags |= SHGFI_USEFILEATTRIBUTES
    } else if type = "link" {
        shellTarget := "FavoriteLauncher.url"
        flags |= SHGFI_USEFILEATTRIBUTES
    } else if !FileExist(target) {
        flags |= SHGFI_USEFILEATTRIBUTES
    }

    structureSize := A_PtrSize = 8 ? 696 : 692
    shellFileInfo := Buffer(structureSize, 0)

    result := DllCall(
        "Shell32\SHGetFileInfoW",
        "WStr", shellTarget,
        "UInt", fileAttributes,
        "Ptr", shellFileInfo.Ptr,
        "UInt", structureSize,
        "UInt", flags,
        "UPtr"
    )

    if result = 0
        return 0

    iconHandle := NumGet(shellFileInfo, 0, "Ptr")
    if !iconHandle
        return 0

    iconNumber := 0
    try iconNumber := IL_Add(FavoriteImageList, "HICON:" iconHandle)
    finally DllCall("DestroyIcon", "Ptr", iconHandle)

    return iconNumber
}

AddFallbackIcon(type) {
    global FavoriteImageList

    switch type {
        case "folder": iconNumber := 4
        case "link": iconNumber := 14
        case "program": iconNumber := 3
        default: iconNumber := 1
    }

    try return IL_Add(
        FavoriteImageList,
        A_WinDir "\System32\shell32.dll",
        iconNumber
    )
    catch
        return IL_Add(FavoriteImageList, A_AhkPath)
}

ClearIconCache() {
    global IconCache
    IconCache := Map()
}

ListItemClicked(listView, row) {
    global SelectedRow
    if row = 0
        return
    SelectedRow := row
    UpdateSelectedRow()
    UpdateFooter()
}

ListItemFocused(listView, row) {
    global SelectedRow
    if row = 0
        return
    SelectedRow := row
    UpdateSelectedRow()
    UpdateFooter()
}

UpdateSelectedRow() {
    global FavoritesList, VisibleFavorites, SelectedRow
    if VisibleFavorites.Length = 0
        return

    SelectedRow := Max(1, Min(SelectedRow, VisibleFavorites.Length))
    FavoritesList.Modify(0, "-Select -Focus")
    FavoritesList.Modify(SelectedRow, "Select Focus Vis")
}

MoveSelection(direction) {
    global VisibleFavorites, SelectedRow
    if VisibleFavorites.Length = 0
        return

    SelectedRow += direction
    if SelectedRow < 1
        SelectedRow := VisibleFavorites.Length
    if SelectedRow > VisibleFavorites.Length
        SelectedRow := 1

    UpdateSelectedRow()
    UpdateFooter()
}

GetSelectedOriginalIndex() {
    global VisibleFavorites, SelectedRow
    if SelectedRow < 1 || SelectedRow > VisibleFavorites.Length
        return 0
    return VisibleFavorites[SelectedRow].OriginalIndex
}

UpdateFooter(*) {
    global VisibleFavorites, SelectedRow, FooterText

    if VisibleFavorites.Length = 0 {
        FooterText.Text := "No matches"
        return
    }

    SelectedRow := Max(1, Min(SelectedRow, VisibleFavorites.Length))
    favorite := VisibleFavorites[SelectedRow].Favorite
    FooterText.Text := TypeToLabel(favorite.Type) "  |  Enter to open"
}

OpenSelected(*) {
    global MainGui
    index := GetSelectedOriginalIndex()
    if index = 0
        return
    MainGui.Hide()
    OpenFavoriteByIndex(index)
}

OpenFavoriteByIndex(index, *) {
    global Favorites
    if index < 1 || index > Favorites.Length
        return

    favorite := Favorites[index]
    try {
        switch favorite.Type {
            case "folder": OpenFolder(favorite.Target)
            case "document", "program": OpenFile(favorite.Target)
            case "link": OpenLink(favorite.Target)
            default: Run(favorite.Target)
        }
    } catch Error as err {
        MsgBox(
            "Could not open:`n`n" favorite.Target "`n`n" err.Message,
            "Favorite Launcher",
            "Iconx 0x40000"
        )
    }
}

OpenFolder(path) {
    if !DirExist(path) {
        MsgBox("The folder does not exist:`n`n" path, "Favorite Launcher", "Iconx 0x40000")
        return
    }

    if NavigateFileDialog(path)
        return
    Run(path)
}

OpenFile(path) {
    if !FileExist(path) {
        MsgBox("The file does not exist:`n`n" path, "Favorite Launcher", "Iconx 0x40000")
        return
    }
    Run(path)
}

OpenLink(url) {
    if !RegExMatch(url, "i)^[a-z][a-z0-9+.-]*://")
        url := "https://" url
    Run(url)
}

NavigateFileDialog(path) {
    if !WinActive("ahk_class #32770")
        return false

    try {
        ControlSetText(path, "Edit1", "A")
        ControlSend("{Enter}", "Edit1", "A")
        return true
    } catch {
        return false
    }
}

AddFavorite(*) {
    ShowAddStep1()
}

EditSelected(*) {
    index := GetSelectedOriginalIndex()
    if index != 0
        OpenEditor(index)
}

; The Edit window for Favorites[index].
OpenEditor(index) {
    global Favorites
    favorite := Favorites[index]
    ShowDetailsStep(index, {
        Name: favorite.Name,
        Target: favorite.Target,
        Type: favorite.Type,
        Hotkey: favorite.Hotkey
    })
}

; Add favorite, step 1: what to add. Choosing a type opens its picker right away.
ShowAddStep1(*) {
    global EditorGui, EditingIndex
    static ButtonWidth := 150, Gap := 10

    EditingIndex := 0
    CreateEditorWindow("Add favorite")

    EditorGui.AddText("xm ym c666666", "Step 1 of 2")
    EditorGui.SetFont("s12 w600")
    EditorGui.AddText("xm y+2", "What do you want to add?")
    EditorGui.SetFont("s10 norm")

    folderButton := EditorGui.AddButton("xm y+14 w" ButtonWidth " h34", "&Folder...")
    folderButton.OnEvent("Click", ChooseAddType.Bind("folder"))
    documentButton := EditorGui.AddButton("x+" Gap " yp w" ButtonWidth " h34", "&Document...")
    documentButton.OnEvent("Click", ChooseAddType.Bind("document"))
    programButton := EditorGui.AddButton("xm y+" Gap " w" ButtonWidth " h34", "&Program...")
    programButton.OnEvent("Click", ChooseAddType.Bind("program"))
    linkButton := EditorGui.AddButton("x+" Gap " yp w" ButtonWidth " h34", "&Web address")
    linkButton.OnEvent("Click", ChooseAddType.Bind("link"))

    cancelX := EditorGui.MarginX + 2 * ButtonWidth + Gap - 90
    cancelButton := EditorGui.AddButton("x" cancelX " y+20 w90 h30", "Cancel")
    cancelButton.OnEvent("Click", CloseEditor)

    ShowEditorWindow()
    folderButton.Focus()
}

ChooseAddType(type, *) {
    if type = "link" {
        ContinueWithTarget("link", "")
        return
    }

    target := PickTarget(type)
    if target != ""
        ContinueWithTarget(type, target)
}

; Add favorite, step 2, for the chosen location.
ContinueWithTarget(type, target) {
    name := target = "" ? "" : GetDefaultName(target, type)
    ShowDetailsStep(0, {Name: name, Target: target, Type: type, Hotkey: ""})
}

GoBackToStep1(*) {
    ShowAddStep1()
}

; Add step 2 (index = 0) or the Edit window: location, then name, then shortcut.
ShowDetailsStep(index, draft) {
    global EditorGui, EditorName, EditorTarget, EditorHotkey, EditorShortcutStatus
    global EditorTypeValue, EditorAutoName, EditingIndex
    static FieldWidth := 470, ButtonWidth := 90, Gap := 8

    isAdding := index = 0
    EditingIndex := index
    EditorTypeValue := draft.Type
    ; The name follows the location until the user types a name of their own.
    EditorAutoName := draft.Name = GetDefaultName(draft.Target, draft.Type) ? draft.Name : ""

    CreateEditorWindow(isAdding ? "Add favorite" : "Edit favorite")

    if isAdding
        EditorGui.AddText("xm ym c666666", "Step 2 of 2")
    EditorGui.AddText(isAdding ? "xm y+8" : "xm ym", TypeToLabel(draft.Type))
    if draft.Type = "link" {
        EditorTarget := EditorGui.AddEdit("xm y+5 w" FieldWidth " h30", draft.Target)
        SetEditPlaceholder(EditorTarget, "example.com")
    } else {
        EditorTarget := EditorGui.AddEdit("xm y+5 w" (FieldWidth - 92 - Gap) " h30", draft.Target)
        changeButton := EditorGui.AddButton("x+" Gap " yp w92 h30", "Change...")
        changeButton.OnEvent("Click", BrowseEditorTarget)
    }
    EditorTarget.OnEvent("Change", SuggestEditorName)

    EditorGui.AddText("xm y+14", "Name")
    EditorName := EditorGui.AddEdit("xm y+5 w" FieldWidth " h30", draft.Name)

    EditorGui.AddText("xm y+14", "Direct shortcut (optional)")
    EditorHotkey := EditorGui.AddHotkey("xm y+5 w220 h30")
    EditorHotkey.Value := draft.Hotkey
    EditorHotkey.OnEvent("Change", ResetShortcutStatus)
    testButton := EditorGui.AddButton("x+" Gap " yp w" ButtonWidth " h30", "Test")
    testButton.OnEvent("Click", TestEditorShortcut)
    clearButton := EditorGui.AddButton("x+" Gap " yp w" ButtonWidth " h30", "Clear")
    clearButton.OnEvent("Click", ClearEditorShortcut)
    EditorShortcutStatus := EditorGui.AddText("xm y+8 w" FieldWidth " r2 c666666")
    ResetShortcutStatus()

    buttonCount := isAdding ? 3 : 2
    firstX := EditorGui.MarginX + FieldWidth - buttonCount * ButtonWidth - (buttonCount - 1) * Gap
    if isAdding {
        backButton := EditorGui.AddButton("x" firstX " y+14 w" ButtonWidth " h32", "< Back")
        backButton.OnEvent("Click", GoBackToStep1)
        saveButton := EditorGui.AddButton("x+" Gap " yp w" ButtonWidth " h32 Default", "Add")
    } else {
        saveButton := EditorGui.AddButton("x" firstX " y+14 w" ButtonWidth " h32 Default", "Save")
    }
    saveButton.OnEvent("Click", SaveEditor)
    cancelButton := EditorGui.AddButton("x+" Gap " yp w" ButtonWidth " h32", "Cancel")
    cancelButton.OnEvent("Click", CloseEditor)

    ShowEditorWindow()
    if draft.Target = "" {
        EditorTarget.Focus()
        return
    }
    EditorName.Focus()
    SendMessage(0xB1, 0, -1, EditorName)    ; EM_SETSEL: select the name so typing replaces it
}

; Starts a new editor window. The previous one stays until the new one is shown,
; so focus never falls to another app between steps.
CreateEditorWindow(title) {
    global EditorGui, EditorReplacedGui, MainGui

    EditorReplacedGui := EditorGui
    ; Owned by the launcher so it always stays in front of it (modal dialog).
    EditorGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +Owner" MainGui.Hwnd, title)
    EditorGui.SetFont("s10", "Segoe UI")
    EditorGui.MarginX := 16
    EditorGui.MarginY := 16
    EditorGui.OnEvent("Escape", CloseEditor)
    EditorGui.OnEvent("Close", CloseEditor)
    SetWindowIcon(EditorGui)
}

; Direct shortcuts are off while the editor is open, so pressing one in the
; shortcut box records it instead of opening a favorite.
ShowEditorWindow() {
    global EditorGui, EditorReplacedGui, MainGui

    UnregisterAllHotkeys()
    MainGui.Opt("+Disabled")
    EditorGui.Show("AutoSize Center")

    if IsObject(EditorReplacedGui)
        try EditorReplacedGui.Destroy()
    EditorReplacedGui := ""
}

; Keeps the name in step with the location until the user types a name of their own.
SuggestEditorName(*) {
    global EditorName, EditorTarget, EditorTypeValue, EditorAutoName

    currentName := Trim(EditorName.Value)
    if currentName != "" && currentName != EditorAutoName
        return

    target := Trim(EditorTarget.Value)
    EditorAutoName := target = "" ? "" : GetDefaultName(target, EditorTypeValue)
    EditorName.Value := EditorAutoName
}

CloseEditor(*) {
    global EditorGui, MainGui, SearchBox
    ; Re-enable the owner first so Windows hands focus back to it, not another app.
    MainGui.Opt("-Disabled")
    try EditorGui.Destroy()
    EditorGui := ""
    RegisterAllHotkeys()
    MainGui.Show()
    SearchBox.Focus()
}

; Opens the folder or file picker for the type; returns "" when cancelled.
PickTarget(type, startAt := "") {
    global EditorGui
    EditorGui.Opt("+OwnDialogs")

    switch type {
        case "folder":
            return DirSelect("*" startAt, 3, "Choose a folder")
        case "document":
            return FileSelect(1, startAt, "Choose a document", "All files (*.*)")
        case "program":
            return FileSelect(1, startAt, "Choose a program", "Programs (*.exe; *.bat; *.cmd; *.com; *.ahk; *.lnk)")
    }
    return ""
}

BrowseEditorTarget(*) {
    global EditorTarget, EditorTypeValue
    selectedTarget := PickTarget(EditorTypeValue, Trim(EditorTarget.Value))
    if selectedTarget = ""
        return

    EditorTarget.Value := selectedTarget
    SuggestEditorName()
}

ClearEditorShortcut(*) {
    global EditorHotkey
    EditorHotkey.Value := ""
    ResetShortcutStatus()
}

ResetShortcutStatus(*) {
    SetShortcutStatus("none", "Press keys in the box, then click Test.")
}

TestEditorShortcut(*) {
    global EditorHotkey, EditingIndex
    result := CheckShortcut(EditorHotkey.Value, EditingIndex)
    if result.Level = "none"
        SetShortcutStatus("none", "Press a key combination in the box first.")
    else
        SetShortcutStatus(result.Level, result.Message)
}

SetShortcutStatus(level, message) {
    global EditorShortcutStatus
    switch level {
        case "ok": color := "c107C10"
        case "warn": color := "c9D5D00"
        case "error": color := "cC42B1C"
        default: color := "c666666"
    }
    EditorShortcutStatus.SetFont(color)
    EditorShortcutStatus.Text := message
}

; Checks the shortcut and asks about a risky one. Returns true if it may be saved.
ConfirmShortcut(hotkeyValue) {
    global Favorites, EditingIndex

    result := CheckShortcut(hotkeyValue, EditingIndex)
    if result.Level = "none" || result.Level = "ok"
        return true

    SetShortcutStatus(result.Level, result.Message)
    if result.Level = "error" {
        MsgBox(result.Message, "Choose another shortcut", "Iconx")
        return false
    }

    ; Do not ask again about a shortcut the favorite already had.
    if EditingIndex > 0 && StrLower(Favorites[EditingIndex].Hotkey) = StrLower(hotkeyValue)
        return true

    answer := MsgBox(result.Message "`n`nUse it anyway?", "Shortcut may cause problems", "YesNo Icon! Default2")
    return answer = "Yes"
}

SaveEditor(*) {
    global Favorites, EditingIndex, EditorName, EditorTarget
    global EditorGui, EditorTypeValue, EditorHotkey, SearchBox
    EditorGui.Opt("+OwnDialogs")

    name := Trim(EditorName.Value)
    target := Trim(EditorTarget.Value)
    type := EditorTypeValue
    hotkeyValue := NormalizeHotkey(EditorHotkey.Value)

    if target = "" {
        MsgBox(
            type = "link" ? "Enter a web address." : "Enter a location, or click Change... to choose one.",
            "Favorite Launcher",
            "Icon!"
        )
        EditorTarget.Focus()
        return
    }

    if name = "" {
        MsgBox("Enter a name.", "Favorite Launcher", "Icon!")
        EditorName.Focus()
        return
    }

    if !ConfirmShortcut(hotkeyValue) {
        EditorHotkey.Focus()
        return
    }

    favorite := {
        Name: name,
        Target: target,
        Type: type,
        Hotkey: hotkeyValue
    }

    UnregisterAllHotkeys()
    if EditingIndex = 0
        Favorites.Push(favorite)
    else
        Favorites[EditingIndex] := favorite

    SortFavorites()
    SaveFavorites()
    RegisterAllHotkeys()
    ClearIconCache()
    CloseEditor()

    SearchBox.Value := ""
    RefreshList()
    SearchBox.Focus()
}

TypeToLabel(type) {
    switch type {
        case "folder": return "Folder"
        case "document": return "Document"
        case "program": return "Program"
        case "link": return "Web address"
        default: return "Favorite"
    }
}

GetDefaultName(target, type) {
    target := Trim(target)

    if type = "link" {
        cleanUrl := RegExReplace(target, "i)^[a-z][a-z0-9+.-]*://")
        cleanUrl := RegExReplace(cleanUrl, "/+$")
        if RegExMatch(cleanUrl, "^([^/]+)", &match)
            return match[1]
        return "Web address"
    }

    cleanTarget := RTrim(target, "\/")
    SplitPath(cleanTarget, &fileName, , , &nameWithoutExtension)

    if type = "folder" && fileName != ""
        return fileName
    if nameWithoutExtension != ""
        return nameWithoutExtension
    if fileName != ""
        return fileName
    return target
}

ShowItemContextMenu(listView, row, isRightClick, mouseX, mouseY) {
    global SelectedRow
    if row = 0
        return

    SelectedRow := row
    UpdateSelectedRow()
    UpdateFooter()

    itemMenu := Menu()
    itemMenu.Add("Open", OpenSelected)
    itemMenu.Default := "Open"
    itemMenu.Add()
    itemMenu.Add("Edit...", EditSelected)
    itemMenu.Add("Remove", RemoveSelected)
    itemMenu.Show(mouseX, mouseY)
}

RemoveSelected(*) {
    global Favorites, SearchBox, MainGui
    MainGui.Opt("+OwnDialogs")
    index := GetSelectedOriginalIndex()
    if index = 0
        return

    favorite := Favorites[index]
    answer := MsgBox(
        "Remove this favorite?`n`n" favorite.Name,
        "Remove favorite",
        "YesNo Icon?"
    )

    if answer != "Yes"
        return

    UnregisterAllHotkeys()
    Favorites.RemoveAt(index)
    SaveFavorites()
    RegisterAllHotkeys()
    ClearIconCache()
    RefreshList(SearchBox.Value)
    SearchBox.Focus()
}

RegisterAllHotkeys() {
    global Favorites, RegisteredHotkeys
    RegisteredHotkeys := Map()

    for index, favorite in Favorites {
        hotkeyValue := NormalizeHotkey(favorite.Hotkey)
        if hotkeyValue = "" || IsReservedHotkey(hotkeyValue)
            continue

        try {
            callback := OpenFavoriteByIndex.Bind(index)
            Hotkey(hotkeyValue, callback, "On")
            RegisteredHotkeys[hotkeyValue] := callback
        }
    }
}

UnregisterAllHotkeys() {
    global RegisteredHotkeys
    for hotkeyValue, callback in RegisteredHotkeys
        try Hotkey(hotkeyValue, "Off")
    RegisteredHotkeys := Map()
}

NormalizeHotkey(hotkeyValue) {
    return Trim(hotkeyValue)
}

IsReservedHotkey(hotkeyValue) {
    normalized := StrLower(StrReplace(hotkeyValue, " "))
    return normalized = "^!space"
}

FindDuplicateHotkey(hotkeyValue, ignoredIndex := 0) {
    global Favorites
    wanted := StrLower(NormalizeHotkey(hotkeyValue))

    for index, favorite in Favorites {
        if index = ignoredIndex
            continue
        if StrLower(NormalizeHotkey(favorite.Hotkey)) = wanted
            return index
    }
    return 0
}

DisplayHotkey(hotkeyValue) {
    if hotkeyValue = ""
        return ""

    key := hotkeyValue
    display := ""

    if InStr(key, "<^>!") {
        display .= "AltGr+"
        key := StrReplace(key, "<^>!")
    } else {
        if InStr(key, "^") {
            display .= "Ctrl+"
            key := StrReplace(key, "^")
        }
        if InStr(key, "!") {
            display .= "Alt+"
            key := StrReplace(key, "!")
        }
    }

    if InStr(key, "+") {
        display .= "Shift+"
        key := StrReplace(key, "+")
    }

    if InStr(key, "#") {
        display .= "Win+"
        key := StrReplace(key, "#")
    }

    key := StrReplace(key, "<")
    key := StrReplace(key, ">")

    switch StrLower(key) {
        case "space": key := "Space"
        case "pgup": key := "Page Up"
        case "pgdn": key := "Page Down"
        case "escape": key := "Esc"
        case "return": key := "Enter"
        default: key := StrUpper(key)
    }

    return display key
}

; Checks a shortcut before it is saved. Returns {Level, Message}, where Level is
; "none" (no shortcut), "ok", "warn" (works, but may clash) or "error" (cannot be used).
CheckShortcut(hotkeyValue, ignoredIndex := 0) {
    global Favorites

    hotkeyValue := NormalizeHotkey(hotkeyValue)
    if hotkeyValue = ""
        return {Level: "none", Message: ""}

    shown := DisplayHotkey(hotkeyValue)
    if IsReservedHotkey(hotkeyValue)
        return {Level: "error", Message: shown " opens the launcher. Choose another shortcut."}

    duplicateIndex := FindDuplicateHotkey(hotkeyValue, ignoredIndex)
    if duplicateIndex > 0
        return {
            Level: "error",
            Message: shown ' is already used by "' Favorites[duplicateIndex].Name '". Choose another shortcut.'
        }

    warning := GetShortcutWarning(hotkeyValue)
    if warning != ""
        return {Level: "warn", Message: warning}

    if IsHotkeyTakenByOtherProgram(hotkeyValue)
        return {Level: "warn", Message: shown " is already used by another program. Choose another shortcut."}

    return {Level: "ok", Message: shown " looks free."}
}

; Why a shortcut is likely to clash with typing, menus or other programs; "" if it looks fine.
GetShortcutWarning(hotkeyValue) {
    keys := ParseHotkey(hotkeyValue)
    shown := DisplayHotkey(hotkeyValue)
    better := SuggestShortcut(hotkeyValue)

    meaning := GetCommonShortcutMeaning(shown)
    if meaning != ""
        return shown " is a common shortcut (" meaning "). Try " better " instead."
    if keys.Win
        return shown " may be used by Windows. Try " better " instead."
    if !keys.Ctrl && !keys.Alt
        return shown " is used for typing and by many programs. Try " better " instead."
    if keys.Alt && !keys.Ctrl && !keys.Shift
        return shown " opens menus in many programs (like Alt+F for File). Try " better " instead."
    if keys.Ctrl && !keys.Alt
        return shown " is used by many programs. Try " better " instead."

    character := GetAltGrCharacter(hotkeyValue)
    if character != ""
        return shown ' types "' character '" on your keyboard. Try ' better " instead."
    return ""
}

; A safer shortcut with the same key: Ctrl+Alt+key, or Ctrl+Alt+Shift+key if Ctrl+Alt+key types a character.
SuggestShortcut(hotkeyValue) {
    key := ParseHotkey(hotkeyValue).Key
    candidate := "^!" key
    if GetAltGrCharacter(candidate) != ""
        candidate := "^!+" key
    return DisplayHotkey(candidate)
}

; Splits an AHK hotkey such as "^+!p" into its modifiers and key.
ParseHotkey(hotkeyValue) {
    keys := {Ctrl: false, Alt: false, Shift: false, Win: false, Key: ""}
    rest := hotkeyValue

    if InStr(rest, "<^>!") {
        keys.Ctrl := true
        keys.Alt := true
        rest := StrReplace(rest, "<^>!")
    }

    while StrLen(rest) > 1 && InStr("^!+#<>*~$", SubStr(rest, 1, 1)) {
        switch SubStr(rest, 1, 1) {
            case "^": keys.Ctrl := true
            case "!": keys.Alt := true
            case "+": keys.Shift := true
            case "#": keys.Win := true
        }
        rest := SubStr(rest, 2)
    }

    keys.Key := rest
    return keys
}

; What a well-known shortcut does, by its display name (for example "Ctrl+S" -> "Save").
GetCommonShortcutMeaning(shown) {
    static meanings := ""
    if !IsObject(meanings) {
        meanings := Map()
        meanings.CaseSense := false
        meanings.Set(
            "Ctrl+A", "Select all", "Ctrl+C", "Copy", "Ctrl+F", "Find", "Ctrl+H", "Replace",
            "Ctrl+N", "New", "Ctrl+O", "Open", "Ctrl+P", "Print", "Ctrl+R", "Refresh",
            "Ctrl+S", "Save", "Ctrl+T", "New tab", "Ctrl+V", "Paste", "Ctrl+W", "Close",
            "Ctrl+X", "Cut", "Ctrl+Y", "Redo", "Ctrl+Z", "Undo", "Ctrl+Esc", "Start menu",
            "Ctrl+Shift+N", "New folder", "Ctrl+Shift+T", "Reopen closed tab",
            "Ctrl+Shift+Esc", "Task Manager", "Alt+F4", "Close window", "Alt+Tab", "Switch windows",
            "Alt+Space", "Window menu", "Alt+Enter", "Properties",
            "F1", "Help", "F2", "Rename", "F3", "Search", "F5", "Refresh", "F11", "Full screen",
            "Win+D", "Show desktop", "Win+E", "File Explorer", "Win+L", "Lock", "Win+R", "Run",
            "Win+V", "Clipboard history"
        )
    }
    return meanings.Has(shown) ? meanings[shown] : ""
}

; The character a Ctrl+Alt (AltGr) shortcut types on the current keyboard layout,
; for example "@" for Ctrl+Alt+2 on a Norwegian keyboard. "" if it types nothing.
GetAltGrCharacter(hotkeyValue) {
    static VK_SHIFT := 0x10, VK_CONTROL := 0x11, VK_MENU := 0x12
    static VK_LSHIFT := 0xA0, VK_LCONTROL := 0xA2, VK_RMENU := 0xA5
    static DontChangeKeyboardState := 0x4

    keys := ParseHotkey(hotkeyValue)
    if !keys.Ctrl || !keys.Alt
        return ""

    virtualKey := GetKeyVK(keys.Key)
    if !virtualKey
        return ""

    keyState := Buffer(256, 0)
    for keyCode in [VK_CONTROL, VK_MENU, VK_LCONTROL, VK_RMENU]
        NumPut("UChar", 0x80, keyState, keyCode)
    if keys.Shift {
        NumPut("UChar", 0x80, keyState, VK_SHIFT)
        NumPut("UChar", 0x80, keyState, VK_LSHIFT)
    }

    characters := Buffer(16, 0)
    layout := DllCall("GetKeyboardLayout", "UInt", 0, "Ptr")
    count := DllCall(
        "ToUnicodeEx",
        "UInt", virtualKey,
        "UInt", GetKeySC(keys.Key),
        "Ptr", keyState,
        "Ptr", characters,
        "Int", 8,
        "UInt", DontChangeKeyboardState,
        "Ptr", layout,
        "Int"
    )
    if count = 0
        return ""

    ; A negative count is a dead key (such as ~), which still types a character.
    text := StrGet(characters, Abs(count), "UTF-16")
    return Ord(text) > 32 ? text : ""
}

; True if another program has claimed this shortcut with Windows (RegisterHotKey).
; Shortcuts that a program only handles inside its own window cannot be detected.
IsHotkeyTakenByOtherProgram(hotkeyValue) {
    static MOD_ALT := 0x1, MOD_CONTROL := 0x2, MOD_SHIFT := 0x4, MOD_WIN := 0x8, MOD_NOREPEAT := 0x4000
    static ERROR_HOTKEY_ALREADY_REGISTERED := 1409, ProbeId := 0xBFF0

    keys := ParseHotkey(hotkeyValue)
    virtualKey := GetKeyVK(keys.Key)
    if !virtualKey
        return false

    modifiers := MOD_NOREPEAT
    if keys.Alt
        modifiers |= MOD_ALT
    if keys.Ctrl
        modifiers |= MOD_CONTROL
    if keys.Shift
        modifiers |= MOD_SHIFT
    if keys.Win
        modifiers |= MOD_WIN

    if DllCall("RegisterHotKey", "Ptr", 0, "Int", ProbeId, "UInt", modifiers, "UInt", virtualKey) {
        DllCall("UnregisterHotKey", "Ptr", 0, "Int", ProbeId)
        return false
    }
    return A_LastError = ERROR_HOTKEY_ALREADY_REGISTERED
}

LoadFavorites() {
    global Favorites, ConfigFile
    Favorites := []

    if !FileExist(ConfigFile) {
        AddDefaultFavorites()
        SaveFavorites()
        return
    }

    count := IniRead(ConfigFile, "Settings", "Count", 0)
    loop count {
        section := "Favorite" A_Index
        name := IniRead(ConfigFile, section, "Name", "")
        target := IniRead(ConfigFile, section, "Target", "")
        type := IniRead(ConfigFile, section, "Type", "")
        hotkeyValue := IniRead(ConfigFile, section, "Hotkey", "")

        if name = "" || target = ""
            continue
        if !IsValidFavoriteType(type)
            type := "folder"

        Favorites.Push({
            Name: name,
            Target: target,
            Type: type,
            Hotkey: hotkeyValue
        })
    }

    SortFavorites()
}

SaveFavorites() {
    global Favorites, ConfigFile

    previousCount := IniRead(ConfigFile, "Settings", "Count", 0)
    loop previousCount
        try IniDelete(ConfigFile, "Favorite" A_Index)

    IniWrite(Favorites.Length, ConfigFile, "Settings", "Count")

    for index, favorite in Favorites {
        section := "Favorite" index
        IniWrite(favorite.Name, ConfigFile, section, "Name")
        IniWrite(favorite.Target, ConfigFile, section, "Target")
        IniWrite(favorite.Type, ConfigFile, section, "Type")
        IniWrite(favorite.Hotkey, ConfigFile, section, "Hotkey")
    }
}

IsValidFavoriteType(type) {
    return type = "folder"
        || type = "document"
        || type = "program"
        || type = "link"
}

SortFavorites() {
    global Favorites
    if Favorites.Length < 2
        return

    itemIndex := 2
    while itemIndex <= Favorites.Length {
        currentFavorite := Favorites[itemIndex]
        compareIndex := itemIndex - 1

        while compareIndex >= 1 {
            if StrCompare(currentFavorite.Name, Favorites[compareIndex].Name) >= 0
                break
            Favorites[compareIndex + 1] := Favorites[compareIndex]
            compareIndex -= 1
        }

        Favorites[compareIndex + 1] := currentFavorite
        itemIndex += 1
    }
}

AddDefaultFavorites() {
    global Favorites

    userProfile := EnvGet("USERPROFILE")

    Favorites := [
        {
            Name: "Desktop",
            Target: A_Desktop,
            Type: "folder",
            Hotkey: ""
        },
        {
            Name: "Downloads",
            Target: GetKnownFolderPath(
                "{374DE290-123F-4565-9164-39C4925E467B}",
                userProfile "\Downloads"
            ),
            Type: "folder",
            Hotkey: ""
        },
        {
            Name: "Pictures",
            Target: GetKnownFolderPath(
                "{33E28130-4E1E-4676-835A-98395C3BC3BB}",
                userProfile "\Pictures"
            ),
            Type: "folder",
            Hotkey: ""
        }
    ]

    SortFavorites()
}

GetKnownFolderPath(folderId, fallbackPath) {
    folderGuid := Buffer(16, 0)
    result := DllCall(
        "Ole32\CLSIDFromString",
        "WStr", folderId,
        "Ptr", folderGuid.Ptr,
        "Int"
    )

    if result != 0
        return fallbackPath

    folderPathPointer := 0
    result := DllCall(
        "Shell32\SHGetKnownFolderPath",
        "Ptr", folderGuid.Ptr,
        "UInt", 0,
        "Ptr", 0,
        "Ptr*", &folderPathPointer,
        "Int"
    )

    if result != 0 || !folderPathPointer
        return fallbackPath

    try folderPath := StrGet(folderPathPointer, "UTF-16")
    finally DllCall("Ole32\CoTaskMemFree", "Ptr", folderPathPointer)

    return folderPath != "" ? folderPath : fallbackPath
}

ShowOnboardingIfNeeded() {
    global ConfigFile

    onboardingShown := IniRead(
        ConfigFile,
        "Settings",
        "OnboardingShown",
        0
    )

    if onboardingShown
        return

    IniWrite(1, ConfigFile, "Settings", "OnboardingShown")

    answer := MsgBox(
        "Your launcher is ready.`n`n"
        "Press Ctrl+Alt+Space to open it.`n"
        "Type to find a favorite.`n"
        "Press Enter to open it.`n`n"
        "Choose Open launcher to try it now.",
        "Favorite Launcher",
        "OKCancel Iconi 0x40000"
    )

    if answer = "OK"
        ShowLauncher()
}

#HotIf IsLauncherActive()
Enter::OpenSelected()
NumpadEnter::OpenSelected()
Down::MoveSelection(1)
Up::MoveSelection(-1)
F2::EditSelected()
Delete::RemoveSelected()
Esc::HideLauncher()
#HotIf

IsLauncherActive() {
    global MainGui
    return IsObject(MainGui) && WinActive("ahk_id " MainGui.Hwnd)
}
