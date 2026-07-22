local _, SMK = ...

local Import = {}

function Import:ImportEntries(entries, invalid)
    local readOnlyMessage = SMK.DB:GetReadOnlyMessage()
    if readOnlyMessage then return nil, readOnlyMessage end
    local existing = {}
    for _, entry in ipairs(SMK.Store:GetAll()) do
        existing[SMK.LocationModel:GetDuplicateKey(entry)] = true
    end
    local result = { imported = 0, duplicates = 0, invalid = invalid or 0 }
    for _, entry in ipairs(entries or {}) do
        local normalized = SMK.LocationModel:Normalize(entry)
        local key = normalized and SMK.LocationModel:GetDuplicateKey(normalized) or nil
        if not normalized then
            result.invalid = result.invalid + 1
        elseif existing[key] then
            result.duplicates = result.duplicates + 1
        else
            local added = SMK.Store:Add(normalized)
            if added then
                existing[key] = true
                result.imported = result.imported + 1
            else
                result.invalid = result.invalid + 1
            end
        end
    end
    return result
end

function Import:ImportText(text)
    local entries, errorMessage, invalid = SMK.ShareCodec:Decode(text)
    if not entries then return nil, errorMessage end
    return self:ImportEntries(entries, invalid)
end

SMK.Import = Import
