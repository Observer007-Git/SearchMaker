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
for key, value in pairs(english.L) do
    assert(chinese.L[key], "zhCN missing locale key: " .. key)
    assert(FormatSignature(value) == FormatSignature(chinese.L[key]),
        "locale format signature mismatch: " .. key)
end
for key in pairs(chinese.L) do assert(english.L[key], "enUS missing locale key: " .. key) end
assert(english.L.ADD == "Add" and chinese.L.ADD == "新增", "locale selection failed")
assert(english.L.READ_COORDINATES == "Get Character Coordinates"
    and chinese.L.READ_COORDINATES == "读取角色坐标",
    "coordinate button locale was not updated")
assert(english.Config.GetCategoryKey("delves") == "delves", "canonical category key failed")
assert(english.Config.GetCategoryKey("地下堡") == "other", "localized category leaked into storage")

print("SearchMaker locale tests passed")
