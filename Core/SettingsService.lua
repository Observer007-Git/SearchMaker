local _, SMK = ...

local Settings = {}
local Config = SMK.Config
local changeHandler

local booleanKeys = {
    showFullPanel = true,
    shortcutSearchVisible = true,
    showMapPins = true,
    searchAllMaps = true,
}

local positionKeys = {
    shortcutSearchBarPosition = true,
    mapSearchBarPosition = true,
}

local function SamePosition(a, b)
    return type(a) == "table" and type(b) == "table"
        and a.x == b.x and a.y == b.y and a.relativePoint == b.relativePoint
end

local function Normalize(key, value)
    if booleanKeys[key] then return value == true end
    if key == "locationScale" then
        local scale = tonumber(value)
        if not scale then return nil end
        scale = math.max(Config.location.minScale, math.min(Config.location.maxScale, scale))
        return math.floor(scale * 10 + 0.5) / 10
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
    if previous == normalized or SamePosition(previous, normalized) then return true end
    settings[key] = normalized
    if changeHandler then changeHandler(key, normalized, previous) end
    return true
end

SMK.Settings = Settings
