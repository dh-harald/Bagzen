Bagzen.SIZE_X = 40
Bagzen.SIZE_Y = 40
Bagzen.START_X = 4
Bagzen.START_Y = -48

Bagzen.ContainerFrames = {
    ["bagframe"] = {
        ["count"] = 0,
    },
    ["bankframe"] = {
        ["count"] = 0,
    }
}

function Bagzen:InitContainerFrame(frame, bags)
    local name = frame:GetName()
    local title = ""

    frame.Bags = bags

    if name == "BagzenBagFrame" then
        frame.SettingSection = "bagframe"
        title = "Bag"
    elseif name == "BagzenBankFrame" then
        frame.SettingSection = "bankframe"
        title = "Bank"
    end
    local titleframe = getglobal(name .. "Title")
    titleframe:SetText(string.format("%s's %s", Bagzen.unitname, title))
end

function Bagzen:UpdateContainerItems(parent, bag)
    local section = parent:GetParent().SettingSection
    local bagframe = getglobal(parent:GetParent():GetName() .. "BagSlotsFrame" .. bag)

    local numslots = GetContainerNumSlots(bag) or 0

    -- create dummy frame for bag
    local bagframename = ""
    if bag == KEYRING_CONTAINER then
        bagframename = parent:GetParent():GetName() .. "KeyRingFrame"
    else
        bagframename = parent:GetParent():GetName() .. "BagFrame" .. bag
    end
    local dummybagframe = getglobal(bagframename) or CreateFrame("Frame", bagframename, parent:GetParent())
    dummybagframe:SetID(bag)
    dummybagframe.size = numslots

    bagframe.slots = numslots

    if Bagzen.ContainerFrames[section][bag] == nil then
        Bagzen.ContainerFrames[section][bag] = {}
    end

    if numslots == 0 then
        -- because of return
        for slot, f in pairs(Bagzen.ContainerFrames[section][bag]) do
            f:Hide()
        end
        return
    end

    for slot = 1, numslots do
        local frame = nil
        if Bagzen.ContainerFrames[section][bag][slot] ~= nil then
            frame = Bagzen.ContainerFrames[section][bag][slot]
        else
            Bagzen.ContainerFrames[section]["count"] = Bagzen.ContainerFrames[section]["count"] + 1
            local framename = parent:GetName() .. "ContainerSlot" .. Bagzen.ContainerFrames[section]["count"]
            frame = CreateFrame("Button", framename, dummybagframe, "BagzenContainerFrameItemButtonTemplate")
            Bagzen.ContainerFrames[section][bag][slot] = frame
        end
        frame.bag = bag
        frame:SetID(slot)
    end

    local count = 0
    for _, tmpbag in pairs(parent:GetParent().Bags) do
        if tmpbag == bag then break end
        count = count + (getglobal(parent:GetParent():GetName() .. "BagSlotsFrame" .. tmpbag).slots or 0)
    end

    for slot, frame in pairs(Bagzen.ContainerFrames[section][bag]) do
        if slot <= numslots then
            local texture = getglobal(frame:GetName() .. "texture") or frame:CreateTexture(frame:GetName() .. "texture", 'OVERLAY')

            local itemtexture, itemcount = GetContainerItemInfo(frame.bag, frame:GetID())
            if itemtexture then
                SetItemButtonTexture(frame, itemtexture)
                SetItemButtonCount(frame, itemcount)
                Bagzen:UpdateCooldown(frame.bag, frame)
                local icontexture = getglobal(frame:GetName() .. "IconTexture")
                icontexture:SetTexCoord(0.03, 0.97, 0.03, 0.97) -- dunno why it's not working in xml
                local itemLink = GetContainerItemLink(frame.bag, frame:GetID())
                local itemID = Bagzen:LinkToItemID(itemLink)
                local itemName = GetItemInfo(itemID)
                frame.ItemName = itemName
                if Bagzen:isScrap(itemID) then
                    texture:SetTexture('Interface/Buttons/UI-GroupLoot-Coin-Up')
                    texture:SetPoint('TOPLEFT', 3, -3)
                    texture:SetWidth(15)
                    texture:SetHeight(15)
                elseif Bagzen:isQuestItem(itemID) then
                    texture:SetTexture('Interface\\AddOns\\Bagzen\\textures\\BagQuestIcon.tga')
                    texture:SetPoint('TOPLEFT', 2, -2)
                    texture:SetWidth(32)
                    texture:SetHeight(32)
                else
                    texture:SetTexture(nil)
                end
            else
                SetItemButtonTexture(frame, nil)
                SetItemButtonCount(frame, 0)
                texture:SetTexture(nil)
                frame.ItemName = nil
            end

            local POS_X = Bagzen.START_X + (Bagzen.SIZE_X * math.mod(count, Bagzen.settings.global[parent:GetParent().SettingSection].width))
            local POS_Y = Bagzen.START_Y - (Bagzen.SIZE_Y * math.floor(count / Bagzen.settings.global[parent:GetParent().SettingSection].width))
            frame:SetPoint("TOPLEFT", parent:GetParent():GetName(), "TOPLEFT", POS_X, POS_Y)
            frame:Show()
        else
            frame:Hide()
        end
        count = count + 1
    end
end

function Bagzen:HighlightSlots(frame, bagID)
    local name = frame:GetName()
    local bagframe = getglobal(name .. "BagSlotsFrame" .. bagID)

    for i, slotframe in pairs(Bagzen.ContainerFrames[frame.SettingSection][bagID]) do
        if i <= bagframe.slots then
            slotframe:LockHighlight()
        end
    end
end

function Bagzen:UnHighlightAll(frame)
    local name = frame:GetName()
    for _, bagID in pairs(frame.Bags) do
        if Bagzen.ContainerFrames[frame.SettingSection][bagID] then
            local bagframe = getglobal(name .. "BagSlotsFrame" .. bagID)
            for i, slotframe in pairs(Bagzen.ContainerFrames[frame.SettingSection][bagID]) do
                if i <= bagframe.slots then
                    slotframe:UnlockHighlight()
                end
            end
        end
    end
end

function Bagzen:UpdateCooldown(container, button)
    local cooldown = getglobal(button:GetName().."Cooldown")
    local start, duration, enable = GetContainerItemCooldown(container, button:GetID())
    CooldownFrame_SetTimer(cooldown, start, duration, enable)
    if duration > 0 and enable == 0 then
        SetItemButtonTextureVertexColor(button, 0.4, 0.4, 0.4)
    end
end

function Bagzen:ResizeFrame(frame)
    frame:SetWidth(Bagzen.START_X + Bagzen.settings.global[frame.SettingSection].width * Bagzen.SIZE_X)
    local count = 0
    for _, bag in pairs(frame.Bags) do
        if bag ~= KEYRING_CONTAINER then
            local bagframe = getglobal(frame:GetName() .. "BagSlotsFrame" .. bag)
            if bagframe.slots then
                count = count + bagframe.slots
            end
        end
    end

    local y = 4 + math.abs(Bagzen.START_Y) + Bagzen.SIZE_Y * (math.floor(count / Bagzen.settings.global[frame.SettingSection].width))
    if math.mod(count, Bagzen.settings.global[frame.SettingSection].width) > 0 then
        y = y + Bagzen.SIZE_Y
    end
    frame:SetHeight(y + 20)

    -- searchbox
    local searchbox = getglobal(frame:GetName() .. "SearchBox")
    searchbox:SetWidth(Bagzen.settings.global[frame.SettingSection].width * Bagzen.SIZE_X - Bagzen.START_X)
end

function Bagzen:UpdateBag(bag, force)
    local parent = ""
    -- if (bag == KEYRING_CONTAINER) or (bag >= 0 and bag <= 4)
    if bag >= 0 and bag <= 4
    then
        parent = "BagzenBagFrame"
    -- elseif bankslots
    end

    if parent == "" then return end

    local containerframe = getglobal(parent .. "ContainerFrame")

    -- check bagsframe change
    if force == nil or force == false then
        for _, b in pairs(getglobal(parent).Bags) do
            if b > 0 then
                local bagframe = getglobal(parent .. "BagSlotsFrame" .. b)
                local slot = bagframe.slots or 0
                local bagslot = GetContainerNumSlots(b) or 0
                if slot ~= bagslot then
                    -- update the whole frame
                    Bagzen:UpdateSlots(getglobal(parent), true)
                    return
                end
            end
        end
    end

    local bagframe = getglobal(parent .. "BagSlotsFrame" .. bag)

    Bagzen:UpdateBagSlot(bagframe)
    Bagzen:UpdateContainerItems(containerframe, bag)
    Bagzen:ResizeFrame(getglobal(parent))
end

function Bagzen:UpdateSlots(frame, force)
    local out = false
    for _, bag in pairs(frame.Bags) do
        Bagzen:UpdateBag(tonumber(bag), force)
    end

    local bagsframe = getglobal(frame:GetName() .. "BagSlotsFrame")
    if Bagzen.settings.global[frame.SettingSection].bagsframe then
        bagsframe:Show()
    else
        bagsframe:Hide()
    end

    -- Bagzen:ResizeFrame(frame)
end

function Bagzen:ToggleBagsFrame(frame)
    local bagsframe = getglobal(frame:GetName() .. "BagSlotsFrame")

    if bagsframe:IsShown() then
        bagsframe:Hide()
        Bagzen.settings.global[frame.SettingSection].bagsframe = false
    else
        bagsframe:Show()
        Bagzen.settings.global[frame.SettingSection].bagsframe = true
    end
end

function Bagzen:ClearSearchBox(frame)
    local searchbox = getglobal(frame:GetName().. "SearchBox")
    searchbox:SetText("")
end
