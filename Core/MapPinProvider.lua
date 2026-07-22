local _, SMK = ...

local MapPins = {}
local TEMPLATE = "SearchMakerMapPinTemplate"

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
        self:SetSize(SMK.Config.mapPins.size, SMK.Config.mapPins.size)
        if not self.icon then
            self.icon = self:CreateTexture(nil, "OVERLAY")
            self.icon:SetAllPoints(self)
        end
        if not self.label then
            self.label = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            self.label:SetPoint("BOTTOM", self, "TOP", 0, 2)
            local color = SMK.Config.colors.gold
            self.label:SetTextColor(color[1], color[2], color[3])
        end
        local texture = SMK.PinTextureByID[tonumber(entry.pinTextureID) or 1]
        self.icon:SetAtlas(texture and texture.atlas or SMK.Config.art.fallbackLocationAtlas, true)
        self.label:SetText(entry.name)
        self.label:SetShown(SMK.Settings:Get("showMapPinNames"))
        self.icon:Show()
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
        GameTooltip:AddLine(string.format(SMK.L.TOOLTIP_COORDINATES,
            entry.mapID, entry.x, entry.y), 1, 1, 1)
        GameTooltip:AddLine(entry.categoryLabel or "", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end

    function mixin:OnMouseLeave()
        GameTooltip_Hide()
    end

    function mixin:OnClick(button)
        if button == "LeftButton" and self.entry and MapPins.callbacks.onEdit then
            GameTooltip_Hide()
            MapPins.callbacks.onEdit(self.entry)
        end
    end

    -- MapCanvasPinMixin 在部分正式服版本会调用受保护的按钮透传 API。
    mixin.SetPassThroughButtons = function() end
    return mixin
end

local function CreatePinPool(map, pinMixin)
    local pool = CreateUnsecuredRegionPoolInstance
        and CreateUnsecuredRegionPoolInstance(TEMPLATE) or CreateFramePool("FRAME")
    pool.parent = map:GetCanvas()
    pool.createFunc = function()
        local pin = CreateFrame("Frame", nil, map:GetCanvas())
        pin.isSearchMakerMapPin = true
        pin:EnableMouse(true)
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
    map.pinPools[TEMPLATE] = pool
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
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        if not SMK.Settings:Get("showMapPins") then return end
        local mapID = self:GetMap():GetMapID()
        if not mapID then return end
        for _, entry in ipairs(SMK.Store:GetByMap(mapID)) do
            if entry.showPin == 1 then
                self:GetMap():AcquirePin(TEMPLATE, entry)
            end
        end
    end

    CreatePinPool(map, CreatePinMixin())
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

function MapPins:Clear()
    if self.provider then self.provider:RemoveAllData() end
end

SMK.MapPins = MapPins
