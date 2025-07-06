Bagzen.ItemCache = {}

function Bagzen:isScrap(itemID)
    local _, _, rarity = GetItemInfo(tonumber(itemID))
    return (Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].useful[itemID] ~= nil) or (rarity == 0) or (Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].scrap[itemID] ~= nil)
end

function Bagzen:isQuestItem(itemID)
    local _, _, _, _, itemtype = GetItemInfo(itemID)
    return itemtype == "Quest"
end

function Bagzen:LinkToItemID(hyperLink)
    if hyperLink then
        local _, _, itemID = string.find(hyperLink, "item:(%d+)")
        return tonumber(itemID)
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

function Bagzen:SavePlayerMoney()
    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].money = GetMoney();
end

function Bagzen:SaveBag(bagID)
    local size
    local link
    if bagID == KEYRING_CONTAINER then
        size = GetKeyRingSize()
    else
        size = GetContainerNumSlots(bagID)
    end

    if size > 0 then
        -- empty bagid
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname][bagID] = {}
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname][bagID].size = size
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname][bagID].slots = {}

        -- save itemid for container
        if bagID > 0 then
            link = GetInventoryItemLink("player", ContainerIDToInventoryID(bagID))
            if link then
                Bagzen.data.global[Bagzen.realmname][Bagzen.unitname][bagID].link = link
            end
        end

        -- save items
        local texture, count, data
        for i = 1, size do
            texture, count = GetContainerItemInfo(bagID, i);
            if texture ~= nil then
                local itemLink = GetContainerItemLink(bagID, i)
                Bagzen.data.global[Bagzen.realmname][Bagzen.unitname][bagID].slots[i] = {
                    count = count,
                    link = itemLink,
                    texture = texture
                }
            end
        end
    else
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname][bagID] = nil
    end
end

function Bagzen:CreateGoldString(money)
    if type(money) ~= "number" then 
        return "-"
    end

    local gold = floor(money/ 100 / 100)
    local silver = floor(mod((money/100),100))
    local copper = floor(mod(money,100))

    local out = ""
    if gold > 0 then
        out = out .. "|cffffffff" .. gold .. "|cffffd700g"
    end

    if silver > 0 or gold > 0 then
        out = out .. "|cffffffff " .. silver .. "|cffc7c7cfs"
    end

    out = out .. "|cffffffff " .. copper .. "|cffeda55fc"

    return out
end

function Bagzen:GetItemIDByName(name)
    for itemID, data in pairs(Bagzen.ItemCache) do
        if data.name == name then
            return tonumber(itemID)
        end
    end
end

function Bagzen:ItemCacheInit()
    Bagzen.ItemCache = {}
    local count = 0
    for itemID=1, 101000 do
        local itemName, hyperLink, itemQuality = GetItemInfo(itemID)
        if itemName ~= nil and hyperLink ~= nil then
            Bagzen.ItemCache[itemID] = {
                name = itemName,
                link = hyperLink,
                quality = itemQuality
            }
            count = count + 1
        end
    end
end
