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
