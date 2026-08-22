local context = assert(...)
local SMK = context.SMK

local tocFile = assert(io.open(context.root .. "/SearchMaker.toc", "r"))
local toc = tocFile:read("*a")
tocFile:close()
assert(toc:find("## IconAtlas: decor-controls-inspect-active", 1, true)
    and not toc:find("## IconTexture:", 1, true)
    and not io.open(context.root .. "/icon.tga", "r"),
    "addon icon is not using the configured native Atlas")

assert(#SMK.AtlasTextures == 38 and #SMK.PathTextures == 16
    and #SMK.IconCatalog.all == 54
    and SMK.IconCatalog.all[#SMK.AtlasTextures].id > 0
    and SMK.IconCatalog.all[#SMK.AtlasTextures + 1].id < 0,
    "custom icon texture catalogs are incomplete")
local atlasNames = {}
for index, icon in ipairs(SMK.AtlasTextures) do
    assert(icon.id == index and icon.atlas and icon.note
        and SMK.IconCatalog:Get(icon.id) == icon
        and SMK.IconCatalog:GetNote(icon),
        "Atlas custom icon IDs are not positive or stable")
    assert(not atlasNames[icon.atlas], "duplicate Atlas custom icon: " .. icon.atlas)
    atlasNames[icon.atlas] = true
end
for _, icon in ipairs(SMK.PathTextures) do
    assert(icon.id < 0 and icon.texture and icon.note
        and SMK.IconCatalog:Get(icon.id) == icon
        and SMK.IconCatalog:GetNote(icon),
        "path custom icon IDs are not negative or stable")
end
assert(SMK.IconGridPicker:GetEntryTooltip(SMK.AtlasTextures[1]) == "联盟"
    and SMK.IconGridPicker:GetEntryTooltip(SMK.PathTextures[3]) == "烹饪",
    "custom icon picker did not use localized note tooltips")
assert(SMK.AtlasTextures[1].atlas == "AllianceSymbol"
    and SMK.AtlasTextures[38].atlas == "CaveUnderground-Up"
    and SMK.PathTextures[1].texture == "Interface\\ICONS\\UI_Profession_Alchemy"
    and SMK.PathTextures[16].texture == "Interface\\ICONS\\ACHIEVEMENT_GUILDPERK_MOUNTUP"
    and SMK.DefaultCustomIconID == 28,
    "provided custom icon catalogs were not installed exactly")
local expectedCategories = {
    { 1, "city_services", "ShipMissionIcon-Bonus-Map", "主城功能区域" },
    { 2, "class", "Class", "职业" },
    { 3, "profession", "Profession", "专业" },
    { 4, "raids", "Raid", "团队副本" },
    { 5, "dungeons", "Dungeon", "地下城" },
    { 6, "delves", "delves-bountiful", "地下堡" },
    { 7, "rares", "vignettekillboss-SuperTracked", "稀有怪物" },
    { 8, "treasures", "VignetteLoot", "宝箱" },
    { 9, "portals", "TaxiNode_Continent_Neutral", "传送门" },
    { 10, "teleport_beacons", "FlightMasterArgus", "传送道标" },
    { 11, "merchants", "SpellIcon-256x256-SellJunk", "商人" },
    { 12, "npc", "GM-icon-assistActive-hover", "NPC" },
    { 14, "handynotes_mapnotes", nil, "HandyNotes_MapNotes" },
    { 13, "other", "Waypoint-MapPin-Minimap-Tracked", "其他" },
}
assert(#SMK.Config.categories == #expectedCategories, "provided category list is incomplete")
for index, expected in ipairs(expectedCategories) do
    local category = SMK.Config.categories[index]
    assert(category.id == expected[1] and category.key == expected[2]
        and category.atlas == expected[3] and SMK.L[category.nameKey] == expected[4],
        "provided category definition changed at index " .. index)
end
local iconKind, iconValue = SMK.Config.GetCategoryIcon("handynotes_mapnotes")
assert(iconKind == "atlas"
    and iconValue == SMK.Config.categoryByKey.other.atlas,
    "unavailable HandyNotes_MapNotes category icon did not fall back to Other")
local originalIsAddOnLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(name) return name == "HandyNotes_MapNotes" end
iconKind, iconValue = SMK.Config.GetCategoryIcon("handynotes_mapnotes")
C_AddOns.IsAddOnLoaded = originalIsAddOnLoaded
assert(iconKind == "texture"
    and iconValue == "Interface\\AddOns\\HandyNotes_MapNotes\\Images\\MNL4.blp",
    "available HandyNotes_MapNotes category icon did not use MNL4.blp")
local panelLayout = SMK.Config.GetPanelLayout()
local panelConfig = SMK.Config.panel.layout
local panelControls = SMK.Config.panel.controls
local columnsWidth = panelLayout.locationButtonWidth * panelConfig.targetColumns
    + SMK.Config.location.horizontalGap * (panelConfig.targetColumns - 1)
assert(panelConfig.targetColumns == 5 and SMK.Config.panel.width == panelLayout.panelWidth
    and panelConfig.showLocationIcons
    and SMK.Config.settingsDefaults.searchBarMapOnly == false
    and SMK.Config.settingsDefaults.thirdPartySearchEnabled == true
    and panelLayout.locationButtonWidth
        == SMK.Config.location.baseWidth + SMK.Config.location.baseHeight
    and math.abs(panelLayout.sidePadding - panelLayout.iconFrameExpand
        - (panelLayout.contentWidth - panelLayout.sidePadding - columnsWidth)) <= 1,
    "main panel five-column margins are not symmetric")
local firstColumnLeft = panelLayout.scrollLeftInset + panelLayout.sidePadding
    - panelLayout.iconFrameExpand
local fifthColumnRight = panelLayout.panelWidth
    - (panelLayout.scrollLeftInset + panelLayout.sidePadding + columnsWidth)
assert(math.abs(firstColumnLeft - fifthColumnRight) <= 1
    and panelLayout.sidePadding + columnsWidth
        <= panelLayout.contentWidth - panelLayout.visualSidePadding
    and panelLayout.panelWidth - panelLayout.scrollLeftInset - panelLayout.scrollRightInset
        == panelLayout.contentWidth + panelConfig.scrollChildInset,
    "main panel scrollbar reserve is not split symmetrically")
assert(panelConfig.scrollbarReserve == 48 and panelLayout.scrollRightInset == 29
    and panelConfig.scrollFrameBottomInset == 50,
    "main panel scrollbar is not inset from the border")
assert(panelConfig.headerHeight == 68 and panelConfig.contentTopGap == 8
    and panelConfig.frequentTitleHeight == 18
    and SMK.Config.panel.backgroundAtlas == "house-drawing-stone-bg"
    and SMK.Config.panel.bottomRightDecorationAtlas
        == "catalog-corbel-bottom-right"
    and SMK.Config.panel.bottomRightDecorationOffset == 2
    and SMK.Config.panel.mapTitle.backgroundAtlas == "housing-woodsign"
    and SMK.Config.panel.mapTitle.foliageAtlas == "housing-foliage-header_right"
    and SMK.Config.panel.mapTitle.topOffset == 2
    and panelControls.buttonAtlas == "pet-list-bg-ferocity-active"
    and panelControls.closeButtonAtlas == "auctionhouse-ui-filter-redx"
    and panelControls.closeButtonOffsetX == -1
    and panelControls.closeButtonOffsetY == -3
    and panelControls.dropdownBorderOutset == 5
    and SMK.Config.search.settingsStyleDropdownOffsetY == 2
    and SMK.Config.search.settingsStyleDropdownLeftInset == 2
    and panelControls.buttonHeight == 24 and panelControls.settingsWidth == 330,
    "main panel controls are not configured")
local editorLayout = SMK.Config.GetLocationEditorLayout()
local previewRowGap = math.ceil((SMK.Config.locationEditor.previewButtonSize
    + SMK.Config.locationEditor.buttonHeight) / 2) + 2
assert(SMK.Config.locationEditor.width == 260 and SMK.Config.locationEditor.height == 455
    and SMK.Config.locationEditor.previewButtonSize == 42
    and editorLayout.categoryRowY - editorLayout.customIconRowY
        == -previewRowGap
    and editorLayout.pinNameRowY - editorLayout.pinSettingsLabelY
        == -SMK.Config.locationEditor.rowGap - 1
    and editorLayout.pinColorRowY - editorLayout.pinNameRowY
        == -SMK.Config.locationEditor.rowGap
    and editorLayout.pinTextureRowY - editorLayout.pinColorRowY
        == -SMK.Config.locationEditor.previewButtonSize - 2
    and SMK.IconGridPicker and SMK.IconGridPicker.Create,
    "location editor flow layout or shared icon grid is unavailable")
local editorX, editorY, editorSide = SMK.LocationEditor:CalculateMapPointPlacement(
    { x = 200, y = 50 }, 100, 900, 1000, 800)
assert(editorSide == "RIGHT" and editorX == 230 and editorY == 0,
    "location editor did not avoid a map point near the left edge")
editorX, editorY, editorSide = SMK.LocationEditor:CalculateMapPointPlacement(
    { x = 800, y = 750 }, 100, 900, 1000, 800)
assert(editorSide == "LEFT" and editorX == 510 and editorY == 345,
    "location editor did not avoid a map point near the right edge")
assert(SMK.Config.searchResultBackdrop.insets.left == 1
    and SMK.Config.searchResultBackdrop.insets.right == 1
    and SMK.Config.searchResultBackdrop.insets.top == 1
    and SMK.Config.searchResultBackdrop.insets.bottom == 1,
    "search result background does not fit its rounded border")
assert(SMK.Config.art.searchIcon == "Interface\\ICONS\\VAS_NameChange"
    and SMK.Config.art.searchAllMapsIcon
        == "Interface\\ICONS\\Ability_Paladin_SavedByTheLight"
    and SMK.Config.art.mapPortalAtlas == "poi-islands-table"
    and SMK.Config.art.searchResultIconFrame == "Interface\\SPELLBOOK\\RotationIconFrame"
    and SMK.Config.art.searchResultIconFrameExpand == 4,
    "search scope icon art is not configured")
assert(SMK.Config.search.resultFrameInset == 5
    and SMK.Config.search.resultNoPortraitLeftInset == 6
    and SMK.Config.search.resultGap == 2
    and SMK.Config.search.historyBackgroundAtlas
        == "housing-basic-panel-footer"
    and SMK.Config.search.resultMaxContentWidth == 520
    and SMK.Config.search.resultScreenMargin == 12
    and SMK.Config.search.hoverHighlightDelay == 0.08
    and SMK.Config.search.appearance.styles.default
        == SMK.Config.search.appearance.styles.portrait
    and SMK.Config.search.appearance.styles.blizzard == 3
    and #SMK.Config.search.appearance.styles.values == 3
    and SMK.Config.search.appearance.styles.allianceAtlas
        == "Objective-Header-CampaignAlliance"
    and SMK.Config.search.appearance.styles.hordeAtlas
        == "Objective-Header-CampaignHorde"
    and SMK.Config.search.appearance.styles.atlasWidth == 274
    and SMK.Config.search.appearance.styles.atlasHeight == 42
    and SMK.Config.search.appearance.styles.circleGap == 1
    and SMK.Config.search.appearance.styles.blizzardAtlas
        == "common-searchbar-a"
    and SMK.Config.search.appearance.styles.blizzardHeight == 30
    and SMK.Config.search.appearance.styles.blizzardSearchIconSize == 14
    and SMK.Config.search.appearance.styles.blizzardClearButtonSize == 19
    and SMK.Config.search.appearance.styles.blizzardClearIconSize == 11
    and SMK.Config.search.appearance.styles.blizzardLeftOutset == 0
    and SMK.Config.search.boxWidth - SMK.Config.search.resultFrameInset * 2 == 230,
    "search result frame is not aligned inside the search box border")
assert(SMK.Config.handyNotes.npcCacheMaxEntries == 512
    and SMK.Config.handyNotes.npcRetrySeconds == 30
    and SMK.Config.handyNotes.buildBatchSize == 20
    and SMK.Config.handyNotes.buildTimeBudgetMs == 2
    and SMK.Config.handyNotes.maxSearchFieldBytes == 160
    and SMK.Config.handyNotes.maxSearchTextBytes == 512
    and SMK.Config.mapIndex.buildBatchSize == 50
    and SMK.Config.mapIndex.buildTimeBudgetMs == 2
    and SMK.Config.location.geometryCacheMaxEntries == 1500,
    "external data and map index work budgets are not configured")
assert(SMK.Util.ContainsHan("㐀") and SMK.Util.ContainsHan("\240\160\128\128")
    and not SMK.Util.ContainsHan("English"),
    "Han detection does not cover extension characters")
assert(SMK.Util.Normalize(" ÉCOLE ÜBER İSTANBUL ẞ ΟΣ Я ") == "écoleüberistanbulßοσя"
    and SMK.Util.SortKey("ÉCOLE") == "école",
    "common non-ASCII case folding is not stable")
assert(SMK.Util.GetTextWidth("e\204\129") == 1
    and SMK.Util.GetTextWidth("👨‍👩‍👧") == 2
    and SMK.Util.GetTextWidth("🇨🇳") == 2
    and SMK.Util.TruncateUTF8("中文", 4) == "中",
    "grapheme width or UTF-8 truncation is incorrect")
assert(SMK.Config.mapPins.size == 30
    and SMK.Config.mapPins.defaultNameOffsetX == 0
    and SMK.Config.mapPins.defaultNameOffsetY == 0
    and SMK.Config.mapPins.targetHighlight.atlas == "Warfront-HordeDot"
    and SMK.Config.mapPins.targetHighlight.ringAtlas
        == "PowerSwirlAnimation-StarBurst-Soulbinds"
    and SMK.Config.mapPins.targetHighlight.ringTexture == nil
    and SMK.Config.mapPins.targetHighlight.size == 32
    and SMK.Config.mapPins.targetHighlight.ringSize == 80
    and SMK.Config.mapPins.targetHighlight.duration == 3
    and SMK.Config.mapPins.routeTemporary.atlas
        == "Ping_Wheel_Icon_Assist_Glow"
    and SMK.PinTextureIDByAtlas[SMK.Config.mapPins.routeTemporary.atlas] == nil,
    "target highlight or temporary route pin is not configured")
local locationSign = SMK.Config.art.locationSign
assert(locationSign.atlas == "housing-woodsign" and locationSign.width == 136
    and locationSign.height == 29 and locationSign.textPadding == 8
    and locationSign.textOffsetY == 1 and SMK.Config.location.baseWidth == 136
    and SMK.Config.location.horizontalGap == 4,
    "location sign art is not configured")
assert(SMK.DefaultPinTextureID == 1 and SMK.PinTextures[1].atlas == "MonsterEnemy",
    "MonsterEnemy is not the first and default pin texture")
local expectedPinAtlases = {
    "MonsterEnemy", "MonsterFriend", "worldquest-questmarker-epic-supertracked",
    "worldquest-Capstone-questmarker-epic",
    "VignetteEvent-SuperTracked", "groupfinder-icon-class-color-deathknight",
    "groupfinder-icon-class-color-priest", "MiniMap-DeadArrow",
    "vignettekillboss-SuperTracked", "poi-traveldirections-arrow2", "poi-door-up", "poi-door-down",
    "poi-door-left", "poi-door-right", "CaveUnderground-Down", "CaveUnderground-Up",
    "friendslist-recentallies-Pin", "friendslist-recentallies-Pin-yellow",
    "XMarksTheSpot", "Ping_Map_Whole_OnMyWay",
}
for index, atlas in ipairs(expectedPinAtlases) do
    assert(SMK.PinTextures[index].id == index
        and SMK.PinTextures[index].atlas == atlas
        and SMK.PinTextureByID[index] == SMK.PinTextures[index]
        and SMK.PinTextureIDByAtlas[atlas] == index,
        "independent pin texture list changed")
    assert(atlas ~= "Ping_Map_Whole_Danger" and atlas ~= "Ping_Map_Whole_Help",
        "removed pin textures are still available")
end
local defaultTextureEntry = assert(SMK.LocationModel:Normalize({
    mapID = 100, x = 1, y = 2, name = "default", categoryKey = "other", pinTexture = "Missing",
}))
assert(defaultTextureEntry.pinTextureID == SMK.DefaultPinTextureID
    and defaultTextureEntry.pinTexture == nil,
    "location normalization did not use the default pin texture")
local legacyTextureEntry = assert(SMK.LocationModel:Normalize({
    mapID = 100, x = 1, y = 2, name = "legacy", categoryKey = "other",
    pinTexture = "VignetteEvent-SuperTracked",
}))
assert(legacyTextureEntry.pinTextureID == 5 and legacyTextureEntry.pinTexture == nil,
    "stored Atlas names were not converted to compact pin texture IDs")
assert(defaultTextureEntry.customIconID == nil,
    "location normalization stored a custom icon without opt-in")
local customIconEntry = assert(SMK.LocationModel:Normalize({
    mapID = 100, x = 1, y = 2, name = "custom", categoryKey = "other", customIconID = -3,
}))
assert(customIconEntry.customIconID == -3
    and SMK.LocationModel:Normalize({
        mapID = 100, x = 1, y = 2, name = "invalid icon",
        categoryKey = "other", customIconID = -999,
    }).customIconID == nil,
    "custom icon normalization did not preserve valid IDs or discard invalid IDs")
local function NormalizeNamedLocation(name)
    return SMK.LocationModel:Normalize({
        mapID = 100, x = 1, y = 2, name = name, categoryKey = "other",
    })
end
assert(NormalizeNamedLocation("一二三四五六七八九十"), "ten-character Chinese name was rejected")
assert(not NormalizeNamedLocation("一二三四五六七八九十一"), "eleven-character Chinese name was accepted")
assert(NormalizeNamedLocation("abcdefghijklmnopqrst"), "twenty-letter English name was rejected")
assert(not NormalizeNamedLocation("abcdefghijklmnopqrstu"), "twenty-one-letter English name was accepted")
assert(NormalizeNamedLocation("éééééééééééééééééééé"),
    "twenty narrow non-ASCII characters were rejected")
assert(not NormalizeNamedLocation("ééééééééééééééééééééé"),
    "twenty-one narrow non-ASCII characters were accepted")
assert(NormalizeNamedLocation(string.rep("e\204\129", 20))
    and not NormalizeNamedLocation(string.rep("e\204\129", 21)),
    "combining-character names were not measured by displayed width")
assert(NormalizeNamedLocation(string.rep("👨‍👩‍👧", 10))
    and not NormalizeNamedLocation(string.rep("👨‍👩‍👧", 11)),
    "joined emoji names were not measured by displayed width")
local notedLocation = assert(SMK.LocationModel:Normalize({
    mapID = 100, x = 1, y = 2, name = "note", categoryKey = "other",
    note = "  绿色备注  ",
}))
assert(notedLocation.note == "绿色备注"
    and not SMK.LocationModel:Normalize({
        mapID = 100, x = 1, y = 2, name = "note", categoryKey = "other",
        note = string.rep("备", 61),
    }),
    "location notes were not trimmed or width-limited")
