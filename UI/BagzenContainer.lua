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
        local bagframe = _G[frame:GetName() .. "BagSlotsFrame" .. bag]
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

function Bagzen:ContainerItemUpdate(frame, bag)
    local _G = _G or getfenv()
    local section = frame.SettingSection
    local live, notlive
    if frame.Virtual == true then
        live = "Virtual"
        notlive = "Live"
    else
        live = "Live"
        notlive = "Virtual"
    end

    local parent = _G[frame:GetName() .. "BagSlotsFrame" .. bag]
    local numslots = parent.Slots

    -- TODO: set already hided to prevent this loop from running
    for tbag, _ in pairs(Bagzen.ContainerFrames[notlive][section]) do
        if type(tbag) == "number" then
            for _, f in pairs(Bagzen.ContainerFrames[notlive][section][tbag]) do
                f:Hide()
            end
        end
    end

    if numslots == 0 and bag ~= KEYRING_CONTAINER then
        for _, f in pairs(Bagzen.ContainerFrames[live][section][bag]) do
            f:Hide()
        end
        local countFrame = _G[frame:GetName() .. "BagSlotsFrame" .. bag .. "Count"]
        countFrame:SetText("")
        countFrame:Hide()
        return
    end

    for slot = 1, numslots do
        local slotframe = nil
        if Bagzen.ContainerFrames[live][section][bag][slot] ~= nil then
            slotframe = Bagzen.ContainerFrames[live][section][bag][slot]
        else
            local parentdummy = _G[frame:GetName() .. "DummyBagSlotFrame" .. bag]
            Bagzen.ContainerFrames[live][section]["count"] = Bagzen.ContainerFrames[live][section]["count"] + 1
            local framename = frame:GetName() .. live .. "ContainerSlot" .. Bagzen.ContainerFrames[live][section]["count"]
            if frame.Virtual == false then
                if section == "bagframe" or (section == "bankframe" and bag >= 5) then
                    if Bagzen.IsWOTLK then -- we can shine/glow
                        slotframe = CreateFrame("Button", framename, parentdummy, "BagzenWOTLKContainerFrameItemButtonTemplate")
                    elseif Bagzen.IsVanilla then
                        slotframe = CreateFrame("Button", framename, parentdummy, "BagzenVanillaContainerFrameItemButtonTemplate")
                    end
                else
                    slotframe = CreateFrame("Button", framename, parentdummy, "BankItemButtonGenericTemplate")
                end
                -- update graphical changes as we need the secure frame
                slotframe:SetNormalTexture("Interface\\AddOns\\Bagzen\\textures\\UI-Quickslot2.tga")
                slotframe:SetPushedTexture("Interface\\AddOns\\Bagzen\\textures\\UI-Quickslot-Depress.tga")
                slotframe:SetHighlightTexture("Interface\\AddOns\\Bagzen\\textures\\UI-Quickslot-Highlight.tga")
                _G[slotframe:GetName() .. "IconTexture"]:SetTexCoord(0.03, 0.97, 0.03, 0.97)
                if section == "bagframe" then
                    local cooldownframe = _G[slotframe:GetName() .. "Cooldown"]
                    if Bagzen.IsWOTLK then
                        cooldownframe:SetScript("OnUpdate", function(self, elapsed)
                            Bagzen:CooldownFrameOnUpdate(self, elapsed)
                        end)
                    elseif Bagzen.IsVanilla then
                        cooldownframe:SetScript("OnUpdate", function()
                            Bagzen:CooldownFrameOnUpdate(this, arg1)
                        end)
                    end
                    slotframe.cooldown = cooldownframe
                    local fontString = cooldownframe:CreateFontString(slotframe:GetName() .. "CooldownText", "OVERLAY", "BagzenFontOutline")
                    fontString:SetPoint("CENTER", cooldownframe, "CENTER", 0, 0)
                    fontString:SetTextColor(1, 1, 1)
                    fontString:SetText("")
                    cooldownframe.timeText = fontString
                end
            else
                slotframe = CreateFrame("Button", framename, parentdummy, "BagzanContainerItemTemplate")
            end
            Bagzen.ContainerFrames[live][section][bag][slot] = slotframe
            slotframe:SetID(slot)
            if section == "bagframe" then
                local slotbackground = _G[slotframe:GetName() .. "Background"]
                if bag == KEYRING_CONTAINER then
                    -- tint the background of keyring slots
                    slotbackground:SetTexture(0.83, 0.78, 0.64, 0.1)
                else
                    slotbackground:SetTexture(0, 0, 0, 0.1)
                end
            end
        end
    end

    local count = 0
    for _, tmpbag in pairs(frame.Bags) do
        if tmpbag == bag then break end
        count = count + (_G[frame:GetName() .. "BagSlotsFrame" .. tmpbag].Slots or 0)
    end

    if bag == KEYRING_CONTAINER then
        -- start a new row for keyring
        if math_mod(count, Bagzen.settings.global[section].width) > 0 then
            count = count + Bagzen.settings.global[section].width - math_mod(count, Bagzen.settings.global[section].width)
        end
    end

    for slot, slotframe in pairs(Bagzen.ContainerFrames[live][section][bag]) do
        if slot <= numslots then
            local texture = _G[slotframe:GetName() .. "texture"] or slotframe:CreateTexture(slotframe:GetName() .. "texture", 'OVERLAY')
            local cooldownframe = slotframe.cooldown
            local itemtexture = nil
            local itemcount = nil
            if frame.Virtual == false then
                 itemtexture, itemcount = GetContainerItemInfo(slotframe:GetParent():GetID(), slotframe:GetID())
            else
                if (Bagzen.data.global[frame.OwnerRealm][frame.OwnerName].bags and
                        Bagzen.data.global[frame.OwnerRealm][frame.OwnerName].bags[slotframe:GetParent():GetID()] and
                        Bagzen.data.global[frame.OwnerRealm][frame.OwnerName].bags[slotframe:GetParent():GetID()].slots[slotframe:GetID()]) then
                    itemtexture = Bagzen.data.global[frame.OwnerRealm][frame.OwnerName].bags[slotframe:GetParent():GetID()].slots[slotframe:GetID()].texture
                    itemcount = Bagzen.data.global[frame.OwnerRealm][frame.OwnerName].bags[slotframe:GetParent():GetID()].slots[slotframe:GetID()].count
                end
            end
            if itemtexture then
                SetItemButtonTexture(slotframe, itemtexture)
                SetItemButtonCount(slotframe, itemcount)
                if section == "bagframe" and frame.Virtual == false then
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
                local itemLink = nil
                if frame.Virtual == false then
                    itemLink = GetContainerItemLink(slotframe:GetParent():GetID(), slotframe:GetID())
                else
                    itemLink = Bagzen.data.global[frame.OwnerRealm][frame.OwnerName].bags[slotframe:GetParent():GetID()].slots[slotframe:GetID()].link
                end
                local itemID = Bagzen:LinkToItemID(itemLink)
                local itemName = Bagzen:GetItemInfo(itemID)
                slotframe.ItemID = itemID
                slotframe.ItemName = itemName
                slotframe.ItemLink = itemLink
                if frame.Virtual == false then
                    if Bagzen:isScrap(itemID) then
                        texture:SetTexture('Interface/Buttons/UI-GroupLoot-Coin-Up')
                        texture:SetPoint('TOPLEFT', 3, -3)
                        texture:SetWidth(15)
                        texture:SetHeight(15)
                    elseif Bagzen:isQuestItem(itemID) then
                        texture:SetTexture('Interface\\AddOns\\Bagzen\\textures\\BagQuestIcon.tga')
                        texture:SetPoint('TOPLEFT', 2, -2)
                        texture:SetWidth(32)
                        texture:SetHeight(32)
                    else
                        texture:SetTexture(nil)
                    end
                    -- save item
                    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags[slotframe:GetParent():GetID()].slots[slot] = {
                        count = itemcount,
                        link = itemLink,
                        texture = itemtexture
                    }
                end
            else
                SetItemButtonTexture(slotframe, nil)
                SetItemButtonCount(slotframe, 0)
                slotframe.ItemID = nil
                slotframe.ItemLink = nil
                slotframe.ItemName = nil
                texture:SetTexture(nil)
                if section == "bagframe" and frame.Virtual == false then
                    cooldownframe:Hide()
                end
            end
            local POS_X = Bagzen.PADDING + (Bagzen.SIZE_X * math_mod(count, Bagzen.settings.global[section].width))
            local POS_Y = Bagzen.MOD_Y - (Bagzen.SIZE_Y * math.floor(count / Bagzen.settings.global[section].width))
            slotframe:SetPoint("TOPLEFT", frame:GetName(), "TOPLEFT", POS_X, POS_Y)
            slotframe:Show()
        else
            slotframe:Hide()
        end
        count = count + 1
    end

    -- show free slots on bags (no keyring)
    if bag ~= KEYRING_CONTAINER then
        local slotfree = Bagzen:GetContainerNumFreeSlots(bag, frame.OwnerRealm, frame.OwnerName)
        local countFrame = _G[frame:GetName() .. "BagSlotsFrame" .. bag .. "Count"]
        countFrame:Show()
        countFrame:SetText(slotfree)
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
        Bagzen:BagSlotUpdate(frame, bag)
        Bagzen:ContainerItemUpdate(frame, bag)
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
