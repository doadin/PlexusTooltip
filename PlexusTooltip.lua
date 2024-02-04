local UnitBuff = UnitBuff --luacheck: ignore 113
local UnitDebuff = UnitDebuff --luacheck: ignore 113
local PlexusFrame = Plexus:GetModule("PlexusFrame") --luacheck: ignore 113
local PlexusTooltip = Plexus:NewModule("PlexusTooltip") --luacheck: ignore 113

PlexusTooltip.defaultDB = {
    enabledIndicators = {
        icon = true,
    },
}

PlexusTooltip.options = {
    name = "Tooltip",
    desc = "Options for PlexusTooltip.",
    order = 2,
    type = "group",
    childGroups = "tab",
    disabled = InCombatLockdown, --luacheck: ignore 113
    args = {
    }
}

local lastMouseOverFrame

local function FindTooltipDebuff(unit, texture, index)
    if _G.Plexus:IsRetailWow() then
        for i=0,40 do
            local auraData = C_UnitAuras.GetDebuffDataByIndex(unit, i)
            if auraData and auraData.icon == texture then
                return i, auraData.spellId
            end
        end
        return nil
    else
        local index = index or 1 --luacheck: ignore 412
        local i = 0
        --search from the last index the texture was found to the left and right for the texture
        local name, icon, _, _, _, _, _, _, _, spellId = UnitDebuff(unit, index) --luacheck: ignore 631
        while name or index - i > 1 do
            if icon == texture then
                return index + i, spellId
            end
            i = i + 1
            _, icon, _, _, _, _, _, _, _, spellId = UnitDebuff(unit, index - i) --luacheck: ignore 631
            if icon == texture then
                return index - i, spellId
            end
            name, icon, _, _, _, _, _, _, _, spellId = UnitDebuff(unit, index + i) --luacheck: ignore 631
        end
        return nil
    end
end

local function FindTooltipBuff(unit, texture, index)
    if _G.Plexus:IsRetailWow() then
        for i=0,40 do
            local auraData = C_UnitAuras.GetBuffDataByIndex(unit, i)
            if auraData and auraData.icon == texture then
                return i, auraData.spellId
            end
        end
        return nil
    else
        local index = index or 1 --luacheck: ignore 412
        local i = 0
        local name, icon, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index) --luacheck: ignore 631
        while name or index - i > 1 do
            if icon == texture then
                return index + i, spellId
            end
            i = i + 1
            _, icon, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index - i) --luacheck: ignore 631
            if icon == texture then
                return index - i, spellId
            end
            name, icon, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index + i) --luacheck: ignore 631
        end
        return nil
    end
end

function PlexusTooltip.SetIndicator(frame, indicator, _, _, _, _, texture, _, _, _)
    if texture and PlexusTooltip.db.profile.enabledIndicators[indicator] then
        if frame.unit and UnitExists(frame.unit)then --luacheck: ignore 113
            frame.ToolTip = texture
            if lastMouseOverFrame then
                PlexusTooltip.OnEnter(lastMouseOverFrame)
            end
        end
    end
end



function PlexusTooltip.ClearIndicator(frame, indicator)
    if PlexusTooltip.db.profile.enabledIndicators[indicator] then
        frame.ToolTip = nil
        frame.ToolTipIndex = nil
    end
end

function PlexusTooltip.CreateFrames(_, frame)
    frame:HookScript("OnEnter", PlexusTooltip.OnEnter)
    frame:HookScript("OnLeave", PlexusTooltip.OnLeave)
end

function PlexusTooltip.OnEnter(frame)
    local unitid = frame.unit
    if not unitid then return end
    lastMouseOverFrame = frame

    if not frame.ToolTip then return end

    local debuff
    local buff
    if FindTooltipDebuff(unitid, frame.ToolTip, frame.ToolTipIndex) then
        frame.ToolTipIndex = FindTooltipDebuff(unitid, frame.ToolTip, frame.ToolTipIndex)
        debuff = true
    end
    if FindTooltipBuff(unitid, frame.ToolTip, frame.ToolTipIndex) then
        frame.ToolTipIndex = FindTooltipBuff(unitid, frame.ToolTip, frame.ToolTipIndex)
        buff = true
    end


    if debuff then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent) --luacheck: ignore 113
        GameTooltip:SetUnitDebuff(unitid, frame.ToolTipIndex) --luacheck: ignore 113
        GameTooltip:Show() --luacheck: ignore 113
    end

    if buff then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent) --luacheck: ignore 113
        GameTooltip:SetUnitBuff(unitid, frame.ToolTipIndex) --luacheck: ignore 113
        GameTooltip:Show() --luacheck: ignore 113
    end
end

function PlexusTooltip.OnLeave(iconFrame)
    GameTooltip:Hide() --luacheck: ignore 113
    if lastMouseOverFrame == iconFrame then
        lastMouseOverFrame = nil
    end
end

function PlexusTooltip:OnInitialize()
    if not self.db then
        self.db = _G.Plexus.db:RegisterNamespace(self.moduleName, { profile = self.defaultDB or { } }) --luacheck: ignore 113
    end

    PlexusTooltip.knownIndicators = {}

    PlexusFrame:RegisterIndicator("tooltip", "Tooltip dummy. Do not use!",
        function(frame)
            PlexusTooltip.CreateFrames(nil, frame)
            return {}
        end,

        function(self) --luacheck: ignore 432
            local indicators = self.__owner.indicators
            for id, _ in pairs(indicators) do
                if not PlexusTooltip.knownIndicators[id] then
                    PlexusTooltip.options.args[id] = {
                        name = id,
                        desc = "Display tooltip for indicator: "..PlexusFrame.indicators[id].name,
                        order = 60, width = "double",
                        type = "toggle",
                        get = function()
                            return PlexusTooltip.db.profile.enabledIndicators[id]
                        end,
                        set = function(_, v)
                            PlexusTooltip.db.profile.enabledIndicators[id] = v
                        end,
                    }
                    PlexusTooltip.knownIndicators[id] = true
                end
            end
        end,

        function()
        end,
        function()
        end
    )
    hooksecurefunc(PlexusFrame.prototype, "SetIndicator", PlexusTooltip.SetIndicator) --luacheck: ignore 113
    hooksecurefunc(PlexusFrame.prototype, "ClearIndicator", PlexusTooltip.ClearIndicator) --luacheck: ignore 113
end

function PlexusTooltip:OnEnable() --luacheck: ignore 212
end

function PlexusTooltip:OnDisable() --luacheck: ignore 212
end

function PlexusTooltip:Reset(frame) --luacheck: ignore 212
end