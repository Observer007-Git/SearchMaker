local _, SMK = ...

local Settings = {}
local Config = SMK.Config
local changeHandler

local booleanKeys = {
    shortcutSearchVisible = true,
    showMapPinNames = true,
    showPinTextures = true,
    searchAllMaps = true,
}

local positionKeys = {
    shortcutSearchBarPosition = true,
    mapSearchBarPosition = true,
}

local function SamePosition(a, b)
    return type(a) == "table" and type(b) == "table"
        and type(a.x) == "number" and type(a.y) == "number"
        and type(b.x) == "number" and type(b.y) == "number"
        and a.x == b.x and a.y == b.y and a.relativePoint == b.relativePoint
end

local function SameColor(a, b)
    return type(a) == "table" and type(b) == "table"
        and type(a.r) == "number" and type(a.g) == "number" and type(a.b) == "number"
        and type(b.r) == "number" and type(b.g) == "number" and type(b.b) == "number"
        and a.r == b.r and a.g == b.g and a.b == b.b
end

local function Normalize(key, value)
    if booleanKeys[key] then return value == true end
    if key == "locationScale" then
        local scale = tonumber(value)
        if not scale then return nil end
        scale = math.max(Config.location.minScale, math.min(Config.location.maxScale, scale))
        return math.floor(scale * 10 + 0.5) / 10
    end
    if key == "searchBarScale" then
        local scale = tonumber(value)
        if not scale then return nil end
        scale = math.max(0.5, math.min(2, scale))
        return math.floor(scale * 10 + 0.5) / 10
    end
    if key == "searchBarOpacity" then
        local opacity = tonumber(value)
        if not opacity then return nil end
        return math.max(0.2, math.min(1, opacity))
    end
    if key == "exportBatchSize" then
        local batchSize = tonumber(value)
        for _, option in ipairs(Config.export.batchSizes) do
            if batchSize == option then return option end
        end
        return nil
    end
    if key == "mapPinTextScale" then
        local scale = tonumber(value)
        if not scale then return nil end
        scale = math.max(Config.mapPins.minTextScale, math.min(Config.mapPins.maxTextScale, scale))
        return math.floor(scale * 10 + 0.5) / 10
    end
    if key == "pinTextureScale" then
        local scale = tonumber(value)
        if not scale then return nil end
        scale = math.max(Config.mapPins.minTextureScale, math.min(Config.mapPins.maxTextureScale, scale))
        return math.floor(scale * 10 + 0.5) / 10
    end
    if key == "mapPinNameOffsetX" or key == "mapPinNameOffsetY" then
        local offset = tonumber(value)
        if not offset then return nil end
        local axis = key:sub(-1)
        local minVal = Config.mapPins["nameOffset" .. axis .. "Min"]
        local maxVal = Config.mapPins["nameOffset" .. axis .. "Max"]
        return math.max(minVal, math.min(maxVal, math.floor(offset + 0.5)))
    end
    if key == "mapPinTextColor" then
        if type(value) ~= "table" or not tonumber(value.r)
            or not tonumber(value.g) or not tonumber(value.b) then return nil end
        return {
            r = math.max(0, math.min(1, tonumber(value.r))),
            g = math.max(0, math.min(1, tonumber(value.g))),
            b = math.max(0, math.min(1, tonumber(value.b))),
        }
    end
    if positionKeys[key] then
        if type(value) ~= "table" or type(value.x) ~= "number" or type(value.y) ~= "number" then
            return nil
        end
        return { x = value.x, y = value.y, relativePoint = value.relativePoint }
    end
end

function Settings:SetChangeHandler(callback)
    changeHandler = callback
end

function Settings:Get(key)
    return SMK.DB:Get().settings[key]
end

function Settings:Set(key, value)
    local readOnlyMessage = SMK.DB:GetReadOnlyMessage()
    if readOnlyMessage then return false, readOnlyMessage end
    local normalized = Normalize(key, value)
    if normalized == nil then return false, "INVALID_SETTING" end
    local settings = SMK.DB:Get().settings
    local previous = settings[key]
    if previous == normalized or SamePosition(previous, normalized)
        or SameColor(previous, normalized) then return true end
    settings[key] = normalized
    if changeHandler then changeHandler(key, normalized, previous) end
    return true
end

SMK.Settings = Settings
