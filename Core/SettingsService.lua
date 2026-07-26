local _, SMK = ...

local Settings = {}
local Schema = SMK.SettingsSchema
local changeHandler

function Settings:SetChangeHandler(callback)
    changeHandler = callback
end

function Settings:Get(key)
    return SMK.DB:Get().settings[key]
end

function Settings:Set(key, value)
    local readOnlyMessage = SMK.DB:GetReadOnlyMessage()
    if readOnlyMessage then return false, readOnlyMessage end
    local normalized = Schema:Normalize(key, value, false)
    if normalized == nil then return false, "INVALID_SETTING" end
    local settings = SMK.DB:Get().settings
    local previous = settings[key]
    if Schema:Equals(previous, normalized) then return true end
    settings[key] = normalized
    if changeHandler then changeHandler(key, normalized, previous) end
    return true
end

SMK.Settings = Settings
