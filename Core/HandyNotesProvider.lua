local _, SMK = ...

local HandyNotesProvider = {}
local pluginName = "MapNotes"
local cache = {}
local npcInfoCache = {}

local function ParseCoord(coord)
    local x = math.floor(coord / 10000) / 10000 * 100
    local y = (coord % 10000) / 10000 * 100
    return x, y
end

local function ContainsHan(text)
    return tostring(text or ""):find("[\228-\233][\128-\191][\128-\191]") ~= nil
end

local function CleanText(text)
    if type(text) ~= "string" then return nil end
    local value = text
        :gsub("|T.-|t", "")
        :gsub("|A.-|a", "")
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
    value = SMK.Util.Trim(value)
    return value ~= "" and value or nil
end

local function IsLocalizedText(text)
    if SMK.locale == "zhCN" or SMK.locale == "zhTW" then
        return ContainsHan(text)
    end
    return text ~= nil and text ~= ""
end

local function ReadMapNotesNpcCache(npcID)
    local db = HandyNotes_MapNotesRetailNpcCacheDB
    local localeNames = db and db.names and db.names[SMK.locale]
    local packed = localeNames and (localeNames[tonumber(npcID)] or localeNames[npcID])
    if type(packed) ~= "string" then return nil, nil end
    local name, title = packed:match("^(.-)\031(.*)$")
    return CleanText(name), CleanText(title)
end

local function ReadNpcTooltip(npcID)
    if not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then return nil, nil end
    local ok, tooltipData = pcall(C_TooltipInfo.GetHyperlink,
        "unit:Creature-0-0-0-0-" .. tostring(npcID) .. "-0000000000")
    if not ok or not tooltipData then return nil, nil end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        TooltipUtil.SurfaceArgs(tooltipData)
        for index = 1, math.min(2, #(tooltipData.lines or {})) do
            TooltipUtil.SurfaceArgs(tooltipData.lines[index])
        end
    end
    local lines = tooltipData.lines or {}
    return CleanText(lines[1] and lines[1].leftText),
        CleanText(lines[2] and lines[2].leftText)
end

local function GetNpcInfo(npcID)
    local key = tostring(SMK.locale) .. ":" .. tostring(npcID)
    local cached = npcInfoCache[key]
    if cached then return cached.name, cached.title end

    local name, title = ReadMapNotesNpcCache(npcID)
    if not name or not title then
        local tooltipName, tooltipTitle = ReadNpcTooltip(npcID)
        name = name or tooltipName
        title = title or tooltipTitle
    end
    if not name and C_CreatureInfo and C_CreatureInfo.GetCreatureName then
        name = CleanText(C_CreatureInfo.GetCreatureName(npcID))
    end
    if name == _G.RETRIEVING_DATA or name == _G.UNKNOWNOBJECT then
        name, title = nil, nil
    end
    if name then
        npcInfoCache[key] = { name = name, title = title }
    end
    return name, title
end

local function AddSearchText(parts, seen, text)
    local value = CleanText(text)
    if not value or not IsLocalizedText(value) or seen[value] then return end
    seen[value] = true
    parts[#parts + 1] = value
end

local function GetTypeDisplay(nodeData)
    local nodeType = type(nodeData.type) == "string" and nodeData.type or ""
    if not nodeType:find("Portal", 1, true) then return nil end
    local label = SMK.L.HANDYNOTES_PORTAL
    local mapInfo = nodeData.mnID and SMK.Map:GetMapInfo(nodeData.mnID)
    local destination = CleanText(mapInfo and mapInfo.name)
    return label, destination and string.format(SMK.L.SEARCH_RESULT_FORMAT, label, destination) or label
end

local function BuildNodeText(nodeData)
    local parts, seen = {}, {}
    local directNames = {
        CleanText(nodeData.name) or false,
        CleanText(nodeData.label) or false,
        CleanText(nodeData.dnID) or false,
    }
    for _, value in ipairs(directNames) do
        AddSearchText(parts, seen, value)
    end

    if SMK.locale == "zhCN" or SMK.locale == "zhTW" then
        for _, value in pairs(nodeData) do
            if type(value) == "string" then
                AddSearchText(parts, seen, value)
            end
        end
    end

    local npcNames, npcTitles = {}, {}
    local function AddNpc(npcID)
        if not npcID then return end
        local name, title = GetNpcInfo(npcID)
        title = title and (title:match("^<(.+)>$") or title)
        AddSearchText(parts, seen, name)
        AddSearchText(parts, seen, title)
        if title and IsLocalizedText(title) then
            npcTitles[#npcTitles + 1] = title
        end
        if name and IsLocalizedText(name) then
            npcNames[#npcNames + 1] = name
        end
    end
    AddNpc(nodeData.npcID)
    for index = 1, 10 do
        AddNpc(nodeData["npcIDs" .. index])
    end

    local typeLabel, typeDisplay = GetTypeDisplay(nodeData)
    AddSearchText(parts, seen, typeLabel)
    AddSearchText(parts, seen, typeDisplay)

    local displayName = npcTitles[1]
    for _, value in ipairs(directNames) do
        if not displayName and value and IsLocalizedText(value) then
            displayName = value:gsub("\n.*", "")
            break
        end
    end
    displayName = displayName or typeDisplay or npcNames[1]
    if not displayName and SMK.locale ~= "zhCN" and SMK.locale ~= "zhTW" then
        displayName = CleanText(nodeData.type)
            or (nodeData.npcID and "NPC:" .. tostring(nodeData.npcID))
    end
    AddSearchText(parts, seen, displayName)
    return displayName, table.concat(parts, " ")
end

function HandyNotesProvider:RebuildCache()
    cache = {}
    if not HandyNotes or not HandyNotes.plugins or not HandyNotes.plugins[pluginName] then return end
    local plugin = HandyNotes.plugins[pluginName]
    if not plugin.GetNodes2 then return end

    local mapID = SMK.Map:GetContextMapID()
    if not mapID then return end

    local ok, iterFunc, tbl = pcall(plugin.GetNodes2, plugin, mapID, false)
    if not ok then return end
    if not iterFunc or not tbl or not tbl.data then return end

    local nodes = {}
    local coord, _, iconTexture = iterFunc(tbl, nil)
    while coord do
        local nodeData = tbl.data[coord]
        if nodeData then
            local displayName, searchable = BuildNodeText(nodeData)
            if displayName and searchable ~= "" then
                local x, y = ParseCoord(coord)
                if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                    displayName = SMK.Util.Trim(displayName)
                    nodes[#nodes + 1] = {
                        mapID = mapID,
                        x = math.floor(x * 100 + 0.5) / 100,
                        y = math.floor(y * 100 + 0.5) / 100,
                        name = displayName,
                        categoryKey = "other",
                        isExternal = true,
                        externalSource = "HandyNotes_MapNotes",
                        iconTexture = (type(iconTexture) == "number"
                            or (type(iconTexture) == "string" and iconTexture ~= ""))
                            and iconTexture or nil,
                        normalizedName = SMK.Util.Normalize(displayName),
                        normalizedSearchable = SMK.Util.Normalize(searchable),
                    }
                end
            end
        end
        coord, _, iconTexture = iterFunc(tbl, coord)
    end
    cache[mapID] = nodes
end

function HandyNotesProvider:GetAll()
    local all = {}
    for _, nodes in pairs(cache) do
        for _, node in ipairs(nodes) do
            all[#all + 1] = node
        end
    end
    return all
end

SMK.HandyNotesProvider = HandyNotesProvider
