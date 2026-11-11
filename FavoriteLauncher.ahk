#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode("Input")
SetWorkingDir(A_ScriptDir)

global ConfigFile := A_ScriptDir "\FavoriteLauncher.ini"
global Favorites := []
global VisibleFavorites := []
global RegisteredHotkeys := Map()
global MainGui := "", SearchBox := "", FavoritesList := "", FooterText := ""
global AboutGui := ""
global EditorGui := "", EditorName := "", EditorType := "", EditorTarget := ""
global EditorHotkey := "", EditorBrowseButton := ""
global EditingIndex := 0, SelectedRow := 0
global FavoriteImageList := 0, IconCache := Map()

if FileExist(A_ScriptDir "\FavoriteLauncher.ico")
    TraySetIcon(A_ScriptDir "\FavoriteLauncher.ico")

A_IconTip := "Favorite Launcher"

ConfigureTrayMenu()
LoadFavorites()
RegisterAllHotkeys()
CreateMainGui()
ShowOnboardingIfNeeded()

^!Space::ShowLauncher()

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
    global MainGui, SearchBox, FavoritesList, FooterText, FavoriteImageList

    MainGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", "Favorites")
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

    FavoriteImageList := IL_Create(10, 10, true)
    FavoritesList.SetImageList(FavoriteImageList, 1)
    FavoritesList.OnEvent("Click", ListItemClicked)
    FavoritesList.OnEvent("DoubleClick", OpenSelected)
    FavoritesList.OnEvent("ItemFocus", ListItemFocused)
    FavoritesList.OnEvent("ContextMenu", ShowItemContextMenu)

    addButton := MainGui.AddButton("xm y+10 w90 h30", "+ Add")
    addButton.OnEvent("Click", AddFavorite)

    FooterText := MainGui.AddText(
        "x+12 yp+6 w430 c666666 Right",
        "Enter to open"
    )

    MainGui.OnEvent("Escape", HideLauncher)
    MainGui.OnEvent("Close", HideLauncher)
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

    switch favorite.Type {
        case "folder": typeText := "Folder"
        case "document": typeText := "Document"
        case "program": typeText := "Program"
        case "link": typeText := "Web address"
        default: typeText := "Favorite"
    }

    FooterText.Text := typeText "  |  Enter to open"
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
            "Iconx"
        )
    }
}

OpenFolder(path) {
    if !DirExist(path) {
        MsgBox("The folder does not exist:`n`n" path, "Favorite Launcher", "Iconx")
        return
    }

    if NavigateFileDialog(path)
        return
    Run(path)
}

OpenFile(path) {
    if !FileExist(path) {
        MsgBox("The file does not exist:`n`n" path, "Favorite Launcher", "Iconx")
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
    OpenEditor()
}

EditSelected(*) {
    index := GetSelectedOriginalIndex()
    if index != 0
        OpenEditor(index)
}

OpenEditor(index := 0) {
    global Favorites, MainGui
    global EditorGui, EditorName, EditorType, EditorTarget
    global EditorHotkey, EditorBrowseButton, EditingIndex

    EditingIndex := index
    if IsObject(EditorGui)
        try EditorGui.Destroy()

    windowTitle := index = 0 ? "Add favorite" : "Edit favorite"
    EditorGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", windowTitle)
    EditorGui.SetFont("s10", "Segoe UI")
    EditorGui.MarginX := 16
    EditorGui.MarginY := 16

    EditorGui.AddText("xm ym", "Name")
    EditorName := EditorGui.AddEdit("xm y+5 w470 h30")

    EditorGui.AddText("xm y+14", "Type")
    EditorType := EditorGui.AddDropDownList(
        "xm y+5 w470 Choose1",
        ["Folder", "Document", "Program", "Web address"]
    )
    EditorType.OnEvent("Change", EditorTypeChanged)

    EditorGui.AddText("xm y+14", "Location")
    EditorTarget := EditorGui.AddEdit("xm y+5 w370 h30")
    EditorTarget.OnEvent("Change", SuggestEditorName)

    EditorBrowseButton := EditorGui.AddButton("x+8 yp w92 h30", "Browse...")
    EditorBrowseButton.OnEvent("Click", BrowseEditorTarget)

    EditorGui.AddText("xm y+14", "Direct shortcut")
    EditorHotkey := EditorGui.AddHotkey("xm y+5 w220 h30")
    EditorGui.AddText("x+10 yp+5 c666666", "Optional")

    clearButton := EditorGui.AddButton("xm y+9 w125 h28", "Clear shortcut")
    clearButton.OnEvent("Click", ClearEditorShortcut)

    saveText := index = 0 ? "Add" : "Save"
    saveButton := EditorGui.AddButton("x285 y+22 w90 h32 Default", saveText)
    saveButton.OnEvent("Click", SaveEditor)

    cancelButton := EditorGui.AddButton("x+8 yp w90 h32", "Cancel")
    cancelButton.OnEvent("Click", CloseEditor)

    EditorGui.OnEvent("Escape", CloseEditor)
    EditorGui.OnEvent("Close", CloseEditor)

    if index > 0 {
        favorite := Favorites[index]
        EditorName.Value := favorite.Name
        EditorTarget.Value := favorite.Target
        EditorHotkey.Value := favorite.Hotkey
        EditorType.Choose(TypeToDropdownIndex(favorite.Type))
    }

    EditorTypeChanged()
    MainGui.Opt("+Disabled")
    EditorGui.Show("AutoSize Center")

    if index = 0
        EditorTarget.Focus()
    else
        EditorName.Focus()
}

SuggestEditorName(*) {
    global EditorName, EditorTarget, EditorType
    if Trim(EditorName.Value) != ""
        return

    target := Trim(EditorTarget.Value)
    if target = ""
        return

    type := DropdownIndexToType(EditorType.Value)
    EditorName.Value := GetDefaultName(target, type)
}

CloseEditor(*) {
    global EditorGui, MainGui, SearchBox
    try EditorGui.Destroy()
    MainGui.Opt("-Disabled")
    MainGui.Show()
    SearchBox.Focus()
}

EditorTypeChanged(*) {
    global EditorType, EditorBrowseButton
    type := DropdownIndexToType(EditorType.Value)

    if type = "link" {
        EditorBrowseButton.Enabled := false
        EditorBrowseButton.Text := "Browse..."
    } else {
        EditorBrowseButton.Enabled := true
        EditorBrowseButton.Text := type = "folder" ? "Folder..." : "File..."
    }
}

BrowseEditorTarget(*) {
    global EditorType, EditorTarget, EditorName
    type := DropdownIndexToType(EditorType.Value)
    selectedTarget := ""

    if type = "folder"
        selectedTarget := DirSelect("*", 3, "Choose a folder")
    else if type = "document"
        selectedTarget := FileSelect(1, "", "Choose a document", "All files (*.*)")
    else if type = "program"
        selectedTarget := FileSelect(
            1,
            "",
            "Choose a program",
            "Programs (*.exe; *.bat; *.cmd; *.com; *.ahk; *.lnk)"
        )
    else
        return

    if selectedTarget = ""
        return

    EditorTarget.Value := selectedTarget
    if Trim(EditorName.Value) = ""
        EditorName.Value := GetDefaultName(selectedTarget, type)
}

ClearEditorShortcut(*) {
    global EditorHotkey
    EditorHotkey.Value := ""
}

SaveEditor(*) {
    global Favorites, EditingIndex, EditorName, EditorTarget
    global EditorType, EditorHotkey, SearchBox

    name := Trim(EditorName.Value)
    target := Trim(EditorTarget.Value)
    type := DropdownIndexToType(EditorType.Value)
    hotkeyValue := NormalizeHotkey(EditorHotkey.Value)

    if name = "" {
        MsgBox("Enter a name.", "Favorite Launcher", "Icon!")
        EditorName.Focus()
        return
    }

    if target = "" {
        MsgBox("Enter a location.", "Favorite Launcher", "Icon!")
        EditorTarget.Focus()
        return
    }

    if hotkeyValue != "" {
        duplicateIndex := FindDuplicateHotkey(hotkeyValue, EditingIndex)
        if duplicateIndex > 0 {
            MsgBox(
                DisplayHotkey(hotkeyValue) " is already assigned to:`n`n"
                Favorites[duplicateIndex].Name,
                "Shortcut already used",
                "Iconx"
            )
            EditorHotkey.Focus()
            return
        }

        if IsReservedHotkey(hotkeyValue) {
            MsgBox(
                "Ctrl+Alt+Space opens the launcher and cannot be assigned.",
                "Shortcut already used",
                "Iconx"
            )
            EditorHotkey.Focus()
            return
        }
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

TypeToDropdownIndex(type) {
    switch type {
        case "folder": return 1
        case "document": return 2
        case "program": return 3
        case "link": return 4
        default: return 1
    }
}

DropdownIndexToType(index) {
    switch index {
        case 1: return "folder"
        case 2: return "document"
        case 3: return "program"
        case 4: return "link"
        default: return "folder"
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
    global Favorites, SearchBox
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
        "OKCancel Iconi"
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
