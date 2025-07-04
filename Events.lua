function Bagzen:BAG_UPDATE()
    Bagzen:SaveBag(arg1)
    Bagzen:UpdateBag(arg1)
end

function Bagzen:BAG_UPDATE_COOLDOWN()
    Bagzen:UpdateSlots(BagzenBagFrame)
end

function Bagzen:PLAYER_MONEY()
    Bagzen:SavePlayerMoney()
end

function Bagzen:PLAYER_LOGIN()
    Bagzen:SaveBag(-2)
    for i=0, 4 do
        Bagzen:SaveBag(i)
    end
    Bagzen:SavePlayerMoney()
    Bagzen:UpdateSlots(BagzenBagFrame)  -- Container.lua
    Bagzen:RePosition(BagzenBagFrame)
end

function Bagzen:MAIL_CLOSED()
    if Bagzen.settings.global.bagframe.close_mail then
        BagzenBagFrame:Hide()
    end
end

function Bagzen:MAIL_SHOW()
    if Bagzen.settings.global.bagframe.open_mail then
        BagzenBagFrame:Show()
    end
end

function Bagzen:MERCHANT_CLOSED()
    if Bagzen.settings.global.bagframe.close_vendor then
        BagzenBagFrame:Hide()
    end
end

function Bagzen:MERCHANT_SHOW()
    if Bagzen.settings.global.general.auto_repair then
        Bagzen:RepairItems()
    end
    if Bagzen.settings.global.general.auto_sell then
        Bagzen:SellScrap()
        Bagzen:UpdateSlots(BagzenBagFrame)
    end
    if Bagzen.settings.global.bagframe.open_vendor then
        BagzenBagFrame:Show()
    end
end

function Bagzen:PLAYER_ENTERING_WORLD()
    -- Bagzen:Print("PLAYER_ENTERING_WORLD")
    Bagzen:UpdateSlots(BagzenBagFrame)  -- Container.lua
end

function Bagzen:OnEnable()
    Bagzen:RegisterEvent("BAG_UPDATE")
    Bagzen:RegisterEvent("BAG_UPDATE_COOLDOWN")
    Bagzen:RegisterEvent("MAIL_SHOW")
    Bagzen:RegisterEvent("MAIL_CLOSED")
    Bagzen:RegisterEvent("MERCHANT_CLOSED")
    Bagzen:RegisterEvent("MERCHANT_SHOW")
    Bagzen:RegisterEvent("PLAYER_MONEY")
    Bagzen:RegisterEvent("PLAYER_LOGIN")
    Bagzen:RegisterEvent("PLAYER_ENTERING_WORLD")
end
