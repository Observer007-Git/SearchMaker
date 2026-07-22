local _, SMK = ...

local MapIndex = {}
local Util = SMK.Util

local index = {}
local built = false

local function Traverse(mapID, depth, visited)
    if depth > 20 or visited[mapID] then return end
    visited[mapID] = true
    local info = C_Map.GetMapInfo(mapID)
    if not info then return end
    local mapType, name = info.mapType, info.name
    if name and name ~= "" and mapType ~= Enum.UIMapType.Cosmic
        and mapType ~= Enum.UIMapType.Phase
        and mapType ~= Enum.UIMapType.AzeriteMap
        and mapType ~= Enum.UIMapType.Orphan then
        index[#index + 1] = {
            name = name,
            normalizedName = Util.Normalize(name),
            mapType = mapType,
            mapID = mapID,
            isMapPortal = true,
        }
    end
    for _, child in ipairs(C_Map.GetMapChildrenInfo(mapID) or {}) do
        Traverse(child.mapID, depth + 1, visited)
    end
end

--- 每次登录构建一次地图索引；force=true 仅供诊断或显式刷新。
function MapIndex:Rebuild(force)
    if built and not force then return true end
    if not C_Map or not C_Map.GetMapInfo or not C_Map.GetMapChildrenInfo then return false end
    index = {}
    local visited = {}
    local rootsFound = 0
    -- 同时遍历已知宇宙/世界根，visited 会消除重叠子树与循环。
    for _, mapID in ipairs({ 946, 947, 1, 2, 13, 197, 4080 }) do
        if C_Map.GetMapInfo(mapID) then
            rootsFound = rootsFound + 1
            Traverse(mapID, 0, visited)
        end
    end
    if rootsFound == 0 then return false end
    table.sort(index, function(a, b)
        if a.normalizedName ~= b.normalizedName then return a.normalizedName < b.normalizedName end
        return a.mapID < b.mapID
    end)
    built = true
    return true
end

function MapIndex:Search(query)
    if not built then return {} end
    local normalizedQuery = Util.Normalize(query)
    if normalizedQuery == "" then return {} end
    local matches = {}
    for _, entry in ipairs(index) do
        local name = entry.normalizedName
        local score
        if name == normalizedQuery then
            score = 0
        elseif name:sub(1, #normalizedQuery) == normalizedQuery then
            score = 1
        elseif name:find(normalizedQuery, 1, true) then
            score = 2
        end
        if score then
            matches[#matches + 1] = {
                entry = entry,
                score = score,
                isMapPortal = true,
            }
        end
    end
    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.entry.normalizedName ~= b.entry.normalizedName then
            return a.entry.normalizedName < b.entry.normalizedName
        end
        return a.entry.mapID < b.entry.mapID
    end)
    for position = #matches, 6, -1 do matches[position] = nil end
    return matches
end

SMK.MapIndex = MapIndex
