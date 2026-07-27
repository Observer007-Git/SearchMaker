local _, SMK = ...

local DB = {}
local Config = SMK.Config
local Model = SMK.LocationModel
local SettingsSchema = SMK.SettingsSchema
local rootKeys = {
    schemaVersion = true, locations = true, usageCounts = true, settings = true, nextLocationID = true,
}

local function AssignLocationIDs(database)
    database.nextLocationID = math.max(1, math.floor(tonumber(database.nextLocationID) or 1))
    local used = {}
    for _, entry in ipairs(database.locations) do
        if type(entry) == "table" then
            local id = tonumber(entry.id)
            if not id or id < 1 or id % 1 ~= 0 or used[id] then
                id = database.nextLocationID
                database.nextLocationID = database.nextLocationID + 1
            end
            entry.id = id
            used[id] = true
            database.nextLocationID = math.max(database.nextLocationID, id + 1)
        end
    end
end

local function NormalizeLocations(database)
    local valid = {}
    for _, stored in ipairs(database.locations) do
        local normalized = Model:Normalize(stored)
        if normalized then
            normalized.id = stored.id
            valid[#valid + 1] = normalized
        end
    end
    database.locations = valid
end

local function PruneUsageCounts(database)
    local counts = {}
    for _, entry in ipairs(database.locations) do
        local count = math.floor(tonumber(database.usageCounts[entry.id]) or 0)
        if count > 0 then counts[entry.id] = count end
    end
    database.usageCounts = counts
end

local function CreateFutureRuntime(database)
    local runtime = {
        locations = {},
        usageCounts = {},
        settings = SettingsSchema:NormalizeAll(database.settings),
        nextLocationID = 1,
        schemaVersion = database.schemaVersion,
    }
    for _, stored in ipairs(type(database.locations) == "table" and database.locations or {}) do
        local normalized = Model:Normalize(stored)
        if normalized then
            normalized.id = stored.id
            runtime.locations[#runtime.locations + 1] = normalized
        end
    end
    AssignLocationIDs(runtime)
    for _, entry in ipairs(runtime.locations) do
        local count = math.floor(tonumber(type(database.usageCounts) == "table"
            and database.usageCounts[entry.id]) or 0)
        if count > 0 then runtime.usageCounts[entry.id] = count end
    end
    return runtime
end

--- 初始化当前存档结构。更高版本的存档只读打开，避免旧插件覆盖新数据。
function DB:Initialize()
    SearchMakerDB = type(SearchMakerDB) == "table" and SearchMakerDB or {}
    local database = SearchMakerDB
    local schemaVersion = math.max(0, math.floor(tonumber(database.schemaVersion) or 0))
    self.savedData = database
    self.futureSchemaVersion = nil
    if schemaVersion > Config.databaseSchemaVersion then
        self.readOnly = true
        self.futureSchemaVersion = schemaVersion
        self.data = CreateFutureRuntime(database)
        return self.data
    end

    self.readOnly = false
    database.schemaVersion = Config.databaseSchemaVersion
    database.locations = type(database.locations) == "table" and database.locations or {}
    database.usageCounts = type(database.usageCounts) == "table" and database.usageCounts or {}
    database.settings = SettingsSchema:NormalizeAll(database.settings)
    for key in pairs(database) do
        if not rootKeys[key] then database[key] = nil end
    end
    NormalizeLocations(database)
    AssignLocationIDs(database)
    PruneUsageCounts(database)
    self.data = database
    return database
end

function DB:Get()
    return self.data or self:Initialize()
end

function DB:IsReadOnly()
    return self.readOnly == true
end

function DB:GetFutureSchemaVersion()
    return self.futureSchemaVersion
end

function DB:GetReadOnlyMessage()
    if not self:IsReadOnly() then return end
    return string.format(SMK.L.DATABASE_READ_ONLY,
        self:GetFutureSchemaVersion(), Config.databaseSchemaVersion)
end

function DB:NextLocationID()
    if self:IsReadOnly() then return nil end
    local database = self:Get()
    local id = database.nextLocationID
    database.nextLocationID = database.nextLocationID + 1
    return id
end

SMK.DB = DB
