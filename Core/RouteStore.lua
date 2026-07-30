local _, SMK = ...

local Store = {}
local Config = SMK.Config
local Util = SMK.Util

local cacheDirty = true
local cachedRoutes = {}
local routeByID = {}
local routeByName = {}
local changeHandler

local function CopyPoint(values)
    if type(values) ~= "table" then return end
    local point = {
        mapID = tonumber(values.mapID),
        x = tonumber(values.x),
        y = tonumber(values.y),
        name = Util.Trim(values.name),
    }
    local nameWidth = Util.GetTextWidth(point.name)
    if not point.mapID or point.mapID <= 0 or point.mapID % 1 ~= 0
        or not point.x or point.x < 0 or point.x > 100
        or not point.y or point.y < 0 or point.y > 100
        or point.name == "" or not nameWidth
        or nameWidth > Config.location.maxNameWidth then
        return
    end
    return point
end

function Store:Normalize(values)
    if type(values) ~= "table" then return nil, "INVALID_ROUTE" end
    local name = Util.Trim(values.name)
    local nameWidth = Util.GetTextWidth(name)
    if name == "" or not nameWidth or nameWidth > Config.route.maxNameWidth
        or type(values.items) ~= "table" or #values.items < 1
        or #values.items > Config.route.maxEntries then
        return nil, "INVALID_ROUTE"
    end
    local route = { name = name, items = {} }
    for _, valuesPoint in ipairs(values.items) do
        local point = CopyPoint(valuesPoint)
        if not point then return nil, "INVALID_ROUTE" end
        route.items[#route.items + 1] = point
    end
    return route
end

--- 规范化数据库中的保存路线，并为缺失或重复的路线分配稳定 ID。
function Store:PrepareDatabase(database)
    database.savedRoutes = type(database.savedRoutes) == "table"
        and database.savedRoutes or {}
    database.nextRouteID = math.max(
        1, math.floor(tonumber(database.nextRouteID) or 1))
    local valid, used = {}, {}
    for _, stored in ipairs(database.savedRoutes) do
        local route = self:Normalize(stored)
        if route then
            local id = tonumber(stored.id)
            if not id or id < 1 or id % 1 ~= 0 or used[id] then
                id = database.nextRouteID
                database.nextRouteID = database.nextRouteID + 1
            end
            route.id = id
            used[id] = true
            database.nextRouteID = math.max(database.nextRouteID, id + 1)
            valid[#valid + 1] = route
        end
    end
    database.savedRoutes = valid
    self:InvalidateCache()
end

local function BuildDisplay(stored)
    local route = {
        id = stored.id,
        name = stored.name,
        items = stored.items,
        isSavedRoute = true,
        normalizedName = Util.Normalize(stored.name),
    }
    return route
end

local function RebuildCache()
    local routes, byID, byName = {}, {}, {}
    for _, stored in ipairs(SMK.DB:Get().savedRoutes) do
        local route = BuildDisplay(stored)
        routes[#routes + 1] = route
        byID[route.id] = route
        byName[route.normalizedName] = byName[route.normalizedName] or route
    end
    cachedRoutes, routeByID, routeByName, cacheDirty = routes, byID, byName, false
end

local function NotifyChanged()
    if changeHandler then changeHandler() end
end

function Store:InvalidateCache()
    cacheDirty = true
end

function Store:SetChangeHandler(callback)
    changeHandler = callback
end

function Store:GetAll()
    if cacheDirty then RebuildCache() end
    return cachedRoutes
end

function Store:GetByID(id)
    if cacheDirty then RebuildCache() end
    return routeByID[tonumber(id)]
end

function Store:GetByName(name)
    if cacheDirty then RebuildCache() end
    return routeByName[Util.Normalize(name)]
end

function Store:Add(values)
    if SMK.DB:IsReadOnly() then return nil, "READ_ONLY" end
    local route, errorMessage = self:Normalize(values)
    if not route then return nil, errorMessage end
    if self:GetByName(route.name) then return nil, "DUPLICATE_ROUTE_NAME" end
    local database = SMK.DB:Get()
    route.id = SMK.DB:NextRouteID()
    database.savedRoutes[#database.savedRoutes + 1] = route
    self:InvalidateCache()
    local display = self:GetByID(route.id)
    NotifyChanged()
    return display
end

function Store:Delete(route)
    if SMK.DB:IsReadOnly() then return 0, "READ_ONLY" end
    local id = tonumber(type(route) == "table" and route.id or route)
    if not id then return 0, "NOT_FOUND" end
    local routes = SMK.DB:Get().savedRoutes
    for index, stored in ipairs(routes) do
        if stored.id == id then
            table.remove(routes, index)
            self:InvalidateCache()
            NotifyChanged()
            return 1
        end
    end
    return 0, "NOT_FOUND"
end

--- 根据路线名称搜索；空筛选词返回按名称排序的全部路线。
function Store:Search(filter, limit)
    filter = Util.Normalize(filter)
    limit = math.max(0, math.floor(tonumber(limit) or 0))
    local matches = {}
    for _, route in ipairs(self:GetAll()) do
        local name = route.normalizedName
        local score = filter == "" and 0
            or name == filter and 0
            or name:sub(1, #filter) == filter and 1
            or name:find(filter, 1, true) and 2
        if score then
            matches[#matches + 1] = { entry = route, score = score, isSavedRoute = true }
        end
    end
    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.entry.normalizedName ~= b.entry.normalizedName then
            return a.entry.normalizedName < b.entry.normalizedName
        end
        return a.entry.id < b.entry.id
    end)
    for index = #matches, limit + 1, -1 do matches[index] = nil end
    return matches
end

SMK.RouteStore = Store
