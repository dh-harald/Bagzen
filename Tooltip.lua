Bagzen.Tooltip = CreateFrame("Frame" , "BagzenTooltip", GameTooltip)
Bagzen.Tooltip:SetScript("OnShow", function ()
    Bagzen:TooltipOnShow(this)
end)

Bagzen.Tooltip:SetScript("OnHide", function ()
    Bagzen:TooltipOnHide(this)
end)

local BagzenSetHyperLink = GameTooltip.SetHyperlink
function GameTooltip.SetHyperlink(self, arg1)
    if arg1 then
        local _, _, linktype = string.find(arg1, "^(.-):(.+)$")
        if linktype == "item" then
            Bagzen.Tooltip.itemID = Bagzen:LinkToItemID(arg1)
        else
            Bagzen.Tooltip.itemID = nil
        end
    end
    return BagzenSetHyperLink(self, arg1)
end

local BagzenSetBagItem = GameTooltip.SetBagItem
function GameTooltip.SetBagItem(self, container, slot)
    if not container or not slot then
        return BagzenSetBagItem(self, container, slot)
    end

    local itemLink = GetContainerItemLink(container, slot)
    if itemLink then
        local itemID = Bagzen:LinkToItemID(itemLink)
        Bagzen.Tooltip.itemID = itemID
    else
        Bagzen.Tooltip.itemID = nil
    end

    return BagzenSetBagItem(self, container, slot)
end

local BagzenSetInventoryItem = GameTooltip.SetInventoryItem
function GameTooltip.SetInventoryItem(self, unit, slot)
    if not unit or not slot then
        return BagzenSetInventoryItem(self, unit, slot)
    end

    local itemLink = GetInventoryItemLink(unit, slot)
    if itemLink then
        Bagzen.Tooltip.itemID = Bagzen:LinkToItemID(itemLink)
    end
    return BagzenSetInventoryItem(self, unit, slot)
end


local BagzenSetInboxItem = GameTooltip.SetInboxItem
function GameTooltip.SetInboxItem(self, index, attachment)
    if not index then
        return BagzenSetInboxItem(self, index, attachment)
    end

    local itemName = GetInboxItem(index, attachment)
    local itemID = Bagzen:GetItemIDByName(itemName)
    if itemID then
        Bagzen.Tooltip.itemID = itemID
    else
        Bagzen.Tooltip.itemID = nil
    end

    return BagzenSetInboxItem(self, index, attachment)
end

local BagzenSetQuestLogItem = GameTooltip.SetQuestLogItem
function GameTooltip.SetQuestLogItem(self, itemType, index)
    if not itemType or not index then
        return BagzenSetQuestLogItem(self, itemType, index)
    end

    local itemLink = GetQuestLogItemLink(itemType, index)
    if itemLink then
        Bagzen.Tooltip.itemID = Bagzen:LinkToItemID(itemLink)
    end

    return BagzenSetQuestLogItem(self, itemType, index)
end

local BagzenSetQuestItem = GameTooltip.SetQuestItem
function GameTooltip.SetQuestItem(self, itemType, index)
    if not itemType or not index then
        return BagzenSetQuestItem(self, itemType, index)
    end

    local itemLink = GetQuestItemLink(itemType, index)
    if itemLink then
        Bagzen.Tooltip.itemID = Bagzen:LinkToItemID(itemLink)
    end
    return BagzenSetQuestItem(self, itemType, index)
end

function Bagzen:TooltipOnShow(frame)
    if not frame.itemID then return end

    local added = false
    local count = 0

    for character, data in pairs(Bagzen.data.global[Bagzen.realmname]) do
        local class = data["class"]
        local bagcount = 0
        local bankcount = 0
        local mailcount = 0

        local bagdata = data.bags
        local maildata = data.mails or {}

        for bag, data2 in pairs(bagdata) do
            if type(bag) == "number" and bag >= -1 then
                if data2["slots"] then
                    for _, item in pairs(data2["slots"]) do
                        if Bagzen:LinkToItemID(item["link"]) == frame.itemID then
                            if bag >=0 and bag < 5 then
                                -- bag
                                bagcount = bagcount + item["count"]
                            elseif bag == -1 or bag > 4 then
                                -- bank
                                bankcount = bankcount + item["count"]
                            end
                        end
                    end
                end
            end
        end

        for i, item in pairs(maildata) do
            if item.itemid ~= nil and item.itemid == frame.itemID
            then
                mailcount = mailcount + item.count
            end
        end

        local countstr = ""
        local classcolor = RAID_CLASS_COLORS[class]
        if bagcount > 0 then
            count = count + bagcount
            countstr = "|cff4378ccBag:|r " .. bagcount
            ---countstr = "Bags: " .. bagcount
        end
        if bankcount > 0 then
            count = count + bankcount
            if countstr == "" then
                countstr = "|cff4378ccBank:|r " .. bankcount
            else
                countstr = countstr .. ", |cff4378ccBank:|r " .. bankcount
            end
        end
        if mailcount > 0 then
            count = count + mailcount
            if countstr == "" then
                countstr = "|cff4378ccMail:|r " .. mailcount
            else
                countstr = countstr .. ", |cff4378ccMail:|r " .. mailcount
            end
        end
        if countstr ~= "" then
            if added == false then
                GameTooltip:AddLine("\n")
                added = true
            end
            GameTooltip:AddDoubleLine(character, countstr, classcolor.r, classcolor.g, classcolor.b, 1, 1, 1)
        end
    end
    if count > 0 then
        GameTooltip:AddDoubleLine("Total", count, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddLine("\n")
    end
end

function Bagzen:TooltipOnHide(frame)
    frame.itemID = nil
end
