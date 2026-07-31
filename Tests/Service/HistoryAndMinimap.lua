local context = assert(...)
local SMK = context.SMK

for index = 1, 12 do
    assert(SMK.SearchHistory:RecordQuery("搜索" .. index),
        "search query history rejected a valid query")
end
assert(#SMK.SearchHistory:GetQueries() == 10
    and SMK.SearchHistory:GetQueries()[1] == "搜索12"
    and SMK.SearchHistory:GetQueries()[10] == "搜索3",
    "search query history did not keep the newest ten entries")
SMK.SearchHistory:RecordQuery("搜索5")
assert(SMK.SearchHistory:GetQueries()[1] == "搜索5"
    and #SMK.SearchHistory:GetQueries() == 10,
    "repeated search query was not moved to the front")

local saved = assert(SMK.Store:Add({
    mapID = 100, x = 31, y = 42, name = "最近地点", categoryKey = "other",
}))
assert(SMK.SearchHistory:RecordResult(saved)
    and SMK.SearchHistory:RecordResult({
        mapID = 200, name = "最近地图", isMapPortal = true,
    })
    and SMK.SearchHistory:RecordResult({
        mapID = 100, x = 12, y = 34, name = "临时搜索结果",
        categoryKey = "other", isCoordinateResult = true,
    }),
    "recent search result rejected a supported result type")
local recent = SMK.SearchHistory:GetRecentResults()
assert(#recent == 3 and recent[1].name == "临时搜索结果"
    and recent[2].isMapPortal and recent[3].id == saved.id,
    "recent search results were not resolved newest first")
SMK.SearchHistory:RecordResult(saved)
recent = SMK.SearchHistory:GetRecentResults()
assert(#recent == 3 and recent[1].id == saved.id,
    "repeated recent result was not moved to the front")

local searchResultsSource = assert(io.open(
    context.root .. "/UI/SearchResults.lua", "r")):read("*a")
local searchBarSource = assert(io.open(
    context.root .. "/UI/SearchBar.lua", "r")):read("*a")
local editorSource = assert(io.open(
    context.root .. "/UI/LocationEditor.lua", "r")):read("*a")
local mainPanelSource = assert(io.open(
    context.root .. "/UI/MainPanel.lua", "r")):read("*a")
local minimapSource = assert(io.open(
    context.root .. "/Core/MinimapPinProvider.lua", "r")):read("*a")
assert(searchResultsSource:find("function SearchResults:RenderHistory", 1, true)
    and searchResultsSource:find("Config.colors.searchMatch", 1, true)
    and searchBarSource:find("SMK.SearchHistory:RecordQuery(query)", 1, true),
    "search history dropdown or match highlighting is not wired")
local historyRendered, historyHidden = 0, 0
local panelExpanded = true
local historySearchBar = setmetatable({
    panel = {
        IsExpanded = function() return panelExpanded end,
        SetSearchActive = function() end,
    },
    searchResults = {
        Hide = function() historyHidden = historyHidden + 1 end,
        RenderHistory = function() historyRendered = historyRendered + 1 end,
    },
}, { __index = SMK.SearchBar })
historySearchBar:ShowHistory()
assert(historyRendered == 0 and historyHidden == 1,
    "search history remained visible while the main panel was open")
panelExpanded = false
historySearchBar:ShowHistory()
assert(historyRendered == 1,
    "search history did not remain available while the main panel was closed")
local spacedRanges = SMK.Util.GetNormalizedMatchRanges("SilverMoon", "Silver Moon")
assert(#spacedRanges == 1 and spacedRanges[1].first == 1
    and spacedRanges[1].last == #"SilverMoon",
    "match highlighting did not use whitespace-insensitive normalization")
local unicodeRanges = SMK.Util.GetNormalizedMatchRanges("Москва", "МОСКВА")
assert(#unicodeRanges == 1 and unicodeRanges[1].first == 1
    and unicodeRanges[1].last == #"Москва",
    "match highlighting did not use Unicode case folding")
assert(mainPanelSource:find("function MainPanel:RenderRecentSearchResults()", 1, true)
    and mainPanelSource:find("SMK.L.RECENT_SEARCH_RESULTS", 1, true)
    and SMK.Config.search.recentResultLimit == 10,
    "main panel recent search results are not wired")
assert(SMK.Config.locationEditor.dropdownBorderOutset == 5
    and editorSource:find("EditorConfig.inputWidth + dropdownOutset * 2", 1, true),
    "category dropdown border is not aligned with the input field")
assert(minimapSource:find("pin.icon:SetAtlas(texture.atlas, false)", 1, true)
    and minimapSource:find(
        "updater:SetScript(\"OnUpdate\", function() self:UpdatePositions() end)",
        1, true)
    and minimapSource:find("if entry.showPinTexture == 1 then", 1, true)
    and not minimapSource:find("CreateFontString", 1, true),
    "minimap pins are not texture-only or do not use stable movement")

local oldMinimap, oldUnitPosition = Minimap, UnitPosition
local oldCMinimap, oldGetCVar = C_Minimap, GetCVar
Minimap = {
    GetWidth = function() return 200 end,
    GetHeight = function() return 200 end,
}
UnitPosition = function() return 100, 100, 0, 1 end
C_Minimap = { GetViewRadius = function() return 100 end }
GetCVar = function() return "0" end
local shown, point, pointUpdates = false, nil, 0
local pin = {
    instanceID = 1,
    targetX = 90,
    targetY = 100,
    ClearAllPoints = function() end,
    SetPoint = function(_, ...)
        pointUpdates = pointUpdates + 1
        point = { ... }
    end,
    Show = function() shown = true end,
    Hide = function() shown = false end,
}
SMK.MinimapPins.hbdPins = nil
SMK.MinimapPins.active = { pin }
SMK.MinimapPins.positionDirty = true
SMK.MinimapPins:UpdatePositions(true)
assert(shown and point and point[4] == 10 and point[5] == 0
    and pointUpdates == 1,
    "native minimap fallback did not position an in-range pin")
SMK.MinimapPins:UpdatePositions()
assert(pointUpdates == 1,
    "stationary minimap fallback repositioned unchanged pins")
pin.targetX = -100
SMK.MinimapPins.positionDirty = true
SMK.MinimapPins:UpdatePositions()
assert(not shown, "native minimap fallback did not hide an out-of-range pin")
SMK.MinimapPins.active = {}
local previewIconShown
SMK.MinimapPins.activeByID = {
    [77] = {
        icon = {
            SetShown = function(_, value) previewIconShown = value end,
        },
    },
}
local originalMinimapRefresh = SMK.MinimapPins.Refresh
SMK.MinimapPins.Refresh = function()
    error("single-pin preview rebuilt all minimap pins")
end
SMK.MapPins:UpdatePinPreviewColor({ id = 77 }, { r = 0.1, g = 0.2, b = 0.3 })
SMK.MapPins:UpdatePinVisibility({ id = 77 }, true, true)
SMK.MinimapPins.Refresh = originalMinimapRefresh
assert(previewIconShown == true,
    "minimap editor preview did not update exactly one active texture")
SMK.MinimapPins.activeByID = {}

local oldCreateFrame = CreateFrame
local initializeRefresh = SMK.MinimapPins.Refresh
SMK.MinimapPins.initialized = false
CreateFrame = function() error("simulated frame creation failure") end
local initialized = SMK.MinimapPins:Initialize()
assert(not initialized and not SMK.MinimapPins.initialized,
    "failed minimap initialization poisoned future retries")
local fallbackFrames = {}
CreateFrame = function()
    local frame = {
        Hide = function() end,
        RegisterEvent = function() end,
        SetScript = function(self, script, callback) self[script] = callback end,
        UnregisterAllEvents = function() end,
    }
    fallbackFrames[#fallbackFrames + 1] = frame
    return frame
end
SMK.MinimapPins.Refresh = function() end
assert(SMK.MinimapPins:Initialize() and SMK.MinimapPins.initialized
    and SMK.MinimapPins:Initialize(),
    "minimap initialization did not recover on retry")
local fallbackUpdates = 0
local originalUpdatePositions = SMK.MinimapPins.UpdatePositions
SMK.MinimapPins.UpdatePositions = function() fallbackUpdates = fallbackUpdates + 1 end
assert(fallbackFrames[1] and fallbackFrames[1].OnUpdate,
    "native minimap fallback did not create a frame-synchronized updater")
fallbackFrames[1].OnUpdate()
SMK.MinimapPins.UpdatePositions = originalUpdatePositions
assert(fallbackUpdates == 1,
    "native minimap fallback did not update on the next rendered frame")
SMK.MinimapPins.initialized = false
SMK.MinimapPins.hbdPins, SMK.MinimapPins.updater, SMK.MinimapPins.events = nil, nil, nil
SMK.MinimapPins.Refresh = initializeRefresh
CreateFrame = oldCreateFrame
Minimap, UnitPosition = oldMinimap, oldUnitPosition
C_Minimap, GetCVar = oldCMinimap, oldGetCVar
