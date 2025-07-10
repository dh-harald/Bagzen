function Bagzen:BAG_UPDATE()
    if arg1 == -1 or arg1 > 4
    then
        -- sometimes it's called for bankframe (5)
        return -- sanity check
    end
    local full = false
    for _, bag in pairs(BagzenBagFrame.Bags) do
        if bag ~= KEYRING_CONTAINER then
            local frame = getglobal("BagzenBagFrameBagSlotsFrame" .. bag)
            local numslots = GetContainerNumSlots(bag) or 0
            if frame.Slots ~= numslots then
                full = true
                break
            end
        end
    end
    if full == true then
        -- layout changed
        Bagzen:ContainerUpdate(BagzenBagFrame, Bagzen.realmname, Bagzen.unitname)
    else
        Bagzen:BagSlotUpdate(BagzenBagFrame, arg1)
        Bagzen:ContainerItemUpdate(BagzenBagFrame, arg1)
    end
end

function Bagzen:BAG_UPDATE_COOLDOWN()
    Bagzen:ContainerUpdate(BagzenBagFrame, Bagzen.realmname, Bagzen.unitname)
end

function Bagzen:BANKFRAME_CLOSED()
    BagzenBankFrame.Virtual = true
    BagzenBankFrame:Hide()
end

function Bagzen:BANKFRAME_OPENED()
    BagzenBankFrame.Virtual = false
    Bagzen:ContainerUpdate(BagzenBankFrame, Bagzen.realmname, Bagzen.unitname)
    BagzenBankFrame:Show()
end

function Bagzen:MAIL_CLOSED()
    if Bagzen.settings.global.bagframe.close_mail then
        BagzenBagFrame:Hide()
    end
end

function Bagzen:MAIL_INBOX_UPDATE()
    Bagzen:ScanMails()
end

function Bagzen:MAIL_SHOW()
    if Bagzen.settings.global.bagframe.open_mail then
        BagzenBagFrame:Show()
    end
end

function Bagzen:MERCHANT_SHOW()
    if Bagzen.settings.global.general.auto_repair then
        Bagzen:RepairItems()
    end
    if Bagzen.settings.global.general.auto_sell then
        Bagzen:SellScrap()
        Bagzen:ContainerUpdate(BagzenBagFrame, Bagzen.realmname, Bagzen.unitname)
    end
    if Bagzen.settings.global.bagframe.open_vendor then
        BagzenBagFrame:Show()
    end
end

function Bagzen:PLAYER_LOGIN()
    Bagzen:ContainerInit(BagzenBagFrame, {0, 1, 2, 3, 4, KEYRING_CONTAINER})
    Bagzen:ContainerInit(BagzenBankFrame, {-1, 5, 6, 7, 8, 9, 10})
    Bagzen:ContainerUpdate(BagzenBagFrame, Bagzen.realmname, Bagzen.unitname)
    Bagzen:ContainerUpdate(BagzenBankFrame, Bagzen.realmname, Bagzen.unitname)
    Bagzen:ContainerReposition(BagzenBagFrame)
    Bagzen:ContainerReposition(BagzenBankFrame)
    Bagzen:ItemCacheInit()
    Bagzen:MoneyFrameUpdate(BagzenBagFrameMoneyFrame, GetMoney())
    Bagzen:MoneyFrameUpdate(BagzenBankFrameMoneyFrame, GetMoney())
end

function Bagzen:PLAYER_MONEY()
    Bagzen:MoneyFrameUpdate(BagzenBagFrameMoneyFrame, GetMoney())
    Bagzen:MoneyFrameUpdate(BagzenBankFrameMoneyFrame, GetMoney())
    if BagzenBankFrame:IsShown() and BagzenBankFrame.Virtual == false then
        -- bag puchased
        Bagzen:ContainerUpdate(BagzenBankFrame, Bagzen.realmname, Bagzen.unitname)
    end
end

function Bagzen:PLAYERBANKSLOTS_CHANGED()
    Bagzen:ContainerUpdate(BagzenBankFrame, Bagzen.realmname, Bagzen.unitname)
end

function Bagzen:OnEnable()
    Bagzen:RegisterEvent("BAG_UPDATE")
    Bagzen:RegisterEvent("BAG_UPDATE_COOLDOWN")
    Bagzen:RegisterEvent("BANKFRAME_CLOSED")
    Bagzen:RegisterEvent("BANKFRAME_OPENED")
    Bagzen:RegisterEvent("MAIL_CLOSED")
    Bagzen:RegisterEvent("MAIL_INBOX_UPDATE")
    Bagzen:RegisterEvent("MAIL_SHOW")
    Bagzen:RegisterEvent("MERCHANT_SHOW")
    Bagzen:RegisterEvent("PLAYER_LOGIN")
    Bagzen:RegisterEvent("PLAYER_MONEY")
    Bagzen:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
end
