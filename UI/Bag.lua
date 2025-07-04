-- ???
function Bagzen:BagOnLoad(frame)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:RegisterForDrag("LeftButton")
end

function Bagzen:UpdateBagSlot(frame)
    local bag = frame:GetID()
    local name = frame:GetParent():GetParent():GetName()

    local icontexture = getglobal(name .. "BagSlotsFrame" .. bag .. "IconTexture")

    if bag == 0 then -- backpack
        frame.itemlink = nil
        icontexture:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    elseif bag > 0 then
        -- containerslots
        local baglink = GetInventoryItemLink("player", ContainerIDToInventoryID(bag))
        if baglink then
            local bagframe = getglobal(name .. "BagSlotsFrame" .. bag)
            local itemID = Bagzen:LinkToItemID(baglink)
            local _, itemlink, _, _, _, _, _, _, texture = GetItemInfo(itemID)
            local icontexture = getglobal(name .. "BagSlotsFrame" .. bag .. "IconTexture")

            bagframe.link = itemlink
            icontexture:SetTexture(texture)
        else
            local bagframe = getglobal(name .. "BagSlotsFrame" .. bag)
            local icontexture = getglobal(name .. "BagSlotsFrame" .. bag .. "IconTexture")
            bagframe.link = nil
            icontexture:SetTexture(nil)
        end
    end
end

function Bagzen:BagOnEnter(frame)
    local bag = frame:GetID()
    if bag == 0 then
        GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
        GameTooltip:ClearLines()
        GameTooltip:SetText("Backpack")
        GameTooltip:Show()
        Bagzen:HighlightSlots(frame:GetParent():GetParent(), bag)
    elseif bag > 0 then
        if frame.link then
            GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
            GameTooltip:ClearLines()
            GameTooltip:SetHyperlink(frame.link)
            GameTooltip:Show()
            Bagzen:HighlightSlots(frame:GetParent():GetParent(), bag)
        end
    end
end

function Bagzen:BagOnLeave(frame)
    GameTooltip:Hide()
    Bagzen:UnHighlightAll(frame:GetParent():GetParent())
end

function Bagzen:BagOnDragStart(frame)
    -- Bagzen:Print("DEBUG, BagOnDragStart", frame:GetName(), button, frame:GetID())
    PickupBagFromSlot(ContainerIDToInventoryID(frame:GetID()))
    PlaySound("BAGMENUBUTTONPRESS")
end

function Bagzen:BagOnClick(frame, button)
    -- Bagzen:Print("DEBUG, BagOnClick", frame:GetName(), button, frame:GetID())
    if ( button == "LeftButton" ) then
        if not PutItemInBag(ContainerIDToInventoryID(frame:GetID())) then
            PickupBagFromSlot(ContainerIDToInventoryID(frame:GetID()))
        end
    end
    PlaySound("BAGMENUBUTTONPRESS")
end
