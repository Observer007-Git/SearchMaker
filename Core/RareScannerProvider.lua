local _, SMK = ...

local RareScannerProvider = {}
local SOURCE = "RareScanner"
local cacheByMap = {}
local allEntries = {}
local entriesByKey = {}
local EMPTY = {}

local function CleanText(text)
    if type(text) ~= "string" then return nil end
    local value = text
        :gsub("|T.-|t", "")
        :gsub("|A.-|a", "")
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
    value = SMK.Util.Trim(value)
    return value ~= "" and value or nil
end

local function NormalizeCoordinates(x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y or x < 0 or y < 0 then return end
    if x <= 1 and y <= 1 then
        x, y = x * 100, y * 100
    end
    if x > 100 or y > 100 then return end
    return math.floor(x * 100 + 0.5) / 100,
        math.floor(y * 100 + 0.5) / 100
end

local function IsRareScannerTexture(texture)
    return type(texture) == "string" and texture:find("RareScanner", 1, true) ~= nil
end

function RareScannerProvider:NotifyChanged()
    if self.notifyPending or not self.changeHandler then return end
    self.notifyPending = true
    C_Timer.After(0, function()
        self.notifyPending = false
        if self.changeHandler then self.changeHandler() end
    end)
end

function RareScannerProvider:AddPOI(poi)
    if type(poi) ~= "table" or not poi.isNpc then return false end
    local mapID = tonumber(poi.mapID)
    local entityID = tonumber(poi.entityID)
    local name = CleanText(poi.name)
    local x, y = NormalizeCoordinates(poi.x, poi.y)
    if not mapID or not entityID or not name or not x or not y then return false end

    local key = string.format("%d:%d:%.2f:%.2f", mapID, entityID, x, y)
    local existing = entriesByKey[key]
    if existing then
        local changed = existing.name ~= name
        existing.name = name
        existing.normalizedName = SMK.Util.Normalize(name)
        existing.normalizedSearchable = existing.normalizedName
        if IsRareScannerTexture(poi.Texture) then
            existing.iconTexture = poi.Texture
        end
        return changed
    end

    local entry = {
        mapID = mapID,
        x = x,
        y = y,
        name = name,
        categoryKey = "npc",
        isExternal = true,
        externalID = entityID,
        externalSource = SOURCE,
        iconTexture = IsRareScannerTexture(poi.Texture) and poi.Texture or nil,
        normalizedName = SMK.Util.Normalize(name),
    }
    entry.normalizedSearchable = entry.normalizedName
    entriesByKey[key] = entry
    allEntries[#allEntries + 1] = entry
    local mapEntries = cacheByMap[mapID]
    if not mapEntries then
        mapEntries = {}
        cacheByMap[mapID] = mapEntries
    end
    mapEntries[#mapEntries + 1] = entry
    return true
end

function RareScannerProvider:CapturePOI(poi)
    if type(poi) ~= "table" then return false end
    local changed = false
    if type(poi.POIs) == "table" then
        for _, child in ipairs(poi.POIs) do
            if self:CapturePOI(child) then changed = true end
        end
    elseif self:AddPOI(poi) then
        changed = true
    end
    if changed then self:NotifyChanged() end
    return changed
end

function RareScannerProvider:RefreshCurrentMap()
    if not WorldMapFrame or type(WorldMapFrame.EnumeratePinsByTemplate) ~= "function" then
        return
    end
    for _, template in ipairs({ "RSEntityPinTemplate", "RSGroupPinTemplate" }) do
        local ok, iterator, state, initial = pcall(
            WorldMapFrame.EnumeratePinsByTemplate, WorldMapFrame, template)
        if ok and type(iterator) == "function" then
            for pin in iterator, state, initial do
                self:CapturePOI(pin and pin.POI)
            end
        end
    end
end

function RareScannerProvider:GetAll(mapID, allMaps)
    if allMaps then return allEntries end
    return cacheByMap[tonumber(mapID)] or EMPTY
end

function RareScannerProvider:Initialize(changeHandler)
    self.changeHandler = changeHandler
    if self.initialized then return end
    self.initialized = true
    if type(RSPinMixin) ~= "table" then return end
    if type(hooksecurefunc) == "function" then
        if type(RSPinMixin.OnAcquired) == "function" then
            hooksecurefunc(RSPinMixin, "OnAcquired", function(_, poi)
                self:CapturePOI(poi)
            end)
        end

        local hbdPins = LibStub and LibStub.GetLibrary
            and LibStub:GetLibrary("HereBeDragons-Pins-2.0", true)
        if hbdPins and type(hbdPins.AddMinimapIconMap) == "function" then
            hooksecurefunc(hbdPins, "AddMinimapIconMap", function(_, _, icon)
                local poi = icon and icon.POI
                if poi and IsRareScannerTexture(poi.Texture) then
                    self:CapturePOI(poi)
                end
            end)
        end
    end
    self:RefreshCurrentMap()
end

SMK.RareScannerProvider = RareScannerProvider
