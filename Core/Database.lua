local _, SMK = ...

local DB = {}
local Config = SMK.Config

local function NormalizeStoredLocation(entry)
    if type(entry) ~= "table" then return end
    entry.mapID = tonumber(entry.mapID)
    entry.x = tonumber(entry.x)
    entry.y = tonumber(entry.y)
    entry.categoryKey = Config.GetCategoryKey(entry.categoryKey or entry.category)
    entry.category = nil
    entry.showPin = (entry.showPin == true or tonumber(entry.showPin) == 1) and 1 or 0
    local pinTextureID = tonumber(entry.pinTextureID or entry.pinTexture)
    entry.pinTextureID = pinTextureID and SMK.PinTextureByID[pinTextureID] and pinTextureID or 1
    entry.pinTexture = nil
    if entry.keywords ~= nil and type(entry.keywords) ~= "string" then
        entry.keywords = tostring(entry.keywords)
    end
end

--- 确保每个保存的地点都有唯一的字符串 id。
local function AssignSavedLocationIDs(database)
    database.nextLocationID = math.max(1, tonumber(database.nextLocationID) or 1)
    local used = {}
    for _, entry in ipairs(database.locations) do
        if type(entry) == "table" then
            if type(entry.id) ~= "string" or entry.id == "" or used[entry.id] then
                entry.id = "user:" .. database.nextLocationID
                database.nextLocationID = database.nextLocationID + 1
            end
            used[entry.id] = true
            local numericID = tonumber(entry.id:match("^user:(%d+)$"))
            if numericID then
                database.nextLocationID = math.max(database.nextLocationID, numericID + 1)
            end
        end
    end
end

local Migrations = {
    [1] = function(database)
        AssignSavedLocationIDs(database)
    end,
    [2] = function(database)
        for _, entry in ipairs(database.locations) do
            NormalizeStoredLocation(entry)
        end
        database.locationEdits = nil
        database.locationDeletions = nil
    end,
}

local function CreateFutureRuntime(database)
    local runtime = SMK.Util.CopyTable(database)
    runtime.locations = type(database.locations) == "table" and database.locations or {}
    runtime.usageCounts = type(database.usageCounts) == "table" and database.usageCounts or {}
    local locationScale = tonumber(database.locationScale) or Config.location.defaultScale
    locationScale = math.max(Config.location.minScale, math.min(Config.location.maxScale, locationScale))
    runtime.locationScale = math.floor(locationScale * 10 + 0.5) / 10
    if type(runtime.showFullPanel) ~= "boolean" then runtime.showFullPanel = true end
    if type(runtime.shortcutSearchVisible) ~= "boolean" then runtime.shortcutSearchVisible = false end
    if type(runtime.showMapPins) ~= "boolean" then runtime.showMapPins = false end
    if type(runtime.searchAllMaps) ~= "boolean" then runtime.searchAllMaps = false end
    return runtime
end

--- 初始化保存数据并顺序执行 schema 迁移。可多次安全调用。
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
    database.locations = type(database.locations) == "table" and database.locations or {}
    database.usageCounts = type(database.usageCounts) == "table" and database.usageCounts or {}
    while schemaVersion < Config.databaseSchemaVersion do
        schemaVersion = schemaVersion + 1
        local migrate = Migrations[schemaVersion]
        if migrate then migrate(database) end
        database.schemaVersion = schemaVersion
    end

    local locationScale = tonumber(database.locationScale) or Config.location.defaultScale
    locationScale = math.max(Config.location.minScale, math.min(Config.location.maxScale, locationScale))
    database.locationScale = math.floor(locationScale * 10 + 0.5) / 10
    if type(database.showFullPanel) ~= "boolean" then database.showFullPanel = true end
    if type(database.shortcutSearchVisible) ~= "boolean" then database.shortcutSearchVisible = false end
    if type(database.showMapPins) ~= "boolean" then database.showMapPins = false end
    if type(database.searchAllMaps) ~= "boolean" then database.searchAllMaps = false end

    -- 每次加载都执行轻量修复，以处理外部手工修改的 SavedVariables。
    AssignSavedLocationIDs(database)
    for _, entry in ipairs(database.locations) do
        NormalizeStoredLocation(entry)
    end

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
    local id = "user:" .. database.nextLocationID
    database.nextLocationID = database.nextLocationID + 1
    return id
end

SMK.DB = DB
