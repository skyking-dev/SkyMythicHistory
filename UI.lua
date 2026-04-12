local _, ns = ...
local MythicTools = ns.MythicTools

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local CLASS_CIRCLE_TEXTURE = "Interface\\TargetingFrame\\UI-Classes-Circles"
local QUESTION_MARK_ICON = "Interface\\ICONS\\INV_Misc_QuestionMark"
local DEFAULT_DUNGEON_ICON = "Interface\\Icons\\achievement_challengemode_gold"
local DEFAULT_DUNGEON_BG = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
local MAX_LOOT_ICONS = 5
local RUN_ROWS = 6
local PLAYER_ROWS = 6
local RECENT_RUN_ROWS = 4
local COMPLETION_ROWS = 5
local PLAYER_DETAIL_HISTORY_ROWS = 5
local PLAYER_DETAIL_HISTORY_MAX_ROWS = 8
local PLAYER_DETAIL_SPEC_CHIPS = 6
local RUN_ROW_HEIGHT = 72
local PLAYER_ROW_HEIGHT = 60
local COMPLETION_ROW_HEIGHT = 52
local PLAYER_TABLE_ROW_HEIGHT = 18
local PLAYER_DETAIL_HISTORY_ROW_HEIGHT = 52
local COMPLETION_POPUP_HEIGHT = 492
local COMPACT_STATS_PLAYER_WIDTH = 170
local COMPACT_STATS_SCORE_X = 232
local COMPACT_STATS_ITEMS_X = 326
local COMPACT_STATS_DAMAGE_X = 514
local COMPACT_STATS_DPS_X = 594
local COMPACT_STATS_HEALING_X = 670
local COMPACT_STATS_INTERRUPTS_X = 754
local COMPACT_STATS_DEATHS_X = 848
local COMPACT_STATS_LOOT_ICON_SIZE = 26
local COMPACT_STATS_LOOT_SPACING = 4

local MAX_STATS_DUNGEON_ROWS = 12
local MAX_STATS_CLASS_ROWS = 13
local MAX_STATS_TEAMMATE_ROWS = 10
local STATS_BAR_H = 8
local STATS_DUNGEON_ROW_H = 30
local STATS_CLASS_ROW_H = 28
local STATS_TEAMMATE_ROW_H = 34
local STATS_SECTION_TITLE_H = 40
local STATS_PAD = 12
local STATS_OVERVIEW_H = 80
local STATS_DUNGEON_SECTION_H = STATS_SECTION_TITLE_H + MAX_STATS_DUNGEON_ROWS * STATS_DUNGEON_ROW_H + STATS_PAD
local STATS_CLASS_SECTION_H = STATS_SECTION_TITLE_H + MAX_STATS_CLASS_ROWS * STATS_CLASS_ROW_H + STATS_PAD
local STATS_TWOCOL_H = (STATS_CLASS_SECTION_H > STATS_DUNGEON_SECTION_H) and STATS_CLASS_SECTION_H or STATS_DUNGEON_SECTION_H
local STATS_TEAMMATE_SECTION_H = STATS_SECTION_TITLE_H + MAX_STATS_TEAMMATE_ROWS * STATS_TEAMMATE_ROW_H + STATS_PAD
local STATS_CONTENT_H = STATS_PAD + STATS_OVERVIEW_H + STATS_PAD + STATS_DUNGEON_SECTION_H + STATS_PAD + STATS_TWOCOL_H + STATS_PAD + STATS_TEAMMATE_SECTION_H + STATS_PAD

local cos = math.cos
local sin = math.sin
local rad = math.rad
local deg = math.deg
local atan2 = math.atan2 or math.atan
local floor = math.floor
local min = math.min
local max = math.max
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
local ScrollingTable = LibStub and LibStub("ScrollingTable", true)
local ROLE_ICON_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"

local COLORS = {
    frameBG = {0.1, 0.1, 0.1, 0.9},
    frameBorder = {0, 0, 0, 1},
    headerBG = {0.115, 0.115, 0.115, 1},
    panelBG = {0.1, 0.1, 0.1, 0.9},
    sectionBG = {0.115, 0.115, 0.115, 1},
    rowBG = {0.115, 0.115, 0.115, 1},
    rowSelected = {0.23, 0.23, 0.23, 1},
    surface = {0, 0, 0, 1},
    accent = {0.7, 0.7, 0.7, 1},
    accentSoft = {0.7, 0.7, 0.7, 0.5},
    success = {0.35, 0.85, 0.35, 1},
    danger = {0.85, 0.25, 0.25, 1},
    warning = {0.85, 0.75, 0.20, 1},
    text = {1, 1, 1, 1},
    muted = {0.7, 0.7, 0.7, 1},
    subdued = {0.5, 0.5, 0.5, 1},
    bright = {1, 1, 1, 1},
    shadow = {0, 0, 0, 0},
}

-- Dynamic class color accent (like Cell's accent system)
do
    local _class = select(2, UnitClass("player"))
    if _class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[_class] then
        local cc = RAID_CLASS_COLORS[_class]
        COLORS.accent = {cc.r, cc.g, cc.b, 1}
        COLORS.accentSoft = {cc.r, cc.g, cc.b, 0.5}
    end
end

local STATUS_OPTIONS = {
    {value = "all", label = "All"},
    {value = "timed", label = "Timed"},
    {value = "overtime", label = "Overtime"},
    {value = "abandoned", label = "Abandoned"},
}

local OWNED_CHARACTER_FILTER_OPTIONS = {
    {value = "all", label = "All runs"},
    {value = "mine", label = "Only my characters"},
}

local POPUP_TRIGGER_OPTIONS = {
    {value = "COMPLETED", label = "When the run ends"},
    {value = "LOOT_CLOSED", label = "After the chest closes"},
}

local SEASON_OPTIONS = {
    {value = "season1", label = "Season 1"},
}

local SEASON_DUNGEONS = {
    season1 = {
        {value = "all", label = "All dungeons"},
        {value = "Magisters' Terrace", label = "Magisters' Terrace"},
        {value = "Maisara Caverns", label = "Maisara Caverns"},
        {value = "Nexus-Point Xenas", label = "Nexus-Point Xenas"},
        {value = "Windrunner Spire", label = "Windrunner Spire"},
        {value = "Algeth'ar Academy", label = "Algeth'ar Academy"},
        {value = "Pit of Saron", label = "Pit of Saron"},
        {value = "Seat of the Triumvirate", label = "Seat of the Triumvirate"},
        {value = "Skyreach", label = "Skyreach"},
    },
}

local function SetTextColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function CreateFont(parent, size, color, justifyH, layer, outline)
    local fontString = parent:CreateFontString(nil, layer or "OVERLAY")
    fontString:SetFont(STANDARD_TEXT_FONT, size, outline or "")
    fontString:SetJustifyH(justifyH or "LEFT")
    fontString:SetJustifyV("MIDDLE")
    fontString:SetShadowColor(0, 0, 0)
    fontString:SetShadowOffset(1, -1)
    SetTextColor(fontString, color or COLORS.text)
    return fontString
end

local function GetStatusLabel(status)
    for _, info in ipairs(STATUS_OPTIONS) do
        if info.value == status then
            return info.label
        end
    end
    return STATUS_OPTIONS[1].label
end

local function GetPopupTriggerLabel(trigger)
    for _, info in ipairs(POPUP_TRIGGER_OPTIONS) do
        if info.value == trigger then
            return info.label
        end
    end
    return POPUP_TRIGGER_OPTIONS[1].label
end

local function GetPopupTriggerNext(trigger)
    for index, info in ipairs(POPUP_TRIGGER_OPTIONS) do
        if info.value == trigger then
            local nextInfo = POPUP_TRIGGER_OPTIONS[index + 1] or POPUP_TRIGGER_OPTIONS[1]
            return nextInfo.value
        end
    end
    return POPUP_TRIGGER_OPTIONS[1].value
end

local function GetSeasonLabel(season)
    for _, info in ipairs(SEASON_OPTIONS) do
        if info.value == season then
            return info.label
        end
    end
    return SEASON_OPTIONS[1].label
end

local function GetSeasonNext(season)
    for index, info in ipairs(SEASON_OPTIONS) do
        if info.value == season then
            local nextInfo = SEASON_OPTIONS[index + 1] or SEASON_OPTIONS[1]
            return nextInfo.value
        end
    end
    return SEASON_OPTIONS[1].value
end

local function GetDungeonOptionsForSeason(season)
    return SEASON_DUNGEONS[season] or SEASON_DUNGEONS[SEASON_OPTIONS[1].value]
end

local function GetOwnedCharacterFilterOptions()
    local options = {
        {value = "all", label = "All runs"},
        {value = "mine", label = "Any account character"},
    }

    local characters = MythicTools.GetOwnedCharacters and MythicTools:GetOwnedCharacters() or {}
    local shortNameCounts = {}
    for _, fullName in ipairs(characters) do
        local shortName = MythicTools:GetShortName(fullName)
        shortNameCounts[shortName] = (shortNameCounts[shortName] or 0) + 1
    end

    for _, fullName in ipairs(characters) do
        local shortName = MythicTools:GetShortName(fullName)
        options[#options + 1] = {
            value = fullName,
            label = (shortNameCounts[shortName] or 0) > 1 and fullName or shortName,
        }
    end

    return options
end

local function NormalizeDateFilter(text)
    text = MythicTools:TrimText(text)
    if text == "" then
        return ""
    end

    local day, month, year = text:match("^(%d%d?)/(%d%d?)/(%d%d%d%d)$")
    if day and month and year then
        return ("%02d/%02d/%04d"):format(tonumber(day), tonumber(month), tonumber(year))
    end

    year, month, day = text:match("^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$")
    if year and month and day then
        return ("%02d/%02d/%04d"):format(tonumber(day), tonumber(month), tonumber(year))
    end

    return MythicTools:Lower(text)
end

local function GetRunStatusColor(run)
    local result = MythicTools:GetRunResult(run)
    if result == "timed" then
        return COLORS.success
    end
    if result == "abandoned" then
        return COLORS.danger
    end
    return COLORS.warning
end

local function GetRunStatusText(run)
    local result = MythicTools:GetRunResult(run)
    if result == "timed" then
        return "Timed"
    end
    if result == "abandoned" then
        return "Abandoned"
    end
    return "Overtime"
end

local function GetDungeonIcon(run)
    return run and (run.textureFileID or run.backgroundTextureFileID) or DEFAULT_DUNGEON_ICON
end

local function GetDungeonBackground(run)
    return run and (run.backgroundTextureFileID or run.textureFileID) or DEFAULT_DUNGEON_BG
end

local function NormalizeDisplayItemLink(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    return itemLink:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
        or itemLink:match("(|Hitem:.-|h%[.-%]|h)")
        or itemLink
end

local function GetItemIDFromLinkish(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    local itemID = itemLink:match("Hitem:(%d+)")
        or itemLink:match("|Hitem:(%d+)")
        or itemLink:match("^item:(%d+)")
        or itemLink:match("item:(%d+)")

    return itemID and tonumber(itemID) or nil
end

local function ExtractItemNameFromLink(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end

    local itemName = itemLink:match("%[(.-)%]")
    if itemName and itemName ~= "" then
        return itemName
    end

    return nil
end

local function GetItemNameFallback(itemLink)
    itemLink = NormalizeDisplayItemLink(itemLink)
    if not itemLink then
        return ""
    end

    local itemName = GetItemInfo(itemLink)
    if itemName and itemName ~= "" then
        return itemName
    end

    itemName = ExtractItemNameFromLink(itemLink)
    if itemName and itemName ~= "" then
        return itemName
    end

    local itemID = GetItemIDFromLinkish(itemLink)
    if itemID and C_Item and C_Item.GetItemNameByID then
        itemName = C_Item.GetItemNameByID(itemID)
        if itemName and itemName ~= "" then
            return itemName
        end
    end

    return "Unknown item"
end

local function GetItemQualityColorByLink(itemLink)
    itemLink = NormalizeDisplayItemLink(itemLink)
    if not itemLink or not C_Item or not C_Item.GetItemQualityColor then
        return nil
    end

    local itemName, itemLinkResolved, itemQuality = GetItemInfo(itemLink)
    if itemName and itemQuality then
        local r, g, b = C_Item.GetItemQualityColor(itemQuality)
        if r and g and b then
            return {r, g, b, 1}
        end
    end

    local itemID = GetItemIDFromLinkish(itemLink)
    if itemID and C_Item and C_Item.GetItemQualityByID then
        local quality = C_Item.GetItemQualityByID(itemID)
        if quality then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            if r and g and b then
                return {r, g, b, 1}
            end
        end
    end

    return nil
end

local function GetItemLevelForLink(itemLink)
    itemLink = NormalizeDisplayItemLink(itemLink)
    if not itemLink then
        return nil
    end

    local itemLevel = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(itemLink) or nil
    itemLevel = tonumber(itemLevel) or itemLevel
    if itemLevel and itemLevel > 0 then
        return itemLevel
    end

    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local detailedItemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
        itemLevel = tonumber(detailedItemLevel) or nil
        if itemLevel and itemLevel > 0 then
            return itemLevel
        end
    end

    return nil
end

local function FormatItemLevelText(itemLevel)
    itemLevel = tonumber(itemLevel)
    if not itemLevel or itemLevel <= 0 then
        return ""
    end

    if math.abs(itemLevel - math.floor(itemLevel + 0.5)) < 0.05 then
        return tostring(math.floor(itemLevel + 0.5))
    end

    return ("%.1f"):format(itemLevel)
end

local function GetClassIconMarkup(classFilename, specIconID)
    if specIconID then
        return ("|T%d:16:16:0:0|t"):format(specIconID)
    end

    local coords = classFilename and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFilename]
    if coords then
        return ("|T%s:16:16:0:0:256:256:%d:%d:%d:%d|t"):format(
            CLASS_CIRCLE_TEXTURE,
            math.floor(coords[1] * 256),
            math.floor(coords[2] * 256),
            math.floor(coords[3] * 256),
            math.floor(coords[4] * 256)
        )
    end

    return ("|T%s:16:16:0:0|t"):format(QUESTION_MARK_ICON)
end

function MythicTools:ApplySurface(frame, bgColor, borderColor, accentColor)
    local surface = frame._mtSurface
    if not surface then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(WHITE_TEXTURE)

        local top = frame:CreateTexture(nil, "ARTWORK")
        top:SetTexture(WHITE_TEXTURE)
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")
        top:SetHeight(1)

        local bottom = frame:CreateTexture(nil, "ARTWORK")
        bottom:SetTexture(WHITE_TEXTURE)
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")
        bottom:SetHeight(1)

        local left = frame:CreateTexture(nil, "ARTWORK")
        left:SetTexture(WHITE_TEXTURE)
        left:SetPoint("TOPLEFT")
        left:SetPoint("BOTTOMLEFT")
        left:SetWidth(1)

        local right = frame:CreateTexture(nil, "ARTWORK")
        right:SetTexture(WHITE_TEXTURE)
        right:SetPoint("TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT")
        right:SetWidth(1)

        surface = {
            bg = bg,
            top = top,
            bottom = bottom,
            left = left,
            right = right,
        }
        frame._mtSurface = surface
    end

    surface.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    surface.top:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    surface.bottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    surface.left:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    surface.right:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
end

local function StyleEditBox(editBox)
    editBox:SetAutoFocus(false)
    editBox:SetTextInsets(10, 10, 0, 0)
    editBox:SetFont(STANDARD_TEXT_FONT, 13, "")
    editBox:SetJustifyH("LEFT")
    if editBox.Left then editBox.Left:SetAlpha(0) end
    if editBox.Middle then editBox.Middle:SetAlpha(0) end
    if editBox.Right then editBox.Right:SetAlpha(0) end
end

local function ClipChildren(frame)
    if frame and frame.SetClipsChildren then
        frame:SetClipsChildren(true)
    end
end

local function CreateLabeledEditBox(parent, labelText, width, onChanged)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 50)

    holder.Label = CreateFont(holder, 11, COLORS.subdued)
    holder.Label:SetPoint("TOPLEFT", 2, 0)
    holder.Label:SetText(labelText)

    holder.Bg = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    holder.Bg:SetPoint("TOPLEFT", 0, -18)
    holder.Bg:SetSize(width, 28)
    holder.Bg:SetBackdrop({bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = 1, insets = {left=1, right=1, top=1, bottom=1}})
    holder.Bg:SetBackdropColor(COLORS.frameBG[1], COLORS.frameBG[2], COLORS.frameBG[3], 1)
    holder.Bg:SetBackdropBorderColor(0, 0, 0, 1)

    holder.Input = CreateFrame("EditBox", nil, holder.Bg, "InputBoxTemplate")
    holder.Input:SetPoint("TOPLEFT", 0, 0)
    holder.Input:SetPoint("BOTTOMRIGHT", 0, 0)
    StyleEditBox(holder.Input)
    holder.Input:SetScript("OnEscapePressed", function(editBox) editBox:ClearFocus() end)
    holder.Input:SetScript("OnEnterPressed", function(editBox)
        editBox:ClearFocus()
        if onChanged then
            onChanged(editBox:GetText())
        end
    end)
    holder.Input:SetScript("OnTextChanged", function(editBox, userInput)
        if userInput and onChanged then
            onChanged(editBox:GetText())
        end
    end)

    function holder:SetValue(value)
        if not self.Input:HasFocus() then
            self.Input:SetText(value or "")
        end
    end

    return holder
end

local function CreateActionButton(parent, width, height, label)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop({bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = 1, insets = {left=1, right=1, top=1, bottom=1}})
    button:SetBackdropColor(COLORS.rowBG[1], COLORS.rowBG[2], COLORS.rowBG[3], 1)
    button:SetBackdropBorderColor(0, 0, 0, 1)

    button.Text = CreateFont(button, 12, COLORS.text, "CENTER", "OVERLAY", "")
    button.Text:SetPoint("CENTER")
    button.Text:SetText(label)

    button._restyle = function(self)
        if self._selected then
            button:SetBackdropColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.3)
            button:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
            SetTextColor(self.Text, COLORS.bright)
        else
            button:SetBackdropColor(COLORS.rowBG[1], COLORS.rowBG[2], COLORS.rowBG[3], 1)
            button:SetBackdropBorderColor(0, 0, 0, 1)
            SetTextColor(self.Text, COLORS.text)
        end
    end

    button:SetScript("OnEnter", function(self)
        if not self._selected then
            button:SetBackdropColor(COLORS.rowSelected[1], COLORS.rowSelected[2], COLORS.rowSelected[3], 1)
            SetTextColor(self.Text, COLORS.bright)
        end
    end)
    button:SetScript("OnLeave", function(self)
        if self._restyle then
            self:_restyle()
        end
    end)

    button:_restyle()
    return button
end

local function CreateCycleControl(parent, labelText, width, getLabel, onClick)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 50)

    holder.Label = CreateFont(holder, 11, COLORS.subdued)
    holder.Label:SetPoint("TOPLEFT", 2, 0)
    holder.Label:SetText(labelText)

    holder.Button = CreateActionButton(holder, width, 28, "")
    holder.Button:SetPoint("TOPLEFT", 0, -18)
    holder.Button:SetScript("OnClick", function()
        if onClick then
            onClick()
        end
    end)

    function holder:SetValue(value)
        holder.Button.Text:SetText(getLabel and getLabel(value) or tostring(value or ""))
    end

    return holder
end

local function CreateDropdownControl(parent, labelText, width, getOptions, onChanged)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 50)

    holder.Label = CreateFont(holder, 11, COLORS.subdued)
    holder.Label:SetPoint("TOPLEFT", 2, 0)
    holder.Label:SetText(labelText)

    holder.Button = CreateFrame("Button", nil, holder, "BackdropTemplate")
    holder.Button:SetPoint("TOPLEFT", 0, -18)
    holder.Button:SetSize(width, 28)
    holder.Button:SetBackdrop({bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = 1, insets = {left=1, right=1, top=1, bottom=1}})
    holder.Button:SetBackdropColor(COLORS.rowBG[1], COLORS.rowBG[2], COLORS.rowBG[3], 1)
    holder.Button:SetBackdropBorderColor(0, 0, 0, 1)
    holder.Button:SetScript("OnEnter", function() holder.Button:SetBackdropColor(COLORS.rowSelected[1], COLORS.rowSelected[2], COLORS.rowSelected[3], 1) end)
    holder.Button:SetScript("OnLeave", function() holder.Button:SetBackdropColor(COLORS.rowBG[1], COLORS.rowBG[2], COLORS.rowBG[3], 1) end)

    holder.Button.Text = CreateFont(holder.Button, 12, COLORS.text)
    holder.Button.Text:SetPoint("LEFT", 10, 0)
    holder.Button.Text:SetPoint("RIGHT", -24, 0)
    holder.Button.Text:SetJustifyH("LEFT")

    holder.Button.Arrow = CreateFont(holder.Button, 11, COLORS.muted, "RIGHT")
    holder.Button.Arrow:SetPoint("RIGHT", -9, 0)
    holder.Button.Arrow:SetText("v")

    holder.Button:SetScript("OnClick", function(button)
        local menu = {}
        for _, info in ipairs(getOptions and getOptions() or {}) do
            menu[#menu + 1] = {
                text = info.label,
                checked = holder.value == info.value,
                notCheckable = false,
                func = function()
                    holder:SetValue(info.value)
                    if onChanged then
                        onChanged(info.value)
                    end
                end,
            }
        end

        MythicTools.dropdownMenuFrame = MythicTools.dropdownMenuFrame or CreateFrame("Frame", "MythicToolsDropdownMenu", UIParent, "UIDropDownMenuTemplate")
        MythicTools.dropdownMenuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        EasyMenu(menu, MythicTools.dropdownMenuFrame, "cursor", 0, 0, "MENU")
    end)

    function holder:SetValue(value)
        holder.value = value
        local selectedLabel = tostring(value or "")
        for _, info in ipairs(getOptions and getOptions() or {}) do
            if info.value == value then
                selectedLabel = info.label
                break
            end
        end
        holder.Button.Text:SetText(selectedLabel)
    end

    return holder
end

local function AttachAceContainer(widget, parent, left, top, right, height)
    widget.frame:SetParent(parent)
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", left, top)
    widget.frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", right, top)
    widget.frame:SetHeight(height)
    widget.frame:Show()
    return widget
end

local function CreateAceFlowRow(parent, topOffset, height)
    if not AceGUI then
        return nil
    end

    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("Flow")
    return AttachAceContainer(group, parent, 12, topOffset, -12, height)
end

local function CreateAceSpacer(width)
    if not AceGUI then return nil end
    local spacer = AceGUI:Create("Label")
    spacer:SetWidth(width)
    spacer:SetText("")
    return spacer
end

local function StyleAceEditWidget(widget)
    if not widget then return end
    local eb = widget.editBox
    if eb then
        if eb.SetBackdropColor then
            eb:SetBackdropColor(0.20, 0.20, 0.20, 1)
        end
        if eb.SetBackdropBorderColor then
            eb:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
        end
    end
end

local function StyleAceDropdownWidget(widget)
    if not widget then return end
    local btn = widget.button
    if btn then
        if btn.SetBackdropColor then
            btn:SetBackdropColor(0.20, 0.20, 0.20, 1)
        end
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
        end
    end
end

local function ApplyThinScrollBar(scrollFrame)
    if not scrollFrame then return end
    local scrollBar
    for _, child in ipairs({scrollFrame:GetChildren()}) do
        if child.GetThumbTexture or child:GetObjectType() == "Slider" then
            scrollBar = child
            break
        end
    end
    if not scrollBar then return end

    scrollBar:SetWidth(6)
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, -1)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 0, 1)

    for _, btn in ipairs({scrollBar:GetChildren()}) do
        btn:SetAlpha(0)
        btn:EnableMouse(false)
    end

    local numRegions = scrollBar.GetNumRegions and scrollBar:GetNumRegions() or 0
    for i = 1, numRegions do
        local region = select(i, scrollBar:GetRegions())
        if region and region.SetTexture then
            region:SetTexture(nil)
        end
    end

    local thumb = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture()
    if thumb then
        thumb:SetTexture(WHITE_TEXTURE)
        thumb:SetWidth(4)
        thumb:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.65)
    end
end

local function ApplyThinScrollBarToST(tableWidget)
    if not tableWidget or not tableWidget.scrollframe then return end
    local scrollframe = tableWidget.scrollframe
    local f = tableWidget.frame

    -- Hide lib-st's custom scroll trough frames (they are Frame children of scrollframe)
    for _, child in ipairs({scrollframe:GetChildren()}) do
        if child:GetObjectType() == "Frame" then
            child:Hide()
        end
    end

    -- Expand the scrollframe into the space freed by removing the wide trough
    scrollframe:ClearAllPoints()
    scrollframe:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -4)
    scrollframe:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 3)

    ApplyThinScrollBar(scrollframe)
end

local function CreateAceEditWidget(labelText, width, value, onChanged)
    if not AceGUI then
        return nil
    end

    local widget = AceGUI:Create("EditBox")
    widget:SetLabel(labelText)
    widget:SetWidth(width)
    widget:DisableButton(true)
    widget:SetText(value or "")
    widget:SetCallback("OnEnterPressed", function(_, _, text)
        if widget._mtSettingValue then
            return
        end
        if onChanged then
            onChanged(text or "")
        end
    end)
    widget:SetCallback("OnTextChanged", function(_, _, text)
        if widget._mtSettingValue then
            return
        end
        if onChanged then
            onChanged(text or "")
        end
    end)
    return widget
end

local function CreateAceDropdownWidget(labelText, width, options, value, onChanged)
    if not AceGUI then
        return nil
    end

    local list = {}
    local order = {}
    for _, info in ipairs(options or {}) do
        list[info.value] = info.label
        order[#order + 1] = info.value
    end

    local widget = AceGUI:Create("Dropdown")
    widget:SetLabel(labelText)
    widget:SetWidth(width)
    widget:SetList(list, order)
    widget:SetValue(value)
    widget:SetCallback("OnValueChanged", function(_, _, selectedValue)
        if widget._mtSettingValue then
            return
        end
        if onChanged then
            onChanged(selectedValue)
        end
    end)
    return widget
end

local function UpdateAceDropdownOptions(widget, options, value)
    if not widget then
        return
    end

    local list = {}
    local order = {}
    for _, info in ipairs(options or {}) do
        list[info.value] = info.label
        order[#order + 1] = info.value
    end

    widget._mtSettingValue = true
    widget:SetList(list, order)
    widget:SetValue(value)
    widget._mtSettingValue = nil
end

local function SetAceEditText(widget, value)
    if widget then
        widget._mtSettingValue = true
        widget:SetText(value or "")
        widget._mtSettingValue = nil
    end
end

local function SetAceDropdownValue(widget, value)
    if widget then
        widget._mtSettingValue = true
        widget:SetValue(value)
        widget._mtSettingValue = nil
    end
end

function MythicTools:RefreshOwnedCharacterFilterOptions()
    if not (self.ui and self.ui.runsOwnedFilter) then
        return
    end

    local options = GetOwnedCharacterFilterOptions()
    local selectedValue = (self.db and self.db.ui and self.db.ui.filters and self.db.ui.filters.ownedCharacters) or "all"
    local hasSelectedValue = false

    for _, info in ipairs(options) do
        if info.value == selectedValue then
            hasSelectedValue = true
            break
        end
    end

    if not hasSelectedValue then
        selectedValue = "all"
        self.db.ui.filters.ownedCharacters = selectedValue
    end

    UpdateAceDropdownOptions(self.ui.runsOwnedFilter, options, selectedValue)
end

local function CreateListButton(parent, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(height)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    MythicTools:ApplySurface(button, COLORS.rowBG, COLORS.surface, nil)

    button.Accent = button:CreateTexture(nil, "ARTWORK")
    button.Accent:SetTexture(WHITE_TEXTURE)
    button.Accent:SetPoint("TOPLEFT")
    button.Accent:SetPoint("BOTTOMLEFT")
    button.Accent:SetWidth(3)
    button.Accent:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.25)

    button.IconFrame = CreateFrame("Frame", nil, button)
    button.IconFrame:SetSize(42, 42)
    button.IconFrame:SetPoint("LEFT", 12, 0)
    MythicTools:ApplySurface(button.IconFrame, COLORS.frameBG, COLORS.surface, nil)

    button.Icon = button.IconFrame:CreateTexture(nil, "ARTWORK")
    button.Icon:SetPoint("TOPLEFT", 1, -1)
    button.Icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.Icon:SetTexture(DEFAULT_DUNGEON_ICON)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.Title = CreateFont(button, 13, COLORS.text)
    button.Title:SetPoint("TOPLEFT", button.IconFrame, "TOPRIGHT", 12, -3)
    button.Title:SetPoint("TOPRIGHT", -104, -3)

    button.Subtitle = CreateFont(button, 11, COLORS.muted)
    button.Subtitle:SetPoint("TOPLEFT", button.Title, "BOTTOMLEFT", 0, -6)
    button.Subtitle:SetPoint("TOPRIGHT", -104, -28)
    button.Subtitle:SetJustifyH("LEFT")

    button.RightTop = CreateFont(button, 11, COLORS.accent, "RIGHT")
    button.RightTop:SetPoint("TOPRIGHT", -12, -12)
    button.RightTop:SetWidth(92)

    button.RightBottom = CreateFont(button, 11, COLORS.subdued, "RIGHT")
    button.RightBottom:SetPoint("BOTTOMRIGHT", -12, 14)
    button.RightBottom:SetWidth(92)

    button:SetHighlightTexture(WHITE_TEXTURE)
    local highlight = button:GetHighlightTexture()
    highlight:SetAllPoints()
    highlight:SetVertexColor(1, 1, 1, 0.04)

    return button
end

function MythicTools:ConfirmDeleteRun(runId)
    if not runId then
        return
    end

    local run = self:GetRunById(runId)
    if not run then
        return
    end

    local label = ("%s +%d"):format(run.dungeonName or "Unknown", tonumber(run.level) or 0)
    StaticPopup_Show("MYTHICTOOLS_DELETE_RUN", label, nil, runId)
end

local function CreateMetricCard(parent, labelText)
    local card = CreateFrame("Frame", nil, parent)
    MythicTools:ApplySurface(card, COLORS.rowBG, COLORS.surface, nil)

    card.Label = CreateFont(card, 10, COLORS.subdued)
    card.Label:SetPoint("TOPLEFT", 12, -10)
    card.Label:SetPoint("TOPRIGHT", -12, -10)
    card.Label:SetJustifyH("LEFT")
    card.Label:SetText(labelText)

    card.Value = CreateFont(card, 18, COLORS.text)
    card.Value:SetPoint("TOPLEFT", card.Label, "BOTTOMLEFT", 0, -8)
    card.Value:SetPoint("TOPRIGHT", -12, -12)
    card.Value:SetJustifyH("LEFT")

    card.Meta = CreateFont(card, 10, COLORS.subdued)
    card.Meta:SetPoint("BOTTOMLEFT", 12, 10)
    card.Meta:SetPoint("BOTTOMRIGHT", -12, 10)
    card.Meta:SetJustifyH("LEFT")

    return card
end

local function CreateBreakdownRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(34)
    MythicTools:ApplySurface(row, COLORS.rowBG, COLORS.surface, nil)

    row.Title = CreateFont(row, 11, COLORS.text)
    row.Title:SetPoint("TOPLEFT", 10, -6)
    row.Title:SetPoint("TOPRIGHT", -10, -6)
    row.Title:SetJustifyH("LEFT")

    row.Meta = CreateFont(row, 10, COLORS.muted)
    row.Meta:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -4)
    row.Meta:SetPoint("TOPRIGHT", -10, -18)
    row.Meta:SetJustifyH("LEFT")

    return row
end

local function CreateSpecChip(parent)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetSize(88, 26)
    MythicTools:ApplySurface(chip, COLORS.rowBG, COLORS.surface, nil)

    chip.Icon = chip:CreateTexture(nil, "ARTWORK")
    chip.Icon:SetSize(18, 18)
    chip.Icon:SetPoint("LEFT", 6, 0)
    chip.Icon:SetTexture(QUESTION_MARK_ICON)
    chip.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    chip.Count = CreateFont(chip, 11, COLORS.text)
    chip.Count:SetPoint("LEFT", chip.Icon, "RIGHT", 6, 0)
    chip.Count:SetJustifyH("LEFT")

    chip.Role = CreateFont(chip, 9, COLORS.subdued, "RIGHT")
    chip.Role:SetPoint("RIGHT", -6, 0)
    chip.Role:SetJustifyH("RIGHT")

    return chip
end

local function CreatePlayerDetailHistoryRow(parent)
    local row = CreateListButton(parent, PLAYER_DETAIL_HISTORY_ROW_HEIGHT - 4)
    row.IconFrame:SetSize(30, 30)
    row.IconFrame:ClearAllPoints()
    row.IconFrame:SetPoint("LEFT", 10, 0)
    row.Title:ClearAllPoints()
    row.Title:SetPoint("TOPLEFT", row.IconFrame, "TOPRIGHT", 10, -2)
    row.Title:SetPoint("TOPRIGHT", -190, -2)
    row.Subtitle:ClearAllPoints()
    row.Subtitle:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -4)
    row.Subtitle:SetPoint("TOPRIGHT", -190, -18)
    row.RightTop:ClearAllPoints()
    row.RightTop:SetPoint("TOPRIGHT", -12, -8)
    row.RightTop:SetWidth(90)
    row.RightBottom:ClearAllPoints()
    row.RightBottom:SetPoint("BOTTOMRIGHT", -12, 8)
    row.RightBottom:SetWidth(150)
    return row
end

local function CreateRoleBadge(parent)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(22, 22)
    MythicTools:ApplySurface(badge, COLORS.rowBG, COLORS.surface, nil)

    badge.Icon = badge:CreateTexture(nil, "ARTWORK")
    badge.Icon:SetPoint("TOPLEFT", 2, -2)
    badge.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
    badge.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    badge.Label = CreateFont(badge, 9, COLORS.text, "CENTER")
    badge.Label:SetAllPoints()

    badge:Hide()
    return badge
end

local function CreateMultilineNoteEditor(parent, width, height)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, height)
    MythicTools:ApplySurface(holder, COLORS.rowBG, COLORS.surface, nil)
    ClipChildren(holder)

    local editBox = CreateFrame("EditBox", nil, holder)
    editBox:SetAutoFocus(false)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], 1)
    editBox:SetMaxLetters(160)
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:SetPoint("TOPLEFT", 10, -8)
    editBox:SetPoint("BOTTOMRIGHT", -10, 8)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text:find("\n") then
            local firstLine, secondLine = text:match("^([^\n]*)\n([^\n]*)")
            local limited = (firstLine or "") .. "\n" .. (secondLine or "")
            if limited ~= text then
                self:SetText(limited)
                self:SetCursorPosition(strlen(limited))
            end
        end
    end)

    holder:SetScript("OnSizeChanged", function(self, newWidth, newHeight)
        editBox:SetWidth(max(20, (newWidth or width or 20) - 20))
        editBox:SetHeight(max(20, (newHeight or height or 20) - 16))
    end)

    holder.EditBox = editBox
    return holder
end

local function CreatePlayerFilterButton(parent, anchorWidget)
    local button = CreateFrame("Button", nil, parent)
    button:SetFrameLevel((parent:GetFrameLevel() or 1) + 6)
    button:SetSize(anchorWidget:GetWidth() > 0 and anchorWidget:GetWidth() or 220, 14)
    button:SetPoint("TOPLEFT", anchorWidget, "TOPLEFT", -2, 0)
    button:RegisterForClicks("AnyUp")
    button:SetHighlightTexture(WHITE_TEXTURE)

    local highlight = button:GetHighlightTexture()
    highlight:SetAllPoints()
    highlight:SetVertexColor(1, 1, 1, 0.08)

    button:SetScript("OnClick", function(self, mouseButton)
        if self.playerName and self.playerName ~= "" then
            if mouseButton == "RightButton" then
                MythicTools:ShowPlayerContextMenu(self.playerName)
            else
                MythicTools:OpenPlayerHistory(self.playerName)
            end
        end
    end)

    button:SetScript("OnEnter", function(self)
        if not self.playerName or self.playerName == "" then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine(self.playerName, COLORS.text[1], COLORS.text[2], COLORS.text[3])
        GameTooltip:AddLine("Left click: open player details.", COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        GameTooltip:AddLine("Right click: history options.", COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

local function CreatePortraitWidget(parent, size)
    local portrait = CreateFrame("Frame", nil, parent)
    portrait:SetSize(size, size)
    MythicTools:ApplySurface(portrait, COLORS.frameBG, COLORS.surface, nil)

    portrait.Texture = portrait:CreateTexture(nil, "ARTWORK")
    portrait.Texture:SetPoint("TOPLEFT", 1, -1)
    portrait.Texture:SetPoint("BOTTOMRIGHT", -1, 1)
    portrait.Texture:SetTexture(QUESTION_MARK_ICON)
    portrait.Texture:SetTexCoord(0, 1, 0, 1)

    portrait.SpecIcon = portrait:CreateTexture(nil, "OVERLAY")
    portrait.SpecIcon:SetSize(14, 14)
    portrait.SpecIcon:SetPoint("BOTTOMRIGHT", 4, -4)
    portrait.SpecIcon:Hide()

    return portrait
end

local function CreateLootIconButton(parent, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp")
    button:SetFrameLevel((parent:GetFrameLevel() or 1) + 8)
    MythicTools:ApplySurface(button, COLORS.frameBG, COLORS.surface, nil)

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetPoint("TOPLEFT", 1, -1)
    button.Icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.Icon:SetTexture(QUESTION_MARK_ICON)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.Gloss = button:CreateTexture(nil, "OVERLAY")
    button.Gloss:SetTexture(WHITE_TEXTURE)
    button.Gloss:SetPoint("TOPLEFT", 1, -1)
    button.Gloss:SetPoint("TOPRIGHT", -1, -1)
    button.Gloss:SetHeight(6)
    button.Gloss:SetVertexColor(1, 1, 1, 0.10)

    button.ItemLevel = CreateFont(button, 9, COLORS.bright, "CENTER", "OVERLAY", "OUTLINE")
    button.ItemLevel:SetPoint("BOTTOM", 0, 1)
    button.ItemLevel:SetText("")

    button:SetScript("OnEnter", function(self)
        if not self.itemLink then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()

        self:SetScript("OnUpdate", function()
            if IsShiftKeyDown() then
                GameTooltip_ShowCompareItem(GameTooltip)
            else
                GameTooltip_HideShoppingTooltips(GameTooltip)
            end
        end)
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        GameTooltip_HideShoppingTooltips(GameTooltip)
        self:SetScript("OnUpdate", nil)
    end)

    button:Hide()
    return button
end

local function CreateLootTextButton(parent, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(parent:GetHeight())
    button:SetWidth(width)
    button:SetFrameLevel((parent:GetFrameLevel() or 1) + 8)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp")

    button.Text = CreateFont(button, 10, COLORS.muted)
    button.Text:SetPoint("TOPLEFT", 0, 0)
    button.Text:SetPoint("BOTTOMRIGHT", 0, 0)
    button.Text:SetJustifyH("LEFT")
    button.Text:SetJustifyV("MIDDLE")
    button.Text:SetWordWrap(false)
    button.Text:Show()

    button:SetScript("OnEnter", function(self)
        if not self.itemLink then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()

        self:SetScript("OnUpdate", function()
            if IsShiftKeyDown() then
                GameTooltip_ShowCompareItem(GameTooltip)
            else
                GameTooltip_HideShoppingTooltips(GameTooltip)
            end
        end)
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        GameTooltip_HideShoppingTooltips(GameTooltip)
        self:SetScript("OnUpdate", nil)
    end)

    button:Hide()
    return button
end

local function CreateLootLine(parent, iconSize, textWidth)
    local line = CreateFrame("Frame", nil, parent)
    line:SetHeight(iconSize)
    line:SetWidth(iconSize + 6 + textWidth)
    line:SetClipsChildren(true)

    line.IconButton = CreateLootIconButton(line, iconSize)
    line.IconButton:SetPoint("LEFT", 0, 0)

    line.TextButton = CreateLootTextButton(line, textWidth)
    line.TextButton:SetPoint("LEFT", line.IconButton, "RIGHT", 6, 0)

    return line
end

local function CreateCompactLootStrip(parent)
    local container = CreateFrame("Frame", nil, parent)
    local width = (MAX_LOOT_ICONS * COMPACT_STATS_LOOT_ICON_SIZE) + ((MAX_LOOT_ICONS - 1) * COMPACT_STATS_LOOT_SPACING) + 34
    container:SetSize(width, COMPACT_STATS_LOOT_ICON_SIZE)

    local buttons = {}
    for index = 1, MAX_LOOT_ICONS do
        local button = CreateLootIconButton(container, COMPACT_STATS_LOOT_ICON_SIZE)
        if index == 1 then
            button:SetPoint("LEFT", 0, 0)
        else
            button:SetPoint("LEFT", buttons[index - 1], "RIGHT", COMPACT_STATS_LOOT_SPACING, 0)
        end
        buttons[index] = button
    end

    local overflow = CreateFont(container, 10, COLORS.subdued)
    overflow:SetPoint("LEFT", buttons[#buttons], "RIGHT", 6, 0)
    overflow:SetJustifyH("LEFT")
    overflow.shortFormat = true

    local empty = CreateFont(container, 10, COLORS.subdued)
    empty:SetPoint("LEFT", 0, 0)
    empty:SetJustifyH("LEFT")
    empty:SetText("No loot")

    return container, buttons, overflow, empty
end

local function CreateCompactStatRow(parent, portraitSize)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(COMPLETION_ROW_HEIGHT)
    MythicTools:ApplySurface(row, COLORS.rowBG, COLORS.surface, nil)

    row.Portrait = CreatePortraitWidget(row, portraitSize)
    row.Portrait:SetPoint("LEFT", 10, 0)

    row.Name = CreateFont(row, 12, COLORS.text)
    row.Name:SetPoint("LEFT", row.Portrait, "RIGHT", 10, 0)
    row.Name:SetWidth(COMPACT_STATS_PLAYER_WIDTH)
    row.Name:SetJustifyH("LEFT")
    row.PlayerButton = CreatePlayerFilterButton(row, row.Name)

    row.Score = CreateFont(row, 11, COLORS.text)
    row.Score:SetPoint("LEFT", COMPACT_STATS_SCORE_X, 0)
    row.Score:SetWidth(88)

    row.Items, row.LootButtons, row.LootOverflow, row.LootEmpty = CreateCompactLootStrip(row)
    row.Items:SetPoint("LEFT", COMPACT_STATS_ITEMS_X, 0)
    row.LootLabel = nil
    row.LootTextButtons = nil

    row.Damage = CreateFont(row, 12, COLORS.text)
    row.Damage:SetPoint("LEFT", COMPACT_STATS_DAMAGE_X, 0)
    row.Damage:SetWidth(68)

    row.DPS = CreateFont(row, 12, COLORS.text)
    row.DPS:SetPoint("LEFT", COMPACT_STATS_DPS_X, 0)
    row.DPS:SetWidth(58)

    row.Healing = CreateFont(row, 12, COLORS.text)
    row.Healing:SetPoint("LEFT", COMPACT_STATS_HEALING_X, 0)
    row.Healing:SetWidth(68)

    row.Interrupts = CreateFont(row, 12, COLORS.text)
    row.Interrupts:SetPoint("LEFT", COMPACT_STATS_INTERRUPTS_X, 0)
    row.Interrupts:SetWidth(70)

    row.Deaths = CreateFont(row, 12, COLORS.text)
    row.Deaths:SetPoint("LEFT", COMPACT_STATS_DEATHS_X, 0)
    row.Deaths:SetWidth(44)

    return row
end

local function CreateStatRow(parent)
    return CreateCompactStatRow(parent, 28)
end

local function CreateCompletionStatRow(parent)
    return CreateCompactStatRow(parent, 34)
end

local function CreateRecentRunButton(parent)
    return CreateListButton(parent, 54)
end

local function StyleTabButton(button, selected)
    button._selected = selected and true or false
    if selected then
        button:SetBackdropColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.3)
        button:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
        SetTextColor(button.Text, COLORS.bright)
    else
        button:SetBackdropColor(COLORS.rowBG[1], COLORS.rowBG[2], COLORS.rowBG[3], 1)
        button:SetBackdropBorderColor(0, 0, 0, 1)
        SetTextColor(button.Text, COLORS.text)
    end
end

local function StyleListButton(button, selected, accentColor)
    button._selected = selected and true or false
    accentColor = accentColor or COLORS.accentSoft

    if selected then
        MythicTools:ApplySurface(button, COLORS.rowSelected, accentColor, COLORS.accent)
        button.Accent:SetVertexColor(accentColor[1], accentColor[2], accentColor[3], 1)
        SetTextColor(button.Title, COLORS.bright)
    else
        MythicTools:ApplySurface(button, COLORS.rowBG, COLORS.surface, nil)
        button.Accent:SetVertexColor(accentColor[1], accentColor[2], accentColor[3], 0.75)
        SetTextColor(button.Title, COLORS.text)
    end
end

local function CreateSidebarMetric(parent, labelText)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(176, 54)
    MythicTools:ApplySurface(card, COLORS.rowBG, COLORS.surface, nil)

    card.Value = CreateFont(card, 18, COLORS.text)
    card.Value:SetPoint("TOPLEFT", 12, -10)
    card.Value:SetText("0")

    card.Label = CreateFont(card, 10, COLORS.subdued)
    card.Label:SetPoint("TOPLEFT", card.Value, "BOTTOMLEFT", 0, -3)
    card.Label:SetText(labelText)

    return card
end

local function CreateSettingToggle(parent, labelText, descriptionText, onClick)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(42)

    row.Check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.Check:SetPoint("TOPLEFT", 0, -2)
    row.Check:SetScale(0.90)
    row.Check:SetScript("OnClick", function(checkButton)
        if onClick then
            onClick(checkButton:GetChecked())
        end
    end)

    row.Label = CreateFont(row, 12, COLORS.text)
    row.Label:SetPoint("TOPLEFT", row.Check, "TOPRIGHT", 4, -1)
    row.Label:SetText(labelText)

    row.Description = CreateFont(row, 10, COLORS.subdued)
    row.Description:SetPoint("TOPLEFT", row.Label, "BOTTOMLEFT", 0, -2)
    row.Description:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.Description:SetJustifyH("LEFT")
    row.Description:SetText(descriptionText or "")

    return row
end

function MythicTools:GetFilteredRuns()
    local filters = self.db.ui.filters
    local filtered = {}
    local normalizedDate = NormalizeDateFilter(filters.date or "")

    for _, run in ipairs(self.db.runs) do
        local include = true
        local runResult = self:GetRunResult(run)
        if include and filters.season ~= "" and filters.season ~= "all" then
            include = self:GetRunSeason(run) == filters.season
        end
        if include and filters.status ~= "all" then
            include = runResult == filters.status
        end
        if include and filters.ownedCharacters == "mine" then
            include = self:RunHasOwnedCharacter(run)
        elseif include and filters.ownedCharacters ~= "" and filters.ownedCharacters ~= "all" then
            include = self:RunHasCharacter(run, filters.ownedCharacters)
        end
        if include and filters.player ~= "" then
            local foundPlayer = false
            for _, fullName in ipairs(run.roster or {}) do
                if self:ContainsText(fullName, filters.player) or self:ContainsText(self:GetShortName(fullName), filters.player) then
                    foundPlayer = true
                    break
                end
            end
            include = foundPlayer
        end
        if include and filters.dungeon ~= "" and filters.dungeon ~= "all" then
            include = (run.dungeonName or "") == filters.dungeon
        end
        if include and normalizedDate ~= "" then
            include = self:ContainsText(self:FormatDate(run.endTime), normalizedDate)
        end
        if include and filters.search ~= "" then
            local blob = (run.dungeonName or "") .. " " .. tostring(run.level or 0) .. " " .. self:FormatDate(run.endTime) .. " " .. runResult
            for _, fullName in ipairs(run.roster or {}) do
                blob = blob .. " " .. fullName .. " " .. self:GetShortName(fullName)
            end
            include = self:ContainsText(blob, filters.search)
        end
        if include then
            filtered[#filtered + 1] = run
        end
    end

    return filtered
end

function MythicTools:GetFilteredPlayers()
    local filters = self.db.ui.playerFilters or {}
    local needle = filters.search or self.db.ui.playerSearch or ""
    local players = {}

    for _, playerEntry in pairs(self.db.playersIndex) do
        if playerEntry.fullName ~= self.playerName then
            local include = true
            if include and needle ~= "" then
                include = self:ContainsText(playerEntry.fullName, needle) or self:ContainsText(playerEntry.shortName, needle)
            end
            if include and filters.season and filters.season ~= "" and filters.season ~= "all" then
                include = false
                for _, runId in ipairs(playerEntry.runIds or {}) do
                    local run = self:GetRunById(runId)
                    if run and self:GetRunSeason(run) == filters.season then
                        include = true
                        break
                    end
                end
            end
            if include and filters.dungeon and filters.dungeon ~= "" and filters.dungeon ~= "all" then
                include = false
                for _, dungeonEntry in pairs(playerEntry.dungeons or {}) do
                    if dungeonEntry.name == filters.dungeon and (dungeonEntry.totalRuns or 0) > 0 then
                        include = true
                        break
                    end
                end
            end
            if include then
                players[#players + 1] = playerEntry
            end
        end
    end

    local sortState = self.db.ui.playerSort or {column = "runs", direction = "desc"}
    local direction = sortState.direction == "asc" and 1 or -1
    table.sort(players, function(left, right)
        local leftValue
        local rightValue
        if sortState.column == "player" then
            leftValue = left.shortName or left.fullName or ""
            rightValue = right.shortName or right.fullName or ""
            if leftValue ~= rightValue then
                if direction == 1 then
                    return leftValue < rightValue
                end
                return leftValue > rightValue
            end
        else
            local keyMap = {
                runs = "totalRuns",
                success = "successRate",
                timed = "timedRuns",
                overtime = "overtimeRuns",
                abandoned = "abandonedRuns",
                best = "bestTimedLevel",
                average = "averageLevel",
                maxdps = "maxDps",
                avgdps = "averageDps",
            }
            local key = keyMap[sortState.column] or "totalRuns"
            leftValue = tonumber(left[key]) or 0
            rightValue = tonumber(right[key]) or 0
            if leftValue ~= rightValue then
                if direction == 1 then
                    return leftValue < rightValue
                end
                return leftValue > rightValue
            end
        end

        if (left.successRate or 0) ~= (right.successRate or 0) then
            return (left.successRate or 0) > (right.successRate or 0)
        end

        return (left.shortName or left.fullName or "") < (right.shortName or right.fullName or "")
    end)

    return players
end

function MythicTools:GetSortedStatsForRun(run)
    local stats = {}
    for _, fullName in ipairs(run.roster or {}) do
        local entry = run.playerStats and run.playerStats[fullName]
        if entry then
            stats[#stats + 1] = entry
        end
    end

    table.sort(stats, function(left, right)
        local leftDamage, rightDamage = left.damage or -1, right.damage or -1
        if leftDamage ~= rightDamage then return leftDamage > rightDamage end
        local leftHealing, rightHealing = left.healing or -1, right.healing or -1
        if leftHealing ~= rightHealing then return leftHealing > rightHealing end
        local leftInterrupts, rightInterrupts = left.interrupts or -1, right.interrupts or -1
        if leftInterrupts ~= rightInterrupts then return leftInterrupts > rightInterrupts end
        return (left.name or "") < (right.name or "")
    end)

    return stats
end

function MythicTools:GetRunLootCount(run)
    local count = 0
    for _, stat in pairs(run and run.playerStats or {}) do
        count = count + #(stat.loot or {})
    end
    return count
end


local function FormatKeyLevel(level)
    level = tonumber(level) or 0
    if level <= 0 then
        return "--"
    end
    return ("+%d"):format(level)
end

local function GetRunUpgradeText(run)
    if not run or MythicTools:GetRunResult(run) == "abandoned" then
        return ""
    end

    local upgradeLevels = tonumber(run.keystoneUpgradeLevels) or 0
    if upgradeLevels <= 0 then
        return ""
    end

    return ("+%d"):format(upgradeLevels)
end

local function FormatScoreNumber(score)
    score = tonumber(score)
    if not score then
        return ""
    end

    if math.abs(score - math.floor(score + 0.5)) < 0.05 then
        return tostring(math.floor(score + 0.5))
    end

    return ("%.1f"):format(score)
end

local function FormatScoreWithDelta(currentScore, previousScore)
    local current = tonumber(currentScore) or 0
    if current <= 0 then
        return ""
    end

    local text = FormatScoreNumber(current)
    local previous = tonumber(previousScore)
    if not previous or previous <= 0 then
        return text
    end

    local delta = current - previous
    if math.abs(delta) < 0.05 then
        return text
    end

    return ("%s(%s%s)"):format(text, delta > 0 and "+" or "", FormatScoreNumber(delta))
end

local function GetRunScoreText(run)
    local scoreText = FormatScoreWithDelta(run and run.newOverallDungeonScore, run and run.oldOverallDungeonScore)
    if scoreText ~= "" then
        return ("Score %s"):format(scoreText)
    end

    return ""
end

local function GetPlayerScoreDisplayText(stat)
    local score = tonumber(stat and stat.score) or 0
    if score > 0 then
        return FormatScoreWithDelta(score, stat and stat.previousScore)
    end

    local previousScore = tonumber(stat and stat.previousScore) or 0
    if previousScore > 0 then
        return FormatScoreNumber(previousScore)
    end

    return ""
end

local function GetPlayerScoreColor(stat)
    local score = tonumber(stat and stat.score) or tonumber(stat and stat.previousScore) or 0
    if score <= 0 or not C_ChallengeMode or not C_ChallengeMode.GetDungeonScoreRarityColor then
        return COLORS.text
    end

    local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
    if color then
        return {color.r or 1, color.g or 1, color.b or 1, color.a or 1}
    end

    return COLORS.text
end

local function GetRunOutOfCombatText(run)
    local outOfCombatSeconds = tonumber(run and run.outOfCombatSeconds) or 0
    if outOfCombatSeconds <= 0 then
        return ""
    end

    return ("Out of combat %s"):format(MythicTools:FormatDurationSeconds(outOfCombatSeconds))
end

local function GetRunStatsSourceText(run)
    local source = run and run.statsSource or nil

    if source == "details" then
        return "Stats Details!"
    end
    if source == "details_hybrid" then
        return "Stats Details! + Blizzard"
    end
    if source == "details_partial" then
        return "Stats Details! totals"
    end
    if source == "damage_meter" then
        return ""
    end
    if run and run.statsUnavailable then
        return "Stats unavailable"
    end

    return "Stats pending"
end

local function PlayerTableCellUpdate(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table)
    if not fShow then
        cellFrame:Hide()
        return
    end

    local rowData = table:GetRow(realrow)
    local cellData = table:GetCell(rowData, column)
    local displayValue = ""
    local color = COLORS.text

    if type(cellData) == "table" then
        displayValue = cellData.display or cellData.value or ""
        color = cellData.color or COLORS.text
    else
        displayValue = cellData or ""
    end

    cellFrame.text:SetText(displayValue)
    cellFrame.text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    cellFrame:Show()
end

function MythicTools:BuildPlayerAnalyticsTableData(players)
    local rows = {}

    for _, playerEntry in ipairs(players or {}) do
        local iconMarkup = GetClassIconMarkup(playerEntry.classFilename, playerEntry.specIconID)
        rows[#rows + 1] = {
            playerName = playerEntry.fullName,
            cols = {
                {value = playerEntry.shortName or playerEntry.fullName or "", display = iconMarkup},
                {value = playerEntry.shortName or playerEntry.fullName or "", display = playerEntry.shortName or playerEntry.fullName or "", color = COLORS.text},
                {value = playerEntry.totalRuns or 0, display = tostring(playerEntry.totalRuns or 0)},
                {value = playerEntry.successRate or 0, display = string.format("%.1f%%", playerEntry.successRate or 0)},
                {value = playerEntry.timedRuns or 0, display = tostring(playerEntry.timedRuns or 0), color = COLORS.success},
                {value = playerEntry.overtimeRuns or 0, display = tostring(playerEntry.overtimeRuns or 0), color = COLORS.accentSoft},
                {value = playerEntry.abandonedRuns or 0, display = tostring(playerEntry.abandonedRuns or 0), color = COLORS.danger},
                {value = playerEntry.bestTimedLevel or 0, display = tostring(playerEntry.bestTimedLevel or 0)},
                {value = playerEntry.averageLevel or 0, display = string.format("%.1f", playerEntry.averageLevel or 0)},
                {value = playerEntry.maxDps or 0, display = self:FormatAmount(playerEntry.maxDps or 0)},
                {value = playerEntry.averageDps or 0, display = self:FormatAmount(playerEntry.averageDps or 0)},
            }
        }
    end

    return rows
end

function MythicTools:CreatePlayersAnalyticsTable(parent)
    if not ScrollingTable then
        return nil
    end

    local columns = {
        {name = "", width = 30, sort = nil, DoCellUpdate = PlayerTableCellUpdate},
        {name = "Player", width = 160, DoCellUpdate = PlayerTableCellUpdate},
        {name = "Runs", width = 52, defaultsort = ScrollingTable.SORT_DSC, DoCellUpdate = PlayerTableCellUpdate},
        {name = "Success", width = 74, DoCellUpdate = PlayerTableCellUpdate},
        {name = "Timed", width = 52, DoCellUpdate = PlayerTableCellUpdate},
        {name = "Overtime", width = 66, DoCellUpdate = PlayerTableCellUpdate},
        {name = "Abandoned", width = 78, DoCellUpdate = PlayerTableCellUpdate},
        {name = "Best", width = 48, DoCellUpdate = PlayerTableCellUpdate},
        {name = "Average", width = 58, DoCellUpdate = PlayerTableCellUpdate},
        {name = "Max DPS", width = 82, DoCellUpdate = PlayerTableCellUpdate},
        {name = "Avg DPS", width = 82, DoCellUpdate = PlayerTableCellUpdate},
    }

    local windowHeight = (MythicTools.db and MythicTools.db.ui and MythicTools.db.ui.height) or 760
    local numRows = max(10, floor((windowHeight - 234) / PLAYER_TABLE_ROW_HEIGHT))
    local tableWidget = ScrollingTable:CreateST(columns, numRows, PLAYER_TABLE_ROW_HEIGHT, nil, parent)
    tableWidget.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -46)
    tableWidget.frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -46)
    tableWidget.frame:SetBackdropColor(COLORS.panelBG[1], COLORS.panelBG[2], COLORS.panelBG[3], 0)
    tableWidget.frame:SetBackdropBorderColor(0, 0, 0, 0)
    tableWidget:EnableSelection(true)

    local sortColumns = {
        [1] = "player",
        [2] = "player",
        [3] = "runs",
        [4] = "success",
        [5] = "timed",
        [6] = "overtime",
        [7] = "abandoned",
        [8] = "best",
        [9] = "average",
        [10] = "maxdps",
        [11] = "avgdps",
    }

    tableWidget:RegisterEvents({
        OnClick = function(_, _, data, _, row, realrow, column, scrollingTable, mouseButton)
            if row and realrow then
                local rowData = data and data[realrow]
                if rowData and rowData.playerName then
                    if mouseButton == "RightButton" then
                        MythicTools:ShowPlayerContextMenu(rowData.playerName)
                    else
                        MythicTools:OpenPlayerHistory(rowData.playerName)
                    end
                end
                return true
            end

            if mouseButton == "RightButton" then
                return false
            end

            C_Timer.After(0, function()
                local sortColumn = sortColumns[column]
                local sortDirection = "desc"
                if scrollingTable and scrollingTable.cols and scrollingTable.cols[column] and scrollingTable.cols[column].sort == ScrollingTable.SORT_ASC then
                    sortDirection = "asc"
                end
                MythicTools.db.ui.playerSort = {
                    column = sortColumn or "runs",
                    direction = sortDirection,
                }
            end)

            return false
        end,
    }, true)

    return tableWidget
end

function MythicTools:ApplyPlayersTableSortState()
    if not (self.ui and self.ui.playersTable and self.ui.playersTable.cols and ScrollingTable) then
        return
    end

    local sortState = self.db.ui.playerSort or {column = "runs", direction = "desc"}
    local columnIndexByKey = {
        player = 2,
        runs = 3,
        success = 4,
        timed = 5,
        overtime = 6,
        abandoned = 7,
        best = 8,
        average = 9,
        maxdps = 10,
        avgdps = 11,
    }
    local selectedIndex = columnIndexByKey[sortState.column] or 3

    for index, column in ipairs(self.ui.playersTable.cols) do
        if index == selectedIndex then
            column.sort = sortState.direction == "asc" and ScrollingTable.SORT_ASC or ScrollingTable.SORT_DSC
        else
            column.sort = nil
        end
    end
end

function MythicTools:GetSelectedPlayerEntry()
    local selectedPlayer = self.db and self.db.ui and self.db.ui.selectedPlayer
    if not selectedPlayer then
        return nil
    end

    return self.db.playersIndex and self.db.playersIndex[selectedPlayer] or nil
end

function MythicTools:GetPlayerRecentRuns(fullName, limit)
    local runs = self:GetRunsForPlayer(fullName)
    table.sort(runs, function(left, right)
        return (left.endTime or 0) > (right.endTime or 0)
    end)

    if limit and #runs > limit then
        local trimmed = {}
        for index = 1, limit do
            trimmed[index] = runs[index]
        end
        return trimmed
    end

    return runs
end

function MythicTools:GetVisiblePlayerDetailHistoryRows()
    local historyBody = self.ui and self.ui.playerDetailHistoryBody
    local availableHeight = historyBody and historyBody:GetHeight() or 0
    if availableHeight <= 0 then
        return PLAYER_DETAIL_HISTORY_ROWS
    end

    return max(1, min(PLAYER_DETAIL_HISTORY_MAX_ROWS, floor((availableHeight + 2) / PLAYER_DETAIL_HISTORY_ROW_HEIGHT)))
end

function MythicTools:GetSortedBreakdownEntries(breakdown)
    local rows = {}
    for _, entry in pairs(breakdown or {}) do
        rows[#rows + 1] = entry
    end

    table.sort(rows, function(left, right)
        if (left.totalRuns or 0) ~= (right.totalRuns or 0) then
            return (left.totalRuns or 0) > (right.totalRuns or 0)
        end
        if (left.bestTimedLevel or 0) ~= (right.bestTimedLevel or 0) then
            return (left.bestTimedLevel or 0) > (right.bestTimedLevel or 0)
        end
        return (left.label or "") < (right.label or "")
    end)

    return rows
end

function MythicTools:SetMetricCardValue(card, value, meta, color)
    if not card then
        return
    end

    card.Value:SetText(value or "--")
    if color then
        SetTextColor(card.Value, color)
    else
        SetTextColor(card.Value, COLORS.text)
    end

    if meta and meta ~= "" then
        card.Meta:SetText(meta)
        card.Meta:Show()
    else
        card.Meta:SetText("")
        card.Meta:Hide()
    end
end

function MythicTools:GetDungeonFilterLabel(value)
    local options = GetDungeonOptionsForSeason((self.db.ui.filters and self.db.ui.filters.season) or SEASON_OPTIONS[1].value)
    for _, info in ipairs(options) do
        if info.value == value then
            return info.label
        end
    end
    return options[1] and options[1].label or "All dungeons"
end

function MythicTools:GetNextDungeonFilterValue(currentValue)
    local options = GetDungeonOptionsForSeason((self.db.ui.filters and self.db.ui.filters.season) or SEASON_OPTIONS[1].value)
    for index, info in ipairs(options) do
        if info.value == currentValue then
            local nextInfo = options[index + 1] or options[1]
            return nextInfo.value
        end
    end
    return options[1] and options[1].value or "all"
end

function MythicTools:SetRunViewMode(mode)
    self.db.ui.runViewMode = mode == "detail" and "detail" or "list"
end

function MythicTools:OpenRunDetails(runId)
    if not runId then
        return
    end

    self.db.ui.selectedRunId = runId
    self:SetRunViewMode("detail")
    if self.ui then
        self:RefreshRunView()
    end
end
function MythicTools:StoreMainFramePoint()
    if not (self.ui and self.ui.frame) then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = self.ui.frame:GetPoint(1)
    self.db.ui.point = {point or "CENTER", relativePoint or point or "CENTER", xOfs or 0, yOfs or 0}
end

function MythicTools:SetPortraitWidget(widget, fullName, classFilename, specIconID)
    if not widget then
        return
    end

    local texture = widget.Texture
    local usedPortrait = false
    local unit = self.GetGroupUnitForPlayer and self:GetGroupUnitForPlayer(fullName) or nil
    if unit and texture then
        texture:SetTexture(nil)
        SetPortraitTexture(texture, unit)
        if texture:GetTexture() then
            texture:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
            usedPortrait = true
        end
    end

    if not usedPortrait and texture then
        if specIconID then
            texture:SetTexture(specIconID)
            texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            local coords = classFilename and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFilename]
            if coords then
                texture:SetTexture(CLASS_CIRCLE_TEXTURE)
                texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            else
                texture:SetTexture(QUESTION_MARK_ICON)
                texture:SetTexCoord(0, 1, 0, 1)
            end
        end
    end

    if usedPortrait and specIconID then
        widget.SpecIcon:SetTexture(specIconID)
        widget.SpecIcon:Show()
    else
        widget.SpecIcon:Hide()
    end
end

function MythicTools:SetRoleBadge(badge, role)
    if not badge then
        return
    end

    local normalizedRole = self:NormalizeRole(role)
    if not normalizedRole then
        badge:Hide()
        return
    end

    local atlasByRole = {
        TANK = "roleicon-tiny-tank",
        HEALER = "roleicon-tiny-healer",
        DAMAGER = "roleicon-tiny-dps",
    }

    badge.Icon:SetTexture(nil)
    badge.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    badge.Label:Hide()

    local atlas = atlasByRole[normalizedRole]
    if atlas and badge.Icon.SetAtlas and pcall(badge.Icon.SetAtlas, badge.Icon, atlas, true) then
        badge:Show()
        return
    end

    if GetTexCoordsForRoleSmall then
        local left, right, top, bottom = GetTexCoordsForRoleSmall(normalizedRole)
        badge.Icon:SetAtlas(nil)
        badge.Icon:SetTexture(ROLE_ICON_TEXTURE)
        badge.Icon:SetTexCoord(left, right, top, bottom)
        badge:Show()
        return
    end

    badge.Icon:SetAtlas(nil)
    badge.Icon:SetTexture(nil)
    badge.Label:SetText(normalizedRole == "HEALER" and "H" or (normalizedRole == "TANK" and "T" or "D"))
    badge.Label:Show()
    badge:Show()
end

function MythicTools:HandleItemInfoReceived(_, success)
    if success == false then
        return
    end

    local mainShown = self.ui and self.ui.frame and self.ui.frame:IsShown()
    local popupShown = self.completionPopup and self.completionPopup:IsShown()
    if mainShown or popupShown then
        self:RefreshAllViews()
    end
end

function MythicTools:SetRunArt(iconWidget, backgroundWidget, run)
    local icon = GetDungeonIcon(run)
    if iconWidget then
        iconWidget:SetTexture(icon or DEFAULT_DUNGEON_ICON)
        iconWidget:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    if backgroundWidget then
        local bg = GetDungeonBackground(run)
        backgroundWidget:SetTexture(bg or DEFAULT_DUNGEON_BG)
        backgroundWidget:SetTexCoord(0, 1, 0, 1)
    end
end

function MythicTools:ResetLootButtons(buttons, lootLabel, overflowLabel, emptyLabel, textButtons)
    if type(buttons) == "table" then
        for _, button in ipairs(buttons) do
            button.itemLink = nil
            button.itemLevel = nil
            button:SetScript("OnUpdate", nil)
            button.Icon:SetTexture(QUESTION_MARK_ICON)
            button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            if button.ItemLevel then
                button.ItemLevel:SetText("")
            end
            self:ApplySurface(button, COLORS.frameBG, COLORS.surface, nil)
            button:Hide()
        end
    end

    if type(textButtons) == "table" then
        for _, button in ipairs(textButtons) do
            button.itemLink = nil
            button.Text:SetText("")
            button.Text:Show()
            button:Hide()
        end
    end

    if lootLabel and (type(textButtons) ~= "table" or #textButtons == 0) then
        lootLabel:SetText("")
        lootLabel:Hide()
    end

    if overflowLabel then
        overflowLabel:SetText("")
        overflowLabel:Hide()
    end

    if emptyLabel then
        emptyLabel:Show()
    end
end

function MythicTools:SetLootButtons(buttons, lootLabel, overflowLabel, emptyLabel, lootLinks, textButtons)
    self:ResetLootButtons(buttons, lootLabel, overflowLabel, emptyLabel, textButtons)

    if self.db and self.db.settings and self.db.settings.showLootHistory == false then
        if emptyLabel then
            emptyLabel:SetText("Loot hidden")
            emptyLabel:Show()
        end
        return
    end

    if type(lootLinks) ~= "table" or #lootLinks == 0 then
        return
    end

    if emptyLabel then
        emptyLabel:SetText("No loot")
        emptyLabel:Hide()
    end

    local visibleCount = min(#(buttons or {}), #lootLinks)
    for index = 1, visibleCount do
        local button = buttons[index]
        local textButton = textButtons and textButtons[index]
        local itemLink = NormalizeDisplayItemLink(lootLinks[index])
        if button and itemLink then
            local displayName = GetItemNameFallback(itemLink)
            if displayName == "" then
                displayName = "Unknown item"
            end

            button.itemLink = itemLink
            if textButton then
                textButton.itemLink = itemLink
            end

            local itemID = GetItemIDFromLinkish(itemLink)
            local icon = C_Item and C_Item.GetItemInfoInstant and select(5, C_Item.GetItemInfoInstant(itemLink)) or nil
            if (not icon or icon == 0) and itemID and C_Item and C_Item.GetItemIconByID then
                icon = C_Item.GetItemIconByID(itemID)
            end
            local itemLevel = GetItemLevelForLink(itemLink)
            button.Icon:SetTexture(icon or QUESTION_MARK_ICON)
            button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            button.itemLevel = itemLevel
            if button.ItemLevel then
                button.ItemLevel:SetText(FormatItemLevelText(itemLevel))
            end
            button:Show()

            local qualityColor = GetItemQualityColorByLink(itemLink) or COLORS.muted

            if textButton then
                textButton.Text:SetText(displayName)
                textButton.Text:Show()
                SetTextColor(textButton.Text, qualityColor)
                textButton:Show()
            elseif index == 1 and lootLabel then
                lootLabel:SetText(displayName)
                SetTextColor(lootLabel, qualityColor)
                lootLabel:Show()
            end

            if Item and Item.CreateFromItemLink then
                local item = Item:CreateFromItemLink(itemLink)
                item:ContinueOnItemLoad(function()
                    if button.itemLink ~= itemLink then
                        return
                    end

                    local quality = item.GetItemQuality and item:GetItemQuality() or nil
                    local loadedIcon = item.GetItemIcon and item:GetItemIcon() or icon
                    button.Icon:SetTexture(loadedIcon or QUESTION_MARK_ICON)
                    if button.ItemLevel then
                        local loadedItemLevel = (item.GetCurrentItemLevel and item:GetCurrentItemLevel()) or GetItemLevelForLink(itemLink)
                        button.itemLevel = tonumber(loadedItemLevel) or button.itemLevel
                        button.ItemLevel:SetText(FormatItemLevelText(button.itemLevel))
                    end

                    local targetText = textButton and textButton.Text or lootLabel
                    if targetText then
                        targetText:SetText(item.GetItemName and item:GetItemName() or displayName)
                        targetText:Show()
                    end

                    local border = COLORS.surface
                    if quality and C_Item.GetItemQualityColor then
                        local r, g, b = C_Item.GetItemQualityColor(quality)
                        border = {r, g, b, 1}
                        if targetText then
                            SetTextColor(targetText, border)
                        end
                    else
                        if targetText then
                            SetTextColor(targetText, COLORS.muted)
                        end
                    end
                    MythicTools:ApplySurface(button, COLORS.frameBG, border, nil)

                end)
            end
        end
    end

    if overflowLabel and #lootLinks > visibleCount then
        if overflowLabel.shortFormat then
            overflowLabel:SetText(("+%d"):format(#lootLinks - visibleCount))
        else
            overflowLabel:SetText(("+%d more item%s"):format(#lootLinks - visibleCount, (#lootLinks - visibleCount) == 1 and "" or "s"))
        end
        overflowLabel:Show()
    end
end

function MythicTools:GetCompletionPopupDelay()
    return self:Clamp(self.db.settings.completionPopupDelay or 0, 0, 10)
end

function MythicTools:GetCompletionPopupScale()
    return self:Clamp(self.db.settings.completionPopupScale or 1, 0.7, 1.4)
end

function MythicTools:ApplyCompletionPopupScale()
    if self.completionPopup then
        self.completionPopup:SetScale(self:GetCompletionPopupScale())
    end
end

function MythicTools:QueueCompletionPopup(runId, reason)
    if not runId or not (self.db and self.db.settings) then
        return
    end

    if self.db.settings.showCompletionPopup == false then
        if self.PushRuntimeDebug then
            self:PushRuntimeDebug(("skip completion popup run %s reason=%s popup disabled"):format(tostring(runId), tostring(reason)))
        end
        return
    end

    local trigger = self.db.settings.completionPopupTrigger or "COMPLETED"
    local delay = self:GetCompletionPopupDelay()
    if self.PushRuntimeDebug then
        self:PushRuntimeDebug(("queue completion popup run %s trigger=%s reason=%s delay=%s"):format(
            tostring(runId),
            tostring(trigger),
            tostring(reason),
            tostring(delay)
        ))
    end

    if trigger == reason then
        self.runtime.pendingCompletionPopup = nil
        local function OpenPopupNow()
            if MythicTools.db and MythicTools.db.settings.showCompletionPopup ~= false then
                local ok, err = pcall(MythicTools.ShowCompletionPopup, MythicTools, runId)
                if not ok and MythicTools.StoreDebugReport then
                    MythicTools:StoreDebugReport("popup_show_error", {
                        trigger = reason,
                        runId = runId,
                        error = tostring(err),
                    })
                end
            end
        end

        if delay <= 0 then
            OpenPopupNow()
        else
            self:Schedule(delay, OpenPopupNow)
        end
    else
        self.runtime.pendingCompletionPopup = {runId = runId}
        if self.PushRuntimeDebug then
            self:PushRuntimeDebug(("store pending completion popup run %s waiting for %s"):format(tostring(runId), tostring(trigger)))
        end
    end
end

function MythicTools:ResolvePendingCompletionPopup(reason)
    if not (self.runtime and self.runtime.pendingCompletionPopup) then
        return
    end

    local trigger = self.db.settings.completionPopupTrigger or "COMPLETED"
    if trigger ~= reason then
        return
    end

    local pending = self.runtime.pendingCompletionPopup
    self.runtime.pendingCompletionPopup = nil
    local delay = self:GetCompletionPopupDelay()
    if self.PushRuntimeDebug then
        self:PushRuntimeDebug(("resolve pending completion popup run %s reason=%s delay=%s"):format(
            tostring(pending.runId),
            tostring(reason),
            tostring(delay)
        ))
    end

    local function OpenPopupNow()
        if MythicTools.db and MythicTools.db.settings.showCompletionPopup ~= false then
            local ok, err = pcall(MythicTools.ShowCompletionPopup, MythicTools, pending.runId)
            if not ok and MythicTools.StoreDebugReport then
                MythicTools:StoreDebugReport("popup_show_error", {
                    trigger = reason,
                    runId = pending.runId,
                    error = tostring(err),
                })
            end
        end
    end

    if delay <= 0 then
        OpenPopupNow()
    else
        self:Schedule(delay, OpenPopupNow)
    end
end

function MythicTools:BuildTestRun()
    local now = time()
    local roster = {
        "Arkanis-Azralon",
        "Lumera-Stormrage",
        "Kaorth-Illidan",
        "Brielle-Sargeras",
        "Torvak-Ragnaros",
    }

    local playerStats = {
        [roster[1]] = {name = roster[1], shortName = "Arkanis", classFilename = "MAGE", damage = 20450000, healing = 310000, interrupts = 4, deaths = 0, loot = {"|cff0070dd|Hitem:19019::::::::80:::::|h[Thunderfury Test]|h|r"}},
        [roster[2]] = {name = roster[2], shortName = "Lumera", classFilename = "PRIEST", damage = 5810000, healing = 15880000, interrupts = 1, deaths = 1, loot = {"|cff1eff00|Hitem:17182::::::::80:::::|h[Sulfuras Cloak Test]|h|r"}},
        [roster[3]] = {name = roster[3], shortName = "Kaorth", classFilename = "WARRIOR", damage = 16800000, healing = 0, interrupts = 8, deaths = 0, loot = {}},
        [roster[4]] = {name = roster[4], shortName = "Brielle", classFilename = "DRUID", damage = 12150000, healing = 4320000, interrupts = 2, deaths = 2, loot = {"|cffa335ee|Hitem:18803::::::::80:::::|h[Finkle's Lava Dredger Test]|h|r", "|cff0070dd|Hitem:19362::::::::80:::::|h[Doom's Edge Test]|h|r"}},
        [roster[5]] = {name = roster[5], shortName = "Torvak", classFilename = "PALADIN", damage = 10900000, healing = 2140000, interrupts = 3, deaths = 0, loot = {"|cffa335ee|Hitem:19364::::::::80:::::|h[Ashkandi Test]|h|r"}},
    }

    return {
        runId = -1,
        preview = true,
        startTime = now - 1600,
        endTime = now,
        mapChallengeModeID = 1,
        mapID = 1,
        dungeonName = "Preview Dungeon",
        level = 12,
        timeMS = 1423000,
        onTime = true,
        keystoneUpgradeLevels = 2,
        practiceRun = false,
        timeLimitSeconds = 1560,
        totalDeaths = 3,
        deathPenaltySeconds = 15,
        roster = roster,
        playerStats = playerStats,
        statsUnavailable = false,
        statsNote = "Layout preview: tooltip, loot, and portraits.",
        textureFileID = DEFAULT_DUNGEON_ICON,
        backgroundTextureFileID = DEFAULT_DUNGEON_BG,
    }
end

function MythicTools:ShowTestCompletionPopup()
    self:ShowCompletionPopup(self:BuildTestRun())
end

function MythicTools:ShowTab(tabName)
    self:BuildUI()
    self.db.ui.activeTab = tabName
    for name, page in pairs(self.ui.pages) do
        page:SetShown(name == tabName)
    end
    for name, button in pairs(self.ui.tabButtons) do
        StyleTabButton(button, name == tabName)
    end
    self:RefreshUI()
end

function MythicTools:ToggleMainFrame(forceShow)
    self:BuildUI()
    if forceShow or not self.ui.frame:IsShown() then
        self.ui.frame:Show()
        self:ShowTab(self.db.ui.activeTab or "Runs")
    else
        self:HideCompletionPopup()
        self.ui.frame:Hide()
    end
end

function MythicTools:ShowPlayersIndex()
    self.db.ui.playersView = "index"
    self.db.ui.selectedPlayer = nil
    self:BuildUI()
    self:ToggleMainFrame(true)
    self:ShowTab("Players")
end

function MythicTools:FocusSelectedPlayerNoteEditor()
    if not (self.ui and self.ui.playerDetailNoteEditor and self.ui.playerDetailNoteEditor.EditBox) then
        return
    end

    local editBox = self.ui.playerDetailNoteEditor.EditBox
    editBox:SetFocus()
    editBox:SetCursorPosition(strlen(editBox:GetText() or ""))
end

function MythicTools:OpenPlayerHistory(playerName, focusNote)
    playerName = self:NormalizePlayerName(playerName) or self:TrimText(playerName)
    if not playerName or playerName == "" then
        return
    end

    self.db.ui.selectedPlayer = playerName
    self.db.ui.playersView = "detail"
    self:BuildUI()
    self:ToggleMainFrame(true)
    self:ShowTab("Players")

    if focusNote then
        self.runtime = self.runtime or {}
        self.runtime.pendingNoteFocusPlayer = playerName
        C_Timer.After(0, function()
            if MythicTools.db and MythicTools.db.ui and MythicTools.db.ui.selectedPlayer == playerName then
                MythicTools:FocusSelectedPlayerNoteEditor()
            end
        end)
    end
end

function MythicTools:EditPlayerNote(playerName)
    self:OpenPlayerHistory(playerName, true)
end

function MythicTools:ShowPlayerContextMenu(playerName)
    playerName = self:NormalizePlayerName(playerName) or self:TrimText(playerName)
    if not playerName or playerName == "" then
        return
    end

    local shortName = self:GetShortName(playerName)
    local menu = {
        {
            text = shortName,
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "View player history",
            notCheckable = true,
            func = function()
                MythicTools:OpenPlayerHistory(playerName)
            end,
        },
        {
            text = "Edit note",
            notCheckable = true,
            func = function()
                MythicTools:EditPlayerNote(playerName)
            end,
        },
    }

    self.playerContextMenuFrame = self.playerContextMenuFrame or CreateFrame("Frame", "MythicToolsPlayerContextMenu", UIParent, "UIDropDownMenuTemplate")
    self.playerContextMenuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    EasyMenu(menu, self.playerContextMenuFrame, "cursor", 0, 0, "MENU")
end

function MythicTools:SaveSelectedPlayerNote()
    local playerName = self.db and self.db.ui and self.db.ui.selectedPlayer
    if not (playerName and self.ui and self.ui.playerDetailNoteEditor and self.ui.playerDetailNoteEditor.EditBox) then
        return
    end

    self:SetPlayerNote(playerName, self.ui.playerDetailNoteEditor.EditBox:GetText() or "")
    if self.ui.playerDetailNoteStatus then
        self.ui.playerDetailNoteStatus:SetText("Saved to your account history.")
    end

    local playerEntry = self:GetSelectedPlayerEntry()
    if playerEntry then
        self:RefreshPlayerDetailView(playerEntry)
    end
end

function MythicTools:GetPlayerNameFromMenuContext(contextData)
    if not contextData then
        return nil
    end

    local unit = contextData.unit
    if unit and UnitExists and UnitExists(unit) then
        return self:GetUnitFullName(unit)
    end

    local accountInfo = contextData.accountInfo
    if accountInfo and accountInfo.gameAccountInfo then
        local gameAccountInfo = accountInfo.gameAccountInfo
        return self:NormalizePlayerName(gameAccountInfo.characterName, gameAccountInfo.realmName)
    end

    if contextData.name then
        return self:NormalizePlayerName(contextData.name, contextData.server)
    end

    return nil
end

function MythicTools:GetUnitMenuSummaryText(playerName)
    local playerEntry = self.db and self.db.playersIndex and self.db.playersIndex[playerName]
    if not playerEntry then
        return nil
    end

    return ("%d of %d timed"):format(playerEntry.timedRuns or 0, playerEntry.totalRuns or 0)
end

function MythicTools:HandleUnitPopupMenu(owner, rootDescription, contextData)
    local playerName = self:GetPlayerNameFromMenuContext(contextData)
    if not playerName or not self:HasPlayerHistory(playerName) then
        return
    end

    local summaryText = self:GetUnitMenuSummaryText(playerName)
    if not summaryText then
        return
    end

    rootDescription:CreateDivider()
    rootDescription:CreateTitle("Sky Mythic History")
    rootDescription:CreateButton(summaryText, function()
        MythicTools:OpenPlayerHistory(playerName)
    end)
end

function MythicTools:InitializeUnitPopupMenu()
    if self.unitPopupMenuInitialized then
        return
    end

    local modifyMenu = Menu and Menu.ModifyMenu
    if not modifyMenu then
        return
    end

    local supportedMenus = {
        "MENU_UNIT_PARTY",
        "MENU_UNIT_PLAYER",
        "MENU_UNIT_RAID",
        "MENU_UNIT_RAID_PLAYER",
        "MENU_UNIT_TARGET",
        "MENU_UNIT_FOCUS",
        "MENU_UNIT_SELF",
        "MENU_UNIT_FRIEND",
        "MENU_UNIT_GUILD",
        "MENU_UNIT_GUILD_OFFLINE",
    }

    for _, tag in ipairs(supportedMenus) do
        modifyMenu(tag, function(owner, rootDescription, contextData)
            MythicTools:HandleUnitPopupMenu(owner, rootDescription, contextData)
        end)
    end

    self.unitPopupMenuInitialized = true
end
function MythicTools:RefreshUI()
    if not self.ui then
        return
    end

    if self.ui.sidebarRuns then
        self.ui.sidebarRuns.Value:SetText(tostring(#(self.db.runs or {})))
    end
    if self.ui.sidebarPlayers then
        self.ui.sidebarPlayers.Value:SetText(tostring(self:GetPlayerCount()))
    end
    if self.ui.sidebarStatus then
        if self.runtime and self.runtime.activeRun then
            self.ui.sidebarStatus.Value:SetText(("+%d"):format(self.runtime.activeRun.keyLevel or 0))
            self.ui.sidebarStatus.Label:SetText(self.runtime.activeRun.dungeonName or "Active run")
        else
            self.ui.sidebarStatus.Value:SetText("--")
            self.ui.sidebarStatus.Label:SetText("No active run")
        end
    end

    self:RefreshOwnedCharacterFilterOptions()
    self:RefreshRunView()
    self:RefreshPlayersView()
    self:RefreshSettingsView()
    self:RefreshStatsView()
end

function MythicTools:RefreshRunView()
    if not self.ui then
        return
    end

    local runs = self:GetFilteredRuns()
    self.ui.filteredRuns = runs
    self.ui.runCountLabel:SetText(("%d runs"):format(#runs))

    local hasVisibleSelection = false
    for _, run in ipairs(runs) do
        if run.runId == self.db.ui.selectedRunId then
            hasVisibleSelection = true
            break
        end
    end
    if not hasVisibleSelection then
        self.db.ui.selectedRunId = runs[1] and runs[1].runId or nil
    end

    local showDetail = false
    if self.ui.runsFilterBar then
        self.ui.runsFilterBar:SetShown(not showDetail)
    end
    if self.ui.runsListView then
        self.ui.runsListView:SetShown(not showDetail)
    end
    if self.ui.runsDetailView then
        self.ui.runsDetailView:SetShown(showDetail)
    end

    FauxScrollFrame_Update(self.ui.runsScroll, #runs, RUN_ROWS, RUN_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(self.ui.runsScroll)

    for rowIndex = 1, RUN_ROWS do
        local row = self.ui.runRows[rowIndex]
        local run = runs[offset + rowIndex]
        if run then
            local upgradeText = GetRunUpgradeText(run)
            local scoreText = GetRunScoreText(run)
            local subtitle = ("%s  |  %d players  |  %d item%s"):format(
                self:FormatDate(run.endTime),
                self:GetRunPlayerCount(run),
                self:GetRunLootCount(run),
                self:GetRunLootCount(run) == 1 and "" or "s"
            )
            if upgradeText ~= "" then
                subtitle = subtitle .. ("  |  Upgrade %s"):format(upgradeText)
            end
            if scoreText ~= "" then
                subtitle = subtitle .. ("  |  %s"):format(scoreText)
            end
            row:Show()
            row.runId = run.runId
            self:SetRunArt(row.Icon, nil, run)
            row.Title:SetText(("%s +%d"):format(run.dungeonName or "Unknown", run.level or 0))
            row.Subtitle:SetText(subtitle)
            row.RightTop:SetText(GetRunStatusText(run))
            row.RightBottom:SetText(self:FormatDurationMS(run.timeMS))
            StyleListButton(row, run.runId == self.db.ui.selectedRunId, GetRunStatusColor(run))
        else
            row:Hide()
            row.runId = nil
        end
    end

    if self.ui.runsEmptyState then
        self.ui.runsEmptyState:SetShown(#runs == 0)
    end
end
function MythicTools:RefreshPlayersView()
    if not self.ui then
        return
    end

    local players = self:GetFilteredPlayers()
    self.ui.filteredPlayers = players
    if self.ui.playerCountLabel then
        self.ui.playerCountLabel:SetText(("%d players"):format(#players))
    end

    if self.ui.playersEmptyState then
        self.ui.playersEmptyState:SetShown(#players == 0)
    end

    if self.ui.playersTable then
        local rows = self:BuildPlayerAnalyticsTableData(players)
        self:ApplyPlayersTableSortState()
        self.ui.playersTable:SetData(rows)
        self.ui.playersTable:SortData()
        if self.ui.playersTable.frame then
            self.ui.playersTable.frame:SetShown(#players > 0)
        end
    end

    local playerEntry = self:GetSelectedPlayerEntry()
    local showDetail = self.db.ui.playersView == "detail" and playerEntry ~= nil

    if self.ui.playersIndexView then
        self.ui.playersIndexView:SetShown(not showDetail)
    end
    if self.ui.playersDetailView then
        self.ui.playersDetailView:SetShown(showDetail)
    end

    if showDetail then
        self:RefreshPlayerDetailView(playerEntry)
    elseif self.db.ui.playersView == "detail" then
        self.db.ui.playersView = "index"
        self.db.ui.selectedPlayer = nil
    end
end

function MythicTools:RefreshPlayerDetailView(playerEntry)
    if not (self.ui and self.ui.playersDetailView and playerEntry) then
        return
    end

    local visualSpecName = playerEntry.specName or nil
    local visualRole = playerEntry.role and self:GetRoleLabel(playerEntry.role) or nil
    local heroMeta = {}
    if visualSpecName then
        heroMeta[#heroMeta + 1] = visualSpecName
    end
    if visualRole then
        heroMeta[#heroMeta + 1] = visualRole
    end
    if playerEntry.classFilename and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[playerEntry.classFilename] then
        heroMeta[#heroMeta + 1] = LOCALIZED_CLASS_NAMES_MALE[playerEntry.classFilename]
    end

    self:SetPortraitWidget(self.ui.playerDetailPortrait, playerEntry.fullName, playerEntry.classFilename, playerEntry.specIconID)
    self:SetRoleBadge(self.ui.playerDetailRoleBadge, playerEntry.role)
    self.ui.playerDetailName:SetText(playerEntry.shortName or playerEntry.fullName or "Unknown player")
    self.ui.playerDetailMeta:SetText(#heroMeta > 0 and table.concat(heroMeta, "  |  ") or "Historical player summary")
    self.ui.playerDetailSummaryPrimary:SetText(("Runs %d  |  Timed %d  |  OT %d  |  Ab %d  |  Best %s  |  Avg %.1f"):format(
        playerEntry.totalRuns or 0,
        playerEntry.timedRuns or 0,
        playerEntry.overtimeRuns or 0,
        playerEntry.abandonedRuns or 0,
        FormatKeyLevel(playerEntry.bestTimedLevel),
        playerEntry.averageLevel or 0
    ))
    self.ui.playerDetailSummarySecondary:SetText(("Max DPS %s  |  Avg DPS %s  |  Max HPS %s  |  Avg HPS %s"):format(
        self:FormatAmount(playerEntry.maxDps or 0),
        self:FormatAmount(playerEntry.averageDps or 0),
        self:FormatAmount(playerEntry.maxHps or 0),
        self:FormatAmount(playerEntry.averageHps or 0)
    ))

    local noteParts = {}
    if playerEntry.lastDungeonName then
        noteParts[#noteParts + 1] = ("Last seen: %s %s"):format(playerEntry.lastDungeonName, FormatKeyLevel(playerEntry.lastLevel))
    end
    if playerEntry.lastSeenAt then
        noteParts[#noteParts + 1] = self:FormatDateTime(playerEntry.lastSeenAt)
    end
    if playerEntry.lastResult then
        noteParts[#noteParts + 1] = playerEntry.lastResult == "timed" and "Timed" or (playerEntry.lastResult == "abandoned" and "Abandoned" or "Overtime")
    end
    self.ui.playerDetailHeroNote:SetText(#noteParts > 0 and table.concat(noteParts, "  |  ") or "No recent metadata available.")

    local specEntries = self:GetSortedBreakdownEntries(playerEntry.specBreakdown)
    local roleShortLabel = {
        DAMAGER = "DPS",
        HEALER = "Heal",
        TANK = "Tank",
    }
    local visibleChipCount = 0
    for index, chip in ipairs(self.ui.playerDetailSpecChips or {}) do
        local entry = specEntries[index]
        if entry then
            visibleChipCount = visibleChipCount + 1
            chip:Show()
            chip:ClearAllPoints()
            chip:SetPoint("RIGHT", self.ui.playerDetailSpecChipsContainer, "RIGHT", -((visibleChipCount - 1) * 92), 0)
            chip.Icon:SetTexture(entry.specIconID or QUESTION_MARK_ICON)
            chip.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            chip.Count:SetText(("x%d"):format(entry.totalRuns or 0))
            chip.Role:SetText(roleShortLabel[entry.role] or "")
            chip.tooltipText = ("%s  |  %d runs"):format(entry.specName or entry.label or "Unknown spec", entry.totalRuns or 0)
            chip:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(self.tooltipText or "Unknown spec", COLORS.text[1], COLORS.text[2], COLORS.text[3])
                GameTooltip:Show()
            end)
            chip:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            chip:Hide()
        end
    end
    if self.ui.playerDetailSpecChipsContainer then
        local reserveWidth = visibleChipCount > 0 and (88 + ((visibleChipCount - 1) * 92)) or 0
        local rightInset = reserveWidth > 0 and (reserveWidth + 30) or 18
        self.ui.playerDetailSpecChipsContainer:SetWidth(reserveWidth)
        self.ui.playerDetailSummaryPrimary:ClearAllPoints()
        self.ui.playerDetailSummaryPrimary:SetPoint("TOPLEFT", self.ui.playerDetailMeta, "BOTTOMLEFT", 0, -8)
        self.ui.playerDetailSummaryPrimary:SetPoint("TOPRIGHT", self.ui.playerDetailHero, "TOPRIGHT", -rightInset, -68)
        self.ui.playerDetailSummarySecondary:ClearAllPoints()
        self.ui.playerDetailSummarySecondary:SetPoint("TOPLEFT", self.ui.playerDetailSummaryPrimary, "BOTTOMLEFT", 0, -6)
        self.ui.playerDetailSummarySecondary:SetPoint("TOPRIGHT", self.ui.playerDetailHero, "TOPRIGHT", -rightInset, -88)
        self.ui.playerDetailHeroNote:ClearAllPoints()
        self.ui.playerDetailHeroNote:SetPoint("TOPLEFT", self.ui.playerDetailSummarySecondary, "BOTTOMLEFT", 0, -6)
        self.ui.playerDetailHeroNote:SetPoint("TOPRIGHT", self.ui.playerDetailHero, "TOPRIGHT", -rightInset, -106)
        self.ui.playerDetailSpecChipsContainer:SetShown(visibleChipCount > 0)
    end
    local noteText = self:GetPlayerNote(playerEntry.fullName)

    if self.ui.playerDetailNoteEditor and self.ui.playerDetailNoteEditor.EditBox then
        local editBox = self.ui.playerDetailNoteEditor.EditBox
        if not editBox:HasFocus() or editBox.playerName ~= playerEntry.fullName then
            editBox:SetText(noteText)
            editBox.playerName = playerEntry.fullName
        end
    end
    if self.ui.playerDetailNoteStatus then
        self.ui.playerDetailNoteStatus:SetText(noteText ~= "" and "Saved." or "Up to 160 characters.")
    end

    local allRecentRuns = self:GetPlayerRecentRuns(playerEntry.fullName)
    local recentRuns = {}
    for i = 1, min(PLAYER_DETAIL_HISTORY_ROWS, #allRecentRuns) do
        recentRuns[i] = allRecentRuns[i]
    end
    if self.ui.playerDetailHistoryCount then
        self.ui.playerDetailHistoryCount:SetText(("%d run%s total"):format(#allRecentRuns, #allRecentRuns == 1 and "" or "s"))
    end
    if self.ui.playerDetailEmptyHistory then
        self.ui.playerDetailEmptyHistory:SetShown(#allRecentRuns == 0)
    end
    if self.ui.playerDetailSeeAllButton then
        self.ui.playerDetailSeeAllButton:SetShown(#allRecentRuns > 0)
    end

    for index, row in ipairs(self.ui.playerDetailHistoryRows or {}) do
        local run = recentRuns[index]
        if run then
            local upgradeText = GetRunUpgradeText(run)
            local scoreText = GetRunScoreText(run)
            local subtitle = ("%s  |  %d deaths  |  %d item%s"):format(
                self:FormatDateTime(run.endTime),
                run.totalDeaths or 0,
                self:GetRunLootCount(run),
                self:GetRunLootCount(run) == 1 and "" or "s"
            )
            if upgradeText ~= "" then
                subtitle = subtitle .. ("  |  Upgrade %s"):format(upgradeText)
            end
            if scoreText ~= "" then
                subtitle = subtitle .. ("  |  %s"):format(scoreText)
            end
            row:Show()
            row.runId = run.runId
            self:SetRunArt(row.Icon, nil, run)
            row.Title:SetText(("%s %s"):format(run.dungeonName or "Unknown", FormatKeyLevel(run.level)))
            row.Subtitle:SetText(subtitle)
            row.RightTop:SetText(run.result == "timed" and "Timed" or (run.result == "abandoned" and "Abandoned" or "Overtime"))
            row.RightBottom:SetText(self:FormatDurationMS(run.timeMS))
            StyleListButton(row, false, GetRunStatusColor(run))
        else
            row.runId = nil
            row:Hide()
        end
    end

    if self.runtime and self.runtime.pendingNoteFocusPlayer == playerEntry.fullName then
        self.runtime.pendingNoteFocusPlayer = nil
        C_Timer.After(0, function()
            MythicTools:FocusSelectedPlayerNoteEditor()
        end)
    end
end

function MythicTools:RefreshSettingsView()
    if not self.ui then
        return
    end

    self.ui.settingsAlerts.Check:SetChecked(self.db.settings.chatAlerts)
    self.ui.settingsMinimap.Check:SetChecked(self.db.settings.showMinimapButton)
    self.ui.settingsPopupEnabled.Check:SetChecked(self.db.settings.showCompletionPopup ~= false)
    self.ui.settingsLootHistory.Check:SetChecked(self.db.settings.showLootHistory ~= false)
    self.ui.settingsPopupTrigger:SetValue(self.db.settings.completionPopupTrigger or "COMPLETED")

    if not self.ui.settingsMaxRuns.Input:HasFocus() then
        self.ui.settingsMaxRuns.Input:SetText(tostring(self.db.settings.maxRuns or 500))
    end
    if not self.ui.settingsPopupDelay.Input:HasFocus() then
        self.ui.settingsPopupDelay.Input:SetText(tostring(self.db.settings.completionPopupDelay or 0))
    end
    if not self.ui.settingsPopupScale.Input:HasFocus() then
        self.ui.settingsPopupScale.Input:SetText(string.format("%.1f", self:GetCompletionPopupScale()))
    end

    self:ApplyCompletionPopupScale()

    local activeRunText = "No active run"
    if self.runtime and self.runtime.activeRun then
        activeRunText = ("Active run: %s +%d"):format(self.runtime.activeRun.dungeonName or "Unknown", self.runtime.activeRun.keyLevel or 0)
    end

    self.ui.settingsSummary:SetText((
        "Saved runs: %d\nIndexed players: %d\n%s\nPopup: %s (%s, delay %ss, scale %.1f)\nData source: Details! preferred, C_DamageMeter fallback"
    ):format(
        #self.db.runs,
        self:GetPlayerCount(),
        activeRunText,
        self.db.settings.showCompletionPopup == false and "disabled" or "enabled",
        GetPopupTriggerLabel(self.db.settings.completionPopupTrigger or "COMPLETED"),
        tostring(self.db.settings.completionPopupDelay or 0),
        self:GetCompletionPopupScale()
    ))
end
local function FormatTotalTime(ms)
    if not ms or ms <= 0 then return "--" end
    local s = floor(ms / 1000)
    local d = floor(s / 86400)
    local h = floor((s % 86400) / 3600)
    local m = floor((s % 3600) / 60)
    if d > 0 then return ("%dd %dh"):format(d, h)
    elseif h > 0 then return ("%dh %dm"):format(h, m)
    else return ("%dm"):format(m) end
end

local function CreateStatsTitleBar(parent, labelText)
    local title = CreateFont(parent, 13, COLORS.text)
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText(labelText)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE_TEXTURE)
    line:SetPoint("BOTTOMLEFT", title, "BOTTOMLEFT", 0, -4)
    line:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 0, -4)
    line:SetHeight(1)
    line:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.4)
    return title
end

local function CreateStatsCard(parent, y, w, h)
    local card = CreateFrame("Frame", nil, parent)
    card:SetPoint("TOPLEFT", STATS_PAD, y)
    card:SetSize(w, h)
    MythicTools:ApplySurface(card, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
    ClipChildren(card)
    return card
end

local function UpdateDungeonRowBar(row, d, maxCount)
    local barW = row.barW or 200
    local fill = maxCount > 0 and (barW * d.count / maxCount) or 0
    local tw = d.count > 0 and (fill * d.timed / d.count) or 0
    local ow = d.count > 0 and (fill * d.overtime / d.count) or 0
    local aw = d.count > 0 and (fill * d.abandoned / d.count) or 0
    row.BarTimed:SetWidth(max(0, tw))
    row.BarOT:ClearAllPoints()
    row.BarOT:SetPoint("TOPLEFT", row.BarTimed, "TOPRIGHT", 0, 0)
    row.BarOT:SetWidth(max(0, ow))
    row.BarAb:ClearAllPoints()
    row.BarAb:SetPoint("TOPLEFT", row.BarOT, "TOPRIGHT", 0, 0)
    row.BarAb:SetWidth(max(0, aw))
end

local function CreateStatsDungeonRow(parent, index, rowW)
    local row = CreateFrame("Frame", nil, parent)
    local rowY = -((index - 1) * STATS_DUNGEON_ROW_H + STATS_SECTION_TITLE_H)
    row:SetPoint("TOPLEFT", 0, rowY)
    row:SetSize(rowW, STATS_DUNGEON_ROW_H)
    row:Hide()
    if index % 2 == 0 then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(WHITE_TEXTURE)
        bg:SetVertexColor(0.07, 0.07, 0.07, 1)
    end
    row.Name = CreateFont(row, 11, COLORS.text)
    row.Name:SetPoint("LEFT", 16, 0)
    row.Name:SetWidth(196)
    row.Count = CreateFont(row, 11, COLORS.accent, "RIGHT")
    row.Count:SetPoint("RIGHT", -16, 0)
    row.Count:SetWidth(40)
    row.Status = CreateFont(row, 9, COLORS.subdued, "RIGHT")
    row.Status:SetPoint("RIGHT", row.Count, "LEFT", -6, 0)
    row.Status:SetWidth(140)
    -- barW: rowW minus fixed left/right elements
    -- LEFT(16) + nameW(196) + gap(10) + [bar] + gap(10) + statusW(140) + gap(6) + countW(40) + RIGHT(16)
    local barW = max(10, rowW - 434)
    row.barW = barW
    local barHolder = CreateFrame("Frame", nil, row)
    barHolder:SetSize(barW, STATS_BAR_H)
    barHolder:SetPoint("LEFT", row.Name, "RIGHT", 10, 0)
    local barBg = barHolder:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture(WHITE_TEXTURE)
    barBg:SetVertexColor(0.07, 0.07, 0.07, 1)
    row.BarTimed = barHolder:CreateTexture(nil, "ARTWORK")
    row.BarTimed:SetTexture(WHITE_TEXTURE)
    row.BarTimed:SetVertexColor(COLORS.success[1], COLORS.success[2], COLORS.success[3], 0.85)
    row.BarTimed:SetPoint("TOPLEFT")
    row.BarTimed:SetHeight(STATS_BAR_H)
    row.BarTimed:SetWidth(0)
    row.BarOT = barHolder:CreateTexture(nil, "ARTWORK")
    row.BarOT:SetTexture(WHITE_TEXTURE)
    row.BarOT:SetVertexColor(COLORS.warning[1], COLORS.warning[2], COLORS.warning[3], 0.85)
    row.BarOT:SetPoint("TOPLEFT", row.BarTimed, "TOPRIGHT", 0, 0)
    row.BarOT:SetHeight(STATS_BAR_H)
    row.BarOT:SetWidth(0)
    row.BarAb = barHolder:CreateTexture(nil, "ARTWORK")
    row.BarAb:SetTexture(WHITE_TEXTURE)
    row.BarAb:SetVertexColor(COLORS.danger[1], COLORS.danger[2], COLORS.danger[3], 0.85)
    row.BarAb:SetPoint("TOPLEFT", row.BarOT, "TOPRIGHT", 0, 0)
    row.BarAb:SetHeight(STATS_BAR_H)
    row.BarAb:SetWidth(0)
    row.BarHolder = barHolder
    return row
end

function MythicTools:ComputeStatsData()
    local runs = (self.db and self.db.runs) or {}
    local total = #runs
    local timed, overtime, abandoned = 0, 0, 0
    local totalLevel, countedLevel, bestTimed = 0, 0, 0
    local totalTimeMS, totalDeaths = 0, 0
    local dungeons, classes, teammates = {}, {}, {}

    for _, run in ipairs(runs) do
        if type(run) == "table" then
            local result = run.result or "abandoned"
            local isAbandoned = result == "abandoned"
            local isTimed = result == "timed"
            if isTimed then timed = timed + 1
            elseif isAbandoned then abandoned = abandoned + 1
            else overtime = overtime + 1 end
            if not isAbandoned and (run.level or 0) > 0 then
                totalLevel = totalLevel + run.level
                countedLevel = countedLevel + 1
            end
            if isTimed and (run.level or 0) > bestTimed then bestTimed = run.level end
            if not isAbandoned then totalTimeMS = totalTimeMS + (run.timeMS or 0) end
            totalDeaths = totalDeaths + (run.totalDeaths or 0)
            local dName = type(run.dungeonName) == "string" and run.dungeonName ~= "" and run.dungeonName
            if dName then
                if not dungeons[dName] then
                    dungeons[dName] = {name=dName, count=0, timed=0, overtime=0, abandoned=0, totalTimeMS=0, countedTime=0}
                end
                local d = dungeons[dName]
                d.count = d.count + 1
                if isTimed then d.timed = d.timed + 1
                elseif isAbandoned then d.abandoned = d.abandoned + 1
                else d.overtime = d.overtime + 1 end
                if not isAbandoned and (run.timeMS or 0) > 0 then
                    d.totalTimeMS = d.totalTimeMS + run.timeMS
                    d.countedTime = d.countedTime + 1
                end
            end
            for playerName, stat in pairs(run.playerStats or {}) do
                if type(stat) == "table" and not self:IsOwnedCharacter(playerName) then
                    if stat.classFilename then
                        classes[stat.classFilename] = (classes[stat.classFilename] or 0) + 1
                    end
                    local sn = stat.shortName or self:GetShortName(playerName)
                    if sn and sn ~= "" then
                        if not teammates[sn] then
                            teammates[sn] = {name=sn, count=0, classFilename=stat.classFilename}
                        end
                        teammates[sn].count = teammates[sn].count + 1
                        if stat.classFilename then teammates[sn].classFilename = stat.classFilename end
                    end
                end
            end
        end
    end

    local sortedDungeons = {}
    for _, d in pairs(dungeons) do
        d.avgTimeMS = d.countedTime > 0 and (d.totalTimeMS / d.countedTime) or 0
        sortedDungeons[#sortedDungeons + 1] = d
    end
    table.sort(sortedDungeons, function(a, b) return a.count > b.count end)

    local sortedClasses = {}
    for cf, cnt in pairs(classes) do
        sortedClasses[#sortedClasses + 1] = {classFilename=cf, count=cnt}
    end
    table.sort(sortedClasses, function(a, b) return a.count > b.count end)

    local sortedTeammates = {}
    for _, t in pairs(teammates) do sortedTeammates[#sortedTeammates + 1] = t end
    table.sort(sortedTeammates, function(a, b) return a.count > b.count end)

    return {
        total = total, timed = timed, overtime = overtime, abandoned = abandoned,
        timedPct = total > 0 and (timed / total * 100) or 0,
        avgLevel = countedLevel > 0 and (totalLevel / countedLevel) or 0,
        bestTimed = bestTimed, totalTimeMS = totalTimeMS, totalDeaths = totalDeaths,
        dungeons = sortedDungeons, classes = sortedClasses, teammates = sortedTeammates,
    }
end

function MythicTools:BuildStatsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    ClipChildren(page)

    -- Header
    local headerCard = CreateFrame("Frame", nil, page)
    headerCard:SetPoint("TOPLEFT", 12, -12)
    headerCard:SetPoint("TOPRIGHT", -12, -12)
    headerCard:SetHeight(38)
    self:ApplySurface(headerCard, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
    local headerTitle = CreateFont(headerCard, 13, COLORS.accent)
    headerTitle:SetPoint("LEFT", 16, 0)
    headerTitle:SetText("Statistics")

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, page)
    scrollFrame:SetPoint("TOPLEFT", 12, -62)
    scrollFrame:SetPoint("BOTTOMRIGHT", -20, 12)
    scrollFrame:EnableMouseWheel(true)
    self.ui.statsScrollFrame = scrollFrame

    -- Explicit content width: SetScrollChild breaks TOPRIGHT anchors (they resolve to 0).
    -- Derive from saved frame width: pageW = frameW - sidebarW(213), scrollFrame inset = 12+20 = 32
    local frameW = (self.db and self.db.ui and self.db.ui.width) or 1080
    local scrollW = max(600, frameW - 245)
    local sectionW = scrollW - 2 * STATS_PAD
    local leftColW = floor(sectionW * 0.37)
    local rightColW = sectionW - leftColW - STATS_PAD

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollW, STATS_CONTENT_H)
    scrollFrame:SetScrollChild(content)
    self.ui.statsContent = content

    -- Thin scrollbar
    local scrollBar = CreateFrame("Slider", nil, page)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetWidth(6)
    scrollBar:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -62)
    scrollBar:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 12)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:Hide()
    local sbThumb = scrollBar:CreateTexture(nil, "ARTWORK")
    sbThumb:SetTexture(WHITE_TEXTURE)
    sbThumb:SetWidth(4)
    sbThumb:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.65)
    scrollBar:SetThumbTexture(sbThumb)
    scrollBar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:SetScript("OnScrollRangeChanged", function(self, _, yRange)
        local m = max(0, yRange)
        scrollBar:SetMinMaxValues(0, m)
        scrollBar:SetShown(m > 0)
    end)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = scrollBar:GetValue()
        local _, maxVal = scrollBar:GetMinMaxValues()
        scrollBar:SetValue(max(0, min(cur - delta * 60, maxVal)))
    end)
    self.ui.statsScrollBar = scrollBar

    local y = -STATS_PAD

    -- ── SECTION 1: OVERVIEW ──────────────────────────────────────────────
    local OVERVIEW_LABELS = {"Total Runs", "Timed %", "Avg Key", "Best Key", "In-Key Time", "Deaths"}
    local NUM_OV = #OVERVIEW_LABELS
    local ovGap = 8
    local ovCardW = floor((sectionW - (NUM_OV - 1) * ovGap) / NUM_OV)
    local overviewRow = CreateFrame("Frame", nil, content)
    overviewRow:SetPoint("TOPLEFT", STATS_PAD, y)
    overviewRow:SetSize(sectionW, STATS_OVERVIEW_H)
    self.ui.statsOverviewCards = {}
    for i = 1, NUM_OV do
        local card = CreateFrame("Frame", nil, overviewRow)
        self:ApplySurface(card, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
        card:SetPoint("TOPLEFT", (i - 1) * (ovCardW + ovGap), 0)
        card:SetSize(ovCardW, STATS_OVERVIEW_H)
        card.Value = CreateFont(card, 22, COLORS.text, "CENTER")
        card.Value:SetPoint("CENTER", 0, 12)
        card.Value:SetText("--")
        card.Label = CreateFont(card, 10, COLORS.subdued, "CENTER")
        card.Label:SetPoint("CENTER", 0, -12)
        card.Label:SetText(OVERVIEW_LABELS[i])
        self.ui.statsOverviewCards[i] = card
    end

    y = y - STATS_OVERVIEW_H - STATS_PAD

    -- ── SECTION 2: MOST PLAYED DUNGEONS ──────────────────────────────────
    local dungeonsCard = CreateStatsCard(content, y, sectionW, STATS_DUNGEON_SECTION_H)
    CreateStatsTitleBar(dungeonsCard, "Most Played Dungeons")
    self.ui.statsDungeonRows = {}
    for i = 1, MAX_STATS_DUNGEON_ROWS do
        self.ui.statsDungeonRows[i] = CreateStatsDungeonRow(dungeonsCard, i, sectionW)
    end

    y = y - STATS_DUNGEON_SECTION_H - STATS_PAD

    -- ── SECTION 3: TWO COLUMNS ────────────────────────────────────────────
    -- Left: Team Classes
    local classesCard = CreateFrame("Frame", nil, content)
    classesCard:SetPoint("TOPLEFT", STATS_PAD, y)
    classesCard:SetSize(leftColW, STATS_TWOCOL_H)
    self:ApplySurface(classesCard, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
    ClipChildren(classesCard)
    CreateStatsTitleBar(classesCard, "Team Classes")
    self.ui.statsClassRows = {}
    for i = 1, MAX_STATS_CLASS_ROWS do
        local row = CreateFrame("Frame", nil, classesCard)
        local rowY = -((i - 1) * STATS_CLASS_ROW_H + STATS_SECTION_TITLE_H)
        row:SetPoint("TOPLEFT", 0, rowY)
        row:SetSize(leftColW, STATS_CLASS_ROW_H)
        row:Hide()
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture(WHITE_TEXTURE)
            bg:SetVertexColor(0.07, 0.07, 0.07, 1)
        end
        row.Dot = row:CreateTexture(nil, "ARTWORK")
        row.Dot:SetTexture(WHITE_TEXTURE)
        row.Dot:SetSize(9, 9)
        row.Dot:SetPoint("LEFT", 16, 0)
        row.Name = CreateFont(row, 11, COLORS.text)
        row.Name:SetPoint("LEFT", row.Dot, "RIGHT", 8, 0)
        row.Name:SetWidth(130)
        row.Count = CreateFont(row, 11, COLORS.accent, "RIGHT")
        row.Count:SetPoint("RIGHT", -16, 0)
        self.ui.statsClassRows[i] = row
    end

    -- Right: Avg Completion Time (TOPLEFT anchor from left col edge, explicit size)
    local avgTimeCard = CreateFrame("Frame", nil, content)
    avgTimeCard:SetPoint("TOPLEFT", STATS_PAD + leftColW + STATS_PAD, y)
    avgTimeCard:SetSize(rightColW, STATS_TWOCOL_H)
    self:ApplySurface(avgTimeCard, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
    ClipChildren(avgTimeCard)
    CreateStatsTitleBar(avgTimeCard, "Avg Completion Time")
    self.ui.statsAvgTimeRows = {}
    for i = 1, MAX_STATS_DUNGEON_ROWS do
        local row = CreateFrame("Frame", nil, avgTimeCard)
        local rowY = -((i - 1) * STATS_DUNGEON_ROW_H + STATS_SECTION_TITLE_H)
        row:SetPoint("TOPLEFT", 0, rowY)
        row:SetSize(rightColW, STATS_DUNGEON_ROW_H)
        row:Hide()
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture(WHITE_TEXTURE)
            bg:SetVertexColor(0.07, 0.07, 0.07, 1)
        end
        row.Name = CreateFont(row, 11, COLORS.text)
        row.Name:SetPoint("LEFT", 16, 0)
        row.Name:SetWidth(200)
        row.Time = CreateFont(row, 12, COLORS.accent, "RIGHT")
        row.Time:SetPoint("RIGHT", -16, 0)
        self.ui.statsAvgTimeRows[i] = row
    end

    y = y - STATS_TWOCOL_H - STATS_PAD

    -- ── SECTION 4: MOST PLAYED WITH ───────────────────────────────────────
    local teammatesCard = CreateStatsCard(content, y, sectionW, STATS_TEAMMATE_SECTION_H)
    CreateStatsTitleBar(teammatesCard, "Most Played With")
    self.ui.statsTeammateRows = {}
    for i = 1, MAX_STATS_TEAMMATE_ROWS do
        local row = CreateFrame("Frame", nil, teammatesCard)
        local rowY = -((i - 1) * STATS_TEAMMATE_ROW_H + STATS_SECTION_TITLE_H)
        row:SetPoint("TOPLEFT", 0, rowY)
        row:SetSize(sectionW, STATS_TEAMMATE_ROW_H)
        row:Hide()
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture(WHITE_TEXTURE)
            bg:SetVertexColor(0.07, 0.07, 0.07, 1)
        end
        local rankBg = CreateFrame("Frame", nil, row)
        rankBg:SetSize(22, 22)
        rankBg:SetPoint("LEFT", 14, 0)
        MythicTools:ApplySurface(rankBg, COLORS.frameBG, COLORS.surface, nil)
        row.Rank = CreateFont(rankBg, 9, COLORS.subdued, "CENTER")
        row.Rank:SetAllPoints()
        row.Rank:SetText(tostring(i))
        row.Dot = row:CreateTexture(nil, "ARTWORK")
        row.Dot:SetTexture(WHITE_TEXTURE)
        row.Dot:SetSize(10, 10)
        row.Dot:SetPoint("LEFT", rankBg, "RIGHT", 10, 0)
        row.Name = CreateFont(row, 12, COLORS.text)
        row.Name:SetPoint("LEFT", row.Dot, "RIGHT", 8, 0)
        row.Name:SetWidth(200)
        row.Class = CreateFont(row, 10, COLORS.subdued)
        row.Class:SetPoint("LEFT", row.Name, "RIGHT", 10, 0)
        row.Class:SetWidth(110)
        row.Runs = CreateFont(row, 12, COLORS.accent, "RIGHT")
        row.Runs:SetPoint("RIGHT", -16, 0)
        self.ui.statsTeammateRows[i] = row
    end

    return page
end

function MythicTools:RefreshStatsView()
    if not (self.ui and self.ui.statsContent) then return end
    if not (self.ui.pages and self.ui.pages.Stats and self.ui.pages.Stats:IsShown()) then return end

    local data = self:ComputeStatsData()

    -- Overview
    local cards = self.ui.statsOverviewCards
    if cards then
        local function sv(i, val) if cards[i] then cards[i].Value:SetText(val) end end
        sv(1, tostring(data.total))
        sv(2, data.total > 0 and string.format("%.1f%%", data.timedPct) or "--")
        sv(3, data.avgLevel > 0 and string.format("%.1f", data.avgLevel) or "--")
        sv(4, data.bestTimed > 0 and ("+%d"):format(data.bestTimed) or "--")
        sv(5, FormatTotalTime(data.totalTimeMS))
        sv(6, tostring(data.totalDeaths))
    end

    -- Dungeon rows
    local maxDungCount = (data.dungeons[1] and data.dungeons[1].count) or 1
    for i, row in ipairs(self.ui.statsDungeonRows or {}) do
        local d = data.dungeons[i]
        if d then
            row.Name:SetText(d.name)
            row.Count:SetText(tostring(d.count))
            row.Status:SetText(("T:%d  OT:%d  Ab:%d"):format(d.timed, d.overtime, d.abandoned))
            UpdateDungeonRowBar(row, d, maxDungCount)
            row:Show()
        else
            row:Hide()
        end
    end

    -- Class rows
    for i, row in ipairs(self.ui.statsClassRows or {}) do
        local c = data.classes[i]
        if c then
            local localName = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.classFilename]) or c.classFilename or "?"
            local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.classFilename]
            if cc then
                row.Dot:SetVertexColor(cc.r, cc.g, cc.b, 1)
                SetTextColor(row.Name, {cc.r, cc.g, cc.b, 1})
            else
                row.Dot:SetVertexColor(0.7, 0.7, 0.7, 1)
                SetTextColor(row.Name, COLORS.text)
            end
            row.Name:SetText(localName)
            row.Count:SetText(tostring(c.count))
            row:Show()
        else
            row:Hide()
        end
    end

    -- Avg time rows (same dungeon order)
    for i, row in ipairs(self.ui.statsAvgTimeRows or {}) do
        local d = data.dungeons[i]
        if d then
            row.Name:SetText(d.name)
            row.Time:SetText(d.avgTimeMS > 0 and self:FormatDurationMS(d.avgTimeMS) or "--")
            row:Show()
        else
            row:Hide()
        end
    end

    -- Teammate rows
    for i, row in ipairs(self.ui.statsTeammateRows or {}) do
        local t = data.teammates[i]
        if t then
            local cc = t.classFilename and RAID_CLASS_COLORS and RAID_CLASS_COLORS[t.classFilename]
            if cc then
                row.Dot:SetVertexColor(cc.r, cc.g, cc.b, 1)
            else
                row.Dot:SetVertexColor(0.6, 0.6, 0.6, 1)
            end
            row.Name:SetText(t.name)
            local localClass = (t.classFilename and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[t.classFilename]) or ""
            row.Class:SetText(localClass)
            row.Runs:SetText(("%d runs"):format(t.count))
            row:Show()
        else
            row:Hide()
        end
    end

    if self.ui.statsScrollFrame then self.ui.statsScrollFrame:SetVerticalScroll(0) end
    if self.ui.statsScrollBar then self.ui.statsScrollBar:SetValue(0) end
end

function MythicTools:BuildRunsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    ClipChildren(page)

    local filterBar = CreateFrame("Frame", nil, page)
    filterBar:SetPoint("TOPLEFT", 12, -12)
    filterBar:SetPoint("TOPRIGHT", -12, -12)
    filterBar:SetHeight(154)
    self:ApplySurface(filterBar, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
    self.ui.runsFilterBar = filterBar

    local filterTitle = CreateFont(filterBar, 13, COLORS.text)
    filterTitle:SetPoint("TOPLEFT", 16, -14)
    filterTitle:SetText("Filters")

    self.ui.runCountLabel = CreateFont(filterBar, 12, COLORS.muted, "RIGHT")
    self.ui.runCountLabel:SetPoint("TOPRIGHT", -16, -14)

    local topRow = CreateAceFlowRow(filterBar, -34, 54)
    local bottomRow = CreateAceFlowRow(filterBar, -92, 54)

    self.ui.runsSearch = CreateAceEditWidget("Search", 210, self.db.ui.filters.search, function(value)
        self.db.ui.filters.search = value or ""
        self:SetRunViewMode("list")
        self:RefreshRunView()
    end)
    StyleAceEditWidget(self.ui.runsSearch)
    topRow:AddChild(self.ui.runsSearch)
    topRow:AddChild(CreateAceSpacer(10))

    self.ui.runsPlayerFilter = CreateAceEditWidget("Player", 190, self.db.ui.filters.player, function(value)
        self.db.ui.filters.player = value or ""
        self:SetRunViewMode("list")
        self:RefreshRunView()
    end)
    StyleAceEditWidget(self.ui.runsPlayerFilter)
    topRow:AddChild(self.ui.runsPlayerFilter)
    topRow:AddChild(CreateAceSpacer(10))

    self.ui.runsDateFilter = CreateAceEditWidget("Date", 120, self.db.ui.filters.date, function(value)
        self.db.ui.filters.date = value or ""
        self:SetRunViewMode("list")
        self:RefreshRunView()
    end)
    StyleAceEditWidget(self.ui.runsDateFilter)
    topRow:AddChild(self.ui.runsDateFilter)
    topRow:AddChild(CreateAceSpacer(10))

    self.ui.runsStatusFilter = CreateAceDropdownWidget("Status", 140, STATUS_OPTIONS, self.db.ui.filters.status, function(value)
        self.db.ui.filters.status = value or "all"
        self:SetRunViewMode("list")
        self:RefreshRunView()
    end)
    StyleAceDropdownWidget(self.ui.runsStatusFilter)
    topRow:AddChild(self.ui.runsStatusFilter)

    self.ui.runsSeasonFilter = CreateAceDropdownWidget("Season", 170, SEASON_OPTIONS, self.db.ui.filters.season, function(value)
        self.db.ui.filters.season = value or SEASON_OPTIONS[1].value
        self.db.ui.filters.dungeon = "all"
        SetAceDropdownValue(self.ui.runsSeasonFilter, self.db.ui.filters.season)
        UpdateAceDropdownOptions(self.ui.runsDungeonFilter, GetDungeonOptionsForSeason(self.db.ui.filters.season), self.db.ui.filters.dungeon)
        self:SetRunViewMode("list")
        self:RefreshRunView()
    end)
    StyleAceDropdownWidget(self.ui.runsSeasonFilter)
    bottomRow:AddChild(self.ui.runsSeasonFilter)
    bottomRow:AddChild(CreateAceSpacer(10))

    self.ui.runsDungeonFilter = CreateAceDropdownWidget("Dungeon", 260, GetDungeonOptionsForSeason(self.db.ui.filters.season), self.db.ui.filters.dungeon, function(value)
        self.db.ui.filters.dungeon = value or "all"
        self:SetRunViewMode("list")
        self:RefreshRunView()
    end)
    StyleAceDropdownWidget(self.ui.runsDungeonFilter)
    bottomRow:AddChild(self.ui.runsDungeonFilter)
    bottomRow:AddChild(CreateAceSpacer(10))

    self.ui.runsOwnedFilter = CreateAceDropdownWidget("Characters", 180, GetOwnedCharacterFilterOptions(), self.db.ui.filters.ownedCharacters or "all", function(value)
        self.db.ui.filters.ownedCharacters = value or "all"
        self:SetRunViewMode("list")
        self:RefreshRunView()
    end)
    StyleAceDropdownWidget(self.ui.runsOwnedFilter)
    bottomRow:AddChild(self.ui.runsOwnedFilter)

    self.ui.runsClearButton = AceGUI and AceGUI:Create("Button") or nil
    if self.ui.runsClearButton then
        self.ui.runsClearButton:SetText("Clear")
        self.ui.runsClearButton:SetWidth(86)
        self.ui.runsClearButton:SetCallback("OnClick", function()
            self.db.ui.filters.search = ""
            self.db.ui.filters.player = ""
            self.db.ui.filters.dungeon = "all"
            self.db.ui.filters.season = "season1"
            self.db.ui.filters.date = ""
            self.db.ui.filters.status = "all"
            self.db.ui.filters.ownedCharacters = "all"
            SetAceEditText(self.ui.runsSearch, "")
            SetAceEditText(self.ui.runsPlayerFilter, "")
            SetAceEditText(self.ui.runsDateFilter, "")
            SetAceDropdownValue(self.ui.runsSeasonFilter, "season1")
            UpdateAceDropdownOptions(self.ui.runsDungeonFilter, GetDungeonOptionsForSeason("season1"), "all")
            SetAceDropdownValue(self.ui.runsStatusFilter, "all")
            SetAceDropdownValue(self.ui.runsOwnedFilter, "all")
            self:SetRunViewMode("list")
            self:RefreshRunView()
        end)
        bottomRow:AddChild(self.ui.runsClearButton)
    end

    if not self.ui.runsClearButton then
        local clearButton = CreateActionButton(filterBar, 86, 28, "Clear")
        clearButton:SetPoint("TOPLEFT", 460, -110)
        clearButton:SetScript("OnClick", function()
            self.db.ui.filters.search = ""
            self.db.ui.filters.player = ""
            self.db.ui.filters.dungeon = "all"
            self.db.ui.filters.season = "season1"
            self.db.ui.filters.date = ""
            self.db.ui.filters.status = "all"
            self.db.ui.filters.ownedCharacters = "all"
            SetAceEditText(self.ui.runsSearch, "")
            SetAceEditText(self.ui.runsPlayerFilter, "")
            SetAceEditText(self.ui.runsDateFilter, "")
            SetAceDropdownValue(self.ui.runsSeasonFilter, "season1")
            UpdateAceDropdownOptions(self.ui.runsDungeonFilter, GetDungeonOptionsForSeason("season1"), "all")
            SetAceDropdownValue(self.ui.runsStatusFilter, "all")
            SetAceDropdownValue(self.ui.runsOwnedFilter, "all")
            self:SetRunViewMode("list")
            self:RefreshRunView()
        end)
    end

    local listView = CreateFrame("Frame", nil, page)
    listView:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -12)
    listView:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 12)
    self:ApplySurface(listView, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
    ClipChildren(listView)
    self.ui.runsListView = listView

    local listTitle = CreateFont(listView, 14, COLORS.text)
    listTitle:SetPoint("TOPLEFT", 16, -14)
    listTitle:SetText("Key history")

    self.ui.runsEmptyState = CreateFont(listView, 13, COLORS.muted, "CENTER")
    self.ui.runsEmptyState:SetPoint("CENTER")
    self.ui.runsEmptyState:SetText("No runs match the current filters.")
    self.ui.runsEmptyState:Hide()

    local listBody = CreateFrame("Frame", nil, listView)
    listBody:SetPoint("TOPLEFT", 10, -44)
    listBody:SetPoint("TOPRIGHT", -22, -44)
    listBody:SetHeight(RUN_ROWS * RUN_ROW_HEIGHT + 2)
    ClipChildren(listBody)
    self.ui.runsListBody = listBody

    self.ui.runsScroll = CreateFrame("ScrollFrame", nil, listView, "FauxScrollFrameTemplate")
    self.ui.runsScroll:SetPoint("TOPLEFT", 0, -44)
    self.ui.runsScroll:SetPoint("BOTTOMRIGHT", -10, 14)
    self.ui.runsScroll:SetScript("OnVerticalScroll", function(scrollFrame, offset)
        FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, RUN_ROW_HEIGHT, function()
            self:RefreshRunView()
        end)
    end)
    ApplyThinScrollBar(self.ui.runsScroll)

    self.ui.runRows = {}
    for index = 1, RUN_ROWS do
        local row = CreateListButton(listBody, RUN_ROW_HEIGHT - 4)
        row:SetPoint("TOPLEFT", 0, -((index - 1) * RUN_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", 0, -((index - 1) * RUN_ROW_HEIGHT))
        row:SetScript("OnClick", function(button, mouseButton)
            if not button.runId then
                return
            end

            if mouseButton == "RightButton" then
                self:ConfirmDeleteRun(button.runId)
            else
                self.db.ui.selectedRunId = button.runId
                self:RefreshRunView()
                self:ShowCompletionPopup(button.runId)
            end
        end)
        self.ui.runRows[index] = row
    end

    local detailPanel = CreateFrame("Frame", nil, page)
    detailPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -12)
    detailPanel:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 12)
    self:ApplySurface(detailPanel, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
    ClipChildren(detailPanel)
    self.ui.runsDetailView = detailPanel

    local detailHeader = CreateFrame("Frame", nil, detailPanel)
    detailHeader:SetPoint("TOPLEFT", 16, -16)
    detailHeader:SetPoint("TOPRIGHT", -16, -16)
    detailHeader:SetHeight(38)

    self.ui.runDetailBackButton = CreateActionButton(detailHeader, 136, 28, "Back to history")
    self.ui.runDetailBackButton:SetPoint("LEFT", 0, 0)
    self.ui.runDetailBackButton:SetScript("OnClick", function()
        self:SetRunViewMode("list")
        self:RefreshRunView()
    end)

    local detailHeaderText = CreateFont(detailHeader, 12, COLORS.muted)
    detailHeaderText:SetPoint("LEFT", self.ui.runDetailBackButton, "RIGHT", 14, 0)
    detailHeaderText:SetText("Run details")

    local hero = CreateFrame("Frame", nil, detailPanel)
    hero:SetPoint("TOPLEFT", 16, -62)
    hero:SetPoint("TOPRIGHT", -16, -62)
    hero:SetHeight(150)
    self:ApplySurface(hero, COLORS.headerBG, COLORS.surface, COLORS.accent)
    self.ui.runHero = hero

    hero.Background = hero:CreateTexture(nil, "BACKGROUND")
    hero.Background:SetAllPoints()
    hero.Background:SetAlpha(0.18)
    self.ui.runHeroBackground = hero.Background

    hero.Shade = hero:CreateTexture(nil, "BORDER")
    hero.Shade:SetAllPoints()
    hero.Shade:SetTexture(WHITE_TEXTURE)
    hero.Shade:SetVertexColor(0.01, 0.02, 0.03, 0.44)

    local iconFrame = CreateFrame("Frame", nil, hero)
    iconFrame:SetSize(70, 70)
    iconFrame:SetPoint("TOPLEFT", 18, -18)
    self:ApplySurface(iconFrame, COLORS.frameBG, COLORS.accentSoft, COLORS.accent)

    iconFrame.Icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.Icon:SetPoint("TOPLEFT", 1, -1)
    iconFrame.Icon:SetPoint("BOTTOMRIGHT", -1, 1)
    self.ui.runHeroIcon = iconFrame.Icon

    self.ui.runDetailTitle = CreateFont(hero, 22, COLORS.text)
    self.ui.runDetailTitle:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 14, -2)
    self.ui.runDetailTitle:SetPoint("RIGHT", hero, "RIGHT", -122, 0)

    self.ui.runDetailMeta = CreateFont(hero, 12, COLORS.muted)
    self.ui.runDetailMeta:SetPoint("TOPLEFT", self.ui.runDetailTitle, "BOTTOMLEFT", 0, -8)

    self.ui.runDetailSubmeta = CreateFont(hero, 11, COLORS.muted)
    self.ui.runDetailSubmeta:SetPoint("TOPLEFT", self.ui.runDetailMeta, "BOTTOMLEFT", 0, -6)
    self.ui.runDetailSubmeta:SetPoint("RIGHT", hero, "RIGHT", -16, 0)

    self.ui.runDetailStatus = CreateFont(hero, 14, COLORS.accent, "RIGHT")
    self.ui.runDetailStatus:SetPoint("TOPRIGHT", -18, -20)

    self.ui.runDetailLoot = CreateFont(hero, 11, COLORS.text)
    self.ui.runDetailLoot:SetPoint("TOPLEFT", iconFrame, "BOTTOMLEFT", 0, -10)
    self.ui.runDetailLoot:SetPoint("RIGHT", hero, "RIGHT", -18, 0)

    self.ui.runDetailNote = CreateFont(hero, 10, COLORS.subdued)
    self.ui.runDetailNote:SetPoint("TOPLEFT", self.ui.runDetailLoot, "BOTTOMLEFT", 0, -6)
    self.ui.runDetailNote:SetPoint("RIGHT", hero, "RIGHT", -18, 0)
    self.ui.runDetailNote:SetJustifyH("LEFT")

    local statsPanel = CreateFrame("Frame", nil, detailPanel)
    statsPanel:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 0, -10)
    statsPanel:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -16, 16)
    self:ApplySurface(statsPanel, COLORS.panelBG, COLORS.surface, nil)
    ClipChildren(statsPanel)

    local columnName = CreateFont(statsPanel, 11, COLORS.subdued)
    columnName:SetPoint("TOPLEFT", 16, -12)
    columnName:SetText("Player")

    local columnScore = CreateFont(statsPanel, 11, COLORS.subdued)
    columnScore:SetPoint("TOPLEFT", COMPACT_STATS_SCORE_X, -12)
    columnScore:SetText("M+ score")

    local columnItems = CreateFont(statsPanel, 11, COLORS.subdued)
    columnItems:SetPoint("TOPLEFT", COMPACT_STATS_ITEMS_X, -12)
    columnItems:SetText("Loot")

    local columnDamage = CreateFont(statsPanel, 11, COLORS.subdued)
    columnDamage:SetPoint("TOPLEFT", COMPACT_STATS_DAMAGE_X, -12)
    columnDamage:SetText("Damage")

    local columnDPS = CreateFont(statsPanel, 11, COLORS.subdued)
    columnDPS:SetPoint("TOPLEFT", COMPACT_STATS_DPS_X, -12)
    columnDPS:SetText("DPS")

    local columnHealing = CreateFont(statsPanel, 11, COLORS.subdued)
    columnHealing:SetPoint("TOPLEFT", COMPACT_STATS_HEALING_X, -12)
    columnHealing:SetText("Healing")

    local columnInterrupts = CreateFont(statsPanel, 11, COLORS.subdued)
    columnInterrupts:SetPoint("TOPLEFT", COMPACT_STATS_INTERRUPTS_X, -12)
    columnInterrupts:SetText("Interrupts")

    local columnDeaths = CreateFont(statsPanel, 11, COLORS.subdued)
    columnDeaths:SetPoint("TOPLEFT", COMPACT_STATS_DEATHS_X, -12)
    columnDeaths:SetText("Deaths")

    self.ui.runStatRows = {}
    for index = 1, 5 do
        local row = CreateStatRow(statsPanel)
        row:SetPoint("TOPLEFT", 12, -34 - ((index - 1) * COMPLETION_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", -12, -34 - ((index - 1) * COMPLETION_ROW_HEIGHT))
        self.ui.runStatRows[index] = row
    end

    return page
end
function MythicTools:BuildPlayersPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    ClipChildren(page)

    local indexView = CreateFrame("Frame", nil, page)
    indexView:SetAllPoints(page)
    ClipChildren(indexView)
    self.ui.playersIndexView = indexView

    local filterBar = CreateFrame("Frame", nil, indexView)
    filterBar:SetPoint("TOPLEFT", 12, -12)
    filterBar:SetPoint("TOPRIGHT", -12, -12)
    filterBar:SetHeight(100)
    self:ApplySurface(filterBar, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)

    local topTitle = CreateFont(filterBar, 13, COLORS.text)
    topTitle:SetPoint("TOPLEFT", 16, -14)
    topTitle:SetText("Known players")

    self.ui.playerCountLabel = CreateFont(filterBar, 12, COLORS.muted, "RIGHT")
    self.ui.playerCountLabel:SetPoint("TOPRIGHT", -16, -14)

    local filtersRow = CreateAceFlowRow(filterBar, -34, 54)

    self.ui.playerSearch = CreateAceEditWidget("Search player", 280, (self.db.ui.playerFilters and self.db.ui.playerFilters.search) or "", function(value)
        self.db.ui.playerFilters.search = value or ""
        self.db.ui.playerSearch = value or ""
        self:RefreshPlayersView()
    end)
    StyleAceEditWidget(self.ui.playerSearch)
    filtersRow:AddChild(self.ui.playerSearch)
    filtersRow:AddChild(CreateAceSpacer(10))

    self.ui.playersSeasonFilter = CreateAceDropdownWidget("Season", 170, SEASON_OPTIONS, (self.db.ui.playerFilters and self.db.ui.playerFilters.season) or "season1", function(value)
        self.db.ui.playerFilters.season = value or "season1"
        self.db.ui.playerFilters.dungeon = "all"
        SetAceDropdownValue(self.ui.playersSeasonFilter, self.db.ui.playerFilters.season)
        UpdateAceDropdownOptions(self.ui.playersDungeonFilter, GetDungeonOptionsForSeason(self.db.ui.playerFilters.season), self.db.ui.playerFilters.dungeon)
        self:RefreshPlayersView()
    end)
    StyleAceDropdownWidget(self.ui.playersSeasonFilter)
    filtersRow:AddChild(self.ui.playersSeasonFilter)
    filtersRow:AddChild(CreateAceSpacer(10))

    self.ui.playersDungeonFilter = CreateAceDropdownWidget("Dungeon", 260, GetDungeonOptionsForSeason((self.db.ui.playerFilters and self.db.ui.playerFilters.season) or "season1"), (self.db.ui.playerFilters and self.db.ui.playerFilters.dungeon) or "all", function(value)
        self.db.ui.playerFilters.dungeon = value or "all"
        self:RefreshPlayersView()
    end)
    StyleAceDropdownWidget(self.ui.playersDungeonFilter)
    filtersRow:AddChild(self.ui.playersDungeonFilter)

    local tableCard = CreateFrame("Frame", nil, indexView)
    tableCard:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -12)
    tableCard:SetPoint("BOTTOMRIGHT", indexView, "BOTTOMRIGHT", -12, 12)
    self:ApplySurface(tableCard, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
    ClipChildren(tableCard)

    local tableTitle = CreateFont(tableCard, 14, COLORS.text)
    tableTitle:SetPoint("TOPLEFT", 16, -14)
    tableTitle:SetText("Player analytics")

    self.ui.playersEmptyState = CreateFont(tableCard, 13, COLORS.muted, "CENTER")
    self.ui.playersEmptyState:SetPoint("CENTER")
    self.ui.playersEmptyState:SetText("No players match the current filters.")
    self.ui.playersEmptyState:Hide()

    self.ui.playersTableCard = tableCard
    self.ui.playersTable = self:CreatePlayersAnalyticsTable(tableCard)
    if self.ui.playersTable then
        ApplyThinScrollBarToST(self.ui.playersTable)
    end

    local detailView = CreateFrame("Frame", nil, page)
    detailView:SetAllPoints(page)
    ClipChildren(detailView)
    self.ui.playersDetailView = detailView

    self.ui.playerDetailBackButton = CreateActionButton(detailView, 138, 28, "Back to players")
    self.ui.playerDetailBackButton:SetPoint("TOPLEFT", 12, -12)
    self.ui.playerDetailBackButton:SetScript("OnClick", function()
        MythicTools:ShowPlayersIndex()
    end)

    self.ui.playerDetailHeader = CreateFont(detailView, 12, COLORS.muted)
    self.ui.playerDetailHeader:SetPoint("LEFT", self.ui.playerDetailBackButton, "RIGHT", 14, 0)
    self.ui.playerDetailHeader:SetText("Player details")

    local heroCard = CreateFrame("Frame", nil, detailView)
    heroCard:SetPoint("TOPLEFT", 12, -52)
    heroCard:SetPoint("TOPRIGHT", -12, -52)
    heroCard:SetHeight(128)
    self:ApplySurface(heroCard, COLORS.headerBG, COLORS.surface, COLORS.accent)
    self.ui.playerDetailHero = heroCard

    heroCard.Background = heroCard:CreateTexture(nil, "BACKGROUND")
    heroCard.Background:SetAllPoints()
    heroCard.Background:SetAlpha(0.18)

    self.ui.playerDetailPortrait = CreatePortraitWidget(heroCard, 72)
    self.ui.playerDetailPortrait:SetPoint("TOPLEFT", 18, -18)

    self.ui.playerDetailRoleBadge = CreateRoleBadge(heroCard)
    self.ui.playerDetailRoleBadge:SetPoint("TOPRIGHT", -18, -18)

    self.ui.playerDetailName = CreateFont(heroCard, 22, COLORS.text)
    self.ui.playerDetailName:SetPoint("TOPLEFT", self.ui.playerDetailPortrait, "TOPRIGHT", 16, -2)
    self.ui.playerDetailName:SetPoint("TOPRIGHT", heroCard, "TOPRIGHT", -52, -18)

    self.ui.playerDetailMeta = CreateFont(heroCard, 12, COLORS.muted)
    self.ui.playerDetailMeta:SetPoint("TOPLEFT", self.ui.playerDetailName, "BOTTOMLEFT", 0, -8)
    self.ui.playerDetailMeta:SetPoint("TOPRIGHT", heroCard, "TOPRIGHT", -52, -52)
    self.ui.playerDetailMeta:SetJustifyH("LEFT")

    self.ui.playerDetailSummaryPrimary = CreateFont(heroCard, 11, COLORS.text)
    self.ui.playerDetailSummaryPrimary:SetPoint("TOPLEFT", self.ui.playerDetailMeta, "BOTTOMLEFT", 0, -8)
    self.ui.playerDetailSummaryPrimary:SetPoint("TOPRIGHT", heroCard, "TOPRIGHT", -18, -68)
    self.ui.playerDetailSummaryPrimary:SetJustifyH("LEFT")
    self.ui.playerDetailSummaryPrimary:SetJustifyV("TOP")

    self.ui.playerDetailSummarySecondary = CreateFont(heroCard, 11, COLORS.muted)
    self.ui.playerDetailSummarySecondary:SetPoint("TOPLEFT", self.ui.playerDetailSummaryPrimary, "BOTTOMLEFT", 0, -6)
    self.ui.playerDetailSummarySecondary:SetPoint("TOPRIGHT", heroCard, "TOPRIGHT", -18, -88)
    self.ui.playerDetailSummarySecondary:SetJustifyH("LEFT")
    self.ui.playerDetailSummarySecondary:SetJustifyV("TOP")

    self.ui.playerDetailHeroNote = CreateFont(heroCard, 10, COLORS.subdued)
    self.ui.playerDetailHeroNote:SetPoint("TOPLEFT", self.ui.playerDetailSummarySecondary, "BOTTOMLEFT", 0, -6)
    self.ui.playerDetailHeroNote:SetPoint("TOPRIGHT", heroCard, "TOPRIGHT", -18, -106)
    self.ui.playerDetailHeroNote:SetJustifyH("LEFT")
    self.ui.playerDetailHeroNote:SetJustifyV("TOP")

    self.ui.playerDetailNoteIndicator = CreateFont(heroCard, 10, COLORS.accentSoft, "RIGHT")
    self.ui.playerDetailNoteIndicator:SetPoint("BOTTOMRIGHT", heroCard, "BOTTOMRIGHT", -18, 14)
    self.ui.playerDetailNoteIndicator:Hide()

    local chipsLabel = CreateFont(heroCard, 10, COLORS.subdued)
    chipsLabel:SetPoint("BOTTOMLEFT", heroCard, "BOTTOMLEFT", 108, 14)
    chipsLabel:SetText("")
    chipsLabel:Hide()

    local chipsContainer = CreateFrame("Frame", nil, heroCard)
    chipsContainer:SetPoint("BOTTOMRIGHT", heroCard, "BOTTOMRIGHT", -18, 12)
    chipsContainer:SetSize(0, 26)
    self.ui.playerDetailSpecChipsContainer = chipsContainer

    self.ui.playerDetailSpecChips = {}
    for index = 1, PLAYER_DETAIL_SPEC_CHIPS do
        local chip = CreateSpecChip(chipsContainer)
        chip:Hide()
        self.ui.playerDetailSpecChips[index] = chip
    end

    self.ui.playerDetailSpecChipEmpty = CreateFont(heroCard, 10, COLORS.subdued)
    self.ui.playerDetailSpecChipEmpty:SetPoint("LEFT", chipsContainer, "LEFT", 0, 0)
    self.ui.playerDetailSpecChipEmpty:SetText("")
    self.ui.playerDetailSpecChipEmpty:Hide()

    local noteCard = CreateFrame("Frame", nil, detailView)
    noteCard:SetPoint("TOPLEFT", heroCard, "BOTTOMLEFT", 0, -12)
    noteCard:SetPoint("TOPRIGHT", heroCard, "TOPRIGHT", 0, -12)
    noteCard:SetHeight(118)
    self:ApplySurface(noteCard, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
    self.ui.playerDetailNoteCard = noteCard

    local noteTitle = CreateFont(noteCard, 13, COLORS.text)
    noteTitle:SetPoint("TOPLEFT", 16, -14)
    noteTitle:SetText("Private note")

    local noteHint = CreateFont(noteCard, 10, COLORS.subdued)
    noteHint:SetPoint("LEFT", noteTitle, "RIGHT", 10, 0)
    noteHint:SetText("")
    noteHint:Hide()
    self.ui.playerDetailNoteHint = noteHint

    self.ui.playerDetailNoteSave = CreateActionButton(noteCard, 78, 28, "Save")
    self.ui.playerDetailNoteSave:SetPoint("TOPRIGHT", -16, -10)
    self.ui.playerDetailNoteSave:SetScript("OnClick", function()
        MythicTools:SaveSelectedPlayerNote()
    end)

    self.ui.playerDetailNoteEditor = CreateMultilineNoteEditor(noteCard, 836, 96)
    self.ui.playerDetailNoteEditor:ClearAllPoints()
    self.ui.playerDetailNoteEditor:SetPoint("TOPLEFT", noteCard, "TOPLEFT", 16, -42)
    self.ui.playerDetailNoteEditor:SetPoint("TOPRIGHT", noteCard, "TOPRIGHT", -16, -42)
    self.ui.playerDetailNoteEditor:SetPoint("BOTTOMLEFT", noteCard, "BOTTOMLEFT", 16, 30)
    self.ui.playerDetailNoteEditor:SetPoint("BOTTOMRIGHT", noteCard, "BOTTOMRIGHT", -16, 30)

    self.ui.playerDetailNoteStatus = CreateFont(noteCard, 10, COLORS.subdued)
    self.ui.playerDetailNoteStatus:SetPoint("BOTTOMLEFT", 16, 12)
    self.ui.playerDetailNoteStatus:SetText("Up to 160 characters.")

    local historyCard = CreateFrame("Frame", nil, detailView)
    historyCard:SetPoint("TOPLEFT", noteCard, "BOTTOMLEFT", 0, -12)
    historyCard:SetPoint("TOPRIGHT", noteCard, "TOPRIGHT", 0, -12)
    historyCard:SetPoint("BOTTOMLEFT", detailView, "BOTTOMLEFT", 12, 12)
    historyCard:SetPoint("BOTTOMRIGHT", detailView, "BOTTOMRIGHT", -12, 12)
    self:ApplySurface(historyCard, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)
    ClipChildren(historyCard)
    self.ui.playerDetailHistoryCard = historyCard

    local historyTitle = CreateFont(historyCard, 13, COLORS.text)
    historyTitle:SetPoint("TOPLEFT", 16, -14)
    historyTitle:SetText("Last Runs")

    self.ui.playerDetailHistoryCount = CreateFont(historyCard, 11, COLORS.muted, "RIGHT")
    self.ui.playerDetailHistoryCount:SetPoint("TOPRIGHT", -16, -14)

    self.ui.playerDetailSeeAllButton = CreateActionButton(historyCard, 86, 20, "See all")
    self.ui.playerDetailSeeAllButton:SetPoint("TOPRIGHT", historyCard, "TOPRIGHT", -16, -10)
    self.ui.playerDetailSeeAllButton:SetScript("OnClick", function()
        local playerEntry = MythicTools:GetSelectedPlayerEntry()
        if playerEntry then
            local name = playerEntry.shortName or playerEntry.fullName or ""
            MythicTools.db.ui.filters.player = name
            SetAceEditText(MythicTools.ui.runsPlayerFilter, name)
            MythicTools:SetRunViewMode("list")
            MythicTools:ShowTab("Runs")
        end
    end)

    local historyBody = CreateFrame("Frame", nil, historyCard)
    historyBody:SetPoint("TOPLEFT", 12, -42)
    historyBody:SetPoint("TOPRIGHT", -12, -42)
    historyBody:SetPoint("BOTTOMLEFT", 12, 12)
    historyBody:SetPoint("BOTTOMRIGHT", -12, 12)
    ClipChildren(historyBody)
    self.ui.playerDetailHistoryBody = historyBody

    self.ui.playerDetailHistoryRows = {}
    for index = 1, PLAYER_DETAIL_HISTORY_ROWS do
        local row = CreatePlayerDetailHistoryRow(historyBody)
        row:SetPoint("TOPLEFT", 0, -((index - 1) * PLAYER_DETAIL_HISTORY_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", 0, -((index - 1) * PLAYER_DETAIL_HISTORY_ROW_HEIGHT))
        row:SetScript("OnClick", function(button)
            if button.runId then
                MythicTools:ShowCompletionPopup(button.runId)
            end
        end)
        self.ui.playerDetailHistoryRows[index] = row
    end

    self.ui.playerDetailEmptyHistory = CreateFont(historyCard, 12, COLORS.muted, "CENTER")
    self.ui.playerDetailEmptyHistory:SetPoint("CENTER")
    self.ui.playerDetailEmptyHistory:SetText("No runs recorded for this player.")
    self.ui.playerDetailEmptyHistory:Hide()

    return page
end

function MythicTools:BuildSettingsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    ClipChildren(page)

    local generalCard = CreateFrame("Frame", nil, page)
    generalCard:SetPoint("TOPLEFT", 12, -12)
    generalCard:SetSize(350, 196)
    self:ApplySurface(generalCard, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)

    local generalTitle = CreateFont(generalCard, 16, COLORS.text)
    generalTitle:SetPoint("TOPLEFT", 16, -16)
    generalTitle:SetText("General")

    self.ui.settingsAlerts = CreateSettingToggle(generalCard, "Chat alerts", "Warn when someone from your history joins your group.", function(checked)
        self:SetChatAlertsEnabled(checked)
        self:RefreshSettingsView()
    end)
    self.ui.settingsAlerts:SetPoint("TOPLEFT", 16, -44)
    self.ui.settingsAlerts:SetPoint("TOPRIGHT", -16, -44)

    self.ui.settingsMinimap = CreateSettingToggle(generalCard, "Minimap button", "Show or hide the circular shortcut around the minimap.", function(checked)
        self:SetMinimapButtonEnabled(checked)
        self:RefreshSettingsView()
    end)
    self.ui.settingsMinimap:SetPoint("TOPLEFT", 16, -92)
    self.ui.settingsMinimap:SetPoint("TOPRIGHT", -16, -92)

    self.ui.settingsLootHistory = CreateSettingToggle(generalCard, "Show loot history", "Display dropped items in the run details and completion popup.", function(checked)
        self.db.settings.showLootHistory = checked and true or false
        self:RefreshAllViews()
    end)
    self.ui.settingsLootHistory:SetPoint("TOPLEFT", 16, -140)
    self.ui.settingsLootHistory:SetPoint("TOPRIGHT", -16, -140)

    local popupCard = CreateFrame("Frame", nil, page)
    popupCard:SetPoint("TOPLEFT", generalCard, "TOPRIGHT", 12, 0)
    popupCard:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -12)
    popupCard:SetHeight(242)
    self:ApplySurface(popupCard, COLORS.sectionBG, COLORS.surface, COLORS.accent)

    local popupTitle = CreateFont(popupCard, 16, COLORS.text)
    popupTitle:SetPoint("TOPLEFT", 16, -16)
    popupTitle:SetText("Completion popup")

    self.ui.settingsPopupEnabled = CreateSettingToggle(popupCard, "Open summary automatically", "Show the final window with loot, damage, healing, interrupts, DPS, and deaths.", function(checked)
        self.db.settings.showCompletionPopup = checked and true or false
        if not checked then
            self.runtime.pendingCompletionPopup = nil
            self:HideCompletionPopup()
        end
        self:RefreshSettingsView()
    end)
    self.ui.settingsPopupEnabled:SetPoint("TOPLEFT", 16, -44)
    self.ui.settingsPopupEnabled:SetPoint("TOPRIGHT", -16, -44)

    self.ui.settingsPopupTrigger = CreateCycleControl(popupCard, "Open timing", 190, GetPopupTriggerLabel, function()
        self.db.settings.completionPopupTrigger = GetPopupTriggerNext(self.db.settings.completionPopupTrigger or "COMPLETED")
        self.ui.settingsPopupTrigger:SetValue(self.db.settings.completionPopupTrigger)
        self:RefreshSettingsView()
    end)
    self.ui.settingsPopupTrigger:SetPoint("TOPLEFT", 16, -96)
    self.ui.settingsPopupDelay = CreateLabeledEditBox(popupCard, "Delay (0-10s)", 110, nil)
    self.ui.settingsPopupDelay:SetPoint("LEFT", self.ui.settingsPopupTrigger, "RIGHT", 14, 0)

    local popupDelayApply = CreateActionButton(popupCard, 78, 28, "Save")
    popupDelayApply:SetPoint("LEFT", self.ui.settingsPopupDelay, "RIGHT", 10, -11)
    popupDelayApply:SetScript("OnClick", function()
        self.db.settings.completionPopupDelay = self:Clamp(tonumber(self.ui.settingsPopupDelay.Input:GetText()) or 0, 0, 10)
        self:RefreshSettingsView()
    end)

    self.ui.settingsPopupScale = CreateLabeledEditBox(popupCard, "Scale (0.7-1.4)", 110, nil)
    self.ui.settingsPopupScale:SetPoint("TOPLEFT", 16, -148)

    local popupScaleApply = CreateActionButton(popupCard, 78, 28, "Apply")
    popupScaleApply:SetPoint("LEFT", self.ui.settingsPopupScale, "RIGHT", 10, -11)
    popupScaleApply:SetScript("OnClick", function()
        self.db.settings.completionPopupScale = self:Clamp(tonumber(self.ui.settingsPopupScale.Input:GetText()) or 1, 0.7, 1.4)
        self:ApplyCompletionPopupScale()
        self:RefreshSettingsView()
    end)

    local previewButton = CreateActionButton(popupCard, 160, 28, "Open preview")
    previewButton:SetPoint("TOPLEFT", self.ui.settingsPopupScale, "TOPRIGHT", 102, 0)
    previewButton:SetScript("OnClick", function()
        self:ShowTestCompletionPopup()
    end)

    local historyCard = CreateFrame("Frame", nil, page)
    historyCard:SetPoint("TOPLEFT", 12, -220)
    historyCard:SetSize(350, 184)
    self:ApplySurface(historyCard, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)

    local historyTitle = CreateFont(historyCard, 16, COLORS.text)
    historyTitle:SetPoint("TOPLEFT", 16, -16)
    historyTitle:SetText("History")

    self.ui.settingsMaxRuns = CreateLabeledEditBox(historyCard, "Saved runs", 120, nil)
    self.ui.settingsMaxRuns:SetPoint("TOPLEFT", 16, -44)

    local applyMaxRuns = CreateActionButton(historyCard, 84, 28, "Apply")
    applyMaxRuns:SetPoint("LEFT", self.ui.settingsMaxRuns, "RIGHT", 10, -11)
    applyMaxRuns:SetScript("OnClick", function()
        self:SetMaxRuns(self.ui.settingsMaxRuns.Input:GetText())
        self:RefreshUI()
    end)

    local clearButton = CreateActionButton(historyCard, 150, 28, "Clear history")
    clearButton:SetPoint("TOPLEFT", 16, -108)
    clearButton:SetScript("OnClick", function()
        StaticPopup_Show("MYTHICTOOLS_CLEAR_HISTORY")
    end)

    local historyNote = CreateFont(historyCard, 10, COLORS.subdued)
    historyNote:SetPoint("TOPLEFT", clearButton, "BOTTOMLEFT", 0, -10)
    historyNote:SetPoint("RIGHT", historyCard, "RIGHT", -16, 0)
    historyNote:SetJustifyH("LEFT")
    historyNote:SetText("History is shared across every character on this account.")

    local summaryCard = CreateFrame("Frame", nil, page)
    summaryCard:SetPoint("TOPLEFT", popupCard, "BOTTOMLEFT", 0, -12)
    summaryCard:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 12)
    self:ApplySurface(summaryCard, COLORS.sectionBG, COLORS.surface, COLORS.accentSoft)

    local summaryTitle = CreateFont(summaryCard, 16, COLORS.text)
    summaryTitle:SetPoint("TOPLEFT", 16, -16)
    summaryTitle:SetText("Summary")

    self.ui.settingsSummary = CreateFont(summaryCard, 12, COLORS.muted)
    self.ui.settingsSummary:SetPoint("TOPLEFT", summaryTitle, "BOTTOMLEFT", 0, -14)
    self.ui.settingsSummary:SetPoint("RIGHT", summaryCard, "RIGHT", -16, 0)
    self.ui.settingsSummary:SetJustifyH("LEFT")
    self.ui.settingsSummary:SetJustifyV("TOP")

    if not StaticPopupDialogs.MYTHICTOOLS_CLEAR_HISTORY then
        StaticPopupDialogs.MYTHICTOOLS_CLEAR_HISTORY = {
            text = "Clear every saved Sky Mythic History run?",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                MythicTools:ClearHistory()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    if not StaticPopupDialogs.MYTHICTOOLS_DELETE_RUN then
        StaticPopupDialogs.MYTHICTOOLS_DELETE_RUN = {
            text = "Delete this run from Sky Mythic History?\n%s",
            button1 = YES,
            button2 = NO,
            OnAccept = function(_, runId)
                if MythicTools:RemoveRunById(runId) then
                    MythicTools:HideCompletionPopup()
                    MythicTools:SetRunViewMode("list")
                    MythicTools:RefreshAllViews()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    return page
end

function MythicTools:StoreCompletionPopupPoint()
    if not (self.completionPopup and self.db and self.db.ui) then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = self.completionPopup:GetPoint(1)
    self.db.ui.completionPopupPoint = {point or "CENTER", relativePoint or point or "CENTER", xOfs or 0, yOfs or 0}
end
function MythicTools:BuildCompletionPopup()
    if self.completionPopup then
        return self.completionPopup
    end

    local frame = CreateFrame("Frame", "MythicToolsCompletionPopup", UIParent)
    frame:SetSize(980, COMPLETION_POPUP_HEIGHT)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(400)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetToplevel(true)
    frame:Hide()
    self:ApplySurface(frame, COLORS.frameBG, COLORS.frameBorder, COLORS.accent)

    frame.Background = frame:CreateTexture(nil, "BACKGROUND")
    frame.Background:SetAllPoints()
    frame.Background:SetAlpha(0.10)

    local point = self.db.ui.completionPopupPoint or {"CENTER", "CENTER", 0, 40}
    frame:SetPoint(point[1] or "CENTER", UIParent, point[2] or point[1] or "CENTER", point[3] or 0, point[4] or 40)
    table.insert(UISpecialFrames, frame:GetName())

    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(116)
    header:SetBackdrop({bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = 1, insets = {left=1, right=1, top=1, bottom=1}})
    header:SetBackdropColor(COLORS.headerBG[1], COLORS.headerBG[2], COLORS.headerBG[3], 1)
    header:SetBackdropBorderColor(0, 0, 0, 1)

    header.Background = header:CreateTexture(nil, "BACKGROUND", nil, 1)
    header.Background:SetAllPoints()
    header.Background:SetAlpha(0.18)
    self.completionPopupHeroBackground = header.Background

    -- Linha accent na base do header do popup
    local popupHeaderLine = header:CreateTexture(nil, "OVERLAY")
    popupHeaderLine:SetTexture(WHITE_TEXTURE)
    popupHeaderLine:SetPoint("BOTTOMLEFT", 1, 0)
    popupHeaderLine:SetPoint("BOTTOMRIGHT", -1, 0)
    popupHeaderLine:SetHeight(1)
    popupHeaderLine:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.8)

    local iconFrame = CreateFrame("Frame", nil, header)
    iconFrame:SetSize(76, 76)
    iconFrame:SetPoint("TOPLEFT", 18, -18)
    self:ApplySurface(iconFrame, COLORS.frameBG, COLORS.surface, nil)

    iconFrame.Icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.Icon:SetPoint("TOPLEFT", 1, -1)
    iconFrame.Icon:SetPoint("BOTTOMRIGHT", -1, 1)
    self.completionPopupHeroIcon = iconFrame.Icon

    frame.Title = CreateFont(header, 22, COLORS.text)
    frame.Title:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 16, -2)
    frame.Title:SetPoint("RIGHT", header, "RIGHT", -154, 0)

    frame.Meta = CreateFont(header, 12, COLORS.muted)
    frame.Meta:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -8)
    frame.Meta:SetPoint("RIGHT", header, "RIGHT", -18, 0)
    frame.Meta:SetJustifyH("LEFT")

    frame.Submeta = CreateFont(header, 11, COLORS.text)
    frame.Submeta:SetPoint("TOPLEFT", frame.Meta, "BOTTOMLEFT", 0, -4)
    frame.Submeta:SetPoint("RIGHT", header, "RIGHT", -18, 0)
    frame.Submeta:SetJustifyH("LEFT")

    frame.Note = CreateFont(header, 10, COLORS.subdued)
    frame.Note:SetPoint("TOPLEFT", frame.Submeta, "BOTTOMLEFT", 0, -5)
    frame.Note:SetPoint("RIGHT", header, "RIGHT", -18, 0)
    frame.Note:SetJustifyH("LEFT")

    frame.Status = CreateFont(header, 14, COLORS.accent, "RIGHT")

    -- Botão fechar estilo Cell no popup
    local closeButton = CreateFrame("Button", nil, header, "BackdropTemplate")
    closeButton:SetSize(20, 20)
    closeButton:SetPoint("TOPRIGHT", -8, -8)
    closeButton:SetBackdrop({bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = 1, insets = {left=1, right=1, top=1, bottom=1}})
    closeButton:SetBackdropColor(0.6, 0.1, 0.1, 0.6)
    closeButton:SetBackdropBorderColor(0, 0, 0, 1)
    closeButton:SetScript("OnEnter", function() closeButton:SetBackdropColor(0.6, 0.1, 0.1, 1) end)
    closeButton:SetScript("OnLeave", function() closeButton:SetBackdropColor(0.6, 0.1, 0.1, 0.6) end)
    closeButton:SetScript("OnClick", function()
        MythicTools:HideCompletionPopup()
    end)
    local closeText = closeButton:CreateFontString(nil, "OVERLAY")
    closeText:SetFont(STANDARD_TEXT_FONT, 14, "")
    closeText:SetText("×")
    closeText:SetAllPoints()
    closeText:SetJustifyH("CENTER")
    closeText:SetJustifyV("MIDDLE")
    closeText:SetTextColor(1, 1, 1, 1)
    closeText:SetShadowColor(0, 0, 0)
    closeText:SetShadowOffset(1, -1)

    frame.Status:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -16, 0)

    frame:SetMovable(true)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:StoreCompletionPopupPoint()
    end)

    local statsPanel = CreateFrame("Frame", nil, frame)
    statsPanel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    statsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
    self:ApplySurface(statsPanel, COLORS.panelBG, COLORS.surface, nil)
    ClipChildren(statsPanel)

    local columnName = CreateFont(statsPanel, 11, COLORS.subdued)
    columnName:SetPoint("TOPLEFT", 16, -12)
    columnName:SetText("Player")

    local columnScore = CreateFont(statsPanel, 11, COLORS.subdued)
    columnScore:SetPoint("TOPLEFT", COMPACT_STATS_SCORE_X, -12)
    columnScore:SetText("M+ score")

    local columnItems = CreateFont(statsPanel, 11, COLORS.subdued)
    columnItems:SetPoint("TOPLEFT", COMPACT_STATS_ITEMS_X, -12)
    columnItems:SetText("Loot")

    local columnDamage = CreateFont(statsPanel, 11, COLORS.subdued)
    columnDamage:SetPoint("TOPLEFT", COMPACT_STATS_DAMAGE_X, -12)
    columnDamage:SetText("Damage")

    local columnDPS = CreateFont(statsPanel, 11, COLORS.subdued)
    columnDPS:SetPoint("TOPLEFT", COMPACT_STATS_DPS_X, -12)
    columnDPS:SetText("DPS")

    local columnHealing = CreateFont(statsPanel, 11, COLORS.subdued)
    columnHealing:SetPoint("TOPLEFT", COMPACT_STATS_HEALING_X, -12)
    columnHealing:SetText("Healing")

    local columnInterrupts = CreateFont(statsPanel, 11, COLORS.subdued)
    columnInterrupts:SetPoint("TOPLEFT", COMPACT_STATS_INTERRUPTS_X, -12)
    columnInterrupts:SetText("Interrupts")

    local columnDeaths = CreateFont(statsPanel, 11, COLORS.subdued)
    columnDeaths:SetPoint("TOPLEFT", COMPACT_STATS_DEATHS_X, -12)
    columnDeaths:SetText("Deaths")

    local rowsBody = CreateFrame("Frame", nil, statsPanel)
    rowsBody:SetPoint("TOPLEFT", 12, -34)
    rowsBody:SetPoint("TOPRIGHT", -14, -34)
    rowsBody:SetHeight(COMPLETION_ROWS * COMPLETION_ROW_HEIGHT)
    ClipChildren(rowsBody)
    frame.rowsBody = rowsBody

    frame.rowsScroll = CreateFrame("ScrollFrame", nil, statsPanel, "FauxScrollFrameTemplate")
    frame.rowsScroll:SetPoint("TOPLEFT", 0, -34)
    frame.rowsScroll:SetPoint("BOTTOMRIGHT", -10, 12)
    frame.rowsScroll:SetScript("OnVerticalScroll", function(scrollFrame, offset)
        FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, COMPLETION_ROW_HEIGHT, function()
            MythicTools:RefreshCompletionPopup()
        end)
    end)
    ApplyThinScrollBar(frame.rowsScroll)

    frame.rows = {}
    for index = 1, COMPLETION_ROWS do
        local row = CreateCompletionStatRow(rowsBody)
        row:SetPoint("TOPLEFT", 0, -((index - 1) * COMPLETION_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", 0, -((index - 1) * COMPLETION_ROW_HEIGHT))
        frame.rows[index] = row
    end

    local deleteButton = CreateActionButton(statsPanel, 92, 24, "Delete")
    deleteButton:SetPoint("BOTTOMRIGHT", statsPanel, "BOTTOMRIGHT", -12, 8)
    deleteButton:SetScript("OnClick", function()
        local runId = frame and frame.runId
        if runId then
            MythicTools:ConfirmDeleteRun(runId)
        end
    end)
    frame.DeleteButton = deleteButton

    self.completionPopup = frame
    self:ApplyCompletionPopupScale()
    return frame
end

function MythicTools:HideCompletionPopup()
    if self.completionPopup then
        self.completionPopup.runId = nil
        self.completionPopup.previewRun = nil
        self.completionPopup:Hide()
    end
    if self.db and self.db.ui then
        self.db.ui.selectedRunId = nil
    end
    if self.ui then
        self:RefreshRunView()
    end
end

function MythicTools:ShowCompletionPopup(runOrRunId)
    local previewRun = type(runOrRunId) == "table" and runOrRunId or nil
    local runId = previewRun and previewRun.runId or runOrRunId
    if not previewRun and not runId then
        return
    end

    if self.PushRuntimeDebug then
        self:PushRuntimeDebug(("show completion popup run %s preview=%s"):format(
            tostring(runId or (previewRun and previewRun.runId) or "?"),
            tostring(previewRun ~= nil)
        ))
    end

    local frame = self:BuildCompletionPopup()
    frame.previewRun = previewRun
    frame.runId = previewRun and nil or runId
    self:ApplyCompletionPopupScale()
    self:RefreshCompletionPopup()
    frame:Show()
    frame:Raise()
end
function MythicTools:RefreshCompletionPopup()
    local frame = self.completionPopup
    if not frame then
        return
    end

    local run = frame.previewRun or (frame.runId and self:GetRunById(frame.runId)) or nil
    if not run then
        if self.PushRuntimeDebug then
            self:PushRuntimeDebug(("hide completion popup missing run %s"):format(tostring(frame.runId or "?")))
        end
        if self.StoreDebugReport then
            self:StoreDebugReport("popup_missing_run", {
                trigger = "RefreshCompletionPopup",
                runId = frame.runId,
            })
        end
        frame.runId = nil
        frame.previewRun = nil
        frame:Hide()
        return
    end

    if frame.DeleteButton then
        frame.DeleteButton:SetShown(not frame.previewRun and run.runId ~= nil)
    end

    self:SetRunArt(self.completionPopupHeroIcon, self.completionPopupHeroBackground, run)
    frame.Title:SetText(("%s +%d"):format(run.dungeonName or "Unknown", run.level or 0))
    frame.Meta:SetText(("%s  •  Time %s  •  Deaths %d"):format(
        self:FormatDateTime(run.endTime),
        self:FormatDurationMS(run.timeMS),
        run.totalDeaths or 0
    ))
    local upgradeText = GetRunUpgradeText(run)
    local scoreText = GetRunScoreText(run)
    local outOfCombatText = GetRunOutOfCombatText(run)
    local submeta = ("Time limit %s  •  Loot recorded %d item%s"):format(
        self:FormatDurationSeconds(run.timeLimitSeconds),
        self:GetRunLootCount(run),
        self:GetRunLootCount(run) == 1 and "" or "s"
    )
    if upgradeText ~= "" then
        submeta = submeta .. ("  •  Upgrade %s"):format(upgradeText)
    end
    if scoreText ~= "" then
        submeta = submeta .. ("  •  %s"):format(scoreText)
    end
    if outOfCombatText ~= "" then
        submeta = submeta .. ("  •  %s"):format(outOfCombatText)
    end
    local statsSourceText = GetRunStatsSourceText(run)
    if statsSourceText ~= "" then
        submeta = submeta .. ("  •  %s"):format(statsSourceText)
    end
    frame.Submeta:SetText(submeta)
    frame.Status:SetText(GetRunStatusText(run))
    SetTextColor(frame.Status, GetRunStatusColor(run))

    local noteParts = {}
    if run.preview then
        noteParts[#noteParts + 1] = "Preview"
    end
    if run.statsNote and run.statsNote ~= "" then
        noteParts[#noteParts + 1] = run.statsNote
    end
    if self.runtime and self.runtime.lootTracking and run.runId and self.runtime.lootTracking.runId == run.runId then
        noteParts[#noteParts + 1] = self.runtime.lootTracking.lootClosed and "Finalizing loot collection..." or "Waiting for chest loot..."
    end
    frame.Note:SetText(table.concat(noteParts, "  |  "))
    SetTextColor(frame.Note, run.statsUnavailable and COLORS.danger or COLORS.subdued)

    local sortedStats = self:GetSortedStatsForRun(run)
    if frame.rowsScroll then
        FauxScrollFrame_Update(frame.rowsScroll, #sortedStats, COMPLETION_ROWS, COMPLETION_ROW_HEIGHT)
    end
    local offset = frame.rowsScroll and FauxScrollFrame_GetOffset(frame.rowsScroll) or 0
    for index, row in ipairs(frame.rows) do
        local stat = sortedStats[offset + index]
        if stat then
            row:Show()
            if row.PlayerButton then
                row.PlayerButton.playerName = stat.name
            end
            self:SetPortraitWidget(row.Portrait, stat.name, stat.classFilename, stat.specIconID)

            local classColor = stat.classFilename and RAID_CLASS_COLORS and RAID_CLASS_COLORS[stat.classFilename]
            if classColor then
                row.Name:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
            else
                SetTextColor(row.Name, COLORS.text)
            end

            row.Name:SetText(stat.shortName or self:GetShortName(stat.name or ""))
            row.Score:SetText(GetPlayerScoreDisplayText(stat))
            self:SetLootButtons(row.LootButtons, row.LootLabel, row.LootOverflow, row.LootEmpty, stat.loot, row.LootTextButtons)
            row.Damage:SetText(self:FormatAmount(stat.damage))
            row.DPS:SetText(self:FormatAmount(self:GetPlayerDPS(run, stat)))
            row.Healing:SetText(self:FormatAmount(stat.healing))
            row.Interrupts:SetText(tostring(stat.interrupts or 0))
            row.Deaths:SetText(tostring(stat.deaths or 0))
            SetTextColor(row.Score, GetPlayerScoreColor(stat))
            SetTextColor(row.DPS, (stat.damage or 0) > 0 and COLORS.accentSoft or COLORS.text)
            SetTextColor(row.Interrupts, (stat.interrupts or 0) > 0 and COLORS.accentSoft or COLORS.text)
            SetTextColor(row.Deaths, (stat.deaths or 0) > 0 and COLORS.danger or COLORS.text)
        else
            if row.PlayerButton then
                row.PlayerButton.playerName = nil
            end
            row.Score:SetText("")
            row.DPS:SetText("")
            self:ResetLootButtons(row.LootButtons, row.LootLabel, row.LootOverflow, row.LootEmpty, row.LootTextButtons)
            row:Hide()
        end
    end
end

function MythicTools:UpdateMinimapButtonPosition()
    if not (self.minimapButton and Minimap and self.db and self.db.settings) then
        return
    end

    local angle = tonumber(self.db.settings.minimapAngle) or -35
    local radius = 78
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", cos(rad(angle)) * radius, sin(rad(angle)) * radius)
end

function MythicTools:CreateMinimapButton()
    if self.minimapButton or not Minimap then
        return self.minimapButton
    end

    local button = CreateFrame("Button", "MythicToolsMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.Border = button:CreateTexture(nil, "OVERLAY")
    button.Border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.Border:SetSize(54, 54)
    button.Border:SetPoint("TOPLEFT")

    button.Bg = button:CreateTexture(nil, "BACKGROUND")
    button.Bg:SetTexture("Interface\\Minimap\\TRACKINGBACKGROUND")
    button.Bg:SetPoint("TOPLEFT", 6, -6)
    button.Bg:SetPoint("BOTTOMRIGHT", -6, 6)
    button.Bg:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.Bg:SetVertexColor(0.18, 0.28, 0.34, 1)

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetPoint("TOPLEFT", 7, -7)
    button.Icon:SetPoint("BOTTOMRIGHT", -7, 7)
    button.Icon:SetTexture(DEFAULT_DUNGEON_ICON)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.Label = CreateFont(button, 10, COLORS.bright, "CENTER")
    button.Label:SetPoint("CENTER", 0, 9)
    button.Label:SetText("M+")

    button:SetHighlightTexture(WHITE_TEXTURE)
    local highlight = button:GetHighlightTexture()
    highlight:SetAllPoints()
    highlight:SetVertexColor(1, 1, 1, 0.10)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Sky Mythic History", COLORS.text[1], COLORS.text[2], COLORS.text[3])
        GameTooltip:AddLine("Left click: open history", COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        GameTooltip:AddLine("Right click: open settings", COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            MythicTools:ToggleMainFrame(true)
            MythicTools:ShowTab("Settings")
        else
            MythicTools:ToggleMainFrame()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local centerX, centerY = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale() or 1
            local cursorX, cursorY = GetCursorPosition()
            cursorX = cursorX / scale
            cursorY = cursorY / scale
            MythicTools.db.settings.minimapAngle = deg(atan2(cursorY - centerY, cursorX - centerX))
            MythicTools:UpdateMinimapButtonPosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        MythicTools:UpdateMinimapButtonPosition()
    end)

    self.minimapButton = button
    return button
end

function MythicTools:UpdateMinimapButton()
    if not (self.db and self.db.settings) then
        return
    end

    local button = self:CreateMinimapButton()
    if not button then
        return
    end

    if self.db.settings.showMinimapButton then
        self:UpdateMinimapButtonPosition()
        button:Show()
    else
        button:Hide()
    end
end
function MythicTools:BuildUI()
    if self.ui then
        return self.ui
    end

    local ui = {}
    self.ui = ui

    local frame = CreateFrame("Frame", "MythicToolsMainFrame", UIParent)
    frame:SetSize(self.db.ui.width, self.db.ui.height)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()
    self:ApplySurface(frame, COLORS.frameBG, COLORS.frameBorder, COLORS.accent)

    frame.Background = frame:CreateTexture(nil, "BACKGROUND")
    frame.Background:SetAllPoints()
    frame.Background:SetTexture(DEFAULT_DUNGEON_BG)
    frame.Background:SetAlpha(0.06)

    local point = self.db.ui.point or {"CENTER", "CENTER", 0, 0}
    frame:SetPoint(point[1] or "CENTER", UIParent, point[2] or point[1] or "CENTER", point[3] or 0, point[4] or 0)
    table.insert(UISpecialFrames, frame:GetName())
    ui.frame = frame

    -- Header: estilo Cell — barra escura compacta com título na cor de classe
    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(36)
    header:SetBackdrop({bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = 1, insets = {left=1, right=1, top=1, bottom=1}})
    header:SetBackdropColor(COLORS.headerBG[1], COLORS.headerBG[2], COLORS.headerBG[3], 1)
    header:SetBackdropBorderColor(0, 0, 0, 1)

    -- Linha de destaque na cor de classe na base do header
    local headerAccentLine = header:CreateTexture(nil, "OVERLAY")
    headerAccentLine:SetTexture(WHITE_TEXTURE)
    headerAccentLine:SetPoint("BOTTOMLEFT", 1, 0)
    headerAccentLine:SetPoint("BOTTOMRIGHT", -1, 0)
    headerAccentLine:SetHeight(1)
    headerAccentLine:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.8)

    local title = CreateFont(header, 13, COLORS.accent)
    title:SetPoint("LEFT", 14, 0)
    title:SetText("Sky Mythic History")

    -- Botão fechar estilo Cell (× vermelho)
    local closeButton = CreateFrame("Button", nil, header, "BackdropTemplate")
    closeButton:SetSize(20, 20)
    closeButton:SetPoint("RIGHT", -6, 0)
    closeButton:SetBackdrop({bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = 1, insets = {left=1, right=1, top=1, bottom=1}})
    closeButton:SetBackdropColor(0.6, 0.1, 0.1, 0.6)
    closeButton:SetBackdropBorderColor(0, 0, 0, 1)
    closeButton:SetScript("OnEnter", function() closeButton:SetBackdropColor(0.6, 0.1, 0.1, 1) end)
    closeButton:SetScript("OnLeave", function() closeButton:SetBackdropColor(0.6, 0.1, 0.1, 0.6) end)
    closeButton:SetScript("OnClick", function()
        MythicTools:HideCompletionPopup()
        frame:Hide()
    end)
    local closeText = closeButton:CreateFontString(nil, "OVERLAY")
    closeText:SetFont(STANDARD_TEXT_FONT, 14, "")
    closeText:SetText("×")
    closeText:SetAllPoints()
    closeText:SetJustifyH("CENTER")
    closeText:SetJustifyV("MIDDLE")
    closeText:SetTextColor(1, 1, 1, 1)
    closeText:SetShadowColor(0, 0, 0)
    closeText:SetShadowOffset(1, -1)

    frame:SetMovable(true)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:StoreMainFramePoint()
    end)

    -- Sidebar estilo Cell
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(204)
    self:ApplySurface(sidebar, COLORS.panelBG, COLORS.surface, COLORS.accentSoft)

    -- Separador de navegação estilo Cell
    local sidebarTitle = CreateFont(sidebar, 11, COLORS.accent)
    sidebarTitle:SetPoint("TOPLEFT", 14, -14)
    sidebarTitle:SetText("Navigation")
    local sidebarTitleLine = sidebar:CreateTexture(nil, "ARTWORK")
    sidebarTitleLine:SetTexture(WHITE_TEXTURE)
    sidebarTitleLine:SetPoint("TOPLEFT", sidebarTitle, "BOTTOMLEFT", 0, -3)
    sidebarTitleLine:SetWidth(176)
    sidebarTitleLine:SetHeight(1)
    sidebarTitleLine:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.5)

    ui.tabButtons = {}
    for index, tabName in ipairs({"Runs", "Players", "Stats", "Settings"}) do
        local button = CreateActionButton(sidebar, 176, 30, tabName)
        button:SetPoint("TOPLEFT", 14, -34 - ((index - 1) * 38))
        button:SetScript("OnClick", function()
            if tabName == "Players" then
                self.db.ui.playersView = "index"
                self.db.ui.selectedPlayer = nil
            end
            self:ShowTab(tabName)
        end)
        ui.tabButtons[tabName] = button
    end

    ui.sidebarRuns = CreateSidebarMetric(sidebar, "Saved runs")
    ui.sidebarRuns:SetPoint("TOPLEFT", 14, -200)

    ui.sidebarPlayers = CreateSidebarMetric(sidebar, "Indexed players")
    ui.sidebarPlayers:SetPoint("TOPLEFT", 14, -262)

    ui.sidebarStatus = CreateSidebarMetric(sidebar, "No active run")
    ui.sidebarStatus:SetPoint("TOPLEFT", 14, -324)

    local footer = CreateFont(sidebar, 10, COLORS.subdued)
    footer:SetPoint("BOTTOMLEFT", 14, 12)
    footer:SetText(("v%s"):format(self.version or "0.3.0"))

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    self:ApplySurface(content, COLORS.panelBG, COLORS.surface, nil)
    ClipChildren(content)

    ui.pages = {}
    ui.pages.Runs = self:BuildRunsPage(content)
    ui.pages.Players = self:BuildPlayersPage(content)
    ui.pages.Stats = self:BuildStatsPage(content)
    ui.pages.Settings = self:BuildSettingsPage(content)

    for pageName, page in pairs(ui.pages) do
        page:SetShown(pageName == (self.db.ui.activeTab or "Runs"))
    end

    frame:SetScript("OnShow", function()
        self:RefreshUI()
    end)

    SetAceEditText(self.ui.runsSearch, self.db.ui.filters.search)
    SetAceEditText(self.ui.runsPlayerFilter, self.db.ui.filters.player)
    SetAceDropdownValue(self.ui.runsSeasonFilter, self.db.ui.filters.season)
    UpdateAceDropdownOptions(self.ui.runsDungeonFilter, GetDungeonOptionsForSeason(self.db.ui.filters.season), self.db.ui.filters.dungeon)
    SetAceEditText(self.ui.runsDateFilter, self.db.ui.filters.date)
    SetAceDropdownValue(self.ui.runsStatusFilter, self.db.ui.filters.status)
    self:RefreshOwnedCharacterFilterOptions()
    SetAceEditText(self.ui.playerSearch, (self.db.ui.playerFilters and self.db.ui.playerFilters.search) or self.db.ui.playerSearch)
    SetAceDropdownValue(self.ui.playersSeasonFilter, (self.db.ui.playerFilters and self.db.ui.playerFilters.season) or "season1")
    UpdateAceDropdownOptions(self.ui.playersDungeonFilter, GetDungeonOptionsForSeason((self.db.ui.playerFilters and self.db.ui.playerFilters.season) or "season1"), (self.db.ui.playerFilters and self.db.ui.playerFilters.dungeon) or "all")

    if self.UpdateMinimapButton then
        self:UpdateMinimapButton()
    end
    if self.InitializeUnitPopupMenu then
        self:InitializeUnitPopupMenu()
    end

    return ui
end
