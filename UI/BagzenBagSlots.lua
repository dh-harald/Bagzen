StaticPopupDialogs["BAGZEN_CONFIRM_BUY_BANK_SLOT"] = {
        text = TEXT(CONFIRM_BUY_BANK_SLOT),
        button1 = TEXT(YES),
        button2 = TEXT(NO),
        OnAccept = function()
                PurchaseSlot();
        end,
        OnShow = function()
                MoneyFrame_Update(this:GetName().."MoneyFrame", BagzenBankFrame.nextSlotCost);
        end,
        hasMoneyFrame = 1,
        timeout = 0,
        hideOnEscape = 1,
};

function Bagzen:BagSlotsInit(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "BagSlotsFrame"]
    if Bagzen.settings.global[parent.SettingSection].bagsframe then
        frame:Show()
    else
        frame:Hide()
    end
    local size = Bagzen.PADDING
    for _, bag in pairs(parent.Bags) do
        if bag ~= KEYRING_CONTAINER then
            size = size + Bagzen.SIZE_X
        end
    end
    size = size + Bagzen.PADDING
    frame:SetWidth(size)
end

function Bagzen:HighlightSlots(frame, bag)
    local _G = _G or getfenv()
    local name = frame:GetName()
    local bagframe = _G[name .. "BagSlotsFrame" .. bag]
    local live = "Live"
    if frame.Virtual == true then
        live = "Virtual"
    end
    for i, slotframe in pairs(Bagzen.ContainerFrames[live][frame.SettingSection][bag]) do
        if i <= bagframe.Slots then
            slotframe:LockHighlight()
        end
    end
end

function Bagzen:UnHighlightSlots(frame)
    local _G = _G or getfenv()
    local name = frame:GetName()
    local live = "Live"
    if frame.Virtual == true then
        live = "Virtual"
    end
    for _, bag in pairs(frame.Bags) do
        if Bagzen.ContainerFrames[live][frame.SettingSection][bag] then
            local bagframe = _G[name .. "BagSlotsFrame" .. bag]
            for i, slotframe in pairs(Bagzen.ContainerFrames[live][frame.SettingSection][bag]) do
                if i <= bagframe.Slots then
                    slotframe:UnlockHighlight()
                end
            end
        end
    end
end

function Bagzen:BagSlotItemOnEnter(frame)
    local bag = frame:GetID()
    if bag == KEYRING_CONTAINER then return end -- sanity check
    local virtual = frame:GetParent():GetParent().Virtual

    local show = bag < 1 or frame.ItemLink or (frame:GetParent():GetParent():GetName() == "BagzenBankFrame" and frame.Purchasable and virtual == false)

    if show then
        GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
        GameTooltip:ClearLines()

        if frame:GetParent():GetParent():GetName() == "BagzenBankFrame" and frame.Purchasable then
            GameTooltip:SetText("Purchasable Bank Slot")
        elseif bag < 1 then
            if bag == -1 then
                GameTooltip:SetText("Bank")
            else
                GameTooltip:SetText("Backpack")
            end
        else
            if frame.ItemLink then
                if virtual == true then
                    GameTooltip:SetHyperlink(frame.ItemLink)
                else
                    GameTooltip:SetInventoryItem("player", frame.Slot)
                end
            else
                show = false
            end
        end
        GameTooltip:Show()

        Bagzen:HighlightSlots(frame:GetParent():GetParent(), bag)
    end
end

function Bagzen:BagSlotItemOnLeave(frame)
    GameTooltip:Hide()
    Bagzen:UnHighlightSlots(frame:GetParent():GetParent())
end

function Bagzen:BagSlotItemOnClick(frame)
    local hadItem = nil
    if frame.Slot == 19 then
        hadItem = PutItemInBackpack()
    else
        hadItem = PutItemInBag(frame.Slot)
    end
    if not hadItem then
        if frame:GetParent():GetParent():GetName() == "BagzenBankFrame" and frame.Purchasable then
            StaticPopup_Show("BAGZEN_CONFIRM_BUY_BANK_SLOT")
        elseif IsShiftKeyDown() then
            if (ChatFrameEditBox:IsShown()) then
                -- ChatFrameEditBox:Insert(frame.ItemLink) TODO: create proper link for linkng
            end
        else
            PickupBagFromSlot(frame.Slot)
        end
    end
end

function Bagzen:BagSlotItemOnDragStart(frame)
    PickupBagFromSlot(frame.Slot)
end

function Bagzen:BagSlotItemUpdate(frame)
    local _G = _G or getfenv()
    local bag = frame:GetID()
    local name = frame:GetName()
    local icontexture = _G[name .. "IconTexture"]
    local parent = frame:GetParent():GetParent()
    local virtual = parent.Virtual
    if virtual == false and bag == KEYRING_CONTAINER then
        local numslots = GetKeyRingSize() or 0
        if numslots > 0 then
            Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags[bag] = {
                size = GetKeyRingSize() or 0,
                slots = {}
            }
        end
        frame.Slots = numslots
        return -- no keyring button here
    elseif bag == KEYRING_CONTAINER then
        frame.Slots = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] and Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].size or 0
        Bagzen:Print(frame.Slots)
        return
    elseif bag <= 0 then
        -- backpack or default bank slot
        frame.itemlink = nil
        icontexture:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    else
        local baglink = nil
        if virtual == false then
            baglink = GetInventoryItemLink("player", frame.Slot)
        else
            if Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags and Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] then
                baglink = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].link
            end
        end
        if baglink ~= nil then
            local itemID = Bagzen:LinkToItemID(baglink)
            local _, itemLink, _, _, _, _, _, _, _, texture = Bagzen:GetItemInfo(itemID)
            icontexture:SetTexture(texture)
            frame.ItemLink = itemLink
        else
            icontexture:SetTexture(nil)
            frame.ItemLink = nil
            frame.Slots = 0
        end
    end
    if virtual == false and (frame.ItemLink or bag < 1) then
        -- save slots
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags[bag] = {
            texture = icontexture:GetTexture(),
            link = frame.ItemLink,
            size = GetContainerNumSlots(bag),
            slots = {}
        }
    end
    if virtual == true or bag < 1 then
        frame:RegisterForClicks(nil)
        frame:RegisterForDrag(nil)
    else
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        frame:RegisterForDrag("LeftButton")
    end
end

function Bagzen:BagSlotUpdate(parent, bag)
    local _G = _G or getfenv()
    local bagslotsframe = _G[parent:GetName() .. "BagSlotsFrame"]
    local dummyframe = _G[parent:GetName() .. "DummyBagSlotFrame" .. bag]
    if dummyframe == nil then
        dummyframe = CreateFrame("Frame", parent:GetName() .. "DummyBagSlotFrame" .. bag, parent)
        Bagzen:HackID(dummyframe)
        dummyframe:SetID(bag)
        if bag == KEYRING_CONTAINER then
            if parent.KeyChain == true then
                dummyframe:Show()
            else
                dummyframe:Hide()
            end
        end
    end

    local numslots = 0
    if parent.Virtual == false then
        if bag == KEYRING_CONTAINER then
            numslots = GetKeyRingSize() or 0
        else
            numslots = GetContainerNumSlots(bag) or 0
        end
        -- remove empty slot from character data
        if numslots == 0 and Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags ~= nil and Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] ~= nil then
            Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] = nil
        end
    else
        if Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags and Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] then
            numslots = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].size or 0
        end
    end

    if bag == KEYRING_CONTAINER then -- create a frame only for keyring
        if numslots == 0 then
        end
        local frame = _G[parent:GetName() .. "BagSlotsFrame" .. bag]
        if frame == nil then
            frame = CreateFrame("Frame", parent:GetName() .. "BagSlotsFrame" .. bag, bagslotsframe)
            Bagzen:HackID(frame)
            frame:SetID(bag)
            frame.Slots = numslots
        end
        Bagzen:BagSlotItemUpdate(frame)
        return
    end

    local frame = _G[parent:GetName() .. "BagSlotsFrame" .. bag]
    if frame == nil then
        frame = CreateFrame("Button", parent:GetName() .. "BagSlotsFrame" .. bag, bagslotsframe, "BagzenBagSlotItemTemplate")
        Bagzen:HackID(frame)
        frame:SetID(bag)
        local index = 0
        for _, tmp in pairs(parent.Bags) do
            if tmp == bag then
                break
            end
            index = index + 1
        end
        frame:SetPoint("TOPLEFT", bagslotsframe:GetName(), "TOPLEFT", 2 * Bagzen.PADDING + index * Bagzen.SIZE_X, -2 * Bagzen.PADDING)
    end

    if parent:GetName() == "BagzenBankFrame" then
        if bag > 0 then
            local bagslottexture = _G[frame:GetName() .. "Background"]

            local numbagslots = 0
            if parent.Virtual == false then
                numbagslots = GetNumBankSlots()
            else
                numbagslots = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bagslots or 0
            end
            if (bag - 4) > numbagslots then
                frame.Purchasable = true
                bagslottexture:SetTexture(0.5, 0, 0, 0.2)
            else
                frame.Purchasable = nil
                bagslottexture:SetTexture(0, 0, 0, 0)
            end
        end
    end
    frame:SetID(bag)
    if bag > 0 then
        frame.Slot = ContainerIDToInventoryID(bag)
    else
        frame.Slot = ContainerIDToInventoryID(1) - 1 + bag
    end
    frame.Slots = numslots
    Bagzen:BagSlotItemUpdate(frame)
    frame:Show()
end

function Bagzen:BagSlotsToggle(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "BagSlotsFrame"]
    if frame:IsShown() then
        frame:Hide()
        Bagzen.settings.global[parent.SettingSection].bagsframe = false
    else
        frame:Show()
        Bagzen.settings.global[parent.SettingSection].bagsframe = true
    end
end
