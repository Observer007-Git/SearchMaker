local _, SMK = ...

local SearchBarPosition = {}
SearchBarPosition.__index = SearchBarPosition

local function IsSavedPosition(position)
    return type(position) == "table"
        and type(position.x) == "number" and type(position.y) == "number"
end

local function GetScaledAnchorPoint(frame, point)
    local left, bottom, width, height = frame:GetScaledRect()
    if not left then return end
    if point == "TOP" then return left + width / 2, bottom + height end
    return left + width / 2, bottom + height / 2
end

function SearchBarPosition:New(owner)
    return setmetatable({ owner = owner }, self)
end

function SearchBarPosition:Apply(mode)
    local owner = self.owner
    local bar = owner.bar
    bar.positionMode = mode
    bar:ClearAllPoints()
    if mode == "shortcut" then
        local position = SMK.Settings:Get("shortcutSearchBarPosition")
        if IsSavedPosition(position) then
            bar:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
        else
            bar:SetPoint("CENTER", UIParent, "CENTER", 0, SMK.Config.search.shortcutDefaultOffsetY)
        end
    else
        local position = SMK.Settings:Get("mapSearchBarPosition")
        if IsSavedPosition(position) then
            if position.relativePoint == "CENTER" then
                bar:SetPoint("CENTER", WorldMapFrame, "CENTER", position.x, position.y)
                if WorldMapFrame:IsShown() then
                    C_Timer.After(0, function()
                        if bar.positionMode == "map" then self:Save() end
                    end)
                end
            else
                bar:SetPoint("CENTER", WorldMapFrame, "TOP", position.x, position.y)
            end
        else
            bar:SetPoint("CENTER", WorldMapFrame, "TOP", 0, 0)
        end
    end
    owner:UpdateMoveHint()
end

function SearchBarPosition:Save()
    local owner = self.owner
    local bar = owner.bar
    local shortcut = bar.positionMode == "shortcut"
    local anchor = shortcut and UIParent or WorldMapFrame
    local relativePoint = shortcut and "CENTER" or "TOP"
    local sx, sy = GetScaledAnchorPoint(bar, "CENTER")
    local ax, ay = GetScaledAnchorPoint(anchor, relativePoint)
    local scale = bar:GetEffectiveScale()
    if not sx or not sy or not ax or not ay or not scale or scale == 0 then return end
    local position = {
        x = (sx - ax) / scale,
        y = (sy - ay) / scale,
        relativePoint = relativePoint,
    }
    local key = shortcut and "shortcutSearchBarPosition" or "mapSearchBarPosition"
    local saved, message = SMK.Settings:Set(key, position)
    if not saved and message ~= "INVALID_SETTING" then SMK:Print(message) end
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, relativePoint, position.x, position.y)
end

function SearchBarPosition:StartDrag()
    local owner = self.owner
    if not IsShiftKeyDown() then return end
    owner.bar.isDragging = true
    owner.box:ClearFocus()
    owner.bar:StartMoving()
end

function SearchBarPosition:StopDrag()
    local owner = self.owner
    if not owner.bar.isDragging then return end
    owner.bar:StopMovingOrSizing()
    owner.bar.isDragging = false
    self:Save()
end

SMK.SearchBarPosition = SearchBarPosition
