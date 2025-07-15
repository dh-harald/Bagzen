
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

local BagzenSendMail = function(recipient, subject, body)
    local ATTACHMENTS_MAX_SEND = ATTACHMENTS_MAX_SEND or 1
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

        for i = 1, ATTACHMENTS_MAX_SEND do
            local name, texture, count = GetSendMailItem(i)
            local data = {
                itemid = Bagzen:GetItemIDByName(name),
                name = name,
                texture = texture,
                count = count
            }
            table.insert(Bagzen.data.global[Bagzen.realmname][recipient].mails, data)
        end
    end
end

local BagzenReturnInboxItem = function(index)
    local ATTACHMENTS_MAX = ATTACHMENTS_MAX or 1
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

        for i = 1, ATTACHMENTS_MAX do
            local name, texture, count = GetInboxItem(index, i)
            if name ~= nil and texture ~= nil and count ~= nil then
                local data = {
                    itemid = Bagzen:GetItemIDByName(name),
                    name = name,
                    texture = texture,
                    count = count
                }
                table.insert(Bagzen.data.global[Bagzen.realmname][recipient].mails, data)
            end
        end
    end
end

Bagzen:SecureHook("SendMail", BagzenSendMail)
Bagzen:SecureHook("ReturnInboxItem", BagzenReturnInboxItem)
