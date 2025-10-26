if isServer() then
    return
end
local tools = require "PhunSprintersUI/ui/tools"
local Core = PhunSprintersUI
local PS = PhunSprinters
local PL = PhunLib
local profileName = "PhunSprintersUISprinter"
PhunSprintersUISprinter = ISPanelJoypad:derive(profileName);
local UI = PhunSprintersUISprinter
Core.ui = Core.ui or {}

function UI:new(x, y, width, height, player, playerIndex)
    local opts = options or {}
    local o = ISPanelJoypad:new(x, y, width, height);
    setmetatable(o, self);
    self.__index = self;

    o.displayColor = {
        r = .39,
        g = .78,
        b = .82,
        a = 1
    }

    o.ghostColor = {
        r = .4,
        g = .4,
        b = .4,
        a = 0.8
    }
    o.borderColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 0
    };
    o.controls = {}
    o.moveWithMouse = false;
    o.anchorRight = true
    o.anchorBottom = true
    o.player = player
    o.playerIndex = playerIndex
    o.displayImage = getTexture("media/ui/sprinter_on.png")
    return o;
end

function UI:prerender()
    ISPanelJoypad.prerender(self);

    local modData = self.player:getModData();

    if PS.sprint then
        self:drawTextureScaled(self.displayImage, 0, 0, self.width, self.height, self.displayColor.a,
            self.displayColor.r, self.displayColor.g, self.displayColor.b);
    else
        self:drawTextureScaled(self.displayImage, 0, 0, self.width, self.height, self.ghostColor.a, self.ghostColor.r,
            self.ghostColor.g, self.ghostColor.b);
    end

    self:updateTooltip()

end

function UI:createChildren()
    ISPanelJoypad.createChildren(self)

    self.tooltip = ISToolTip:new();
    self.tooltip:initialise();
    self.tooltip:setVisible(false);
    self.tooltip:setName("");
    self.tooltip:setAlwaysOnTop(true)
    self.tooltip.description = "";
    self.tooltip:setOwner(self)
end

function UI:onMouseMove(x, y)
    ISPanelJoypad.onMouseMove(self, x, y)
    self.mouseOver = true
end

function UI:onMouseMoveOutside(x, y)
    ISPanelJoypad.onMouseMoveOutside(self, x, y)
    self.mouseOver = false
end

function UI:updateTooltip()
    if self.mouseOver and self.tooltip then
        self.tooltip:setVisible(true)
        self.tooltip:addToUIManager()
        self.tooltip:setX(self:getAbsoluteX() - self.tooltip:getWidth())
        self.tooltip:setName(PS.sprint and getText("IGUI_PhunSprinters_ZedsAreRestless") or
                                 getText("IGUI_PhunSprinters_ZedsAreSettling"))

        local txt = self.desc and self.desc(self.player) or ""
        self.tooltip.description = txt
    else
        self.tooltip:setVisible(false)
        self.tooltip:removeFromUIManager()
    end
end
