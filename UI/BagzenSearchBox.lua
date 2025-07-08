function Bagzen:SearchBoxOnTextChanged(frame)
    local text = frame:GetText()
    for t, data in pairs(Bagzen.ContainerFrames) do
        if data.count > 0 then
            local containerframe = nil
            if t == "bagframe" then
                containerframe = BagzenBagFrame
            elseif t == "bankframe" then
                -- containerframe = BagzenBankFrame
            end
            if containerframe then
                for _, bag in pairs(containerframe.Bags) do
                    if bag >= 0 then
                        local slots = getglobal(containerframe:GetName() .. "BagSlotsFrame" .. bag).Slots
                        for i, slotframe in pairs(Bagzen.ContainerFrames[t][bag]) do
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
            end
        end
    end
end
