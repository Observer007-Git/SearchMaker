local _, SMK = ...

local Import = {}

function Import:ImportEntries(entries, invalid)
    local readOnlyMessage = SMK.DB:GetReadOnlyMessage()
    if readOnlyMessage then return nil, readOnlyMessage end
    return SMK.Store:AddMany(entries, invalid)
end

function Import:ImportText(text)
    local entries, errorMessage, invalid = SMK.ShareCodec:Decode(text)
    if not entries then return nil, errorMessage end
    return self:ImportEntries(entries, invalid)
end

SMK.Import = Import
