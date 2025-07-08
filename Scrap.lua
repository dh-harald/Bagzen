function Bagzen:isScrap(itemID)
    local _, _, rarity = GetItemInfo(tonumber(itemID))
    return (Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].useful[itemID] ~= nil) or (rarity == 0) or (Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].scrap[itemID] ~= nil)
end

function Bagzen:RepairItems()
    local cost, possible = GetRepairAllCost()
    if cost > 0 and possible then
        Bagzen:Print("Your items have been repaired for" .. " " .. Bagzen:CreateGoldString(cost))
        RepairAllItems()
    end
end

function Bagzen:iterateScrap()
    local numSlots = GetContainerNumSlots(0)
    local bag, slot = 0, 0
    return function()
        while true do
            if slot < numSlots then
                slot = slot + 1
            elseif bag < 5 then
                bag, slot = bag + 1, 1
                numSlots = GetContainerNumSlots(bag)
            else
                return
            end

            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemID = Bagzen:LinkToItemID(itemLink)
                if Bagzen:isScrap(itemID) then
                    return bag, slot, itemLink
                end
           end
        end
    end
end

function Bagzen:SellScrap()
    local count = 0
    for bag, slot, itemLink in Bagzen:iterateScrap() do
        Bagzen:Print("Selling " .. itemLink)
        ClearCursor()
        UseContainerItem(bag, slot)
        count = count + 1
        if count == 12 then break end
    end
end

function Bagzen:ToggleScrap(itemID)
    local scrap = Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].scrap[itemID]
    local useful = Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].useful[itemID]
    local itemName, _, rarity, _, itemtype = GetItemInfo(tonumber(itemID))

    if itemtype == "Quest" then
        Bagzen:Print("Can't add quest item as scrap")
        return
    end

    if (scrap == nil and useful == nil) then
        if rarity > 0 then
            Bagzen:Print("Setting " .. itemName .. " as scrap")
            Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].scrap[itemID] = true
        else
            Bagzen:Print(itemName .. " is already scrap")
        end        
    elseif (scrap == nil and useful ~= nil) then
        -- item was set as useful (only poor item could be useful)
        Bagzen:Print("Removing " .. itemName .. " as useful")
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].useful[itemID] = nil
    else
        Bagzen:Print("Removing " .. itemName .. " as scrap")
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].scrap[itemID] = nil
    end
end

function Bagzen:BindingsToggleScrap()
    if GameTooltip:IsVisible() then
        local itemID = BagzenTooltip.itemID
        if itemID then
            Bagzen:ToggleScrap(itemID)
            Bagzen:ContainerUpdate(BagzenBagFrame, Bagzen.realmname, Bagzen.unitname)
        end
    end
end
