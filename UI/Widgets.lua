local _, SMK = ...

local Widgets = {}
local Config = SMK.Config
local Art = Config.art
local Sign = Art.locationSign

local function GetLocationScale()
    return SMK.Settings:Get("locationScale") or Config.location.defaultScale
end

-- Cache map: "text|scale" → pixel width. Avoids font measurement on re-render.
--- 缓存映射："文本|缩放比例" → 像素宽度。
-- 避免重复渲染时多次调用 GetUnboundedStringWidth()。
local geometryCache = {}
local geometryCacheSize = 0
local geometryCacheKeys = {}
local geometryCacheNext = 1
local geometryCacheMaxSize = Config.location.geometryCacheMaxEntries

local function GetTextWidth(label, text, locationScale)
    local cacheKey = text .. "|" .. tostring(locationScale)
    local textWidth = geometryCache[cacheKey]
    if textWidth then return textWidth end
    if label.SetText then label:SetText(text) end
    textWidth = label.GetUnboundedStringWidth
        and label:GetUnboundedStringWidth() or label:GetStringWidth()
    textWidth = math.max(1, math.ceil(textWidth))
    local slot
    if geometryCacheSize < geometryCacheMaxSize then
        geometryCacheSize = geometryCacheSize + 1
        slot = geometryCacheSize
    else
        slot = geometryCacheNext
        geometryCache[geometryCacheKeys[slot]] = nil
        geometryCacheNext = geometryCacheNext % geometryCacheMaxSize + 1
    end
    geometryCacheKeys[slot] = cacheKey
    geometryCache[cacheKey] = textWidth
    return textWidth
end

local function ApplyLocationFont(label, locationScale)
    if label.baseFontPath and label.baseFontSize then
        label:SetFont(label.baseFontPath,
            label.baseFontSize * locationScale, label.baseFontFlags or "")
    end
end

--- 测量地点木牌尺寸，不创建地点按钮。
-- @param label FontString 用于测量的字体对象。
-- @param text string 地点显示文字。
-- @param showIcon boolean 是否包含左侧图标。
-- @return number, number 木牌总宽度和高度。
function Widgets:MeasureLocation(label, text, showIcon)
    local locationScale = GetLocationScale()
    ApplyLocationFont(label, locationScale)
    local textWidth = GetTextWidth(label, text or "", locationScale)
    local height = math.max(1, math.ceil(Sign.height * locationScale))
    local signWidth = math.max(1, math.ceil(Sign.width * height / Sign.height))
    local totalWidth = math.max(signWidth, textWidth + Sign.textPadding * 2)
    return math.ceil((showIcon and height or 0) + totalWidth), height
end

--- 根据文本宽度和缩放比例计算并设置地点按钮的正确尺寸。
-- 使用 geometryCache 避免重复调用时的字体测量。
-- @param button Frame 地点按钮部件。
function Widgets:UpdateLocationGeometry(button)
    local text = button.label:GetText() or ""
    local totalButtonWidth, height = self:MeasureLocation(button.label, text, button.showIcon)
    local textPadding = Sign.textPadding
    local textOffsetY = Sign.textOffsetY
    local iconWidth = button.showIcon and height or 0
    button:SetSize(totalButtonWidth, height)
    button.iconBox:ClearAllPoints()
    button.iconBox:SetPoint("TOPLEFT")
    button.iconBox:SetSize(iconWidth, height)
    button.iconBox:SetShown(button.showIcon)
    button.background:ClearAllPoints()
    if button.showIcon then
        button.background:SetPoint("TOPLEFT", button.iconBox, "TOPRIGHT")
    else
        button.background:SetPoint("TOPLEFT")
    end
    button.background:SetPoint("BOTTOMRIGHT")
    button.background:SetAtlas(Sign.atlas, false)
    button.background:Show()
    button.hitArea:ClearAllPoints()
    button.hitArea:SetAllPoints(button)
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", button.background, "LEFT", textPadding, textOffsetY)
    button.label:SetPoint("RIGHT", button.background, "RIGHT", -textPadding, textOffsetY)
end

--- 创建主面板使用的 Atlas 文字按钮。
-- 宽度默认根据当前语言文本自动计算；可通过 options.width 固定宽度。
function Widgets:CreatePanelButton(parent, text, options)
    options = options or {}
    local style = Config.panel.controls
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(options.height or style.buttonHeight)
    button:RegisterForClicks("LeftButtonUp")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.background:SetAtlas(style.buttonAtlas, false)
    button.background:SetAlpha(0.72)

    button.hover = button:CreateTexture(nil, "HIGHLIGHT")
    button.hover:SetAllPoints()
    button.hover:SetAtlas(style.buttonAtlas, false)
    button.hover:SetBlendMode("ADD")
    button.hover:SetAlpha(0.65)
    button:SetHighlightTexture(button.hover)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetAllPoints()
    button.label:SetJustifyH("CENTER")
    button.label:SetJustifyV("MIDDLE")
    button.label:SetWordWrap(false)
    button.label:SetTextColor(unpack(Config.colors.gold))

    function button:SetText(value)
        self.label:SetText(value or "")
        if options.width then
            self:SetWidth(options.width)
            return
        end
        local width = self.label.GetUnboundedStringWidth
            and self.label:GetUnboundedStringWidth() or self.label:GetStringWidth()
        self:SetWidth(math.max(options.minWidth or style.buttonMinWidth,
            math.ceil(width) + (options.padding or style.buttonPadding) * 2))
    end

    button:SetScript("OnEnable", function(self)
        self.background:SetAlpha(0.72)
        self.label:SetTextColor(unpack(Config.colors.gold))
    end)
    button:SetScript("OnDisable", function(self)
        self.background:SetAlpha(0.3)
        self.label:SetTextColor(unpack(Config.colors.disabled))
    end)
    button:SetText(text)
    return button
end

--- 设置地点条目的图标。
-- 已保存的自定义图标优先；否则使用地图、HandyNotes 来源或地点分组的默认图标。
function Widgets:SetLocationIcon(texture, entry)
    if entry.customIconID and SMK.IconCatalog:Apply(texture, entry.customIconID) then
        return
    elseif entry.isMapPortal then
        texture:SetAtlas(Art.mapPortalAtlas, false)
    elseif entry.isExternal and entry.iconTexture then
        texture:SetTexture(entry.iconTexture)
        texture:SetTexCoord(0, 1, 0, 1)
    else
        Config.ApplyCategoryIcon(texture, entry.categoryKey)
    end
end

--- 用条目数据、图标和几何信息填充地点按钮。
-- 地图传送门条目使用 Config 中的专用图标。
-- @param button Frame 要填充的按钮。
-- @param entry table 地点条目（可能带有 isMapPortal 标记）。
-- @param displayText string|nil 按钮标签的替代文本。
-- @param showIcon boolean|nil 是否在木牌左侧显示图标。
function Widgets:SetLocationEntry(button, entry, displayText, showIcon)
    local locationScale = GetLocationScale()
    ApplyLocationFont(button.label, locationScale)
    button.entry = entry
    button.hitArea.entry = entry
    button.isSearchSelected = false
    button.showIcon = showIcon == true
    button.highlight:Hide()
    local isPinned = entry.showPinName == 1 or entry.showPinTexture == 1
    button.isPinned = isPinned
    button.label:SetTextColor(unpack(isPinned and Config.colors.locationPinned or Config.colors.locationNormal))
    button.label:SetText(displayText or entry.name)
    self:SetLocationIcon(button.icon, entry)
    self:UpdateLocationGeometry(button)
    button.background:Show()
    button:Show()
end

--- 释放地点按钮持有的数据引用，供各 UI 部件池安全复用。
-- @param button Frame 地点按钮。
function Widgets:ReleaseLocationButton(button)
    button.entry = nil
    button.hitArea.entry = nil
    button.resultIndex = nil
    button.isSearchSelected = false
    button.isSearchResult = false
    button.isPinned = false
    button.showIcon = false
    button.highlight:Hide()
    button.label:SetText("")
    button.icon:SetTexture(nil)
    button:Hide()
    button:ClearAllPoints()
end

--- 创建带有点击处理、工具提示和高亮的新地点按钮框架。
-- 使用部件池模式：按钮创建一次，通过 Acquire/Release 复用。
-- @param parent Frame 父框架。
-- @param callbacks table { onActivate, onContext, onEnter, onLeave }。
-- @return Frame 新按钮。
function Widgets:CreateLocationButton(parent, callbacks)
    local button = CreateFrame("Frame", nil, parent)
    button:SetSize(Config.location.baseWidth, Config.location.baseHeight)
    button.callbacks = callbacks or {}

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints(button)
    button.background:SetAtlas(Sign.atlas, false)

    button.highlight = button:CreateTexture(nil, "ARTWORK")
    button.highlight:SetAllPoints(button)
    button.highlight:SetTexture(Art.highlight)
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetAlpha(0.75)
    button.highlight:Hide()

    button.iconBox = CreateFrame("Frame", nil, button)
    button.icon = button.iconBox:CreateTexture(nil, "ARTWORK")
    button.iconFrame = button.iconBox:CreateTexture(nil, "OVERLAY")
    local frameExpand = Art.searchResultIconFrameExpand
    button.icon:SetAllPoints(button.iconBox)
    button.iconFrame:SetPoint("TOPLEFT", button.iconBox, "TOPLEFT", -frameExpand, frameExpand)
    button.iconFrame:SetPoint("BOTTOMRIGHT", button.iconBox, "BOTTOMRIGHT", frameExpand, -frameExpand)
    button.iconFrame:SetTexture(Art.searchResultIconFrame)

    button.hitArea = CreateFrame("Button", nil, button)
    button.hitArea:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.hitArea:SetClipsChildren(true)
    button.hitArea.owner = button
    button.label = button.hitArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("LEFT")
    button.label:SetPoint("RIGHT")
    button.label:SetPoint("TOP")
    button.label:SetPoint("BOTTOM")
    button.label:SetJustifyH("LEFT")
    button.label:SetJustifyV("MIDDLE")
    button.label:SetWordWrap(false)
    button.baseFontPath, button.baseFontSize, button.baseFontFlags = button.label:GetFont()
    button.label.baseFontPath = button.baseFontPath
    button.label.baseFontSize = button.baseFontSize
    button.label.baseFontFlags = button.baseFontFlags

    button.hitArea:SetScript("OnClick", function(self, mouseButton)
        local owner = self.owner
        if mouseButton == "RightButton" then
            if owner.callbacks.onContext then
                owner.callbacks.onContext(owner.entry, self)
            end
        elseif owner.callbacks.onActivate then
            owner.callbacks.onActivate(owner.entry, owner.isSearchResult)
        end
    end)
    button.hitArea:SetScript("OnEnter", function(self)
        local owner = self.owner
        if owner.callbacks.onEnter then
            owner.callbacks.onEnter(owner)
        end
        owner.highlight:Show()
        owner.label:SetTextColor(unpack(Config.colors.locationHover))
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(owner.entry.name)
        if owner.entry.isMapPortal then
            GameTooltip:AddLine(SMK.L.OPEN_MAP, 0.35, 0.85, 1)
        elseif owner.entry.isExternal then
            GameTooltip:AddLine(SMK.L.EXTERNAL_SOURCE .. ": " .. owner.entry.externalSource, 0.35, 0.85, 1)
            GameTooltip:AddLine(string.format(SMK.L.MAP_FORMAT,
                SMK.Map:GetMapName(owner.entry.mapID), owner.entry.mapID), 1, 1, 1)
            GameTooltip:AddLine(string.format(SMK.L.TOOLTIP_XY,
                owner.entry.x, owner.entry.y), 1, 1, 1)
        else
            GameTooltip:AddLine(string.format(SMK.L.MAP_FORMAT,
                SMK.Map:GetMapName(owner.entry.mapID), owner.entry.mapID), 1, 1, 1)
            GameTooltip:AddLine(string.format(SMK.L.TOOLTIP_XY,
                owner.entry.x, owner.entry.y), 1, 1, 1)
            if not owner.entry.isCoordinateResult then
                GameTooltip:AddLine(string.format(SMK.L.TOOLTIP_USAGE_COUNT,
                    SMK.Store:GetUsage(owner.entry)), 0.75, 0.75, 0.75)
            end
        end
        if owner.entry.note and owner.entry.note ~= "" then
            local color = Config.colors.note
            GameTooltip:AddLine(owner.entry.note, color[1], color[2], color[3])
        end
        if not owner.entry.isMapPortal then
            GameTooltip:AddLine(SMK.L.TOOLTIP_INSTRUCTIONS, 0.35, 0.85, 1)
        end
        GameTooltip:Show()
    end)
    button.hitArea:SetScript("OnLeave", function(self)
        local owner = self.owner
        if owner.callbacks.onLeave then
            owner.callbacks.onLeave(owner)
        end
        owner.highlight:SetShown(owner.isSearchSelected)
        local color = owner.isSearchSelected and Config.colors.locationHover
            or (owner.isPinned and Config.colors.locationPinned or Config.colors.locationNormal)
        owner.label:SetTextColor(unpack(color))
        GameTooltip_Hide()
    end)
    return button
end

--- 将搜索结果木牌扩展到下拉框宽度，额外宽度由中段吸收。
-- @param button Frame 要重新样式的按钮。
-- @param targetWidth number 期望宽度。
function Widgets:StretchSearchResult(button, targetWidth)
    button:SetClipsChildren(false)
    self:UpdateLocationGeometry(button)
    button:SetWidth(math.max(1, targetWidth))
    button.background:Show()
end

--- 创建带有图标和大号文字的类别标题栏。
-- 宽度由调用者（RenderList）动态设置。
-- @param parent Frame 父框架。
-- @return Frame 标题。
function Widgets:CreateCategoryHeading(parent)
    local height = Config.location.baseHeight * Config.categoryHeadingScale
    local verticalScale = height / Art.buttonArtHeight
    local leftWidth = Art.textLeft * verticalScale
    local heading = CreateFrame("Frame", nil, parent)
    heading:SetHeight(height)
    heading.leftWidth = leftWidth
    heading.backgroundLeft = heading:CreateTexture(nil, "BACKGROUND")
    heading.backgroundLeft:SetPoint("TOPLEFT")
    heading.backgroundLeft:SetPoint("BOTTOMLEFT")
    heading.backgroundLeft:SetWidth(leftWidth)
    heading.backgroundLeft:SetTexture(Art.button)
    heading.backgroundLeft:SetTexCoord(0, Art.textLeft / Art.buttonTextureWidth,
        0, Art.buttonArtHeight / Art.buttonTextureHeight)
    heading.backgroundRight = heading:CreateTexture(nil, "BACKGROUND")
    heading.backgroundRight:SetPoint("TOPLEFT", heading.backgroundLeft, "TOPRIGHT")
    heading.backgroundRight:SetPoint("BOTTOMRIGHT")
    heading.backgroundRight:SetTexture(Art.button)
    heading.backgroundRight:SetTexCoord(Art.textLeft / Art.buttonTextureWidth,
        Art.buttonArtWidth / Art.buttonTextureWidth, 0, Art.buttonArtHeight / Art.buttonTextureHeight)
    heading.icon = heading:CreateTexture(nil, "ARTWORK")
    heading.icon:SetPoint("TOPLEFT", Art.iconLeft * verticalScale, -Art.iconTop * verticalScale)
    heading.icon:SetSize(Art.iconWidth * verticalScale, Art.iconHeight * verticalScale)
    heading.label = heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading.label:SetPoint("LEFT", heading.backgroundLeft, "RIGHT", 1, 0)
    heading.label:SetPoint("RIGHT", -8, 0)
    heading.label:SetJustifyH("LEFT")
    heading.label:SetJustifyV("MIDDLE")
    heading.label:SetTextColor(unpack(Config.colors.gold))
    local path, size, flags = heading.label:GetFont()
    if path and size then
        heading.label:SetFont(path, size * Config.categoryHeadingScale, flags)
    end
    return heading
end

--- 设置类别标题的文本和图标。
-- @param heading Frame 标题部件。
-- @param displayName string 本地化类别名称。
-- @param storageKey string 规范类别名称（用于图标查找）。
function Widgets:SetCategory(heading, displayName, storageKey)
    heading.label:SetText(displayName)
    Config.ApplyCategoryIcon(heading.icon, storageKey)
end

SMK.Widgets = Widgets
