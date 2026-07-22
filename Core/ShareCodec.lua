local _, SMK = ...

local Codec = {}
local Config = SMK.Config
local Util = SMK.Util

local supportedPrefixes = { Config.share.prefix, "SMK3|", "SMK2|", "MLL2|", "MLL1|" }

local function EncodeField(text)
    return (tostring(text or "")
        :gsub("%%", "%%25")
        :gsub("|", "%%7C")
        :gsub(",", "%%2C")
        :gsub(";", "%%3B")
        :gsub("\r", "%%0D")
        :gsub("\n", "%%0A"))
end

local function DecodeField(text)
    return (tostring(text or ""):gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function SplitRecord(record)
    local fields, startAt = {}, 1
    while true do
        local commaAt = record:find(",", startAt, true)
        if not commaAt then
            fields[#fields + 1] = record:sub(startAt)
            return fields
        end
        fields[#fields + 1] = record:sub(startAt, commaAt - 1)
        startAt = commaAt + 1
    end
end

local function GetPrefix(text)
    for _, prefix in ipairs(supportedPrefixes) do
        if text:sub(1, #prefix) == prefix then return prefix end
    end
end

function Codec:FindShareText(text)
    local bestPosition
    for _, prefix in ipairs(supportedPrefixes) do
        local position = tostring(text or ""):find(prefix, 1, true)
        if position and (not bestPosition or position < bestPosition) then bestPosition = position end
    end
    return bestPosition and tostring(text):sub(bestPosition) or nil
end

function Codec:Encode(entries)
    local records = {}
    for _, entry in ipairs(entries or {}) do
        local category = Config.categoryByKey[entry.categoryKey] or Config.categoryByKey[Config.defaultCategoryKey]
        records[#records + 1] = table.concat({
            entry.mapID,
            string.format("%.0f", entry.x * 100),
            string.format("%.0f", entry.y * 100),
            category.id,
            EncodeField(entry.name),
            entry.showPin or 0,
            tonumber(entry.pinTextureID) or 1,
        }, ",")
    end
    return Config.share.prefix .. table.concat(records, ";")
end

local function DecodeCategory(field, prefix)
    if prefix == "MLL1|" then return Config.defaultCategoryKey end
    local decoded = DecodeField(field)
    local categoryID = tonumber(decoded)
    if categoryID and Config.categoryByID[categoryID] then
        return Config.categoryByID[categoryID].key
    end
    return Config.GetCategoryKey(decoded)
end

local function DecodeCoordinates(fields, prefix)
    local x, y = tonumber(fields[2]), tonumber(fields[3])
    if not x or not y then return end
    if prefix == Config.share.prefix or prefix == "SMK3|" then
        return x / 100, y / 100
    end
    return x, y
end

function Codec:Decode(text)
    text = Util.Trim(text)
    local prefix = GetPrefix(text)
    if not prefix then return nil, SMK.L.IMPORT_INVALID_FORMAT end
    local payload = text:sub(#prefix + 1)
    if payload == "" then return nil, SMK.L.IMPORT_EMPTY end

    local entries, invalid = {}, 0
    for record in payload:gmatch("[^;]+") do
        local fields = SplitRecord(record)
        local x, y = DecodeCoordinates(fields, prefix)
        local values = {
            mapID = tonumber(fields[1]),
            x = x,
            y = y,
            categoryKey = DecodeCategory(fields[4], prefix),
            name = DecodeField(fields[5]),
            icon = Config.art.defaultLocationIcon,
            showPin = tonumber(fields[6]) or 0,
            pinTextureID = tonumber(fields[7]) or 1,
        }
        local entry = #fields >= 5 and SMK.Store:NormalizeLocation(values) or nil
        if entry then
            entries[#entries + 1] = entry
        else
            invalid = invalid + 1
        end
    end
    return entries, nil, invalid
end

SMK.ShareCodec = Codec
