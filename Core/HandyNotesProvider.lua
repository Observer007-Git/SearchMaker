local _, SMK = ...

local HandyNotesProvider = {}
local pluginName = "MapNotes"
local cache = {}

local function ParseCoord(coord)
    local x = math.floor(coord / 10000) / 10000 * 100
    local y = (coord % 10000) / 10000 * 100
    return x, y
end

function HandyNotesProvider:RebuildCache()
    cache = {}
    if not HandyNotes or not HandyNotes.plugins or not HandyNotes.plugins[pluginName] then return end
    local plugin = HandyNotes.plugins[pluginName]
    if not plugin.GetNodes2 then return end

    local mapID = WorldMapFrame and WorldMapFrame:GetMapID() or nil
    if not mapID then return end

    local ok, iterFunc, tbl = pcall(plugin.GetNodes2, plugin, mapID, false)
    if not ok then return end
    if not iterFunc or not tbl or not tbl.data then return end

    local nodes = {}
    local coord = iterFunc(tbl, nil)
    while coord do
        local nodeData = tbl.data[coord]
        if nodeData then
            local displayName = nodeData.name or nodeData.label or ""
            local desc = nodeData.dnID or ""
            if displayName == "" and desc ~= "" then
                displayName = desc:gsub("\n.*", "")
            end
            if displayName == "" and nodeData.npcID then
                local npcName = C_CreatureInfo and C_CreatureInfo.GetCreatureName and C_CreatureInfo.GetCreatureName(nodeData.npcID)
                if npcName and npcName ~= "" then
                    displayName = npcName
                end
            end
            if displayName == "" and nodeData.type then displayName = nodeData.type end
            if displayName == "" and nodeData.npcID then displayName = "NPC:" .. tostring(nodeData.npcID) end
            if displayName ~= "" then
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
                        externalSource = "HandyNotes",
                        normalizedName = SMK.Util.Normalize(displayName),
                        normalizedSearchable = SMK.Util.Normalize(displayName),
                    }
                end
            end
        end
        coord = iterFunc(tbl, coord)
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
