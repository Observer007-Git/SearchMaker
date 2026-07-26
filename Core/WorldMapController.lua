local _, SMK = ...

local Controller = {}

local function IsCursorOverCanvas()
    local container = WorldMapFrame and WorldMapFrame.ScrollContainer
    if not container then return false end
    local foci = GetMouseFoci and GetMouseFoci() or nil
    if foci and DoesAncestryIncludeAny then
        if SMK.MapPins:ContainsMouseFocus(foci) then return false end
        return DoesAncestryIncludeAny(container, foci)
    end
    return container:IsMouseOver()
end

function Controller:BuildMapIndex()
    if SMK.MapIndex:Rebuild() then return end
    self.rebuildAttempts = (self.rebuildAttempts or 0) + 1
    if self.rebuildAttempts < 10 then
        C_Timer.After(1, function() self:BuildMapIndex() end)
    end
end

function Controller:Initialize(callbacks)
    if self.initialized then return end
    self.initialized = true
    self.callbacks = callbacks or {}

    WorldMapFrame:HookScript("OnShow", function()
        SMK.MapIndex:Rebuild()
        SMK.HandyNotesProvider:RebuildCache()
        if self.callbacks.onShown then self.callbacks.onShown() end
    end)
    WorldMapFrame:HookScript("OnHide", function()
        SMK.HandyNotesProvider:RebuildCache(SMK.Map:GetPlayerMapID())
        if self.callbacks.onHidden then self.callbacks.onHidden() end
    end)
    hooksecurefunc(WorldMapFrame, "SetMapID", function()
        if WorldMapFrame:IsShown() then
            SMK.HandyNotesProvider:RebuildCache()
            if self.callbacks.onMapChanged then self.callbacks.onMapChanged() end
        end
    end)

    local mouseFrame = CreateFrame("Frame")
    self.mouseFrame = mouseFrame
    mouseFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    mouseFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    mouseFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    mouseFrame:SetScript("OnEvent", function(_, event, button)
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            SMK.HandyNotesProvider:RebuildCache()
            if self.callbacks.onMapChanged then self.callbacks.onMapChanged() end
            return
        end
        if button ~= "LeftButton" or not IsAltKeyDown()
            or not WorldMapFrame:IsShown() or not IsCursorOverCanvas() then return end
        local x, y = SMK.Map:GetCursorMapCoordinates()
        local mapID = x and SMK.Map:GetContextMapID() or nil
        local screenX, screenY = SMK.Map:GetCursorScreenPosition()
        if mapID and self.callbacks.onAltClick then
            self.callbacks.onAltClick(mapID, x, y, screenX, screenY)
        end
    end)

    self:BuildMapIndex()
    SMK.HandyNotesProvider:RebuildCache()
    C_Timer.After(0, function()
        if self.callbacks.onReady then self.callbacks.onReady() end
    end)
end

SMK.WorldMapController = Controller
