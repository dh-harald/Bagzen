StaticPopupDialogs["BAGZEN_CONFIRM_BUY_BANK_SLOT"] = {
        text = TEXT(CONFIRM_BUY_BANK_SLOT),
        button1 = TEXT(YES),
        button2 = TEXT(NO),
        OnAccept = function()
                PurchaseSlot();
        end,
        OnShow = function()
                MoneyFrame_Update(this:GetName().."MoneyFrame", BagzenBankFrame.nextSlotCost);
        end,
        hasMoneyFrame = 1,
        timeout = 0,
        hideOnEscape = 1,
};

-- A bag's button is looked up here rather than by frame name: a live bag is
-- shown by the client's own button, a cached one by a Bagzen button, and the
-- two have unrelated names. The bank's main panel and the keyring have no
-- native counterpart, so there one frame is registered in both sets.
Bagzen.BagSlots = {
    ["Live"] = {
        ["bagframe"] = {},
        ["bankframe"] = {},
    },
    ["Virtual"] = {
        ["bagframe"] = {},
        ["bankframe"] = {},
    },
}

-- The client's own bag buttons, borrowed for the live view. They identify the
-- bag from its inventory slot, which is the only route that works on Unreal
-- Azeroth, where GetInventoryItemLink returns nil for a bag slot. Their ID is
-- an inventory slot (20-23) for the character bags, so the bag number is kept
-- in the BagzenBag field instead of on the frame ID.
local NATIVE_BAG_SLOT = {
    [0] = "MainMenuBarBackpackButton",
    [1] = "CharacterBag0Slot",
    [2] = "CharacterBag1Slot",
    [3] = "CharacterBag2Slot",
    [4] = "CharacterBag3Slot",
    [5] = "BankFrameBag1",
    [6] = "BankFrameBag2",
    [7] = "BankFrameBag3",
    [8] = "BankFrameBag4",
    [9] = "BankFrameBag5",
    [10] = "BankFrameBag6",
}

local function BagSlotSet(frame)
    if frame.Virtual == true then
        return "Virtual"
    end
    return "Live"
end

function Bagzen:GetBagSlot(frame, bag)
    return Bagzen.BagSlots[BagSlotSet(frame)][frame.SettingSection][bag]
end

-- The free-slot number Bagzen paints on a bag button. It is kept on the button
-- because a borrowed button's count font string is also driven by the client
-- (the bag's own stack count, the total free slots on the backpack button), so
-- the value has to be re-applied after every stock repaint.
function Bagzen:BagSlotFreeCount(button, free)
    local _G = _G or getfenv()
    local countFrame = _G[button:GetName() .. "Count"]
    button.BagzenFree = free
    if free == nil then
        countFrame:SetText("")
        countFrame:Hide()
    else
        countFrame:SetText(free)
        countFrame:Show()
    end
end

-- A borrowed button brings the slot art geometry of its own template, which
-- differs per client (on Unreal Azeroth the bank buttons draw it smaller than
-- the button itself). It is restated from Bagzen's own template instead --
-- read back from a button built from it rather than hardcoded, because what
-- the declared size comes out as also differs per client, and the borrowed
-- buttons have to end up looking like the Bagzen-made ones beside them.
local slotArt = nil
local function SlotArtGeometry()
    if slotArt == nil then
        slotArt = false
        local reference = CreateFrame("Button", "BagzenSlotArtReference", UIParent, "BagzenBagSlotItemTemplate")
        reference:Hide()
        local ok, normal = pcall(reference.GetNormalTexture, reference)
        if ok and normal then
            local point, _, relativePoint, x, y = normal:GetPoint()
            slotArt = {
                button = { width = reference:GetWidth(), height = reference:GetHeight() },
                width = normal:GetWidth(),
                height = normal:GetHeight(),
                point = point or "CENTER",
                relativePoint = relativePoint or "CENTER",
                x = x or 0,
                y = y or 0,
            }
        end
    end
    return slotArt
end

local function SkinSlotArt(button)
    local art = SlotArtGeometry()
    if not art then return end
    if art.button.width and art.button.width > 0 then
        button:SetWidth(art.button.width)
        button:SetHeight(art.button.height)
    end
    local ok, normal = pcall(button.GetNormalTexture, button)
    if ok and normal then
        normal:SetWidth(art.width)
        normal:SetHeight(art.height)
        normal:ClearAllPoints()
        normal:SetPoint(art.point, button, art.relativePoint, art.x, art.y)
    end
end

-- The stock helper resolves the normal texture by frame name, which does not
-- work on every borrowed button (skinning it replaces the texture the name
-- points at), so the object is coloured directly.
function Bagzen:SetSlotBorderColor(button, r, g, b)
    local ok, normal = pcall(button.GetNormalTexture, button)
    if ok and normal then
        normal:SetVertexColor(r, g, b)
    end
end

-- Everything a stock repaint of a borrowed button overwrites.
local function ReapplyBagSlotOverlay(button)
    if button == nil or button.BagzenBag == nil then return end

    if button.BagzenFree ~= nil then
        Bagzen:BagSlotFreeCount(button, button.BagzenFree)
    end
    local quality = button.itemQuality and ITEM_QUALITY_COLORS[button.itemQuality]
    if quality then
        Bagzen:SetSlotBorderColor(button, quality.r, quality.g, quality.b)
    end
    if button.Purchasable and button.BagzenIcon then
        button.BagzenIcon:Hide() -- the client paints the empty bank-bag slot texture
    end
end

-- Repaints a borrowed button on demand. They paint themselves from their own
-- events, but a window that has just been shown needs one manual pass: the
-- bank buttons only react to their own events and their template has an empty
-- OnShow. The backpack button's icon is static, so it needs nothing.
local function RefreshNativeBagSlot(button)
    local bag = button.BagzenBag
    local caller = this
    if bag >= 5 then
        if Bagzen.IsWOTLK then
            pcall(BankFrameItemButton_Update, button)
        else
            this = button
            pcall(BankFrameItemButton_OnUpdate)
        end
    elseif bag >= 1 then
        if Bagzen.IsWOTLK then
            pcall(PaperDollItemSlotButton_Update, button)
        else
            this = button
            pcall(PaperDollItemSlotButton_Update)
        end
    end
    this = caller
end

local stockOverridesInstalled = false

-- Bagzen owns the bag UI, so the stock per-bag frames must never open and the
-- borrowed buttons must not toggle Bagzen's window from under themselves. The
-- click handlers reach these FrameXML globals, which the XML templates look up
-- at call time; replacing the globals therefore covers the borrowed buttons on
-- every client, including Unreal Azeroth, where a native button's inline
-- script cannot be read back. Vanilla passes the button in `this`, wrath as
-- the first argument.
local function InstallStockOverrides()
    if stockOverridesInstalled then return end
    stockOverridesInstalled = true

    local function Caller(a1)
        if type(a1) == "table" then return a1 end
        return this
    end

    ToggleBag = function(id) end

    BackpackButton_OnClick = function(a1)
        PutItemInBackpack()
    end

    BagSlotButton_OnClick = function(a1)
        local button = Caller(a1)
        if button then
            PutItemInBag(button:GetID())
        end
    end

    BankFrameItemButtonBag_OnClick = function(a1)
        local button = Caller(a1)
        if button == nil then return end
        if button.Purchasable then
            StaticPopup_Show("BAGZEN_CONFIRM_BUY_BANK_SLOT")
            return
        end
        PutItemInBag(BankButtonIDToInvSlotID(button:GetID(), 1))
    end

    -- A stock repaint resets the border colour and rewrites the count text, so
    -- Bagzen's overlay is restored after each one.
    Bagzen:PostHookGlobal("PaperDollItemSlotButton_Update", function(caller, a1)
        ReapplyBagSlotOverlay(Caller(a1) or caller)
    end)
    Bagzen:PostHookGlobal("MainMenuBarBackpackButton_UpdateFreeSlots", function()
        ReapplyBagSlotOverlay(MainMenuBarBackpackButton)
    end)
    if Bagzen.IsWOTLK then
        Bagzen:PostHookGlobal("BankFrameItemButton_Update", function(caller, a1)
            ReapplyBagSlotOverlay(Caller(a1) or caller)
        end)
    else
        Bagzen:PostHookGlobal("BankFrameItemButton_OnUpdate", function(caller)
            ReapplyBagSlotOverlay(caller)
        end)
    end
end

-- Moves a native bag button into Bagzen's bag row and gives it Bagzen's look.
-- The client keeps painting it (icon, lock desaturation, cursor highlight,
-- item-push animation); Bagzen adds its own hover on top for the
-- cross-character counts and for lighting up the bag's slots.
local function AdoptNativeBagSlot(parent, bag)
    local _G = _G or getfenv()
    local name = NATIVE_BAG_SLOT[bag]
    local button = name and _G[name]
    if button == nil then return nil end

    InstallStockOverrides()

    button:SetParent(_G[parent:GetName() .. "BagSlotsFrame"])
    button:SetNormalTexture("Interface\\AddOns\\Bagzen\\textures\\UI-Quickslot2")
    button:SetPushedTexture("Interface\\AddOns\\Bagzen\\textures\\UI-Quickslot-Depress")
    -- Bagzen's own hover art: the stock buttons bring the client's solid
    -- square, which reads as a different button next to the addon's own
    button:SetHighlightTexture("Interface\\AddOns\\Bagzen\\textures\\ButtonHilight-Square", "ADD")
    SkinSlotArt(button)
    button.BagzenIcon = _G[name .. "IconTexture"]
    button.BagzenIcon:SetTexCoord(0.03, 0.97, 0.03, 0.97)

    -- the stock OnUpdate only refreshes a tooltip Bagzen fills itself
    pcall(button.SetScript, button, "OnUpdate", nil)
    if button.SetChecked then
        pcall(button.SetChecked, button, 0)
    end

    button.Native = true
    Bagzen:PostHookScript(button, "OnEnter", function(frame)
        Bagzen:BagSlotItemOnEnter(frame)
    end)
    Bagzen:PostHookScript(button, "OnLeave", function(frame)
        Bagzen:BagSlotItemOnLeave(frame)
    end)

    return button
end

local function CreateOwnBagSlot(parent, bag, set)
    local _G = _G or getfenv()
    local bagslotsframe = _G[parent:GetName() .. "BagSlotsFrame"]
    local name = parent:GetName() .. "BagSlotsFrame" .. Bagzen:FixBagNumber(bag)
    if set == "Virtual" and NATIVE_BAG_SLOT[bag] then
        name = name .. "Cached" -- the live view of this bag is a native button
    end

    local button
    if bag == KEYRING_CONTAINER then
        button = CreateFrame("Frame", name, bagslotsframe) -- holds the slot count, the keyring has no button
    else
        button = CreateFrame("Button", name, bagslotsframe, "BagzenBagSlotItemTemplate")
    end
    Bagzen:HackID(button)
    button:SetID(bag)
    if bag ~= KEYRING_CONTAINER then
        button.BagzenIcon = _G[name .. "IconTexture"]
        SkinSlotArt(button)
    end
    return button
end

-- Cell of a bag in the row, in the order the frame lists its bags.
local function BagSlotOffset(parent, bag)
    local index = 0
    for _, tmp in pairs(parent.Bags) do
        if tmp == bag then break end
        index = index + 1
    end
    return 2 * Bagzen.PADDING + index * Bagzen.SIZE_X, -2 * Bagzen.PADDING
end

local function PlaceBagSlot(parent, button, bag)
    if bag == KEYRING_CONTAINER then return end
    local x, y = BagSlotOffset(parent, bag)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", parent:GetName() .. "BagSlotsFrame", "TOPLEFT", x, y)
end

-- An unbought bank-bag slot is marked with a tinted square behind the slot
-- art. The texture belongs to the button itself: one drawn on the row instead
-- is covered by the button on wrath, since a parent's textures are always
-- below its child frames. Borrowed buttons have no background texture of their
-- own, so every bag button gets this one, Bagzen-made included.
local function MarkPurchasableSlot(button, purchasable)
    local mark = button.BagzenMark
    if mark == nil then
        -- Drawn above the button's own art rather than behind it: a borrowed
        -- button's art sits over a background-layer texture and swallows a
        -- translucent tint, while a Bagzen-made button shows it at full
        -- strength, so the same value looked different in the two views. The
        -- slot's icon is hidden while it is unbought, so nothing is covered up.
        mark = button:CreateTexture(button:GetName() .. "BagzenMark", "OVERLAY")
        mark:SetAllPoints(button)
        button.BagzenMark = mark
    end
    if purchasable then
        mark:SetTexture(0.5, 0, 0, 0.2)
    else
        mark:SetTexture(0, 0, 0, 0)
    end
end

local function CreateBagSlot(parent, bag)
    local set = BagSlotSet(parent)
    local button = nil
    if set == "Live" then
        button = AdoptNativeBagSlot(parent, bag)
    end
    if button == nil then
        button = CreateOwnBagSlot(parent, bag, set)
    end

    button.BagzenBag = bag
    PlaceBagSlot(parent, button, bag)
    Bagzen.BagSlots[set][parent.SettingSection][bag] = button
    if NATIVE_BAG_SLOT[bag] == nil then
        -- nothing native to swap in, so this frame serves both views
        Bagzen.BagSlots["Live"][parent.SettingSection][bag] = button
        Bagzen.BagSlots["Virtual"][parent.SettingSection][bag] = button
    end
    return button
end

local function HideInactiveBagSlot(parent, bag)
    local other = "Live"
    if parent.Virtual ~= true then
        other = "Virtual"
    end
    local button = Bagzen.BagSlots[other][parent.SettingSection][bag]
    if button and button ~= Bagzen:GetBagSlot(parent, bag) then
        button:Hide()
    end
end

function Bagzen:BagSlotsInit(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "BagSlotsFrame"]
    if Bagzen.settings.global[parent.SettingSection].bagsframe then
        frame:Show()
    else
        frame:Hide()
    end
    local size = Bagzen.PADDING
    for _, bag in pairs(parent.Bags) do
        if bag ~= KEYRING_CONTAINER then
            size = size + Bagzen.SIZE_X
        end
    end
    size = size + Bagzen.PADDING
    frame:SetWidth(size)
end

function Bagzen:HighlightSlots(frame, bag)
    local bagframe = Bagzen:GetBagSlot(frame, bag)
    local live = "Live"
    if frame.Virtual == true then
        live = "Virtual"
    end
    for i, slotframe in pairs(Bagzen.ContainerFrames[live][frame.SettingSection][bag]) do
        if i <= bagframe.Slots then
            slotframe:LockHighlight()
        end
    end
end

function Bagzen:UnHighlightSlots(frame)
    local live = "Live"
    if frame.Virtual == true then
        live = "Virtual"
    end
    for _, bag in pairs(frame.Bags) do
        if Bagzen.ContainerFrames[live][frame.SettingSection][bag] then
            local bagframe = Bagzen:GetBagSlot(frame, bag)
            for i, slotframe in pairs(Bagzen.ContainerFrames[live][frame.SettingSection][bag]) do
                if i <= bagframe.Slots then
                    slotframe:UnlockHighlight()
                end
            end
        end
    end
end

function Bagzen:BagSlotItemOnEnter(frame)
    local bag = frame.BagzenBag
    if bag == nil or bag == KEYRING_CONTAINER then return end -- sanity check
    local parent = frame:GetParent():GetParent()
    local virtual = parent.Virtual
    local shown = false

    GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()

    if parent:GetName() == "BagzenBankFrame" and frame.Purchasable and virtual == false then
        GameTooltip:SetText("Purchasable Bank Slot")
        shown = true
    elseif bag < 1 then
        if bag == -1 then
            GameTooltip:SetText("Bank")
        else
            GameTooltip:SetText("Backpack")
        end
        shown = true
    elseif virtual == true then
        -- only the item id of a cached link is trusted: the entry may have been
        -- written by another client build, and a malformed link throws
        local itemID = Bagzen:LinkToItemID(frame.ItemLink)
        if itemID then
            GameTooltip:SetHyperlink("item:" .. itemID .. ":0:0:0")
            shown = true
        end
    elseif GetInventoryItemTexture("player", frame.Slot) then
        -- the texture, not the link, decides: a live bag has no link on UA
        GameTooltip:SetInventoryItem("player", frame.Slot)
        shown = true
    end

    if shown then
        GameTooltip:Show()
        if Bagzen.IsUA and bag > 0 and frame.ItemLink then
            -- GameTooltip setters cannot be wrapped on UA
            Bagzen:TooltipAddCounts(GameTooltip, Bagzen:LinkToItemID(frame.ItemLink))
        end
        Bagzen:HighlightSlots(parent, bag)
    else
        GameTooltip:Hide()
    end
end

function Bagzen:BagSlotItemOnLeave(frame)
    GameTooltip:Hide()
    Bagzen:UnHighlightSlots(frame:GetParent():GetParent())
end

function Bagzen:BagSlotItemOnClick(frame)
    local hadItem = nil
    if frame.BagzenBag == 0 then
        hadItem = PutItemInBackpack()
    else
        hadItem = PutItemInBag(frame.Slot)
    end
    if not hadItem then
        if frame:GetParent():GetParent():GetName() == "BagzenBankFrame" and frame.Purchasable then
            StaticPopup_Show("BAGZEN_CONFIRM_BUY_BANK_SLOT")
        elseif IsShiftKeyDown() then
            if (ChatFrameEditBox:IsShown()) then
                -- ChatFrameEditBox:Insert(frame.ItemLink) TODO: create proper link for linkng
            end
        else
            PickupBagFromSlot(frame.Slot)
        end
    end
end

function Bagzen:BagSlotItemOnDragStart(frame)
    PickupBagFromSlot(frame.Slot)
end

function Bagzen:BagSlotItemUpdate(frame)
    local _G = _G or getfenv()
    local bag = frame.BagzenBag
    local native = frame.Native == true
    local icontexture = frame.BagzenIcon
    local parent = frame:GetParent():GetParent()
    local virtual = parent.Virtual

    if virtual == false and bag == KEYRING_CONTAINER then
        local numslots = GetKeyRingSize() or 0
        if numslots > 0 then
            Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags[bag] = {
                size = numslots,
                slots = {}
            }
        end
        frame.Slots = numslots
        return -- no keyring button here
    elseif bag == KEYRING_CONTAINER then
        frame.Slots = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] and Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].size or 0
        return
    elseif bag <= 0 then
        -- backpack or default bank slot
        frame.ItemLink = nil
        if not native then
            icontexture:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
        end
    else
        local baglink = nil
        if virtual == false then
            if Bagzen.IsUA
            then
                local numslots = Bagzen:GetContainerNumSlots(bag)
                if numslots > 0
                then
                    baglink = Bagzen:GetUABagLink(frame.Slot, numslots)
                end
            else
                baglink = GetInventoryItemLink("player", frame.Slot)
            end
        else
            if Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags and Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] then
                baglink = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].link
            end
        end
        if baglink ~= nil then
            local itemID = Bagzen:LinkToItemID(baglink)
            local _, _, itemQuality, _, _, _, _, _, _, texture = Bagzen:GetItemInfo(itemID)
            local cached = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag]
            -- the cached field holds the quality index, not a colour: an item
            -- the client has no entry for yet resolves to nothing here
            itemQuality = itemQuality or (cached and cached.quality)
            local itemQualityColor = ITEM_QUALITY_COLORS[itemQuality]
            if not native then
                icontexture:SetTexture(texture or (cached and cached.texture))
            end
            frame.ItemLink = baglink
            if itemQualityColor then
                frame.itemQuality = itemQuality -- save this
                Bagzen:SetSlotBorderColor(frame, itemQualityColor.r, itemQualityColor.g, itemQualityColor.b)
            end
        else
            frame.ItemLink = nil
            frame.itemQuality = nil
            if not native then
                -- a borrowed button knows its own bag: its size comes from the
                -- client, not from a link Bagzen may not have resolved yet
                icontexture:SetTexture(nil)
                frame.Slots = 0
                Bagzen:SetSlotBorderColor(frame, 1, 1, 1)
            end
        end
    end

    local hasbag = frame.ItemLink ~= nil or bag < 1
    if native and bag > 0 then
        hasbag = GetInventoryItemTexture("player", frame.Slot) ~= nil
    end
    if virtual == false and hasbag then
        -- save slots
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags[bag] = {
            texture = icontexture:GetTexture(),
            link = frame.ItemLink,
            size = Bagzen:GetContainerNumSlots(bag),
            quality = frame.itemQuality,
            slots = {}
        }
    end

    if not native then
        if virtual == true or bag < 1 then
            frame:RegisterForClicks(nil)
            frame:RegisterForDrag(nil)
        else
            frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            frame:RegisterForDrag("LeftButton")
        end
    end
end

function Bagzen:BagSlotUpdate(parent, bag)
    local _G = _G or getfenv()
    local dummyframe = _G[parent:GetName() .. "DummyBagSlotFrame" .. Bagzen:FixBagNumber(bag)]
    if dummyframe == nil then
        dummyframe = CreateFrame("Frame", parent:GetName() .. "DummyBagSlotFrame" .. Bagzen:FixBagNumber(bag), parent)
        Bagzen:HackID(dummyframe)
        dummyframe:SetID(bag)
        if bag == KEYRING_CONTAINER then
            if parent.KeyChain == true then
                dummyframe:Show()
            else
                dummyframe:Hide()
            end
        end
    end

    local numslots = 0
    if parent.Virtual == false then
        if bag == KEYRING_CONTAINER then
            numslots = GetKeyRingSize() or 0
        else
            numslots = Bagzen:GetContainerNumSlots(bag) or 0
        end
        -- remove empty slot from character data
        if numslots == 0 and Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags ~= nil and Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] ~= nil then
            Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] = nil
        end
    else
        if Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags and Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag] then
            numslots = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bags[bag].size or 0
        end
    end

    local frame = Bagzen:GetBagSlot(parent, bag)
    if frame == nil then
        frame = CreateBagSlot(parent, bag)
    end

    if bag == KEYRING_CONTAINER then
        frame.Slots = numslots
        Bagzen:BagSlotItemUpdate(frame)
        return
    end

    if parent:GetName() == "BagzenBankFrame" and bag > 0 then
        local numbagslots = 0
        if parent.Virtual == false then
            numbagslots = GetNumBankSlots()
        else
            numbagslots = Bagzen.data.global[parent.OwnerRealm][parent.OwnerName].bagslots or 0
        end
        if (bag - 4) > numbagslots then
            frame.Purchasable = true
        else
            frame.Purchasable = nil
        end
        MarkPurchasableSlot(frame, frame.Purchasable)
        if frame.Native == true then
            if frame.Purchasable then
                frame.BagzenIcon:Hide() -- the client paints the empty bank-bag slot texture
            else
                frame.BagzenIcon:Show()
            end
        end
        -- the stock bank-bag button's own OnEnter reads this field and throws
        -- on an empty slot without it. It is normally filled by
        -- UpdateBagSlotStatus, which never runs: BankFrame is silenced.
        if frame.Purchasable then
            frame.tooltipText = BANK_BAG_PURCHASE or "Purchasable Bank Slot"
        else
            frame.tooltipText = BANK_BAG or "Bank Bag"
        end
    end

    if bag > 0 then
        frame.Slot = ContainerIDToInventoryID(bag)
    else
        frame.Slot = ContainerIDToInventoryID(1) - 1 + bag
    end
    frame.Slots = numslots
    if frame.Native == true then
        -- the stock bag buttons come from main-bar chrome that other addons
        -- fade out; the fade travels with the button through the reparent
        frame:SetAlpha(1)
        RefreshNativeBagSlot(frame)
    end
    Bagzen:BagSlotItemUpdate(frame)
    frame:Show()
    HideInactiveBagSlot(parent, bag)
end

function Bagzen:BagSlotsToggle(parent)
    local _G = _G or getfenv()
    local frame = _G[parent:GetName() .. "BagSlotsFrame"]
    if frame:IsShown() then
        frame:Hide()
        Bagzen.settings.global[parent.SettingSection].bagsframe = false
    else
        frame:Show()
        Bagzen.settings.global[parent.SettingSection].bagsframe = true
    end
end
