Bagzen.ScrapFrame = Bagzen.SortFrame or CreateFrame("Frame", "BagzenScrapFrame")
Bagzen.ScrapFrame.delay = 0.1
Bagzen.ScrapFrame.max = 12
Bagzen.ScrapFrame:Hide()
Bagzen.ScrapFrame:SetScript("OnUpdate", function()
    Bagzen:ScrapFrameOnUpdate(this)
end)
Bagzen.ScrapFrame:SetScript("OnShow", function()
    this.money = GetMoney()
    this.processed = 0
end)
Bagzen.ScrapFrame:SetScript("OnHide", function()
    this.money = nil
    this.processed = 0
end)


function Bagzen:ScrapFrameOnUpdate(frame)
    if (frame.tick or 1) > GetTime() then return else frame.tick = GetTime() + frame.delay end
    frame.processed = frame.processed + 1
    if frame.processed > frame.max + 1 then
        Bagzen:Print("Something went wrong")
        frame:Hide()
        return
    end

    local next = next
    local _, tmp = next(frame.data)
    if tmp ~= nil then
        Bagzen:Print("Selling " .. tmp.itemLink)
        ClearCursor()
        UseContainerItem(tmp.bag, tmp.slot)
        table.remove(frame.data, 1)
    else
        Bagzen:Print("You earned", Bagzen:CreateGoldString(GetMoney() - frame.money))
        frame.processed = 0
        frame:Hide()
    end
end

function Bagzen:isScrap(itemID)
    local _, _, rarity = Bagzen:GetItemInfo(tonumber(itemID))
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
    local sellList = {}
    for bag, slot, itemLink in Bagzen:iterateScrap() do
        if bag ~= nil and slot ~= nil and itemLink ~= nil then
            count = count + 1
            table.insert(sellList, {
                bag = bag,
                slot = slot,
                itemLink = itemLink
            })
            if count == Bagzen.ScrapFrame.max then break end -- buyback limit
        end
        if count > 0 then
            Bagzen.ScrapFrame.data = sellList
            Bagzen.ScrapFrame:Show()
        end
    end
end

function Bagzen:ToggleScrap(itemID)
    local scrap = Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].scrap[itemID]
    local useful = Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].useful[itemID]
    local itemName, _, rarity, _, itemtype = Bagzen:GetItemInfo(tonumber(itemID))

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
