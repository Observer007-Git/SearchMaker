local _, SMK = ...

local Store = {}
local Config = SMK.Config
local Util = SMK.Util
local Model = SMK.LocationModel

local cacheDirty = true
local cachedEntries = {}
local mapIndex = {}
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
    local display = Model:Normalize(entry)
    if not display then return end
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
        end
    end
    cachedEntries = entries
    mapIndex = newMapIndex
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

function Store:Add(values)
    if SMK.DB:IsReadOnly() then return nil, "READ_ONLY" end
    local entry, errorMessage = Model:Normalize(values)
    if not entry then return nil, errorMessage end
    local database = SMK.DB:Get()
    entry.id = SMK.DB:NextLocationID()
    database.locations[#database.locations + 1] = entry
    self:InvalidateCache()
    local display = BuildSavedEntry(entry, #database.locations)
    NotifyChanged("locations")
    return display
end

function Store:AddExternal(entry)
    if type(entry) ~= "table" or not entry.isExternal
        or entry.externalSource ~= "HandyNotes_MapNotes" then
        return nil, "INVALID_LOCATION"
    end
    local values = {
        mapID = entry.mapID,
        x = entry.x,
        y = entry.y,
        name = entry.name,
        categoryKey = Config.defaultCategoryKey,
    }
    local duplicate, duplicateMessage = self:FindDuplicate(values)
    if duplicate then return nil, duplicateMessage end
    return self:Add(values)
end

function Store:Update(entry, values)
    if SMK.DB:IsReadOnly() then return false, "READ_ONLY" end
    if type(entry) ~= "table" or not entry.id then return false end
    local database = SMK.DB:Get()
    local target = database.locations[entry.sourceIndex]
    if not target or target.id ~= entry.id then
        target = nil
        for _, candidate in ipairs(database.locations) do
            if type(candidate) == "table" and candidate.id == entry.id then
                target = candidate
                break
            end
        end
    end
    if not target then return false end
    local updateValues = Util.CopyTable(values)
    local normalized = Model:Normalize(updateValues)
    if not normalized then return false end
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
    local deleted = 0
    for index = #database.locations, 1, -1 do
        local entry = database.locations[index]
        if type(entry) == "table" and requestedIDs[entry.id] then
            database.usageCounts["id:" .. entry.id] = nil
            table.remove(database.locations, index)
            deleted = deleted + 1
        end
    end
    if deleted > 0 then
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
    local duplicateKey = Model:GetDuplicateKey(values)
    for _, entry in ipairs(self:GetByMap(tonumber(values.mapID))) do
        if not (excludeEntry and excludeEntry.id == entry.id)
            and Model:GetDuplicateKey(entry) == duplicateKey then
            return entry, string.format(SMK.L.DUPLICATE_NAME, entry.name)
        end
    end
end

local function UsageKey(entry)
    return "id:" .. tostring(entry and entry.id)
end

function Store:GetUsage(entry)
    return tonumber(SMK.DB:Get().usageCounts[UsageKey(entry)]) or 0
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
