local _, SMK = ...

local MinimapPins = {
    active = {},
    activeByID = {},
    pool = {},
}

local function GetHereBeDragonsPins()
    if not LibStub then return end
    return LibStub("HereBeDragons-Pins-2.0", true)
end

local function ApplyPinAppearance(pin, entry, temporary)
    local textureScale = SMK.Settings:Get("pinTextureScale")
    local config = temporary and SMK.Config.mapPins.routeTemporary or nil
    local size = config and config.size
        or SMK.Config.mapPins.size * textureScale
    pin:SetSize(size, size)
    if temporary then
        pin.icon:SetAtlas(config.atlas, false)
    else
        local texture = SMK.PinTextureByID[tonumber(entry.pinTextureID)]
            or SMK.PinTextureByID[SMK.DefaultPinTextureID]
        pin.icon:SetAtlas(texture.atlas, false)
    end
    pin.icon:Show()
end

function MinimapPins:Acquire(entry, temporary)
    local pin = table.remove(self.pool)
    if not pin then
        pin = CreateFrame("Frame", nil, Minimap)
        pin:SetFrameStrata("MEDIUM")
        pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        pin:EnableMouse(false)
        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetAllPoints(pin)
    end
    pin.entry = entry
    pin.temporary = temporary == true
    pin:Hide()
    ApplyPinAppearance(pin, entry, temporary)
    self.active[#self.active + 1] = pin
    return pin
end

function MinimapPins:ReleaseAll()
    if self.hbdPins then self.hbdPins:RemoveAllMinimapIcons(SMK.name) end
    for _, pin in ipairs(self.active) do
        pin.entry = nil
        pin.targetX, pin.targetY, pin.instanceID = nil, nil, nil
        pin.icon:Hide()
        pin:Hide()
        self.pool[#self.pool + 1] = pin
    end
    self.active = {}
    self.activeByID = {}
end

function MinimapPins:Place(pin, entry)
    if self.hbdPins then
        return self.hbdPins:AddMinimapIconMap(
            SMK.name, pin, entry.mapID, entry.x / 100, entry.y / 100, false, false)
    end
    if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then
        return false
    end
    local instanceID, position = C_Map.GetWorldPosFromMapPos(
        entry.mapID, CreateVector2D(entry.x / 100, entry.y / 100))
    if not position then return false end
    local worldY, worldX = position:GetXY()
    pin.targetX, pin.targetY, pin.instanceID = worldX, worldY, instanceID
    return worldX ~= nil and worldY ~= nil
end

function MinimapPins:AddEntry(entry, temporary)
    local pin = self:Acquire(entry, temporary)
    if self:Place(pin, entry) then
        if entry.id and not temporary then self.activeByID[entry.id] = pin end
        return
    end
    self.active[#self.active] = nil
    pin.entry = nil
    pin:Hide()
    self.pool[#self.pool + 1] = pin
end

function MinimapPins:Refresh()
    if not self.initialized then return end
    self:ReleaseAll()
    local mapID = SMK.Map:GetPlayerMapID()
    if mapID then
        for _, entry in ipairs(SMK.Store:GetByMap(mapID)) do
            if entry.showPinTexture == 1 then
                self:AddEntry(entry, false)
            end
        end
        for _, temporary in pairs(SMK.MapPins:GetTemporaryRoutePins()) do
            local entry = temporary.id and SMK.Store:GetByID(temporary.id) or temporary
            if entry and entry.mapID == mapID
                and not SMK.MapPins:HasPersistentMarker(entry) then
                self:AddEntry(entry, true)
            end
        end
    end
    self.positionDirty = true
    if self.updater then self.updater:SetShown(#self.active > 0) end
    if not self.hbdPins and #self.active > 0 then self:UpdatePositions(true) end
end

function MinimapPins:UpdatePositions(force)
    if self.hbdPins or #self.active == 0 or not UnitPosition
        or not C_Minimap or not C_Minimap.GetViewRadius then return end
    if Minimap.IsShown and not Minimap:IsShown() then return end
    local playerY, playerX, _, instanceID = UnitPosition("player")
    local radius = C_Minimap.GetViewRadius()
    if not playerX or not playerY or not radius or radius <= 0 then
        if self.positionAvailable ~= false then
            for _, pin in ipairs(self.active) do pin:Hide() end
        end
        self.positionAvailable = false
        return
    end
    local halfWidth, halfHeight = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing and GetPlayerFacing() or nil
    if rotate and not facing then
        if self.positionAvailable ~= false then
            for _, pin in ipairs(self.active) do pin:Hide() end
        end
        self.positionAvailable = false
        return
    end
    if not force and not self.positionDirty and self.positionAvailable
        and self.lastPlayerX == playerX and self.lastPlayerY == playerY
        and self.lastInstanceID == instanceID and self.lastRadius == radius
        and self.lastHalfWidth == halfWidth and self.lastHalfHeight == halfHeight
        and self.lastRotate == rotate and self.lastFacing == facing then
        return
    end
    self.positionDirty = false
    self.positionAvailable = true
    self.lastPlayerX, self.lastPlayerY = playerX, playerY
    self.lastInstanceID, self.lastRadius = instanceID, radius
    self.lastHalfWidth, self.lastHalfHeight = halfWidth, halfHeight
    self.lastRotate, self.lastFacing = rotate, facing
    local mapSin, mapCos = rotate and math.sin(facing) or 0,
        rotate and math.cos(facing) or 1
    for _, pin in ipairs(self.active) do
        if pin.instanceID ~= instanceID then
            pin:Hide()
        else
            local xDistance = playerX - pin.targetX
            local yDistance = playerY - pin.targetY
            if rotate then
                local x, y = xDistance, yDistance
                xDistance = x * mapCos - y * mapSin
                yDistance = x * mapSin + y * mapCos
            end
            local x, y = xDistance / radius, yDistance / radius
            if (x * x + y * y) <= 0.81 then
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", Minimap, "CENTER",
                    x * halfWidth, -y * halfHeight)
                pin:Show()
            else
                pin:Hide()
            end
        end
    end
end

function MinimapPins:UpdatePinVisibility(entry, showPinTexture)
    local pin = entry and self.activeByID[entry.id]
    if not pin then return end
    pin.icon:SetShown(showPinTexture == true)
end

function MinimapPins:Initialize()
    if self.initialized then return true end
    if not Minimap then return false end

    local updater, events
    local ready, errorMessage = pcall(function()
        self.hbdPins = GetHereBeDragonsPins()
        if not self.hbdPins then
            updater = CreateFrame("Frame")
            updater:Hide()
            updater:SetScript("OnUpdate", function() self:UpdatePositions() end)
            self.updater = updater
        end
        events = CreateFrame("Frame")
        self.events = events
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        if not self.hbdPins then
            events:RegisterEvent("MINIMAP_UPDATE_ZOOM")
            events:RegisterEvent("CVAR_UPDATE")
        end
        events:SetScript("OnEvent", function(_, event, name)
            if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
                self:Refresh()
            elseif not self.hbdPins and event == "MINIMAP_UPDATE_ZOOM" then
                self:UpdatePositions(true)
            elseif not self.hbdPins and event == "CVAR_UPDATE"
                and (name == "rotateMinimap" or name == "ROTATE_MINIMAP") then
                self:UpdatePositions(true)
            end
        end)
        self.initialized = true
        self:Refresh()
    end)
    if ready then return true end

    pcall(self.ReleaseAll, self)
    if updater then
        pcall(function()
            updater:SetScript("OnUpdate", nil)
            updater:Hide()
        end)
    end
    if events then
        pcall(function()
            events:UnregisterAllEvents()
            events:SetScript("OnEvent", nil)
        end)
    end
    self.initialized = false
    self.hbdPins, self.updater, self.events = nil, nil, nil
    return false, errorMessage
end

SMK.MinimapPins = MinimapPins
