function Bagzen:ButtonTooltip(text)
    GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:SetText(text)
    GameTooltip:Show()
end

function Bagzen:SortButtonOnClick(frame)
    Bagzen:SortBags(frame:GetParent())
end

function Bagzen:CloseButtonOnClick(frame)
    frame:GetParent():Hide()
end

function Bagzen:KeyChainButtonOnClick(frame)
    local _G = _G or getfenv()
    local parent = frame:GetParent()
    parent.KeyChain = not parent.KeyChain
    local dummyframe = _G[parent:GetName() .. "DummyBagSlotFrame" .. Bagzen:FixBagNumber(KEYRING_CONTAINER)]
    if frame:GetParent().KeyChain then
        frame:SetNormalTexture("Interface\\AddOns\\Bagzen\\icons\\keyh")
        frame:SetHighlightTexture("Interface\\AddOns\\Bagzen\\icons\\keyh")
        frame:SetPushedTexture("Interface\\AddOns\\Bagzen\\icons\\keyh")
        dummyframe:Show()
        Bagzen.settings.global[parent.SettingSection].keychain = true
    else
        frame:SetNormalTexture("Interface\\AddOns\\Bagzen\\icons\\key")
        frame:SetHighlightTexture("Interface\\AddOns\\Bagzen\\icons\\key")
        frame:SetPushedTexture("Interface\\AddOns\\Bagzen\\icons\\key")
        Bagzen:UnHighlightSlots(parent)
        dummyframe:Hide()
        Bagzen.settings.global[parent.SettingSection].keychain = false
    end
    Bagzen:ContainerResize(parent)
end

function Bagzen:OpenOptions()
    if Bagzen.IsWOTLK then
        InterfaceOptionsFrame_OpenToCategory("Bagzen")
    elseif Bagzen.IsVanilla then
        LibStub("LibConfig-1.0"):OpenToCategory("Bagzen")
    end
end
