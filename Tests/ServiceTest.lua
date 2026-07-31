local root = assert(arg[1], "usage: lua Tests/ServiceTest.lua <addon-root>")
local bootstrap = assert(loadfile(root .. "/Tests/Service/Bootstrap.lua"))
local context = bootstrap()(root)

for _, path in ipairs({
    "ConfigAndModel.lua",
    "StoreAndSettings.lua",
    "HistoryAndMinimap.lua",
    "SearchAndExternal.lua",
    "SharingAndImport.lua",
    "MapIndexAndStatic.lua",
    "PinsAndUI.lua",
}) do
    assert(loadfile(root .. "/Tests/Service/" .. path))(context)
end

print("SearchMaker service tests passed")
