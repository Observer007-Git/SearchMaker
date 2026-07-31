--- 插件名称空间
-- 接收 WoW 传入的插件表，定义基础工具函数和聊天输出函数。
-- 所有其他模块都挂载到此表上。
local addonName, SMK = ...

SMK.name = addonName
SMK.version = C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
SMK.Util = {}

function SMK.Util.Trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function IsWideCodepoint(codepoint)
    return (codepoint >= 0x1100 and codepoint <= 0x115F)
        or codepoint == 0x2329 or codepoint == 0x232A
        or (codepoint >= 0x2E80 and codepoint <= 0xA4CF)
        or (codepoint >= 0xAC00 and codepoint <= 0xD7A3)
        or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
        or (codepoint >= 0xFE10 and codepoint <= 0xFE19)
        or (codepoint >= 0xFE30 and codepoint <= 0xFE6F)
        or (codepoint >= 0xFF00 and codepoint <= 0xFF60)
        or (codepoint >= 0xFFE0 and codepoint <= 0xFFE6)
        or (codepoint >= 0x1F300 and codepoint <= 0x1FAFF)
        or (codepoint >= 0x20000 and codepoint <= 0x3FFFD)
end

local function DecodeCodepoint(value, index)
    local first = value:byte(index)
    if not first then return end
    if first < 0x80 then return first, index + 1 end

    local length, codepoint, minimum
    if first >= 0xC2 and first <= 0xDF then
        length, codepoint, minimum = 2, first - 0xC0, 0x80
    elseif first >= 0xE0 and first <= 0xEF then
        length, codepoint, minimum = 3, first - 0xE0, 0x800
    elseif first >= 0xF0 and first <= 0xF4 then
        length, codepoint, minimum = 4, first - 0xF0, 0x10000
    else
        return nil
    end
    for offset = 1, length - 1 do
        local byte = value:byte(index + offset)
        if not byte or byte < 0x80 or byte > 0xBF then return nil end
        codepoint = codepoint * 0x40 + byte - 0x80
    end
    if codepoint < minimum or codepoint > 0x10FFFF
        or (codepoint >= 0xD800 and codepoint <= 0xDFFF) then
        return nil
    end
    return codepoint, index + length
end

local function EncodeCodepoint(codepoint)
    if codepoint < 0x80 then
        return string.char(codepoint)
    elseif codepoint < 0x800 then
        return string.char(0xC0 + math.floor(codepoint / 0x40),
            0x80 + codepoint % 0x40)
    elseif codepoint < 0x10000 then
        return string.char(0xE0 + math.floor(codepoint / 0x1000),
            0x80 + math.floor(codepoint / 0x40) % 0x40,
            0x80 + codepoint % 0x40)
    end
    return string.char(0xF0 + math.floor(codepoint / 0x40000),
        0x80 + math.floor(codepoint / 0x1000) % 0x40,
        0x80 + math.floor(codepoint / 0x40) % 0x40,
        0x80 + codepoint % 0x40)
end

local function FoldCodepoint(codepoint)
    if codepoint == 0x130 then
        return 0x69
    elseif codepoint == 0x178 then
        return 0xFF
    elseif codepoint == 0x1E9E then
        return 0xDF
    elseif codepoint == 0x3C2 then
        return 0x3C3
    elseif codepoint >= 0x41 and codepoint <= 0x5A
        or codepoint >= 0xC0 and codepoint <= 0xD6
        or codepoint >= 0xD8 and codepoint <= 0xDE then
        return codepoint + 0x20
    elseif codepoint >= 0x100 and codepoint <= 0x12F and codepoint % 2 == 0
        or codepoint >= 0x132 and codepoint <= 0x137 and codepoint % 2 == 0
        or codepoint >= 0x14A and codepoint <= 0x177 and codepoint % 2 == 0
        or codepoint >= 0x1E00 and codepoint <= 0x1E95 and codepoint % 2 == 0 then
        return codepoint + 1
    elseif codepoint >= 0x139 and codepoint <= 0x147 and codepoint % 2 == 1
        or codepoint >= 0x391 and codepoint <= 0x3A1
        or codepoint >= 0x3A3 and codepoint <= 0x3AB
        or codepoint >= 0x410 and codepoint <= 0x42F then
        return codepoint + 0x20
    elseif codepoint >= 0x400 and codepoint <= 0x40F then
        return codepoint + 0x50
    end
    return codepoint
end

--- 生成用于搜索和稳定排序的大小写折叠文本，并移除 ASCII 空白。
function SMK.Util.Normalize(text)
    local value = SMK.Util.Trim(text)
    local parts, index = {}, 1
    while index <= #value do
        local codepoint, nextIndex = DecodeCodepoint(value, index)
        if not codepoint then
            parts[#parts + 1] = value:sub(index, index):lower()
            index = index + 1
        else
            if not (codepoint == 0x20 or codepoint >= 0x09 and codepoint <= 0x0D) then
                parts[#parts + 1] = EncodeCodepoint(FoldCodepoint(codepoint))
            end
            index = nextIndex
        end
    end
    return table.concat(parts)
end

--- 返回按 Normalize 规则匹配到的原始文本字节范围。
-- 归一化会移除空白并折叠 Unicode 大小写，不能直接用普通字符串下标高亮。
function SMK.Util.GetNormalizedMatchRanges(text, query)
    local value = tostring(text or "")
    local normalizedQuery = SMK.Util.Normalize(query)
    if normalizedQuery == "" then return {} end

    local parts, starts, ends = {}, {}, {}
    local index, normalizedLength = 1, 0
    while index <= #value do
        local codepoint, nextIndex = DecodeCodepoint(value, index)
        local folded
        if not codepoint then
            folded = value:sub(index, index):lower()
            nextIndex = index + 1
        elseif not (codepoint == 0x20 or codepoint >= 0x09 and codepoint <= 0x0D) then
            folded = EncodeCodepoint(FoldCodepoint(codepoint))
        end
        if folded and folded ~= "" then
            parts[#parts + 1] = folded
            for offset = 1, #folded do
                starts[normalizedLength + offset] = index
                ends[normalizedLength + offset] = nextIndex - 1
            end
            normalizedLength = normalizedLength + #folded
        end
        index = nextIndex
    end

    local normalizedText = table.concat(parts)
    local ranges, cursor = {}, 1
    local first, last = normalizedText:find(normalizedQuery, cursor, true)
    while first do
        ranges[#ranges + 1] = { first = starts[first], last = ends[last] }
        cursor = last + 1
        first, last = normalizedText:find(normalizedQuery, cursor, true)
    end
    return ranges
end

function SMK.Util.SortKey(text)
    return SMK.Util.Normalize(text)
end

function SMK.Util.TruncateUTF8(text, maximumBytes)
    local value = tostring(text or "")
    maximumBytes = math.max(0, math.floor(tonumber(maximumBytes) or 0))
    if #value <= maximumBytes then return value end
    local index, last = 1, 0
    while index <= #value do
        local _, nextIndex = DecodeCodepoint(value, index)
        if not nextIndex or nextIndex - 1 > maximumBytes then break end
        last, index = nextIndex - 1, nextIndex
    end
    return value:sub(1, last)
end

local function IsZeroWidthCodepoint(codepoint)
    return codepoint == 0x200D
        or codepoint >= 0x300 and codepoint <= 0x36F
        or codepoint >= 0x1AB0 and codepoint <= 0x1AFF
        or codepoint >= 0x1DC0 and codepoint <= 0x1DFF
        or codepoint >= 0x20D0 and codepoint <= 0x20FF
        or codepoint >= 0xFE00 and codepoint <= 0xFE0F
        or codepoint >= 0xFE20 and codepoint <= 0xFE2F
        or codepoint >= 0x1F3FB and codepoint <= 0x1F3FF
        or codepoint >= 0xE0100 and codepoint <= 0xE01EF
end

--- 按显示宽度计算名称长度：东亚宽字符和 emoji 计 2，其他字符计 1。
-- @param text string
-- @return number|nil 非法 UTF-8 返回 nil。
function SMK.Util.GetTextWidth(text)
    local value = tostring(text or "")
    local width, index, joinNext, regionalPending = 0, 1, false, false
    while index <= #value do
        local codepoint, nextIndex = DecodeCodepoint(value, index)
        if not codepoint then return nil end
        local isRegional = codepoint >= 0x1F1E6 and codepoint <= 0x1F1FF
        if codepoint == 0x200D then
            joinNext = true
        elseif IsZeroWidthCodepoint(codepoint) or joinNext
            or isRegional and regionalPending then
            joinNext = false
            if isRegional then regionalPending = false end
        else
            width = width + ((isRegional or IsWideCodepoint(codepoint)) and 2 or 1)
            regionalPending = isRegional
        end
        index = nextIndex
    end
    return width
end

--- 判断文本是否包含汉字，覆盖基本区、兼容区和扩展区。
function SMK.Util.ContainsHan(text)
    local value, index = tostring(text or ""), 1
    while index <= #value do
        local codepoint, nextIndex = DecodeCodepoint(value, index)
        if not codepoint then return false end
        if (codepoint >= 0x3400 and codepoint <= 0x4DBF)
            or (codepoint >= 0x4E00 and codepoint <= 0x9FFF)
            or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
            or (codepoint >= 0x20000 and codepoint <= 0x323AF) then
            return true
        end
        index = nextIndex
    end
    return false
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
    local prefix = SMK.L and SMK.L.PREFIX or "[SearchMaker] "
    DEFAULT_CHAT_FRAME:AddMessage("|cffd9a441" .. prefix .. "|r" .. tostring(message or ""))
end
