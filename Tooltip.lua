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
--     Unreal Azeroth takes the vanilla path: it calls a replaced GameTooltip
--     setter method through Lua as well.
-- Bagzen's own SetHyperlink buttons add the lines once more after their
-- explicit Show(), since the wrapper skips a tooltip that is not shown yet;
-- TooltipAddCounts never adds the same lines twice.

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
    -- Main bank slots arrive as inventory ids 40-63 (BankButtonIDToInvSlotID);
    -- UA's GetInventoryItemLink returns links for equipment slots only, so
    -- those are read through the bank container.
    SetInventoryItem = { arity = 2, resolve = function(unit, slot)
        if not unit or not slot then return end
        if slot > 39 and slot <= 39 + (NUM_BANKGENERIC_SLOTS or 24) then
            return Bagzen:LinkToItemID(GetContainerItemLink(BANK_CONTAINER or -1, slot - 39))
        end
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
-- fires synchronously inside the setter and reads it. The setters are called
-- from inline XML OnEnter handlers that keep reading the `this` global; on UA
-- a script fired by the added lines (Show() -> OnShow) leaves `this` on that
-- inner frame, so it is put back.
local function WrapSetter(name, setter)
    local original = GameTooltip[name]
    if type(original) ~= "function" then return end

    GameTooltip[name] = function(self, a1, a2)
        local caller = this
        local ok, itemID = pcall(setter.resolve, a1, a2)
        if not ok then
            itemID = nil
        end
        Bagzen.Tooltip.itemID = itemID
        local r1, r2, r3 = CallSetter(original, self, setter.arity, a1, a2)
        if itemID and not Bagzen.IsWOTLK then
            Bagzen:TooltipAddCounts(self, itemID)
        end
        this = caller
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

for name, setter in pairs(ITEM_SETTERS) do
    WrapSetter(name, setter)
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
