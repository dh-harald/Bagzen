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

function Bagzen:ContainerResize(frame)
    local _G = _G or getfenv()
    frame:SetWidth(Bagzen.settings.global[frame.SettingSection].width * Bagzen.SIZE_X)
    local count = 0
    for _, bag in pairs(frame.Bags) do
        if bag ~= KEYRING_CONTAINER then
            local bagframe = _G[frame:GetName() .. "BagSlotsFrame" .. bag]
            if bagframe then
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
    if bag == KEYRING_CONTAINER then return end -- sanity check
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
    for bag, _ in pairs(Bagzen.ContainerFrames[notlive][section]) do
        if type(bag) == "number" then
            for _, f in pairs(Bagzen.ContainerFrames[notlive][section][bag]) do
                f:Hide()
            end
        end
    end

    if numslots == 0 then
        for _, f in pairs(Bagzen.ContainerFrames[live][section][bag]) do
            f:Hide()
        end
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
                if section == "bagframe" then
                    slotframe = CreateFrame("Button", framename, parentdummy, "ContainerFrameItemButtonTemplate")
                else
                    if Bagzen.IsWOTLK then
                        slotframe = CreateFrame("Button", framename, parentdummy, "BankItemButtonGenericTemplate")
                    else
                        slotframe = CreateFrame("Button", framename, parentdummy, "BankItemButtonTemplate")
                        slotframe.GetInventorySlot = function(self)
                            return self:GetID()
                        end
                    end
                end
                -- update graphical changes as we need the secure frame
                slotframe:SetNormalTexture("Interface\\AddOns\\Bagzen\\textures\\UI-Quickslot2.tga")
                slotframe:SetPushedTexture("Interface\\AddOns\\Bagzen\\textures\\UI-Quickslot-Depress.tga")
                slotframe:SetHighlightTexture("Interface\\AddOns\\Bagzen\\textures\\UI-Quickslot-Highlight.tga")
                _G[slotframe:GetName() .. "IconTexture"]:SetTexCoord(0.03, 0.97, 0.03, 0.97)
            else
                slotframe = CreateFrame("Button", framename, parentdummy, "BagzanContainerItemTemplate")
            end
            Bagzen.ContainerFrames[live][section][bag][slot] = slotframe
            slotframe:SetID(slot)
        end
    end

    local count = 0
    for _, tmpbag in pairs(frame.Bags) do
        if tmpbag == bag then break end
        count = count + (_G[frame:GetName() .. "BagSlotsFrame" .. tmpbag].Slots or 0)
    end

    for slot, slotframe in pairs(Bagzen.ContainerFrames[live][section][bag]) do
        if slot <= numslots then
            local texture = _G[slotframe:GetName() .. "texture"] or slotframe:CreateTexture(slotframe:GetName() .. "texture", 'OVERLAY')
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
                    ContainerFrame_UpdateCooldown(slotframe:GetParent():GetID(), slotframe)
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
