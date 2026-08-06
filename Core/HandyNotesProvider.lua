local _, SMK = ...

local HandyNotesProvider = {}
local pluginName = "MapNotes"
local cachedMapID
local cachedEntries = {}
local cacheReady = false
local npcInfoCache = {}
local npcInfoCacheSize = 0
local changeHandler
local updateHooked = false
local enabled = false
local buildGeneration = 0
local buildingMapID

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function ResetMissingNpcRetries()
    for _, cached in pairs(npcInfoCache) do
        if not cached.name or not cached.title then
            cached.retryAt = 0
            cached.partialRetried = false
        end
    end
end

local function ClearNpcInfoCache()
    npcInfoCache = {}
    npcInfoCacheSize = 0
end

local function CacheNpcInfo(key, name, title, retryAt, partialRetried)
    local existing = npcInfoCache[key]
    local limit = math.max(1, tonumber(SMK.Config.handyNotes.npcCacheMaxEntries) or 1)
    if not existing and npcInfoCacheSize >= limit then
        local evictedKey = next(npcInfoCache)
        if evictedKey then
            npcInfoCache[evictedKey] = nil
            npcInfoCacheSize = npcInfoCacheSize - 1
        end
    end
    if not existing then npcInfoCacheSize = npcInfoCacheSize + 1 end
    npcInfoCache[key] = {
        name = name,
        title = title,
        retryAt = retryAt,
        partialRetried = partialRetried == true,
    }
end

local function ParseCoord(coord)
    local x = math.floor(coord / 10000) / 10000 * 100
    local y = (coord % 10000) / 10000 * 100
    return x, y
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
    if SMK.locale == "zhCN" then
        return SMK.Util.ContainsHan(text)
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
    local now = Now()
    if cached and (not cached.retryAt or cached.retryAt > now) then
        return cached.name, cached.title, cached.retryAt
    end

    local previousName = cached and cached.name
    local previousTitle = cached and cached.title
    local retryingPartial = cached and (cached.name or cached.title)
        and cached.retryAt ~= nil
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
    name, title = name or previousName, title or previousTitle
    local retrySeconds = tonumber(SMK.Config.handyNotes.npcRetrySeconds) or 30
    local retryAt, partialRetried
    if not name and not title then
        retryAt = now + retrySeconds
    elseif not name or not title then
        partialRetried = retryingPartial or (cached and cached.partialRetried)
        if not partialRetried then retryAt = now + retrySeconds end
    end
    CacheNpcInfo(key, name, title, retryAt, partialRetried)
    return name, title, retryAt
end

function HandyNotesProvider:Invalidate(resetMissingRetries)
    local invalidatedMapID = cachedMapID or buildingMapID
    if resetMissingRetries then ResetMissingNpcRetries() end
    buildGeneration = buildGeneration + 1
    buildingMapID = nil
    cachedMapID, cachedEntries, cacheReady = nil, {}, false
    return invalidatedMapID
end

local function EnsureUpdateHook()
    if updateHooked or not HandyNotes or type(HandyNotes.SendMessage) ~= "function"
        or type(hooksecurefunc) ~= "function" then
        return
    end
    updateHooked = true
    hooksecurefunc(HandyNotes, "SendMessage", function(_, message, source)
        if not enabled or message ~= "HandyNotes_NotifyUpdate"
            or source ~= pluginName then return end
        local mapID = HandyNotesProvider:Invalidate(true)
        if changeHandler then changeHandler("invalidated", mapID) end
    end)
end

function HandyNotesProvider:SetChangeHandler(callback)
    changeHandler = callback
    if enabled then EnsureUpdateHook() end
end

function HandyNotesProvider:SetEnabled(value)
    value = value == true
    if enabled == value then return false end
    enabled = value
    local invalidatedMapID = self:Invalidate(false)
    if enabled then
        EnsureUpdateHook()
    else
        ClearNpcInfoCache()
    end
    return true, invalidatedMapID
end

function HandyNotesProvider:IsEnabled()
    return enabled
end

local function AddSearchText(parts, seen, text, budget)
    local value = CleanText(text)
    if not value or not IsLocalizedText(value) then return end
    local fieldLimit = tonumber(SMK.Config.handyNotes.maxSearchFieldBytes) or 160
    local totalLimit = tonumber(SMK.Config.handyNotes.maxSearchTextBytes) or 512
    local separatorBytes = #parts > 0 and 1 or 0
    local remaining = totalLimit - budget.bytes - separatorBytes
    if remaining <= 0 then return end
    value = SMK.Util.TruncateUTF8(value, math.min(fieldLimit, remaining))
    if value == "" or seen[value] then return end
    seen[value] = true
    parts[#parts + 1] = value
    budget.bytes = budget.bytes + #value + separatorBytes
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
    local parts, seen, budget = {}, {}, { bytes = 0 }
    local directNames = {
        CleanText(nodeData.name) or false,
        CleanText(nodeData.label) or false,
        CleanText(nodeData.dnID) or false,
    }
    for _, value in ipairs(directNames) do
        AddSearchText(parts, seen, value, budget)
    end

    local npcNames, npcTitles = {}, {}
    local nextRetryAt
    local function AddNpc(npcID)
        if not npcID then return end
        local name, title, retryAt = GetNpcInfo(npcID)
        if retryAt and (not nextRetryAt or retryAt < nextRetryAt) then
            nextRetryAt = retryAt
        end
        title = title and (title:match("^<(.+)>$") or title)
        AddSearchText(parts, seen, name, budget)
        AddSearchText(parts, seen, title, budget)
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
    AddSearchText(parts, seen, typeLabel, budget)
    AddSearchText(parts, seen, typeDisplay, budget)

    -- 只接收 MapNotes 的用户可见补充字段，避免布尔配置、链接和内部备注进入搜索。
    if SMK.locale == "zhCN" then
        for _, key in ipairs({ "TransportName", "title", "info", "wwwName" }) do
            AddSearchText(parts, seen, nodeData[key], budget)
        end
        for index = 1, 10 do
            AddSearchText(parts, seen, nodeData["wwwNames" .. index], budget)
            AddSearchText(parts, seen, nodeData["mnIDText" .. index], budget)
            AddSearchText(parts, seen, nodeData["npcIDs" .. index .. "Info"], budget)
        end
    end

    local displayName = npcTitles[1]
    for _, value in ipairs(directNames) do
        if not displayName and value and IsLocalizedText(value) then
            displayName = value:gsub("\n.*", "")
            break
        end
    end
    displayName = displayName or typeDisplay or npcNames[1]
    if not displayName and SMK.locale ~= "zhCN" then
        displayName = CleanText(nodeData.type)
            or (nodeData.npcID and "NPC:" .. tostring(nodeData.npcID))
    end
    AddSearchText(parts, seen, displayName, budget)
    return displayName, table.concat(parts, " "), nextRetryAt
end

function HandyNotesProvider:RebuildCache(mapID, force)
    if not enabled then return cachedEntries end
    EnsureUpdateHook()
    mapID = tonumber(mapID) or SMK.Map:GetContextMapID()
    if not mapID then
        buildGeneration = buildGeneration + 1
        buildingMapID = nil
        cachedMapID, cachedEntries, cacheReady = nil, {}, false
        return cachedEntries
    end
    if cacheReady and cachedMapID == mapID and not force then return cachedEntries end
    if buildingMapID == mapID and not force then return cachedEntries end

    buildGeneration = buildGeneration + 1
    local generation = buildGeneration
    buildingMapID = mapID
    cachedMapID, cachedEntries, cacheReady = mapID, {}, false
    if not HandyNotes or not HandyNotes.plugins or not HandyNotes.plugins[pluginName] then
        buildingMapID = nil
        return cachedEntries
    end
    local plugin = HandyNotes.plugins[pluginName]
    if not plugin.GetNodes2 then
        buildingMapID = nil
        return cachedEntries
    end

    local ok, iterFunc, tbl = pcall(plugin.GetNodes2, plugin, mapID, false)
    if not ok or not iterFunc or not tbl or not tbl.data then
        buildingMapID = nil
        return cachedEntries
    end

    local nodes = {}
    local nextRetryAt
    local previousCoord
    local function AddNode(coord, iconTexture)
        local nodeData = tbl.data[coord]
        if nodeData then
            local displayName, searchable, retryAt = BuildNodeText(nodeData)
            if retryAt and (not nextRetryAt or retryAt < nextRetryAt) then
                nextRetryAt = retryAt
            end
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
    end

    local function Finish()
        if generation ~= buildGeneration then return end
        cachedEntries = nodes
        cacheReady = true
        buildingMapID = nil
        if nextRetryAt and C_Timer and type(C_Timer.After) == "function" then
            local delay = math.max(0, nextRetryAt - Now())
            C_Timer.After(delay, function()
                if generation ~= buildGeneration or not cacheReady
                    or cachedMapID ~= mapID then return end
                local invalidatedMapID = HandyNotesProvider:Invalidate(false)
                if changeHandler then changeHandler("invalidated", invalidatedMapID) end
            end)
        end
    end

    local function ProcessBatch()
        if generation ~= buildGeneration then return end
        local batchSize = math.max(1,
            tonumber(SMK.Config.handyNotes.buildBatchSize) or 1)
        local budget = math.max(0,
            tonumber(SMK.Config.handyNotes.buildTimeBudgetMs) or 0)
        local canProfile = type(debugprofilestop) == "function"
        local startedAt = canProfile and debugprofilestop() or 0
        for _ = 1, batchSize do
            local coord, _, iconTexture = iterFunc(tbl, previousCoord)
            if not coord then
                Finish()
                if changeHandler then changeHandler("ready", mapID) end
                return
            end
            previousCoord = coord
            AddNode(coord, iconTexture)
            if canProfile and debugprofilestop() - startedAt >= budget then break end
        end
        C_Timer.After(0, ProcessBatch)
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, ProcessBatch)
        return cachedEntries
    end

    local coord, _, iconTexture = iterFunc(tbl, previousCoord)
    while coord do
        previousCoord = coord
        AddNode(coord, iconTexture)
        coord, _, iconTexture = iterFunc(tbl, previousCoord)
    end
    Finish()
    return cachedEntries
end

function HandyNotesProvider:GetByMap(mapID)
    return enabled and cacheReady
        and tonumber(mapID) == cachedMapID and cachedEntries or {}
end

SMK.HandyNotesProvider = HandyNotesProvider
