local _, SMK = ...

local Store = {}
local Config = SMK.Config
local Util = SMK.Util
local Model = SMK.LocationModel

local cacheDirty = true
local cachedEntries = {}
local mapIndex = {}
local entryByID = {}
local storageIndexByID = {}
local duplicateIndexByMap = {}
local changeHandler

local function NotifyChanged(reason)
    if changeHandler then changeHandler(reason) end
end

local function GetCategoryLabel(categoryKey)
    local category = Config.categoryByKey[categoryKey]
    return category and (SMK.L[category.nameKey] or category.key)
        or (SMK.L.CAT_OTHER or Config.defaultCategoryKey)
end

local function BuildSavedEntry(entry, index)
    local display = Model:CopyPersistent(entry)
    display.id = entry.id
    display.source = "saved"
    display.sourceIndex = index
    display.categoryLabel = GetCategoryLabel(display.categoryKey)
    display.normalizedName = Util.Normalize(display.name)
    display.normalizedSearchable = display.normalizedName
    return display
end

local function RebuildCache()
    local entries = {}
    local newMapIndex = {}
    local newEntryByID = {}
    local newStorageIndexByID = {}
    local newDuplicateIndexByMap = {}
    for index, entry in ipairs(SMK.DB:Get().locations) do
        local display = BuildSavedEntry(entry, index)
        if display then
            entries[#entries + 1] = display
            local map = newMapIndex[display.mapID]
            if not map then
                map = {}
                newMapIndex[display.mapID] = map
            end
            map[#map + 1] = display
            newEntryByID[display.id] = display
            newStorageIndexByID[display.id] = index
            local duplicates = newDuplicateIndexByMap[display.mapID]
            if not duplicates then
                duplicates = {}
                newDuplicateIndexByMap[display.mapID] = duplicates
            end
            duplicates[Model:GetDuplicateKey(display)] = display
        end
    end
    cachedEntries = entries
    mapIndex = newMapIndex
    entryByID = newEntryByID
    storageIndexByID = newStorageIndexByID
    duplicateIndexByMap = newDuplicateIndexByMap
    cacheDirty = false
end

function Store:InvalidateCache()
    cacheDirty = true
end

function Store:SetChangeHandler(callback)
    changeHandler = callback
end

function Store:GetAll()
    if cacheDirty then RebuildCache() end
    return cachedEntries
end

function Store:GetByMap(mapID)
    if cacheDirty then RebuildCache() end
    return mapIndex[mapID] or {}
end

function Store:GetByID(id)
    if cacheDirty then RebuildCache() end
    return entryByID[tonumber(id)]
end

function Store:Add(values)
    if SMK.DB:IsReadOnly() then return nil, "READ_ONLY" end
    local entry, errorMessage = Model:Normalize(values)
    if not entry then return nil, errorMessage end
    local duplicate, duplicateMessage = self:FindDuplicate(entry)
    if duplicate then return nil, duplicateMessage end
    local database = SMK.DB:Get()
    entry.id = SMK.DB:NextLocationID()
    database.locations[#database.locations + 1] = entry
    self:InvalidateCache()
    local display = BuildSavedEntry(entry, #database.locations)
    NotifyChanged("locations")
    return display
end

function Store:AddExternal(entry, categoryKey)
    if type(entry) ~= "table" or not entry.isExternal
        or entry.externalSource ~= "HandyNotes_MapNotes" then
        return nil, "INVALID_LOCATION"
    end
    local values = {
        mapID = entry.mapID,
        x = entry.x,
        y = entry.y,
        name = entry.name,
        categoryKey = Config.GetCategoryKey(categoryKey),
    }
    local duplicate, duplicateMessage = self:FindDuplicate(values)
    if duplicate then return nil, duplicateMessage end
    return self:Add(values)
end

--- 批量写入导入地点，只构建一次重复索引并只触发一次刷新。
function Store:AddMany(valuesList, invalid)
    if SMK.DB:IsReadOnly() then return nil, "READ_ONLY" end
    if cacheDirty then RebuildCache() end
    local database = SMK.DB:Get()
    local existing = {}
    for _, entry in ipairs(cachedEntries) do
        existing[Model:GetDuplicateKey(entry)] = true
    end
    local result = { imported = 0, duplicates = 0, invalid = invalid or 0 }
    for _, values in ipairs(valuesList or {}) do
        local entry = Model:Normalize(values)
        local key = entry and Model:GetDuplicateKey(entry) or nil
        if not entry then
            result.invalid = result.invalid + 1
        elseif existing[key] then
            result.duplicates = result.duplicates + 1
        else
            entry.id = SMK.DB:NextLocationID()
            database.locations[#database.locations + 1] = entry
            existing[key] = true
            result.imported = result.imported + 1
        end
    end
    if result.imported > 0 then
        self:InvalidateCache()
        NotifyChanged("locations")
    end
    return result
end

function Store:Update(entry, values)
    if SMK.DB:IsReadOnly() then return false, "READ_ONLY" end
    if type(entry) ~= "table" or not entry.id then return false, "NOT_FOUND" end
    if cacheDirty then RebuildCache() end
    local database = SMK.DB:Get()
    local target = database.locations[storageIndexByID[entry.id]]
    if not target or target.id ~= entry.id then return false, "NOT_FOUND" end
    local normalized, errorMessage = Model:Normalize(values)
    if not normalized then return false, errorMessage end
    local duplicate, duplicateMessage = self:FindDuplicate(normalized, entry)
    if duplicate then return false, duplicateMessage end
    for _, key in ipairs(Model.persistentKeys) do target[key] = normalized[key] end
    self:InvalidateCache()
    NotifyChanged("locations")
    return true
end

function Store:DeleteMany(entries)
    if SMK.DB:IsReadOnly() then return 0, "READ_ONLY" end
    local database = SMK.DB:Get()
    local requestedIDs = {}
    for _, entry in ipairs(entries or {}) do
        if type(entry) == "table" and entry.id then requestedIDs[entry.id] = true end
    end
    local deleted, retained = 0, {}
    for _, entry in ipairs(database.locations) do
        if type(entry) == "table" and requestedIDs[entry.id] then
            database.usageCounts[entry.id] = nil
            deleted = deleted + 1
        else
            retained[#retained + 1] = entry
        end
    end
    if deleted > 0 then
        database.locations = retained
        self:InvalidateCache()
        NotifyChanged("locations")
    end
    return deleted
end

function Store:Delete(entry)
    return self:DeleteMany({ entry })
end

function Store:FindByCategory(category)
    local categoryKey = Config.GetCategoryKey(category)
    local matches = {}
    for _, entry in ipairs(self:GetAll()) do
        if entry.categoryKey == categoryKey then matches[#matches + 1] = entry end
    end
    return matches
end

function Store:FindDuplicate(values, excludeEntry)
    if not values or not values.mapID then return end
    if cacheDirty then RebuildCache() end
    local duplicates = duplicateIndexByMap[tonumber(values.mapID)]
    local entry = duplicates and duplicates[Model:GetDuplicateKey(values)]
    if entry and not (excludeEntry and excludeEntry.id == entry.id) then
        return entry, string.format(SMK.L.DUPLICATE_NAME, entry.name)
    end
end

local function UsageKey(entry)
    return tonumber(entry and entry.id)
end

function Store:GetUsage(entry)
    local key = UsageKey(entry)
    return key and tonumber(SMK.DB:Get().usageCounts[key]) or 0
end

function Store:RecordUsage(entry)
    if SMK.DB:IsReadOnly() or type(entry) ~= "table" or not entry.id then return false end
    local counts = SMK.DB:Get().usageCounts
    local key = UsageKey(entry)
    counts[key] = self:GetUsage(entry) + 1
    NotifyChanged("usage")
    return true
end

SMK.Store = Store
