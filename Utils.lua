Bagzen.ItemCache = {}

function Bagzen:UnsignedToSigned(num)
    if num > 32768 then
        num = num - 65536
    end
    return num
end

function Bagzen:SignetToUnsigned(num)
    if num < 0 then
        num = num + 65536
    end
    return num
end

function Bagzen:HackID(frame)
    if Bagzen.IsWOTLK then return end -- not needed for WOTLK // taints the frame anyway
    -- HACK: replace GetID/SetID functions as not handling negative IDs
    frame.OldGetID = frame.GetID
    frame.OldSetID = frame.SetID
    frame.SetID = function(self, id)
        self:OldSetID(Bagzen:SignetToUnsigned(id))
    end
    frame.GetID = function(self)
        return Bagzen:UnsignedToSigned(self:OldGetID())
    end
end

---Middle layer for GetItemInfo, make it working on vanilla and wotlk
---@param arg (itemID|itemLink)
---@return itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, stackCount, itemEquipLoc, itemTexture, itemSellPrice
function Bagzen:GetItemInfo(arg)
    if arg == nil then return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil end -- sanity check
    local itemID
    if type(arg) == "string" then
        itemID = Bagzen:LinkToItemID(arg)
    else
        itemID = arg
    end

    if Bagzen.ItemCache[itemID] then
        local c = Bagzen.ItemCache[itemID]
        return c.itemName, c.itemLink, c.itemRarity, c.itemLevel, c.itemMinLevel, c.itemType, c.itemSubType, c.itemStackCount, c.itemEquipLoc, c.itemTexture, c.itemSellPrice
    end
    if Bagzen.IsWOTLK then
        local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID)
        if itemName ~= nil and itemLink ~= nil then
            Bagzen.ItemCache[itemID] = {
                itemName = itemName,
                itemLink = itemLink,
                itemRarity = itemRarity,
                itemLevel = itemLevel,
                itemMinLevel = itemMinLevel,
                itemType = itemType,
                itemSubType = itemSubType,
                itemStackCount = itemStackCount,
                itemEquipLoc = itemEquipLoc,
                itemTexture = itemTexture,
                itemSellPrice = itemSellPrice
            }
            return itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice
        end
    else
        local itemName, itemLink, itemRarity, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemID)
        if itemName ~= nil and itemLink ~= nil then
            local itemSellPrice = Bagzen.sellData[itemID]
            Bagzen.ItemCache[itemID] = {
                itemName = itemName,
                itemLink = itemLink,
                itemRarity = itemRarity,
                itemMinLevel = itemMinLevel,
                itemType = itemType,
                itemSubType = itemSubType,
                itemStackCount = itemStackCount,
                itemEquipLoc = itemEquipLoc,
                itemTexture = itemTexture,
                itemSellPrice = itemSellPrice
            }
            return itemName, itemLink, itemRarity, nil, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice
        end
    end
    return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
end

function Bagzen:GetItemFamily(itemID)
    if Bagzen.IsWOTLK then
        return GetItemFamily(itemID)
    end
    local _, _, _, _, _, itemType, itemSubType = Bagzen:GetItemInfo(itemID)
    if itemType ~= nil then
        itemType = string.lower(itemType)
    end
    if itemSubType ~= nil then
        itemSubType = string.lower(itemSubType)
    end

    if itemType == nil and itemSubType == nil then return nil end

    if itemType == "projectile" or itemType == "quiver" then
        -- https://wowwiki-archive.fandom.com/wiki/ItemFamily
        if itemSubType == "arrow" or itemSubType == "quiver" then
            return 1 -- quiver / arrow
        elseif itemSubType == "bullet" or itemSubType == "ammo pouch" then
            return 2 -- bullet / ammo pouch
        end
    elseif itemSubType == "soul bag" or itemID == 6265 then
        return 4 -- soul bag
    end
end

function Bagzen:GetContainerNumFreeSlots(bag, realmName, unitName)
    realmName = realmName or Bagzen.realmname
    unitName = unitName or Bagzen.unitname
    if Bagzen.data.global[realmName][unitName].bags[bag] then
        local slots = Bagzen.data.global[realmName][unitName].bags[bag].size
        if slots > 0 then
            if Bagzen.data.global[realmName][unitName].bags[bag].slots then
                for _, _ in pairs(Bagzen.data.global[realmName][unitName].bags[bag].slots) do
                    slots = slots - 1
                end
                return slots
            end
        end
    end
    return nil
end

function Bagzen:isQuestItem(itemID)
    local _, _, _, _, _, itemtype = Bagzen:GetItemInfo(itemID)
    return itemtype == "Quest"
end

function Bagzen:LinkToItemID(hyperLink)
    if hyperLink then
        local _, _, itemID = string.find(hyperLink, "item:(%d+)")
        return tonumber(itemID)
    end
end

function Bagzen:GetItemIDByName(name)
    for itemID, data in pairs(Bagzen.ItemCache) do
        if data.itemName == name then
            return tonumber(itemID)
        end
    end
end

function Bagzen:ItemCacheInit()
    local count = 0
    for itemID=1, 101000 do
        local _ = Bagzen:GetItemInfo(itemID) -- just fill the cache with GetItemInfo
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
