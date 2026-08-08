local _, SMK = ...

local Controller = {}

function Controller:IsCreateShortcutDown()
    local shortcut = SMK.Settings:Get("mapPinCreateShortcut")
    if type(shortcut) ~= "table" then return IsAltKeyDown() end
    return (shortcut.alt == true) == (IsAltKeyDown() and true or false)
        and (shortcut.ctrl == true) == (IsControlKeyDown() and true or false)
        and (shortcut.shift == true) == (IsShiftKeyDown() and true or false)
        and (shortcut.meta == true) == (IsMetaKeyDown() and true or false)
        and (not shortcut.key or IsKeyDown(shortcut.key))
end

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

function Controller:ScheduleMapIndexRetry()
    self.rebuildAttempts = (self.rebuildAttempts or 0) + 1
    if self.rebuildAttempts < 10 then
        C_Timer.After(1, function() self:BuildMapIndex() end)
    end
end

function Controller:BuildMapIndex()
    local accepted, building = SMK.MapIndex:Rebuild()
    if accepted then
        if not building then self.rebuildAttempts = 0 end
        return
    end
    self:ScheduleMapIndexRetry()
end

function Controller:Initialize(callbacks)
    if self.initialized then return end
    self.initialized = true
    self.callbacks = callbacks or {}
    SMK.MapIndex:SetBuildHandler(function(success)
        if success then
            self.rebuildAttempts = 0
            if self.callbacks.onMapIndexReady then
                self.callbacks.onMapIndexReady()
            end
        else
            self:ScheduleMapIndexRetry()
        end
    end)

    WorldMapFrame:HookScript("OnShow", function()
        SMK.MapIndex:Rebuild()
        if self.callbacks.onShown then
            self.callbacks.onShown(SMK.Map:GetContextMapID())
        end
    end)
    WorldMapFrame:HookScript("OnHide", function()
        if self.callbacks.onHidden then
            self.callbacks.onHidden(SMK.Map:GetPlayerMapID())
        end
    end)
    hooksecurefunc(WorldMapFrame, "SetMapID", function()
        if WorldMapFrame:IsShown() then
            if self.callbacks.onMapChanged then
                self.callbacks.onMapChanged(SMK.Map:GetContextMapID(), false)
            end
        end
    end)

    local mouseFrame = CreateFrame("Frame")
    self.mouseFrame = mouseFrame
    mouseFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    mouseFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    mouseFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    mouseFrame:SetScript("OnEvent", function(_, event, button)
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            if self.callbacks.onMapChanged then
                self.callbacks.onMapChanged(SMK.Map:GetPlayerMapID(), false)
            end
            return
        end
        if button ~= "LeftButton" or not self:IsCreateShortcutDown()
            or not WorldMapFrame:IsShown() or not IsCursorOverCanvas() then return end
        local x, y = SMK.Map:GetCursorMapCoordinates()
        local mapID = x and SMK.Map:GetContextMapID() or nil
        local screenX, screenY = SMK.Map:GetCursorScreenPosition()
        if mapID and self.callbacks.onMapCreateClick then
            self.callbacks.onMapCreateClick(mapID, x, y, screenX, screenY)
        end
    end)

    self:BuildMapIndex()
    C_Timer.After(0, function()
        if self.callbacks.onReady then self.callbacks.onReady() end
    end)
end

SMK.WorldMapController = Controller
