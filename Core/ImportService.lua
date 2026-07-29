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

--- 解码并分类待导入地点，不修改存档。
function Import:PreviewText(text)
    local entries, errorMessage, invalid = SMK.ShareCodec:Decode(text)
    if not entries then return nil, errorMessage end
    local preview = {
        entries = entries,
        items = {},
        importable = 0,
        duplicates = 0,
        invalid = invalid or 0,
    }
    local batchKeys = {}
    for _, entry in ipairs(entries) do
        local key = SMK.LocationModel:GetDuplicateKey(entry)
        local duplicate = batchKeys[key] or SMK.Store:FindDuplicate(entry)
        if duplicate then
            preview.duplicates = preview.duplicates + 1
        else
            preview.importable = preview.importable + 1
            batchKeys[key] = entry
        end
        preview.items[#preview.items + 1] = {
            entry = entry,
            duplicate = duplicate ~= nil,
        }
    end
    return preview
end

function Import:CommitPreview(preview)
    if type(preview) ~= "table" or type(preview.entries) ~= "table" then
        return nil, SMK.L.IMPORT_INVALID_FORMAT
    end
    return self:ImportEntries(preview.entries, preview.invalid, true)
end

SMK.Import = Import
