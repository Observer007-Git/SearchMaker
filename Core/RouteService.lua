local _, SMK = ...

local Route = {
    items = {},
    currentIndex = 0,
}

local function CopyEntry(entry)
    return {
        id = entry.id,
        mapID = entry.mapID,
        x = entry.x,
        y = entry.y,
        name = entry.name,
        note = entry.note,
    }
end

local function GetKey(entry)
    if entry.id then return "id:" .. entry.id end
    return "point:" .. SMK.LocationModel:GetDuplicateKey(entry)
end

function Route:SetChangeHandler(callback)
    self.changeHandler = callback
end

function Route:SetActivateHandler(callback)
    self.activateHandler = callback
end

function Route:NotifyChanged()
    if self.changeHandler then self.changeHandler() end
end

function Route:GetItems()
    return self.items
end

function Route:GetCurrentIndex()
    return self.currentIndex
end

function Route:GetActiveSavedRouteID()
    return self.activeSavedRouteID
end

function Route:IsSavedRouteActive(route)
    local id = tonumber(type(route) == "table" and route.id or route)
    return self.currentIndex > 0 and id and self.activeSavedRouteID == id or false
end

local function ClearItems(items)
    for index = #items, 1, -1 do items[index] = nil end
end

function Route:Add(entry)
    if type(entry) ~= "table" or not tonumber(entry.mapID)
        or not tonumber(entry.x) or not tonumber(entry.y) or entry.isMapPortal then
        return false, "INVALID_LOCATION"
    end
    local key = GetKey(entry)
    for _, item in ipairs(self.items) do
        if GetKey(item) == key then return false, "ROUTE_DUPLICATE" end
    end
    if #self.items >= SMK.Config.route.maxEntries then
        return false, "ROUTE_FULL"
    end
    self.items[#self.items + 1] = CopyEntry(entry)
    self.activeSavedRouteID = nil
    self:NotifyChanged()
    return true
end

function Route:Remove(index)
    index = tonumber(index)
    if not index or not self.items[index] then return false end
    table.remove(self.items, index)
    if self.currentIndex == index then
        self.currentIndex = 0
    elseif self.currentIndex > index then
        self.currentIndex = self.currentIndex - 1
    end
    self.activeSavedRouteID = nil
    self:NotifyChanged()
    return true
end

function Route:Move(index, delta)
    index, delta = tonumber(index), tonumber(delta)
    local target = index and delta and index + delta
    if not target or not self.items[index] or not self.items[target] then return false end
    self.items[index], self.items[target] = self.items[target], self.items[index]
    if self.currentIndex == index then
        self.currentIndex = target
    elseif self.currentIndex == target then
        self.currentIndex = index
    end
    self.activeSavedRouteID = nil
    self:NotifyChanged()
    return true
end

local function SortSegmentByNearest(items, first, last, startX, startY)
    local remaining = {}
    for index = first, last do
        remaining[#remaining + 1] = {
            entry = items[index],
            originalIndex = index,
        }
    end
    for target = first, last do
        local nearest, nearestDistance
        for index, candidate in ipairs(remaining) do
            local dx = candidate.entry.x - startX
            local dy = candidate.entry.y - startY
            local distance = dx * dx + dy * dy
            if not nearestDistance or distance < nearestDistance
                or distance == nearestDistance
                    and candidate.originalIndex < remaining[nearest].originalIndex then
                nearest, nearestDistance = index, distance
            end
        end
        local selected = table.remove(remaining, nearest).entry
        items[target] = selected
        startX, startY = selected.x, selected.y
    end
end

--- 按最近邻重新排列连续的同地图区段，不改变地图区段的先后。
-- 玩家所在地图从角色坐标开始；其他地图保留区段首个地点作为入口。
function Route:SortByNearest(playerMapID, playerX, playerY)
    if self.currentIndex > 0 then return false, "ROUTE_ACTIVE" end
    if #self.items < 2 then return false, "ROUTE_TOO_SHORT" end
    playerMapID = tonumber(playerMapID)
    playerX, playerY = tonumber(playerX), tonumber(playerY)
    local before = {}
    for index, entry in ipairs(self.items) do before[index] = entry end

    local first = 1
    while first <= #self.items do
        local last = first
        while last < #self.items
            and self.items[last + 1].mapID == self.items[first].mapID do
            last = last + 1
        end
        if last > first then
            if self.items[first].mapID == playerMapID and playerX and playerY then
                SortSegmentByNearest(self.items, first, last, playerX, playerY)
            elseif last > first + 1 then
                local anchor = self.items[first]
                SortSegmentByNearest(self.items, first + 1, last, anchor.x, anchor.y)
            end
        end
        first = last + 1
    end

    local changed = false
    for index, entry in ipairs(self.items) do
        if entry ~= before[index] then
            changed = true
            break
        end
    end
    if not changed then return false, "ROUTE_ALREADY_SORTED" end
    self.activeSavedRouteID = nil
    self:NotifyChanged()
    return true
end

function Route:Activate(index)
    index = tonumber(index)
    local entry = index and self.items[index]
    if not entry then return false end
    if self.activateHandler and not self.activateHandler(entry) then
        return false, "ACTIVATE_FAILED"
    end
    self.currentIndex = index
    self:NotifyChanged()
    return true
end

--- 将一条保存路线复制为本次登录唯一的执行路线，并从指定点开始。
function Route:ActivateSavedRoute(route, index)
    if type(route) ~= "table" or not tonumber(route.id)
        or type(route.items) ~= "table" or #route.items == 0 then
        return false, "INVALID_ROUTE"
    end
    if self:IsSavedRouteActive(route.id) then
        return false, "ROUTE_ALREADY_ACTIVE"
    end
    index = math.floor(tonumber(index) or 1)
    if not route.items[index] then return false, "INVALID_ROUTE" end
    local newItems = {}
    for _, entry in ipairs(route.items) do
        newItems[#newItems + 1] = CopyEntry(entry)
    end
    if self.activateHandler and not self.activateHandler(newItems[index]) then
        return false, "ACTIVATE_FAILED"
    end
    ClearItems(self.items)
    for _, entry in ipairs(newItems) do self.items[#self.items + 1] = entry end
    self.currentIndex = index
    self.activeSavedRouteID = route.id
    self:NotifyChanged()
    return true
end

function Route:CompleteCurrent()
    local index = self.currentIndex
    if index < 1 or not self.items[index] then return false end
    local activeSavedRouteID = self.activeSavedRouteID
    table.remove(self.items, index)
    self.currentIndex = 0
    if self.items[index] then
        self.activeSavedRouteID = activeSavedRouteID
        local activated = self:Activate(index)
        if not activated then
            self.currentIndex = 0
            self.activeSavedRouteID = nil
            self:NotifyChanged()
        end
        return activated
    end
    self.activeSavedRouteID = nil
    self:NotifyChanged()
    return true
end

function Route:Clear()
    ClearItems(self.items)
    self.currentIndex = 0
    self.activeSavedRouteID = nil
    self:NotifyChanged()
end

--- 地点更新后刷新路线快照；已删除的自建地点从路线中移除。
function Route:RefreshSavedEntries()
    local changed = false
    for index = #self.items, 1, -1 do
        local item = self.items[index]
        if item.id then
            local saved = SMK.Store:GetByID(item.id)
            if not saved then
                table.remove(self.items, index)
                if self.currentIndex == index then
                    self.currentIndex = 0
                elseif self.currentIndex > index then
                    self.currentIndex = self.currentIndex - 1
                end
                changed = true
            else
                self.items[index] = CopyEntry(saved)
                changed = true
            end
        end
    end
    if changed then
        self.activeSavedRouteID = nil
        self:NotifyChanged()
    end
end

function Route:SavedRouteDeleted(route)
    local id = tonumber(type(route) == "table" and route.id or route)
    if id and self.activeSavedRouteID == id then self.activeSavedRouteID = nil end
end

SMK.Route = Route
