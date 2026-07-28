local _, SMK = ...

local Catalog = {
    all = {},
    byID = {},
}

local function Register(entry, expectedKind)
    local id = tonumber(entry and entry.id)
    assert(id and id % 1 == 0 and id ~= 0, "custom icon ID must be a non-zero integer")
    assert(not Catalog.byID[id], "duplicate custom icon ID: " .. id)
    if expectedKind == "atlas" then
        assert(id > 0 and entry.atlas and not entry.texture,
            "Atlas custom icon IDs must be positive")
    else
        assert(id < 0 and entry.texture and not entry.atlas,
            "path custom icon IDs must be negative")
    end
    entry.kind = expectedKind
    Catalog.byID[id] = entry
    Catalog.all[#Catalog.all + 1] = entry
end

for _, entry in ipairs(SMK.AtlasTextures or {}) do Register(entry, "atlas") end
for _, entry in ipairs(SMK.PathTextures or {}) do Register(entry, "texture") end

function Catalog:Get(iconID)
    return self.byID[tonumber(iconID)]
end

function Catalog:GetNote(entryOrID)
    local entry = type(entryOrID) == "table" and entryOrID or self:Get(entryOrID)
    local notes = SMK.L and SMK.L.ICON_NOTES
    return entry and notes and notes[entry.note] or nil
end

function Catalog:Apply(texture, iconID)
    local entry = self:Get(iconID)
    if not texture or not entry then return false end
    if entry.atlas then
        texture:SetAtlas(entry.atlas, false)
    else
        texture:SetTexture(entry.texture)
        texture:SetTexCoord(0, 1, 0, 1)
    end
    return true
end

SMK.IconCatalog = Catalog
SMK.DefaultCustomIconID = 29
