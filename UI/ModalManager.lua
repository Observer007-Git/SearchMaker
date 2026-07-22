local _, SMK = ...

local ModalManager = { dialogs = {} }

function ModalManager:Register(dialog, menuKeys)
    self.dialogs[#self.dialogs + 1] = { dialog = dialog, menuKeys = menuKeys or {} }
end

function ModalManager:HideAll(except)
    for _, item in ipairs(self.dialogs) do
        if item.dialog ~= except and item.dialog.Hide then item.dialog:Hide() end
    end
end

function ModalManager:ShowOnly(dialog)
    self:HideAll(dialog)
end

function ModalManager:IsMenuOpen()
    for _, item in ipairs(self.dialogs) do
        for _, key in ipairs(item.menuKeys) do
            local menu = item.dialog[key]
            if menu and menu.IsMenuOpen and menu:IsMenuOpen() then return true end
        end
    end
    return false
end

function ModalManager:ContainsMouseFocus(foci)
    if not foci or not DoesAncestryIncludeAny then return false end
    for _, item in ipairs(self.dialogs) do
        local frame = item.dialog.frame
        if frame and frame:IsShown() and DoesAncestryIncludeAny(frame, foci) then return true end
    end
    return false
end

SMK.ModalManager = ModalManager
