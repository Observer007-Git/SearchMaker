--- 插件名称空间
-- 接收 WoW 传入的插件表，定义基础工具函数和聊天输出函数。
-- 所有其他模块都挂载到此表上。
local addonName, SMK = ...

SMK.name = addonName
SMK.version = C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
SMK.State = {
    currentMapID = nil,
    currentEntries = {},
    totalLocationCount = 0,
}

SMK.Util = {}

function SMK.Util.Trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function SMK.Util.Normalize(text)
    return SMK.Util.Trim(text):lower():gsub("%s+", "")
end

--- 按显示宽度计算名称长度：ASCII 字符计 1，其他 UTF-8 字符计 2。
-- @param text string
-- @return number|nil 非法 UTF-8 返回 nil。
function SMK.Util.GetTextWidth(text)
    local value = tostring(text or "")
    local ok, characterCount = pcall(strlenutf8, value)
    if not ok then return nil end
    local asciiCount = 0
    for index = 1, #value do
        if value:byte(index) < 128 then asciiCount = asciiCount + 1 end
    end
    return asciiCount + (characterCount - asciiCount) * 2
end

function SMK.Util.CopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

--- 向默认聊天框输出一条带颜色的消息。
-- @param message string 要显示的文字。
function SMK:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd9a441" .. SMK.L.PREFIX .. "|r" .. tostring(message or ""))
end
