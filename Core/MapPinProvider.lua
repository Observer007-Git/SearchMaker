local _, SMK = ...

local MapPins = {}
local TEMPLATE = "SearchMakerMapPinTemplate"
local HIGHLIGHT_TEMPLATE = "SearchMakerTargetHighlightPinTemplate"

local function CreatePinMixin()
    local mixin = CreateFromMixins(MapCanvasPinMixin)

    function mixin:OnLoad()
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
        self:SetScalingLimits(1, SMK.Config.mapPins.minScale, SMK.Config.mapPins.maxScale)
    end

    function mixin:OnAcquired(entry)
        if not self.searchMakerLoaded then
            self.searchMakerLoaded = true
            self:OnLoad()
        end
        self.entry = entry
        self:SetPosition(entry.x / 100, entry.y / 100)
        local textureScale = SMK.Settings:Get("pinTextureScale")
        local pinSize = SMK.Config.mapPins.size * textureScale
        self:SetSize(pinSize, pinSize)
        if not self.icon then
            self.icon = self:CreateTexture(nil, "OVERLAY")
            self.icon:SetAllPoints(self)
        end
        if not self.label then
            self.label = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        end
        self.label:ClearAllPoints()
        local offsetX = SMK.Settings:Get("mapPinNameOffsetX")
        local offsetY = SMK.Settings:Get("mapPinNameOffsetY")
        self.label:SetPoint("BOTTOM", self, "TOP", offsetX, offsetY)
        if entry.pinColor then
            self.label:SetTextColor(entry.pinColor.r, entry.pinColor.g, entry.pinColor.b)
        else
            local textColor = SMK.Settings:Get("mapPinTextColor")
            self.label:SetTextColor(textColor.r, textColor.g, textColor.b)
        end
        self.label:SetScale(SMK.Settings:Get("mapPinTextScale"))
        local texture = SMK.PinTextureByID[tonumber(entry.pinTextureID)]
            or SMK.PinTextureByID[SMK.DefaultPinTextureID]
        self.icon:SetAtlas(texture and texture.atlas or SMK.Config.art.fallbackLocationAtlas, true)
        self.icon:SetVertexColor(1, 1, 1)
        self.label:SetText(entry.name)
        local showName = entry.showPinName == 1
        local showTexture = entry.showPinTexture == 1
        self.label:SetShown(SMK.Settings:Get("showMapPinNames") and showName)
        self.icon:SetShown(SMK.Settings:Get("showPinTextures") and showTexture)
        self:Show()
    end

    function mixin:OnReleased()
        self.entry = nil
        if self.icon then self.icon:Hide() end
        if self.label then
            self.label:SetText("")
            self.label:Hide()
        end
        GameTooltip_Hide()
    end

    function mixin:OnMouseEnter()
        local entry = self.entry
        if not entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(entry.name)
        GameTooltip:AddLine(string.format(SMK.L.MAP_FORMAT,
            SMK.Map:GetMapName(entry.mapID), entry.mapID), 1, 1, 1)
        GameTooltip:AddLine(string.format(SMK.L.TOOLTIP_XY, entry.x, entry.y), 1, 1, 1)
        GameTooltip:AddLine(entry.categoryLabel or "", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end

    function mixin:OnMouseLeave()
        GameTooltip_Hide()
    end

    function mixin:OnClick(button)
        if button == "LeftButton" and self.entry and MapPins.callbacks.onEdit then
            GameTooltip_Hide()
            local screenX = (self:GetLeft() + self:GetRight()) / 2
            local screenY = (self:GetBottom() + self:GetTop()) / 2
            MapPins.callbacks.onEdit(self.entry, screenX, screenY)
        end
    end

    -- MapCanvasPinMixin 在部分正式服版本会调用受保护的按钮透传 API。
    mixin.SetPassThroughButtons = function() end
    return mixin
end

local function CreateHighlightPinMixin()
    local mixin = CreateFromMixins(MapCanvasPinMixin)

    function mixin:OnLoad()
        self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
        self:SetScalingLimits(1, SMK.Config.mapPins.minScale, SMK.Config.mapPins.maxScale)
    end

    function mixin:OnAcquired(entry)
        if not self.searchMakerLoaded then
            self.searchMakerLoaded = true
            self:OnLoad()
        end
        local config = SMK.Config.mapPins.targetHighlight
        self:SetPosition(entry.x / 100, entry.y / 100)
        self:SetSize(config.size, config.size)
        if not self.icon then
            self.icon = self:CreateTexture(nil, "OVERLAY")
            self.icon:SetAllPoints(self)
            self.icon:SetAtlas(config.atlas, false)

            self.ring = self:CreateTexture(nil, "OVERLAY")
            self.ring:SetPoint("CENTER", self, "CENTER")
            self.ring:SetTexture(config.ringTexture)
            self.ring:SetBlendMode("ADD")
            self.ring:SetVertexColor(1, 1, 1)

            self.pulse = self.ring:CreateAnimationGroup()
            local fadeOut = self.pulse:CreateAnimation("Alpha")
            fadeOut:SetFromAlpha(1)
            fadeOut:SetToAlpha(0.2)
            fadeOut:SetDuration(0.45)
            fadeOut:SetOrder(1)
            local fadeIn = self.pulse:CreateAnimation("Alpha")
            fadeIn:SetFromAlpha(0.2)
            fadeIn:SetToAlpha(1)
            fadeIn:SetDuration(0.45)
            fadeIn:SetOrder(2)
            self.pulse:SetLooping("REPEAT")
        end
        self.ring:SetSize(config.ringSize, config.ringSize)
        self.icon:Show()
        self.ring:Show()
        self.pulse:Play()
        self:Show()
    end

    function mixin:OnReleased()
        if self.pulse then self.pulse:Stop() end
        if self.icon then self.icon:Hide() end
        if self.ring then self.ring:Hide() end
    end

    mixin.SetPassThroughButtons = function() end
    return mixin
end

local function CreatePinPool(map, template, pinMixin, enableMouse)
    local pool = CreateUnsecuredRegionPoolInstance
        and CreateUnsecuredRegionPoolInstance(template) or CreateFramePool("FRAME")
    pool.parent = map:GetCanvas()
    pool.createFunc = function()
        local pin = CreateFrame("Frame", nil, map:GetCanvas())
        pin.isSearchMakerMapPin = true
        pin:EnableMouse(enableMouse == true)
        return Mixin(pin, pinMixin)
    end
    pool.resetFunc = function(_, pin)
        pin:Hide()
        pin:ClearAllPoints()
        pin:OnReleased()
        pin.pinTemplate = nil
        pin.owningMap = nil
    end
    pool.creationFunc = pool.createFunc
    pool.resetterFunc = pool.resetFunc
    map.pinPools[template] = pool
end

function MapPins:Initialize(map, callbacks)
    self.callbacks = callbacks or self.callbacks or {}
    if self.provider then return true end
    if not map or not MapCanvasDataProviderMixin or not MapCanvasPinMixin then
        self.available = false
        return false
    end

    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
        self:GetMap():RemoveAllPinsByTemplate(HIGHLIGHT_TEMPLATE)
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        local mapID = self:GetMap():GetMapID()
        if not mapID then return end
        local showNames = SMK.Settings:Get("showMapPinNames")
        local showTextures = SMK.Settings:Get("showPinTextures")
        for _, entry in ipairs(SMK.Store:GetByMap(mapID)) do
            local showName = entry.showPinName == 1
            local showTexture = entry.showPinTexture == 1
            if (showNames and showName) or (showTextures and showTexture) then
                self:GetMap():AcquirePin(TEMPLATE, entry)
            end
        end
    end

    CreatePinPool(map, TEMPLATE, CreatePinMixin(), true)
    CreatePinPool(map, HIGHLIGHT_TEMPLATE, CreateHighlightPinMixin(), false)
    map:AddDataProvider(provider)
    self.provider = provider
    self.available = true
    return true
end

function MapPins:IsAvailable()
    return self.available == true
end

function MapPins:ContainsMouseFocus(foci)
    for _, focus in ipairs(foci or {}) do
        local frame = focus
        while frame do
            if frame.isSearchMakerMapPin then return true end
            frame = frame.GetParent and frame:GetParent() or nil
        end
    end
    return false
end

function MapPins:Refresh()
    if self.provider then self.provider:RefreshAllData() end
end

function MapPins:ClearTargetHighlight()
    self.highlightToken = (self.highlightToken or 0) + 1
    self.highlightMode = nil
    if self.provider then
        self.provider:GetMap():RemoveAllPinsByTemplate(HIGHLIGHT_TEMPLATE)
    end
end

function MapPins:ShowTargetHighlight(entry)
    self:ClearTargetHighlight()
    if not self.provider or type(entry) ~= "table" then return false end
    local map = self.provider:GetMap()
    if not map:IsShown() or map:GetMapID() ~= entry.mapID then return false end

    map:AcquirePin(HIGHLIGHT_TEMPLATE, entry)
    self.highlightMode = "target"
    local token = self.highlightToken
    C_Timer.After(SMK.Config.mapPins.targetHighlight.duration, function()
        if self.highlightToken == token then self:ClearTargetHighlight() end
    end)
    return true
end

function MapPins:ShowHoverHighlight(entry)
    if self.highlightMode == "target" or not self.provider or type(entry) ~= "table" then
        return false
    end
    local map = self.provider:GetMap()
    if not map:IsShown() or map:GetMapID() ~= entry.mapID then return false end

    self:ClearTargetHighlight()
    map:AcquirePin(HIGHLIGHT_TEMPLATE, entry)
    self.highlightMode = "hover"
    return true
end

function MapPins:ClearHoverHighlight()
    if self.highlightMode == "hover" then self:ClearTargetHighlight() end
end

function MapPins:Clear()
    if self.provider then self.provider:RemoveAllData() end
end

--- 实时更新地图上指定条目标记的文字颜色（颜色选择预览用）。
-- @param entry table 地点条目。
-- @param color table|nil {r, g, b} 或 nil 表示恢复默认颜色。
function MapPins:UpdatePinPreviewColor(entry, color)
    if not self.provider or not entry then return end
    local map = self.provider:GetMap()
    if not map or not map:IsShown() or map:GetMapID() ~= entry.mapID then return end
    local canvas = map:GetCanvas()
    if not canvas then return end
    for _, child in ipairs({canvas:GetChildren()}) do
        if child.isSearchMakerMapPin and child.entry == entry and child.label then
            if color then
                child.label:SetTextColor(color.r, color.g, color.b)
            else
                local textColor = SMK.Settings:Get("mapPinTextColor")
                child.label:SetTextColor(textColor.r, textColor.g, textColor.b)
            end
            return
        end
    end
end

function MapPins:UpdatePinVisibility(entry, showPinName, showPinTexture)
    if not self.provider or not entry then return end
    local map = self.provider:GetMap()
    if not map or not map:IsShown() or map:GetMapID() ~= entry.mapID then return end
    local canvas = map:GetCanvas()
    if not canvas then return end
    for _, child in ipairs({canvas:GetChildren()}) do
        if child.isSearchMakerMapPin and child.entry == entry then
            local nameVisible = SMK.Settings:Get("showMapPinNames") and showPinName
            local textureVisible = SMK.Settings:Get("showPinTextures") and showPinTexture
            if child.label then
                child.label:SetShown(nameVisible)
            end
            if child.icon then
                child.icon:SetShown(textureVisible)
            end
            child:SetShown(nameVisible or textureVisible)
            return
        end
    end
end

SMK.MapPins = MapPins
