function Bagzen:ScanMails()
    local numItems = GetInboxNumItems()
    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].mails = {}
    if numItems > 0 then
        for i = 1, numItems do
            local _, _, _, _, _, _, _, hasItem = GetInboxHeaderInfo(i)
            if hasItem ~= nil and hasItem > 0 then
                for j = 1, hasItem do
                    local itemName, texture, count = GetInboxItem(i, j)
                    local itemID = Bagzen:GetItemIDByName(itemName)
                    if itemID then
                        local data = {
                            itemid = itemID,
                            name = itemName,
                            texture = texture,
                            count = count
                        }
                        table.insert(Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].mails, data)
                    end
                end
            end
        end
    end
end

local BagzenSendMail = SendMail
function SendMail(recipient, subject, body)
    local recipient_found = false
    for character, _ in pairs(Bagzen.data.global[Bagzen.realmname]) do
        if character == recipient then
            recipient_found = true
            break
        end
    end
    if recipient_found == true then
        if Bagzen.data.global[Bagzen.realmname][recipient].mails == nil then
            Bagzen.data.global[Bagzen.realmname][recipient].mails = {}
        end

        local name, texture, count = GetSendMailItem(1) -- only 1 item
        local data = {
            itemid = Bagzen:GetItemIDByName(name),
            name = name,
            texture = texture,
            count = count
        }
        table.insert(Bagzen.data.global[Bagzen.realmname][recipient].mails, data)
    end
    return BagzenSendMail(recipient, subject, body)
end

local BagzenReturnInboxItem = ReturnInboxItem
function ReturnInboxItem(index)
    Bagzen:Print("ReturnInboxItem")
    local _, _, recipient = GetInboxHeaderInfo(index)

    local recipient_found = false
    for character, _ in pairs(Bagzen.data.global[Bagzen.realmname]) do
        if character == recipient then
            recipient_found = true
            break
        end
    end
    if recipient_found == true then
        if Bagzen.data.global[Bagzen.realmname][recipient].mails == nil then
            Bagzen.data.global[Bagzen.realmname][recipient].mails = {}
        end

        local name, texture, count = GetInboxItem(index, 1) -- only 1 item
        Bagzen:Print(name, texture, count)
        local data = {
            itemid = Bagzen:GetItemIDByName(name),
            name = name,
            texture = texture,
            count = count
        }
        table.insert(Bagzen.data.global[Bagzen.realmname][recipient].mails, data)
    end
    return BagzenReturnInboxItem(index)
end
