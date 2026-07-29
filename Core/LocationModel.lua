local _, SMK = ...

local Model = {}
local Config = SMK.Config
local Util = SMK.Util

Model.persistentKeys = {
    "mapID", "x", "y", "name", "categoryKey", "showPinName", "showPinTexture", "pinTextureID", "pinColor",
    "customIconID", "note",
}

function Model:Normalize(values)
    if type(values) ~= "table" then return nil, "INVALID_LOCATION" end
    local showPinName = values.showPinName == true or tonumber(values.showPinName) == 1
    local showPinTexture = values.showPinTexture == true or tonumber(values.showPinTexture) == 1
    local entry = {
        mapID = tonumber(values.mapID),
        x = tonumber(values.x),
        y = tonumber(values.y),
        name = Util.Trim(values.name),
        categoryKey = Config.GetCategoryKey(values.categoryKey),
        note = Util.Trim(values.note),
        showPinName = showPinName and 1 or 0,
        showPinTexture = showPinTexture and 1 or 0,
    }
    local pinTextureID = tonumber(values.pinTextureID)
    if not SMK.PinTextureByID[pinTextureID]
        and type(values.pinTexture) == "string" then
        pinTextureID = SMK.PinTextureIDByAtlas[values.pinTexture]
    end
    entry.pinTextureID = SMK.PinTextureByID[pinTextureID]
        and pinTextureID or SMK.DefaultPinTextureID
    local customIconID = tonumber(values.customIconID)
    entry.customIconID = customIconID and SMK.IconCatalog:Get(customIconID)
        and customIconID or nil
    local pinColor = type(values.pinColor) == "table" and values.pinColor or nil
    if pinColor and tonumber(pinColor.r) and tonumber(pinColor.g) and tonumber(pinColor.b) then
        entry.pinColor = {
            r = math.max(0, math.min(1, tonumber(pinColor.r))),
            g = math.max(0, math.min(1, tonumber(pinColor.g))),
            b = math.max(0, math.min(1, tonumber(pinColor.b))),
        }
    end
    if not entry.mapID or entry.mapID <= 0 or entry.mapID % 1 ~= 0
        or not entry.x or entry.x < 0 or entry.x > 100
        or not entry.y or entry.y < 0 or entry.y > 100
        or entry.name == "" then
        return nil, "INVALID_LOCATION"
    end
    local nameWidth = Util.GetTextWidth(entry.name)
    if not nameWidth or nameWidth > Config.location.maxNameWidth then
        return nil, "INVALID_LOCATION"
    end
    local noteWidth = Util.GetTextWidth(entry.note)
    if not noteWidth or noteWidth > Config.location.maxNoteWidth then
        return nil, "INVALID_LOCATION"
    end
    if entry.note == "" then entry.note = nil end
    return entry
end

function Model:CopyPersistent(entry)
    local copy = {}
    for _, key in ipairs(self.persistentKeys) do
        copy[key] = entry[key]
    end
    return copy
end

function Model:GetDuplicateKey(values)
    local mapID = math.floor(tonumber(values and values.mapID) or 0)
    local x = math.floor((tonumber(values and values.x) or 0) * 100 + 0.5)
    local y = math.floor((tonumber(values and values.y) or 0) * 100 + 0.5)
    return table.concat({ mapID, Util.Normalize(values and values.name), x, y }, "\031")
end

SMK.LocationModel = Model
