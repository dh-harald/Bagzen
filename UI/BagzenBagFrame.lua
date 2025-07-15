function Bagzen:ToggleBags()
    local stack = debugstack()
    if stack:match("OpenAllBags") or stack:match("CloseAllBags") then
        return
    end
    if BagzenBagFrame:IsShown() then
            BagzenBagFrame:Hide()
    else
        BagzenBagFrame:Show()
    end
end
