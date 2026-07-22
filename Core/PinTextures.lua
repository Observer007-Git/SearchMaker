local _, SMK = ...

SMK.PinTextures = {
    { id = 1, atlas = "Ping_Map_Whole_OnMyWay" },
    { id = 2, atlas = "Ping_Map_Whole_Warning" },
    { id = 3, atlas = "Ping_Map_Whole_Danger" },
    { id = 4, atlas = "Ping_Map_Whole_Help" },
    { id = 5, atlas = "Ping_Map_Whole_Assist" },
    { id = 6, atlas = "VignetteEvent-SuperTracked" },
    { id = 7, atlas = "ElementalStorm-Lesser-Fire" },
    { id = 8, atlas = "MonsterEnemy" },
    { id = 9, atlas = "MonsterFriend" },
    { id = 10, atlas = "PlayerPartyBlip" },
    { id = 11, atlas = "vignettekillboss-SuperTracked" },
    { id = 12, atlas = "poi-traveldirections-arrow2" },
    { id = 13, atlas = "poi-door-up" },
    { id = 14, atlas = "poi-door-down" },
    { id = 15, atlas = "poi-door-left" },
    { id = 16, atlas = "poi-door-right" },
    { id = 17, atlas = "CrossedFlags" },
    { id = 18, atlas = "Professions_Tracking_Fish_Special" },
    { id = 19, atlas = "Map-MarkedDefeated" },
}

SMK.PinTextureByID = {}
for _, texture in ipairs(SMK.PinTextures) do
    SMK.PinTextureByID[texture.id] = texture
end
