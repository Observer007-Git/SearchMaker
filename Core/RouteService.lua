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
    self:NotifyChanged()
    return true
end

function Route:Activate(index)
    index = tonumber(index)
    local entry = index and self.items[index]
    if not entry then return false end
    self.currentIndex = index
    self:NotifyChanged()
    if self.activateHandler then return self.activateHandler(entry) end
    return true
end

function Route:CompleteCurrent()
    local index = self.currentIndex
    if index < 1 or not self.items[index] then return false end
    table.remove(self.items, index)
    self.currentIndex = 0
    if self.items[index] then
        return self:Activate(index)
    end
    self:NotifyChanged()
    return true
end

function Route:Clear()
    for index = #self.items, 1, -1 do self.items[index] = nil end
    self.currentIndex = 0
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
    if changed then self:NotifyChanged() end
end

SMK.Route = Route
