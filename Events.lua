-- frame for delayed init
Bagzen.InitFrame = Bagzen.InitFrame or CreateFrame("Frame", "BagzenInitFrame")
Bagzen.InitFrame.delay = 0.1
Bagzen.InitFrame.finished = false
Bagzen.InitFrame.Queue = {
    [1] = {"PLAYER_LOGIN"}
}
Bagzen.InitFrame:Hide()
Bagzen.InitFrame:SetScript("OnUpdate", function()
    Bagzen:InitFrameOnUpdate(this)
end)

function Bagzen:BAG_CLOSED()
    -- remove bag from database
    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags[arg1] = nil
    if arg1 > 0 and arg1 < 5 then
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
    -- delay until init completed
    if Bagzen.InitFrame.finished == false then
        table.insert(Bagzen.InitFrame.Queue, {"BAG_UPDATE", arg1})
        return
    end
    local _G = _G or getfenv()
    if (arg1 < KEYRING_CONTAINER) or (arg1 > 10)
    then
        -- sometimes it's called for bankframe (5) when it's not open
        -- on WOTLK, looks triggered for extra bagslots,
        -- on WOTLK, triggering (-4) which I don't know, what it means
        return -- sanity check
    end

    local parent = nil
    if arg1 == KEYRING_CONTAINER or arg1 >= 0 and arg1 < 5 then
        parent = _G["BagzenBagFrame"]
    elseif arg1 == -1 or arg1 >= 5 then
        parent = _G["BagzenBankFrame"]
        if parent.Virtual == true then
            return -- sanity check
        end
    end

    local full = false
    for _, bag in pairs(parent.Bags) do
        local frame = _G[parent:GetName() .. "BagSlotsFrame" .. bag]
        local numslots
        if bag == KEYRING_CONTAINER then
            numslots = GetKeyRingSize() or 0
        else
            numslots = GetContainerNumSlots(bag) or 0
        end
        if frame.Slots ~= numslots then
            full = true
            break
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
    -- delay until init completed
    if Bagzen.InitFrame.finished == false then
        table.insert(Bagzen.InitFrame.Queue, {"BAG_UPDATE_COOLDOWN"})
        return
    end
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
    local parent = nil

    if Bagzen.IsWOTLK then
        local container = false
        if arg1 >= ContainerIDToInventoryID(1) and arg1 <= ContainerIDToInventoryID(4) then
            arg1 = arg1 - ContainerIDToInventoryID(1) + 1
            container = true
        elseif arg1 == -1 and arg2 > 28 then
            arg1 = arg2 - 28 + NUM_BAG_SLOTS
            arg2 = nil
            container = true
        end
        if arg1 == KEYRING_CONTAINER or arg1 >= 0 and arg1 < 5 then
            section = "bagframe"
            parent = "BagzenBagFrame"
        elseif arg1 >= 5 or arg1 == -1 then
            section = "bankframe"
            parent = "BagzenBankFrame"
        end

        local frame
        if Bagzen.ContainerFrames["Live"][section][arg1] ~= nil then
            if container then
                frame = _G[parent .. "BagSlotsFrame" .. arg1]
            else
                frame = Bagzen.ContainerFrames["Live"][section][arg1][arg2]
            end
        end
        if frame ~= nil and frame:IsShown() then
            local locked
            if container then
                locked = IsInventoryItemLocked(ContainerIDToInventoryID(arg1))
            else
                _, _, locked = GetContainerItemInfo(arg1, arg2)
            end
            _G[frame:GetName() .. "IconTexture"]:SetDesaturated(locked or 0)
        end
    else
        for sname, section in pairs(Bagzen.ContainerFrames["Live"]) do
            local parent = nil
            if sname == "bagframe" then
                parent = "BagzenBagFrame"
            elseif sname == "bankframe" then
                parent = "BagzenBankFrame"
            end
            for bag, data in pairs(section) do
                if type(bag) == "number" then
                    -- bag
                    if bag ~= KEYRING_CONTAINER then
                        local locked = IsInventoryItemLocked(ContainerIDToInventoryID(bag))
                        _G[parent .. "BagSlotsFrame" .. bag .. "IconTexture"]:SetDesaturated(locked or 0)
                    end
                    -- items
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

function Bagzen:MODIFIER_STATE_CHANGED()
    Bagzen:ScrapHighlight(arg1, arg2)
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

function Bagzen:InitFrameOnUpdate(frame)
    if (frame.tick or 1) > GetTime() then return else frame.tick = GetTime() + frame.delay end
    if Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags[0] == nil then return end
    local ready = true
    -- wait until itemlinks are available
    for i = 1, 4 do
        local baglink = GetInventoryItemLink("player", i + 19)
        if baglink ~= nil then
            if string.find(baglink, "%[%]") then
                ready = false
            end
        end
    end
    if ready == false then return end
    frame.finished = true
    for k, v in pairs(frame.Queue) do
        if v[1] == "PLAYER_LOGIN" then
            Bagzen:PLAYER_LOGIN()
        elseif v[1] == "BAG_UPDATE" then
            if v[2] >= 0 and v[2] < 5 then
                Bagzen:BagSlotUpdate(BagzenBagFrame, v[2])
                Bagzen:ContainerItemUpdate(BagzenBagFrame, v[2])
            end
        elseif v[1] == "BAG_UPDATE_COOLDOWN" then
            Bagzen:BAG_UPDATE_COOLDOWN()
        end
    end
    frame:Hide()
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
    Bagzen:RegisterEvent("MODIFIER_STATE_CHANGED")
    Bagzen:RegisterEvent("PLAYER_MONEY")
    Bagzen:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    Bagzen.InitFrame:Show()
    -- not triggered on WOTLK client
    --Bagzen:PLAYER_LOGIN()
end

-- emulate MODIFIER_STATE_CHANGED (for shift) in vanilla and call ScrapHighlight/ScrapGlow
if Bagzen.IsVanilla then
    local frame = CreateFrame("Frame", "BagzenModShift")
    frame.tick = GetTime()
    frame.delay = 0.1 -- throttle
    frame.stateShift = 0
    frame:SetScript("OnUpdate", function()
        if frame.tick > GetTime() then return else frame.tick = GetTime() + frame.delay end
        -- Bagzen:Print(this.tick)
        local stateShift = IsShiftKeyDown() and 1 or 0
        if stateShift ~= frame.stateShift then
            frame.stateShift = stateShift
            Bagzen:ScrapHighlight("LSHIFT", stateShift)
        end
    end)
end