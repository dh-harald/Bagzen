function Bagzen:BankFrameOnShow(frame)
    if frame.Virtual == true then
        getglobal(frame:GetName() .. "OnlineButton"):Hide()
        getglobal(frame:GetName() .. "OfflineButton"):Show()
    else
        getglobal(frame:GetName() .. "OnlineButton"):Show()
        getglobal(frame:GetName() .. "OfflineButton"):Hide()
    end
end

function Bagzen:BankFrameToggle()
    if BagzenBankFrame:IsShown() then
        BagzenBankFrame:Hide()
    else
        BagzenBankFrame:Show()
    end
end