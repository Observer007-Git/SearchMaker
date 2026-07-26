local _, SMK = ...

-- 常用尺寸、视觉和限制集中在本文件；修改后 /reload 即可生效。
local Config = {
    databaseSchemaVersion = 5,
    panel = {
        height = 512,
        backgroundAtlas = "catalog-list-preview-bg",
        borderAtlas = "housing-wood-frame",
        layout = {
            targetColumns = 5,
            contentInset = 4,
            outerInset = 14,
            headerHeight = 40,
            headerMapMaxWidth = 300,
            contentTopGap = 8,
            dividerInset = 4,
            scrollLeftOutset = 6,
            scrollbarReserve = 48,
            scrollChildInset = 2,
        },
        controls = {
            buttonAtlas = "housefinder_neighborhood-list-item-highlight",
            buttonHeight = 24,
            buttonMinWidth = 40,
            buttonPadding = 12,
            buttonGap = 4,
            popupPadding = 12,
            settingsWidth = 330,
        },
    },
    search = {
        barWidth = 240,
        barHeight = 52,
        boxWidth = 240,
        boxHeight = 44,
        resultBackdropInset = 5,
        resultFrameInset = 5,
        resultGap = 2,
        resultMaxContentWidth = 520,
        resultScreenMargin = 12,
        maxResults = 20,
        hoverHighlightDelay = 0.08,
        shortcutDefaultOffsetY = 200,
    },
    location = {
        baseWidth = 136,
        baseHeight = 29,
        horizontalGap = 4,
        verticalGap = 1,
        groupGap = 1,
        maxNameLength = 20,
        maxNameWidth = 20,
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
    locationEditor = {
        width = 216,
        height = 510,
        titleOffsetY = -18,
        mapNameOffsetY = -8,
        rowGap = 25,
        categoryRowY = -80,
        nameRowY = -105,
        xRowY = -130,
        yRowY = -155,
        coordinateButtonY = -181,
        errorY = -208,
        pinColorRowY = -231,
        pinTextureRowY = -258,
        pinTextureLabelY = -285,
        pinTexturePanelY = -300,
        buttonHeight = 24,
        buttonWidth = 60,
        coordinateButtonWidth = 120,
        inputWidth = 140,
        labelGap = 8,
        bottomButtonOffsetX = 12,
        bottomButtonOffsetY = 15,
        positionGap = 30,
    },
    share = {
        prefix = "SMK|",
        portalSoundID = 875,
        chatScanMessageCount = 50,
    },
    mapPins = {
        size = 18,
        minScale = 0.8,
        maxScale = 1.2,
        defaultTextScale = 1,
        minTextScale = 0.5,
        maxTextScale = 2,
        textScaleStep = 0.1,
        defaultTextureScale = 1,
        minTextureScale = 0.5,
        maxTextureScale = 2,
        textureScaleStep = 0.1,
        defaultNameOffsetX = 0,
        defaultNameOffsetY = 2,
        nameOffsetXMin = -50,
        nameOffsetXMax = 50,
        nameOffsetYMin = -50,
        nameOffsetYMax = 50,
        targetHighlight = {
            atlas = "MonsterEnemy",
            ringTexture = "Interface\\Cooldown\\starburst",
            size = 32,
            ringSize = 80,
            duration = 3,
        },
    },
    mapIndex = {
        roots = { 946, 947, 1, 2, 13, 197, 4080 },
        maxDepth = 20,
        maxResults = 5,
    },
    art = {
        searchIcon = "Interface\\ICONS\\VAS_NameChange",
        searchAllMapsIcon = "Interface\\ICONS\\Ability_Paladin_SavedByTheLight",
        searchResultIconFrame = "Interface\\SPELLBOOK\\RotationIconFrame",
        searchResultIconFrameExpand = 4,
        handyNotesFallbackIcon = "Interface\\AddOns\\SearchMaker\\Textures\\MNL4.blp",
        button = "Interface\\ENCOUNTERJOURNAL\\loottab-item-background",
        highlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
        fallbackLocationAtlas = "Waypoint-MapPin-Tracked",
        locationSign = {
            atlas = "housing-woodsign",
            width = 136,
            height = 29,
            textPadding = 8,
            textOffsetY = 1,
        },
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
        locationPinned = { 0.33, 0.9, 1 },
        externalSource = { 0.72, 0.55, 1 },
        panelBorder = { 0.82, 0.62, 0.25, 1 },
        dialogBackground = { 0.08, 0.055, 0.025, 1 },
        disabled = { 0.55, 0.55, 0.55 },
    },
}

--- 根据目标列数、木牌尺寸和滚动区域边距计算主面板布局。
function Config.GetPanelLayout()
    local layout = Config.panel.layout
    local headingIconWidth = Config.location.baseHeight * Config.categoryHeadingScale
        * Config.art.textLeft / Config.art.buttonArtHeight
    local sidePadding = layout.contentInset + headingIconWidth
    local columnsWidth = Config.location.baseWidth * layout.targetColumns
        + Config.location.horizontalGap * math.max(0, layout.targetColumns - 1)
    local contentWidth = math.ceil(sidePadding * 2 + columnsWidth)
    local originalLeftInset = layout.outerInset + layout.dividerInset - layout.scrollLeftOutset
    local horizontalReserve = originalLeftInset
        + layout.scrollbarReserve + layout.scrollChildInset
    local contentOuterInset = math.ceil(horizontalReserve / 2)
    return {
        panelWidth = contentWidth + contentOuterInset * 2,
        contentWidth = contentWidth,
        sidePadding = sidePadding,
        scrollLeftInset = contentOuterInset,
        scrollRightInset = contentOuterInset - layout.scrollChildInset,
    }
end

Config.panel.width = Config.GetPanelLayout().panelWidth

-- id 是共享格式中的稳定编号；调整显示顺序时不得修改已有 id。
Config.categories = {
    { id = 1, key = "delves", nameKey = "CAT_DELVES", atlas = "delves-bountiful" },
    { id = 2, key = "dungeons", nameKey = "CAT_DUNGEONS", atlas = "Dungeon" },
    { id = 3, key = "raids", nameKey = "CAT_RAIDS", atlas = "Raid" },
    { id = 4, key = "teleport", nameKey = "CAT_TELEPORT", atlas = "TaxiNode_Continent_Neutral" },
    { id = 5, key = "flight", nameKey = "CAT_FLIGHT", atlas = "TaxiNode_Neutral" },
    { id = 6, key = "professions", nameKey = "CAT_PROFESSIONS", atlas = "MajorFactions_MapIcons_Expedition64" },
    { id = 7, key = "npc", nameKey = "CAT_NPC", atlas = "Embercourt-Guest-PrinceRenathal" },
    { id = 8, key = "other", nameKey = "CAT_OTHER", atlas = Config.art.fallbackLocationAtlas },
}
Config.defaultCategoryKey = "other"
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
    if Config.categoryByKey[text] then return text end
    local category = Config.categoryByID[tonumber(text)]
    if category then return category.key end
    return Config.defaultCategoryKey
end

Config.settingsDefaults = {
    locationScale = Config.location.defaultScale,
    shortcutSearchVisible = false,
    showMapPinNames = false,
    showPinTextures = true,
    pinTextureScale = Config.mapPins.defaultTextureScale,
    mapPinTextColor = {
        r = Config.colors.gold[1],
        g = Config.colors.gold[2],
        b = Config.colors.gold[3],
    },
    mapPinTextScale = Config.mapPins.defaultTextScale,
    mapPinNameOffsetX = Config.mapPins.defaultNameOffsetX,
    mapPinNameOffsetY = Config.mapPins.defaultNameOffsetY,
    searchAllMaps = false,
    searchBarScale = 1,
    searchBarOpacity = 1,
}

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

Config.searchResultBackdrop = SMK.Util.CopyTable(Config.resultBackdrop)
local searchResultInset = Config.search.resultBackdropInset
Config.searchResultBackdrop.insets = {
    left = searchResultInset,
    right = searchResultInset,
    top = searchResultInset,
    bottom = searchResultInset,
}

SMK.Config = Config
