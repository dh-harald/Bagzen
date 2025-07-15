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

function Bagzen:GetItemInfo(arg)
    -- make it working on vanilla and wotlk
    if Bagzen.IsWOTLK then
        return GetItemInfo(arg)
    else
        local r1, r2, r3, r4, r5, r6, r7, r8, r9 = GetItemInfo(arg)
        return r1, r2, r3, r4, nil, r5, r6, r7, r8, r9, nil -- no itemlevel in vanilla, TODO: itemprice
    end
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
        if data.name == name then
            return tonumber(itemID)
        end
    end
end

function Bagzen:ItemCacheInit()
    Bagzen.ItemCache = {}
    local count = 0
    for itemID=1, 101000 do
        local itemName, hyperLink, itemQuality = Bagzen:GetItemInfo(itemID)
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
