local _, SMK = ...

local Codec = {}
local PREFIX = SMK.Config.share.prefix .. "R|"

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

function Codec:Encode(route)
    local normalized = SMK.RouteStore:Normalize(route)
    if not normalized then return end
    local records = {}
    for _, point in ipairs(normalized.items) do
        records[#records + 1] = table.concat({
            point.mapID,
            string.format("%.0f", point.x * 100),
            string.format("%.0f", point.y * 100),
            EncodeField(point.name),
        }, ",")
    end
    return PREFIX .. EncodeField(normalized.name) .. "|" .. table.concat(records, ";")
end

function Codec:Decode(text)
    local value = SMK.Util.Trim(text)
    if value:sub(1, #PREFIX) ~= PREFIX then
        return nil, SMK.L.ROUTE_IMPORT_INVALID
    end
    local separator = value:find("|", #PREFIX + 1, true)
    if not separator then return nil, SMK.L.ROUTE_IMPORT_INVALID end
    local route = {
        name = DecodeField(value:sub(#PREFIX + 1, separator - 1)),
        items = {},
    }
    local payload = value:sub(separator + 1)
    if payload == "" then return nil, SMK.L.ROUTE_IMPORT_INVALID end
    for record in payload:gmatch("[^;]+") do
        local fields = SplitRecord(record)
        if #fields ~= 4 then return nil, SMK.L.ROUTE_IMPORT_INVALID end
        route.items[#route.items + 1] = {
            mapID = tonumber(fields[1]),
            x = tonumber(fields[2]) and tonumber(fields[2]) / 100 or nil,
            y = tonumber(fields[3]) and tonumber(fields[3]) / 100 or nil,
            name = DecodeField(fields[4]),
        }
    end
    local normalized = SMK.RouteStore:Normalize(route)
    if not normalized then return nil, SMK.L.ROUTE_IMPORT_INVALID end
    return normalized
end

SMK.RouteCodec = Codec
