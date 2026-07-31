local _, SMK = ...

local History = {}
local Config = SMK.Config
local Util = SMK.Util
local changeHandler

local function NotifyChanged(kind)
    if changeHandler then changeHandler(kind) end
end

local function GetResultKey(record)
    if record.kind == "saved" or record.kind == "route" then
        return record.kind .. ":" .. tostring(record.id)
    elseif record.kind == "map" then
        return "map:" .. tostring(record.mapID)
    end
    return table.concat({
        "point", tostring(record.mapID), tostring(record.x),
        tostring(record.y), Util.Normalize(record.name),
    }, ":")
end

local function NormalizeRecent(record)
    if type(record) ~= "table" then return end
    if record.kind == "saved" or record.kind == "route" then
        local id = tonumber(record.id)
        if id and id > 0 then return { kind = record.kind, id = id } end
        return
    end
    local mapID = tonumber(record.mapID)
    if record.kind == "map" then
        if not mapID or mapID <= 0 then return end
        return {
            kind = "map",
            mapID = mapID,
        }
    end
    local x, y = tonumber(record.x), tonumber(record.y)
    local name = Util.Trim(record.name)
    if not mapID or mapID <= 0 or not x or x < 0 or x > 100
        or not y or y < 0 or y > 100 or name == "" then
        return
    end
    return {
        kind = "point",
        mapID = mapID,
        x = x,
        y = y,
        name = name,
        categoryKey = Config.GetCategoryKey(record.categoryKey),
        note = Util.Trim(record.note),
        isExternal = record.isExternal == true or nil,
        externalSource = record.isExternal and record.externalSource or nil,
        iconTexture = record.isExternal and record.iconTexture or nil,
        isCoordinateResult = record.isCoordinateResult == true or nil,
    }
end

function History:PrepareDatabase(database)
    local queries, seenQueries = {}, {}
    for _, query in ipairs(type(database.searchHistory) == "table"
        and database.searchHistory or {}) do
        query = Util.Trim(query)
        local key = Util.Normalize(query)
        if query ~= "" and not seenQueries[key]
            and #queries < Config.search.historyLimit then
            queries[#queries + 1] = query
            seenQueries[key] = true
        end
    end
    database.searchHistory = queries

    local results, seenResults = {}, {}
    for _, stored in ipairs(type(database.recentSearchResults) == "table"
        and database.recentSearchResults or {}) do
        local record = NormalizeRecent(stored)
        local key = record and GetResultKey(record)
        if key and not seenResults[key]
            and #results < Config.search.recentResultLimit then
            results[#results + 1] = record
            seenResults[key] = true
        end
    end
    database.recentSearchResults = results
end

function History:SetChangeHandler(callback)
    changeHandler = callback
end

function History:GetQueries()
    return SMK.DB:Get().searchHistory
end

function History:RecordQuery(query)
    if SMK.DB:IsReadOnly() then return false end
    query = Util.Trim(query)
    local key = Util.Normalize(query)
    if key == "" then return false end
    local queries = self:GetQueries()
    for index = #queries, 1, -1 do
        if Util.Normalize(queries[index]) == key then table.remove(queries, index) end
    end
    table.insert(queries, 1, query)
    for index = #queries, Config.search.historyLimit + 1, -1 do
        queries[index] = nil
    end
    NotifyChanged("query")
    return true
end

function History:RecordResult(entry)
    if SMK.DB:IsReadOnly() or type(entry) ~= "table" then return false end
    local record
    if entry.isSavedRoute then
        record = NormalizeRecent({ kind = "route", id = entry.id })
    elseif entry.isMapPortal then
        record = NormalizeRecent({
            kind = "map", mapID = entry.mapID,
        })
    elseif entry.source == "saved" and entry.id then
        record = NormalizeRecent({ kind = "saved", id = entry.id })
    else
        local values = {}
        for key, value in pairs(entry) do values[key] = value end
        values.kind = "point"
        record = NormalizeRecent(values)
    end
    if not record then return false end
    local results = SMK.DB:Get().recentSearchResults
    local key = GetResultKey(record)
    for index = #results, 1, -1 do
        if GetResultKey(results[index]) == key then table.remove(results, index) end
    end
    table.insert(results, 1, record)
    for index = #results, Config.search.recentResultLimit + 1, -1 do
        results[index] = nil
    end
    NotifyChanged("result")
    return true
end

function History:GetRecentResults()
    local resolved = {}
    local database = SMK.DB:Get()
    local validRecords = {}
    for _, record in ipairs(database.recentSearchResults) do
        local entry
        if record.kind == "saved" then
            entry = SMK.Store:GetByID(record.id)
        elseif record.kind == "route" then
            entry = SMK.RouteStore:GetByID(record.id)
        elseif record.kind == "map" then
            entry = {
                mapID = record.mapID,
                name = SMK.Map:GetMapName(record.mapID),
                isMapPortal = true,
            }
        else
            entry = record
        end
        if entry then
            resolved[#resolved + 1] = entry
            validRecords[#validRecords + 1] = record
        end
    end
    if not SMK.DB:IsReadOnly() and #validRecords ~= #database.recentSearchResults then
        database.recentSearchResults = validRecords
    end
    return resolved
end

SMK.SearchHistory = History
