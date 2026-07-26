local _, SMK = ...

local DB = {}
local Config = SMK.Config
local Model = SMK.LocationModel
local obsoleteRootKeys = {
    "locationScale", "showFullPanel", "shortcutSearchVisible", "showMapPins", "showMapPinNames", "searchAllMaps",
    "shortcutSearchBarPosition", "mapSearchBarPosition", "locationEdits", "locationDeletions",
}

local function CopyPosition(position)
    if type(position) ~= "table" or type(position.x) ~= "number" or type(position.y) ~= "number" then
        return nil
    end
    return {
        x = position.x,
        y = position.y,
        relativePoint = position.relativePoint,
    }
end

local function NormalizeSettings(source)
    source = type(source) == "table" and source or {}
    local sourceColor = type(source.mapPinTextColor) == "table" and source.mapPinTextColor or {}
    local defaultColor = Config.settingsDefaults.mapPinTextColor
    local function NumberInRange(key, minimum, maximum, decimals)
        local value = tonumber(source[key]) or Config.settingsDefaults[key]
        value = math.max(minimum, math.min(maximum, value))
        local factor = 10 ^ (decimals or 0)
        return math.floor(value * factor + 0.5) / factor
    end
    local function ColorComponent(key)
        local value = tonumber(sourceColor[key]) or defaultColor[key]
        return math.max(0, math.min(1, value))
    end
    local function BooleanOrDefault(key)
        if type(source[key]) == "boolean" then return source[key] end
        return Config.settingsDefaults[key]
    end
    local function ExportBatchSize()
        local value = tonumber(source.exportBatchSize)
        for _, option in ipairs(Config.export.batchSizes) do
            if value == option then return option end
        end
        return Config.settingsDefaults.exportBatchSize
    end
    return {
        locationScale = NumberInRange("locationScale",
            Config.location.minScale, Config.location.maxScale, 1),
        mapPinTextScale = NumberInRange("mapPinTextScale",
            Config.mapPins.minTextScale, Config.mapPins.maxTextScale, 1),
        pinTextureScale = NumberInRange("pinTextureScale",
            Config.mapPins.minTextureScale, Config.mapPins.maxTextureScale, 1),
        mapPinNameOffsetX = NumberInRange("mapPinNameOffsetX",
            Config.mapPins.nameOffsetXMin, Config.mapPins.nameOffsetXMax),
        mapPinNameOffsetY = NumberInRange("mapPinNameOffsetY",
            Config.mapPins.nameOffsetYMin, Config.mapPins.nameOffsetYMax),
        searchBarScale = NumberInRange("searchBarScale", 0.5, 2, 1),
        searchBarOpacity = NumberInRange("searchBarOpacity", 0.2, 1, 1),
        mapPinTextColor = {
            r = ColorComponent("r"),
            g = ColorComponent("g"),
            b = ColorComponent("b"),
        },
        shortcutSearchVisible = BooleanOrDefault("shortcutSearchVisible"),
        showMapPinNames = BooleanOrDefault("showMapPinNames"),
        showPinTextures = BooleanOrDefault("showPinTextures"),
        searchAllMaps = BooleanOrDefault("searchAllMaps"),
        exportBatchSize = ExportBatchSize(),
        shortcutSearchBarPosition = CopyPosition(source.shortcutSearchBarPosition),
        mapSearchBarPosition = CopyPosition(source.mapSearchBarPosition),
    }
end

local function AssignLocationIDs(database)
    database.nextLocationID = math.max(1, math.floor(tonumber(database.nextLocationID) or 1))
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

local function NormalizeLocations(database)
    for _, stored in ipairs(database.locations) do
        local normalized = Model:Normalize(stored)
        if normalized then
            for _, key in ipairs(Model.persistentKeys) do stored[key] = normalized[key] end
            stored.category = nil
            stored.pinTexture = nil
            stored.icon = nil
        end
    end
end

local function CreateFutureRuntime(database)
    local runtime = SMK.Util.CopyTable(database)
    runtime.locations = type(database.locations) == "table" and database.locations or {}
    runtime.usageCounts = type(database.usageCounts) == "table" and database.usageCounts or {}
    runtime.settings = NormalizeSettings(database.settings)
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
    database.settings = NormalizeSettings(database.settings)
    for _, key in ipairs(obsoleteRootKeys) do database[key] = nil end
    AssignLocationIDs(database)
    NormalizeLocations(database)
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
