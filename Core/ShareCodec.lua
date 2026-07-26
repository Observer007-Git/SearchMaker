local _, SMK = ...

local Codec = {}
local Config = SMK.Config
local Util = SMK.Util

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

local function GetPayload(text)
    if text:sub(1, #Config.share.prefix) ~= Config.share.prefix then
        return nil, SMK.L.IMPORT_INVALID_FORMAT
    end
    local payload = text:sub(#Config.share.prefix + 1)
    if payload == "" then return nil, SMK.L.IMPORT_EMPTY end
    return payload
end

function Codec:FindShareText(text)
    local value = tostring(text or "")
    local position = value:find(Config.share.prefix, 1, true)
    return position and value:sub(position) or nil
end

function Codec:Encode(entries)
    local records = {}
    for _, entry in ipairs(entries or {}) do
        local category = Config.categoryByKey[entry.categoryKey]
            or Config.categoryByKey[Config.defaultCategoryKey]
        records[#records + 1] = table.concat({
            entry.mapID,
            string.format("%.0f", entry.x * 100),
            string.format("%.0f", entry.y * 100),
            category.id,
            EncodeField(entry.name),
            entry.showPin or 0,
            tonumber(entry.pinTextureID) or SMK.DefaultPinTextureID,
            entry.showPinName or 0,
            entry.showPinTexture or 0,
        }, ",")
    end
    return Config.share.prefix .. table.concat(records, ";")
end

function Codec:Decode(text)
    local payload, formatError = GetPayload(Util.Trim(text))
    if not payload then return nil, formatError end

    local entries, invalid = {}, 0
    for record in payload:gmatch("[^;]+") do
        local fields = SplitRecord(record)
        local category = Config.categoryByID[tonumber(fields[4])]
        if not category then
            invalid = invalid + 1
        else
            local values = {
                mapID = tonumber(fields[1]),
                x = tonumber(fields[2]) and tonumber(fields[2]) / 100 or nil,
                y = tonumber(fields[3]) and tonumber(fields[3]) / 100 or nil,
                categoryKey = category.key,
                name = DecodeField(fields[5]),
                showPin = tonumber(fields[6]) or 0,
                pinTextureID = tonumber(fields[7]) or SMK.DefaultPinTextureID,
                showPinName = tonumber(fields[8]) or 0,
                showPinTexture = tonumber(fields[9]) or 0,
            }
            if #fields == 7 then
                values.showPinName = values.showPin
                values.showPinTexture = values.showPin
            end
            local entry = SMK.LocationModel:Normalize(values) or nil
            if entry then
                entries[#entries + 1] = entry
            else
                invalid = invalid + 1
            end
        end
    end
    return entries, nil, invalid
end

SMK.ShareCodec = Codec
