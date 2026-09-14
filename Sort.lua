-- based on Baganator and SortBags, help by ChatGPT

Bagzen.BagSortFrame = Bagzen.BagSortFrame or CreateFrame("Frame", "BagzenBagFrameSortFrame", BagzenBagFrame)
Bagzen.BankSortFrame = Bagzen.BankSortFrame or CreateFrame("Frame", "BagzenBankFrameSortFrame", BagzenBankFrame)
-- Pacing (ElvUI vanilla port, Bags/Sort.lua): a short tick, and one move at a
-- time that is only followed by the next once it has settled (see
-- PendingState), instead of a fixed delay per move. Fast servers finish in a
-- few ticks, slow ones are waited for. The legacy 1.12.1 client cannot keep up
-- with a 0.05s tick; Unreal Azeroth can.
if Bagzen.IsUA then
    Bagzen.SortTickInterval = 0.05
else
    Bagzen.SortTickInterval = 0.1
end
-- A move whose slots have settled but still hold what they held before, this
-- long after it was issued, was refused by the client.
Bagzen.SortMoveTimeout = 1.0
-- Ends the run: a pending move that has not settled this long (slot kept
-- locked, or the saved data never caught up), or steps that issue no move
-- for this long.
Bagzen.SortStallTimeout = 3.0
-- Refused moves allowed per run: the stack phase re-issues the same merge
-- after a refusal, and each issued move restarts the stall clock.
Bagzen.SortMaxRefusals = 4

Bagzen.BagSortFrame:Hide()
Bagzen.BankSortFrame:Hide()

Bagzen.BagSortFrame:SetScript("OnUpdate", function()
    Bagzen:SortFrameOnUpdate(this)
end)
Bagzen.BankSortFrame:SetScript("OnUpdate", function()
    Bagzen:SortFrameOnUpdate(this)
end)

Bagzen.BagSortFrame:SetScript("OnShow", function()
    this.pending = nil
    this.stallSince = nil
    this.refusals = 0
    this.tick = nil
end)
Bagzen.BankSortFrame:SetScript("OnShow", function()
    this.pending = nil
    this.stallSince = nil
    this.refusals = 0
    this.tick = nil
end)

Bagzen.BagSortFrame:SetScript("OnHide", function()
    this.task = nil
end)
Bagzen.BankSortFrame:SetScript("OnHide", function()
    this.task = nil
end)

local function idump(t, h)
    for k, v in pairs(t) do
        Bagzen:Print(h, k, "itemID=".. v.itemID, "itemCount=" .. v.itemCount, "bag=" .. v.bag, "slot=" .. v.slot)
    end
end

local allSortKeys = {
    "priority",
    "questItem",
    "quality",
    "itemType",
    "itemSubType",
    "itemInvLoc",
    "itemName",
    "invertedItemID",
    "invertedItemCount"
}

local orderHelper = {
  itemType = {
    ["consumable"] = 0,
    ["container"] = 1,
    ["weapon"] = 2,
    ["armor"] = 3,
    ["gem"] = 4,
    ["reagent"] = 5,
    ["projectile"] = 6,
    ["trade goods"] = 7,
    ["item enhancement"] = 8,
    ["recipe"] = 9,
    ["money"] = 10,
    ["quiver"] = 11,
    ["quest"] = 12,
    ["key"] = 13,
    ["permanent"] = 14,
    ["glyph"] = 16,
    ["miscellaneous"] = 15,
    ["profession"] = 16,
  },
  itemSubType = {
    ["trade goods"] = 1,   -- consumables
    ["parts"] = 2,         -- consumables
    ["devices"] = 3,       -- consumables
    ["jewelcrafting"] = 4, -- consumables
    ["cloth"] = 5,         -- consumables
    ["leather"] = 6,       -- consumables
    ["metal & stone"] = 7, -- consumables
    ["cooking"] = 8,       -- consumables
    ["herb"] = 9,          -- consumables
    ["elemental"] = 10,    -- consumables
  },
  invLoc = {
    ["INVTYPE_HEAD"] = 1,
    ["INVTYPE_NECK"] = 2,
    ["INVTYPE_SHOULDER"] = 3,
    ["INVTYPE_BODY"] = 4,
    ["INVTYPE_CHEST"] = 5,
    ["INVTYPE_ROBE"] = 5,
    ["INVTYPE_WAIST"] = 6,
    ["INVTYPE_LEGS"] = 7,
    ["INVTYPE_FEET"] = 8,
    ["INVTYPE_WRIST"] = 9,
    ["INVTYPE_HAND"] = 10,
    ["INVTYPE_FINGER"] = 11,
    ["INVTYPE_TRINKET"] = 13,
    ["INVTYPE_CLOAK"] = 15,
    ["INVTYPE_RANGED"] = 16,
    ["INVTYPE_RANGEDRIGHT"] = 16,
    ["INVTYPE_THROWN"] = 16,
    ["INVTYPE_WEAPON"] = 16,
    ["INVTYPE_WEAPONMAINHAND"] = 16,
    ["INVTYPE_SHIELD"] = 17,
    ["INVTYPE_HOLDABLE"] = 17,
    ["INVTYPE_WEAPONOFFHAND"] = 18,
    ["INVTYPE_TABARD"] = 19,
  }
}

local priorityItems = {
    [6948] = 1, -- Hearthstone
}

local function sortTable(t)
    if t ~= nil then
        table.sort(t, function(a, b)
            for _, key in pairs(allSortKeys) do
                if a == nil or b == nil or a[key] == nil or b[key] == nil then
                    -- Bagzen:Print(key, a.id, b.id)
                    return
                end
                if a[key] ~= b[key] then
                    return a[key] < b[key]
                end
            end
            return  a.id < b.id
        end)
    end
    return t
end

local function TableLength(t)
    local count = 0
    if t == nil then return count end
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function IndexToBagSlot(bags, index)
    local remaining = index
    for _, bag in pairs(bags) do
        if remaining <= bag.slots then
            return bag.bag, remaining
        else
            remaining = remaining - bag.slots
        end
    end
    return nil, nil
end

local function BagSlotToIndex(bags, bag, slot)
    local index = 0
    for _, b in pairs(bags) do
        if b.bag == bag then
            index = index + slot
            return index
        else
            index = index + b.slots
        end
    end
    return nil
end

local function ItemsEqual(a, b)
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end
    if a.itemID ~= b.itemID then return false end
    if a.itemCount ~= b.itemCount then return false end
    return true
end

local function SpecialBagsAndScrap(frame, bagdata)
    local scrapItemsByFamily = {
        [0] = {} -- standard scrap
    }
    local normalItemsByFamily = {
        [0] = {} -- standard items
    }

    local newbagdata = {}

    -- 1. Collect scraps and non-scraps by family
    for _, item in pairs(bagdata) do
        local itemID = item.itemID
        local _, _, _, _, _, _, _, _, itemInvLoc = Bagzen:GetItemInfo(itemID)
        local family = itemInvLoc ~= "INVTYPE_BAG" and Bagzen:GetItemFamily(itemID) or 0
        if Bagzen:isScrap(itemID) then
            if scrapItemsByFamily[family] == nil then
                scrapItemsByFamily[family] = {}
            end
            table.insert(scrapItemsByFamily[family], item)
        else
            if normalItemsByFamily[family] == nil then
                normalItemsByFamily[family] = {}
            end
            table.insert(normalItemsByFamily[family], item)
        end
    end

    -- Get slots family
    local slotsByFamily = {}

    for b = 1, TableLength(frame.Bags) do
        local bagInfo = frame.Bags[b]
        local bagID = bagInfo.bag
        local slots = bagInfo.slots
        local special = bagInfo.special or 0

        for s = 1, slots do
            local index = BagSlotToIndex(frame.Bags, bagID, s)
            if slotsByFamily[special] == nil then
                slotsByFamily[special] = {}
            end
            table.insert(slotsByFamily[special], index)
        end
    end

    -- 1. insert special scraps to their bags
    for family, items in pairs(scrapItemsByFamily) do
        if family > 0 then
            local slotLen = TableLength(slotsByFamily[family])
            -- sort items first
            items = sortTable(items)
            local scrapLen = TableLength(items)
            for i, item in pairs(items) do
                local index = slotLen - scrapLen + i
                if index <= 0 then
                    -- we're running out of special slots, move back to standard scrap
                    table.insert(scrapItemsByFamily[0], item)
                else
                    newbagdata[slotsByFamily[family][index]] = item
                end
            end
        end
    end

    -- 2. sort remaining scraps
    scrapItemsByFamily[0] = sortTable(scrapItemsByFamily[0])

    -- 3. insert scraps to normal bags
    for family, items in pairs(scrapItemsByFamily) do
        if family == 0 then
            local slotLen = TableLength(slotsByFamily[family])
            local scrapLen = TableLength(items)
            for i, item in pairs(items) do
                local index = slotLen - scrapLen + i
                newbagdata[slotsByFamily[family][index]] = item
            end
        end
    end

    -- 4. move special items to their bags
    for family, items in pairs(normalItemsByFamily) do
        if family > 0 then
            local index = 1
            items = sortTable(items) -- sort items first
            for _, item in pairs(items) do
                if slotsByFamily[family] ~= nil and                             -- we have special bag for this family
                        newbagdata[slotsByFamily[family][index]] == nil and     -- slot is empty, no scrap there
                        index <= TableLength(slotsByFamily[family]) then        -- we have enough slots
                    newbagdata[slotsByFamily[family][index]] = item
                else
                    table.insert(normalItemsByFamily[0], item)
                end
                index = index + 1
            end
        end
    end

    -- 5. sort normal items
    normalItemsByFamily[0] = sortTable(normalItemsByFamily[0])

    -- 6 move normal items in their place
    for family, items in pairs(normalItemsByFamily) do
        if family == 0 then
            index = 1
            for _, item in pairs(items) do
                if newbagdata[slotsByFamily[family][index]] == nil then
                    -- slot is empty, no scrap there
                    newbagdata[slotsByFamily[family][index]] = item
                else
                    table.insert(normalItemsByFamily[0], item)
                end
                index = index + 1
            end
        end
    end

    return newbagdata
end

local function OptimizeDuplicatePlacements(Bags, current, bagdata)
    local byItemID = {}
    for _, item in pairs(current) do
        if item and item.itemID then
            if not byItemID[item.itemID] then
                byItemID[item.itemID] = {}
            end
            table.insert(byItemID[item.itemID], item)
        end
    end

    for targetIndex, targetItem in pairs(bagdata) do
        if targetItem ~= nil then
            local itemID = targetItem.itemID
            local candidates = byItemID[itemID]
            if candidates ~= nil then
                for _, candidate in pairs(candidates) do
                    local sourceIndex = BagSlotToIndex(Bags, candidate.bag, candidate.slot)
                    if sourceIndex ~= targetIndex and not bagdata[sourceIndex] then
                        if ItemsEqual(targetItem, candidate) then
                            bagdata[targetIndex].bag = candidate.bag
                            bagdata[targetIndex].slot = candidate.slot
                            break
                        end
                    end
                end
            end
        end
    end
    return bagdata
end

function Bagzen:MoveContainerItem(srcBag, srcSlot, dstBag, dstSlot)
    local ret = false
    if Bagzen.IsWrath and InCombatLockdown() or UnitIsDead("player") then
        return ret
    end
    local _, _, srcLocked = GetContainerItemInfo(srcBag, srcSlot)
    local _, _, dstLocked = GetContainerItemInfo(dstBag, dstSlot)
    if not srcLocked and not dstLocked then
        PickupContainerItem(srcBag, srcSlot)
        PickupContainerItem(dstBag, dstSlot)
        ClearCursor()
        ret = true
    end
    return ret
end

-- Live contents of a slot as one comparable string ("" when empty).
local function LiveSlotKey(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return "" end
    local _, count = GetContainerItemInfo(bag, slot)
    return link .. "#" .. tostring(count)
end

-- True once a slot is unlocked and Bagzen's saved copy matches it: the planner
-- reads the saved data (refreshed from BAG_UPDATE), not the live slots, so a
-- move only counts as done once that has caught up. An empty slot is missing
-- from the saved data, or saved without a link (UA reports "" as the texture
-- of an empty slot, which the save treats as an item).
local function SlotSettled(parent, bag, slot)
    local _, _, locked = GetContainerItemInfo(bag, slot)
    if locked then return false end

    local saved = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag]
    local item = saved and saved.slots and saved.slots[slot]
    local savedKey = ""
    if item and item.link then
        savedKey = item.link .. "#" .. tostring(item.count)
    end
    return savedKey == LiveSlotKey(bag, slot)
end

-- Issues one move and records it as pending; no further move is issued until
-- PendingState no longer reports "wait".
local function IssueMove(frame, srcBag, srcSlot, dstBag, dstSlot)
    local srcKey = LiveSlotKey(srcBag, srcSlot)
    local dstKey = LiveSlotKey(dstBag, dstSlot)
    if not Bagzen:MoveContainerItem(srcBag, srcSlot, dstBag, dstSlot) then
        return false
    end
    frame.pending = {
        srcBag = srcBag,
        srcSlot = srcSlot,
        dstBag = dstBag,
        dstSlot = dstSlot,
        srcKey = srcKey,
        dstKey = dstKey,
        at = GetTime(),
    }
    frame.moves = (frame.moves or 0) + 1
    frame.stallSince = nil
    return true
end

-- "settled": both slots have settled and at least one of them changed.
-- "refused": both settled but unchanged after SortMoveTimeout; the next step
-- replans from the current state. "failed": not settled after
-- SortStallTimeout. "wait": anything else.
local function PendingState(frame, now)
    local p = frame.pending
    local parent = frame:GetParent()
    local age = now - p.at

    if SlotSettled(parent, p.srcBag, p.srcSlot) and SlotSettled(parent, p.dstBag, p.dstSlot) then
        if LiveSlotKey(p.srcBag, p.srcSlot) ~= p.srcKey or LiveSlotKey(p.dstBag, p.dstSlot) ~= p.dstKey then
            return "settled"
        end
        if age >= Bagzen.SortMoveTimeout then
            return "refused"
        end
        return "wait"
    end

    if age > Bagzen.SortStallTimeout then
        return "failed"
    end
    return "wait"
end

function Bagzen:TaskCombineStacksInit(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]
    frame.task = "CombineStacks"
end

function Bagzen:TaskCombineStacks(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]
    local incomplete = {}
    for _, bag in pairs(parent.Bags) do
        if bag ~= KEYRING_CONTAINER then -- AFAIK no stacking keys
            for slot = 1, GetContainerNumSlots(bag) do
                local itemID = Bagzen:LinkToItemID(GetContainerItemLink(bag, slot))
                if itemID then
                    local _, count = GetContainerItemInfo(bag, slot)
                    local _, _, _, _, _, _, _, stack = Bagzen:GetItemInfo(itemID)
                    if stack and stack > 1 and count ~= stack then
                        if incomplete[itemID] == nil then
                            incomplete[itemID] = {}
                        end
                        table.insert(incomplete[itemID], {
                            ["bag"] = bag,
                            ["slot"] = slot
                        })
                    end
                end
            end
        end
    end

    for _, data in pairs(incomplete) do
        local len = TableLength(data)
        if len >= 2 then
            IssueMove(frame, data[len - 1].bag, data[len - 1].slot, data[len].bag, data[len].slot)
            return
        end
    end

    -- Bagzen:TaskSortBagsInit(parent)
    frame.task = "SortBags"
    frame.moves = 0
    frame.stallSince = nil
end

function Bagzen:MoveItem(parent, current, bagdata)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]
    frame.moves = frame.moves or 0

    -- remove those items that are already in their correct place
    for k, v in pairs(bagdata) do
        if ItemsEqual(current[k], v) then
            bagdata[k] = nil
        end
    end

    -- exit if done
    if TableLength(bagdata) == 0 then
        frame:Hide()
        return
    end

    -- safety exit
    if frame.moves >= 100 then
        frame:Hide()
        return
    end

    -- 1. swap
    for k, v in pairs(bagdata) do
        local dstBag, dstSlot = IndexToBagSlot(frame.Bags, k)
        if current[k] ~= nil and v ~= nil and not ItemsEqual(current[k], v) then
            IssueMove(frame, v.bag, v.slot, dstBag, dstSlot)
            return
        end
    end

    -- 2. move to empty slot
    for k, v in pairs(bagdata) do
        local dstBag, dstSlot = IndexToBagSlot(frame.Bags, k)
        if not ItemsEqual(current[k], v) then
            IssueMove(frame, v.bag, v.slot, dstBag, dstSlot)
            return
        end
    end
end

function Bagzen:BagSortSetBags(parent)
    local Bags = {}
    for _, bag in pairs(parent.Bags) do
        if bag ~= KEYRING_CONTAINER then
            if Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] ~= nil then
                local numslots = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].size or 0
                local itemLink = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].link or ""
                local special = nil
                if itemLink then
                    local itemID = Bagzen:LinkToItemID(itemLink)
                    local itemFamily = Bagzen:GetItemFamily(itemID)
                    if itemFamily and itemFamily > 0 then
                        special = itemFamily
                    end
                end
                table.insert(Bags, {
                    bag = bag,
                    slots = numslots,
                    special = special
                })
            end
        else
            table.insert(Bags, {
                bag = bag,
                slots = GetKeyRingSize() or 0,
                special = 256 -- keyring
            })
        end
    end
    return Bags
end

-- Added to handle page numbers
function Bagzen:SortItemNameHelper(itemName)
    local out = itemName
    if string.len(itemName) > 33 and string.sub(itemName, 1, 33) == "Shredder Operating Manual - Page " then
        out = string.sub(itemName, 1, 33) .. string.format("%02d", tonumber(string.sub(itemName, 34)))
    elseif string.len(itemName) > 36 and string.sub(itemName, 1, 36) == "Green Hills of Stranglethorn - Page " then
        out = string.sub(itemName, 1, 36) .. string.format("%02d", tonumber(string.sub(itemName, 37)))
    end
    return out
end

function Bagzen:BagSortCurrent(parent)
    -- local _G = _G or getfenv()
    ---local frame = _G[parent:GetName() .. "SortFrame"]

    local bagdata = {}
    local count = 0
    for _, bag in pairs(parent.Bags) do
        if Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] then
            local numslots = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].size
            -- Bagzen.tmp[bag] =
            for slot = 1, numslots do
                count = count + 1
                local item = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].slots[slot]
                if item ~= nil and item.link ~= nil then
                    local data = {
                        ["bag"] = bag,
                        ["slot"] = slot,
                        ["id"] = count,
                    }
                    local itemID = Bagzen:LinkToItemID(item.link)
                    local itemName, _, itemRarity, _, _, itemType, itemSubType, _, itemInvLoc  = Bagzen:GetItemInfo(itemID)
                    data["priority"] = priorityItems[itemID] or 100
                    data["questItem"] = -(Bagzen:isQuestItem(itemID) and 1 or 0)
                    data["quality"] = (itemRarity or -1) * -1
                    data["itemInvLoc"] = (itemInvLoc and orderHelper.invLoc[string.upper(itemInvLoc)]) or 100
                    data["itemType"] = (itemType and orderHelper.itemType[string.lower(itemType)]) or 100
                    data["itemSubType"] = (itemSubType and orderHelper.itemSubType[string.lower(itemSubType)]) or 100
                    data["itemName"] = Bagzen:SortItemNameHelper(itemName)
                    data["itemID"] = itemID
                    data["itemCount"] = item.count
                    data["invertedItemID"] = -itemID
                    data["invertedItemCount"] = item.count
                    -- setmetatable(data, itemMetatable)
                    bagdata[count] = data
                end
            end
        end
    end

    return bagdata
end

function Bagzen:TaskSortBags(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]

    local Bags = Bagzen:BagSortSetBags(parent)
    frame.Bags = Bags

    local current = Bagzen:BagSortCurrent(parent)
    local bagdata = SpecialBagsAndScrap(frame, current)
    bagdata = OptimizeDuplicatePlacements(Bags, current, bagdata)

    Bagzen:MoveItem(parent, current, bagdata)
end


function Bagzen:SortFrameOnUpdate(frame)
    if frame.task == nil then
        Bagzen:Print("No task, exiting")
        frame:Hide()
        return
    end

    local now = GetTime()
    if (frame.tick or 0) > now then return end
    frame.tick = now + Bagzen.SortTickInterval

    if frame.pending then
        local state = PendingState(frame, now)
        if state == "wait" then
            return
        end
        frame.pending = nil
        if state == "refused" then
            frame.refusals = (frame.refusals or 0) + 1
        end
        if state == "failed" or frame.refusals > Bagzen.SortMaxRefusals then
            Bagzen:Print("Something went wrong")
            frame.task = nil
            frame:Hide()
            return
        end
    end

    -- IssueMove clears stallSince; a step that issues nothing leaves it running
    frame.stallSince = frame.stallSince or now
    if now - frame.stallSince > Bagzen.SortStallTimeout then
        Bagzen:Print("Something went wrong")
        frame.task = nil
        frame:Hide()
        return
    end

    if frame.task == "CombineStacks" then
        Bagzen:TaskCombineStacks(frame:GetParent())
    elseif frame.task == "SortBags" then
        Bagzen:TaskSortBags(frame:GetParent())
    else
        Bagzen:Print("Unknown task, exiting")
        frame:Hide()
        return
    end
end

Bagzen.tmp = {}

function Bagzen:SortBags(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]
    if Bagzen.IsWrath and InCombatLockdown() or UnitIsDead("player") then
        -- cant't sort bags in combat or when dead
        frame:Hide()
        return
    end
    Bagzen:TaskCombineStacksInit(parent)
    frame:Show()
end
