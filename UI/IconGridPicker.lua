local _, SMK = ...

local IconGridPicker = {}
IconGridPicker.__index = IconGridPicker

function IconGridPicker:Create(parent, options)
    options = options or {}
    local picker = setmetatable({
        entries = options.entries or {},
        buttons = {},
        selectedValue = options.selectedValue,
        enabled = true,
        onSelect = options.onSelect,
        getValue = options.getValue,
        applyIcon = options.applyIcon,
        getTooltip = options.getTooltip,
        showKind = options.showKind,
    }, self)
    local columns = options.columns or 5
    local cellSize = options.cellSize or 28
    local gap = options.gap or 4
    local columnGap = options.columnGap or gap
    local rowGap = options.rowGap or gap
    local padding = options.padding or 8
    local rows = math.ceil(#picker.entries / columns)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    picker.frame = frame
    frame:SetSize(
        options.width or padding * 2 + columns * cellSize + math.max(0, columns - 1) * columnGap,
        options.height or padding * 2 + rows * cellSize + math.max(0, rows - 1) * rowGap)
    frame:EnableMouse(true)
    frame:SetBackdrop(SMK.Config.resultBackdrop)
    frame:SetBackdropColor(0.04, 0.03, 0.02, options.alpha or 0.7)
    frame:SetBackdropBorderColor(unpack(SMK.Config.colors.panelBorder))

    for index, entry in ipairs(picker.entries) do
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(cellSize, cellSize)
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        button:SetPoint("TOPLEFT", padding + column * (cellSize + columnGap),
            -padding - row * (cellSize + rowGap))
        button.entry = entry
        button.value = picker.getValue and picker.getValue(entry) or entry.id
        button.selection = button:CreateTexture(nil, "BACKGROUND")
        button.selection:SetAllPoints(button)
        button.selection:SetColorTexture(unpack(SMK.Config.colors.gold))
        button.selection:SetAlpha(0.45)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        if picker.applyIcon then
            picker.applyIcon(button.icon, entry)
        else
            SMK.IconCatalog:Apply(button.icon, entry.id)
        end
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetColorTexture(1, 1, 1, 0.2)
        button:SetScript("OnClick", function()
            if picker.enabled and picker.onSelect then picker.onSelect(button.value) end
        end)
        button:SetScript("OnEnter", function()
            local selected = button.entry
            local tooltip = picker.getTooltip and picker.getTooltip(selected)
                or selected.atlas or selected.texture
            if not tooltip then return end
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip)
            if picker.showKind then
                GameTooltip:AddLine(selected.kind == "atlas"
                    and SMK.L.CUSTOM_ICON_ATLAS or SMK.L.CUSTOM_ICON_PATH,
                    0.75, 0.75, 0.75)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        picker.buttons[#picker.buttons + 1] = button
    end
    picker:Refresh()
    return picker
end

function IconGridPicker:SetSelected(value)
    self.selectedValue = value
    self:Refresh()
end

function IconGridPicker:SetEnabled(enabled)
    self.enabled = enabled == true
    self:Refresh()
end

function IconGridPicker:Refresh()
    for _, button in ipairs(self.buttons) do
        button:SetEnabled(self.enabled)
        button.icon:SetAlpha(self.enabled and 1 or 0.4)
        button.icon:SetDesaturated(not self.enabled)
        button.selection:SetShown(button.value == self.selectedValue)
    end
end

SMK.IconGridPicker = IconGridPicker
