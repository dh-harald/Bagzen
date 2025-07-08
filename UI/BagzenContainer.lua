Bagzen.ContainerFrames = {
    ["bagframe"] = {
        ["count"] = 0,
    },
    ["bankframe"] = {
        ["count"] = 0,
    }
}

function Bagzen:ContainerOnLoad(frame)
    local name = frame:GetName()
    frame:RegisterForDrag("LeftButton")
    frame:SetUserPlaced(true)
    tinsert(UISpecialFrames, name)
    if name == "BagzenBagFrame" then
        frame.SettingSection = "bagframe"
        frame.FrameName = "Bag"
    elseif name == "BagzenBankFrame" then
        frame.SettingSection = "bankframe"
        frame.FrameName = "Bank"
    end
    frame.SplitStack = function(button, split)
        SplitContainerItem(button.Bag, button:GetID(), split)
    end
end

function Bagzen:ContainerInit(frame, bags)
    frame.Bags = bags
    Bagzen:BagSlotsInit(frame)
    frame.OwnerName = Bagzen.unitname
    frame.OwnerRealm = Bagzen.realmname
end

function Bagzen:ContainerGetPosition(frame)
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
        Bagzen.settings.char[frame.SettingSection].point = point
        Bagzen.settings.char[frame.SettingSection].relativePoint = relativePoint
        Bagzen.settings.char[frame.SettingSection].xOfs = xOfs
        Bagzen.settings.char[frame.SettingSection].yOfs = yOfs
end

function Bagzen:ContainerOnMouseDown(frame)
    frame.isMoving = 1
    frame:StartMoving()
end

function Bagzen:ContainerOnMouseUp(frame)
    frame:StopMovingOrSizing()
    frame.isMoving = nil
    Bagzen:ContainerGetPosition(frame)
end

function Bagzen:ContainerItemOnEnter(frame)
    if frame ~= nil and frame.ItemLink then
        GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
        GameTooltip:ClearLines()
        GameTooltip:SetBagItem(frame.Bag, frame:GetID())
        GameTooltip:Show()
    end
end

function Bagzen:ContainerItemOnLeave(frame)
    GameTooltip:Hide()
end

function Bagzen:ContainerItemOnClick(frame, button, nomod)
    if button == "LeftButton" then
        if IsControlKeyDown() and not nomod then
            Bagzen:Print(frame.ItemLink)
            DressUpItemLink(frame.ItemLink)
        elseif IsShiftKeyDown() and not nomod then
            if ChatFrameEditBox:IsShown() then
                ChatFrameEditBox:Insert(frame.ItemLink)
            else
                local texture, itemCount, locked = GetContainerItemInfo(frame.Bag, frame:GetID())
                if not locked then
                    frame.SplitStack = function(button, split)
                        SplitContainerItem(button.Bag, button:GetID(), split)
                    end
                    OpenStackSplitFrame(frame.count, this, "BOTTOMRIGHT", "TOPRIGHT")
                end
            end
        else
            PickupContainerItem(frame.Bag, frame:GetID())
            StackSplitFrame:Hide()
        end
    else
        -- right button
        if IsControlKeyDown() and not nomod then
            return
        elseif IsShiftKeyDown() and MerchantFrame:IsShown() and not nomod then
            this.SplitStack = function(button, split)
                SplitContainerItem(button.Bag, button:GetID(), split)
                MerchantItemButton_OnClick("LeftButton")
            end
            OpenStackSplitFrame(this.count, this, "BOTTOMRIGHT", "TOPRIGHT")
        elseif MerchantFrame:IsShown() and MerchantFrame.selectedTab == 2 then
            return
        elseif AuctionFrame and AuctionFrame:IsShown() and AuctionFrame.selectedTab == 3 then
            PickupContainerItem(frame.Bag, frame:GetID())
            ClickAuctionSellItemButton()
            PutItemInBag(20)
            PutItemInBag(21)
            PutItemInBag(22)
            PutItemInBag(23)
        else
            UseContainerItem(frame.Bag, frame:GetID())
            StackSplitFrame:Hide()
        end
    end
end

function Bagzen:ContainerResize(frame)
    frame:SetWidth(Bagzen.settings.global[frame.SettingSection].width * Bagzen.SIZE_X)
    local count = 0
    for _, bag in pairs(frame.Bags) do
        if bag ~= KEYRING_CONTAINER then
            local bagframe = getglobal(frame:GetName() .. "BagSlotsFrame" .. bag)
            if bagframe then
                count = count + (bagframe.Slots or 0)
            end
        end
    end

    local y = 4 + math.abs(Bagzen.MOD_Y) + Bagzen.SIZE_Y * (math.floor(count / Bagzen.settings.global[frame.SettingSection].width))
    if math.mod(count, Bagzen.settings.global[frame.SettingSection].width) > 0 then
        y = y + Bagzen.SIZE_Y
    end
    frame:SetHeight(y + 20)
end

function Bagzen:UpdateCooldown(container, button)
    local cooldown = getglobal(button:GetName().."Cooldown")
    local start, duration, enable = GetContainerItemCooldown(container, button:GetID())
    CooldownFrame_SetTimer(cooldown, start, duration, enable)
    if duration > 0 and enable == 0 then
        SetItemButtonTextureVertexColor(button, 0.4, 0.4, 0.4)
    end
end

function Bagzen:ContainerItemUpdate(frame, bag)
    if bag == KEYRING_CONTAINER then return end -- sanity check
    local section = frame.SettingSection
    local parent = getglobal(frame:GetName() .. "BagSlotsFrame" .. bag)
    local numslots = parent.Slots

    if Bagzen.ContainerFrames[section][bag] == nil then
        Bagzen.ContainerFrames[section][bag] = {}
    end

    if numslots == 0 then
        for _, f in pairs(Bagzen.ContainerFrames[section][bag]) do
            f:Hide()
        end
        return
    end

    for slot = 1, numslots do
        local slotframe = nil
        if Bagzen.ContainerFrames[section][bag][slot] ~= nil then
            slotframe = Bagzen.ContainerFrames[section][bag][slot]
        else
            Bagzen.ContainerFrames[section]["count"] = Bagzen.ContainerFrames[section]["count"] + 1
            local framename = frame:GetName() .. "ContainerSlot" .. Bagzen.ContainerFrames[section]["count"]
            slotframe = CreateFrame("Button", framename, frame, "BagzanContainerItemTemplate")
            Bagzen.ContainerFrames[section][bag][slot] = slotframe
        end
        slotframe.Bag = bag
        slotframe:SetID(slot)
    end

    local count = 0
    for _, tmpbag in pairs(frame.Bags) do
        if tmpbag == bag then break end
        count = count + (getglobal(frame:GetName() .. "BagSlotsFrame" .. tmpbag).Slots or 0)
    end

    for slot, slotframe in pairs(Bagzen.ContainerFrames[section][bag]) do
        if slot <= numslots then
            local texture = getglobal(slotframe:GetName() .. "texture") or slotframe:CreateTexture(slotframe:GetName() .. "texture", 'OVERLAY')
            local itemtexture, itemcount = GetContainerItemInfo(slotframe.Bag, slotframe:GetID())
            if itemtexture then
                SetItemButtonTexture(slotframe, itemtexture)
                SetItemButtonCount(slotframe, itemcount)
                Bagzen:UpdateCooldown(slotframe.Bag, slotframe)
                local itemLink = GetContainerItemLink(slotframe.Bag, slotframe:GetID())
                local itemID = Bagzen:LinkToItemID(itemLink)
                local itemName = GetItemInfo(itemID)
                slotframe.ItemName = itemName
                slotframe.ItemLink = itemLink
                if frame.Virtual == false then
                    if Bagzen:isQuestItem(itemID) then
                        texture:SetTexture('Interface\\AddOns\\Bagzen\\textures\\BagQuestIcon.tga')
                        texture:SetPoint('TOPLEFT', 2, -2)
                        texture:SetWidth(32)
                        texture:SetHeight(32)
                    end
                    -- save item
                    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags[slotframe.Bag].slots[slot] = {
                        count = itemcount,
                        link = itemLink,
                        texture = itemtexture
                    }
                end
            else
                SetItemButtonTexture(slotframe, nil)
                SetItemButtonCount(slotframe, 0)
                slotframe.ItemLink = nil
                slotframe.ItemName = nil
            end
            local POS_X = Bagzen.PADDING + (Bagzen.SIZE_X * math.mod(count, Bagzen.settings.global[section].width))
            local POS_Y = Bagzen.MOD_Y - (Bagzen.SIZE_Y * math.floor(count / Bagzen.settings.global[section].width))
            slotframe:SetPoint("TOPLEFT", frame:GetName(), "TOPLEFT", POS_X, POS_Y)
            slotframe:Show()
            if frame.Virtual == false then
                slotframe:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                slotframe:RegisterForDrag("LeftButton")
            end
        else
            slotframe:Hide()
        end
        count = count + 1
    end
end

function Bagzen:ContainerUpdate(frame, realm, name)
    frame.OwnerName = name
    frame.OwnerRealm = realm
    if frame:GetName() == "BagzenBagFrame" then
        if frame.OwnerName == Bagzen.unitname and frame.OwnerRealm == Bagzen.realmname then
            frame.Virtual = false
        else
            frame.Virtual = true
        end
    else
        -- TODO: Bank frame
    end

    local titleframe = getglobal(frame:GetName() .. "TitleText")
    titleframe:SetText(string.format("%s's %s", frame.OwnerName, frame.FrameName))

    for _, bag in pairs(frame.Bags) do
        Bagzen:BagSlotUpdate(frame, bag)
        Bagzen:ContainerItemUpdate(frame, bag)
    end
    Bagzen:ContainerResize(frame)
end

function Bagzen:ContainerReposition(frame)
    local scale = Bagzen.settings.char[frame.SettingSection].scale or 1
    if scale then
        frame:SetScale(scale)
    end
    if Bagzen.settings.char[frame.SettingSection].point then
        frame:SetPoint(Bagzen.settings.char[frame.SettingSection].point, nil, Bagzen.settings.char[frame.SettingSection].relativePoint, Bagzen.settings.char[frame.SettingSection].xOfs, Bagzen.settings.char[frame.SettingSection].yOfs)
    end
end
