local _, SMK = ...

-- id 是地点存储和共享格式中的稳定索引；调整显示顺序时不得修改已有 id。
SMK.PinTextures = {
    { id = 1, atlas = "MonsterEnemy" },
    { id = 2, atlas = "MonsterFriend" },
    { id = 3, atlas = "PlayerPartyBlip" },
    { id = 4, atlas = "Ping_Map_Whole_Assist" },
    { id = 5, atlas = "VignetteEvent-SuperTracked" },
    { id = 6, atlas = "groupfinder-icon-class-color-deathknight" },
    { id = 7, atlas = "groupfinder-icon-class-color-priest" },
    { id = 8, atlas = "MiniMap-DeadArrow" },
    { id = 9, atlas = "vignettekillboss-SuperTracked" },
    { id = 10, atlas = "poi-traveldirections-arrow2" },
    { id = 11, atlas = "poi-door-up" },
    { id = 12, atlas = "poi-door-down" },
    { id = 13, atlas = "poi-door-left" },
    { id = 14, atlas = "poi-door-right" },
    { id = 15, atlas = "CaveUnderground-Down" },
    { id = 16, atlas = "CaveUnderground-Up" },
    { id = 17, atlas = "friendslist-recentallies-Pin" },
    { id = 18, atlas = "friendslist-recentallies-Pin-yellow" },
    { id = 19, atlas = "XMarksTheSpot" },
    { id = 20, atlas = "Ping_Map_Whole_OnMyWay" },
}

SMK.DefaultPinTextureID = SMK.PinTextures[1].id
SMK.PinTextureByID = {}
SMK.PinTextureIDByAtlas = {}
for _, texture in ipairs(SMK.PinTextures) do
    SMK.PinTextureByID[texture.id] = texture
    SMK.PinTextureIDByAtlas[texture.atlas] = texture.id
end
