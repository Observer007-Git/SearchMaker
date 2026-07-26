local _, SMK = ...

local Context = {
    mapID = nil,
    entries = {},
    externalEntries = {},
    totalLocationCount = 0,
}

function Context:Refresh(mapID, forceExternal)
    mapID = tonumber(mapID) or SMK.Map:GetContextMapID()
    if mapID then
        SMK.HandyNotesProvider:RebuildCache(mapID, forceExternal == true)
    end
    self.mapID = mapID
    self.entries = mapID and SMK.Store:GetByMap(mapID) or {}
    self.externalEntries = mapID and SMK.HandyNotesProvider:GetByMap(mapID) or {}
    self.totalLocationCount = #SMK.Store:GetAll()
    return mapID
end

function Context:GetMapID()
    return self.mapID
end

function Context:GetEntries()
    return self.entries
end

function Context:GetExternalEntries()
    return self.externalEntries
end

function Context:GetTotalLocationCount()
    return self.totalLocationCount
end

function Context:GetSearchEntries(allMaps)
    return allMaps and SMK.Store:GetAll() or self.entries
end

SMK.MapContext = Context
