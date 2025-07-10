-- Bindings
BINDING_HEADER_SCRAP = "Bagzen"
BINDING_NAME_SCRAP_TOGGLE = "Toggle Item Under Mouse"

Bagzen = LibStub("AceAddon-3.0"):NewAddon("Bagzen", "AceEvent-3.0", "AceConsole-3.0")

Bagzen.realmname = GetRealmName()
Bagzen.unitname = GetUnitName("player")

Bagzen.SIZE_X = 40 -- slot size X
Bagzen.SIZE_Y = 40 -- slot size Y
Bagzen.PADDING = 2
Bagzen.MOD_Y = -48 -- where the containerslots starts in Y

Bagzen.icon = LibStub("LibDBIcon-1.0", true)
Bagzen.LDB = LibStub("LibDataBroker-1.1"):NewDataObject("Bagzen", {
    type = "launcher",
    icon = "Interface\\Buttons\\Button-Backpack-Up.PNG",
    tocname = "Bagzen",
    label = "Bagzen",
    OnClick = function(self, button)
        if button == "RightButton" then
            Bagzen:ChatCommand()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:SetText("Bagzen")
        tooltip:AddDoubleLine("Right-Click", "Open Settings", 1, 1, 1, 1, 1, 1)
    end,
})

function Bagzen:ChatCommand()
    InterfaceOptionsFrame_OpenToCategory("Bagzen")
end

local default_settings = {
    global = {
        general = {
            auto_repair = true,
            auto_sell = true,
        },
        bagframe = {
            width = 8,
            open_vendor = true,
            open_mail = true,
            close_vendor = true,
            close_mail = true,
            bagsframe = false,
        },
        bankframe = {
            width = 18,
            scale = 1,
            bagsframe = false
        },
    },
    profile = {
        minimap = {
            hide = false
        }
    },
    char = {
        bagframe = {
            scale = 1
        },
        bankframe = {
            scale = 1
        }
    }
}

local default_data = {
    global = {}
}

local ConfigTable = {
    type = "group",
    args = {
        general = {
            type = "group",
            inline = true,
            name = "General",
            order = 10,
            args = {
                auto_repair = {
                    order = 10,
                    name = "Auto Repair",
                    type = "toggle",
                    set = function(info, val)
                        Bagzen.settings.global.general.auto_repair = val
                    end,
                    get = function(info)
                        return Bagzen.settings.global.general.auto_repair
                    end,
                },
                auto_sell = {
                    order = 20,
                    name = "Auto Sell Scraps",
                    type = "toggle",
                    set = function(info, val)
                        Bagzen.settings.global.general.auto_sell = val
                    end,
                    get = function(info)
                        return Bagzen.settings.global.general.auto_sell
                    end,
                },
                minimap_hide = {
                    order = 30,
                    name = "Hide Minimap Icon",
                    type = "toggle",
                    set = function(info, val)
                        Bagzen.settings.profile.minimap.hide = val
                    end,
                    get = function(info)
                        return Bagzen.settings.profile.minimap.hide
                    end,
                }
            }
        },
        bagframe = {
            type = "group",
            inline = true,
            name = "Bag Frame",
            order = 20,
            args = {
                bag_width = {
                    order = 100,
                    name = "Backpack width",
                    type = "range",
                    min = 4,
                    max = 16,
                    step = 1,
                    set = function(info, val)
                        Bagzen.settings.global.bagframe.width = val
                        Bagzen:ContainerUpdate(BagzenBagFrame, BagzenBagFrame.OwnerRealm, BagzenBagFrame.OwnerName)
                    end,
                    get = function(info)
                        return Bagzen.settings.global.bagframe.width
                    end,
                },
                scale = {
                    order = 110,
                    name = "Backpack scale",
                    type = "range",
                    min = 0.5,
                    max = 2,
                    step = 0.1,
                    set = function(info, val)
                        local scale = Bagzen.settings.char.bagframe.scale
                        local _, _, _, xOfs, yOfs = BagzenBagFrame:GetPoint()
                        xOfs = xOfs * scale / val
                        yOfs = yOfs * scale / val

                        Bagzen.settings.char.bagframe.xOfs = xOfs
                        Bagzen.settings.char.bagframe.yOfs = yOfs

                        Bagzen.settings.char.bagframe.scale = val

                        Bagzen:ContainerReposition(BagzenBagFrame)
                     end,
                    get = function(info)
                        return Bagzen.settings.char.bagframe.scale
                    end,
                },
                auto_open = {
                    type = "group",
                    order = 200,
                    name = "Auto open",
                    args = {
                        auto_open_vendor = {
                                order = 200,
                                name = "on vendor",
                                type = "toggle",
                                set = function(info, val)
                                    Bagzen.settings.global.bagframe.open_vendor = val
                                end,
                                get = function(info)
                                    return Bagzen.settings.global.bagframe.open_vendor
                                end,
                        },
                        auto_open_mail = {
                                order = 210,
                                name = "on mail",
                                type = "toggle",
                                set = function(info, val)
                                    Bagzen.settings.global.bagframe.open_mail = val
                                end,
                                get = function(info)
                                    return Bagzen.settings.global.bagframe.open_mail
                                end,
                        },
                    },
                },
                auto_close = {
                    type = "group",
                    order = 210,
                    name = "Auto open",
                    args = {
                        auto_close_vendor = {
                            order = 220,
                            name = "on vendor",
                            type = "toggle",
                            set = function(info, val)
                                Bagzen.settings.global.bagframe.close_vendor = val
                            end,
                            get = function(info)
                                return Bagzen.settings.global.bagframe.close_vendor
                            end,
                        },
                        auto_close_mail = {
                            order = 230,
                            name = "on mailbox",
                            type = "toggle",
                            set = function(info, val)
                                Bagzen.settings.global.bagframe.close_mail = val
                            end,
                            get = function(info)
                                return Bagzen.settings.global.bagframe.close_mail
                            end,
                        },
                    },
                },
            },
        },
        bankframe = {
            type = "group",
            inline = true,
            name = "Bank Frame",
            order = 30,
            args = {
                bank_width = {
                    order = 100,
                    name = "Bank view width",
                    type = "range",
                    min = 8,
                    max = 36,
                    step = 1,
                    set = function(info, val)
                        Bagzen.settings.global.bankframe.width = val
                        Bagzen:ContainerUpdate(BagzenBankFrame, BagzenBankFrame.OwnerRealm, BagzenBankFrame.OwnerName)
                    end,
                    get = function(info)
                        return Bagzen.settings.global.bankframe.width
                    end,
                },
                scale = {
                    order = 110,
                    name = "Bank view scale",
                    type = "range",
                    min = 0.5,
                    max = 2,
                    step = 0.1,
                    set = function(info, val)
                        local scale = Bagzen.settings.char.bankframe.scale
                        local _, _, _, xOfs, yOfs = BagzenBankFrame:GetPoint()
                        xOfs = xOfs * scale / val
                        yOfs = yOfs * scale / val

                        Bagzen.settings.char.bankframe.xOfs = xOfs
                        Bagzen.settings.char.bankframe.yOfs = yOfs

                        Bagzen.settings.char.bankframe.scale = val

                        Bagzen:ContainerReposition(BagzenBankFrame)
                    end,
                    get = function(info)
                        return Bagzen.settings.char.bankframe.scale
                    end,
                },
            }
        },
    }
}

function Bagzen:OnInitialize()
    Bagzen:Print("Initialized")

    -- settings / data
    Bagzen.settings = LibStub("AceDB-3.0"):New("BagzenSettings", default_settings)
    Bagzen.data = LibStub("AceDB-3.0"):New("BagzenData", default_data)

    -- config dialog
    local ACD = LibStub("AceConfigDialog-3.0")
    LibStub('AceConfig-3.0').RegisterOptionsTable(Bagzen, "Bagzen", ConfigTable)
    Bagzen.OptionsFrame = ACD:AddToBlizOptions("Bagzen", "Bagzen")

    -- minimap icon
    Bagzen.icon:Register("Bagzen", Bagzen.LDB, Bagzen.settings.profile.minimap)

    Bagzen:RegisterChatCommand("bagzen", "ChatCommand")

    -- database init
    if Bagzen.data.global[Bagzen.realmname] == nil then
        Bagzen.data.global[Bagzen.realmname] = {}
    end
    if Bagzen.data.global[Bagzen.realmname][Bagzen.unitname] == nil then
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname] = {}
    end

    if Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags == nil then
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].bags = {}
    end

    if Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].scrap == nil then
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].scrap = {}
    end

    if Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].useful == nil then
        Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].useful = {}
    end

    local _, race = UnitRace("player")
    local _, class = UnitClass("player")
    local sexname = {
        [1] = "NA",
        [2] = "MALE",
        [3] = "FEMALE"
    }
    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].race = string.upper(race)
    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].class = string.upper(class)
    Bagzen.data.global[Bagzen.realmname][Bagzen.unitname].sex = sexname[UnitSex("player")]

    -- override default backpack functions
    ToggleBackpack = function()
        if BagzenBagFrame:IsShown() then
            BagzenBagFrame:Hide()
        else
            BagzenBagFrame:Show()
        end
    end

    ToggleBag = function(id)
        ToggleBackpack()
    end

    OpenAllBags = function()
        BagzenBagFrame:Show()
    end

    CloseAllBags = function()
        BagzenBagFrame:Hide()
    end

    -- remove hooks from original BankFrame
    local bankframe = getglobal("BankFrame")
    if bankframe then
        bankframe:UnregisterEvent("BANKFRAME_OPENED")
        bankframe:UnregisterEvent("PLAYERBANKSLOTS_CHANGED")
        bankframe:UnregisterEvent("ITEM_LOCK_CHANGED")
        bankframe:UnregisterEvent("CURSOR_UPDATE")
    end
end
