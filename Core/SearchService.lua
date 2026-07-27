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

--- 搜索条目列表并返回带分数的结果。
-- 始终追加地图索引匹配结果（不受 allMaps 参数影响）。
-- @param entries table 待搜索的地点条目数组。
-- @param query string 用户原始查询（会被归一化）。
-- @param allMaps boolean 若为 true，每条结果包含地图名称。
-- @param currentMapID number|nil 当前地图 ID，用于生成临时坐标结果。
-- @param externalEntries table|nil 当前上下文的外部地点。
-- @return table { entry, score, mapName?, isMapPortal?, isCoordinateResult? } 数组。
function Search:Find(entries, query, allMaps, currentMapID, externalEntries)
    local coordinateX, coordinateY = self:ParseCoordinates(query)
    query = Util.Normalize(query)
    if query == "" then
        return {}
    end
    local matches = {}
    local maxResults = Config.search.maxResults
    currentMapID = tonumber(currentMapID)
    if coordinateX and currentMapID and currentMapID > 0 then
        matches[#matches + 1] = {
            entry = {
                mapID = currentMapID,
                x = coordinateX,
                y = coordinateY,
                name = string.format(SMK.L.COORDINATE_RESULT_FORMAT,
                    FormatCoordinate(coordinateX), FormatCoordinate(coordinateY)),
                categoryKey = Config.defaultCategoryKey,
                isCoordinateResult = true,
            },
            score = -1,
            isCoordinateResult = true,
        }
    end
    for _, entry in ipairs(entries or {}) do
        local score = self:GetScore(entry, query)
        if score then
            local mapName = allMaps and SMK.Map:GetMapName(entry.mapID) or nil
            matches[#matches + 1] = { entry = entry, score = score, mapName = mapName }
        end
    end
    -- Include map portal matches (always)
    if SMK.MapIndex then
        local mapMatches = SMK.MapIndex:Search(query)
        for _, m in ipairs(mapMatches) do
            matches[#matches + 1] = m
        end
    end
    -- HandyNotes 只维护当前地图的惰性缓存，不能在全图模式中冒充全图数据。
    for _, entry in ipairs(not allMaps and externalEntries or {}) do
        local score = entry.mapID == currentMapID and self:GetScore(entry, query) or nil
        if score then
            matches[#matches + 1] = {
                entry = entry, score = score + 4,
                isExternal = true,
            }
        end
    end
    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.isMapPortal ~= b.isMapPortal then return not a.isMapPortal end
        local nameA = a.entry.normalizedName or Util.Normalize(a.entry.name)
        local nameB = b.entry.normalizedName or Util.Normalize(b.entry.name)
        if nameA ~= nameB then return nameA < nameB end
        local mapNameA, mapNameB = a.mapName or "", b.mapName or ""
        if mapNameA ~= mapNameB then return mapNameA < mapNameB end
        local mapIDA, mapIDB = tonumber(a.entry.mapID) or 0, tonumber(b.entry.mapID) or 0
        if mapIDA ~= mapIDB then return mapIDA < mapIDB end
        local xA, xB = tonumber(a.entry.x) or 0, tonumber(b.entry.x) or 0
        if xA ~= xB then return xA < xB end
        return (tonumber(a.entry.y) or 0) < (tonumber(b.entry.y) or 0)
    end)
    if #matches > maxResults then
        for i = maxResults + 1, #matches do
            matches[i] = nil
        end
    end
    return matches
end

SMK.Search = Search
