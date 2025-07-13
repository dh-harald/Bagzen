
function Bagzen:CharactersFrameToggle(frame)
    local charactersframe = getglobal(frame:GetParent():GetName() .. "CharactersFrame")
    if charactersframe:IsShown() then
        charactersframe:Hide()
    else
        charactersframe:Show()
    end
end

function Bagzen:CharactersFrameInit()
    Bagzen.CharacterButtonCount = 0
    Bagzen.CharacterButtons = {
        ["bagframe"] = {},
        ["bankframe"] = {},
    }

    local count = 0
    -- TODO: calculate this framenames
    local bag = getglobal("BagzenBagFrameCharactersFrameCharacterList")
    local bank = getglobal("BagzenBankFrameCharactersFrameCharacterList")
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
    local count = 0
    local searchText = getglobal(frame:GetName() .. "CharactersFrameSearchBox"):GetText()
    local charactersframe = getglobal(frame:GetName() .. "CharactersFrame")
    local size = (math.floor(charactersframe:GetHeight() + 0.5) - 92) / 20
    local offset = getglobal(frame:GetName() .. "CharactersFrameCharacterList").Offset
    local upButton = getglobal(frame:GetName() .. "CharactersFrameCharacterListSliderScrollUpButton")
    local downButton = getglobal(frame:GetName() .. "CharactersFrameCharacterListSliderScrollDownButton")

    local MOD_Y = Bagzen.MOD_Y - 18

    local chars = {}
    local showcount = 0
    for character, _ in pairs(Bagzen.data.global[Bagzen.realmname]) do
        if searchText == "" or string.find(string.lower(character), string.lower(searchText)) then
            table.insert(chars, character)
            showcount = showcount + 1
        end
    end

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
        local lefttext = getglobal(button:GetName() .. "LeftText")
        local color = RAID_CLASS_COLORS[data.class]
        lefttext:SetTextColor(color.r, color.g, color.b)
        local righttext = getglobal(button:GetName() .. "RightText")
        local dot = getglobal(button:GetName() .. "Dot")
        lefttext:SetText(character)
        righttext:SetText(Bagzen.realmname)
        button.value = count
        button.ParentFrame = frame:GetName()
        button:SetPoint("TOPLEFT", charactersframe:GetName(), "TOPLEFT", 2, MOD_Y - (count - 1) * (Bagzen.SIZE_Y / 2))

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
            local lefttext = getglobal(button:GetName() .. "LeftText")
            local righttext = getglobal(button:GetName() .. "RightText")
            local dot = getglobal(button:GetName() .. "Dot")
            lefttext:SetText("")
            righttext:SetText("")
            dot:Hide()
        end
    end
end

function Bagzen:CharactersFrameResize(parent)
    local MIN_HEIGHT = 152 -- 2 lines of bagslots
    -- todo: calculate this if needed
    local width = 200
    local parentHeight = parent:GetHeight()
    local frame = getglobal(parent:GetName() .. "CharactersFrame")

    if parentHeight <= MIN_HEIGHT then
        frame:SetHeight(MIN_HEIGHT)
    else
        frame:SetHeight(parentHeight)
    end

    frame:SetWidth(width)

    local searchFrame = getglobal(parent:GetName() .. "CharactersFrameSearchBox")
    searchFrame:SetWidth(width - 4 * Bagzen.PADDING)
end

function Bagzen:CharacterButtonOnClick(frame)
    local framename = frame:GetName()
    local realmname = getglobal(framename .. "RightText"):GetText()
    local unitname = getglobal(framename .. "LeftText"):GetText()

    Bagzen:ContainerUpdate(getglobal(frame.ParentFrame), realmname, unitname)
    Bagzen:CharactersFrameUpdate(getglobal(frame.ParentFrame))
    Bagzen:ContainerReposition(getglobal(frame.ParentFrame))
    local money = Bagzen.data.global[realmname][unitname].money or 0
    local moneyframe = getglobal(frame.ParentFrame .. "MoneyFrame")
    Bagzen:MoneyFrameUpdate(moneyframe, money)
end