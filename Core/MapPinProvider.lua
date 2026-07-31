local _, SMK = ...

local MapPins = { activePins = {}, temporaryPins = {} }
local TEMPLATE = "SearchMakerMapPinTemplate"
local TEMPORARY_TEMPLATE = "SearchMakerTemporaryRoutePinTemplate"
local HIGHLIGHT_TEMPLATE = "SearchMakerTargetHighlightPinTemplate"

local function GetTemporaryKey(entry)
    if entry.id then return "id:" .. entry.id end
    return "point:" .. SMK.LocationModel:GetDuplicateKey(entry)
end

local function GetCurrentTemporaryEntry(entry)
    return entry.id and SMK.Store:GetByID(entry.id) or entry
end

local function HasPersistentMarker(entry)
    local saved = entry.id and SMK.Store:GetByID(entry.id)
        or SMK.Store:FindDuplicate(entry)
    return saved and (saved.showPinName == 1 or saved.showPinTexture == 1) or false
end

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
        if entry.id then MapPins.activePins[entry.id] = self end
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
            self.labelHitbox = CreateFrame("Button", nil, self)
            self.labelHitbox:SetAllPoints(self.label)
            self.labelHitbox:EnableMouse(true)
            self.labelHitbox:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            self.labelHitbox:SetScript("OnEnter", function() self:OnMouseEnter() end)
            self.labelHitbox:SetScript("OnLeave", function() self:OnMouseLeave() end)
            self.labelHitbox:SetScript("OnClick", function(owner, button)
                self:OnClick(button, owner)
            end)
        end
        self.label:ClearAllPoints()
        local offsetX = SMK.Settings:Get("mapPinNameOffsetX")
        local offsetY = SMK.Settings:Get("mapPinNameOffsetY")
        self.label:SetPoint("CENTER", self, "CENTER", offsetX, offsetY)
        if entry.pinColor then
            self.label:SetTextColor(entry.pinColor.r, entry.pinColor.g, entry.pinColor.b)
        else
            local color = SMK.Config.colors.gold
            self.label:SetTextColor(color[1], color[2], color[3])
        end
        self.label:SetScale(SMK.Settings:Get("mapPinTextScale"))
        local pinTexture = SMK.PinTextureByID[tonumber(entry.pinTextureID)]
            or SMK.PinTextureByID[SMK.DefaultPinTextureID]
        self.icon:SetAtlas(pinTexture.atlas, true)
        self.icon:SetVertexColor(1, 1, 1)
        self.label:SetText(entry.name)
        local showName = entry.showPinName == 1
        local showTexture = entry.showPinTexture == 1
        self.label:SetShown(showName)
        self.labelHitbox:SetShown(showName)
        self.icon:SetShown(showTexture)
        self:Show()
    end

    function mixin:OnReleased()
        if self.entry and self.entry.id and MapPins.activePins[self.entry.id] == self then
            MapPins.activePins[self.entry.id] = nil
        end
        self.entry = nil
        if self.icon then self.icon:Hide() end
        if self.label then
            self.label:SetText("")
            self.label:Hide()
        end
        if self.labelHitbox then self.labelHitbox:Hide() end
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
        if entry.note and entry.note ~= "" then
            local color = SMK.Config.colors.note
            GameTooltip:AddLine(entry.note, color[1], color[2], color[3])
        end
        GameTooltip:AddLine(SMK.L.TOOLTIP_PIN_INSTRUCTIONS, 0.35, 0.85, 1)
        GameTooltip:Show()
    end

    function mixin:OnMouseLeave()
        GameTooltip_Hide()
    end

    function mixin:OnClick(button, owner)
        if button == "RightButton" and self.entry and MapPins.callbacks.onContext then
            GameTooltip_Hide()
            MapPins.callbacks.onContext(self.entry, owner or self)
        elseif button == "LeftButton" and self.entry and MapPins.callbacks.onEdit then
            GameTooltip_Hide()
            local screenX, screenY = SMK.Map:GetCursorScreenPosition()
            if not screenX or not screenY then
                screenX = (self:GetLeft() + self:GetRight()) / 2
                screenY = (self:GetBottom() + self:GetTop()) / 2
            end
            MapPins.callbacks.onEdit(self.entry, screenX, screenY)
        end
    end

    -- MapCanvasPinMixin 在部分正式服版本会调用受保护的按钮透传 API。
    mixin.SetPassThroughButtons = function() end
    return mixin
end

local function CreateTemporaryPinMixin()
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
        local config = SMK.Config.mapPins.routeTemporary
        self:SetPosition(entry.x / 100, entry.y / 100)
        self:SetSize(config.size, config.size)
        if not self.icon then
            self.icon = self:CreateTexture(nil, "OVERLAY")
            self.icon:SetAllPoints(self)
            self.icon:SetAtlas(config.atlas, false)
        end
        self.icon:Show()
        self:Show()
    end

    function mixin:OnReleased()
        if self.icon then self.icon:Hide() end
    end

    mixin.SetPassThroughButtons = function() end
    return mixin
end

local function CreateHighlightPinMixin()
    local mixin = CreateFromMixins(MapCanvasPinMixin)

    function mixin:OnLoad()
        self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
        self:SetScalingLimits(1, SMK.Config.mapPins.minScale, SMK.Config.mapPins.maxScale)
    end

    function mixin:OnAcquired(entry, hideIcon)
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
        self.icon:SetShown(not hideIcon)
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

function MapPins:Initialize(map, callbacks)
    self.callbacks = callbacks or self.callbacks or {}
    if self.provider then return true end
    if not map or not MapCanvasDataProviderMixin or not MapCanvasPinMixin then
        self.available = false
        return false
    end

    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData()
        MapPins.activePins = {}
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
        self:GetMap():RemoveAllPinsByTemplate(TEMPORARY_TEMPLATE)
        self:GetMap():RemoveAllPinsByTemplate(HIGHLIGHT_TEMPLATE)
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        local mapID = self:GetMap():GetMapID()
        if not mapID then return end
        for _, entry in ipairs(SMK.Store:GetByMap(mapID)) do
            local showName = entry.showPinName == 1
            local showTexture = entry.showPinTexture == 1
            if showName or showTexture then
                self:GetMap():AcquirePin(TEMPLATE, entry)
            end
        end
        for _, temporary in pairs(MapPins.temporaryPins) do
            local entry = GetCurrentTemporaryEntry(temporary) or temporary
            if entry.mapID == mapID and not HasPersistentMarker(entry) then
                self:GetMap():AcquirePin(TEMPORARY_TEMPLATE, entry)
            end
        end
    end

    if not SMK.MapPinPoolAdapter:Register(map, TEMPLATE, CreatePinMixin(), true)
        or not SMK.MapPinPoolAdapter:Register(
            map, TEMPORARY_TEMPLATE, CreateTemporaryPinMixin(), false)
        or not SMK.MapPinPoolAdapter:Register(
            map, HIGHLIGHT_TEMPLATE, CreateHighlightPinMixin(), false) then
        self.available = false
        return false
    end
    map:AddDataProvider(provider)
    self.provider = provider
    self.available = true
    return true
end

function MapPins:AddTemporaryRoutePin(entry)
    if not self.provider then return false, "UNAVAILABLE" end
    if type(entry) ~= "table" or not tonumber(entry.mapID)
        or not tonumber(entry.x) or not tonumber(entry.y) then
        return false, "INVALID_LOCATION"
    end
    if HasPersistentMarker(entry) then return false, "PERSISTENT_EXISTS" end
    local key = GetTemporaryKey(entry)
    if self.temporaryPins[key] then return false, "TEMPORARY_EXISTS" end
    self.temporaryPins[key] = {
        id = entry.id,
        mapID = entry.mapID,
        x = entry.x,
        y = entry.y,
        name = entry.name,
    }
    self:Refresh()
    return true
end

function MapPins:HasTemporaryRoutePin(entry)
    return type(entry) == "table"
        and self.temporaryPins[GetTemporaryKey(entry)] ~= nil or false
end

function MapPins:GetTemporaryRoutePins()
    return self.temporaryPins
end

function MapPins:HasPersistentMarker(entry)
    return type(entry) == "table" and HasPersistentMarker(entry) or false
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
    if SMK.MinimapPins then SMK.MinimapPins:Refresh() end
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
    map:AcquirePin(HIGHLIGHT_TEMPLATE, entry, true)
    self.highlightMode = "hover"
    return true
end

function MapPins:ClearHoverHighlight()
    if self.highlightMode == "hover" then self:ClearTargetHighlight() end
end

--- 实时更新地图上指定条目标记的文字颜色（颜色选择预览用）。
-- @param entry table 地点条目。
-- @param color table|nil {r, g, b} 或 nil 表示恢复默认颜色。
function MapPins:UpdatePinPreviewColor(entry, color)
    if not entry then return end
    if SMK.MinimapPins then
        SMK.MinimapPins:UpdatePinPreviewColor(entry, color)
    end
    if not self.provider then return end
    local map = self.provider:GetMap()
    if not map or not map:IsShown() or map:GetMapID() ~= entry.mapID then return end
    local pin = self.activePins[entry.id]
    if not pin or not pin.label then return end
    if color then
        pin.label:SetTextColor(color.r, color.g, color.b)
    else
        local defaultColor = SMK.Config.colors.gold
        pin.label:SetTextColor(defaultColor[1], defaultColor[2], defaultColor[3])
    end
end

function MapPins:UpdatePinVisibility(entry, showPinName, showPinTexture)
    if not entry then return end
    if SMK.MinimapPins then
        SMK.MinimapPins:UpdatePinVisibility(
            entry, showPinName, showPinTexture)
    end
    if not self.provider then return end
    local map = self.provider:GetMap()
    if not map or not map:IsShown() or map:GetMapID() ~= entry.mapID then return end
    local pin = self.activePins[entry.id]
    if not pin then return end
    local nameVisible = showPinName == true
    local textureVisible = showPinTexture == true
    if pin.label then pin.label:SetShown(nameVisible) end
    if pin.labelHitbox then pin.labelHitbox:SetShown(nameVisible) end
    if pin.icon then pin.icon:SetShown(textureVisible) end
    pin:SetShown(nameVisible or textureVisible)
end

SMK.MapPins = MapPins
