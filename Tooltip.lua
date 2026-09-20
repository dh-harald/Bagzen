-- Per-character item counts (bags, bank, mail) appended to item tooltips.
--
-- The hovered item is resolved differently per client:
--   * wrath: the GameTooltip item setters are wrapped to remember the item id,
--     and the lines are added from the OnShow of a child frame.
--   * vanilla: the same setter wrappers add the lines right after the native
--     fill. A child OnShow is not enough there: it fires only when the tooltip
--     turns visible, while a bag button re-runs its OnEnter (and so
--     SetBagItem, which clears the tooltip) every frame it is hovered
--     (ContainerFrameItemButton_OnUpdate).
--   * Unreal Azeroth: replacing GameTooltip's methods does not take effect,
--     the replaced setters are never called. The item is resolved from the
--     hovered surface instead, one hook per surface: post-hooks on FrameXML
--     hover globals, chained OnEnter scripts on inline-XML buttons (the
--     load-on-demand trade skill, craft and auction UIs once they load), and
--     direct calls from Bagzen's own buttons (UnrealUI itemprice "Hover path"
--     approach). Action buttons are not covered: no API returns their item.

local _G = _G or getfenv()

Bagzen.Tooltip = CreateFrame("Frame" , "BagzenTooltip", GameTooltip)

Bagzen.Tooltip:SetScript("OnHide", function ()
    Bagzen:TooltipOnHide(this)
end)

if Bagzen.IsWOTLK then
    Bagzen.Tooltip:SetScript("OnShow", function ()
        Bagzen:TooltipOnShow(this)
    end)
end

-- Item id resolvers, called with the setter's own arguments. `arity` is the
-- number of arguments passed on to the native setter.
local ITEM_SETTERS = {
    SetHyperlink = { arity = 1, resolve = function(link)
        if type(link) ~= "string" then return end
        if string.find(link, "^item:%d") or string.find(link, "|Hitem:%d") then
            return Bagzen:LinkToItemID(link)
        end
    end },
    SetBagItem = { arity = 2, resolve = function(container, slot)
        if not container or not slot then return end
        return Bagzen:LinkToItemID(GetContainerItemLink(container, slot))
    end },
    SetInventoryItem = { arity = 2, resolve = function(unit, slot)
        if not unit or not slot then return end
        return Bagzen:LinkToItemID(GetInventoryItemLink(unit, slot))
    end },
    SetInboxItem = { arity = 2, resolve = function(index, attachment)
        if not index then return end
        return Bagzen:GetItemIDByName(GetInboxItem(index, attachment))
    end },
    SetQuestLogItem = { arity = 2, resolve = function(itemType, index)
        if not itemType or not index then return end
        return Bagzen:LinkToItemID(GetQuestLogItemLink(itemType, index))
    end },
    SetQuestItem = { arity = 2, resolve = function(itemType, index)
        if not itemType or not index then return end
        return Bagzen:LinkToItemID(GetQuestItemLink(itemType, index))
    end },
    SetTradeSkillItem = { arity = 2, resolve = function(index, reagent)
        if reagent ~= nil then
            return Bagzen:LinkToItemID(GetTradeSkillReagentItemLink(index, reagent))
        end
        return Bagzen:LinkToItemID(GetTradeSkillItemLink(index))
    end },
    SetCraftItem = { arity = 2, resolve = function(index, reagent)
        if reagent ~= nil then
            return Bagzen:LinkToItemID(GetCraftReagentItemLink(index, reagent))
        end
        return Bagzen:LinkToItemID(GetCraftItemLink(index))
    end },
    SetAuctionItem = { arity = 2, resolve = function(atype, index)
        return Bagzen:LinkToItemID(GetAuctionItemLink(atype, index))
    end },
    SetAuctionSellItem = { arity = 0, resolve = function()
        return Bagzen:GetItemIDByName(GetAuctionSellItemInfo())
    end },
    SetLootItem = { arity = 1, resolve = function(slot)
        return Bagzen:LinkToItemID(GetLootSlotLink(slot))
    end },
    SetLootRollItem = { arity = 1, resolve = function(id)
        return Bagzen:LinkToItemID(GetLootRollItemLink(id))
    end },
    SetMerchantItem = { arity = 1, resolve = function(index)
        return Bagzen:LinkToItemID(GetMerchantItemLink(index))
    end },
    -- GetBuybackItemLink exists on wrath only
    SetBuybackItem = { arity = 1, resolve = function(index)
        if GetBuybackItemLink then
            return Bagzen:LinkToItemID(GetBuybackItemLink(index))
        end
        return Bagzen:GetItemIDByName(GetBuybackItemInfo(index))
    end },
    SetTradePlayerItem = { arity = 1, resolve = function(index)
        return Bagzen:LinkToItemID(GetTradePlayerItemLink(index))
    end },
    SetTradeTargetItem = { arity = 1, resolve = function(index)
        return Bagzen:LinkToItemID(GetTradeTargetItemLink(index))
    end },
}

-- Native setters get exactly the arguments FrameXML passed; no trailing nils.
local function CallSetter(original, self, arity, a1, a2)
    if arity == 0 then
        return original(self)
    elseif arity == 1 then
        return original(self, a1)
    end
    return original(self, a1, a2)
end

-- The item id is stored before the native call: on wrath the child OnShow
-- fires synchronously inside the setter and reads it.
local function WrapSetter(name, setter)
    local original = GameTooltip[name]
    if type(original) ~= "function" then return end

    GameTooltip[name] = function(self, a1, a2)
        local ok, itemID = pcall(setter.resolve, a1, a2)
        if not ok then
            itemID = nil
        end
        Bagzen.Tooltip.itemID = itemID
        local r1, r2, r3 = CallSetter(original, self, setter.arity, a1, a2)
        if itemID and not Bagzen.IsWOTLK then
            Bagzen:TooltipAddCounts(self, itemID)
        end
        return r1, r2, r3
    end
end

-- Chains `handler(caller, a1, a2)` after a FrameXML Lua global (the XML templates
-- look the global up at call time, so replacing it is enough). On UA a script
-- fired synchronously inside a handler (a Show() firing OnShow) leaves the
-- `this` global on that inner frame, and the native caller keeps reading
-- `this` afterwards, so it is restored after each step.
local function PostHookGlobal(name, handler)
    local original = _G[name]
    if type(original) ~= "function" then return end

    _G[name] = function(a1, a2, a3, a4)
        local caller = this
        local r1, r2, r3 = original(a1, a2, a3, a4)
        this = caller
        pcall(handler, caller, a1, a2)
        this = caller
        return r1, r2, r3
    end
end

-- Chains `handler(frame)` after a frame's existing script. GetScript returns
-- the inline XML handler, which reads `this`; restored as in PostHookGlobal.
local function PostHookScript(frame, script, handler)
    local ok, original = pcall(frame.GetScript, frame, script)
    if not ok then return end

    pcall(frame.SetScript, frame, script, function(a1, a2, a3, a4)
        local caller = this
        if original then
            original(a1, a2, a3, a4)
        end
        this = caller
        pcall(handler, frame)
        this = caller
    end)
end

-- Both hook helpers are shared with the modules that borrow native frames,
-- where a stock update pass has to be followed by Bagzen's own.
function Bagzen:PostHookGlobal(name, handler)
    PostHookGlobal(name, handler)
end

function Bagzen:PostHookScript(frame, script, handler)
    PostHookScript(frame, script, handler)
end

-- Stock bag buttons (ContainerFrameItemButtonTemplate), Bagzen's live bag and
-- bank-bag slots included. `button` is nil when the per-frame OnUpdate calls
-- the global; the global itself then falls back to `this`.
function Bagzen:TooltipContainerItemEnter(button)
    if not button then return end
    local bag = button:GetParent():GetID()
    local slot = button:GetID()
    local link
    if bag == KEYRING_CONTAINER then
        link = GetInventoryItemLink("player", KeyRingButtonIDToInvSlotID(slot))
    else
        link = GetContainerItemLink(bag, slot)
    end
    Bagzen:TooltipAddCounts(GameTooltip, Bagzen:LinkToItemID(link))
end

-- Main bank slots (BankItemButtonGenericTemplate): the OnEnter is inline XML
-- calling SetInventoryItem, so there is no global to hook. Called on UA for
-- each slot button Bagzen creates.
function Bagzen:TooltipHookBankButton(button)
    PostHookScript(button, "OnEnter", function(frame)
        Bagzen:TooltipAddCounts(GameTooltip, Bagzen:LinkToItemID(GetContainerItemLink(BANK_CONTAINER or -1, frame:GetID())))
    end)
end

-- Resolves the item with the arguments the native OnEnter passes to `setter`.
local function AddCountsFor(setter, a1, a2)
    local ok, itemID = pcall(ITEM_SETTERS[setter].resolve, a1, a2)
    if ok then
        Bagzen:TooltipAddCounts(GameTooltip, itemID)
    end
end

local function HookButton(name, handler)
    local button = _G[name]
    if button then
        PostHookScript(button, "OnEnter", handler)
    end
end

-- Button fields read below (`type`, `rewardType`, `hasItem`, `index`,
-- `rollID`) are set on the button by FrameXML; each condition mirrors the
-- native OnEnter, so lines are only added where it filled an item.
local function HookFrameXMLSurfaces()
    PostHookGlobal("ContainerFrameItemButton_OnEnter", function(caller, button)
        Bagzen:TooltipContainerItemEnter(button or caller)
    end)
    PostHookGlobal("PaperDollItemSlotButton_OnEnter", function(caller)
        AddCountsFor("SetInventoryItem", "player", caller:GetID())
    end)

    -- the same buttons list buyback items while the buyback tab is selected
    for i = 1, 12 do
        HookButton("MerchantItem" .. i .. "ItemButton", function(frame)
            if MerchantFrame.selectedTab == 1 then
                AddCountsFor("SetMerchantItem", frame:GetID())
            else
                AddCountsFor("SetBuybackItem", frame:GetID())
            end
        end)
    end
    HookButton("MerchantBuyBackItemItemButton", function()
        AddCountsFor("SetBuybackItem", GetNumBuybackItems())
    end)

    local lootButtons = LOOTFRAME_NUMBUTTONS or 4
    for i = 1, lootButtons do
        HookButton("LootButton" .. i, function(frame)
            local slot = (lootButtons - 1) * (LootFrame.page - 1) + frame:GetID()
            if LootSlotIsItem(slot) then
                AddCountsFor("SetLootItem", slot)
            end
        end)
    end
    for i = 1, 4 do
        HookButton("GroupLootFrame" .. i .. "IconFrame", function(frame)
            AddCountsFor("SetLootRollItem", frame:GetParent().rollID)
        end)
    end

    local function QuestItemEnter(frame)
        if frame.rewardType == "item" then
            AddCountsFor("SetQuestItem", frame.type, frame:GetID())
        end
    end
    for i = 1, 10 do
        HookButton("QuestDetailItem" .. i, QuestItemEnter)
        HookButton("QuestRewardItem" .. i, QuestItemEnter)
        HookButton("QuestLogItem" .. i, function(frame)
            if frame.rewardType == "item" then
                AddCountsFor("SetQuestLogItem", frame.type, frame:GetID())
            end
        end)
    end
    for i = 1, 6 do
        HookButton("QuestProgressItem" .. i, QuestItemEnter)
    end

    -- the trade slot index is the id of the button's parent frame
    for i = 1, 7 do
        local id = i
        HookButton("TradePlayerItem" .. i .. "ItemButton", function()
            AddCountsFor("SetTradePlayerItem", id)
        end)
        HookButton("TradeRecipientItem" .. i .. "ItemButton", function()
            AddCountsFor("SetTradeTargetItem", id)
        end)
    end

    PostHookGlobal("InboxFrameItem_OnEnter", function(caller)
        if caller.hasItem then
            AddCountsFor("SetInboxItem", caller.index)
        end
    end)
    PostHookGlobal("OpenMailPackage_OnEnter", function()
        AddCountsFor("SetInboxItem", InboxFrame.openMailID)
    end)
end

-- Surfaces of load-on-demand Blizzard addons, hooked once `global` exists.
local LOAD_ON_DEMAND_SURFACES = {
    { global = "TradeSkillFrame", hook = function()
        HookButton("TradeSkillSkillIcon", function()
            local index = GetTradeSkillSelectionIndex()
            if index and index ~= 0 then
                AddCountsFor("SetTradeSkillItem", index)
            end
        end)
        for i = 1, 8 do
            HookButton("TradeSkillReagent" .. i, function(frame)
                AddCountsFor("SetTradeSkillItem", GetTradeSkillSelectionIndex(), frame:GetID())
            end)
        end
    end },
    -- the craft window's own icon shows the craft spell, not an item
    { global = "CraftFrame", hook = function()
        for i = 1, 8 do
            HookButton("CraftReagent" .. i, function(frame)
                AddCountsFor("SetCraftItem", GetCraftSelectionIndex(), frame:GetID())
            end)
        end
    end },
    { global = "AuctionFrameItem_OnEnter", hook = function()
        PostHookGlobal("AuctionFrameItem_OnEnter", function(caller, atype, index)
            AddCountsFor("SetAuctionItem", atype, index)
        end)
        HookButton("AuctionsItemButton", function()
            if GetAuctionSellItemInfo() then
                AddCountsFor("SetAuctionSellItem")
            end
        end)
    end },
}

local function HookLoadOnDemandSurfaces()
    for _, surface in ipairs(LOAD_ON_DEMAND_SURFACES) do
        if not surface.done and _G[surface.global] then
            surface.done = true
            surface.hook()
        end
    end
end

if Bagzen.IsUA then
    HookFrameXMLSurfaces()
    HookLoadOnDemandSurfaces()
    -- stays registered: UnregisterEvent is a no-op on UA, and the handler
    -- does nothing once every surface is hooked
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", HookLoadOnDemandSurfaces)
else
    for name, setter in pairs(ITEM_SETTERS) do
        WrapSetter(name, setter)
    end
end

-- Count lines for `itemID`: a spacer, one row per character holding the item,
-- then a Total row and a closing spacer. Rows are { left, right, r, g, b };
-- spacers have no `right`. Empty when no character holds the item.
local function BuildCountLines(itemID)
    local lines = {}
    local count = 0

    for character, data in pairs(Bagzen.data.global[Bagzen.realmname] or {}) do
        local bagcount = 0
        local bankcount = 0
        local mailcount = 0
        local bagslotcount = 0

        for bag, data2 in pairs(data.bags or {}) do
            -- the bag item itself, equipped in a bag slot (1-4) or bank bag
            -- slot (5-10); the backpack, main bank and keyring have no link
            if type(bag) == "number" and bag > 0 and type(data2) == "table" and data2.link
                    and Bagzen:LinkToItemID(data2.link) == itemID then
                bagslotcount = bagslotcount + 1
            end
            if type(bag) == "number" and bag >= -1 and data2["slots"] then
                for _, item in pairs(data2["slots"]) do
                    if Bagzen:LinkToItemID(item["link"]) == itemID then
                        if bag >= 0 and bag < 5 then
                            bagcount = bagcount + item["count"]
                        else
                            bankcount = bankcount + item["count"]
                        end
                    end
                end
            end
        end

        for _, item in pairs(data.mails or {}) do
            if item.itemid ~= nil and item.itemid == itemID then
                mailcount = mailcount + item.count
            end
        end

        local countstr = ""
        if bagcount > 0 then
            count = count + bagcount
            countstr = "|cff4378ccBag:|r " .. bagcount
        end
        if bankcount > 0 then
            count = count + bankcount
            if countstr ~= "" then
                countstr = countstr .. ", "
            end
            countstr = countstr .. "|cff4378ccBank:|r " .. bankcount
        end
        if mailcount > 0 then
            count = count + mailcount
            if countstr ~= "" then
                countstr = countstr .. ", "
            end
            countstr = countstr .. "|cff4378ccMail:|r " .. mailcount
        end
        if bagslotcount > 0 then
            count = count + bagslotcount
            if countstr ~= "" then
                countstr = countstr .. ", "
            end
            countstr = countstr .. "|cff4378ccBag slot:|r " .. bagslotcount
        end

        if countstr ~= "" then
            if table.getn(lines) == 0 then
                table.insert(lines, { left = "\n" })
            end
            local color = RAID_CLASS_COLORS[data["class"]] or { r = 1, g = 1, b = 1 }
            table.insert(lines, { left = character, right = countstr, r = color.r, g = color.g, b = color.b })
        end
    end

    if count > 0 then
        table.insert(lines, { left = "Total", right = tostring(count), r = 1, g = 1, b = 1 })
        table.insert(lines, { left = "\n" })
    end
    return lines
end

local function AddCountLine(tip, line)
    if line.right then
        tip:AddDoubleLine(line.left, line.right, line.r, line.g, line.b, 1, 1, 1)
    else
        tip:AddLine(line.left)
    end
end

-- A hovered bag button refills the tooltip every frame; walking every
-- character's bags, bank and mail that often is wasted work, so the lines of
-- the last item are reused for up to a second.
local cache = { itemID = nil, time = 0, lines = nil }

local function GetCountLines(itemID)
    local now = GetTime()
    if cache.itemID ~= itemID or now - cache.time > 1 then
        cache.itemID = itemID
        cache.time = now
        cache.lines = BuildCountLines(itemID)
    end
    return cache.lines
end

-- Compared without colour escapes and whitespace: on UA FontString:GetText()
-- drops colour escapes, the legacy client keeps them.
local function NormalizeText(text)
    if not text then return "" end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "%s", "")
    return text
end

local function ShownText(fontstring)
    if fontstring and fontstring:IsShown() then
        return NormalizeText(fontstring:GetText())
    end
    return ""
end

-- True when the tooltip already ends with `lines`. Only shown lines count:
-- UA's ClearLines clears the left column only and leaves the old right-column
-- text hidden in place.
local function TailMatches(tip, lines)
    local name = tip:GetName()
    local count = table.getn(lines)
    local first = tip:NumLines() - count
    if not name or first < 1 then return false end

    for i = 1, count do
        local line = lines[i]
        if ShownText(_G[name .. "TextLeft" .. (first + i)]) ~= NormalizeText(line.left) then
            return false
        end
        if line.right and ShownText(_G[name .. "TextRight" .. (first + i)]) ~= NormalizeText(line.right) then
            return false
        end
    end
    return true
end

-- Vanilla entry point, safe to call repeatedly for the same fill: the lines
-- are only added when the tooltip does not already end with them. A shown
-- tooltip is required, since other addons fill a hidden GameTooltip to read
-- item text. Show() re-runs the layout so the tooltip grows to fit the lines.
function Bagzen:TooltipAddCounts(tip, itemID)
    Bagzen.Tooltip.itemID = itemID
    if not itemID or not tip or not tip:IsShown() then return end

    local lines = GetCountLines(itemID)
    local count = table.getn(lines)
    if count == 0 or TailMatches(tip, lines) then return end

    for i = 1, count do
        AddCountLine(tip, lines[i])
    end
    tip:Show()
end

-- Wrath entry point: the child frame's OnShow, with the item id stored by the
-- setter wrappers.
function Bagzen:TooltipOnShow(frame)
    if not frame.itemID then return end
    for _, line in ipairs(BuildCountLines(frame.itemID)) do
        AddCountLine(GameTooltip, line)
    end
end

function Bagzen:TooltipOnHide(frame)
    frame.itemID = nil
end
