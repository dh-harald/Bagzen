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
