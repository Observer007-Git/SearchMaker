local _, SMK = ...

local Widgets = {}
local Config = SMK.Config
local Art = Config.art

local function GetLocationScale()
    return SMK.Settings:Get("locationScale") or Config.location.defaultScale
end

-- Cache map: "text|scale" → pixel width. Avoids font measurement on re-render.
--- 缓存映射："文本|缩放比例" → 像素宽度。
-- 避免重复渲染时多次调用 GetUnboundedStringWidth()。
local geometryCache = {}

--- 根据文本宽度和缩放比例计算并设置地点按钮的正确尺寸。
-- 使用 geometryCache 避免重复调用时的字体测量。
-- @param button Frame 地点按钮部件。
function Widgets:UpdateLocationGeometry(button)
    local locationScale = GetLocationScale()
    local _, fontSize = button.label:GetFont()
    local textHeight = math.max(1, tonumber(fontSize) or button.label:GetStringHeight() or 1)
    local text = button.label:GetText() or ""
    local cacheKey = text .. "|" .. tostring(locationScale)
    local textWidth = geometryCache[cacheKey]
    if not textWidth then
        textWidth = button.label.GetUnboundedStringWidth
            and button.label:GetUnboundedStringWidth() or button.label:GetStringWidth()
        textWidth = math.max(1, math.ceil(textWidth))
        geometryCache[cacheKey] = textWidth
    end

    local height = math.ceil(textHeight + Art.verticalPadding * locationScale)
    local verticalScale = height / Art.buttonArtHeight
    local naturalWidth = Art.buttonArtWidth * verticalScale
    local reservedRatio = (Art.textLeft + Art.textRightPadding) / Art.buttonArtWidth
    local width = math.ceil(math.max(
        naturalWidth,
        (textWidth + Art.textLeftPadding * locationScale) / (1 - reservedRatio)
    ))
    local horizontalScale = width / Art.buttonArtWidth
    button:SetSize(width, height)
    button.iconBox:ClearAllPoints()
    button.iconBox:SetPoint("TOPLEFT", button, "TOPLEFT",
        Art.iconLeft * horizontalScale, -Art.iconTop * verticalScale)
    button.iconBox:SetSize(Art.iconWidth * horizontalScale, Art.iconHeight * verticalScale)
    button.hitArea:ClearAllPoints()
    button.hitArea:SetAllPoints(button)
    local labelLeft = Art.textLeft * horizontalScale + Art.textLeftPadding * locationScale
    local labelRight = Art.textRightPadding * locationScale
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", labelLeft, 0)
    button.label:SetPoint("RIGHT", -labelRight, 0)
    button.label:SetPoint("TOP")
    button.label:SetPoint("BOTTOM")
end

--- 清除字体测量缓存（数据变更时调用）。
function Widgets:ClearGeometryCache()
    geometryCache = {}
end

--- 用条目数据、图标和几何信息填充地点按钮。
-- 地图传送门条目使用不同的图标（poi-islands-table）。
-- @param button Frame 要填充的按钮。
-- @param entry table 地点条目（可能带有 isMapPortal 标记）。
-- @param displayText string|nil 按钮标签的替代文本。
function Widgets:SetLocationEntry(button, entry, displayText)
    local locationScale = GetLocationScale()
    if button.baseFontPath and button.baseFontSize then
        button.label:SetFont(button.baseFontPath, button.baseFontSize * locationScale, button.baseFontFlags or "")
    end
    button.entry = entry
    button.hitArea.entry = entry
    button.isSearchSelected = false
    button.highlight:Hide()
    button.label:SetText(displayText or entry.name)
    if entry.isMapPortal then
        button.icon:SetAtlas("poi-islands-table", false)
    else
        local catInfo = Config.categoryByKey[entry.categoryKey]
        button.icon:SetAtlas(catInfo and catInfo.atlas or Config.art.fallbackLocationAtlas, false)
    end
    self:UpdateLocationGeometry(button)
    button:Show()
end

--- 创建带有点击处理、工具提示和高亮的新地点按钮框架。
-- 使用部件池模式：按钮创建一次，通过 Acquire/Release 复用。
-- @param parent Frame 父框架。
-- @param callbacks table { onActivate, onEdit, onDelete, onEnter }。
-- @return Frame 新按钮。
function Widgets:CreateLocationButton(parent, callbacks)
    local button = CreateFrame("Frame", nil, parent)
    button:SetSize(Config.location.baseWidth, Config.location.baseHeight)
    button.callbacks = callbacks or {}

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints(button)
    button.background:SetTexture(Art.button)
    button.background:SetTexCoord(0, Art.buttonArtWidth / Art.buttonTextureWidth,
        0, Art.buttonArtHeight / Art.buttonTextureHeight)

    button.highlight = button:CreateTexture(nil, "ARTWORK")
    button.highlight:SetAllPoints(button)
    button.highlight:SetTexture(Art.highlight)
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetAlpha(0.75)
    button.highlight:Hide()

    button.iconBox = CreateFrame("Frame", nil, button)
    button.icon = button.iconBox:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button.iconBox)

    button.hitArea = CreateFrame("Button", nil, button)
    button.hitArea:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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

    button.hitArea:SetScript("OnClick", function(self, mouseButton)
        local owner = self.owner
        if mouseButton == "RightButton" then
            if IsShiftKeyDown() and owner.callbacks.onDelete then
                owner.callbacks.onDelete(owner.entry)
            elseif owner.callbacks.onEdit then
                owner.callbacks.onEdit(owner.entry)
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
        else
            GameTooltip:AddLine(string.format(SMK.L.MAP_FORMAT,
                SMK.Map:GetMapName(owner.entry.mapID), owner.entry.mapID), 1, 1, 1)
            GameTooltip:AddLine(string.format(SMK.L.TOOLTIP_XY,
                owner.entry.x, owner.entry.y), 1, 1, 1)
            GameTooltip:AddLine(string.format(SMK.L.TOOLTIP_USAGE_COUNT, SMK.Store:GetUsage(owner.entry)), 0.75, 0.75, 0.75)
            GameTooltip:AddLine(SMK.L.TOOLTIP_INSTRUCTIONS, 0.35, 0.85, 1)
        end
        GameTooltip:Show()
    end)
    button.hitArea:SetScript("OnLeave", function(self)
        local owner = self.owner
        owner.highlight:SetShown(owner.isSearchSelected)
        owner.label:SetTextColor(unpack(owner.isSearchSelected
            and Config.colors.locationHover or Config.colors.locationNormal))
        GameTooltip_Hide()
    end)
    return button
end

--- 调整地点按钮大小，用于搜索结果下拉框。
-- 将左侧图标+背景布局替换为全宽设计。
-- @param button Frame 要重新样式的按钮。
-- @param targetWidth number 期望宽度。
function Widgets:StretchSearchResult(button, targetWidth)
    local locationScale = GetLocationScale()
    local verticalScale = button:GetHeight() / Art.buttonArtHeight
    local leftWidth = Art.textLeft * verticalScale
    button:SetWidth(math.max(targetWidth, leftWidth + 1))
    button:SetClipsChildren(true)
    button.background:Hide()
    if not button.searchBackgroundLeft then
        button.searchBackgroundLeft = button:CreateTexture(nil, "BACKGROUND")
        button.searchBackgroundLeft:SetTexture(Art.button)
        button.searchBackgroundLeft:SetTexCoord(0, Art.textLeft / Art.buttonTextureWidth,
            0, Art.buttonArtHeight / Art.buttonTextureHeight)
        button.searchBackgroundRight = button:CreateTexture(nil, "BACKGROUND")
        button.searchBackgroundRight:SetTexture(Art.button)
        button.searchBackgroundRight:SetTexCoord(Art.textLeft / Art.buttonTextureWidth,
            Art.buttonArtWidth / Art.buttonTextureWidth, 0, Art.buttonArtHeight / Art.buttonTextureHeight)
    end
    button.searchBackgroundLeft:ClearAllPoints()
    button.searchBackgroundLeft:SetPoint("TOPLEFT")
    button.searchBackgroundLeft:SetPoint("BOTTOMLEFT")
    button.searchBackgroundLeft:SetWidth(leftWidth)
    button.searchBackgroundRight:ClearAllPoints()
    button.searchBackgroundRight:SetPoint("TOPLEFT", button.searchBackgroundLeft, "TOPRIGHT")
    button.searchBackgroundRight:SetPoint("BOTTOMRIGHT")
    button.iconBox:ClearAllPoints()
    button.iconBox:SetPoint("TOPLEFT", Art.iconLeft * verticalScale, -Art.iconTop * verticalScale)
    button.iconBox:SetSize(Art.iconWidth * verticalScale, Art.iconHeight * verticalScale)
    button.hitArea:ClearAllPoints()
    button.hitArea:SetAllPoints(button)
    local labelLeft = leftWidth + Art.textLeftPadding * locationScale
    local labelRight = Art.textRightPadding * locationScale
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", labelLeft, 0)
    button.label:SetPoint("RIGHT", -labelRight, 0)
    button.label:SetPoint("TOP")
    button.label:SetPoint("BOTTOM")
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
    local catInfo = Config.categoryByKey[storageKey]
    heading.icon:SetAtlas(catInfo and catInfo.atlas or Config.art.fallbackLocationAtlas, false)
end

SMK.Widgets = Widgets
