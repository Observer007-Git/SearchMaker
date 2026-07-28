local _, SMK = ...

-- 常用尺寸、视觉和限制集中在本文件；修改后 /reload 即可生效。
local Config = {
    databaseSchemaVersion = 9,
    panel = {
        height = 512,
        backgroundAtlas = "catalog-list-preview-bg",
        borderAtlas = "housing-wood-frame",
        layout = {
            targetColumns = 5,
            contentInset = 4,
            outerInset = 14,
            headerHeight = 68,
            contentTopGap = 8,
            dividerInset = 4,
            scrollLeftOutset = 6,
            scrollbarReserve = 48,
            scrollChildInset = 2,
            scrollbarOffsetX = -6,
            showLocationIcons = true,
            frequentTitleHeight = 18,
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
        resultBackdropInset = 1,
        resultFrameInset = 5,
        resultGap = 2,
        resultMaxContentWidth = 520,
        resultScreenMargin = 12,
        maxResults = 20,
        hoverHighlightDelay = 0.08,
        shortcutDefaultOffsetY = 200,
        appearance = {
            defaultScale = 1,
            minScale = 0.5,
            maxScale = 2,
            scaleStep = 0.1,
            defaultOpacity = 1,
            minOpacity = 0.2,
            maxOpacity = 1,
            opacityStep = 0.1,
        },
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
        geometryCacheMaxEntries = 1500,
        defaultScale = 1,
        minScale = 0.5,
        maxScale = 2,
        scaleStep = 0.1,
    },
    categoryHeadingScale = 1.3,
    shortcutAction = "SEARCHMAKER_TOGGLE_SEARCH",
    export = {
        batchSizes = { 20, 50, 100, 200 },
        defaultBatchSize = 200,
    },
    locationEditor = {
        width = 260,
        height = 430,
        titleOffsetY = -18,
        mapNameOffsetY = -8,
        rowStartY = -80,
        rowGap = 25,
        buttonHeight = 24,
        buttonWidth = 60,
        coordinateButtonWidth = 120,
        inputWidth = 140,
        previewButtonSize = 42,
        customIconPickerColumns = 6,
        customIconPickerCellSize = 28,
        customIconPickerGap = 4,
        customIconPickerPadding = 8,
        pinTexturePickerColumns = 5,
        pinTexturePickerCellSize = 28,
        pinTexturePickerColumnGap = 6,
        pinTexturePickerRowGap = 3,
        pinTexturePickerPadding = 7,
        bottomButtonOffsetX = 12,
        bottomButtonOffsetY = 15,
        positionGap = 30,
    },
    share = {
        prefix = "SMK|",
        portalSoundID = 875,
        whisperInboxMaxEntries = 50,
    },
    handyNotes = {
        npcCacheMaxEntries = 512,
        npcRetrySeconds = 30,
        buildBatchSize = 20,
        buildTimeBudgetMs = 2,
        maxSearchFieldBytes = 160,
        maxSearchTextBytes = 512,
    },
    mapPins = {
        size = 30,
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
        defaultNameOffsetY = 0,
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
        buildBatchSize = 50,
        buildTimeBudgetMs = 2,
    },
    art = {
        searchIcon = "Interface\\ICONS\\VAS_NameChange",
        searchAllMapsIcon = "Interface\\ICONS\\Ability_Paladin_SavedByTheLight",
        mapPortalAtlas = "poi-islands-table",
        searchResultIconFrame = "Interface\\SPELLBOOK\\RotationIconFrame",
        searchResultIconFrameExpand = 4,
        button = "Interface\\ENCOUNTERJOURNAL\\loottab-item-background",
        highlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
        fallbackLocationAtlas = "Waypoint-MapPin-Minimap-Tracked",
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

--- 按统一行高计算地点编辑器的纵向布局。
function Config.GetLocationEditorLayout()
    local editor = Config.locationEditor
    local function Row(index) return editor.rowStartY - index * editor.rowGap end
    local previewGap = math.ceil((editor.previewButtonSize + editor.buttonHeight) / 2) + 2
    local previewExtra = math.max(0, previewGap - editor.rowGap)
    local pinColorRowY = Row(9) - previewExtra - 1
    return {
        customIconRowY = Row(0),
        categoryRowY = Row(1) - previewExtra,
        nameRowY = Row(2) - previewExtra,
        xRowY = Row(3) - previewExtra,
        yRowY = Row(4) - previewExtra,
        coordinateButtonY = Row(5) - previewExtra - 1,
        errorY = Row(6) - previewExtra - 3,
        pinSettingsLabelY = Row(7) - previewExtra,
        pinNameRowY = Row(8) - previewExtra - 1,
        pinColorRowY = pinColorRowY,
        pinTextureRowY = pinColorRowY - editor.previewButtonSize - 2,
    }
end

for key, value in pairs(Config.GetLocationEditorLayout()) do
    Config.locationEditor[key] = value
end

--- 根据目标列数、木牌尺寸和滚动区域边距计算主面板布局。
function Config.GetPanelLayout()
    local layout = Config.panel.layout
    local headingIconWidth = Config.location.baseHeight * Config.categoryHeadingScale
        * Config.art.textLeft / Config.art.buttonArtHeight
    local visualSidePadding = layout.contentInset + headingIconWidth
    local iconWidth = layout.showLocationIcons and Config.location.baseHeight or 0
    local locationButtonWidth = Config.location.baseWidth + iconWidth
    local iconFrameExpand = layout.showLocationIcons
        and Config.art.searchResultIconFrameExpand or 0
    local sidePadding = visualSidePadding + iconFrameExpand
    local columnsWidth = locationButtonWidth * layout.targetColumns
        + Config.location.horizontalGap * math.max(0, layout.targetColumns - 1)
    local contentWidth = math.ceil(visualSidePadding * 2 + iconFrameExpand + columnsWidth)
    local originalLeftInset = layout.outerInset + layout.dividerInset - layout.scrollLeftOutset
    local horizontalReserve = originalLeftInset
        + layout.scrollbarReserve + layout.scrollChildInset
    local contentOuterInset = math.ceil(horizontalReserve / 2)
    return {
        panelWidth = contentWidth + contentOuterInset * 2,
        contentWidth = contentWidth,
        sidePadding = sidePadding,
        visualSidePadding = visualSidePadding,
        locationButtonWidth = locationButtonWidth,
        iconFrameExpand = iconFrameExpand,
        scrollLeftInset = contentOuterInset,
        scrollRightInset = contentOuterInset - layout.scrollChildInset,
    }
end

Config.panel.width = Config.GetPanelLayout().panelWidth

-- id 是共享格式中的稳定编号；调整显示顺序时不得修改已有 id。
Config.categories = {
    { id = 1, key = "city_services", nameKey = "CAT_CITY_SERVICES", atlas = "ShipMissionIcon-Bonus-Map" },
    { id = 2, key = "class", nameKey = "CAT_CLASS", atlas = "Class" },
    { id = 3, key = "profession", nameKey = "CAT_PROFESSION", atlas = "Profession" },
    { id = 4, key = "raids", nameKey = "CAT_RAIDS", atlas = "Raid" },
    { id = 5, key = "dungeons", nameKey = "CAT_DUNGEONS", atlas = "Dungeon" },
    { id = 6, key = "delves", nameKey = "CAT_DELVES", atlas = "delves-bountiful" },
    { id = 7, key = "rares", nameKey = "CAT_RARES", atlas = "vignettekillboss-SuperTracked" },
    { id = 8, key = "treasures", nameKey = "CAT_TREASURES", atlas = "VignetteLoot" },
    { id = 9, key = "portals", nameKey = "CAT_PORTALS", atlas = "TaxiNode_Continent_Neutral" },
    { id = 10, key = "teleport_beacons", nameKey = "CAT_TELEPORT_BEACONS", atlas = "FlightMasterArgus" },
    { id = 11, key = "merchants", nameKey = "CAT_MERCHANTS", atlas = "SpellIcon-256x256-SellJunk" },
    { id = 12, key = "npc", nameKey = "CAT_NPC", atlas = "GM-icon-assistActive-hover" },
    { id = 13, key = "other", nameKey = "CAT_OTHER", atlas = "Waypoint-MapPin-Minimap-Tracked" },
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
    pinTextureScale = Config.mapPins.defaultTextureScale,
    mapPinTextScale = Config.mapPins.defaultTextScale,
    mapPinNameOffsetX = Config.mapPins.defaultNameOffsetX,
    mapPinNameOffsetY = Config.mapPins.defaultNameOffsetY,
    searchAllMaps = false,
    searchBarScale = Config.search.appearance.defaultScale,
    searchBarOpacity = Config.search.appearance.defaultOpacity,
    exportBatchSize = Config.export.defaultBatchSize,
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
