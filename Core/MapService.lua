local _, SMK = ...

local Map = {}
local mapNameCache = {}

function Map:GetCursorScreenPosition()
    local x, y = GetCursorPosition()
    if not x or not y then return end
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not scale or scale <= 0 then scale = 1 end
    return x / scale, y / scale
end

--- 获取玩家当前区域的地图 ID。
-- @return number|nil 地图 ID。
function Map:GetPlayerMapID()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

--- 获取当前相关的地图 ID：已打开的世界地图，或玩家当前区域。
-- @return number|nil 地图 ID。
function Map:GetContextMapID()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        return WorldMapFrame:GetMapID()
    end
    return self:GetPlayerMapID()
end

--- 对 C_Map.GetMapInfo 的封装，带 nil 安全保护。
-- @param mapID number
-- @return table|nil 地图信息。
function Map:GetMapInfo(mapID)
    return mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
end

--- 获取可读的地图名称，回退为本地化的"地图 {id}"字符串。
-- @param mapID number
-- @return string
function Map:GetMapName(mapID)
    if mapNameCache[mapID] then return mapNameCache[mapID] end
    local info = self:GetMapInfo(mapID)
    local name = info and info.name
        or (mapID and string.format(SMK.L.MAP_FALLBACK, tostring(mapID)) or SMK.L.UNKNOWN_MAP)
    if mapID and info and info.name then mapNameCache[mapID] = name end
    return name
end

--- 获取玩家在指定地图上的当前位置，坐标范围 0-100。
-- @param mapID number
-- @return number, number|nil x, y（0-100）。
function Map:GetPlayerCoordinates(mapID)
    if not mapID or not C_Map or not C_Map.GetPlayerMapPosition then
        return
    end
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return
    end
    local x, y = position.x, position.y
    if position.GetXY then
        x, y = position:GetXY()
    end
    if type(x) == "number" and type(y) == "number" then
        return x * 100, y * 100
    end
end

--- 将鼠标光标在屏幕上的位置转换为地图坐标（0-100）。
-- 优先尝试 WorldMapFrame:GetNormalizedCursorPosition()，
-- 然后回退到 ScrollContainer 边界与 GetCursorPosition() 的计算。
-- @return number, number|nil x, y（0-100）。
function Map:GetCursorMapCoordinates()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        return
    end
    -- Prefer API method if available
    local nx, ny
    if WorldMapFrame.GetNormalizedCursorPosition then
        nx, ny = WorldMapFrame:GetNormalizedCursorPosition()
    end
    if nx and ny then
        if nx < 0 or nx > 1 or ny < 0 or ny > 1 then return end
        return nx * 100, ny * 100
    end
    -- Fallback: ScrollContainer bounds vs cursor position
    local container = WorldMapFrame.ScrollContainer
    if not container then return end
    local left, right, top, bottom = container:GetLeft(), container:GetRight(), container:GetTop(), container:GetBottom()
    if not (left and right and top and bottom) or right - left == 0 or top - bottom == 0 then
        return
    end
    local cursorX, cursorY = self:GetCursorScreenPosition()
    if not cursorX or not cursorY then
        return
    end
    nx = (cursorX - left) / (right - left)
    ny = (cursorY - bottom) / (top - bottom)
    if nx < 0 or nx > 1 or ny < 0 or ny > 1 then return end
    return nx * 100, ny * 100
end


--- 移除用户放置的路径点并关闭超级追踪。
function Map:ClearWaypoint()
    C_Map.ClearUserWaypoint()
    if C_SuperTrack then
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    end
end

local function GetWaypointSnapshot()
    if not C_Map or not C_Map.GetUserWaypoint then return end
    local point = C_Map.GetUserWaypoint()
    if not point or not point.position then return end
    return {
        mapID = point.uiMapID,
        x = point.position.x,
        y = point.position.y,
        superTracked = C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint
            and C_SuperTrack.IsSuperTrackingUserWaypoint() or false,
    }
end

local function IsWaypointAt(snapshot)
    local current = GetWaypointSnapshot()
    return current and snapshot and current.mapID == snapshot.mapID
        and math.abs(current.x - snapshot.x) < 0.0001
        and math.abs(current.y - snapshot.y) < 0.0001
end

--- 将游戏路径点设置到指定坐标并开启超级追踪。
-- @param entry table 必须包含 mapID, x（0-100）, y（0-100）。
-- @return boolean, string|nil 是否成功，错误消息。
function Map:SetWaypoint(entry)
    if not C_Map or not C_Map.SetUserWaypoint or not UiMapPoint
        or not UiMapPoint.CreateFromCoordinates then
        return false, SMK.L.ERROR_NO_CLIENT_SUPPORT
    end
    if type(entry) ~= "table" or type(entry.mapID) ~= "number"
        or type(entry.x) ~= "number" or entry.x < 0 or entry.x > 100
        or type(entry.y) ~= "number" or entry.y < 0 or entry.y > 100 then
        return false, SMK.L.ERROR_INVALID_COORDINATES
    end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(entry.mapID) then
        return false, SMK.L.ERROR_MAP_NOT_SUPPORTED
    end
    local point = UiMapPoint.CreateFromCoordinates(entry.mapID, entry.x / 100, entry.y / 100)
    C_Map.SetUserWaypoint(point)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
end

--- 创建编辑器预览路径点，并保存玩家原有路径点用于关闭时恢复。
function Map:BeginTemporaryWaypoint(entry)
    self:ClearTemporaryWaypoint()
    local previous = GetWaypointSnapshot()
    local marked, message = self:SetWaypoint(entry)
    if not marked then return false, message end
    self.temporaryWaypoint = {
        previous = previous,
        mapID = entry.mapID,
        x = entry.x / 100,
        y = entry.y / 100,
    }
    return true
end

--- 仅当当前路径点仍是插件预览点时恢复原路径点。
function Map:ClearTemporaryWaypoint()
    local temporary = self.temporaryWaypoint
    self.temporaryWaypoint = nil
    if not temporary or not IsWaypointAt(temporary) then return end
    if temporary.previous and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(
            temporary.previous.mapID, temporary.previous.x, temporary.previous.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(temporary.previous.superTracked)
        end
    else
        self:ClearWaypoint()
    end
end

--- 打开世界地图并跳转到指定地图 ID。
-- 如果世界地图未打开，先打开它。
-- @param mapID number
function Map:OpenMap(mapID)
    if not WorldMapFrame then return false end
    local info = self:GetMapInfo(mapID)
    if not info then return false end
    if not WorldMapFrame:IsShown() then
        local opened
        if C_Map and C_Map.OpenWorldMap then
            opened = pcall(C_Map.OpenWorldMap, mapID)
        else
            opened = pcall(WorldMapFrame.Show, WorldMapFrame)
        end
        if not opened or not WorldMapFrame:IsShown() then return false end
    end
    if WorldMapFrame.SetMapID and WorldMapFrame:GetMapID() ~= mapID then
        local ok = pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
        return ok
    end
    return true
end


SMK.Map = Map
