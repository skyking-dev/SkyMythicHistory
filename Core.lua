local ADDON_NAME, ns = ...

local MythicTools = {}
ns.MythicTools = MythicTools
_G.MythicTools = MythicTools

MythicTools.name = ADDON_NAME
MythicTools.version = C_AddOns and C_AddOns.GetAddOnMetadata and (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.3.0") or "0.3.0"
MythicTools.DB_VERSION = 7

local canaccessvalue = canaccessvalue or function(value)
    return value ~= nil
end

local canaccesstable = canaccesstable or function(value)
    return type(value) == "table"
end

local floor = math.floor
local min = math.min
local max = math.max

local function SafeToNumber(value)
    if type(value) == "number" then
        return value
    end

    if type(value) == "string" then
        return tonumber(value)
    end

    return nil
end

function MythicTools:CanAccessValue(value)
    return value ~= nil and canaccessvalue(value)
end

function MythicTools:CanAccessTable(value)
    return type(value) == "table" and canaccesstable(value)
end

function MythicTools:GetLocalRealmName()
    if self.localRealmName and self.localRealmName ~= "" then
        return self.localRealmName
    end

    local normalizedRealm = GetNormalizedRealmName and GetNormalizedRealmName() or nil
    if normalizedRealm and normalizedRealm ~= "" then
        self.localRealmName = normalizedRealm
        return self.localRealmName
    end

    local realmName = GetRealmName and GetRealmName() or ""
    self.localRealmName = realmName:gsub("[%s%-]", "")
    return self.localRealmName
end

function MythicTools:TrimText(text)
    if type(text) ~= "string" then
        return ""
    end

    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

function MythicTools:NormalizePlayerName(name, realm)
    if type(name) ~= "string" then
        return nil
    end

    name = self:TrimText(name)
    if name == "" then
        return nil
    end

    if name:find("%-") then
        local shortName, realmPart = name:match("^([^%-]+)%-(.+)$")
        if shortName and realmPart and realmPart ~= "" then
            return shortName .. "-" .. realmPart:gsub("[%s%-]", "")
        end
    end

    realm = type(realm) == "string" and realm:gsub("[%s%-]", "") or ""
    if realm == "" then
        realm = self:GetLocalRealmName()
    end

    if realm == "" then
        return name
    end

    return name .. "-" .. realm
end

function MythicTools:GetUnitFullName(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local name, realm = UnitFullName(unit)
    if not self:CanAccessValue(name) then
        return nil
    end

    return self:NormalizePlayerName(name, realm)
end

function MythicTools:GetShortName(fullName)
    if type(fullName) ~= "string" then
        return ""
    end

    return fullName:match("^[^%-]+") or fullName
end

function MythicTools:NormalizeRole(role)
    if type(role) ~= "string" then
        return nil
    end

    local normalized = role:upper()
    if normalized == "NONE" or normalized == "" then
        return nil
    end
    if normalized == "DPS" or normalized == "DAMAGE" or normalized == "DAMAGER" then
        return "DAMAGER"
    end
    if normalized == "HEAL" or normalized == "HEALING" or normalized == "HEALER" then
        return "HEALER"
    end
    if normalized == "TANK" then
        return "TANK"
    end
    if normalized == "DAMAGER" or normalized == "HEALER" then
        return normalized
    end

    return nil
end

function MythicTools:GetRoleLabel(role)
    local normalized = self:NormalizeRole(role)
    if normalized == "TANK" then
        return "Tank"
    end
    if normalized == "HEALER" then
        return "Healer"
    end
    if normalized == "DAMAGER" then
        return "DPS"
    end
    return "Unknown"
end

function MythicTools:GetSpecInfo(specID)
    if not specID or specID == 0 or not GetSpecializationInfoByID then
        return nil, nil, nil
    end

    local resolvedSpecID, specName, _, specIconID, role = GetSpecializationInfoByID(specID)
    return resolvedSpecID or specID, specName, specIconID, self:NormalizeRole(role)
end

function MythicTools:GetUnitRoleSpecInfo(unit)
    if not unit or not UnitExists(unit) then
        return nil, nil, nil, nil
    end

    local role = self:NormalizeRole(UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or nil)
    local specID, specName, specIconID

    if UnitIsUnit and UnitIsUnit(unit, "player") and GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization()
        if specIndex and specIndex > 0 then
            specID, specName, _, specIconID, role = GetSpecializationInfo(specIndex)
            role = self:NormalizeRole(role)
        end
    elseif GetInspectSpecialization then
        local inspectedSpecID = GetInspectSpecialization(unit)
        if inspectedSpecID and inspectedSpecID > 0 then
            specID, specName, specIconID, role = self:GetSpecInfo(inspectedSpecID)
        end
    end

    return role, specID, specName, specIconID
end

function MythicTools:Lower(text)
    return type(text) == "string" and text:lower() or ""
end

function MythicTools:ContainsText(haystack, needle)
    if not needle or needle == "" then
        return true
    end

    return self:Lower(haystack):find(self:Lower(needle), 1, true) ~= nil
end

function MythicTools:FormatDate(timestamp)
    if not timestamp or timestamp <= 0 then
        return "--"
    end

    return date("%d/%m/%Y", timestamp)
end

function MythicTools:FormatDateTime(timestamp)
    if not timestamp or timestamp <= 0 then
        return "--"
    end

    return date("%d/%m/%Y %H:%M", timestamp)
end

function MythicTools:FormatDurationMS(milliseconds)
    if not milliseconds or milliseconds <= 0 then
        return "--"
    end

    local totalSeconds = floor((milliseconds / 1000) + 0.5)
    local minutes = floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local hours = floor(minutes / 60)

    if hours > 0 then
        return ("%d:%02d:%02d"):format(hours, minutes % 60, seconds)
    end

    return ("%d:%02d"):format(minutes, seconds)
end

function MythicTools:FormatDurationSeconds(seconds)
    if not seconds or seconds <= 0 then
        return "--"
    end

    return self:FormatDurationMS(seconds * 1000)
end

function MythicTools:FormatAmount(value)
    if value == nil then
        return "--"
    end

    value = SafeToNumber(value) or 0
    value = floor(value + 0.5)

    if AbbreviateNumbers then
        return AbbreviateNumbers(value)
    end

    if AbbreviateLargeNumbers then
        return AbbreviateLargeNumbers(value)
    end

    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value)
    end

    return tostring(value)
end

function MythicTools:NormalizeRunResult(result, onTime)
    if result == "timed" or result == "overtime" or result == "abandoned" then
        return result
    end

    if onTime == true then
        return "timed"
    end

    if onTime == false then
        return "overtime"
    end

    return "overtime"
end

function MythicTools:GetRunResult(run)
    if type(run) ~= "table" then
        return "overtime"
    end

    return self:NormalizeRunResult(run.result, run.onTime)
end

function MythicTools:GetRunSeason(run)
    if type(run) ~= "table" then
        return "season1"
    end

    return run.season or "season1"
end

function MythicTools:IsPlayerGUID(guid)
    return type(guid) == "string" and guid:match("^Player%-") ~= nil
end

function MythicTools:IsRunPlayerEntry(fullName, stat)
    if type(fullName) ~= "string" or fullName == "" then
        return false
    end

    local guid = type(stat) == "table" and stat.guid or nil
    if guid ~= nil and guid ~= "" then
        return self:IsPlayerGUID(guid)
    end

    return true
end

function MythicTools:NormalizeRunRoster(run)
    if type(run) ~= "table" then
        return {}
    end

    local unique = {}
    local seen = {}
    local source = type(run.roster) == "table" and run.roster or {}
    local stats = type(run.playerStats) == "table" and run.playerStats or {}

    for _, fullName in ipairs(source) do
        if type(fullName) == "string" and fullName ~= "" and not seen[fullName] and self:IsRunPlayerEntry(fullName, stats[fullName]) then
            seen[fullName] = true
            unique[#unique + 1] = fullName
        end
    end

    if #unique == 0 then
        for fullName, stat in pairs(stats) do
            if type(fullName) == "string" and fullName ~= "" and not seen[fullName] and self:IsRunPlayerEntry(fullName, stat) then
                seen[fullName] = true
                unique[#unique + 1] = fullName
            end
        end
        table.sort(unique)
    end

    if #unique > 5 then
        while #unique > 5 do
            table.remove(unique)
        end
    end

    run.roster = unique
    return unique
end

function MythicTools:GetRunPlayerCount(run)
    return #(self:NormalizeRunRoster(run))
end

function MythicTools:ColorText(text, color)
    if type(color) ~= "string" or color == "" then
        return tostring(text)
    end

    return color .. tostring(text) .. "|r"
end

function MythicTools:Print(message)
    print(("|cffcfa85dMythic Tools|r: %s"):format(tostring(message or "")))
end

function MythicTools:IsDebugLoggingEnabled()
    return self.db and self.db.debug and self.db.debug.enabled ~= false
end

function MythicTools:GetDebugReports()
    if not (self.db and self.db.debug) then
        return {}
    end

    self.db.debug.reports = type(self.db.debug.reports) == "table" and self.db.debug.reports or {}
    return self.db.debug.reports
end

function MythicTools:BuildDebugRuntimeSnapshot()
    local runtime = self.runtime or {}
    local activeRun = runtime.activeRun
    local lootTracking = runtime.lootTracking
    local rewards = runtime.lastCompletionRewards

    return {
        activeRunId = type(activeRun) == "table" and activeRun.runId or nil,
        activeRunState = type(activeRun) == "table" and activeRun.state or nil,
        activeRunLevel = type(activeRun) == "table" and activeRun.keyLevel or nil,
        activeRunDungeon = type(activeRun) == "table" and activeRun.dungeonName or nil,
        activeRunCompletionPending = type(activeRun) == "table" and (activeRun.completionPending and true or false) or false,
        lootTrackingRunId = type(lootTracking) == "table" and lootTracking.runId or nil,
        lootClosed = type(lootTracking) == "table" and (lootTracking.lootClosed and true or false) or false,
        lastRewardsMapId = type(rewards) == "table" and rewards.mapChallengeModeID or nil,
        lastRewardsTimeMS = type(rewards) == "table" and rewards.timeMS or nil,
        pendingCompletionSnapshots = type(runtime.pendingCompletionSnapshots) == "table" and #runtime.pendingCompletionSnapshots or 0,
        pendingCompletionPopupRunId = type(runtime.pendingCompletionPopup) == "table" and runtime.pendingCompletionPopup.runId or nil,
        completionPopupTrigger = self.db and self.db.settings and self.db.settings.completionPopupTrigger or nil,
        savedRunCount = self.db and self.db.runs and #self.db.runs or 0,
    }
end

function MythicTools:StoreDebugReport(kind, context)
    if not self:IsDebugLoggingEnabled() then
        return nil
    end

    local reports = self:GetDebugReports()
    local report = {
        timestamp = time(),
        kind = kind or "event",
        context = type(context) == "table" and context or {},
        runtime = self:BuildDebugRuntimeSnapshot(),
        recentEvents = self:CopyArray(self.runtime and self.runtime.debugLog or {}),
    }

    table.insert(reports, 1, report)

    local maxReports = self:Clamp(self.db.debug.maxReports or 20, 5, 50)
    while #reports > maxReports do
        table.remove(reports)
    end

    return report
end

function MythicTools:GetLatestDebugReport()
    local reports = self:GetDebugReports()
    return reports[1]
end

function MythicTools:FormatDebugReport(report)
    if type(report) ~= "table" then
        return {}
    end

    local lines = {}
    local context = type(report.context) == "table" and report.context or {}
    local runtime = type(report.runtime) == "table" and report.runtime or {}

    lines[#lines + 1] = ("Debug report: %s at %s"):format(tostring(report.kind or "event"), self:FormatDateTime(report.timestamp))
    lines[#lines + 1] = ("Context: trigger=%s result=%s runId=%s state=%s map=%s level=%s"):format(
        tostring(context.trigger or "-"),
        tostring(context.result or "-"),
        tostring(context.runId or runtime.activeRunId or "-"),
        tostring(context.state or runtime.activeRunState or "-"),
        tostring(context.mapChallengeModeID or context.lastRewardsMapId or runtime.lastRewardsMapId or "-"),
        tostring(context.level or runtime.activeRunLevel or "-")
    )
    lines[#lines + 1] = ("Runtime: lootRun=%s lootClosed=%s pendingSnapshots=%s pendingPopup=%s popupTrigger=%s rewardsTime=%s savedRuns=%s"):format(
        tostring(runtime.lootTrackingRunId or "-"),
        tostring(runtime.lootClosed or false),
        tostring(runtime.pendingCompletionSnapshots or 0),
        tostring(runtime.pendingCompletionPopupRunId or "-"),
        tostring(runtime.completionPopupTrigger or "-"),
        tostring(runtime.lastRewardsTimeMS or "-"),
        tostring(runtime.savedRunCount or 0)
    )

    local recentEvents = type(report.recentEvents) == "table" and report.recentEvents or {}
    if #recentEvents > 0 then
        lines[#lines + 1] = "Recent events:"
        local startIndex = math.max(1, #recentEvents - 14)
        for index = startIndex, #recentEvents do
            lines[#lines + 1] = ("[%02d] %s"):format(index - startIndex + 1, tostring(recentEvents[index]))
        end
    end

    return lines
end

function MythicTools:PrintLatestDebugReport()
    local report = self:GetLatestDebugReport()
    if type(report) ~= "table" then
        self:Print("No debug report saved yet.")
        return
    end

    for _, line in ipairs(self:FormatDebugReport(report)) do
        self:Print(line)
    end
    self:Print("Full report is also stored in MythicToolsDB.debug.reports[1].")
end

function MythicTools:Clamp(value, minValue, maxValue)
    value = SafeToNumber(value) or minValue
    value = max(minValue, value)
    value = min(maxValue, value)
    return value
end

function MythicTools:CopyArray(source)
    local copy = {}

    if type(source) ~= "table" then
        return copy
    end

    for index = 1, #source do
        copy[index] = source[index]
    end

    return copy
end

function MythicTools:GetGroupUnits()
    local units = {}

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. index
        end
    elseif IsInGroup() then
        units[1] = "player"
        for index = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. index
        end
    else
        units[1] = "player"
    end

    return units
end

function MythicTools:GetCurrentGroupRoster()
    local roster = {}
    local seen = {}

    for _, unit in ipairs(self:GetGroupUnits()) do
        if UnitExists(unit) then
            local fullName = self:GetUnitFullName(unit)
            if fullName and not seen[fullName] then
                seen[fullName] = true

                local guid = UnitGUID(unit)
                if not self:CanAccessValue(guid) then
                    guid = nil
                end

                local _, classFilename = UnitClass(unit)
                local role, specID, specName, specIconID = self:GetUnitRoleSpecInfo(unit)
                roster[#roster + 1] = {
                    unit = unit,
                    name = fullName,
                    shortName = self:GetShortName(fullName),
                    guid = guid,
                    classFilename = classFilename,
                    role = role,
                    specID = specID,
                    specName = specName,
                    specIconID = specIconID,
                    isDead = UnitIsDeadOrGhost(unit) and not UnitIsFeignDeath(unit) or false,
                }
            end
        end
    end

    return roster
end

function MythicTools:GetGroupUnitForPlayer(fullName)
    if not fullName then
        return nil
    end

    if self.playerName and fullName == self.playerName and UnitExists("player") then
        return "player"
    end

    for _, rosterEntry in ipairs(self:GetCurrentGroupRoster()) do
        if rosterEntry.name == fullName and rosterEntry.unit and UnitExists(rosterEntry.unit) then
            return rosterEntry.unit
        end
    end

    return nil
end

function MythicTools:GetRosterSignature(roster)
    if type(roster) ~= "table" then
        return ""
    end

    local names = {}
    for _, entry in ipairs(roster) do
        names[#names + 1] = entry.name
    end

    table.sort(names)
    return table.concat(names, "|")
end

function MythicTools:Schedule(delay, callback)
    if type(callback) ~= "function" then
        return
    end

    C_Timer.After(delay or 0, callback)
end

function MythicTools:RefreshAllViews()
    if self.RefreshUI then
        self:RefreshUI()
    end
    if self.RefreshCompletionPopup then
        self:RefreshCompletionPopup()
    end
end

function MythicTools:HandlePlayerLogin()
    self.playerName = self:GetUnitFullName("player")
    if self.RegisterOwnedCharacter then
        self:RegisterOwnedCharacter(self.playerName)
    end
    if self.RequestMythicPlusData then
        self:RequestMythicPlusData()
    end
    self:GetLocalRealmName()
    if self.InitializeUnitPopupMenu then
        self:InitializeUnitPopupMenu()
    end
    if self.UpdateMinimapButton then
        self:UpdateMinimapButton()
    end
    self:QueueGroupScan()
end

function MythicTools:HandlePlayerEnteringWorld(isLogin, isReload)
    self.playerName = self:GetUnitFullName("player")
    if self.RegisterOwnedCharacter then
        self:RegisterOwnedCharacter(self.playerName)
    end

    local challengeActive = C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
    if challengeActive then
        if self.TryRestoreActiveRun then
            self:TryRestoreActiveRun()
        end
    else
        local activeRun = self.runtime and self.runtime.activeRun or nil
        if self.QueueInactiveRunResolution and type(activeRun) == "table" then
            self:QueueInactiveRunResolution(activeRun, "PLAYER_ENTERING_WORLD")
        elseif self.QueuePendingCompletionProcessing then
            self:QueuePendingCompletionProcessing("PLAYER_ENTERING_WORLD")
        end
    end

    if not isLogin and not isReload and not challengeActive and self.PushRuntimeDebug then
        local activeRun = self.runtime and self.runtime.activeRun or nil
        if type(activeRun) == "table" then
            self:PushRuntimeDebug(("PLAYER_ENTERING_WORLD outside challenge for run %s"):format(tostring(activeRun.runId)))
        else
            self:PushRuntimeDebug("PLAYER_ENTERING_WORLD outside challenge with no active run")
        end
    end

    self:QueueGroupScan()
end

function MythicTools:HandleGroupRosterChanged()
    if self.UpdateActiveRunParticipants then
        self:UpdateActiveRunParticipants()
    end

    self:QueueGroupScan()
end

function MythicTools:ADDON_LOADED(loadedAddon)
    if loadedAddon ~= ADDON_NAME then
        return
    end

    self.EventFrame:UnregisterEvent("ADDON_LOADED")

    self:InitializeDB()
    self:InitializeSlashCommands()

    self.runtime = {
        activeRun = nil,
        groupScanQueued = false,
        currentGroupPlayers = {},
        lootTracking = nil,
        pendingCompletionPopup = nil,
        lastActiveRunSnapshot = nil,
        pendingCompletionSnapshots = {},
        pendingCompletionProcessingQueued = false,
        lastCompletionRewards = nil,
        lastCompletedRunId = nil,
        lastCompletedAt = nil,
        lastCompletedMapChallengeModeID = nil,
        lastCompletedLevel = nil,
        debugLog = {},
    }

    self.EventFrame:RegisterEvent("PLAYER_LOGIN")
    self.EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.EventFrame:RegisterEvent("CHALLENGE_MODE_START")
    self.EventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    self.EventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED_REWARDS")
    self.EventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
    self.EventFrame:RegisterEvent("SCENARIO_COMPLETED")
    self.EventFrame:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    self.EventFrame:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    self.EventFrame:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    self.EventFrame:RegisterEvent("DAMAGE_METER_RESET")
    self.EventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end

function MythicTools:PLAYER_LOGIN()
    self:HandlePlayerLogin()
end

function MythicTools:PLAYER_ENTERING_WORLD(...)
    self:HandlePlayerEnteringWorld(...)
end

function MythicTools:GROUP_ROSTER_UPDATE()
    self:HandleGroupRosterChanged()
end

function MythicTools:CHALLENGE_MODE_START(...)
    if self.HandleChallengeModeStart then
        self:HandleChallengeModeStart(...)
    end
end

function MythicTools:CHALLENGE_MODE_COMPLETED(...)
    if self.HandleChallengeModeCompleted then
        self:HandleChallengeModeCompleted(...)
    end
end

function MythicTools:CHALLENGE_MODE_COMPLETED_REWARDS(...)
    if self.HandleChallengeModeCompletedRewards then
        self:HandleChallengeModeCompletedRewards(...)
    end
end

function MythicTools:CHALLENGE_MODE_RESET(...)
    if self.HandleChallengeModeReset then
        self:HandleChallengeModeReset(...)
    end
end

function MythicTools:SCENARIO_COMPLETED(...)
    if self.HandleScenarioCompleted then
        self:HandleScenarioCompleted(...)
    end
end

function MythicTools:CHALLENGE_MODE_DEATH_COUNT_UPDATED(...)
    if self.HandleChallengeDeathCountUpdated then
        self:HandleChallengeDeathCountUpdated(...)
    end
end

function MythicTools:UNIT_HEALTH(...)
    if self.HandleUnitHealth then
        self:HandleUnitHealth(...)
    end
end

function MythicTools:DAMAGE_METER_COMBAT_SESSION_UPDATED(...)
    if self.HandleDamageMeterSessionUpdated then
        self:HandleDamageMeterSessionUpdated(...)
    end
end

function MythicTools:DAMAGE_METER_CURRENT_SESSION_UPDATED(...)
    if self.HandleDamageMeterCurrentSessionUpdated then
        self:HandleDamageMeterCurrentSessionUpdated(...)
    end
end

function MythicTools:DAMAGE_METER_RESET(...)
    if self.HandleDamageMeterReset then
        self:HandleDamageMeterReset(...)
    end
end

function MythicTools:ENCOUNTER_LOOT_RECEIVED(...)
    if self.HandleEncounterLootReceived then
        self:HandleEncounterLootReceived(...)
    end
end

function MythicTools:CHAT_MSG_LOOT(...)
    if self.HandleChatMsgLoot then
        self:HandleChatMsgLoot(...)
    end
end

function MythicTools:GET_ITEM_INFO_RECEIVED(...)
    if self.HandleItemInfoReceived then
        self:HandleItemInfoReceived(...)
    end
end

function MythicTools:LOOT_CLOSED(...)
    if self.HandleLootClosed then
        self:HandleLootClosed(...)
    end
end

MythicTools.EventFrame = CreateFrame("Frame")
MythicTools.EventFrame:SetScript("OnEvent", function(_, event, ...)
    local handler = MythicTools[event]
    if handler then
        handler(MythicTools, ...)
    end
end)
MythicTools.EventFrame:RegisterEvent("ADDON_LOADED")





