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

local function EncodeColor(color)
    if type(color) ~= "table" then return "" end
    local function Component(value)
        value = tonumber(value)
        if not value then return end
        return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
    end
    local r, g, b = Component(color.r), Component(color.g), Component(color.b)
    if not r or not g or not b then return "" end
    return string.format("%02X%02X%02X", r, g, b)
end

local function DecodeColor(text)
    if text == "" then return nil, true end
    if not tostring(text):match("^%x%x%x%x%x%x$") then return nil, false end
    return {
        r = tonumber(text:sub(1, 2), 16) / 255,
        g = tonumber(text:sub(3, 4), 16) / 255,
        b = tonumber(text:sub(5, 6), 16) / 255,
    }, true
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
        local pinTextureID = tonumber(entry.pinTextureID)
        if not SMK.PinTextureByID[pinTextureID] then
            pinTextureID = SMK.DefaultPinTextureID
        end
        local flags = (tonumber(entry.showPinName) == 1 and 1 or 0)
            + (tonumber(entry.showPinTexture) == 1 and 2 or 0)
        records[#records + 1] = table.concat({
            entry.mapID,
            string.format("%.0f", entry.x * 100),
            string.format("%.0f", entry.y * 100),
            category.id,
            EncodeField(entry.name),
            flags,
            pinTextureID,
            EncodeColor(entry.pinColor),
            tonumber(entry.customIconID) or "",
            EncodeField(entry.note),
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
        local flags = tonumber(fields[6])
        local pinTextureID = tonumber(fields[7])
        local pinColor, colorValid = DecodeColor(fields[8] or "")
        local customIconID = fields[9] ~= "" and tonumber(fields[9]) or nil
        local customIconValid = fields[9] == ""
            or (customIconID and SMK.IconCatalog:Get(customIconID))
        if #fields ~= 10 or not category or not flags or flags % 1 ~= 0
            or flags < 0 or flags > 3 or not SMK.PinTextureByID[pinTextureID]
            or not colorValid or not customIconValid then
            invalid = invalid + 1
        else
            local values = {
                mapID = tonumber(fields[1]),
                x = tonumber(fields[2]) and tonumber(fields[2]) / 100 or nil,
                y = tonumber(fields[3]) and tonumber(fields[3]) / 100 or nil,
                categoryKey = category.key,
                name = DecodeField(fields[5]),
                pinTextureID = pinTextureID,
                showPinName = flags % 2,
                showPinTexture = math.floor(flags / 2),
                pinColor = pinColor,
                customIconID = customIconID,
                note = DecodeField(fields[10]),
            }
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
