
function Bagzen:CharactersFrameToggle(frame)
    local _G = _G or getfenv()
    local charactersframe = _G[frame:GetParent():GetName() .. "CharactersFrame"]
    if charactersframe:IsShown() then
        charactersframe:Hide()
    else
        charactersframe:Show()
    end
end

function Bagzen:CharactersFrameInit()
    local _G = _G or getfenv()
    Bagzen.CharacterButtonCount = 0
    Bagzen.CharacterButtons = {
        ["bagframe"] = {},
        ["bankframe"] = {},
    }

    local count = 0
    -- TODO: calculate this framenames
    local bag = _G["BagzenBagFrameCharactersFrameCharacterList"]
    local bank = _G["BagzenBankFrameCharactersFrameCharacterList"]
    for _, _ in pairs(Bagzen.data.global[Bagzen.realmname]) do
        count = count + 1
        Bagzen.CharacterButtons["bagframe"][count] = Bagzen.CharacterButtons["bagframe"][count] or CreateFrame("button", "BagzenBagFrameCharacterButton" .. count, bag, "BagzenCharacterButtonTemplate")
        Bagzen.CharacterButtons["bankframe"][count] = Bagzen.CharacterButtons["bankframe"][count] or CreateFrame("button", "BagzenBankFrameCharacterButton" .. count, bank, "BagzenCharacterButtonTemplate")
    end
    Bagzen.CharacterButtonCount = count
    bag.Offset = 0
    bank.Offset = 0
end

function Bagzen:CharactersFrameUpdate(frame)
    local _G = _G or getfenv()
    local count = 0
    local searchText = _G[frame:GetName() .. "CharactersFrameSearchBox"]:GetText()
    local charactersframe = _G[frame:GetName() .. "CharactersFrame"]
    local size = (math.floor(charactersframe:GetHeight() + 0.5) - 92) / 20
    local offset = _G[frame:GetName() .. "CharactersFrameCharacterList"].Offset
    local upButton = _G[frame:GetName() .. "CharactersFrameCharacterListSliderScrollUpButton"]
    local downButton = _G[frame:GetName() .. "CharactersFrameCharacterListSliderScrollDownButton"]

    local MOD_Y = Bagzen.MOD_Y - 18

    local chars = {}
    local showcount = 0
    for character, _ in pairs(Bagzen.data.global[Bagzen.realmname]) do
        if searchText == "" or string.find(string.lower(character), string.lower(searchText)) then
            table.insert(chars, character)
            showcount = showcount + 1
        end
    end
    frame.ShowCount = showcount

    table.sort(chars)

    if offset == 0 then
        upButton:Disable()
    else
        upButton:Enable()
    end

    if offset + size >= showcount then
        downButton:Disable()
    else
        downButton:Enable()
    end

    local chars2 = {}

    for i = 1, size do
        table.insert(chars2, chars[offset + i])
    end

    for _, character in pairs(chars2) do
        local data = Bagzen.data.global[Bagzen.realmname][character]
        count = count + 1
        local button = Bagzen.CharacterButtons[frame.SettingSection][count]
        local lefttext = _G[button:GetName() .. "LeftText"]
        local color = RAID_CLASS_COLORS[data.class]
        lefttext:SetTextColor(color.r, color.g, color.b)
        local righttext = _G[button:GetName() .. "RightText"]
        local dot = _G[button:GetName() .. "Dot"]
        lefttext:SetText(character)
        righttext:SetText(Bagzen.realmname)
        button.value = count
        button.ParentFrame = frame:GetName()
        Bagzen:CharacterButtonAnchors(button, charactersframe, MOD_Y - (count - 1) * (Bagzen.SIZE_Y / 2))

        if frame.OwnerRealm == righttext:GetText() and frame.OwnerName == lefttext:GetText() then
            dot:Show()
        else
            dot:Hide()
        end
        button:Show()
    end

    for i, button in pairs(Bagzen.CharacterButtons[frame.SettingSection]) do
        if i > count then
            button:Hide()
            button.value = nil
            button.ParentFrame = nil
            local lefttext = _G[button:GetName() .. "LeftText"]
            local righttext = _G[button:GetName() .. "RightText"]
            local dot = _G[button:GetName() .. "Dot"]
            lefttext:SetText("")
            righttext:SetText("")
            dot:Hide()
        end
    end
end

function Bagzen:CharactersFrameResize(parent)
    local _G = _G or getfenv()
    local MIN_HEIGHT = 152 -- 2 lines of bagslots
    -- todo: calculate this if needed
    local width = 200
    local parentHeight = parent:GetHeight()
    local frame = _G[parent:GetName() .. "CharactersFrame"]

    if parentHeight <= MIN_HEIGHT then
        frame:SetHeight(MIN_HEIGHT)
    else
        frame:SetHeight(parentHeight)
    end

    frame:SetWidth(width)

    local searchFrame = _G[parent:GetName() .. "CharactersFrameSearchBox"]
    searchFrame:SetWidth(width - 4 * Bagzen.PADDING)
    Bagzen:CharactersFrameAnchors(frame, width, frame:GetHeight())
    Bagzen:CharactersFrameFixOffset(parent)
    Bagzen:CharactersFrameUpdate(parent)
end

-- The template's Title and CharacterList anchor TOPLEFT to the parent's
-- TOPRIGHT, producing an inverted rect. The stock client normalizes that
-- (Title spans the full width, CharacterList becomes the 24px column at the
-- right edge); Unreal Azeroth collapses the frame onto its first anchor
-- instead. Build that geometry explicitly with single anchors and sizes so
-- both clients lay out the same. ClearAllPoints is only safe because every
-- axis is set again here.
function Bagzen:CharactersFrameAnchors(frame, width, height)
    local _G = _G or getfenv()
    local name = frame:GetName()

    local title = _G[name .. "Title"]
    title:ClearAllPoints()
    title:SetPoint("TOP", frame, "TOP", 0, 0)
    title:SetWidth(width - 4)
    title:SetHeight(20)

    -- UA ignores justifyV and two-edge text spans: one CENTER anchor plus an
    -- explicit width centers the text reliably
    local titletext = _G[name .. "TitleText"]
    titletext:ClearAllPoints()
    titletext:SetPoint("CENTER", title, "CENTER", 0, 0)
    titletext:SetWidth(width - 4)

    local list = _G[name .. "CharacterList"]
    list:ClearAllPoints()
    list:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, -48)
    list:SetWidth(24)
    list:SetHeight(height - 50)

    -- holds the scroll buttons only (no thumb); they anchor to its TOP/BOTTOM
    local slider = _G[name .. "CharacterListSlider"]
    slider:ClearAllPoints()
    slider:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -20)
    slider:SetWidth(24)
    slider:SetHeight(height - 90)
end

-- Row buttons take their right edge from the template's CharacterList
-- anchor, and their FontStrings combine setAllPoints with a two-edge span;
-- Unreal Azeroth renders both at the wrong spot. Size the row explicitly
-- (2px to the frame's right edge) and pin each text to its own edge with an
-- explicit width.
function Bagzen:CharacterButtonAnchors(button, charactersframe, y)
    local _G = _G or getfenv()
    local name = button:GetName()
    local width = charactersframe:GetWidth() - 2
    local textwidth = (width - 40) / 2

    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", charactersframe, "TOPLEFT", 2, y)
    button:SetWidth(width)
    button:SetHeight(20)

    -- Button SetWidth/SetHeight does not resize the highlight texture on UA
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
        highlight:ClearAllPoints()
        highlight:SetAllPoints(button)
    end

    local lefttext = _G[name .. "LeftText"]
    lefttext:ClearAllPoints()
    lefttext:SetPoint("LEFT", button, "LEFT", 20, 0)
    lefttext:SetWidth(textwidth)
    lefttext:SetJustifyH("LEFT")

    local righttext = _G[name .. "RightText"]
    righttext:ClearAllPoints()
    righttext:SetPoint("RIGHT", button, "RIGHT", -20, 0)
    righttext:SetWidth(textwidth)
    righttext:SetJustifyH("RIGHT")
end

function Bagzen:CharactersFrameFixOffset(frame)
    local _G = _G or getfenv()
    local searchText = _G[frame:GetName() .. "CharactersFrameSearchBox"]:GetText()
    local charactersframe = _G[frame:GetName() .. "CharactersFrame"]
    local size = (math.floor(charactersframe:GetHeight() + 0.5) - 92) / 20
    local offset = _G[frame:GetName() .. "CharactersFrameCharacterList"].Offset

    local chars = {}
    local showcount = 0
    for character, _ in pairs(Bagzen.data.global[Bagzen.realmname]) do
        if searchText == "" or string.find(string.lower(character), string.lower(searchText)) then
            table.insert(chars, character)
            showcount = showcount + 1
        end
    end

    table.sort(chars)

    local curpos
    for i, character in pairs(chars) do
        if character == frame.OwnerName then
            curpos = i
            break
        end
    end

    if offset + size < curpos then
        offset = curpos - size + 1
        _G[frame:GetName() .. "CharactersFrameCharacterList"].Offset = offset
    end

    if showcount - offset < size then
        if showcount > size then
            offset = showcount - size
        else
            offset = 0
        end
        _G[frame:GetName() .. "CharactersFrameCharacterList"].Offset = offset
    end
end

function Bagzen:CharacterButtonOnClick(frame)
    local _G = _G or getfenv()
    local framename = frame:GetName()
    local realmname = _G[framename .. "RightText"]:GetText()
    local unitname = _G[framename .. "LeftText"]:GetText()
    local parentFrame = _G[frame.ParentFrame]

    Bagzen:ContainerUpdate(parentFrame, realmname, unitname)
    Bagzen:CharactersFrameFixOffset(parentFrame)
    Bagzen:CharactersFrameUpdate(parentFrame)
    Bagzen:ContainerReposition(parentFrame)
    local money = Bagzen.data.global[realmname][unitname].money or 0
    local moneyframe = _G[parentFrame:GetName() .. "MoneyFrame"]
    Bagzen:MoneyFrameUpdate(moneyframe, money)
end

function Bagzen:CharacterFrameOnWheel(frame, arg1)
    local changed = false
    if arg1 > 0 then
        if frame.Offset > 0 then
            frame.Offset = frame.Offset - 1
            changed = true
        end
    else
        local showcount = frame:GetParent():GetParent().ShowCount
        local size = (math.floor(frame:GetParent():GetHeight() + 0.5) - 92) / 20
        if frame.Offset + size < showcount then
            frame.Offset = frame.Offset + 1
            changed = true
        end
    end
    if changed == true then
        PlaySound("UChatScrollButton")
        Bagzen:CharactersFrameUpdate(frame:GetParent():GetParent())
    end
end
