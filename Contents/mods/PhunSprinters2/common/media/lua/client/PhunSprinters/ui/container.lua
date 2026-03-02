if isServer() then
    return
end
local tools = require "PhunSprinters/ui/tools"

local Core = PhunSprinters

local profileName = "PhunSprintersContainer"
PhunSprintersContainer = ISPanelJoypad:derive(profileName);
local UI = PhunSprintersContainer
Core.ui = Core.ui or {}
Core.ui.container = UI

local function getMoonDescription(player)
    local md = player:getModData()
    local pd = md.PhunSprinters or {}
    local texts = {}

    local c = Core
    if Core.moonPhase == nil or Core.moon == nil then
        Core.CalcMoon()
    end
    local moon = c.moon or 0
    if moon == 1 then
        table.insert(texts, getText("IGUI_PhunSprinters_Moon_Normal_Desc",
            getText("IGUI_PhunSprinters_MoonPhase" .. (Core.moonPhase or 0))))
    elseif moon < 1 then
        table.insert(texts,
            getText("IGUI_PhunSprinters_Moon_Reducing_Desc",
                getText("IGUI_PhunSprinters_MoonPhase" .. (Core.moonPhase or 0)),
                100 - Core.tools.formatNumber(moon * 100)))
    else
        table.insert(texts,
            getText("IGUI_PhunSprinters_Moon_Increasing_Desc",
                getText("IGUI_PhunSprinters_MoonPhase" .. (Core.moonPhase or 0)), Core.tools.formatNumber(moon * 100)))
    end

    if Core.env.adjustedLightIntensity <= Core.settings.DarknessLevel then
        table.insert(texts, "Dark: " .. tostring(Core.tools.formatNumber(100 - Core.env.adjustedLightIntensity)) .. "%")
        if Core.env.fogIntensity > 0 then
            table.insert(texts, " - Light level: " .. Core.tools.formatNumber(Core.env.lightIntensity) .. "%")
            table.insert(texts, " - Fog density: " .. Core.tools.formatNumber(Core.env.fogIntensity) .. "%")
        end
    end

    return #texts > 0 and table.concat(texts, "\n") or ""
end

local function getSprinterDescription(player)
    local md = player:getModData()
    local pd = md.PhunSprinters or {}
    local texts = {}

    local pzdata = Core.getPlayerZoneData(player)

    local zoneName = pzdata.title or "Unknown"
    if pzdata.subtitle and pzdata.subtitle ~= "" then
        zoneName = zoneName .. " (" .. pzdata.subtitle .. ")"
    end

    local prefix = ""
    if Core.sprint then
        prefix = "IGUI_PhunSprinters_ActiveMode" .. tostring(Core.settings.Mode)
    else
        prefix = "IGUI_PhunSprinters_InactiveMode" .. tostring(Core.settings.Mode)
    end

    table.insert(texts, getText(prefix))
    table.insert(texts, "")

    table.insert(texts,
        getText("IGUI_PhunSprinters_X_Risk", zoneName or "???",
            getText("IGUI_PhunSprinters_Risk" .. (pd.riskLevel or "Low")), Core.tools.formatNumber(pd.risk or 0, true)))
    table.insert(texts, "")
    if pd.hoursAdj and pd.hoursAdj ~= 1 then
        local hours = (pd.totalHours or 0) + player:getHoursSurvived()
        table.insert(texts, getText("IGUI_PhunSprinters_Risk_Hours_Discounted", Core.tools.formatNumber(hours),
            Core.tools.formatNumber((1 - pd.hoursAdj) * 100)))
    end

    if Core.env.adjustedLightIntensity <= Core.settings.DarknessLevel then
        table.insert(texts, "Dark: " .. tostring(Core.tools.formatNumber(100 - Core.env.adjustedLightIntensity)) .. "%")
        if Core.env.fogIntensity > 0 then
            table.insert(texts, " - Light level: " .. Core.tools.formatNumber(Core.env.lightIntensity) .. "%")
            table.insert(texts, " - Fog density: " .. Core.tools.formatNumber(Core.env.fogIntensity) .. "%")
        end
    end

    if isAdmin() or isDebugEnabled() then
        local defaultRisk = getSandboxOptions():getOptionByName("PhunSprinters.DefaultRisk"):getValue() or 0
        local maxRisk = tonumber(pzdata.maxSprinterRisk) or 100
        if maxRisk == 0 then
            maxRisk = 100
        end
        table.insert(texts, "Env")
        table.insert(texts,
            " - Base risk: " .. tostring(tonumber(pzdata.minSprinterRisk) or tonumber(defaultRisk)) .. "%")
        table.insert(texts, " - Max Risk: " .. Core.tools.formatNumber(maxRisk) .. "%")
        table.insert(texts, " - Moon Phase: " .. tostring(md.PhunSprinters.moonPhase))
        table.insert(texts, " - Moon Multiplier: " .. tostring(md.PhunSprinters.moon * 100) .. "%")
        table.insert(texts, " - Light: " .. tostring(Core.env.lightIntensity) .. "%")
        table.insert(texts, " - Fog: " .. tostring(Core.env.fogIntensity) .. "%")
        table.insert(texts, " - Adjusted: " .. Core.tools.formatNumber(Core.env.adjustedLightIntensity) .. "%")
        table.insert(texts, "-----")
        table.insert(texts, "Spawning mode")
        table.insert(texts, " - sprinting: " .. tostring(Core.sprint))
        table.insert(texts, "Settings")
        table.insert(texts, " - Darkness Level: " .. tostring(Core.settings.DarknessLevel))
        table.insert(texts, " - Mode: " .. tostring(Core.settings.Mode))
        table.insert(texts, " - Dawn: " .. Core.tools.formatGameTime(Core.dawnTime))
        table.insert(texts, " - Dusk: " .. Core.tools.formatGameTime(Core.duskTime))

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

    local sprinter = PhunSprintersSprinter:new(x, y, w, h / 2 - padding / 2, self.player, self.playerIndex)
    sprinter:initialise()
    self.controls.sprinter = sprinter
    sprinter.desc = getSprinterDescription
    self:addChild(sprinter)

    local moon =
        PhunSprintersMoon:new(x, y + h / 2 + padding / 2, w, h / 2 - padding / 2, self.player, self.playerIndex)
    moon:initialise()
    self.controls.moon = moon
    moon.desc = getMoonDescription
    self:addChild(moon)

    local pips =
        PhunSprintersPips:new(x, y + h / 2 + padding / 2, w, h / 2 - padding / 2, self.player, self.playerIndex)
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

        self.controls.moon:setHeight(h - 6) -- * tools.FONT_SCALE)
        self.controls.moon:setWidth(h - 6) -- * tools.FONT_SCALE)
        self.controls.moon:setY(1)
        self.controls.moon:setX(3)

        self.controls.sprinter:setHeight(self.controls.moon.height)
        self.controls.sprinter:setWidth(self.controls.moon.width)
        self.controls.sprinter:setY(self.controls.moon.y + self.controls.moon.height + 3) -- * tools.FONT_SCALE)
        self.controls.sprinter:setX(self.controls.moon.x)

        self.controls.pips:setHeight(3) -- * tools.FONT_SCALE)
        self.controls.pips:setWidth(self.width - 2) -- * tools.FONT_SCALE)
        self.controls.pips:setY(self.height - self.controls.pips.height - 2)
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
