local context = assert(...)
local SMK = context.SMK
local root = context.root
local mapInfo = context.mapInfo
local mapChildren = context.mapChildren

mapInfo[946] = { name = "Cosmic", mapType = Enum.UIMapType.Cosmic }
mapChildren[946] = {}
assert(not SMK.MapIndex:Rebuild(true), "empty map index was marked ready")
for _, index in ipairs({ 8, 2, 7, 1, 6, 3, 5, 4 }) do
    local mapID = 1000 + index
    mapInfo[mapID] = { name = "Map " .. index, mapType = Enum.UIMapType.Zone }
    mapChildren[946][#mapChildren[946] + 1] = { mapID = mapID }
end
mapInfo[947] = { name = "Duplicate Root", mapType = Enum.UIMapType.Cosmic }
mapChildren[947] = { { mapID = 1001 } }
assert(SMK.MapIndex:Rebuild(true), "map index build failed")
local mapMatches = SMK.MapIndex:Search("Map")
assert(#mapMatches == 5, "map result limit failed")
local seenMapIDs = {}
for resultIndex, match in ipairs(mapMatches) do
    assert(not seenMapIDs[match.entry.mapID], "map index contains duplicates")
    assert(match.entry.mapID == 1000 + resultIndex,
        "bounded map candidates changed deterministic ordering")
    seenMapIDs[match.entry.mapID] = true
end
local mapIndexCallbacks = {}
local originalMapIndexBatchSize = SMK.Config.mapIndex.buildBatchSize
SMK.Config.mapIndex.buildBatchSize = 2
C_Timer = {
    After = function(_, callback)
        mapIndexCallbacks[#mapIndexCallbacks + 1] = callback
    end,
}
local mapIndexBuildSucceeded
SMK.MapIndex:SetBuildHandler(function(success) mapIndexBuildSucceeded = success end)
local acceptedMapBuild, mapBuildPending = SMK.MapIndex:Rebuild(true)
assert(acceptedMapBuild and mapBuildPending and SMK.MapIndex:IsBuilding()
    and #mapIndexCallbacks == 1,
    "map index was not started asynchronously")
while #mapIndexCallbacks > 0 do
    table.remove(mapIndexCallbacks, 1)()
end
assert(mapIndexBuildSucceeded and not SMK.MapIndex:IsBuilding()
    and #SMK.MapIndex:Search("Map") == 5,
    "asynchronous map index was not published")
SMK.MapIndex:SetBuildHandler(nil)
SMK.Config.mapIndex.buildBatchSize = originalMapIndexBatchSize
C_Timer = nil

local function ReadSource(path)
    local file = assert(io.open(root .. "/" .. path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end
local appSource = ReadSource("Core/App.lua")
local mapControllerSource = ReadSource("Core/WorldMapController.lua")
local mainPanelSource = ReadSource("UI/MainPanel.lua")
local shareDialogSource = ReadSource("UI/ShareDialog.lua")
local iconGridSource = ReadSource("UI/IconGridPicker.lua")
local widgetsSource = ReadSource("UI/Widgets.lua")
local panelSettingsSource = ReadSource("UI/PanelSettings.lua")

SMK.testOriginalGetPanelEntries = SMK.MapContext.GetEntries
SMK.testPanelEntries = {
    { id = 1, categoryKey = "other", showPinTexture = 1, name = "标记地点" },
    { id = 2, categoryKey = "other", note = "备注", name = "备注地点" },
    { id = 3, categoryKey = "npc", customIconID = 1, name = "图标地点" },
    { id = 4, categoryKey = "raids", name = "普通地点" },
}
SMK.MapContext.GetEntries = function() return SMK.testPanelEntries end
SMK.MainPanel.filteredEntries = {}
SMK.MainPanel.locationFilter = "all"
assert(#SMK.MainPanel:GetDisplayedEntries() == 4, "all-locations panel filter removed entries")
SMK.MainPanel.locationFilter = "category:npc"
assert(#SMK.MainPanel:GetDisplayedEntries() == 1
    and SMK.MainPanel:GetDisplayedEntries()[1].id == 3,
    "category panel filter returned the wrong entries")
SMK.MainPanel.locationFilter = "pins"
assert(#SMK.MainPanel:GetDisplayedEntries() == 1
    and SMK.MainPanel:GetDisplayedEntries()[1].id == 1,
    "map-pin panel filter returned the wrong entries")
SMK.MainPanel.locationFilter = "notes"
assert(#SMK.MainPanel:GetDisplayedEntries() == 1
    and SMK.MainPanel:GetDisplayedEntries()[1].id == 2,
    "note panel filter returned the wrong entries")
SMK.MainPanel.locationFilter = "customIcon"
assert(#SMK.MainPanel:GetDisplayedEntries() == 1
    and SMK.MainPanel:GetDisplayedEntries()[1].id == 3,
    "custom-icon panel filter returned the wrong entries")
SMK.MainPanel.locationFilter = "all"
SMK.MapContext.GetEntries = SMK.testOriginalGetPanelEntries
SMK.testOriginalGetPanelEntries, SMK.testPanelEntries = nil, nil

assert(appSource:find("HandyNotesProvider:SetChangeHandler", 1, true)
    and appSource:find("RequestRefresh(\"external\")", 1, true)
    and appSource:find("RequestMapRefresh(mapID, false)", 1, true)
    and not appSource:find("RequestMapRefresh(mapID, true)", 1, true)
    and mapControllerSource:find("GetPlayerMapID(), false", 1, true)
    and not mapControllerSource:find("GetPlayerMapID(), true", 1, true),
    "routine map lifecycle still forces HandyNotes cache rebuilds")
assert(mapControllerSource:find("SetBuildHandler", 1, true)
    and appSource:find("onMapIndexReady", 1, true),
    "asynchronous map index completion is not connected to search refresh")
assert(not appSource:find("local collected = {}", 1, true)
    and not appSource:find("GetMessageInfo", 1, true)
    and not appSource:find("function App:ImportWhispers", 1, true)
    and not mainPanelSource:find("SMK.L.CHAT_IMPORT", 1, true)
    and shareDialogSource:find("SMK.WhisperInbox:GetImportText", 1, true)
    and shareDialogSource:find("self:PreviewImport(text, false)", 1, true),
    "whisper import is outside the share dialog or scans chat frames")
assert(not panelSettingsSource:find("showPinTexturesCheck", 1, true)
    and not panelSettingsSource:find("showPinNamesCheck", 1, true)
    and not panelSettingsSource:find("ColorPickerFrame", 1, true)
    and panelSettingsSource:find("pinTextureScale", 1, true)
    and panelSettingsSource:find("mapPinTextScale", 1, true)
    and panelSettingsSource:find("mapPinNameOffsetX", 1, true)
    and panelSettingsSource:find("mapPinNameOffsetY", 1, true),
    "pin settings panel retained global visibility/color controls or lost appearance controls")
assert(iconGridSource:find("SetAtlas(SMK.Config.panel.backgroundAtlas, false)", 1, true)
    and iconGridSource:find("SMK.Widgets:ApplyPanelBorder(frame)", 1, true),
    "icon selection popup does not use the main panel background atlas")
assert(mainPanelSource:find("BuildListLayout", 1, true)
    and mainPanelSource:find("RenderVisibleList", 1, true)
    and mainPanelSource:find("widgetPools", 1, true)
    and mainPanelSource:find("renderedFirst == first", 1, true)
    and mainPanelSource:find("self.listLayoutCount = 0", 1, true)
    and mainPanelSource:find("function MainPanel:GetDisplayedEntries()", 1, true)
    and mainPanelSource:find("self.filterDropdown:IsMenuOpen()", 1, true)
    and widgetsSource:find("ReleaseLocationButton", 1, true)
    and widgetsSource:find("geometryCacheKeys", 1, true)
    and appSource:find("usage = { frequent = true }", 1, true)
    and appSource:find("SMK.MainPanel:RenderFrequent()", 1, true),
    "main panel virtualization, bounded caches, or usage-only refresh regressed")

context.waypoint = UiMapPoint.CreateFromCoordinates(200, 0.2, 0.3)
context.superTracked = true
assert(SMK.Map:BeginTemporaryWaypoint({ mapID = 100, x = 40, y = 50 }), "temporary waypoint failed")
assert(context.waypoint.uiMapID == 100, "temporary waypoint was not set")
SMK.Map:ClearTemporaryWaypoint()
assert(context.waypoint.uiMapID == 200 and context.waypoint.position.x == 0.2 and context.superTracked,
    "previous waypoint was not restored")

function Mixin(target, ...)
    for index = 1, select("#", ...) do
        for key, value in pairs(select(index, ...)) do target[key] = value end
    end
    return target
end
function CreateFromMixins(...) return Mixin({}, ...) end
MapCanvasDataProviderMixin = { GetMap = function(self) return self.map end }
MapCanvasPinMixin = {
    UseFrameLevelType = function(self, value) self.frameLevelType = value end,
    SetScalingLimits = function() end,
    SetPosition = function(self, x, y) self.x, self.y = x, y end,
}
function CreateUnsecuredRegionPoolInstance() return {} end
local function NewTexture()
    return {
        SetAllPoints = function() end,
        SetAtlas = function(self, atlas) self.atlas = atlas end,
        SetPoint = function() end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        SetTexture = function(self, texture) self.texture = texture end,
        SetBlendMode = function(self, blendMode) self.blendMode = blendMode end,
        SetVertexColor = function(self, r, g, b) self.color = { r = r, g = g, b = b } end,
        CreateAnimationGroup = function(self)
            local group = {
                CreateAnimation = function()
                    return {
                        SetFromAlpha = function() end,
                        SetToAlpha = function() end,
                        SetDuration = function() end,
                        SetOrder = function() end,
                    }
                end,
                SetLooping = function() end,
                Play = function(groupSelf) groupSelf.playing = true end,
                Stop = function(groupSelf) groupSelf.playing = false end,
            }
            self.animationGroup = group
            return group
        end,
        Show = function(self) self.shown = true end,
        SetShown = function(self, value) self.shown = value end,
        Hide = function(self) self.shown = false end,
    }
end
local function NewFontString()
    return {
        ClearAllPoints = function() end,
        SetPoint = function(self, ...) self.point = { ... } end,
        SetTextColor = function(self, r, g, b) self.color = { r = r, g = g, b = b } end,
        SetScale = function(self, value) self.scale = value end,
        SetText = function(self, value) self.text = value end,
        SetShown = function(self, value) self.shown = value end,
        Hide = function(self) self.shown = false end,
    }
end
function CreateFrame()
    return {
        EnableMouse = function() end,
        RegisterForClicks = function(self, ...) self.registeredClicks = { ... } end,
        SetScript = function(self, event, callback)
            self.scripts = self.scripts or {}
            self.scripts[event] = callback
        end,
        SetAllPoints = function(self, target) self.allPointsTarget = target end,
        CreateTexture = function() return NewTexture() end,
        CreateFontString = function() return NewFontString() end,
        SetSize = function() end,
        SetShown = function(self, value) self.shown = value end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        ClearAllPoints = function() end,
        GetLeft = function() return 10 end,
        GetRight = function() return 30 end,
        GetBottom = function() return 20 end,
        GetTop = function() return 40 end,
    }
end
GameTooltip = {
    SetOwner = function() end,
    SetText = function(self, value) self.title = value end,
    AddLine = function(self, value, ...)
        self.lines = self.lines or {}
        self.lines[#self.lines + 1] = value
        self.lineColors = self.lineColors or {}
        self.lineColors[#self.lines] = { ... }
    end,
    Show = function(self) self.shown = true end,
}
function GameTooltip_Hide() end

context.appSource = appSource
context.mainPanelSource = mainPanelSource
context.widgetsSource = widgetsSource
context.panelSettingsSource = panelSettingsSource
context.readSource = ReadSource
