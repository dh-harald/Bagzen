function Bagzen:RepairItems()
    local cost, possible = GetRepairAllCost()
    if cost > 0 and possible then
        Bagzen:Print("Your items have been repaired for" .. " " .. Bagzen:CreateGoldString(cost))
        RepairAllItems()
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

function Bagzen:ScrapToggle()
    if GameTooltip:IsVisible() then
        local itemID = BagzenTooltip.itemID
        if itemID then
            Bagzen:ToggleScrap(itemID)
            Bagzen:UpdateSlots(BagzenBagFrame)
        end
    end
end
