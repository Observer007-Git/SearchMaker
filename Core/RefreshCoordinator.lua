local _, SMK = ...

local RefreshCoordinator = {}
RefreshCoordinator.__index = RefreshCoordinator

--- 创建刷新请求协调器。相邻请求会合并到下一帧执行一次。
-- @param flush function 接收合并后的 flags 表。
-- @param schedule function 调度函数，签名 schedule(callback)。
function RefreshCoordinator:New(flush, schedule)
    return setmetatable({
        flush = flush,
        schedule = schedule,
        pending = {},
        scheduled = false,
    }, self)
end

function RefreshCoordinator:Request(flags)
    for key, value in pairs(flags or {}) do
        if value then self.pending[key] = true end
    end
    if self.scheduled then return end
    self.scheduled = true
    self.schedule(function() self:Flush() end)
end

function RefreshCoordinator:Flush()
    if not self.scheduled and not next(self.pending) then return end
    local flags = self.pending
    self.pending = {}
    self.scheduled = false
    self.flush(flags)
end

SMK.RefreshCoordinator = RefreshCoordinator
