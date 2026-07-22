local _, SMK = ...

local MapPins = {}
local TEMPLATE = "SearchMakerMapPinTemplate"

local function CreatePinMixin()
    local mixin = CreateFromMixins(MapCanvasPinMixin)

    function mixin:OnLoad()
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
        self:SetScalingLimits(1, 0.8, 1.2)
    end

    function mixin:OnAcquired(entry)
        if not self.searchMakerLoaded then
            self.searchMakerLoaded = true
            self:OnLoad()
        end
        self.entry = entry
        self:SetPosition(entry.x / 100, entry.y / 100)
        self:SetSize(18, 18)
        if not self.icon then
            self.icon = self:CreateTexture(nil, "OVERLAY")
            self.icon:SetAllPoints(self)
        end
        local texture = SMK.PinTextureByID[tonumber(entry.pinTextureID) or 1]
        self.icon:SetAtlas(texture and texture.atlas or "Waypoint-MapPin-Minimap-Tracked", true)
        self.icon:Show()
        self:Show()
    end

    function mixin:OnReleased()
        self.entry = nil
        if self.icon then self.icon:Hide() end
        GameTooltip_Hide()
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
        pin:EnableMouse(true)
        pin:SetScript("OnEnter", function(owner)
            local entry = owner.entry
            if not entry then return end
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.name)
            GameTooltip:AddLine(string.format(SMK.L.TOOLTIP_COORDINATES,
                entry.mapID, entry.x, entry.y), 1, 1, 1)
            GameTooltip:AddLine(entry.categoryLabel or "", 0.75, 0.75, 0.75)
            GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", GameTooltip_Hide)
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

function MapPins:Initialize(map)
    if self.provider then return true end
    if not map or not MapCanvasDataProviderMixin or not MapCanvasPinMixin then return false end

    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        if not SMK.DB:Get().showMapPins then return end
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
    return true
end

function MapPins:Refresh()
    if self.provider then self.provider:RefreshAllData() end
end

function MapPins:Clear()
    if self.provider then self.provider:RemoveAllData() end
end

SMK.MapPins = MapPins
