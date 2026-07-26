local _, SMK = ...

local PanelController = {}
PanelController.__index = PanelController

function PanelController:New(searchBar)
    return setmetatable({ searchBar = searchBar }, self)
end

function PanelController:AttachPanel(panel)
    self.panel = panel
end

function PanelController:SetExpanded(expanded)
    if not self.panel then return end
    local searchBar = self.searchBar
    searchBar.suppressPanelHidden = not expanded
    self.panel:SetExpanded(expanded)
    searchBar.suppressPanelHidden = false
    self:UpdateOutsideListener()
end

function PanelController:Open()
    self:SetExpanded(true)
    self.searchBar:UpdateResults()
end

function PanelController:Close()
    local searchBar = self.searchBar
    searchBar.suppressPanelHidden = true
    if self.panel then self.panel:SetExpanded(false) end
    searchBar.suppressPanelHidden = false
    searchBar:HideResults()
    searchBar:CancelPendingSearch()
    searchBar:SetQuery("")
    searchBar.box:ClearFocus()
    self:UpdateOutsideListener()
end

function PanelController:OnPanelHidden()
    if not self.searchBar.suppressPanelHidden then self:Close() end
end

function PanelController:UpdateOutsideListener()
    local results = self.searchBar.searchResults
    local needs = (self.panel and self.panel:IsExpanded()) or (results and results:IsShown())
    local listener = self.searchBar.outsideListener
    if not listener then return end
    if needs then
        listener:RegisterEvent("GLOBAL_MOUSE_DOWN")
    else
        listener:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    end
end

function PanelController:HandleGlobalMouseDown(button)
    local searchBar = self.searchBar
    local results = searchBar.searchResults
    if results:IsContextMenuOpen() or SMK.ModalManager:IsMenuOpen() then return end
    local panelExpanded = self.panel and self.panel:IsExpanded()
    if not panelExpanded and not results:IsShown() then return end
    local foci = GetMouseFoci()
    if self.panel and self.panel:ContainsMouseFocus(foci)
        or SMK.ModalManager:ContainsMouseFocus(foci)
        or DoesAncestryIncludeAny(searchBar.results, foci) then return end
    if panelExpanded then
        if button == "RightButton" and DoesAncestryIncludeAny(searchBar.box, foci) then return end
    elseif DoesAncestryIncludeAny(searchBar.bar, foci) then
        return
    end
    self:Close()
end

SMK.PanelController = PanelController
