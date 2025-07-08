function Bagzen:LinkToItemID(hyperLink)
    if hyperLink then
        local _, _, itemID = string.find(hyperLink, "item:(%d+)")
        return tonumber(itemID)
    end
end

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