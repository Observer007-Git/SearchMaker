local _, SMK = ...

SMK.PinTextures = {
    { id = 1, atlas = "Ping_Map_Whole_OnMyWay" },
    { id = 2, atlas = "Ping_Map_Whole_Warning" },
    { id = 3, atlas = "Ping_Map_Whole_Danger" },
    { id = 4, atlas = "Ping_Map_Whole_Help" },
    { id = 5, atlas = "Ping_Map_Whole_Assist" },
}

SMK.PinTextureByID = {}
for _, texture in ipairs(SMK.PinTextures) do
    SMK.PinTextureByID[texture.id] = texture
end
