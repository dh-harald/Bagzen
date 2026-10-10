Bagzen.ItemCache = {}

-- Vanilla's GetItemInfo returns no sell price, so the vendor value comes from
-- this shared library, which only the vanilla build loads. Shared with ElvUI
-- through LibStub, so whichever addon loads first carries the data for both.
local ItemPrice = LibStub("ItemPrice-1.1", true)

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

function Bagzen:FixBagNumber(bag)
    -- HACK: UnReal Azeroth thinks I'm stupid, because I add minus sign (-) to frame name (IamStupidAddonDeveloper)
    if Bagzen.IsUA == false then
        return bag
    else
        if bag < 0 then
            return "_" .. abs(bag)
        else
            return bag
        end
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
        if itemName ~= nil and itemLink ~= nil and itemTexture ~= nil then
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
        if itemName ~= nil and itemLink ~= nil and itemTexture ~= nil then
            local itemSellPrice = ItemPrice and ItemPrice:GetPriceById(itemID)
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

-- Vanilla has no GetItemFamily, and an item's bag family is not exposed by
-- GetItemInfo, so the items a profession bag accepts are listed by id. The
-- family values are the wrath client's ItemFamily bits. An item missing from
-- these lists is never placed into such a bag by the sorter, so the lists
-- only need to be correct, not complete.
local herbItems = {
    [765] = true,   -- Silverleaf
    [785] = true,   -- Mageroyal
    [2447] = true,  -- Peacebloom
    [2449] = true,  -- Earthroot
    [2450] = true,  -- Briarthorn
    [2452] = true,  -- Swiftthistle
    [2453] = true,  -- Bruiseweed
    [3355] = true,  -- Wild Steelbloom
    [3356] = true,  -- Kingsblood
    [3357] = true,  -- Liferoot
    [3358] = true,  -- Khadgar's Whisker
    [3369] = true,  -- Grave Moss
    [3818] = true,  -- Fadeleaf
    [3819] = true,  -- Wintersbite
    [3820] = true,  -- Stranglekelp
    [3821] = true,  -- Goldthorn
    [4625] = true,  -- Firebloom
    [8153] = true,  -- Wildvine
    [8831] = true,  -- Purple Lotus
    [8836] = true,  -- Arthas' Tears
    [8838] = true,  -- Sungrass
    [8839] = true,  -- Blindweed
    [8845] = true,  -- Ghost Mushroom
    [8846] = true,  -- Gromsblood
    [13463] = true, -- Dreamfoil
    [13464] = true, -- Golden Sansam
    [13465] = true, -- Mountain Silversage
    [13466] = true, -- Plaguebloom
    [13467] = true, -- Icecap
    [13468] = true, -- Black Lotus
    [19726] = true, -- Bloodvine
}

local enchantingItems = {
    -- dusts
    [10940] = true, -- Strange Dust
    [11083] = true, -- Soul Dust
    [11137] = true, -- Vision Dust
    [11176] = true, -- Dream Dust
    [16204] = true, -- Illusion Dust
    -- essences
    [10938] = true, -- Lesser Magic Essence
    [10939] = true, -- Greater Magic Essence
    [10998] = true, -- Lesser Astral Essence
    [11082] = true, -- Greater Astral Essence
    [11134] = true, -- Lesser Mystic Essence
    [11135] = true, -- Greater Mystic Essence
    [11174] = true, -- Lesser Nether Essence
    [11175] = true, -- Greater Nether Essence
    [16202] = true, -- Lesser Eternal Essence
    [16203] = true, -- Greater Eternal Essence
    -- shards and crystals
    [10978] = true, -- Small Glimmering Shard
    [11084] = true, -- Large Glimmering Shard
    [11138] = true, -- Small Glowing Shard
    [11139] = true, -- Large Glowing Shard
    [11177] = true, -- Small Radiant Shard
    [11178] = true, -- Large Radiant Shard
    [14343] = true, -- Small Brilliant Shard
    [14344] = true, -- Large Brilliant Shard
    [20725] = true, -- Nexus Crystal
    -- rods
    [6217] = true,  -- Copper Rod
    [6218] = true,  -- Runed Copper Rod
    [6338] = true,  -- Silver Rod
    [6339] = true,  -- Runed Silver Rod
    [11128] = true, -- Golden Rod
    [11130] = true, -- Runed Golden Rod
    [11144] = true, -- Truesilver Rod
    [11145] = true, -- Runed Truesilver Rod
    [16206] = true, -- Arcanite Rod
    [16207] = true, -- Runed Arcanite Rod
}

-- Container subtypes of the 1.12.1 client (enUS) that only accept one family.
local specialBagSubtypes = {
    ["soul bag"] = 4,
    ["herb bag"] = 32,
    ["enchanting bag"] = 64,
}

-- Family of a container whose subtype is neither a plain bag nor listed
-- above: no item maps to it, so the sorter leaves nothing in it.
local FAMILY_UNKNOWN_BAG = 65536

function Bagzen:GetItemFamily(itemID)
    -- https://www.wowhead.com/classic/guide/classic-keyring-dungeon-keys-guide
    local keys = {
        [5396] = true,  -- Key to Searing Gorge
        [6893] = true,  -- Workshop Key
        [7146] = true,  -- The Scarlet Key
        [11000] = true, -- Shadowforge Key
        [11140] = true, -- Prison Cell Key
        [12382] = true, -- Key to the City
        [13704] = true, -- Skeleton Key
        [18249] = true, -- Crescent Key
    }

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
    elseif itemType == "container" then
        if itemSubType == "bag" then return nil end
        return specialBagSubtypes[itemSubType] or FAMILY_UNKNOWN_BAG
    elseif itemID == 6265 then
        return 4 -- soul shard
    elseif herbItems[itemID] then
        return 32
    elseif enchantingItems[itemID] then
        return 64
    elseif keys[itemID] then
        return 256 -- keyring
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
    local exclude = {
        [1688] = true, -- Long Soft Tail
        [2799] = true, -- Gorilla Fang
    }
    if exclude[itemID] then
        return false
    end
    local _, _, _, _, _, itemtype = Bagzen:GetItemInfo(itemID)
    return itemtype == "Quest"
end

function Bagzen:LinkToItemID(hyperLink)
    if hyperLink then
        local _, _, itemID = string.find(hyperLink, "item:(%d+)")
        return tonumber(itemID)
    end
end

-- Name shown in a saved link: chat links carry it, bare "item:" strings (as
-- GetItemInfo returns on Unreal Azeroth) get it from GetItemInfo.
local function LinkName(link)
    local _, _, name = string.find(link, "%[(.+)%]")
    if name then return name end
    return (Bagzen:GetItemInfo(Bagzen:LinkToItemID(link)))
end

-- Item id of an item known only by name: 1.12 has no link getter for mail
-- attachments or the buyback and auction sell slots, and Unreal Azeroth none
-- for equipped bags. Tries Bagzen's item cache first (items looked up through
-- Bagzen:GetItemInfo this session), then the saved bags (and their contents),
-- bank and mail of every character on the realm. An empty slot reports "" as
-- name on UA.
function Bagzen:GetItemIDByName(name)
    if not name or name == "" then return end

    for itemID, data in pairs(Bagzen.ItemCache) do
        if data.itemName == name then
            return tonumber(itemID)
        end
    end

    for _, data in pairs(Bagzen.data.global[Bagzen.realmname] or {}) do
        for _, bag in pairs(data.bags or {}) do
            if type(bag) == "table" then
                if bag.link and LinkName(bag.link) == name then
                    return Bagzen:LinkToItemID(bag.link)
                end
                for _, item in pairs(bag.slots or {}) do
                    if item.link and LinkName(item.link) == name then
                        return Bagzen:LinkToItemID(item.link)
                    end
                end
            end
        end
        for _, item in pairs(data.mails or {}) do
            if item.name == name and item.itemid then
                return item.itemid
            end
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

function Bagzen:GetContainerNumSlots(bag)
    local numslots = GetContainerNumSlots(bag)
    if bag == -1 and numslots == 0
    then
        numslots = 24 -- Unreal Azeroth return 0 for bankslot
    end
    return numslots
end

-- Unreal Azeroth: an equipped bag has no link (GetInventoryItemLink covers the
-- equipment slots 1-19 only), so it is identified by name. The name comes from
-- a hidden tooltip filled with SetInventoryItem, which does work for bag slots
-- there. The name is resolved to an item id through GetItemIDByName; failing
-- that, GetItemInfo is scanned over the item id range, as it answers for every
-- item in the local cache and an equipped bag always is. Every candidate must
-- match both name and icon. The scan is spread over frames and runs at most
-- once per bag per session; the resulting link is saved with the bag, so later
-- sessions resolve it through GetItemIDByName.

local UA_BAG_SCAN_MAX_ID = 200000
local UA_BAG_SCAN_IDS_PER_FRAME = 20000

-- "name|icon" -> item id; false once a full scan found nothing; true while a
-- scan is queued or running
local uaBagIDs = {}
local uaBagScanQueue = {}
local uaBagScanner = nil
local uaBagTooltip = nil

-- Last path segment in lower case, so icon paths compare equal regardless of
-- separator and case.
local function IconKey(texture)
    if not texture then return "" end
    texture = string.lower(string.gsub(texture, "\\", "/"))
    local _, _, last = string.find(texture, "([^/]+)$")
    return last or texture
end

local function InventoryItemName(slot)
    local _G = _G or getfenv()
    if not uaBagTooltip then
        uaBagTooltip = CreateFrame("GameTooltip", "BagzenUABagTooltip", nil, "GameTooltipTemplate")
    end
    uaBagTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    uaBagTooltip:SetInventoryItem("player", slot)
    local line = _G["BagzenUABagTooltipTextLeft1"]
    local name = line and line:GetText()
    -- a filled GameTooltipTemplate left shown stays on screen
    uaBagTooltip:Hide()
    if name and name ~= "" then
        return name
    end
end

local function MatchesBag(itemID, name, iconKey)
    local itemName, _, _, _, _, _, _, _, _, texture = Bagzen:GetItemInfo(itemID)
    return itemName == name and IconKey(texture) == iconKey
end

local function RefreshLiveContainers()
    if BagzenBagFrame.Virtual == false then
        Bagzen:ContainerUpdate(BagzenBagFrame, Bagzen.realmname, Bagzen.unitname)
    end
    if BagzenBankFrame.Virtual == false then
        Bagzen:ContainerUpdate(BagzenBankFrame, Bagzen.realmname, Bagzen.unitname)
    end
end

local function UABagScanOnUpdate()
    local job = uaBagScanQueue[1]
    if not job then
        uaBagScanner:Hide()
        return
    end

    local last = math.min(job.nextID + UA_BAG_SCAN_IDS_PER_FRAME - 1, UA_BAG_SCAN_MAX_ID)
    local found = false
    for itemID = job.nextID, last do
        local itemName, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
        if itemName == job.name and IconKey(texture) == job.iconKey then
            found = itemID
            break
        end
    end

    if found or last >= UA_BAG_SCAN_MAX_ID then
        uaBagIDs[job.key] = found
        table.remove(uaBagScanQueue, 1)
        if found then
            RefreshLiveContainers()
        end
    else
        job.nextID = last + 1
    end
end

-- inventory slot -> { signature = "icon|slots", name = bag name }
local uaBagNames = {}

-- Link ("item:id:0:0:0") of the bag equipped in inventory `slot` holding
-- `numslots` slots, or nil when it is not identified (yet). An unknown bag
-- queues a scan, and the live windows are refreshed once the scan finds it.
-- The hidden tooltip is only filled again when the slot's icon or size
-- changed: hiding it runs GameTooltip_OnHide, which resets the tooltip
-- backdrop colours, and on UA those are shared by every GameTooltipTemplate.
function Bagzen:GetUABagLink(slot, numslots)
    local texture = GetInventoryItemTexture("player", slot)
    if not texture then return end

    local iconKey = IconKey(texture)
    local signature = iconKey .. "|" .. tostring(numslots)
    local cached = uaBagNames[slot]
    local name
    if cached and cached.signature == signature then
        name = cached.name
    else
        name = InventoryItemName(slot)
        if name then
            uaBagNames[slot] = { signature = signature, name = name }
        end
    end
    if not name then return end

    local key = name .. "|" .. iconKey
    local itemID = uaBagIDs[key]

    if itemID == nil then
        itemID = Bagzen:GetItemIDByName(name)
        if itemID and MatchesBag(itemID, name, iconKey) then
            uaBagIDs[key] = itemID
        else
            itemID = nil
            uaBagIDs[key] = true
            table.insert(uaBagScanQueue, { key = key, name = name, iconKey = iconKey, nextID = 1 })
            if not uaBagScanner then
                uaBagScanner = CreateFrame("Frame")
                uaBagScanner:SetScript("OnUpdate", UABagScanOnUpdate)
            end
            uaBagScanner:Show()
        end
    end

    if type(itemID) == "number" then
        return "item:" .. itemID .. ":0:0:0"
    end
end
