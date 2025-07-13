function Bagzen:SearchBoxOnTextChanged(frame)
    local text = frame:GetText()
    local parent = frame:GetParent()
    local parentName = parent:GetName()
    if parentName == "BagzenBagFrame" or parentName == "BagzenBankFrame" then
        for _, bag in pairs(parent.Bags) do
            if bag ~= KEYRING_CONTAINER then
                local slots = getglobal(parentName .. "BagSlotsFrame" .. bag).Slots
                for i, slotframe in pairs(Bagzen.ContainerFrames[parent.SettingSection][bag]) do
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
        end
    else
        Bagzen:CharactersFrameUpdate(parent:GetParent())
    end
end

function Bagzen:SearchBoxClearText(frame)
    local searchbox = getglobal(frame:GetName().. "SearchBox")
    searchbox:SetText("")
end
