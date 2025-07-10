function Bagzen:ButtonTooltip(text)
    GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:SetText(text)
    GameTooltip:Show()
end

function Bagzen:SortButtonOnClick(frame)
    local parent = frame:GetParent()
    if parent.Virtual == false
    then
        SetSortBagsRightToLeft(true)
        if parent:GetName() == "BagzenBagFrame"
        then
            SortBags()
        else
            SortBankBags()
        end
    end
end
