local _, SMK = ...

-- 常用尺寸、视觉和限制集中在本文件；修改后 /reload 即可生效。
local Config = {
    databaseSchemaVersion = 2,
    panel = {
        width = 700,
        height = 512,
        backgroundAtlas = "shop-virtual currency-menu-bg",
        borderAtlas = "housing-wood-frame",
    },
    search = {
        barWidth = 240,
        barHeight = 52,
        boxWidth = 240,
        boxHeight = 44,
        modeButtonWidth = 96,
        maxResults = 20,
        shortcutDefaultOffsetY = 200,
    },
    location = {
        baseWidth = 120,
        baseHeight = 28,
        horizontalGap = 0,
        verticalGap = 1,
        groupGap = 1,
        maxNameLength = 7,
        maxCoordinateLength = 6,
        maxFrequent = 5,
        defaultScale = 1,
        minScale = 0.5,
        maxScale = 2,
        scaleStep = 0.1,
    },
    categoryHeadingScale = 1.3,
    shortcutAction = "SEARCHMAKER_TOGGLE_SEARCH",
    export = {
        maxPerBatch = 500,
    },
    share = {
        prefix = "SMK|",
    },
    art = {
        defaultLocationIcon = "Interface\\ICONS\\VAS_CharacterTransfer",
        searchIcon = "Interface\\ICONS\\INV_Misc_Map03",
        button = "Interface\\ENCOUNTERJOURNAL\\loottab-item-background",
        highlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
        fallbackLocationAtlas = "Waypoint-MapPin-Minimap-Tracked",
        buttonTextureWidth = 512,
        buttonTextureHeight = 128,
        buttonArtWidth = 356,
        buttonArtHeight = 92,
        iconLeft = 17,
        iconTop = 17,
        iconWidth = 58,
        iconHeight = 58,
        textLeft = 88,
        textLeftPadding = 1,
        textRightPadding = 20,
        verticalPadding = 16,
    },
    colors = {
        gold = { 1, 0.82, 0 },
        locationNormal = { 1, 0.82, 0 },
        locationHover = { 1, 1, 1 },
        panelBorder = { 0.82, 0.62, 0.25, 1 },
        dialogBackground = { 0.08, 0.055, 0.025, 1 },
        disabled = { 0.55, 0.55, 0.55 },
    },
}

-- id 是共享格式中的稳定编号；调整显示顺序时不得修改已有 id。
Config.categories = {
    { id = 1, key = "Delves", nameKey = "CAT_DELVES", legacyNames = { "地下堡" }, atlas = "delves-bountiful" },
    { id = 2, key = "Dungeons", nameKey = "CAT_DUNGEONS", legacyNames = { "地下城" }, atlas = "Dungeon" },
    { id = 3, key = "Raids", nameKey = "CAT_RAIDS", legacyNames = { "团队副本" }, atlas = "Raid" },
    { id = 4, key = "Teleport Points", nameKey = "CAT_TELEPORT", legacyNames = { "传送点" }, atlas = "TaxiNode_Continent_Neutral" },
    { id = 5, key = "Flight Paths", nameKey = "CAT_FLIGHT", legacyNames = { "飞行点" }, atlas = "TaxiNode_Neutral" },
    { id = 6, key = "Professions", nameKey = "CAT_PROFESSIONS", legacyNames = { "专业" }, atlas = "MajorFactions_MapIcons_Expedition64" },
    { id = 7, key = "NPC", nameKey = "CAT_NPC", legacyNames = { "NPC" }, atlas = "Embercourt-Guest-PrinceRenathal" },
    { id = 8, key = "Other", nameKey = "CAT_OTHER", legacyNames = { "其他" }, atlas = Config.art.fallbackLocationAtlas },
}
Config.defaultCategoryKey = "Other"
Config.categoryByKey = {}
Config.categoryByID = {}
Config.categoryOrder = {}
for index, category in ipairs(Config.categories) do
    Config.categoryByKey[category.key] = category
    Config.categoryByID[category.id] = category
    Config.categoryOrder[category.key] = index
end

function Config.GetCategoryKey(value)
    local text = SMK.Util.Trim(value)
    if Config.categoryByKey[text] then
        return text
    end
    for _, category in ipairs(Config.categories) do
        if SMK.L and SMK.L[category.nameKey] == text then
            return category.key
        end
        for _, legacyName in ipairs(category.legacyNames or {}) do
            if legacyName == text then return category.key end
        end
    end
    return Config.defaultCategoryKey
end

Config.panelBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 24,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

Config.resultBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

SMK.Config = Config
