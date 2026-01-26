if isServer() then
    return
end
local tools = require "PhunSprintersUI/ui/tools"
local Core = PhunSprintersUI
local PS = PhunSprinters
local PL = PhunLib
local profileName = "PhunSprintersUIContainer"
PhunSprintersUIContainer = ISPanelJoypad:derive(profileName);
local UI = PhunSprintersUIContainer
Core.ui = Core.ui or {}
Core.ui.container = UI

local function getMoonDescription(player)
    local md = player:getModData()
    local pd = md.PhunSprinters or {}
    local texts = {}

    local c = PS
    local moon = c.moon
    if moon == 1 then
        table.insert(texts, getText("IGUI_PhunSprinters_Moon_Normal_Desc",
            getText("IGUI_PhunSprinters_MoonPhase" .. PS.moonPhase)))
    elseif moon < 1 then
        table.insert(texts,
            getText("IGUI_PhunSprinters_Moon_Reducing_Desc", getText("IGUI_PhunSprinters_MoonPhase" .. PS.moonPhase),
                100 - PL.string.formatNumber(moon * 100)))
    else
        table.insert(texts,
            getText("IGUI_PhunSprinters_Moon_Increasing_Desc", getText("IGUI_PhunSprinters_MoonPhase" .. PS.moonPhase),
                PL.string.formatNumber(moon * 100)))
    end

    if PS.env.adjustedLightIntensity <= PS.settings.DarknessLevel then
        table.insert(texts, "Dark: " .. tostring(PL.string.formatNumber(100 - PS.env.adjustedLightIntensity)) .. "%")
        if PS.env.fogIntensity > 0 then
            table.insert(texts, " - Light level: " .. PL.string.formatNumber(PS.env.lightIntensity) .. "%")
            table.insert(texts, " - Fog density: " .. tostring(PS.env.fogIntensity) .. "%")
        end
    end

    if RNC and RNC.client then
        table.insert(texts, "")
        table.insert(texts, RNC.client.fetchTooltipText(RNC.sandboxSettings))
    end

    return #texts > 0 and table.concat(texts, "\n") or ""
end

local function getSprinterDescription(player)
    local md = player:getModData()
    local pd = md.PhunSprinters or {}
    local texts = {}

    local zoneName = md.PhunZones and md.PhunZones.title or "Unknown"
    if md.PhunZones and md.PhunZones.subtitle and md.PhunZones.subtitle ~= "" then
        zoneName = zoneName .. " (" .. md.PhunZones.subtitle .. ")"
    end

    local c = PS
    local p = PL
    local prefix = ""
    if c.sprint then
        prefix = "IGUI_PhunSprinters_ActiveMode" .. tostring(c.settings.Mode)
    else
        prefix = "IGUI_PhunSprinters_InactiveMode" .. tostring(c.settings.Mode)
    end

    -- if c.sprint and not p.isNight and (PS.env.adjustedLightIntensity < PS.env.lightIntensity) then
    --     table.insert(texts, getText("IGUI_PhunSprinters_Bad_Weather_Desc"))
    -- elseif PS.sprint and PS.env.adjustedLightIntensity < PS.settings.DarknessLevel then
    --     table.insert(texts, getText("IGUI_PhunSprinters_Too_Dark_Desc"))
    -- elseif not PS.sprint then
    --     table.insert(texts, getText("IGUI_PhunSprinters_Too_Light_Desc"))
    -- end
    table.insert(texts, getText(prefix))
    table.insert(texts, "")

    table.insert(texts,
        getText("IGUI_PhunSprinters_X_Risk", zoneName, getText("IGUI_PhunSprinters_Risk" .. pd.riskLevel),
            PL.string.formatNumber(pd.risk, true)))
    table.insert(texts, "")
    if pd.hoursAdj and pd.hoursAdj ~= 1 then
        local hours = (pd.totalHours or 0) + player:getHoursSurvived()
        table.insert(texts, getText("IGUI_PhunSprinters_Risk_Hours_Discounted", PL.string.formatNumber(hours),
            PL.string.formatNumber((1 - pd.hoursAdj) * 100)))
    end

    if PS.env.adjustedLightIntensity <= PS.settings.DarknessLevel then
        table.insert(texts, "Dark: " .. tostring(PL.string.formatNumber(100 - PS.env.adjustedLightIntensity)) .. "%")
        if PS.env.fogIntensity > 0 then
            table.insert(texts, " - Light level: " .. PL.string.formatNumber(PS.env.lightIntensity) .. "%")
            table.insert(texts, " - Fog density: " .. tostring(PS.env.fogIntensity) .. "%")
        end
    end

    if isAdmin() or isDebugEnabled() then
        local defaultRisk = getSandboxOptions():getOptionByName("PhunSprinters.DefaultRisk"):getValue() or 0
        local maxRisk = md.PhunZones.maxSprinterRisk or 100
        if maxRisk == 0 then
            maxRisk = 100
        end
        table.insert(texts, "Env")
        table.insert(texts, " - Base risk: " .. tostring(md.PhunZones.minSprinterRisk or defaultRisk) .. "%")
        table.insert(texts, " - Max Risk: " .. PL.string.formatNumber(maxRisk) .. "%")
        table.insert(texts, " - Moon Phase: " .. tostring(md.PhunSprinters.moonPhase))
        table.insert(texts, " - Moon Multiplier: " .. tostring(md.PhunSprinters.moon * 100) .. "%")
        table.insert(texts, " - Light: " .. tostring(PS.env.lightIntensity) .. "%")
        table.insert(texts, " - Fog: " .. tostring(PS.env.fogIntensity) .. "%")
        table.insert(texts, " - Adjusted: " .. PL.string.formatNumber(PS.env.adjustedLightIntensity) .. "%")
        table.insert(texts, "-----")
        table.insert(texts, "Spawning mode")
        table.insert(texts, " - sprinting: " .. tostring(PS.sprint))
        table.insert(texts, "Settings")
        table.insert(texts, " - Darkness Level: " .. tostring(PS.settings.DarknessLevel))
        table.insert(texts, " - Mode: " .. tostring(PS.settings.Mode))
        table.insert(texts, " - Dawn:" .. PL.string.formatGameTime(PL.dawnTime))
        table.insert(texts, " - Dusk:" .. PL.string.formatGameTime(PL.duskTime))

    end

    return #texts > 0 and table.concat(texts, "\n") or ""
end

function UI.open(player)

    local playerIndex = player:getPlayerNum()
    local core = getCore()
    local width = 35 * tools.FONT_SCALE
    local height = 65 * tools.FONT_SCALE

    local x = core:getScreenWidth() - width - 5 * tools.FONT_SCALE
    local y = 10 * tools.FONT_SCALE

    local instance = UI:new(x, y, width, height, player, playerIndex);

    instance:initialise();

    ISLayoutManager.RegisterWindow(profileName, UI, instance)

    instance:addToUIManager();
    instance:setVisible(false);
    instance:ensureVisible()
    Core.ui.instances[player:getPlayerNum()] = instance
    return instance;

end

function UI:new(x, y, width, height, player, playerIndex)
    local opts = options or {}
    local o = ISPanelJoypad:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;

    o.variableColor = {
        r = 0.9,
        g = 0.55,
        b = 0.1,
        a = 1
    };
    o.backgroundColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 0.8
    };
    o.buttonBorderColor = {
        r = 0.2,
        g = 0.2,
        b = 0.2,
        a = 0
    };
    o.borderColor = {
        r = 0.4,
        g = 0.4,
        b = 0.4,
        a = 0.7
    }
    o.controls = {}
    o.moveWithMouse = false;
    o.anchorRight = true
    o.anchorBottom = true
    o.player = player
    o.playerIndex = playerIndex
    return o;
end

function UI:createChildren()
    ISPanelJoypad.createChildren(self)
    local padding = 5 * tools.FONT_SCALE
    local x = 0
    local y = 0
    local w = self.width - padding * 2
    local h = self.height - padding * 2

    self.controls = {}

    local sprinter = PhunSprintersUISprinter:new(x, y, w, h / 2 - padding / 2, self.player, self.playerIndex)
    sprinter:initialise()
    self.controls.sprinter = sprinter
    sprinter.desc = getSprinterDescription
    self:addChild(sprinter)

    local moon = PhunSprintersUIMoon:new(x, y + h / 2 + padding / 2, w, h / 2 - padding / 2, self.player,
        self.playerIndex)
    moon:initialise()
    self.controls.moon = moon
    moon.desc = getMoonDescription
    self:addChild(moon)

    local pips = PhunSprintersUIPips:new(x, y + h / 2 + padding / 2, w, h / 2 - padding / 2, self.player,
        self.playerIndex)
    pips:initialise()
    self.controls.pips = pips
    pips.desc = getSprinterDescription
    self:addChild(pips)

end

function UI:prerender()
    ISPanelJoypad.prerender(self)
    self:updateLayout()
end

function UI:updateLayout()

    local modData = self.player:getModData() or {};

    local clock = UIManager.getClock()
    local speed = UIManager.getSpeedControls()
    local c = Core
    if Core.settings.layout == 9999 then
        -- doesnt exist!
    elseif Core.settings.layout == 2 then
        -- horizontal
        local height = 16 * tools.FONT_SCALE
        local h = height - 4 * tools.FONT_SCALE

        self:setWidth(clock and clock:getWidth() or speed and speed:getWidth() or 150 * tools.FONT_SCALE)
        self:setHeight(height)

        self.controls.moon:setHeight(h)
        self.controls.moon:setWidth(h)
        self.controls.moon:setY(tools.FONT_SCALE)
        self.controls.moon:setX(tools.FONT_SCALE)

        self.controls.sprinter:setHeight(self.controls.moon.height)
        self.controls.sprinter:setWidth(self.controls.moon.width)
        self.controls.sprinter:setY(self.controls.moon.y)
        self.controls.sprinter:setX(self.controls.moon.x + self.controls.moon.width + 2 * tools.FONT_SCALE)

        self.controls.pips:setHeight(self.controls.moon.height)
        self.controls.pips:setWidth(self.width - self.controls.moon.width - self.controls.sprinter.width - 6 *
                                        tools.FONT_SCALE)
        self.controls.pips:setY(self.controls.moon.y)
        self.controls.pips:setX(self.width - self.controls.pips.width - tools.FONT_SCALE)
        if clock and clock:isVisible() then
            self:setX(clock:getX())
            self:setY(clock:getY() + clock:getHeight() - tools.FONT_SCALE)
        elseif Core.isLocal and speed and speed:isVisible() then
            self:setX(speed:getX() + speed:getWidth() - self.width)
            self:setY(speed:getY() + speed:getHeight() + 2 * tools.FONT_SCALE)
        else
            self:setX(getCore():getScreenWidth() - self.width - 5)
            self:setY(5)
        end
    else
        -- default to stacked (default)
        local height = clock and clock:getHeight() or 65 * tools.FONT_SCALE
        local h = (height - 5 * tools.FONT_SCALE) / 2

        self:setWidth(h + 2 * tools.FONT_SCALE)
        self:setHeight(height)

        self.controls.moon:setHeight(h - 6 * tools.FONT_SCALE)
        self.controls.moon:setWidth(h - 6 * tools.FONT_SCALE)
        self.controls.moon:setY(1)
        self.controls.moon:setX(3)

        self.controls.sprinter:setHeight(self.controls.moon.height)
        self.controls.sprinter:setWidth(self.controls.moon.width)
        self.controls.sprinter:setY(self.controls.moon.y + self.controls.moon.height + 3 * tools.FONT_SCALE)
        self.controls.sprinter:setX(self.controls.moon.x)

        self.controls.pips:setHeight(3 * tools.FONT_SCALE)
        self.controls.pips:setWidth(self.width - 2 * tools.FONT_SCALE)
        self.controls.pips:setY((self.height - self.controls.pips.height) / 2)
        self.controls.pips:setX(tools.FONT_SCALE)

        if clock and clock:isVisible() then
            self:setX(clock:getX() - self.width)
            self:setY(clock:getY())
        elseif Core.isLocal and speed and speed:isVisible() then

            self:setX(getCore():getScreenWidth() - self.width - 5 * tools.FONT_SCALE)
            self:setY(speed:getY() + speed:getHeight() + 5 * tools.FONT_SCALE)

        else
            self:setX(getCore():getScreenWidth() - self.width - 5 * tools.FONT_SCALE)
            self:setY(2 * tools.FONT_SCALE)
        end
    end
    self:setVisible(true);
end
