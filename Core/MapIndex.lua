local _, SMK = ...

local MapIndex = {}
local Util = SMK.Util
local Config = SMK.Config

local index = {}
local built = false
local building = false
local buildGeneration = 0
local buildHandler

local function ShouldIndex(info)
    local mapType = info and info.mapType
    return info and info.name and info.name ~= ""
        and mapType ~= Enum.UIMapType.Cosmic
        and mapType ~= Enum.UIMapType.Phase
        and mapType ~= Enum.UIMapType.AzeriteMap
        and mapType ~= Enum.UIMapType.Orphan
end

local function AddMap(target, info, mapID)
    if not ShouldIndex(info) then return end
    target[#target + 1] = {
        name = info.name,
        normalizedName = Util.Normalize(info.name),
        mapID = mapID,
        isMapPortal = true,
    }
end

local function SortIndex(target)
    table.sort(target, function(a, b)
        if a.normalizedName ~= b.normalizedName then
            return a.normalizedName < b.normalizedName
        end
        return a.mapID < b.mapID
    end)
end

local function Traverse(target, mapID, depth, visited)
    if depth > Config.mapIndex.maxDepth or visited[mapID] then return end
    visited[mapID] = true
    local info = C_Map.GetMapInfo(mapID)
    if not info then return end
    AddMap(target, info, mapID)
    for _, child in ipairs(C_Map.GetMapChildrenInfo(mapID) or {}) do
        Traverse(target, child.mapID, depth + 1, visited)
    end
end

local function CreateBuildState()
    local state = { stack = {}, visited = {}, entries = {} }
    for index = #Config.mapIndex.roots, 1, -1 do
        local mapID = Config.mapIndex.roots[index]
        local info = C_Map.GetMapInfo(mapID)
        if info then
            state.stack[#state.stack + 1] = {
                mapID = mapID,
                depth = 0,
                info = info,
            }
        end
    end
    return #state.stack > 0 and state or nil
end

local function ProcessNode(state)
    local task = table.remove(state.stack)
    if not task or task.depth > Config.mapIndex.maxDepth
        or state.visited[task.mapID] then
        return task ~= nil
    end
    state.visited[task.mapID] = true
    local info = task.info or C_Map.GetMapInfo(task.mapID)
    if not info then return true end
    AddMap(state.entries, info, task.mapID)
    local children = C_Map.GetMapChildrenInfo(task.mapID) or {}
    for childIndex = #children, 1, -1 do
        state.stack[#state.stack + 1] = {
            mapID = children[childIndex].mapID,
            depth = task.depth + 1,
        }
    end
    return true
end

local function Publish(state, generation, notify)
    if generation ~= buildGeneration then return false end
    SortIndex(state.entries)
    index = state.entries
    built = #index > 0
    building = false
    if notify and buildHandler then buildHandler(built) end
    return built
end

function MapIndex:SetBuildHandler(callback)
    buildHandler = callback
end

function MapIndex:IsBuilding()
    return building
end

--- 每次登录构建一次地图索引；正式服中按条数和时间预算分帧处理。
-- @return boolean, boolean 已接受构建请求、是否仍在构建。
function MapIndex:Rebuild(force)
    if built and not force then return true, false end
    if building and not force then return true, true end
    if not C_Map or not C_Map.GetMapInfo or not C_Map.GetMapChildrenInfo then
        return false, false
    end
    local state = CreateBuildState()
    if not state then return false, false end

    buildGeneration = buildGeneration + 1
    local generation = buildGeneration
    building = true
    if C_Timer and type(C_Timer.After) == "function" then
        local function ProcessBatch()
            if generation ~= buildGeneration then return end
            local batchSize = math.max(1,
                tonumber(Config.mapIndex.buildBatchSize) or 1)
            local budget = math.max(0,
                tonumber(Config.mapIndex.buildTimeBudgetMs) or 0)
            local canProfile = type(debugprofilestop) == "function"
            local startedAt = canProfile and debugprofilestop() or 0
            for _ = 1, batchSize do
                if #state.stack == 0 then
                    Publish(state, generation, true)
                    return
                end
                ProcessNode(state)
                if canProfile and debugprofilestop() - startedAt >= budget then break end
            end
            C_Timer.After(0, ProcessBatch)
        end
        C_Timer.After(0, ProcessBatch)
        return true, true
    end

    local visited = {}
    local entries = {}
    for _, mapID in ipairs(Config.mapIndex.roots) do
        Traverse(entries, mapID, 0, visited)
    end
    state.entries = entries
    return Publish(state, generation, false), false
end

function MapIndex:Search(query)
    if not built then return {} end
    local normalizedQuery = Util.Normalize(query)
    if normalizedQuery == "" then return {} end
    local matches = {}
    local function IsBetter(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.entry.normalizedName ~= b.entry.normalizedName then
            return a.entry.normalizedName < b.entry.normalizedName
        end
        return a.entry.mapID < b.entry.mapID
    end
    local function IsBetterValues(entry, score, candidate)
        if score ~= candidate.score then return score < candidate.score end
        if entry.normalizedName ~= candidate.entry.normalizedName then
            return entry.normalizedName < candidate.entry.normalizedName
        end
        return entry.mapID < candidate.entry.mapID
    end
    local function SiftUp(position)
        while position > 1 do
            local parent = math.floor(position / 2)
            if not IsBetter(matches[parent], matches[position]) then break end
            matches[parent], matches[position] = matches[position], matches[parent]
            position = parent
        end
    end
    local function SiftDown(position)
        while true do
            local left = position * 2
            if left > #matches then return end
            local right = left + 1
            local worse = left
            if right <= #matches and IsBetter(matches[left], matches[right]) then
                worse = right
            end
            if not IsBetter(matches[position], matches[worse]) then return end
            matches[position], matches[worse] = matches[worse], matches[position]
            position = worse
        end
    end
    local function AddBounded(entry, score)
        if #matches < Config.mapIndex.maxResults then
            matches[#matches + 1] = {
                entry = entry,
                score = score,
                isMapPortal = true,
            }
            SiftUp(#matches)
            return
        end
        if IsBetterValues(entry, score, matches[1]) then
            matches[1].entry = entry
            matches[1].score = score
            matches[1].isMapPortal = true
            SiftDown(1)
        end
    end
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
        if score then AddBounded(entry, score) end
    end
    table.sort(matches, IsBetter)
    return matches
end

SMK.MapIndex = MapIndex
