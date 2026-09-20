Bagzen.ContainerFrames = {
    ["Live"] = {
        ["bagframe"] = {
            ["count"] = 0,
        },
        ["bankframe"] = {
            ["count"] = 0,
        },
    },
    ["Virtual"] = {
        ["bagframe"] = {
            ["count"] = 0,
        },
        ["bankframe"] = {
            ["count"] = 0,
        }
    }
}

local math_mod = math.mod or math.fmod

function Bagzen:ContainerOnLoad(frame)
    local name = frame:GetName()
    frame:RegisterForDrag("LeftButton")
    frame:SetUserPlaced(true)
    tinsert(UISpecialFrames, name)
    if name == "BagzenBagFrame" then
        frame.SettingSection = "bagframe"
        frame.FrameName = "Bag"
    elseif name == "BagzenBankFrame" then
        frame.SettingSection = "bankframe"
        frame.FrameName = "Bank"
    end
    frame.SplitStack = function(button, split)
        SplitContainerItem(button:GetParent():GetID(), button:GetID(), split)
    end
end

function Bagzen:ContainerResetOwner(frame)
    local _G = _G or getfenv()
    if frame.Virtual == true and (frame.OwnerRealm ~= Bagzen.realmname or frame.OwnerName ~= Bagzen.unitname) then
        Bagzen:ContainerUpdate(frame, Bagzen.realmname, Bagzen.unitname)
        Bagzen:CharactersFrameUpdate(frame)
        Bagzen:ContainerReposition(frame)
    end
    _G[frame:GetName() .. "CharactersFrame"]:Hide()
end

function Bagzen:ContainerInit(frame, bags)
    frame.Bags = bags
    if frame:GetName() == "BagzenBankFrame" then
        BagzenBankFrame.Virtual = true
    end

    frame.KeyChain = (frame:GetName() == "BagzenBagFrame") and (Bagzen.settings.global[frame.SettingSection].keychain or false)

    Bagzen:BagSlotsInit(frame)
    frame.OwnerName = Bagzen.unitname
    frame.OwnerRealm = Bagzen.realmname

    for _, bag in pairs(bags) do
        if Bagzen.ContainerFrames["Live"][frame.SettingSection][bag] == nil then -- sanity check
            Bagzen.ContainerFrames["Live"][frame.SettingSection][bag] = {}
        end
        if Bagzen.ContainerFrames["Virtual"][frame.SettingSection][bag] == nil then -- sanity check
            Bagzen.ContainerFrames["Virtual"][frame.SettingSection][bag] = {}
        end
    end
end

function Bagzen:ContainerGetPosition(frame)
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
    Bagzen.settings.char[frame.SettingSection].point = point
    Bagzen.settings.char[frame.SettingSection].relativePoint = relativePoint
    Bagzen.settings.char[frame.SettingSection].xOfs = xOfs
    Bagzen.settings.char[frame.SettingSection].yOfs = yOfs
end

function Bagzen:ContainerOnMouseDown(frame)
    frame.isMoving = 1
    frame:StartMoving()
end

function Bagzen:ContainerOnMouseUp(frame)
    frame:StopMovingOrSizing()
    frame.isMoving = nil
    Bagzen:ContainerGetPosition(frame)
end

function Bagzen:ContainerItemOnEnter(frame)
    if frame ~= nil and frame.ItemLink then
        GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
        GameTooltip:ClearLines()
        GameTooltip:SetHyperlink("item:" .. Bagzen:LinkToItemID(frame.ItemLink) .. ":0:0:0")
        GameTooltip:Show()
        if Bagzen.IsUA then
            -- GameTooltip setters cannot be wrapped on UA
            Bagzen:TooltipAddCounts(GameTooltip, Bagzen:LinkToItemID(frame.ItemLink))
        end
    end
end

function Bagzen:ContainerItemOnLeave(frame)
    GameTooltip:Hide()
    ResetCursor()
end

local function FitFontToFrame(fontString, frame)
    if Bagzen.IsWOTLK then
        local minSize = 8
        local maxSize = 20
        local font, _, outline = fontString:GetFont()
        local w, h = frame:GetWidth(), frame:GetHeight()
        local size = maxSize
        fontString:SetFont(font, size, outline)
        while (fontString:GetStringWidth() > w or fontString:GetStringHeight() > h) and size > minSize do
            size = size - 1
            fontString:SetFont(font, size, outline)
        end
    elseif Bagzen.IsVanilla then
        -- no GetStringWidth and GetStringHeight in Vanilla, try to estimate size
        local font, size, outline = fontString:GetFont()
        local scale = (frame:GetParent():GetParent():GetParent():GetScale() or 1) * (UIParent:GetScale() or 1)
        local height = (frame:GetParent() and frame:GetParent():GetHeight() or frame:GetHeight() or 0) * scale
        size = math.max((height > 0 and height * .64 or 16), 16)
        fontString:SetFont(font, size, outline)
    end
end

-- https://github.com/Stanzilla/WoWUIBugs/issues/47#issuecomment-710698976
local function GetCooldownLeft(start, duration)
    -- Before restarting the GetTime() will always be greater than [start]
    -- After the restart, [start] is technically always bigger because of the 2^32 offset thing
    if start < GetTime() then
        local cdEndTime = start + duration
        local cdLeftDuration = cdEndTime - GetTime()

        return cdLeftDuration
    end

    local time = time()
    local startupTime = time - GetTime()
    -- just a simplification of: ((2^32) - (start * 1000)) / 1000
    local cdTime = (2 ^ 32) / 1000 - start
    local cdStartTime = startupTime - cdTime
    local cdEndTime = cdStartTime + duration
    local cdLeftDuration = cdEndTime - time

    return cdLeftDuration
end

function Bagzen:CooldownFrameOnUpdate(frame, elapsed)
    local scale = frame:GetParent():GetParent():GetParent():GetScale() or 1
    local framescale = frame.scale or 1

    -- Adjust the size of the cooldown text on resize
    if framescale ~= scale then
        frame.scale = scale
        FitFontToFrame(frame.timeText, frame)
    end

    -- Timer for controlling text update
    frame._cooldownUpdateTimer = (frame._cooldownUpdateTimer or 0) + elapsed

    if frame._nextCooldownTextUpdate and frame._cooldownUpdateTimer < frame._nextCooldownTextUpdate then
        return
    end

    local start = frame._cooldownStart or 0
    local duration = frame._cooldownDuration or 0
    local enable = frame._cooldownEnable or 0
    local remaining = 0

    if enable and enable ~= 0 and start and duration and duration > 1.5 then
        remaining = GetCooldownLeft(start, duration)
        local tmp = remaining - math.floor(remaining)
        if tmp < 0.001  and tmp >= 0 then
            remaining = remaining - 0.001
        end
    end

    if remaining > 0 then
        local text, color, nextUpdate
        if remaining >= 86400 then
            local days = math.ceil(remaining / 86400)
            text = string.format("%dd", days)
            color = {1, 1, 1}
            nextUpdate = remaining - ((days - 1) * 86400)
            if nextUpdate < 60 then nextUpdate = 60 end
        elseif remaining >= 3600 then
            local hours = math.ceil(remaining / 3600)
            text = string.format("%dh", hours)
            color = {1, 1, 1}
            nextUpdate = remaining - ((hours - 1) * 3600)
            if nextUpdate < 60 then nextUpdate = 60 end
        elseif remaining >= 60 then
            local mins = math.ceil(remaining / 60)
            text = string.format("%dm", mins)
            color = {1, 1, 1}
            nextUpdate = remaining - ((mins - 1) * 60)
            if nextUpdate < 1 then nextUpdate = 1 end
        elseif remaining >= 5 then
            local secs = math.ceil(remaining)
            text = string.format("%ds", math.floor(remaining))
            color = {1, 1, 1}
            nextUpdate = remaining - (secs - 1)
            if nextUpdate < 0.1 then nextUpdate = 0.1 end
        else
            text = string.format("%.1fs", remaining)
            if remaining <= 1 then
                color = {1, 0, 0}
            else
                color = {1, 1, 1}
            end
            nextUpdate = 0.1
        end

        if frame.lastText ~= text then
            frame.timeText:SetText(text)
            frame.timeText:SetTextColor(unpack(color))
            -- Fit font size to slot
            FitFontToFrame(frame.timeText, frame, 8, 32)
            frame.lastText = text
        end

        frame._nextCooldownTextUpdate = nextUpdate
        frame._cooldownUpdateTimer = 0
    else
        frame.timeText:SetText("")
        frame.lastText = nil
        frame._nextCooldownTextUpdate = nil
        frame._cooldownUpdateTimer = 0
    end
end

function Bagzen:ContainerResize(frame)
    local _G = _G or getfenv()
    local section = frame.SettingSection
    frame:SetWidth(Bagzen.settings.global[section].width * Bagzen.SIZE_X)
    local count = 0
    for _, bag in pairs(frame.Bags) do
        local bagframe = Bagzen:GetBagSlot(frame, bag)
        if bagframe then
            if frame.KeyChain == true and bag == KEYRING_CONTAINER and (bagframe.Slots or 0) > 0 then
                if math_mod(count, Bagzen.settings.global[section].width) > 0 then
                    count = count + Bagzen.settings.global[section].width - math_mod(count, Bagzen.settings.global[section].width)
                end
            end
            if frame.KeyChain == true or bag ~= KEYRING_CONTAINER then
                count = count + (bagframe.Slots or 0)
            end
        end
    end

    local y = 4 + math.abs(Bagzen.MOD_Y) + Bagzen.SIZE_Y * (math.floor(count / Bagzen.settings.global[frame.SettingSection].width))
    if math_mod(count, Bagzen.settings.global[frame.SettingSection].width) > 0 then
        y = y + Bagzen.SIZE_Y
    end
    frame:SetHeight(y + 20)

    -- searchbox
    local searchbox = _G[frame:GetName() .. "SearchBox"]
    searchbox:SetWidth(Bagzen.settings.global[frame.SettingSection].width * Bagzen.SIZE_X - 4 * Bagzen.PADDING)

    Bagzen:CharactersFrameResize(frame)
end

-- Slot buttons exist in two independent sets: "Live" (this character, read
-- from the client) and "Virtual" (any character, read from the saved cache).
-- Only one set is on screen at a time, so showing one hides the other.
local function HideSlotSet(section, set)
    for bag, slots in pairs(Bagzen.ContainerFrames[set][section]) do
        if type(bag) == "number" then
            for _, slotframe in pairs(slots) do
                slotframe:Hide()
            end
        end
    end
end

-- Grid index of a bag's first slot: the slot counts of every bag ahead of it
-- in the frame's bag order. The keyring always starts on a fresh row.
local function SlotGridOffset(frame, bag)
    local width = Bagzen.settings.global[frame.SettingSection].width
    local index = 0
    for _, tmpbag in pairs(frame.Bags) do
        if tmpbag == bag then break end
        local bagslot = Bagzen:GetBagSlot(frame, tmpbag)
        index = index + ((bagslot and bagslot.Slots) or 0)
    end
    if bag == KEYRING_CONTAINER and math_mod(index, width) > 0 then
        index = index + width - math_mod(index, width)
    end
    return index
end

local function PlaceSlot(frame, slotframe, index)
    local width = Bagzen.settings.global[frame.SettingSection].width
    local x = Bagzen.PADDING + (Bagzen.SIZE_X * math_mod(index, width))
    local y = Bagzen.MOD_Y - (Bagzen.SIZE_Y * math.floor(index / width))
    -- a borrowed button still carries the anchors its own XML chained it to
    -- the neighbouring slots with; left in place they fight the grid point and
    -- the button's size is derived from the pair
    slotframe:ClearAllPoints()
    slotframe:SetPoint("TOPLEFT", frame:GetName(), "TOPLEFT", x, y)
    slotframe:Show()
end

-- Free-slot counter on the bag button. The keyring has none.
local function UpdateFreeSlotCount(frame, bag)
    if bag == KEYRING_CONTAINER then return end
    Bagzen:BagSlotFreeCount(Bagzen:GetBagSlot(frame, bag), Bagzen:GetContainerNumFreeSlots(bag, frame.OwnerRealm, frame.OwnerName))
end

-- A bag slot that holds no bag: drop its slots and its counter off screen.
local function HideBag(frame, set, bag)
    local _G = _G or getfenv()
    for _, slotframe in pairs(Bagzen.ContainerFrames[set][frame.SettingSection][bag]) do
        slotframe:Hide()
    end
    Bagzen:BagSlotFreeCount(Bagzen:GetBagSlot(frame, bag), nil)
end

-- Per-slot overlay for the scrap coin / quest marker, created on first use.
local function SlotOverlay(slotframe)
    local _G = _G or getfenv()
    return _G[slotframe:GetName() .. "texture"] or slotframe:CreateTexture(slotframe:GetName() .. "texture", "OVERLAY")
end

local function SlotName(frame, set)
    local section = frame.SettingSection
    Bagzen.ContainerFrames[set][section]["count"] = Bagzen.ContainerFrames[set][section]["count"] + 1
    return frame:GetName() .. set .. "ContainerSlot" .. Bagzen.ContainerFrames[set][section]["count"]
end

-- What a Bagzen slot looks like, read back from a button built the template
-- the cached view uses: that one defines the look of the grid, and a live slot
-- has to end up indistinguishable from the cached slot it replaces. Read
-- rather than assumed, because neither the declared size nor what
-- SetNormalTexture leaves behind comes out the same on every client.
local slotLook = nil
local function SlotLook()
    if slotLook == nil then
        slotLook = false
        local ok, reference = pcall(CreateFrame, "Button", "BagzenSlotLookReference", UIParent, "BagzanContainerItemTemplate")
        if ok and reference then
            reference:Hide()
            local look = {
                width = reference:GetWidth(),
                height = reference:GetHeight(),
            }
            local okNormal, normal = pcall(reference.GetNormalTexture, reference)
            if okNormal and normal then
                local point, _, relativePoint, x, y = normal:GetPoint()
                look.art = {
                    width = normal:GetWidth(),
                    height = normal:GetHeight(),
                    point = point or "CENTER",
                    relativePoint = relativePoint or "CENTER",
                    x = x or 0,
                    y = y or 0,
                }
            end
            slotLook = look
        end
    end
    return slotLook
end

-- Everything Bagzen adds to a live slot button on top of what its template
-- brings: its own slot art, the cooldown timer text, the per-bag background
-- tint and the glow Scrap.lua lights the worst scrap up with. Borrowed buttons
-- get all of it from here, since only Bagzen's own templates declare it.
-- On Unreal Azeroth a button created from an XML template under a scaled
-- parent comes out with its declared size multiplied by that scale, and so
-- does its art; a borrowed button, built by FrameXML under UIParent, does not.
-- Both are therefore restated from the reference, which is measured under
-- UIParent as well.
local function ApplySlotLook(slotframe)
    local look = SlotLook()
    if not look then return end

    if look.width and look.width > 0 then
        slotframe:SetWidth(look.width)
        slotframe:SetHeight(look.height)
    end

    local art = look.art
    if art then
        local ok, normal = pcall(slotframe.GetNormalTexture, slotframe)
        if ok and normal then
            normal:SetWidth(art.width)
            normal:SetHeight(art.height)
            normal:ClearAllPoints()
            normal:SetPoint(art.point, slotframe, art.relativePoint, art.x, art.y)
        end
    end
end

local function SkinLiveSlot(slotframe, section, bag)
    local _G = _G or getfenv()
    local name = slotframe:GetName()

    -- update graphical changes as we need the secure frame
    slotframe:SetNormalTexture("Interface\\AddOns\\Bagzen\\textures\\UI-Quickslot2")
    slotframe:SetPushedTexture("Interface\\AddOns\\Bagzen\\textures\\UI-Quickslot-Depress")
    ApplySlotLook(slotframe)
    -- Bagzen's own hover art, so a stock-template slot lights up the way the
    -- addon's own buttons do; HighlightSlots drives it through LockHighlight
    slotframe:SetHighlightTexture("Interface\\AddOns\\Bagzen\\textures\\ButtonHilight-Square", "ADD")
    _G[name .. "IconTexture"]:SetTexCoord(0.03, 0.97, 0.03, 0.97)

    if section ~= "bagframe" then return end

    local cooldownframe = _G[name .. "Cooldown"]
    if cooldownframe and cooldownframe.timeText == nil then
        if Bagzen.IsWOTLK then
            cooldownframe:SetScript("OnUpdate", function(self, elapsed)
                Bagzen:CooldownFrameOnUpdate(self, elapsed)
            end)
        elseif Bagzen.IsVanilla then
            cooldownframe:SetScript("OnUpdate", function()
                Bagzen:CooldownFrameOnUpdate(this, arg1)
            end)
        end
        local fontString = cooldownframe:CreateFontString(name .. "CooldownText", "OVERLAY", "BagzenFontOutline")
        fontString:SetPoint("CENTER", cooldownframe, "CENTER", 0, 0)
        fontString:SetTextColor(1, 1, 1)
        fontString:SetText("")
        cooldownframe.timeText = fontString
    end
    slotframe.cooldown = cooldownframe

    local background = _G[name .. "Background"]
    if background == nil then
        background = slotframe:CreateTexture(name .. "Background", "BACKGROUND")
        background:SetAllPoints(slotframe)
    end
    if bag == KEYRING_CONTAINER then
        -- tint the background of keyring slots
        background:SetTexture(0.83, 0.78, 0.64, 0.1)
    else
        background:SetTexture(0, 0, 0, 0.1)
    end

    -- Scrap.lua lights a slot up through this child, by name: an autocast
    -- shine on wrath, the autocast model on vanilla (no shine template there).
    if Bagzen.IsWOTLK then
        if _G[name .. "Shine"] == nil then
            local shine = CreateFrame("Frame", name .. "Shine", slotframe, "AutoCastShineTemplate")
            shine:SetWidth(38)
            shine:SetHeight(38)
            shine:SetPoint("CENTER", slotframe, "CENTER", 1, -1)
        end
    elseif _G[name .. "AutoCast"] == nil then
        local ok, model = pcall(CreateFrame, "Model", name .. "AutoCast", slotframe)
        if ok and model then
            if Bagzen.IsUA then
                -- SetScale is inert on a Model here, so the shine is sized by
                -- anchors reaching 6px past the button on every side (the
                -- outset the ElvUI vanilla port's spell book skin settled on).
                model:SetPoint("TOPLEFT", slotframe, "TOPLEFT", -6, 6)
                model:SetPoint("BOTTOMRIGHT", slotframe, "BOTTOMRIGHT", 6, -6)
            else
                model:SetWidth(38)
                model:SetHeight(38)
                model:SetPoint("CENTER", slotframe, "CENTER", 1, -1)
            end
            pcall(model.SetModel, model, "Interface\\Buttons\\UI-AutoCastButton.mdx")
            pcall(model.SetSequence, model, 0)
            pcall(model.SetSequenceTime, model, 0, 0)
            if not Bagzen.IsUA then
                -- Enlarged inside its own frame rather than by frame scale,
                -- and only once the shine is on screen: a scale set while the
                -- model file is still loading leaves the model invisible, both
                -- as a frame scale and as a model scale.
                model:SetScript("OnShow", function()
                    pcall(model.SetModelScale, model, 1.5)
                end)
            end
            model:Hide()
        end
    end
end

-- The native container frame that lends its item buttons to a bag.
-- ContainerFrame_Update finds the buttons by global name, so it keeps filling
-- them after they are reparented into Bagzen's grid; the lending frame only
-- has to carry the bag id and the slot count. The main bank panel is left out:
-- its slots are the BankFrameItem buttons, not a container's.
local function LendingContainer(frame, bag)
    local _G = _G or getfenv()
    local index = 0
    for _, tmp in pairs(frame.Bags) do
        if tmp == bag then break end
        if tmp ~= -1 then
            index = index + 1
        end
    end
    local first = 1
    if frame.SettingSection == "bankframe" then
        first = 7
    end
    local container = _G["ContainerFrame" .. (first + index)]
    if container and container.BagzenHacked == nil then
        Bagzen:HackID(container) -- the keyring's bag id is negative
        container.BagzenHacked = true
    end
    return container
end

-- Borrows one native item button. Its parent carries the bag id and the button
-- its slot id, which is what both the stock click handlers and
-- ContainerFrame_Update read.
local function BorrowLiveSlot(frame, bag, slot)
    local _G = _G or getfenv()
    local container = LendingContainer(frame, bag)
    if container == nil then return nil end

    local slotframe = _G[container:GetName() .. "Item" .. slot]
    if slotframe == nil then return nil end

    slotframe:SetParent(_G[frame:GetName() .. "DummyBagSlotFrame" .. Bagzen:FixBagNumber(bag)])
    slotframe:SetAlpha(1)
    slotframe:SetID(slot)
    slotframe.Borrowed = true
    SkinLiveSlot(slotframe, frame.SettingSection, bag)
    return slotframe
end

-- Hands the bag to the client to paint: every borrowed button of this bag is
-- filled in one pass, with the icon, count, lock state and cooldown the client
-- itself reads out of the bag.
local function PaintBorrowedBag(frame, bag, numslots)
    local container = LendingContainer(frame, bag)
    if container == nil then return end
    container:SetID(bag)
    container.size = numslots
    pcall(ContainerFrame_Update, container)
end

-- The main bank panel's slots are the BankFrameItem buttons rather than a
-- container's: their own id is the bank slot the stock handlers read, and it
-- already matches Bagzen's slot numbering, so it is left alone.
local function BorrowBankPanelSlot(frame, slot)
    local _G = _G or getfenv()
    local slotframe = _G["BankFrameItem" .. slot]
    if slotframe == nil then return nil end

    slotframe:SetParent(_G[frame:GetName() .. "DummyBagSlotFrame" .. Bagzen:FixBagNumber(-1)])
    slotframe:SetAlpha(1)
    slotframe.Borrowed = true
    SkinLiveSlot(slotframe, frame.SettingSection, -1)
    if Bagzen.IsUA then
        Bagzen:TooltipHookBankButton(slotframe)
    end
    return slotframe
end

-- Those buttons paint on their own event only, and the stock template's OnShow
-- is empty, so a window that has just been shown needs one manual pass each.
local function PaintBorrowedBankPanel(slots, numslots)
    local caller = this
    for slot = 1, numslots do
        local slotframe = slots[slot]
        if slotframe and slotframe.Borrowed == true then
            if Bagzen.IsWOTLK then
                pcall(BankFrameItemButton_Update, slotframe)
            else
                this = slotframe
                pcall(BankFrameItemButton_OnUpdate)
            end
        end
    end
    this = caller
end

-- Reported once per bag: every client Bagzen supports has a native button for
-- every slot, so a miss means the container-to-bag mapping above does not hold
-- on this one, and the bag would silently come up short of slots.
local missingSlots = {}

local function AcquireLiveSlot(frame, bag, slot)
    local slotframe
    if bag == -1 then
        slotframe = BorrowBankPanelSlot(frame, slot)
    else
        slotframe = BorrowLiveSlot(frame, bag, slot)
    end
    if slotframe == nil and missingSlots[bag] == nil then
        missingSlots[bag] = true
        Bagzen:Print("no native button to borrow for bag " .. bag .. " slot " .. slot)
    end
    return slotframe
end

local function PaintLiveSlots(frame, bag, numslots, slots)
    if bag == -1 then
        PaintBorrowedBankPanel(slots, numslots)
    else
        PaintBorrowedBag(frame, bag, numslots)
    end
end

-- Cached slots are display only, so they use Bagzen's own button template.
local function CreateVirtualSlot(frame, bag, slot)
    local _G = _G or getfenv()
    local parentdummy = _G[frame:GetName() .. "DummyBagSlotFrame" .. Bagzen:FixBagNumber(bag)]
    local slotframe = CreateFrame("Button", SlotName(frame, "Virtual"), parentdummy, "BagzanContainerItemTemplate")
    slotframe:SetID(slot)
    ApplySlotLook(slotframe)
    if frame.SettingSection == "bagframe" then
        local slotbackground = _G[slotframe:GetName() .. "Background"]
        if bag == KEYRING_CONTAINER then
            -- tint the background of keyring slots
            slotbackground:SetTexture(0.83, 0.78, 0.64, 0.1)
        else
            slotbackground:SetTexture(0, 0, 0, 0.1)
        end
    end
    return slotframe
end

-- A borrowed button's icon and count are the client's to paint, so an empty
-- slot only has Bagzen's own marks cleared off it.
local function ClearSlot(slotframe, borrowed)
    if not borrowed then
        SetItemButtonTexture(slotframe, nil)
        SetItemButtonCount(slotframe, 0)
    end
    Bagzen:SetSlotBorderColor(slotframe, 1, 1, 1)
    slotframe.ItemID = nil
    slotframe.ItemLink = nil
    slotframe.ItemName = nil
    SlotOverlay(slotframe):SetTexture(nil)
end

-- Item identity shared by both sets: the quality border and the fields the
-- search box, sorter and tooltip read off the button.
local function SetSlotItem(slotframe, itemLink)
    local itemID = Bagzen:LinkToItemID(itemLink)
    local itemName, _, itemQuality = Bagzen:GetItemInfo(itemID)
    local itemQualityColor = ITEM_QUALITY_COLORS[itemQuality]
    slotframe.ItemID = itemID
    slotframe.ItemName = itemName
    slotframe.ItemLink = itemLink
    if itemQualityColor then
        Bagzen:SetSlotBorderColor(slotframe, itemQualityColor.r, itemQualityColor.g, itemQualityColor.b)
    end
    return itemID
end

local function FillLiveSlot(frame, bag, slot, slotframe)
    local section = frame.SettingSection
    local borrowed = slotframe.Borrowed == true
    -- the link decides whether the slot holds an item: GetContainerItemInfo
    -- reports an empty string as the texture of an empty slot on UA, which is
    -- truthy
    local itemLink = GetContainerItemLink(bag, slot)

    if itemLink == nil then
        ClearSlot(slotframe, borrowed)
        if section == "bagframe" and slotframe.cooldown then
            slotframe.cooldown:Hide()
        end
        return
    end

    local itemtexture, itemcount = GetContainerItemInfo(bag, slot)
    if not borrowed then
        SetItemButtonTexture(slotframe, itemtexture)
        SetItemButtonCount(slotframe, itemcount)
    end

    if section == "bagframe" then
        local cooldownframe = slotframe.cooldown
        local start, duration, enable = GetContainerItemCooldown(bag, slot)
        CooldownFrame_SetTimer(cooldownframe, start, duration, enable)
        cooldownframe._cooldownStart = start
        cooldownframe._cooldownDuration = duration
        cooldownframe._cooldownEnable = enable
        if duration > 0 and enable == 0 then
            SetItemButtonTextureVertexColor(slotframe, 0.4, 0.4, 0.4)
        else
            SetItemButtonTextureVertexColor(slotframe, 1, 1, 1)
        end
    end

    local itemID = SetSlotItem(slotframe, itemLink)

    local overlay = SlotOverlay(slotframe)
    if Bagzen:isScrap(itemID) then
        overlay:SetTexture("Interface/Buttons/UI-GroupLoot-Coin-Up")
        overlay:SetPoint("TOPLEFT", 3, -3)
        overlay:SetWidth(15)
        overlay:SetHeight(15)
    elseif Bagzen:isQuestItem(itemID) then
        overlay:SetTexture("Interface\\AddOns\\Bagzen\\textures\\BagQuestIcon")
        overlay:SetPoint("TOPLEFT", 2, -2)
        overlay:SetWidth(32)
        overlay:SetHeight(32)
    else
        overlay:SetTexture(nil)
    end

    -- feed the cache the other characters' views read from
    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags[bag].slots[slot] = {
        count = itemcount,
        link = itemLink,
        texture = itemtexture
    }
end

local function FillVirtualSlot(frame, bag, slot, slotframe)
    local bags = Bagzen.data.global[frame.OwnerRealm][frame.OwnerName].bags
    local cached = bags and bags[bag] and bags[bag].slots[slot]

    if not (cached and cached.texture) then
        ClearSlot(slotframe, false)
        return
    end

    SetItemButtonTexture(slotframe, cached.texture)
    SetItemButtonCount(slotframe, cached.count)
    SetSlotItem(slotframe, cached.link)
end

function Bagzen:ContainerItemUpdateLive(frame, bag)
    local section = frame.SettingSection
    local slots = Bagzen.ContainerFrames["Live"][section][bag]
    local numslots = Bagzen:GetBagSlot(frame, bag).Slots

    -- TODO: set already hided to prevent this loop from running
    HideSlotSet(section, "Virtual")

    if numslots == 0 and bag ~= KEYRING_CONTAINER then
        HideBag(frame, "Live", bag)
        return
    end

    for slot = 1, numslots do
        if slots[slot] == nil then
            slots[slot] = AcquireLiveSlot(frame, bag, slot)
        end
    end

    PaintLiveSlots(frame, bag, numslots, slots)

    local index = SlotGridOffset(frame, bag)
    for slot, slotframe in pairs(slots) do
        if slot <= numslots then
            FillLiveSlot(frame, bag, slot, slotframe)
            PlaceSlot(frame, slotframe, index)
        else
            slotframe:Hide()
        end
        index = index + 1
    end

    UpdateFreeSlotCount(frame, bag)
end

function Bagzen:ContainerItemUpdateVirtual(frame, bag)
    local section = frame.SettingSection
    local slots = Bagzen.ContainerFrames["Virtual"][section][bag]
    local numslots = Bagzen:GetBagSlot(frame, bag).Slots

    -- TODO: set already hided to prevent this loop from running
    HideSlotSet(section, "Live")

    if numslots == 0 and bag ~= KEYRING_CONTAINER then
        HideBag(frame, "Virtual", bag)
        return
    end

    for slot = 1, numslots do
        if slots[slot] == nil then
            slots[slot] = CreateVirtualSlot(frame, bag, slot)
        end
    end

    local index = SlotGridOffset(frame, bag)
    for slot, slotframe in pairs(slots) do
        if slot <= numslots then
            FillVirtualSlot(frame, bag, slot, slotframe)
            PlaceSlot(frame, slotframe, index)
        else
            slotframe:Hide()
        end
        index = index + 1
    end

    UpdateFreeSlotCount(frame, bag)
end

function Bagzen:ContainerItemUpdate(frame, bag)
    if frame.Virtual == true then
        Bagzen:ContainerItemUpdateVirtual(frame, bag)
    else
        Bagzen:ContainerItemUpdateLive(frame, bag)
    end
end
-- One bag must not take the whole window with it: a native call that throws
-- on one client would otherwise leave the frame half built, and a window that
-- is shown at the end of the update never becomes visible at all. The message
-- names the bag so the cause stays identifiable.
local function UpdateBag(frame, bag)
    local ok, err = pcall(Bagzen.BagSlotUpdate, Bagzen, frame, bag)
    if not ok then
        Bagzen:Print("bag " .. bag .. " slots: " .. tostring(err))
        return
    end
    ok, err = pcall(Bagzen.ContainerItemUpdate, Bagzen, frame, bag)
    if not ok then
        Bagzen:Print("bag " .. bag .. " items: " .. tostring(err))
    end
end

function Bagzen:ContainerUpdate(frame, realm, name)
    local _G = _G or getfenv()
    frame.OwnerName = name
    frame.OwnerRealm = realm
    if frame:GetName() == "BagzenBagFrame" then
        -- bagframe
        if frame.OwnerName == Bagzen.unitname and frame.OwnerRealm == Bagzen.realmname then
            frame.Virtual = false
        else
            frame.Virtual = true
        end
    else
        -- bankframe
        frame.Virtual = true
        if frame.Real == true and frame.OwnerName == Bagzen.unitname and frame.OwnerRealm == Bagzen.realmname then
            frame.Virtual = false
        end

        if frame.Virtual == true then
            _G[frame:GetName() .. "OnlineButton"]:Hide()
            _G[frame:GetName() .. "OfflineButton"]:Show()
        else
            local numBankSlots = GetNumBankSlots()
            Bagzen.data.global[frame.OwnerRealm][frame.OwnerName].bagslots = numBankSlots
            frame.nextSlotCost = GetBankSlotCost(numBankSlots)
            _G[frame:GetName() .. "OnlineButton"]:Show()
            _G[frame:GetName() .. "OfflineButton"]:Hide()
        end
    end

    if frame.Virtual == true then
        _G[frame:GetName() .. "SortButton"]:Hide()
    else
        _G[frame:GetName() .. "SortButton"]:Show()
    end

    local titleframe = _G[frame:GetName() .. "TitleText"]
    titleframe:SetText(string.format("%s's %s", frame.OwnerName, frame.FrameName))

    for _, bag in pairs(frame.Bags) do
        UpdateBag(frame, bag)
    end
    Bagzen:ContainerResize(frame)
end

function Bagzen:ContainerReposition(frame)
    local scale = Bagzen.settings.char[frame.SettingSection].scale or 1
    if scale then
        frame:SetScale(scale)
    end
    if Bagzen.settings.char[frame.SettingSection].point then
        frame:SetPoint(Bagzen.settings.char[frame.SettingSection].point, nil, Bagzen.settings.char[frame.SettingSection].relativePoint, Bagzen.settings.char[frame.SettingSection].xOfs, Bagzen.settings.char[frame.SettingSection].yOfs)
    else
        local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        if frame:GetName() == "BagzenBagFrame" then
            local gapX = 300
            local gapY = 300
            BagzenBagFrame:SetPoint("TOPLEFT", "UIParent", "TOPLEFT", (UIParent:GetWidth() - gapX * ratio), -1 * (UIParent:GetHeight() - gapY) * ratio)
        else
            local gapX = 100
            local gapY = 100
            BagzenBankFrame:SetPoint("TOPLEFT", "UIParent", "TOPLEFT", gapX, -1 * gapY)
        end
    end
end
