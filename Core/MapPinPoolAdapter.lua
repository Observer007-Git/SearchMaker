local _, SMK = ...

local Adapter = {}

--- 将自定义 Pin 池注册到暴雪 MapCanvas。
-- 对 map.pinPools 等内部字段的访问集中在此兼容边界中。
function Adapter:Register(map, template, pinMixin, enableMouse)
    if not map or not map.GetCanvas or type(map.pinPools) ~= "table"
        or type(template) ~= "string" or type(pinMixin) ~= "table" then
        return false
    end
    if map.pinPools[template] then return true end

    local pool = CreateUnsecuredRegionPoolInstance
        and CreateUnsecuredRegionPoolInstance(template) or CreateFramePool("FRAME")
    pool.parent = map:GetCanvas()
    pool.createFunc = function()
        local pin = CreateFrame("Frame", nil, map:GetCanvas())
        pin.isSearchMakerMapPin = true
        pin:EnableMouse(enableMouse == true)
        return Mixin(pin, pinMixin)
    end
    pool.resetFunc = function(_, pin)
        pin:Hide()
        pin:ClearAllPoints()
        pin:OnReleased()
        pin.pinTemplate = nil
        pin.owningMap = nil
    end
    pool.creationFunc = pool.createFunc
    pool.resetterFunc = pool.resetFunc
    map.pinPools[template] = pool
    return true
end

SMK.MapPinPoolAdapter = Adapter
