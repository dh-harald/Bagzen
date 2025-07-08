function Bagzen:ButtonTooltip(text)
    GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:SetText(text)
    GameTooltip:Show()
end

function Bagzen:SortButtonOnClick(frame)
    -- TODO:
    -- Bags/Bank -- SortBags
    -- Own sort
    SetSortBagsRightToLeft(true)
    SortBags()
end
