local _, SMK = ...

local Search = {}
local Util = SMK.Util
local Config = SMK.Config

local function IsCoordinateToken(value)
    return value:match("^%d+$")
        or value:match("^%d+%.%d%d?$")
end

local function FormatCoordinate(value)
    local text = string.format("%.2f", value)
    return (text:gsub("0+$", ""):gsub("%.$", ""))
end

--- 解析两个坐标值；每项可为一位或多位整数，可带 1–2 位小数。
-- 支持空格、英文逗号或中文逗号分隔。坐标范围 0–100。
function Search:ParseCoordinates(query)
    local text = Util.Trim(query):gsub("，", ",")
    local xText, yText = text:match("^(%S+)%s*,%s*(%S+)$")
    if not xText then
        xText, yText = text:match("^(%S+)%s+(%S+)$")
    end
    if not xText or not IsCoordinateToken(xText) or not IsCoordinateToken(yText) then
        return
    end
    local x, y = tonumber(xText), tonumber(yText)
    if not x or x < 0 or x > 100 or not y or y < 0 or y > 100 then return end
    return x, y
end

--- 计算条目与搜索词的相关度分数。
-- 0 = 精确匹配，1 = 前缀匹配，2 = 子串匹配。
-- @param entry table 携带有预计算 normalizedName/normalizedSearchable 的条目。
-- @param query string 已归一化的查询词。
-- @return number|nil 分数（无匹配时返回 nil）。
function Search:GetScore(entry, query)
    if query == "" then
        return
    end
    local name = entry.normalizedName
    local searchable = entry.normalizedSearchable
    if name == query then
        return 0
    elseif name:sub(1, #query) == query then
        return 1
    elseif searchable:find(query, 1, true) then
        return 2
    end
end

--- 仅在完整、连续匹配本地化“路线”关键字时进入路线搜索。
-- 关键字之外的文本继续用于筛选路线名称，例如“路线 银月”。
function Search:GetRouteFilter(query)
    local keyword = Util.Normalize(SMK.L.ROUTE_SEARCH_KEYWORD)
    if keyword == "" then return end
    local first, last = query:find(keyword, 1, true)
    if not first then return end
    return query:sub(1, first - 1) .. query:sub(last + 1)
end

local function ResolveMapSortKey(match)
    if match.includeMapName and not match.mapName then
        match.mapName = SMK.Map:GetMapName(match.entry.mapID)
    end
    if match.includeMapName and not match.mapSortKey then
        match.mapSortKey = Util.SortKey(match.mapName)
    end
    return match.mapSortKey or ""
end

local function IsBetterValues(entry, score, mapName, isMapPortal, includeMapName, b)
    if score ~= b.score then return score < b.score, mapName end
    local portalA, portalB = isMapPortal == true, b.isMapPortal == true
    if portalA ~= portalB then return not portalA, mapName end
    local nameA = entry.normalizedName or Util.Normalize(entry.name)
    local nameB = b.entry.normalizedName or Util.Normalize(b.entry.name)
    if nameA ~= nameB then return nameA < nameB, mapName end
    if includeMapName then
        mapName = mapName or SMK.Map:GetMapName(entry.mapID)
        local mapKeyA = Util.SortKey(mapName)
        local mapKeyB = ResolveMapSortKey(b)
        if mapKeyA ~= mapKeyB then return mapKeyA < mapKeyB, mapName end
    end
    local mapIDA, mapIDB = tonumber(entry.mapID) or 0, tonumber(b.entry.mapID) or 0
    if mapIDA ~= mapIDB then return mapIDA < mapIDB, mapName end
    local xA, xB = tonumber(entry.x) or 0, tonumber(b.entry.x) or 0
    if xA ~= xB then return xA < xB, mapName end
    return (tonumber(entry.y) or 0) < (tonumber(b.entry.y) or 0), mapName
end

local function IsBetterMatch(a, b)
    if a.score ~= b.score then return a.score < b.score end
    local portalA, portalB = a.isMapPortal == true, b.isMapPortal == true
    if portalA ~= portalB then return not portalA end
    local nameA = a.entry.normalizedName or Util.Normalize(a.entry.name)
    local nameB = b.entry.normalizedName or Util.Normalize(b.entry.name)
    if nameA ~= nameB then return nameA < nameB end
    local mapKeyA, mapKeyB = ResolveMapSortKey(a), ResolveMapSortKey(b)
    if mapKeyA ~= mapKeyB then return mapKeyA < mapKeyB end
    local mapIDA = tonumber(a.entry.mapID) or 0
    local mapIDB = tonumber(b.entry.mapID) or 0
    if mapIDA ~= mapIDB then return mapIDA < mapIDB end
    local xA, xB = tonumber(a.entry.x) or 0, tonumber(b.entry.x) or 0
    if xA ~= xB then return xA < xB end
    return (tonumber(a.entry.y) or 0) < (tonumber(b.entry.y) or 0)
end

local function SiftUp(heap, index)
    while index > 1 do
        local parent = math.floor(index / 2)
        if not IsBetterMatch(heap[parent], heap[index]) then break end
        heap[parent], heap[index] = heap[index], heap[parent]
        index = parent
    end
end

local function SiftDown(heap, index)
    while true do
        local left = index * 2
        if left > #heap then return end
        local right = left + 1
        local worse = left
        if right <= #heap and IsBetterMatch(heap[left], heap[right]) then
            worse = right
        end
        if not IsBetterMatch(heap[index], heap[worse]) then return end
        heap[index], heap[worse] = heap[worse], heap[index]
        index = worse
    end
end

local function SetCandidate(candidate, entry, score, mapName, isMapPortal,
    isCoordinateResult, isExternal, includeMapName)
    candidate.entry = entry
    candidate.score = score
    candidate.mapName = mapName
    candidate.mapSortKey = nil
    candidate.isMapPortal = isMapPortal
    candidate.isCoordinateResult = isCoordinateResult
    candidate.isExternal = isExternal
    candidate.includeMapName = includeMapName == true
end

local function AddBounded(matches, entry, score, limit, mapName,
    isMapPortal, isCoordinateResult, isExternal, includeMapName)
    local accepted, resolvedMapName = true, mapName
    if #matches >= limit then
        accepted, resolvedMapName = IsBetterValues(entry, score, mapName,
            isMapPortal, includeMapName, matches[1])
    end
    if not accepted then return end
    if #matches < limit then
        local candidate = {}
        SetCandidate(candidate, entry, score, resolvedMapName, isMapPortal,
            isCoordinateResult, isExternal, includeMapName)
        matches[#matches + 1] = candidate
        SiftUp(matches, #matches)
    else
        SetCandidate(matches[1], entry, score, resolvedMapName, isMapPortal,
            isCoordinateResult, isExternal, includeMapName)
        SiftDown(matches, 1)
    end
end

--- 搜索条目列表并返回带分数的结果。
-- 始终追加地图索引匹配结果（不受 allMaps 参数影响）。
-- @param entries table 待搜索的地点条目数组。
-- @param query string 用户原始查询（会被归一化）。
-- @param allMaps boolean 若为 true，每条结果包含地图名称。
-- @param currentMapID number|nil 当前地图 ID，用于生成临时坐标结果。
-- @param externalEntries table|nil 当前上下文的外部地点。
-- @return table { entry, score, mapName?, isMapPortal?, isCoordinateResult? } 数组。
function Search:Find(entries, query, allMaps, currentMapID, externalEntries)
    local rawQuery = query
    query = Util.Normalize(rawQuery)
    if query == "" then
        return {}
    end
    local maxResults = Config.search.maxResults
    local routeFilter = self:GetRouteFilter(query)
    if routeFilter ~= nil then
        return SMK.RouteStore:Search(routeFilter, maxResults)
    end
    local coordinateX, coordinateY = self:ParseCoordinates(rawQuery)
    local matches = {}
    currentMapID = tonumber(currentMapID)
    if coordinateX and currentMapID and currentMapID > 0 then
        local entry = {
                mapID = currentMapID,
                x = coordinateX,
                y = coordinateY,
                name = string.format(SMK.L.COORDINATE_RESULT_FORMAT,
                    FormatCoordinate(coordinateX), FormatCoordinate(coordinateY)),
                categoryKey = Config.defaultCategoryKey,
                isCoordinateResult = true,
            }
        AddBounded(matches, entry, -1, maxResults, nil, nil, true)
    end
    for _, entry in ipairs(entries or {}) do
        local score = self:GetScore(entry, query)
        if score then
            AddBounded(matches, entry, score, maxResults,
                nil, nil, nil, nil, allMaps)
        end
    end
    -- Include map portal matches (always)
    if SMK.MapIndex then
        local mapMatches = SMK.MapIndex:Search(query)
        for _, m in ipairs(mapMatches) do
            AddBounded(matches, m.entry, m.score, maxResults,
                m.mapName, true)
        end
    end
    -- HandyNotes 只维护当前地图的惰性缓存，不能在全图模式中冒充全图数据。
    for _, entry in ipairs(not allMaps and externalEntries or {}) do
        local score = entry.mapID == currentMapID and self:GetScore(entry, query) or nil
        if score then
            AddBounded(matches, entry, score + 4, maxResults,
                nil, nil, nil, true)
        end
    end
    for _, match in ipairs(matches) do
        if match.includeMapName then ResolveMapSortKey(match) end
    end
    table.sort(matches, IsBetterMatch)
    return matches
end

SMK.Search = Search
