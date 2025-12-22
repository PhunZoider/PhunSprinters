PhunSprinters = {
    name = "PhunSprinters",
    consts = {},
    data = {},
    env = {},
    commands = {
        playerSetup = "playerSetup"
    },
    events = {
        onReady = "PhunSprintersOnReady",
        onSprinterAdded = "PhunSprintersOnSprinterAdded"
    },
    settings = {},
    ui = {},
    queueIds = {},
    queue = {},
    sprint = true,
    daytime = true,
    baseOutfits = {
        christmas = {
            male = {
                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.Hat_SantaHatBluePattern",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_SantaHat",
                        probability = 50

                    }, {
                        type = "Base.Hat_SantaHatGreen",
                        probability = 10
                    }}
                }
            },
            female = {
                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.Hat_SantaHatBluePattern",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_SantaHat",
                        probability = 50

                    }, {
                        type = "Base.Hat_SantaHatGreen",
                        probability = 10
                    }}
                }

            }
        },
        easter = {
            male = {
                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.BunnyEars",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_BunnyEarsBlack",
                        probability = 50

                    }, {
                        type = "Base.Hat_BunnyEarsWhite",
                        probability = 10
                    }}
                }
            },
            female = {
                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.BunnyEars",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_BunnyEarsBlack",
                        probability = 50

                    }, {
                        type = "Base.Hat_BunnyEarsWhite",
                        probability = 10
                    }}
                }

            }
        },
        halloween = {
            male = {
                FullHelmet = {
                    probability = 100,
                    items = {{
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Angry",
                        mod = "HallweensPumpkinHelmets",
                        probability = 10
                    }, {
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Pirate",
                        mod = "HallweensPumpkinHelmets",
                        probability = 1

                    }, {
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Surprised",
                        mod = "HallweensPumpkinHelmets",
                        probability = 5
                    }}
                }
            },
            female = {
                FullHelmet = {
                    probability = 100,
                    items = {{
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Angry",
                        mod = "HallweensPumpkinHelmets",
                        probability = 10
                    }, {
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Pirate",
                        mod = "HallweensPumpkinHelmets",
                        probability = 1

                    }, {
                        type = "HallweensPumpkinHelmets.Hat_Pumpkin_Helmet_Surprised",
                        mod = "HallweensPumpkinHelmets",
                        probability = 5
                    }}
                }

            }
        },
        party = {
            male = {

                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.Hat_ClownConeHead",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_PartyHat_TINT",
                        probability = 80

                    }}
                }
            },
            female = {
                Hat = {
                    probability = 100,
                    items = {{
                        type = "AuthenticZClothing.Hat_ClownConeHead",
                        mod = "Authentic Z - Current",
                        probability = 10
                    }, {
                        type = "Base.Hat_PartyHat_TINT",
                        probability = 80

                    }}
                }
            }

        }

    },
    outfit = nil
}

local Core = PhunSprinters
Core.isLocal = not isClient() and not isServer() and not isCoopHost()
Core.settings = SandboxVars[Core.name] or {}
for _, event in pairs(Core.events) do
    if not Events[event] then
        LuaEventManager.AddEvent(event)
    end
end

function Core:ini()
    self.inied = true
    if not isClient() then

    end
    triggerEvent(self.events.OnReady, self)
end

function Core:getId(zedObj)
    if zedObj then
        if instanceof(zedObj, "IsoZombie") then
            if zedObj:isZombie() then
                if isClient() or isServer() then
                    return zedObj:getOnlineID()
                else
                    return zedObj:getID()
                end
            end
        end
    end
end
