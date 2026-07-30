local root = assert(arg[1], "usage: lua Tests/RouteTest.lua <addon-root>")

function GetLocale() return "zhCN" end
C_AddOns = { GetAddOnMetadata = function() return "test" end }

local function Load(namespace, path)
    return assert(loadfile(root .. "/" .. path))("SearchMaker", namespace)
end

local SMK = {}
for _, path in ipairs({
    "Core/Namespace.lua", "Core/AtlasTextures.lua", "Core/PathTextures.lua",
    "Core/IconCatalog.lua", "Core/PinTextures.lua", "Config.lua",
    "Locales/init.lua", "Locales/enUS.lua", "Locales/zhCN.lua",
    "Core/LocationModel.lua", "Core/RouteStore.lua", "Core/SettingsSchema.lua",
    "Core/Database.lua", "Core/RouteService.lua", "Core/RouteCodec.lua",
    "Core/SearchService.lua", "Core/ShareCodec.lua",
}) do
    Load(SMK, path)
end

SearchMakerDB = {}
SMK.DB:Initialize()
assert(type(SearchMakerDB.savedRoutes) == "table"
    and SearchMakerDB.nextRouteID == 1
    and SearchMakerDB.activeRoute == nil,
    "database did not initialize persistent routes independently of session state")
assert(type(SMK.Config.route.searchIcon) == "string"
    and SMK.Config.route.searchIcon:find("^Interface\\")
    and SMK.Config.route.searchIconID == nil,
    "saved route search icon is not a standalone texture path")

local first = assert(SMK.RouteStore:Add({
    name = "银月路线",
    items = {
        { mapID = 2393, x = 61.69, y = 51.47, name = "理发师", note = "不应保存" },
        { mapID = 2395, x = 53.59, y = 70.11, name = "传送门" },
    },
}))
assert(first.id == 1 and #first.items == 2
    and SearchMakerDB.savedRoutes[1].items[1].note == nil,
    "saved route retained fields outside map ID, name, and coordinates")
local duplicate, duplicateReason = SMK.RouteStore:Add({
    name = " 银月路线 ",
    items = { { mapID = 1, x = 10, y = 20, name = "重复路线" } },
})
assert(not duplicate and duplicateReason == "DUPLICATE_ROUTE_NAME"
    and #SearchMakerDB.savedRoutes == 1,
    "normalized duplicate route names were accepted")

local encoded = assert(SMK.RouteCodec:Encode(first))
local decoded = assert(SMK.RouteCodec:Decode(encoded))
assert(encoded:sub(1, 6) == "SMK|R|"
    and decoded.name == first.name
    and decoded.items[1].mapID == 2393
    and decoded.items[1].x == 61.69
    and decoded.items[1].name == "理发师",
    "route share format did not round-trip")
assert(SMK.ShareCodec:FindShareText("whisper " .. encoded) == nil,
    "route share text leaked into the location whisper importer")
assert(not SMK.RouteCodec:Decode("SMK|2393,6169,5147"),
    "location share text was accepted as a route")

assert(#SMK.Search:Find({}, "路", false, 2393, {}) == 0
    and #SMK.Search:Find({}, "线", true, 2393, {}) == 0,
    "a partial Chinese route keyword exposed saved routes")
local routeMatches = SMK.Search:Find({}, "路线", false, 2393, {})
local filteredMatches = SMK.Search:Find({}, "路线银月", true, 2393, {})
assert(#routeMatches == 1 and routeMatches[1].entry.id == first.id
    and routeMatches[1].isSavedRoute
    and #filteredMatches == 1 and filteredMatches[1].entry.id == first.id,
    "saved routes were not searchable in both scopes by the complete keyword")

for index = 1, 24 do
    assert(SMK.RouteStore:Add({
        name = "路线测试" .. index,
        items = { { mapID = index, x = index, y = index, name = "点" .. index } },
    }))
end
assert(#SMK.Search:Find({}, "路线", false, 2393, {}) == 20,
    "saved route search exceeded the shared 20-result limit")

local activated
SMK.Route:SetActivateHandler(function(entry)
    activated = (activated or 0) + 1
    return entry.mapID ~= nil
end)
assert(SMK.Route:ActivateSavedRoute(first)
    and SMK.Route:IsSavedRouteActive(first)
    and SMK.Route:GetCurrentIndex() == 1
    and activated == 1,
    "saved route did not become the single session route")
local repeated, repeatedReason = SMK.Route:ActivateSavedRoute(first)
assert(not repeated and repeatedReason == "ROUTE_ALREADY_ACTIVE" and activated == 1,
    "an active saved route was activated twice")
SMK.Route:SetActivateHandler(function() return false end)
local failed, failedReason = SMK.Route:ActivateSavedRoute(SMK.RouteStore:GetByID(2))
assert(not failed and failedReason == "ACTIVATE_FAILED"
    and SMK.Route:IsSavedRouteActive(first)
    and SMK.Route:GetCurrentIndex() == 1
    and SMK.Route:GetItems()[1].mapID == first.items[1].mapID,
    "failed saved-route activation replaced the current route")
SMK.Route:SetActivateHandler(function(entry)
    activated = activated + 1
    return entry.mapID ~= nil
end)
assert(SMK.Route:CompleteCurrent()
    and SMK.Route:IsSavedRouteActive(first)
    and activated == 2,
    "completing one point lost the active saved-route identity")
assert(SMK.Route:CompleteCurrent()
    and not SMK.Route:IsSavedRouteActive(first)
    and #SMK.Route:GetItems() == 0,
    "completed saved route remained active")

assert(SMK.Route:Add({ mapID = 10, x = 10, y = 10, name = "临时一" }))
assert(SMK.Route:Add({ mapID = 20, x = 20, y = 20, name = "临时二" }))
SMK.Route:SetActivateHandler(function() return true end)
assert(SMK.Route:Activate(1) and SMK.Route:GetCurrentIndex() == 1,
    "regular route did not activate")
SMK.Route:SetActivateHandler(function() return false end)
local moveFailed, moveReason = SMK.Route:Activate(2)
assert(not moveFailed and moveReason == "ACTIVATE_FAILED"
    and SMK.Route:GetCurrentIndex() == 1,
    "failed waypoint activation changed the active route index")
SMK.Route:Clear()

for _, entry in ipairs({
    { mapID = 10, x = 90, y = 0, name = "同图远点" },
    { mapID = 10, x = 10, y = 0, name = "同图近点" },
    { mapID = 10, x = 20, y = 0, name = "同图中点" },
    { mapID = 20, x = 80, y = 0, name = "异图入口" },
    { mapID = 20, x = 10, y = 0, name = "异图远点" },
    { mapID = 20, x = 70, y = 0, name = "异图近点" },
}) do
    assert(SMK.Route:Add(entry))
end
assert(SMK.Route:SortByNearest(10, 0, 0), "route nearest sort did not run")
local sortedItems = SMK.Route:GetItems()
assert(sortedItems[1].name == "同图近点"
    and sortedItems[2].name == "同图中点"
    and sortedItems[3].name == "同图远点"
    and sortedItems[4].name == "异图入口"
    and sortedItems[5].name == "异图近点"
    and sortedItems[6].name == "异图远点",
    "route nearest sort crossed map sections or used the wrong starting point")
local sortedAgain, sortedReason = SMK.Route:SortByNearest(10, 0, 0)
assert(not sortedAgain and sortedReason == "ROUTE_ALREADY_SORTED",
    "an already sorted route reported another change")
SMK.Route:SetActivateHandler(function() return true end)
assert(SMK.Route:Activate(1))
local activeSort, activeSortReason = SMK.Route:SortByNearest(10, 0, 0)
assert(not activeSort and activeSortReason == "ROUTE_ACTIVE",
    "active route was reordered")
SMK.Route:Clear()
assert(SearchMakerDB.activeRoute == nil and SearchMakerDB.currentRoute == nil,
    "session route leaked into SavedVariables")

assert(SMK.RouteStore:Delete(first) == 1
    and SMK.RouteStore:GetByID(first.id) == nil,
    "saved route was not deleted")
assert(not SMK.RouteStore:Add({ name = "", items = {} }),
    "invalid empty route was saved")

local appFile = assert(io.open(root .. "/Core/App.lua", "r"))
local appSource = appFile:read("*a")
appFile:close()
local openRouteBlock = assert(appSource:match(
    "function App:OpenSavedRoute.-\nend"))
assert(openRouteBlock:find("SMK.RouteDialog:OpenSaved", 1, true)
    and openRouteBlock:find("SMK.SearchBar:ClosePanel()", 1, true)
    and not openRouteBlock:find("SMK.MainPanel", 1, true),
    "opening a saved route also opened or depended on the main panel")

local menuFile = assert(io.open(root .. "/UI/LocationContextMenu.lua", "r"))
local menuSource = menuFile:read("*a")
menuFile:close()
for _, localeKey in ipairs({
    "MENU_OPEN_ROUTE", "MENU_ACTIVATE_ROUTE", "MENU_SHARE_ROUTE", "MENU_DELETE_ROUTE",
}) do
    assert(menuSource:find(localeKey, 1, true),
        "saved route context menu is missing " .. localeKey)
end

print("SearchMaker route tests passed")
