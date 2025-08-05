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
    local dummyframe = _G[parent:GetName() .. "DummyBagSlotFrame" .. KEYRING_CONTAINER]
    if frame:GetParent().KeyChain then
        frame:SetNormalTexture("Interface\\AddOns\\Bagzen\\icons\\keyh.tga")
        frame:SetHighlightTexture("Interface\\AddOns\\Bagzen\\icons\\keyh.tga")
        frame:SetPushedTexture("Interface\\AddOns\\Bagzen\\icons\\keyh.tga")
        dummyframe:Show()
        Bagzen.settings.global[parent.SettingSection].keychain = true
    else
        frame:SetNormalTexture("Interface\\AddOns\\Bagzen\\icons\\key.tga")
        frame:SetHighlightTexture("Interface\\AddOns\\Bagzen\\icons\\key.tga")
        frame:SetPushedTexture("Interface\\AddOns\\Bagzen\\icons\\key.tga")
        Bagzen:UnHighlightSlots(parent)
        dummyframe:Hide()
        Bagzen.settings.global[parent.SettingSection].keychain = false
    end
    Bagzen:ContainerResize(frame:GetParent())
end
