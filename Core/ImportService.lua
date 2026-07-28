local _, SMK = ...

local Import = {}

function Import:ImportEntries(entries, invalid, alreadyNormalized)
    local readOnlyMessage = SMK.DB:GetReadOnlyMessage()
    if readOnlyMessage then return nil, readOnlyMessage end
    return SMK.Store:AddMany(entries, invalid, alreadyNormalized)
end

function Import:ImportText(text)
    local entries, errorMessage, invalid = SMK.ShareCodec:Decode(text)
    if not entries then return nil, errorMessage end
    return self:ImportEntries(entries, invalid, true)
end

SMK.Import = Import
