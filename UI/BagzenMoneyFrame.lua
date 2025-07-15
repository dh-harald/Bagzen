function Bagzen:MoneyFrameUpdate(frame, money)
    local _G = _G or getfenv()
    -- Breakdown the money into denominations
    local frameName = frame:GetName()

    local gold = floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD))
    local silver = floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
    local copper = mod(money, COPPER_PER_SILVER)

    local goldButton = _G[frameName.."GoldButton"]
    local silverButton = _G[frameName.."SilverButton"]
    local copperButton = _G[frameName.."CopperButton"]

    local iconWidth = MONEY_ICON_WIDTH_SMALL
    local spacing = MONEY_BUTTON_SPACING_SMALL

    goldButton:SetText(gold)
    goldButton:SetWidth(goldButton:GetTextWidth() + iconWidth)
    goldButton:Show()
    silverButton:SetText(silver)
    silverButton:SetWidth(silverButton:GetTextWidth() + iconWidth)
    silverButton:Show()
    copperButton:SetText(copper)
    copperButton:SetWidth(copperButton:GetTextWidth() + iconWidth)
    copperButton:Show()

    frame.staticMoney = money

    local width = copperButton:GetWidth()

    if gold > 0 then
        width = width + goldButton:GetWidth()
    else
        goldButton:Hide()
    end

    if silver > 0 then
        width = width + silverButton:GetWidth()
    else
        silverButton:Hide()
    end
    frame:SetWidth(width)
end
