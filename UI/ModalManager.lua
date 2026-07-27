local _, SMK = ...

local ModalManager = { dialogs = {} }

function ModalManager:Register(dialog)
    self.dialogs[#self.dialogs + 1] = dialog
end

function ModalManager:HideAll(except)
    for _, dialog in ipairs(self.dialogs) do
        if dialog ~= except and dialog.Hide then dialog:Hide() end
    end
end

function ModalManager:PrepareToShow(dialog)
    self:HideAll(dialog)
end

function ModalManager:IsMenuOpen()
    for _, dialog in ipairs(self.dialogs) do
        if dialog.IsMenuOpen and dialog:IsMenuOpen() then return true end
    end
    return false
end

function ModalManager:CloseTransientMenus(foci)
    for _, dialog in ipairs(self.dialogs) do
        if dialog.CloseTransientMenu then dialog:CloseTransientMenu(foci) end
    end
end

function ModalManager:ContainsMouseFocus(foci)
    if not foci or not DoesAncestryIncludeAny then return false end
    for _, dialog in ipairs(self.dialogs) do
        local frame = dialog.frame
        if frame and frame:IsShown() and DoesAncestryIncludeAny(frame, foci) then return true end
        if dialog.ContainsMouseFocus and dialog:ContainsMouseFocus(foci) then return true end
    end
    return false
end

SMK.ModalManager = ModalManager
