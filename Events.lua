function Bagzen:BAG_CLOSED()
    if arg1 > 0 and arg1< 5 then
        --- bag
        Bagzen:BagSlotUpdate(BagzenBagFrame, arg1)
        Bagzen:ContainerItemUpdate(BagzenBagFrame, arg1)
    elseif arg1 >= 5 then
        --- bank
        Bagzen:BagSlotUpdate(BagzenBankFrame, arg1)
        Bagzen:ContainerItemUpdate(BagzenBankFrame, arg1)
    end
end

function Bagzen:BAG_UPDATE()
    local _G = _G or getfenv()
    -- TODO keyring
    if (arg1 == KEYRING_CONTAINER) or (arg1 < -1) or (arg1 > 10)
    then
        -- sometimes it's called for bankframe (5) when it's not open
        -- on WOTLK, looks triggered for extra bagslots,
        -- on WOTLK, triggering (-4) which I don't know, what it means
        return -- sanity check
    end

    local parent = nil
    if arg1 >= 0 and arg1 < 5 then
        parent = _G["BagzenBagFrame"]
    elseif arg1 == -1 or arg1 >= 5 then
        parent = _G["BagzenBankFrame"]
        if parent.Virtual == true then
            return -- sanity check
        end
    end

    local full = false
    for _, bag in pairs(parent.Bags) do
        if bag ~= KEYRING_CONTAINER then
            local frame = _G[parent:GetName() .. "BagSlotsFrame" .. bag]
            local numslots = GetContainerNumSlots(bag) or 0
            if frame.Slots ~= numslots then
                full = true
                break
            end
        end
    end

    if full == true then
        -- layout changed
        Bagzen:ContainerUpdate(parent, Bagzen.realmname, Bagzen.unitname)
    else
        Bagzen:BagSlotUpdate(parent, arg1)
        Bagzen:ContainerItemUpdate(parent, arg1)
    end
end

function Bagzen:BAG_UPDATE_COOLDOWN()
    Bagzen:ContainerUpdate(BagzenBagFrame, Bagzen.realmname, Bagzen.unitname)
end

function Bagzen:BANKFRAME_CLOSED()
    BagzenBankFrame.Real = false
    BagzenBankFrame:Hide()
    Bagzen:ContainerUpdate(BagzenBankFrame, Bagzen.realmname, Bagzen.unitname)
end

function Bagzen:BANKFRAME_OPENED()
    BagzenBankFrame.Real = true
    Bagzen:ContainerUpdate(BagzenBankFrame, Bagzen.realmname, Bagzen.unitname)
    BagzenBankFrame:Show()
end

function Bagzen:ITEM_LOCK_CHANGED()
    local _G = _G or getfenv()
    local section = nil

    if Bagzen.IsWOTLK then
        if arg1 == KEYRING_CONTAINER then return end -- sanity check
        if arg1 >= 0 and arg1 < 5 then
            section = "bagframe"
        elseif arg1 >= 5 or arg1 == -1 then
            section = "bankframe"
        end

        local frame = Bagzen.ContainerFrames["Live"][section][arg1][arg2]
        if frame ~= nil and frame:IsShown() then
            local _, _, locked = GetContainerItemInfo(arg1, arg2)
            -- frame:SetItemButtonDesaturated(locked or 0)
            _G[frame:GetName() .. "IconTexture"]:SetDesaturated(locked or 0)
        end
    else
        for _, section in pairs(Bagzen.ContainerFrames["Live"]) do
            for bag, data in pairs(section) do
                if type(bag) == "number" and bag ~= KEYRING_CONTAINER then
                    for slot, frame in pairs(data) do
                        if frame and frame:IsShown() then
                            local _, _, locked = GetContainerItemInfo(bag, slot)
                            _G[frame:GetName() .. "IconTexture"]:SetDesaturated(locked or 0)
                        end
                    end
                end
            end
        end
    end
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
    Bagzen:ItemCacheInit()
    Bagzen:CharactersFrameInit()
    Bagzen:ContainerInit(BagzenBagFrame, {0, 1, 2, 3, 4, KEYRING_CONTAINER})
    Bagzen:ContainerInit(BagzenBankFrame, {-1, 5, 6, 7, 8, 9, 10})
    Bagzen:ContainerUpdate(BagzenBagFrame, Bagzen.realmname, Bagzen.unitname)
    Bagzen:ContainerUpdate(BagzenBankFrame, Bagzen.realmname, Bagzen.unitname)
    Bagzen:CharactersFrameUpdate(BagzenBagFrame)
    Bagzen:CharactersFrameUpdate(BagzenBankFrame)
    Bagzen:ContainerReposition(BagzenBagFrame)
    Bagzen:ContainerReposition(BagzenBankFrame)
    local money = GetMoney()
    Bagzen:MoneyFrameUpdate(BagzenBagFrameMoneyFrame, money)
    Bagzen:MoneyFrameUpdate(BagzenBankFrameMoneyFrame, money)
    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].money = money
end

function Bagzen:PLAYER_MONEY()
    local money = GetMoney()
    Bagzen:MoneyFrameUpdate(BagzenBagFrameMoneyFrame, money)
    Bagzen:MoneyFrameUpdate(BagzenBankFrameMoneyFrame, money)
    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].money = money
    if BagzenBankFrame:IsShown() and BagzenBankFrame.Virtual == false then
        -- bag puchased
        Bagzen:ContainerUpdate(BagzenBankFrame, Bagzen.realmname, Bagzen.unitname)
    end
end

function Bagzen:PLAYERBANKSLOTS_CHANGED()
    Bagzen:ContainerUpdate(BagzenBankFrame, Bagzen.realmname, Bagzen.unitname)
end

function Bagzen:OnEnable()
    Bagzen:RegisterEvent("BAG_CLOSED")
    Bagzen:RegisterEvent("BAG_UPDATE")
    Bagzen:RegisterEvent("BAG_UPDATE_COOLDOWN")
    Bagzen:RegisterEvent("BANKFRAME_CLOSED")
    Bagzen:RegisterEvent("BANKFRAME_OPENED")
    Bagzen:RegisterEvent("ITEM_LOCK_CHANGED")
    Bagzen:RegisterEvent("MAIL_CLOSED")
    Bagzen:RegisterEvent("MAIL_INBOX_UPDATE")
    Bagzen:RegisterEvent("MAIL_SHOW")
    Bagzen:RegisterEvent("MERCHANT_SHOW")
    Bagzen:RegisterEvent("PLAYER_MONEY")
    Bagzen:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    -- not triggered on WOTLK client
    Bagzen:PLAYER_LOGIN()
end
