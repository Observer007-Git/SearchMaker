local root = assert(arg[1], "usage: lua Tests/LocaleTest.lua <addon-root>")

local activeLocale = "enUS"
function GetLocale() return activeLocale end
C_AddOns = { GetAddOnMetadata = function() return "test" end }

local function loadModule(namespace, path)
    local chunk = assert(loadfile(root .. "/" .. path))
    return chunk("SearchMaker", namespace)
end

local function loadLocale(locale)
    activeLocale = locale
    local namespace = {}
    loadModule(namespace, "Core/Namespace.lua")
    loadModule(namespace, "Core/AtlasTextures.lua")
    loadModule(namespace, "Core/PathTextures.lua")
    loadModule(namespace, "Core/IconCatalog.lua")
    loadModule(namespace, "Config.lua")
    loadModule(namespace, "Locales/init.lua")
    loadModule(namespace, "Locales/enUS.lua")
    loadModule(namespace, "Locales/zhCN.lua")
    return namespace
end

local function FormatSignature(text)
    local signature = {}
    for specifier in tostring(text):gmatch("%%[-+ #0]*%d*%.?%d*[cdeEfgGiouXxsq]") do
        signature[#signature + 1] = specifier
    end
    return table.concat(signature, "|")
end

local english = loadLocale("enUS")
local chinese = loadLocale("zhCN")
local traditionalChinese = loadLocale("zhTW")
for key, value in pairs(english.L) do
    assert(chinese.L[key], "zhCN missing locale key: " .. key)
    assert(FormatSignature(value) == FormatSignature(chinese.L[key]),
        "locale format signature mismatch: " .. key)
end
for key in pairs(chinese.L) do assert(english.L[key], "enUS missing locale key: " .. key) end
assert(english.L.ADD == "Add Coordinate" and chinese.L.ADD == "新增坐标", "locale selection failed")
assert(traditionalChinese.L.ADD == english.L.ADD,
    "a non-zhCN client did not fall back to English")
assert(english.L.READ_COORDINATES == "Get Character Coordinates"
    and chinese.L.READ_COORDINATES == "读取角色坐标",
    "coordinate button locale was not updated")
assert(english.L.COORDINATE_RESULT_FORMAT and chinese.L.COORDINATE_RESULT_FORMAT,
    "coordinate result locale is missing")
assert(english.L.CUSTOM_ICON == "Custom Icon" and chinese.L.CUSTOM_ICON == "自定义图标"
    and english.L.CUSTOM_ICON_ATLAS and chinese.L.CUSTOM_ICON_PATH
    and english.L.MAP_PIN_SETTINGS_LABEL == "Map Pin Settings:"
    and chinese.L.MAP_PIN_SETTINGS_LABEL == "地图标记设置："
    and chinese.L.CUSTOM_PIN_COLOR == "显示标记文字颜色",
    "custom icon locale is missing")
for index, englishIcon in ipairs(english.IconCatalog.all) do
    local chineseIcon = chinese.IconCatalog.all[index]
    assert(chineseIcon and chineseIcon.id == englishIcon.id
        and english.IconCatalog:GetNote(englishIcon)
        and chinese.IconCatalog:GetNote(chineseIcon),
        "custom icon tooltip locale is missing for ID " .. englishIcon.id)
end
for key in pairs(english.L.ICON_NOTES) do
    assert(chinese.L.ICON_NOTES[key], "zhCN missing custom icon note: " .. key)
end
for key in pairs(chinese.L.ICON_NOTES) do
    assert(english.L.ICON_NOTES[key], "enUS missing custom icon note: " .. key)
end
assert(english.IconCatalog:GetNote(1) == "Alliance"
    and chinese.IconCatalog:GetNote(1) == "联盟"
    and traditionalChinese.IconCatalog:GetNote(-3) == "Cooking",
    "custom icon tooltip did not follow the active locale")
assert(english.L.EXPORT_BATCH_SIZE == "Maximum per Export"
    and chinese.L.EXPORT_BATCH_SIZE == "最大单次导出数量",
    "export batch size locale is missing")
assert(english.L.SEARCH_BAR_SETTINGS == "Search Settings"
    and chinese.L.SEARCH_BAR_SETTINGS == "搜索设置"
    and english.L.SEARCH_ALL_MAPS == "Search All Maps"
    and chinese.L.SEARCH_ALL_MAPS == "搜索 所有地图"
    and english.L.EXTERNAL_SOURCE == "External Source"
    and chinese.L.HANDYNOTES_SOURCE_SUFFIX == "[HandyNotes_MapNotes]"
    and chinese.L.HANDYNOTES_PORTAL == "传送门",
    "search settings or external source locale is missing")
assert(english.L.HELP == "How to Use" and chinese.L.HELP == "使用说明"
    and english.L.HELP_TITLE == "SearchMaker Guide"
    and chinese.L.HELP_TITLE == "SearchMaker 使用说明"
    and english.L.HELP_TEXT and chinese.L.HELP_TEXT
    and chinese.L.HELP_TEXT:find("搜索所有地图", 1, true)
    and chinese.L.HELP_TEXT:find("从私聊接收的分享消息中导入", 1, true)
    and english.L.HELP_TEXT:find("character and Battle.net whispers", 1, true)
    and english.L.HELP_TEXT:find("All Maps", 1, true)
    and not chinese.L.HELP_TEXT:find("当前地图/全图", 1, true),
    "help dialog locale is missing")
assert(english.L.ROUTE_SEARCH_KEYWORD == "route"
    and chinese.L.ROUTE_SEARCH_KEYWORD == "路线"
    and chinese.L.MENU_OPEN_ROUTE == "打开路线"
    and chinese.L.MENU_ACTIVATE_ROUTE == "激活路线"
    and chinese.L.MENU_SHARE_ROUTE == "分享路线"
    and chinese.L.MENU_DELETE_ROUTE == "删除路线"
    and chinese.L.MENU_OPEN_MAP == "打开地图"
    and chinese.L.HELP_TEXT:find("搜索完整关键字“路线”", 1, true),
    "saved route search or action locale is missing")
assert(english.Config.GetCategoryKey("delves") == "delves", "canonical category key failed")
assert(english.Config.GetCategoryKey("地下堡") == "other", "localized category leaked into storage")

print("SearchMaker locale tests passed")
