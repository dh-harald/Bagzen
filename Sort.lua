-- based on Baganator and SortBags, help by ChatGPT

Bagzen.BagSortFrame = Bagzen.BagSortFrame or CreateFrame("Frame", "BagzenBagFrameSortFrame")
Bagzen.BankSortFrame = Bagzen.BankSortFrame or CreateFrame("Frame", "BagzenBankFrameSortFrame")
if Bagzen.IsTurtle then
    Bagzen.BagSortFrame.delay = 1.2
    Bagzen.BankSortFrame.delay = 1.2
else
    Bagzen.BagSortFrame.delay = 0.2
    Bagzen.BankSortFrame.delay = 0.2
end

Bagzen.SortFrameRetry = 10

Bagzen.BagSortFrame:Hide()
Bagzen.BankSortFrame:Hide()

Bagzen.BagSortFrame:SetScript("OnUpdate", function()
    Bagzen:SortFrameOnUpdate(this)
end)
Bagzen.BankSortFrame:SetScript("OnUpdate", function()
    Bagzen:SortFrameOnUpdate(this)
end)

Bagzen.BagSortFrame:SetScript("OnShow", function()
    this.taskRunning = false
    this.retry = Bagzen.SortFrameRetry
end)
Bagzen.BankSortFrame:SetScript("OnShow", function()
    this.taskRunning = false
    this.retry = Bagzen.SortFrameRetry
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
    return t
end

local function TableLength(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function IndexToBagSlot(bags, index)
    local remaining = index
    for _, bag in ipairs(bags) do
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
    for _, b in ipairs(bags) do
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
    local scrapItemsByFamily = {}
    local normalItemsByFamily = {}

    local newbagdata = {}

    -- 1. Collect scraps and non-scraps by family
    for index, item in pairs(bagdata) do
        local itemID = item.itemID
        local family = Bagzen:GetItemFamily(itemID) or 0
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

    -- 1. sort special tables as it could be in wrong order
    for family in pairs(scrapItemsByFamily) do
        if family > 0 then
            scrapItemsByFamily[family] = sortTable(scrapItemsByFamily[family])
        end
    end

    -- 2. insert special scraps to their bags, check overflow
    local overflow = false
    for family, items in pairs(scrapItemsByFamily) do
        if family > 0 then
            local slotLen = TableLength(slotsByFamily[family])
            local scrapLen = TableLength(items)
            for i, item in items do
                local index = slotLen - scrapLen + i
                if index <= 0 then
                    -- we're running out of special slots, move back to standard scrap
                    table.insert(scrapItemsByFamily[0], item)
                    overflow = true
                else
                    newbagdata[slotsByFamily[family][index]] = item
                end
            end
        end
    end

    -- 3. resort scrap items it needed
    if overflow then
        scrapItemsByFamily[0] = sortTable(scrapItemsByFamily[0])
    end

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

    -- 4. move special items to their bags, check overflow
    overflow = false
    for family, items in pairs(normalItemsByFamily) do
        if family > 0 then
            local index = 1
            for _, item in pairs(items) do
                if slotsByFamily[family] ~= nil and                             -- we have special bag for this family
                        newbagdata[slotsByFamily[family][index]] == nil and     -- slot is empty, no scrap there
                        index <= TableLength(slotsByFamily[family]) then        -- we have enough slots
                    newbagdata[slotsByFamily[family][index]] = item
                else
                    table.insert(normalItemsByFamily[0], item)
                    overflow = true
                end
                index = index + 1
            end
        end
    end

    -- 5. resort normal items it needed
    if overflow then
        normalItemsByFamily[0] = sortTable(normalItemsByFamily[0])
    end

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
                    overflow = true
                end
                index = index + 1
            end
        end
    end

    -- return bagdata
    return newbagdata
end

function Bagzen:MoveContainerItem(srcBag, srcSlot, dstBag, dstSlot)
    ret = false
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

function Bagzen:TaskCombineStacksInit(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]
    frame.task = "CombineStacks"
end

function Bagzen:TaskCombineStacks(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]
    frame.task_running = true
    local incomplete = {}
    for _, bag in pairs(parent.Bags) do
        if bag ~= KEYRING_CONTAINER then
            for slot = 1, GetContainerNumSlots(bag) do
                local itemID = Bagzen:LinkToItemID(GetContainerItemLink(bag, slot))
                if itemID then
                    local _, count = GetContainerItemInfo(bag, slot)
                    local _, _, _, _, _, _, _, stack = Bagzen:GetItemInfo(itemID)
                    if stack > 1 and count ~= stack then
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
        local count = 0
        local src
        for _, item in pairs(data) do
            count = count + 1
            if count == 1 then
                src = item
            elseif count == 2 then
                if Bagzen:MoveContainerItem(item.bag, item.slot, src.bag, src.slot) then
                    frame.retry = Bagzen.SortFrameRetry -- reset registry
                end
                return
            end
        end
    end

    Bagzen:TaskSortBagsInit(parent)
    frame.task = "SortBags"
    frame.task_running = false
end

function Bagzen:ComputeMovePlan(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]

    local current = frame.current
    local bagdata = frame.bagdata
    local movePlan = {}
    local timeout = 0

    bagdata = SpecialBagsAndScrap(frame, bagdata)

    while TableLength(bagdata) > 0 do
        -- 1. Remove items that are already in their correct place
        local used = {}
        for k, v in pairs(bagdata) do
            local bag, slot = IndexToBagSlot(frame.Bags, k)
            local curIdx = BagSlotToIndex(frame.Bags, bag, slot)
            local curItem = current[curIdx]
            if ItemsEqual(curItem, v) then
                bagdata[k] = nil
                used[curIdx] = true
            end
        end

        -- 2. Update the bag/slot fields of the remaining bagdata items
        for k, v in pairs(bagdata) do
            for curIdx, curItem in pairs(current) do
                if not used[curIdx] and ItemsEqual(curItem, v) then
                    local bag, slot = IndexToBagSlot(frame.Bags, curIdx)
                    v.bag = bag
                    v.slot = slot
                    used[curIdx] = true
                    break
                end
            end
        end

        -- 3. First, swaps: every pair where both places have an item and they are not equal
        local swapped = false
        for k, v in pairs(bagdata) do
            local dstBag, dstSlot = IndexToBagSlot(frame.Bags, k)
            local dstIdx = BagSlotToIndex(frame.Bags, dstBag, dstSlot)
            local srcIdx = BagSlotToIndex(frame.Bags, v.bag, v.slot)
            if current[dstIdx] ~= nil and current[srcIdx] ~= nil and not ItemsEqual(current[dstIdx], v) and srcIdx ~= dstIdx then
                table.insert(movePlan, {
                    srcBag = v.bag,
                    srcSlot = v.slot,
                    dstBag = dstBag,
                    dstSlot = dstSlot
                })
                -- Update current!
                local tmp = current[dstIdx]
                current[dstIdx] = current[srcIdx]
                current[srcIdx] = tmp

                -- Update bagdata!
                for k2, v2 in pairs(bagdata) do
                    if v2.bag == dstBag and v2.slot == dstSlot then
                        bagdata[k2].bag = v.bag
                        bagdata[k2].slot = v.slot
                    end
                end
                bagdata[k] = nil
                swapped = true
                break -- only perform one swap per iteration
            end
        end

        if swapped then
            timeout = timeout + 1
            if timeout > 100 then break end
        else
            -- 4. If there are no more swaps, move to empty slot
            local moved = false
            for k, v in pairs(bagdata) do
                local dstBag, dstSlot = IndexToBagSlot(frame.Bags, k)
                local dstIdx = BagSlotToIndex(frame.Bags, dstBag, dstSlot)
                local srcIdx = BagSlotToIndex(frame.Bags, v.bag, v.slot)
                if current[dstIdx] == nil and current[srcIdx] ~= nil then
                    table.insert(movePlan, {
                        srcBag = v.bag,
                        srcSlot = v.slot,
                        dstBag = dstBag,
                        dstSlot = dstSlot
                    })
                    current[dstIdx] = current[srcIdx]
                    current[srcIdx] = nil
                    bagdata[k] = nil
                    moved = true
                    break -- only perform one move per iteration
                end
            end

            timeout = timeout + 1
            if timeout > 100 then break end
            if not moved then
                -- If nothing could be moved, we're done
                break
            end
        end
    end

    -- Bagzen:Print(TableLength(movePlan), "moves")
    frame.movePlan = movePlan
end

function Bagzen:TaskSortBagsInit(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]

    local Bags = Bagzen:BagSortSetBags(parent)
    local current = Bagzen:BagSortCurrent(parent)
    frame.Bags = Bags
    local bagdata = {}

    for _, v in pairs(current) do
        table.insert(bagdata, v)
    end

    bagdata = sortTable(bagdata)

    frame.current = current
    frame.bagdata = bagdata

    Bagzen:ComputeMovePlan(parent)
end

function Bagzen:BagSortSetBags(parent)
    local Bags = {}
    for _, bag in pairs(parent.Bags) do
        if bag ~= KEYRING_CONTAINER then -- sanity check
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
        end
    end
    return Bags
end

function Bagzen:BagSortCurrent(parent)
    -- local _G = _G or getfenv()
    ---local frame = _G[parent:GetName() .. "SortFrame"]

    local bagdata = {}
    local count = 0
    for _, bag in pairs(parent.Bags) do
    -- for _, bag in pairs(parent.Bags) do
        if bag ~= KEYRING_CONTAINER then -- sanity check
            if Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] then
                local numslots = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].size
                -- Bagzen.tmp[bag] =
                for slot = 1, numslots do
                    count = count + 1
                    local item = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].slots[slot]
                    if item ~= nil then
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
                        data["itemInvLoc"] = orderHelper.invLoc[string.upper(itemInvLoc)] or 100
                        data["itemType"] = orderHelper.itemType[string.lower(itemType)] or 100
                        data["itemSubType"] = orderHelper.itemSubType[string.lower(itemSubType)] or 100
                        data["itemName"] = itemName
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
    end

    return bagdata
end

function Bagzen:TaskSortBags(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]
    local step = table.remove(frame.movePlan, 1)
    if step then
        -- Bagzen:Print("Moving", step.srcBag, step.srcSlot, "TO", step.dstBag, step.dstSlot)
        frame.task_running = true
        if Bagzen:MoveContainerItem(step.srcBag, step.srcSlot, step.dstBag, step.dstSlot) then
            frame.retry = Bagzen.SortFrameRetry -- reset registry
        else
            -- locked, try it again for the next run
            table.insert(frame.movePlan, 1, step)
        end
        frame.task_running = false
        return
    end
    frame:Hide()
    frame.task_running = false
end

function Bagzen:SortFrameOnUpdate(frame)
    if frame.task == nil then
        Bagzen:Print("No task, exiting")
        frame:Hide()
        return
    end

    if (frame.tick or 1) > GetTime() then return else frame.tick = GetTime() + frame.delay end

    frame.retry = frame.retry - 1
    if frame.retry <= 0
    then
        Bagzen:Print("Something went wrong")
        frame.task_running = false
        frame.task = nil
        frame:Hide()
        return
    end

    if frame.task_running then
        return
    end

    if frame.task == "CombineStacks" then
        Bagzen:TaskCombineStacks(frame.parent)
    elseif frame.task == "SortBags" then
        Bagzen:TaskSortBags(frame.parent)
    else
        Bagzen:Print("Unknown task, exiting")
        frame:Hide()
        return
    end
end

Bagzen.tmp = {}

function Bagzen:SortBags(parent)
    if InCombatLockdown() or UnitIsDead("player") then return end -- cant't sort bags in combat or when dead
    Bagzen:TaskCombineStacksInit(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "SortFrame"]
    frame.parent = parent
    frame:Show()
end
