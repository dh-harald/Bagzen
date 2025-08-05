function Bagzen:SearchBoxOnTextChanged(frame)
    local _G = _G or getfenv()
    local text = frame:GetText()
    local parent = frame:GetParent()
    local live = "Live"
    if parent.Virtual == true then
        live = "Virtual"
    end
    local parentName = parent:GetName()
    if parentName == "BagzenBagFrame" or parentName == "BagzenBankFrame" then
        for _, bag in pairs(parent.Bags) do
            local slots = _G[parentName .. "BagSlotsFrame" .. bag].Slots
            for i, slotframe in pairs(Bagzen.ContainerFrames[live][parent.SettingSection][bag]) do
                if i <= slots then
                    local itemName = slotframe.ItemName
                    if text == "" or itemName == nil or string.find(string.lower(itemName), string.lower(text)) then
                        slotframe:SetAlpha(1)
                    else
                        slotframe:SetAlpha(0.2)
                    end
                end
            end
        end
    else
        Bagzen:CharactersFrameUpdate(parent:GetParent())
    end
end

function Bagzen:SearchBoxClearText(frame)
    local _G = _G or getfenv()
    local searchbox = _G[frame:GetName().. "SearchBox"]
    searchbox:SetText("")
end
