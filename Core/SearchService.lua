local _, SMK = ...

local Search = {}
local Util = SMK.Util
local Config = SMK.Config

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
-- @return table { entry, score, mapName?, isMapPortal? } 数组。
function Search:Find(entries, query, allMaps)
    query = Util.Normalize(query)
    if query == "" then
        return {}
    end
    local matches = {}
    local maxResults = Config.search.maxResults
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
    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.isMapPortal ~= b.isMapPortal then return not a.isMapPortal end
        local nameA, nameB = Util.Normalize(a.entry.name), Util.Normalize(b.entry.name)
        if nameA ~= nameB then return nameA < nameB end
        local mapNameA, mapNameB = a.mapName or "", b.mapName or ""
        if mapNameA ~= mapNameB then return mapNameA < mapNameB end
        return (tonumber(a.entry.mapID) or 0) < (tonumber(b.entry.mapID) or 0)
    end)
    if #matches > maxResults then
        for i = maxResults + 1, #matches do
            matches[i] = nil
        end
    end
    return matches
end

SMK.Search = Search
