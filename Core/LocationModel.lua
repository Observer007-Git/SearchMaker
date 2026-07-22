local _, SMK = ...

local Model = {}
local Config = SMK.Config
local Util = SMK.Util

Model.persistentKeys = {
    "mapID", "x", "y", "name", "categoryKey", "showPin", "pinTextureID", "keywords",
}

function Model:Normalize(values)
    if type(values) ~= "table" then return nil, "INVALID_LOCATION" end
    local entry = {
        mapID = tonumber(values.mapID),
        x = tonumber(values.x),
        y = tonumber(values.y),
        name = Util.Trim(values.name),
        categoryKey = Config.GetCategoryKey(values.categoryKey),
        showPin = (values.showPin == true or tonumber(values.showPin) == 1) and 1 or 0,
        keywords = values.keywords ~= nil and Util.Trim(values.keywords) or nil,
    }
    local pinTextureID = tonumber(values.pinTextureID)
    entry.pinTextureID = pinTextureID and SMK.PinTextureByID[pinTextureID]
        and pinTextureID or SMK.DefaultPinTextureID
    if entry.keywords == "" then entry.keywords = nil end
    if not entry.mapID or entry.mapID <= 0 or entry.mapID % 1 ~= 0
        or not entry.x or entry.x < 0 or entry.x > 100
        or not entry.y or entry.y < 0 or entry.y > 100
        or entry.name == "" then
        return nil, "INVALID_LOCATION"
    end
    local ok, length = pcall(strlenutf8, entry.name)
    if not ok or length > Config.location.maxNameLength then
        return nil, "INVALID_LOCATION"
    end
    return entry
end

function Model:GetDuplicateKey(values)
    local mapID = math.floor(tonumber(values and values.mapID) or 0)
    local x = math.floor((tonumber(values and values.x) or 0) * 100 + 0.5)
    local y = math.floor((tonumber(values and values.y) or 0) * 100 + 0.5)
    return table.concat({ mapID, Util.Normalize(values and values.name), x, y }, "\031")
end

SMK.LocationModel = Model
