function Bagzen:TooltipOnShow(frame)
    if not frame.itemID then return end

    GameTooltip:AddLine("\n")
    local count = 0
    for character, data in pairs(Bagzen.data.global[Bagzen.realmname]) do
        local class = data["class"]
        local bagcount = 0
        for bag, data in pairs(data) do
            if type(bag) == "number" and bag >= 0 then
                if data["slots"] then
                    for _, item in pairs(data["slots"]) do
                        if Bagzen:LinkToItemID(item["link"]) == frame.itemID then
                            if bag < 5 then
                                -- bag
                                bagcount = bagcount + item["count"]
                            else
                                -- bank
                            end
                        end
                    end
                end
            end
        end
        local countstr = ""
        local classcolor = RAID_CLASS_COLORS[class]
        if bagcount > 0 then
            count = count + bagcount
            countstr = "|cff4378ccBag:|r " .. bagcount
            ---countstr = "Bags: " .. bagcount
        end
        if countstr ~= "" then
            GameTooltip:AddDoubleLine(character, countstr, classcolor.r, classcolor.g, classcolor.b, 1, 1, 1)
        end
    end
    if count > 0 then
        GameTooltip:AddDoubleLine("Total", count, 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine("\n")
end

function Bagzen:TooltipOnHide(frame)
    frame.itemID = nil
    frame.itemLink = nil
end
