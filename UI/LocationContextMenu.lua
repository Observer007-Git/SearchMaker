local _, SMK = ...

local ContextMenu = {}

function ContextMenu:Initialize(callbacks)
    self.callbacks = callbacks or {}
end

function ContextMenu:Open(entry, owner)
    if type(entry) ~= "table" or entry.isMapPortal then return end
    GameTooltip_Hide()
    self.menu = MenuUtil.CreateContextMenu(owner, function(_, root)
        if entry.isCoordinateResult then
            root:CreateButton(SMK.L.MENU_COPY_COORDINATES, function()
                self.callbacks.onCopy(entry)
            end)
            root:CreateButton(SMK.L.MENU_ADD_TEMP_PIN, function()
                self.callbacks.onTemporaryPin(entry)
            end)
            root:CreateButton(SMK.L.MENU_ADD_ROUTE, function()
                self.callbacks.onRoute(entry)
            end)
            return
        end
        if entry.isExternal then
            root:CreateButton(SMK.L.MENU_FAVORITE, function()
                self.callbacks.onFavorite(entry)
            end)
        end
        root:CreateButton(SMK.L.MENU_COPY_COORDINATES, function()
            self.callbacks.onCopy(entry)
        end)
        root:CreateButton(SMK.L.MENU_SHARE_COORDINATE, function()
            self.callbacks.onShare(entry)
        end)
        if not entry.isExternal then
            root:CreateButton(SMK.L.MENU_EDIT_COORDINATE, function()
                self.callbacks.onEdit(entry)
            end)
            root:CreateButton(SMK.L.MENU_DELETE_COORDINATE, function()
                self.callbacks.onDelete(entry)
            end)
        end
        root:CreateButton(SMK.L.MENU_ADD_ROUTE, function()
            self.callbacks.onRoute(entry)
        end)
    end)
end

function ContextMenu:IsShown()
    return self.menu and self.menu.IsShown and self.menu:IsShown() or false
end

SMK.LocationContextMenu = ContextMenu
