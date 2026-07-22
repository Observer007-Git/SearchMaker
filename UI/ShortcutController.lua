local _, SMK = ...

local ShortcutController = {}
ShortcutController.__index = ShortcutController

function ShortcutController:New(button, callbacks)
    local controller = setmetatable({ button = button, callbacks = callbacks or {} }, self)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function()
        if button.isCapturing then controller:StopCapture() else controller:StartCapture() end
    end)
    button:SetScript("OnKeyDown", function(_, key)
        if not button.isCapturing then return end
        key = GetConvertedKeyOrButton(key)
        if not IsKeyPressIgnoredForBinding(key) then
            controller:Apply(CreateKeyChordStringUsingMetaKeyState(key))
        end
    end)
    button:SetScript("OnEnter", function(owner)
        local key = GetBindingKey(SMK.Config.shortcutAction)
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        GameTooltip:SetText(SMK.L.SHORTCUT_TOOLTIP_TITLE)
        GameTooltip:AddLine(string.format(SMK.L.SHORTCUT_TOOLTIP_CURRENT,
            key and GetBindingText(key) or SMK.L.NO_KEY_BOUND), 1, 1, 1)
        GameTooltip:AddLine(SMK.L.SHORTCUT_TOOLTIP_HINT, 0.35, 0.85, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    controller:StopCapture()
    return controller
end

function ShortcutController:NotifyChanged()
    if self.callbacks.onChanged then self.callbacks.onChanged() end
end

function ShortcutController:StopCapture()
    local button = self.button
    button.isCapturing = false
    if not InCombatLockdown() and button.SetPropagateKeyboardInput then
        button:SetPropagateKeyboardInput(true)
    end
    button:EnableKeyboard(false)
    button:SetText(SMK.L.SHORTCUT)
    self:NotifyChanged()
end

function ShortcutController:StartCapture()
    if InCombatLockdown() then return SMK:Print(SMK.L.KEY_BIND_IN_COMBAT) end
    self.button.isCapturing = true
    self.button:SetText(SMK.L.CAPTURE_SHORTCUT)
    GameTooltip_Hide()
    self.button:EnableKeyboard(true)
    if self.button.SetPropagateKeyboardInput then
        self.button:SetPropagateKeyboardInput(false)
    end
end

function ShortcutController:Apply(newKey)
    local action = GetBindingAction(newKey)
    if action and action ~= "" and action ~= SMK.Config.shortcutAction then
        self:StopCapture()
        return SMK:Print(string.format(SMK.L.KEY_ALREADY_BOUND,
            GetBindingText(newKey), GetBindingName(action)))
    end
    local old1, old2 = GetBindingKey(SMK.Config.shortcutAction)
    if old1 then SetBinding(old1) end
    if old2 then SetBinding(old2) end
    if not SetBinding(newKey, SMK.Config.shortcutAction) then
        if old1 then SetBinding(old1, SMK.Config.shortcutAction) end
        if old2 then SetBinding(old2, SMK.Config.shortcutAction) end
        self:StopCapture()
        return SMK:Print(SMK.L.KEY_BIND_FAILED)
    end
    SaveBindings(GetCurrentBindingSet())
    self:StopCapture()
    SMK:Print(string.format(SMK.L.KEY_BIND_UPDATED, GetBindingText(newKey)))
end

SMK.ShortcutController = ShortcutController
