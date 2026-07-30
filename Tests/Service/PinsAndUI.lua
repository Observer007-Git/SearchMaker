local context = assert(...)
local SMK = context.SMK
local root = context.root
local loadModule = context.loadModule
local mapInfo = context.mapInfo
local first = context.first
local externalFavorite = context.externalFavorite
local coordinateResult = context.coordinateResult
local appSource = context.appSource
local mainPanelSource = context.mainPanelSource
local widgetsSource = context.widgetsSource
local panelSettingsSource = context.panelSettingsSource
local ReadSource = context.readSource

mapInfo[100] = { name = "测试地图", mapType = Enum.UIMapType.Zone }
local fakeMap = { pinPools = {}, pins = {}, mapID = 100 }
function fakeMap:GetCanvas() return self end
function fakeMap:GetMapID() return self.mapID end
function fakeMap:IsShown() return true end
function fakeMap:AddDataProvider(provider) provider.map = self end
function fakeMap:AcquirePin(template, ...)
    local pin = self.pinPools[template].createFunc()
    pin.pinTemplate = template
    pin:OnAcquired(...)
    self.pins[#self.pins + 1] = pin
    return pin
end
function fakeMap:RemoveAllPinsByTemplate(template)
    local retained = {}
    for _, pin in ipairs(self.pins) do
        if pin.pinTemplate == template then
            self.pinPools[template].resetFunc(nil, pin)
        else
            retained[#retained + 1] = pin
        end
    end
    self.pins = retained
end
local editedPinEntry, contextPinEntry
assert(SMK.MapPins:Initialize(fakeMap, {
    onEdit = function(entry) editedPinEntry = entry end,
    onContext = function(entry) contextPinEntry = entry end,
}), "map pin provider initialization failed")
SMK.MapPins:Refresh()
assert(#fakeMap.pins == 1, "enabled map pin was not acquired")
assert(fakeMap.pins[1].frameLevelType == "PIN_FRAME_LEVEL_AREA_POI",
    "persistent map pin frame level changed")
assert(fakeMap.pins[1].icon.atlas == "VignetteEvent-SuperTracked",
    "selected pin texture was ignored")
assert(fakeMap.pins[1].label.text == "旧地点" and fakeMap.pins[1].label.shown,
    "enabled map pin name was not rendered")
assert(fakeMap.pins[1].labelHitbox
    and fakeMap.pins[1].labelHitbox.allPointsTarget == fakeMap.pins[1].label
    and fakeMap.pins[1].labelHitbox.registeredClicks[1] == "LeftButtonUp"
    and fakeMap.pins[1].labelHitbox.registeredClicks[2] == "RightButtonUp"
    and fakeMap.pins[1].labelHitbox.scripts.OnEnter
    and fakeMap.pins[1].labelHitbox.scripts.OnLeave
    and fakeMap.pins[1].labelHitbox.scripts.OnClick,
    "map pin name did not create a matching interactive hitbox")
assert(fakeMap.pins[1].label.color.r == SMK.Config.colors.gold[1]
    and fakeMap.pins[1].label.color.g == SMK.Config.colors.gold[2]
    and fakeMap.pins[1].label.color.b == SMK.Config.colors.gold[3]
    and fakeMap.pins[1].label.scale == 1.4
    and fakeMap.pins[1].label.point[1] == "CENTER"
    and fakeMap.pins[1].label.point[3] == "CENTER",
    "pin text appearance settings were not rendered")
SMK.MapPins:UpdatePinPreviewColor(first, { r = 0.9, g = 0.8, b = 0.7 })
assert(fakeMap.pins[1].label.color.r == 0.9,
    "active pin lookup did not update the matching preview directly")
SMK.MapPins:UpdatePinPreviewColor(first, nil)
assert(fakeMap.pins[1].label.color.r == SMK.Config.colors.gold[1],
    "active pin preview did not restore the fixed default color")
local highlightTimers = {}
C_Timer = {
    After = function(_, callback) highlightTimers[#highlightTimers + 1] = callback end,
}
assert(SMK.MapPins:ShowTargetHighlight({ mapID = 100, x = 25, y = 75 })
    and #fakeMap.pins == 2,
    "target highlight pin was not acquired")
local highlightPin = fakeMap.pins[2]
assert(highlightPin.pinTemplate == "SearchMakerTargetHighlightPinTemplate"
    and highlightPin.frameLevelType == "PIN_FRAME_LEVEL_TOPMOST"
    and highlightPin.x == 0.25 and highlightPin.y == 0.75
    and highlightPin.icon.atlas == "MonsterEnemy"
    and highlightPin.ring.texture == "Interface\\Cooldown\\starburst"
    and highlightPin.ring.width == 80
    and highlightPin.ring.color.r == 1
    and highlightPin.ring.color.g == 1
    and highlightPin.ring.color.b == 1
    and highlightPin.icon.shown
    and highlightPin.ring.animationGroup.playing,
    "target highlight was not positioned or animated")
assert(SMK.MapPins:ShowTargetHighlight({ mapID = 100, x = 40, y = 60 })
    and #fakeMap.pins == 2 and fakeMap.pins[2].x == 0.4,
    "a newer target highlight did not replace the previous one")
highlightTimers[1]()
assert(#fakeMap.pins == 2, "an older timer removed the current target highlight")
highlightTimers[2]()
assert(#fakeMap.pins == 1, "target highlight was not released after its duration")
assert(SMK.MapPins:ShowHoverHighlight({ mapID = 100, x = 30, y = 70 })
    and #fakeMap.pins == 2 and fakeMap.pins[2].x == 0.3,
    "hover highlight pin was not acquired")
assert(not fakeMap.pins[2].icon.shown
    and fakeMap.pins[2].ring.shown
    and fakeMap.pins[2].ring.animationGroup.playing,
    "hover highlight did not hide the marker while keeping the animation")
assert(SMK.MapPins:ShowHoverHighlight({ mapID = 100, x = 45, y = 55 })
    and #fakeMap.pins == 2 and fakeMap.pins[2].x == 0.45,
    "a newer hover highlight did not replace the previous one")
SMK.MapPins:ClearHoverHighlight()
assert(#fakeMap.pins == 1, "hover highlight was not cleared")
assert(SMK.MapPins:ShowTargetHighlight({ mapID = 100, x = 20, y = 80 })
    and not SMK.MapPins:ShowHoverHighlight({ mapID = 100, x = 90, y = 10 })
    and #fakeMap.pins == 2 and fakeMap.pins[2].x == 0.2,
    "hover highlight replaced an active target highlight")
SMK.MapPins:ClearHoverHighlight()
assert(#fakeMap.pins == 2, "clearing hover removed an active target highlight")
highlightTimers[3]()
assert(#fakeMap.pins == 1, "protected target highlight was not released by its timer")
assert(SMK.MapPins:ContainsMouseFocus({ fakeMap.pins[1] }),
    "map pin focus was not identified")
assert(not fakeMap.pins[1].scripts or (not fakeMap.pins[1].scripts.OnEnter
    and not fakeMap.pins[1].scripts.OnLeave),
    "map pin installed inherited motion scripts before AcquirePin")
fakeMap.pins[1].labelHitbox.scripts.OnEnter()
assert(GameTooltip.title == "旧地点",
    "hovering the map pin name did not show the location tooltip")
fakeMap.pins[1].labelHitbox.scripts.OnClick(fakeMap.pins[1].labelHitbox, "LeftButton")
assert(editedPinEntry and editedPinEntry.name == "旧地点",
    "clicking the map pin name did not open the location editor")
fakeMap.pins[1].labelHitbox.scripts.OnClick(fakeMap.pins[1].labelHitbox, "RightButton")
assert(contextPinEntry and contextPinEntry.name == "旧地点",
    "right-clicking the map pin name did not open the shared context menu")
editedPinEntry = nil
fakeMap.pins[1]:OnMouseEnter()
assert(GameTooltip.title == "旧地点"
    and GameTooltip.lines[1]:find("测试地图", 1, true)
    and GameTooltip.lines[1]:find("100", 1, true)
    and GameTooltip.lines[2]:find("12.34", 1, true)
    and GameTooltip.lines[2]:find("56.78", 1, true),
    "map pin tooltip did not separate its map name and coordinates")
local noteColorFound
for index, line in ipairs(GameTooltip.lines) do
    if line == "绿色备注" then
        local color = GameTooltip.lineColors[index]
        noteColorFound = color and color[1] == SMK.Config.colors.note[1]
            and color[2] == SMK.Config.colors.note[2]
            and color[3] == SMK.Config.colors.note[3]
    end
end
assert(noteColorFound, "map pin note did not use the configured green tooltip color")
fakeMap.pins[1]:OnClick("LeftButton")
assert(editedPinEntry and editedPinEntry.name == "旧地点", "map pin click did not open its editor callback")
SMK.MapPins:UpdatePinVisibility(first, false, true)
assert(fakeMap.pins[1].label.shown == false
    and fakeMap.pins[1].labelHitbox.shown == false
    and fakeMap.pins[1].icon.shown == true
    and fakeMap.pins[1].shown == true,
    "per-location texture visibility depended on a removed global setting")
SMK.MapPins:UpdatePinVisibility(first, false, false)
assert(fakeMap.pins[1].shown == false,
    "a location with both display options disabled retained an interactive pin")
local addedPersistentTemporary, persistentTemporaryReason =
    SMK.MapPins:AddTemporaryRoutePin(first)
assert(not addedPersistentTemporary and persistentTemporaryReason == "PERSISTENT_EXISTS",
    "a route temporary pin replaced an existing saved map pin")
assert(SMK.MapPins:HasPersistentMarker(first),
    "saved map pin state was not exposed to the route dialog")
local addedRouteTemporary = assert(SMK.MapPins:AddTemporaryRoutePin(externalFavorite))
assert(addedRouteTemporary and SMK.MapPins:HasTemporaryRoutePin(externalFavorite)
    and #fakeMap.pins == 2,
    "route temporary pin was not retained in the session pin collection")
local temporaryPin
for _, pin in ipairs(fakeMap.pins) do
    if pin.pinTemplate == "SearchMakerTemporaryRoutePinTemplate" then
        temporaryPin = pin
        break
    end
end
assert(temporaryPin
    and temporaryPin.icon.atlas == SMK.Config.mapPins.routeTemporary.atlas,
    "route temporary pin did not use its independent special Atlas")
assert(SMK.Route:Add(first) and SMK.Route:Add(externalFavorite))
function SMK.RouteDialog:NewTestRow()
    local function TextValue()
        return {
            SetText = function(self, value) self.text = value end,
            SetTextColor = function(self, r, g, b) self.color = { r, g, b } end,
        }
    end
    return {
        SetShown = function(self, shown) self.shown = shown end,
        name = TextValue(),
        details = TextValue(),
        mark = {
            SetText = function(self, value) self.text = value end,
            SetEnabled = function(self, enabled) self.enabled = enabled end,
        },
        up = {
            SetEnabled = function(self, enabled) self.enabled = enabled end,
            SetShown = function(self, shown) self.shown = shown end,
        },
        down = {
            SetEnabled = function(self, enabled) self.enabled = enabled end,
            SetShown = function(self, shown) self.shown = shown end,
        },
        remove = { SetShown = function(self, shown) self.shown = shown end },
    }
end
SMK.RouteDialog.rows = {
    SMK.RouteDialog:NewTestRow(),
    SMK.RouteDialog:NewTestRow(),
}
SMK.RouteDialog.count = { SetText = function(self, value) self.text = value end }
SMK.RouteDialog.empty = { SetShown = function(self, shown) self.shown = shown end }
SMK.RouteDialog.content = { SetHeight = function(self, height) self.height = height end }
SMK.RouteDialog.nameInput = {
    SetEnabled = function() end,
    SetTextColor = function() end,
}
SMK.RouteDialog.save = { SetShown = function() end }
SMK.RouteDialog.start = {
    SetText = function(self, value) self.text = value end,
    SetEnabled = function(self, enabled) self.enabled = enabled end,
}
SMK.RouteDialog.complete = {
    SetShown = function(self, shown) self.shown = shown end,
    SetEnabled = function(self, enabled) self.enabled = enabled end,
}
SMK.RouteDialog.clear = {
    SetShown = function(self, shown) self.shown = shown end,
    SetEnabled = function(self, enabled) self.enabled = enabled end,
}
SMK.RouteDialog.sort = {
    SetShown = function(self, shown) self.shown = shown end,
    SetEnabled = function(self, enabled) self.enabled = enabled end,
}
assert(SMK.Route:Activate(1))
SMK.RouteDialog:Refresh()
assert(not SMK.RouteDialog.rows[1].mark.enabled
    and SMK.RouteDialog.rows[1].mark.text == SMK.L.ROUTE_TEMP_PIN_PERSISTENT_STATE
    and not SMK.RouteDialog.rows[2].mark.enabled
    and SMK.RouteDialog.rows[2].mark.text == SMK.L.ROUTE_TEMP_PIN_ACTIVE,
    "route rows did not display and disable existing marker states")
assert(SMK.RouteDialog.rows[1].name.text == first.name
    and SMK.RouteDialog.rows[1].name.color[1] == SMK.Config.colors.routeCurrent[1]
    and SMK.RouteDialog.rows[1].name.color[2] == SMK.Config.colors.routeCurrent[2]
    and SMK.RouteDialog.rows[1].name.color[3] == SMK.Config.colors.routeCurrent[3],
    "current route location retained a glyph prefix or did not use green text")
SMK.Route:Clear()
SMK.MapPins:Refresh()
assert(#fakeMap.pins == 2 and SMK.MapPins:HasTemporaryRoutePin(externalFavorite),
    "clearing the route also cleared its session-only map pin")
local duplicateTemporary, duplicateTemporaryReason =
    SMK.MapPins:AddTemporaryRoutePin(externalFavorite)
assert(not duplicateTemporary and duplicateTemporaryReason == "TEMPORARY_EXISTS",
    "duplicate route temporary pin was accepted")

local layoutButton = {
    showIcon = false,
    SetSize = function(self, width, height) self.width, self.height = width, height end,
    GetWidth = function(self) return self.width end,
    SetWidth = function(self, width) self.width = width end,
    SetClipsChildren = function(self, value) self.clipsChildren = value end,
    iconBox = {
        ClearAllPoints = function() end,
        SetPoint = function() end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        SetShown = function(self, shown) self.shown = shown end,
    },
    background = {
        ClearAllPoints = function() end,
        SetPoint = function() end,
        SetAtlas = function() end,
        Show = function() end,
    },
    hitArea = { ClearAllPoints = function() end, SetAllPoints = function() end },
    label = {
        text = "short",
        width = 50,
        GetText = function(self) return self.text end,
        GetUnboundedStringWidth = function(self) return self.width end,
        ClearAllPoints = function() end,
        SetPoint = function(self, point, _, _, x, y)
            if point == "LEFT" then self.leftOffset, self.yOffset = x, y end
        end,
    },
}
SMK.Widgets:UpdateLocationGeometry(layoutButton)
assert(layoutButton.height == 38 and layoutButton.width == 179
    and layoutButton.iconBox.width == 0 and not layoutButton.iconBox.shown
    and layoutButton.label.leftOffset == 8 and layoutButton.label.yOffset == 1,
    "main panel location sign geometry is incorrect")
layoutButton.showIcon = true
SMK.Widgets:UpdateLocationGeometry(layoutButton)
assert(layoutButton.width == 217 and layoutButton.iconBox.width == 38
    and layoutButton.iconBox.shown,
    "search result location icon geometry is incorrect")
layoutButton.label.text, layoutButton.label.width = "long", 220
SMK.Widgets:UpdateLocationGeometry(layoutButton)
assert(layoutButton.width == 274,
    "search result location sign did not expand for long text")
SMK.Widgets:StretchSearchResult(layoutButton, 232)
assert(layoutButton.width == 232 and not layoutButton.clipsChildren,
    "search result width was not constrained")

local appliedBarAlpha, appliedBoxAlpha, appliedHintAlpha
local originalSearchBar, originalSearchBox = SMK.SearchBar.bar, SMK.SearchBar.box
SMK.SearchBar.bar = { SetAlpha = function(_, value) appliedBarAlpha = value end }
SMK.SearchBar.box = {
    SetAlpha = function(_, value) appliedBoxAlpha = value end,
    moveHint = { SetAlpha = function(_, value) appliedHintAlpha = value end },
}
SMK.SearchBar:ApplyOpacity()
SMK.SearchBar.bar, SMK.SearchBar.box = originalSearchBar, originalSearchBox
assert(appliedBarAlpha == 1 and appliedBoxAlpha == SMK.Settings:Get("searchBarOpacity")
    and appliedHintAlpha == appliedBoxAlpha,
    "search results inherited search-box opacity")

local playerContextRequests = 0
local originalCallbacks = SMK.SearchBar.callbacks
SMK.SearchBar.callbacks = {
    onPlayerContextRequested = function() playerContextRequests = playerContextRequests + 1 end,
}
assert(SMK.Settings:Set("searchAllMaps", false))
SMK.SearchBar:RefreshPlayerContext()
SMK.SearchBar.callbacks = originalCallbacks
assert(playerContextRequests == 1,
    "floating search did not request a fresh player-map context")

local menuLabels, favoriteMenuEntry = {}, nil
MenuUtil = {
    CreateContextMenu = function(_, initializer)
        local root = {
            CreateButton = function(_, label, callback)
                menuLabels[#menuLabels + 1] = { label = label, callback = callback }
            end,
        }
        initializer(nil, root)
        return { IsShown = function() return true end }
    end,
}
SMK.LocationContextMenu:Initialize({
    onFavorite = function(entry) favoriteMenuEntry = entry end,
    onCopy = function() end,
    onShare = function() end,
    onOpenMap = function(entry) SMK.testOpenedMapMenuEntry = entry end,
    onEdit = function() end,
    onDelete = function() end,
    onRoute = function() end,
    onTemporaryPin = function(entry) SMK.testTemporaryMenuEntry = entry end,
})
SMK.LocationContextMenu:Open(externalFavorite, {})
assert(#menuLabels == 4
    and menuLabels[1].label == SMK.L.MENU_FAVORITE
    and menuLabels[4].label == SMK.L.MENU_ADD_ROUTE,
    "external location context menu did not expose the required fixed actions")
menuLabels[1].callback()
assert(favoriteMenuEntry == externalFavorite,
    "external favorite action did not use the shared context menu callback")
menuLabels = {}
SMK.LocationContextMenu:Open(first, {})
assert(#menuLabels == 5
    and menuLabels[1].label == SMK.L.MENU_COPY_COORDINATES
    and menuLabels[3].label == SMK.L.MENU_EDIT_COORDINATE
    and menuLabels[4].label == SMK.L.MENU_DELETE_COORDINATE,
    "saved location context menu did not expose the required fixed actions")
menuLabels = {}
SMK.LocationContextMenu:Open(first, {}, true)
assert(#menuLabels == 6 and menuLabels[1].label == SMK.L.MENU_OPEN_MAP,
    "hidden-map saved search result did not expose Open Map")
menuLabels[1].callback()
assert(SMK.testOpenedMapMenuEntry == first,
    "Open Map did not use the selected saved search result")
SMK.testOpenedMapMenuEntry = nil
menuLabels = {}
SMK.LocationContextMenu:Open(externalFavorite, {}, true)
assert(#menuLabels == 4 and menuLabels[1].label == SMK.L.MENU_FAVORITE,
    "external search result incorrectly exposed Open Map")
WorldMapFrame.IsShown = function() return true end
menuLabels = {}
SMK.LocationContextMenu:Open(first, {}, true)
assert(#menuLabels == 5 and menuLabels[1].label == SMK.L.MENU_COPY_COORDINATES,
    "visible world map retained the search-only Open Map action")
WorldMapFrame.IsShown = function() return false end
menuLabels = {}
SMK.LocationContextMenu:Open(
    coordinateResult.entry, {}, true)
assert(#menuLabels == 3
    and menuLabels[1].label == SMK.L.MENU_COPY_COORDINATES
    and menuLabels[2].label == SMK.L.MENU_ADD_TEMP_PIN
    and menuLabels[3].label == SMK.L.MENU_ADD_ROUTE,
    "recognized coordinate context menu did not expose route and temporary-pin actions")
menuLabels[2].callback()
assert(SMK.testTemporaryMenuEntry == coordinateResult.entry,
    "recognized coordinate temporary-pin action did not use the shared callback")
menuLabels = {}
SMK.LocationContextMenu:Open(
    { isMapPortal = true, mapID = 100 }, {}, true)
assert(#menuLabels == 0, "map search result incorrectly exposed a location context menu")
assert(SMK.HelpDialog and SMK.HelpDialog.Create and SMK.HelpDialog.Open
    and SMK.L.HELP_TEXT ~= "",
    "localized help dialog is unavailable")
SMK.testOpenLocationOnMapBlock = assert(appSource:match(
    "function App:OpenLocationOnMap.-\nend"))
assert(SMK.testOpenLocationOnMapBlock:find("SMK.Map:OpenMap", 1, true)
    and SMK.testOpenLocationOnMapBlock:find("SMK.SearchBar:ClosePanel", 1, true)
    and SMK.testOpenLocationOnMapBlock:find(
        "self:QueueLocationHighlight", 1, true)
    and SMK.testOpenLocationOnMapBlock:find(
        "self:ShowPendingLocationHighlight", 1, true),
    "Open Map action does not open, close search, and queue target highlighting")
SMK.testOpenLocationOnMapBlock = nil
SMK.testPendingHighlightBlock = assert(appSource:match(
    "function App:ShowPendingLocationHighlight.-\nend"))
assert(SMK.testPendingHighlightBlock:find("request.token", 1, true)
    and SMK.testPendingHighlightBlock:find("C_Timer.After", 1, true)
    and SMK.testPendingHighlightBlock:find(
        "SMK.MapPins:ShowTargetHighlight", 1, true)
    and appSource:find(
        "self:OpenLocationContext(entry, owner, true)", 1, true)
    and not ReadSource("UI/LocationContextMenu.lua"):find(
        "owner.owner", 1, true),
    "Open Map source or map-ready highlighting still depends on UI ownership timing")
SMK.testPendingHighlightBlock = nil
assert(mainPanelSource:find(
        "Widgets:CreatePanelButton(frame, SMK.L.ROUTE_TITLE)", 1, true)
    and mainPanelSource:find(
        "route:SetPoint(\"RIGHT\", scalePlus, \"LEFT\", -buttonGap, 0)", 1, true)
    and not mainPanelSource:find(
        "Widgets:CreatePanelButton(moreFrame, SMK.L.ROUTE_TITLE)", 1, true),
    "route button was not moved beside the location scale controls")
assert(select(2, mainPanelSource:gsub(
        "PanelLayout%.visualSidePadding", "")) >= 2
    and mainPanelSource:find("rowX + width > rowRight", 1, true)
    and mainPanelSource:find("x + width > rowRight", 1, true),
    "main panel rows do not use the asymmetric icon-frame visual bounds")
assert(ReadSource("UI/HelpDialog.lua"):find("UIPanelScrollFrameTemplate", 1, true)
    and ReadSource("UI/RouteDialog.lua"):find(
        "close:SetFrameLevel(frame:GetFrameLevel() + 20)", 1, true)
    and ReadSource("UI/RouteDialog.lua"):find(
        "SMK.Widgets:ApplyPanelBorder(frame)", 1, true),
    "help scrolling, route close-button priority, or picker-style route border is missing")
assert(SMK.Config.panelBackdrop.edgeFile
        == "Interface\\Tooltips\\UI-Tooltip-Border"
    and SMK.Config.resultBackdrop.edgeFile
        == "Interface\\Tooltips\\UI-Tooltip-Border"
    and SMK.Config.panel.backgroundInset == 3
    and SMK.Config.panelBackdrop.insets.left == 1
    and SMK.Config.panelBackdrop.insets.right == 1
    and SMK.Config.panelBackdrop.insets.top == 1
    and SMK.Config.panelBackdrop.insets.bottom == 1
    and SMK.Config.resultBackdrop.insets.left == 1
    and SMK.Config.resultBackdrop.insets.right == 1
    and SMK.Config.resultBackdrop.insets.top == 1
    and SMK.Config.resultBackdrop.insets.bottom == 1
    and widgetsSource:find("function Widgets:ApplyPanelBorder(frame)", 1, true)
    and not (mainPanelSource
        .. panelSettingsSource
        .. ReadSource("UI/BulkDeleteDialog.lua")
        .. ReadSource("UI/CopyDialog.lua")
        .. ReadSource("UI/HelpDialog.lua")
        .. ReadSource("UI/ImportPreviewDialog.lua")
        .. ReadSource("UI/LocationEditor.lua")
        .. ReadSource("UI/RouteImportDialog.lua")
        .. ReadSource("UI/RouteDialog.lua")
        .. ReadSource("UI/SearchBarSettings.lua")
        .. ReadSource("UI/ShareDialog.lua")):find("borderAtlas", 1, true),
    "plugin panels do not share the Tooltip border implementation")
assert(not (ReadSource("UI/BulkDeleteDialog.lua")
        .. ReadSource("UI/ImportPreviewDialog.lua")
        .. ReadSource("UI/LocationEditor.lua")
        .. ReadSource("UI/RouteImportDialog.lua")
        .. ReadSource("UI/RouteDialog.lua")
        .. ReadSource("UI/ShareDialog.lua")):find(
            "UIPanelButtonTemplate", 1, true),
    "a plugin action button still uses the default panel button background")
assert(SMK.Config.panel.layout.scrollFrameRightInset == 28
    and mainPanelSource:find(
        "%-Config%.panel%.layout%.scrollFrameRightInset")
    and ReadSource("UI/RouteDialog.lua"):find(
        "%-SMK%.Config%.panel%.layout%.scrollFrameRightInset")
    and ReadSource("UI/ImportPreviewDialog.lua"):find(
        "%-SMK%.Config%.panel%.layout%.scrollFrameRightInset")
    and ReadSource("UI/HelpDialog.lua"):find(
        "%-Config%.panel%.layout%.scrollFrameRightInset")
    and ReadSource("UI/ShareDialog.lua"):find(
        "%-Config%.panel%.layout%.scrollFrameRightInset"),
    "panel scrollbars are not inset two pixels from the right border")
local closeButtonSources = mainPanelSource
    .. panelSettingsSource
    .. ReadSource("UI/SearchBarSettings.lua")
    .. ReadSource("UI/BulkDeleteDialog.lua")
    .. ReadSource("UI/CopyDialog.lua")
    .. ReadSource("UI/HelpDialog.lua")
    .. ReadSource("UI/ImportPreviewDialog.lua")
    .. ReadSource("UI/RouteImportDialog.lua")
    .. ReadSource("UI/RouteDialog.lua")
    .. ReadSource("UI/ShareDialog.lua")
assert(select(2, closeButtonSources:gsub(
        "close:SetPoint%(\"TOPRIGHT\", %-3, %-3%)", "")) == 10
    and select(2, closeButtonSources:gsub("CreateCloseButton%(frame%)", "")) == 10
    and not closeButtonSources:find("UIPanelCloseButton", 1, true)
    and widgetsSource:find(
        "normal:SetAtlas(Config.panel.controls.closeButtonAtlas, false)", 1, true)
    and widgetsSource:find("highlight:SetAllPoints()", 1, true)
    and widgetsSource:find("highlight:SetAlpha(0.5)", 1, true)
    and widgetsSource:find(
        "button.locationHighlight = button:CreateTexture", 1, true),
    "panel buttons do not share the configured Atlas, hover, or close-button style")

local panelExpanded, resultsUpdated, outsideRegistered = false, 0, false
local pickerHidden, pinPickerHidden = false, false
local transientEditor = setmetatable({
    customIconPicker = {
        IsShown = function() return true end,
        Hide = function() pickerHidden = true end,
    },
    customIconButton = {},
    pinTexturePicker = {
        IsShown = function() return true end,
        Hide = function() pinPickerHidden = true end,
    },
    pinTextureButton = {},
}, { __index = SMK.LocationEditor })
SMK.ModalManager:Register(transientEditor)
SMK.ModalManager:CloseTransientMenus({ {} })
assert(pickerHidden and pinPickerHidden,
    "outside clicks did not close the transient icon or pin texture picker")
local controllerSearchBar = {
    suppressPanelHidden = false,
    searchResults = {
        IsShown = function() return false end,
    },
    outsideListener = {
        RegisterEvent = function() outsideRegistered = true end,
        UnregisterEvent = function() outsideRegistered = false end,
    },
    box = { ClearFocus = function() end },
    UpdateResults = function() resultsUpdated = resultsUpdated + 1 end,
    HideResults = function() end,
    CancelPendingSearch = function() end,
    SetQuery = function() end,
}
local managedPanel = {
    SetExpanded = function(_, value) panelExpanded = value end,
    IsExpanded = function() return panelExpanded end,
}
local panelController = SMK.PanelController:New(controllerSearchBar)
panelController:AttachPanel(managedPanel)
panelController:Open()
assert(panelExpanded and resultsUpdated == 1 and outsideRegistered,
    "panel controller did not own panel opening and listener registration")
panelController:Close()
assert(not panelExpanded and not outsideRegistered,
    "panel controller did not close the panel and release its listener")

local originalCreateFrame = CreateFrame
local originalIsAddOnLoaded = C_AddOns.IsAddOnLoaded
local whisperListener
CreateFrame = function()
    local frame = { registered = {} }
    function frame:RegisterEvent(event) self.registered[event] = true end
    function frame:UnregisterEvent(event) self.registered[event] = nil end
    function frame:SetScript(script, callback) self[script] = callback end
    whisperListener = frame
    return frame
end
C_AddOns.IsAddOnLoaded = function() return false end
loadModule(SMK, "Core/App.lua")
CreateFrame = originalCreateFrame
C_AddOns.IsAddOnLoaded = originalIsAddOnLoaded
assert(whisperListener.registered.ADDON_LOADED
    and whisperListener.registered.CHAT_MSG_WHISPER
    and whisperListener.registered.CHAT_MSG_WHISPER_INFORM
    and whisperListener.registered.CHAT_MSG_BN_WHISPER
    and whisperListener.registered.CHAT_MSG_BN_WHISPER_INFORM
    and not whisperListener.registered.CHAT_MSG_CHANNEL,
    "app did not register exactly the supported whisper sources")
local originalWorldMapFrame = WorldMapFrame
local originalSettingsGet = SMK.Settings.Get
local originalGetPlayerMapID = SMK.Map.GetPlayerMapID
local originalRecordUsage = SMK.Store.RecordUsage
local originalShowTargetHighlight = SMK.MapPins.ShowTargetHighlight
local originalClosePanel = SMK.SearchBar.ClosePanel
local originalIsMapMode = SMK.SearchBar.IsMapMode
local originalShowForMap = SMK.SearchBar.ShowForMap
local originalFocus = SMK.SearchBar.Focus
local originalTimerAfter = C_Timer.After
local originalPlaySound, originalSoundKit = PlaySound, SOUNDKIT
local originalOpenWorldMap = C_Map.OpenWorldMap
local openedMap = { shown = false, mapID = 100 }
function openedMap:IsShown() return self.shown end
function openedMap:Show() self.shown = true end
function openedMap:GetMapID() return self.mapID end
function openedMap:SetMapID(mapID) self.mapID = mapID end
WorldMapFrame = openedMap
mapInfo[200] = { name = "跨地图测试", mapType = Enum.UIMapType.Zone }
local nativeOpenMapID
C_Map.OpenWorldMap = function(mapID)
    nativeOpenMapID = mapID
    openedMap.shown = true
    openedMap.mapID = mapID
end
SMK.Settings.Get = function(_, key)
    if key == "searchAllMaps" then return true end
    return originalSettingsGet(SMK.Settings, key)
end
SMK.Map.GetPlayerMapID = function() return 100 end
SMK.Store.RecordUsage = function() return true end
local closedPanels, shownForMap, focusedSearch = 0, 0, 0
SMK.SearchBar.ClosePanel = function() closedPanels = closedPanels + 1 end
SMK.SearchBar.IsMapMode = function() return false end
SMK.SearchBar.ShowForMap = function() shownForMap = shownForMap + 1 end
SMK.SearchBar.Focus = function() focusedSearch = focusedSearch + 1 end
local highlightedEntry, pendingHighlight
SMK.MapPins.ShowTargetHighlight = function(_, entry)
    highlightedEntry = entry
    return true
end
C_Timer.After = function(_, callback) pendingHighlight = callback end
local playedSound
PlaySound = function(soundID) playedSound = soundID end
SOUNDKIT = {
    UI_MAP_WAYPOINT_SUPER_TRACK_ON = 1,
    UI_MAP_WAYPOINT_BUTTON_CLICK_OFF = 2,
}
assert(SMK.App:Activate({ isMapPortal = true, mapID = 200 }, true) == nil
    and nativeOpenMapID == 200 and openedMap.shown and openedMap.mapID == 200
    and closedPanels == 1 and shownForMap == 1 and focusedSearch == 1
    and playedSound == SMK.Config.share.portalSoundID,
    "hidden-map portal result did not use the native map flow or restore the search bar")
openedMap.shown, openedMap.mapID = false, 100
nativeOpenMapID, playedSound = nil, nil
local crossMapSavedEntry = {
    id = 999, source = "saved", mapID = 200, x = 25, y = 75,
    name = "跨地图地点",
}
assert(SMK.App:Activate(crossMapSavedEntry, true)
    and nativeOpenMapID == 200 and openedMap.shown and openedMap.mapID == 200
    and context.waypoint.uiMapID == 200
    and pendingHighlight and not highlightedEntry
    and playedSound == SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON,
    "all-map saved result did not open its target map and set a waypoint")
pendingHighlight()
assert(highlightedEntry == crossMapSavedEntry,
    "all-map saved result did not highlight after the target map was ready")
openedMap.shown, openedMap.mapID = false, 100
highlightedEntry, pendingHighlight, playedSound = nil, nil, nil
local currentMapSavedEntry = {
    id = 1000, source = "saved", mapID = 100, x = 30, y = 60,
    name = "当前地图地点",
}
assert(SMK.App:Activate(currentMapSavedEntry, true)
    and not openedMap.shown and context.waypoint.uiMapID == 100
    and highlightedEntry == currentMapSavedEntry and not pendingHighlight,
    "all-map current-map result unexpectedly opened the world map")
WorldMapFrame = originalWorldMapFrame
SMK.Settings.Get = originalSettingsGet
SMK.Map.GetPlayerMapID = originalGetPlayerMapID
SMK.Store.RecordUsage = originalRecordUsage
SMK.MapPins.ShowTargetHighlight = originalShowTargetHighlight
SMK.SearchBar.ClosePanel = originalClosePanel
SMK.SearchBar.IsMapMode = originalIsMapMode
SMK.SearchBar.ShowForMap = originalShowForMap
SMK.SearchBar.Focus = originalFocus
C_Timer.After = originalTimerAfter
PlaySound, SOUNDKIT = originalPlaySound, originalSoundKit
C_Map.OpenWorldMap = originalOpenWorldMap
local whisperEntry = assert(SMK.LocationModel:Normalize({
    mapID = 9090, x = 12.34, y = 56.78, name = "Whisper Import",
    categoryKey = "other",
}))
SMK.WhisperInbox.codes = {}
whisperListener.OnEvent(whisperListener, "CHAT_MSG_WHISPER",
    "sender: " .. SMK.ShareCodec:Encode({ whisperEntry }))
assert(#SMK.WhisperInbox:GetAll() == 1, "whisper event did not capture an SMK code")
SMK.ShareDialog:ImportWhispers()
assert(SMK.Store:FindDuplicate(whisperEntry),
    "captured whisper SMK code was not imported through the share dialog")
