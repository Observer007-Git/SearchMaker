local _, SMK = ...

local Schema = {}
local Config = SMK.Config

local definitions = {
    locationScale = {
        kind = "number", min = Config.location.minScale, max = Config.location.maxScale, decimals = 1,
    },
    mapPinTextScale = {
        kind = "number", min = Config.mapPins.minTextScale, max = Config.mapPins.maxTextScale, decimals = 1,
    },
    pinTextureScale = {
        kind = "number", min = Config.mapPins.minTextureScale, max = Config.mapPins.maxTextureScale, decimals = 1,
    },
    mapPinNameOffsetX = {
        kind = "number", min = Config.mapPins.nameOffsetXMin, max = Config.mapPins.nameOffsetXMax,
    },
    mapPinNameOffsetY = {
        kind = "number", min = Config.mapPins.nameOffsetYMin, max = Config.mapPins.nameOffsetYMax,
    },
    searchBarScale = {
        kind = "number", min = Config.search.appearance.minScale,
        max = Config.search.appearance.maxScale, decimals = 1,
    },
    searchBarOpacity = {
        kind = "number", min = Config.search.appearance.minOpacity,
        max = Config.search.appearance.maxOpacity, decimals = 1,
    },
    searchBarStyle = {
        kind = "enum", values = Config.search.appearance.styles.values,
    },
    shortcutSearchVisible = { kind = "boolean" },
    searchAllMaps = { kind = "boolean" },
    exportBatchSize = { kind = "enum", values = Config.export.batchSizes },
    shortcutSearchBarPosition = { kind = "position" },
    mapSearchBarPosition = { kind = "position" },
}

local keys = {
    "locationScale", "mapPinTextScale", "pinTextureScale",
    "mapPinNameOffsetX", "mapPinNameOffsetY", "searchBarScale", "searchBarOpacity",
    "searchBarStyle",
    "shortcutSearchVisible", "searchAllMaps", "exportBatchSize",
    "shortcutSearchBarPosition", "mapSearchBarPosition",
}

local function Copy(value)
    return type(value) == "table" and SMK.Util.CopyTable(value) or value
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function NormalizeValue(definition, value)
    if definition.kind == "boolean" then
        if type(value) == "boolean" then return value end
        return nil
    elseif definition.kind == "number" then
        value = tonumber(value)
        if not value then return nil end
        value = Clamp(value, definition.min, definition.max)
        local factor = 10 ^ (definition.decimals or 0)
        return math.floor(value * factor + 0.5) / factor
    elseif definition.kind == "enum" then
        value = tonumber(value)
        for _, option in ipairs(definition.values) do
            if value == option then return option end
        end
        return nil
    elseif definition.kind == "position" then
        if type(value) ~= "table"
            or type(value.x) ~= "number" or type(value.y) ~= "number" then
            return nil
        end
        return { x = value.x, y = value.y, relativePoint = value.relativePoint }
    end
end

function Schema:Normalize(key, value, useDefault)
    local definition = definitions[key]
    if not definition then return nil end
    local normalized = NormalizeValue(definition, value)
    if normalized ~= nil or not useDefault then return normalized end
    return Copy(Config.settingsDefaults[key])
end

function Schema:NormalizeAll(source)
    source = type(source) == "table" and source or {}
    local result = {}
    for _, key in ipairs(keys) do
        local value = self:Normalize(key, source[key], true)
        if value ~= nil then result[key] = value end
    end
    return result
end

function Schema:Equals(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for key, value in pairs(a) do
        if b[key] ~= value then return false end
    end
    for key, value in pairs(b) do
        if a[key] ~= value then return false end
    end
    return true
end

SMK.SettingsSchema = Schema
