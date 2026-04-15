local _, ns = ...
local MythicTools = ns.MythicTools

local function NormalizeStoredItemLink(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    local hyperlink = itemLink:match("(|Hitem:.-|h%[.-%]|h)")
    if hyperlink and hyperlink ~= "" then
        return hyperlink
    end

    return itemLink
end

local function CreateAggregateEntry(label)
    return {
        label = label,
        totalRuns = 0,
        timedRuns = 0,
        overtimeRuns = 0,
        abandonedRuns = 0,
        successRate = 0,
        bestLevel = 0,
        bestTimedLevel = 0,
        averageLevel = 0,
        maxDps = 0,
        averageDps = 0,
        maxHps = 0,
        averageHps = 0,
        totalLevel = 0,
        countedLevels = 0,
        totalDps = 0,
        countedDps = 0,
        totalHps = 0,
        countedHps = 0,
    }
end

local function GetDerivedStatDuration(run, stat, activeSecondsField)
    local durationSeconds = tonumber(run and run.combatTimeSeconds)
    if durationSeconds and durationSeconds > 0 then
        return durationSeconds
    end

    durationSeconds = tonumber(stat and stat[activeSecondsField])
    if durationSeconds and durationSeconds > 0 then
        return durationSeconds
    end

    durationSeconds = (tonumber(run and run.timeMS) or 0) / 1000
    if durationSeconds > 0 then
        return durationSeconds
    end

    return 0
end

local function RunNeedsDerivedStatRefresh(run)
    if type(run) ~= "table" then
        return false
    end

    for _, stat in pairs(run.playerStats or {}) do
        if type(stat) == "table" then
            if stat.damage ~= nil and stat.dps == nil and GetDerivedStatDuration(run, stat, "damageActiveSeconds") > 0 then
                return true
            end
            if stat.healing ~= nil and stat.hps == nil and GetDerivedStatDuration(run, stat, "healingActiveSeconds") > 0 then
                return true
            end
        end
    end

    return false
end

local function AccumulateAggregate(target, run, dps, hps)
    target.totalRuns = (target.totalRuns or 0) + 1

    if run.result == "timed" then
        target.timedRuns = (target.timedRuns or 0) + 1
    elseif run.result == "abandoned" then
        target.abandonedRuns = (target.abandonedRuns or 0) + 1
    else
        target.overtimeRuns = (target.overtimeRuns or 0) + 1
    end

    local isAbandoned = run.result == "abandoned"

    if run.level and run.level > 0 then
        target.bestLevel = math.max(target.bestLevel or 0, run.level)
        if run.result == "timed" then
            target.bestTimedLevel = math.max(target.bestTimedLevel or 0, run.level)
        end
        if not isAbandoned then
            target.totalLevel = (target.totalLevel or 0) + run.level
            target.countedLevels = (target.countedLevels or 0) + 1
        end
    end

    if dps ~= nil and not isAbandoned then
        target.maxDps = math.max(target.maxDps or 0, dps)
        target.totalDps = (target.totalDps or 0) + dps
        target.countedDps = (target.countedDps or 0) + 1
    end

    if hps ~= nil and not isAbandoned then
        target.maxHps = math.max(target.maxHps or 0, hps)
        target.totalHps = (target.totalHps or 0) + hps
        target.countedHps = (target.countedHps or 0) + 1
    end
end

local function FinalizeAggregate(target)
    if (target.totalRuns or 0) > 0 then
        target.successRate = ((target.timedRuns or 0) / target.totalRuns) * 100
    else
        target.successRate = 0
    end

    if (target.countedLevels or 0) > 0 then
        target.averageLevel = (target.totalLevel or 0) / target.countedLevels
    else
        target.averageLevel = 0
    end

    if (target.countedDps or 0) > 0 then
        target.averageDps = (target.totalDps or 0) / target.countedDps
    else
        target.averageDps = 0
    end

    if (target.countedHps or 0) > 0 then
        target.averageHps = (target.totalHps or 0) / target.countedHps
    else
        target.averageHps = 0
    end
end

local defaults = {
    version = MythicTools.DB_VERSION,
    nextRunId = 1,
    runs = {},
    playersIndex = {},
    playerNotes = {},
    ownedCharacters = {},
    debug = {
        enabled = true,
        maxReports = 20,
        reports = {},
    },
    settings = {
        chatAlerts = true,
        maxRuns = 500,
        showMinimapButton = true,
        minimapAngle = -35,
        showCompletionPopup = true,
        completionPopupTrigger = "COMPLETED",
        completionPopupDelay = 0,
        completionPopupScale = 1,
        showLootHistory = true,
    },
    ui = {
        point = {"CENTER", "CENTER", 0, 0},
        width = 1280,
        height = 760,
        activeTab = "Runs",
        filters = {
            search = "",
            player = "",
            dungeon = "all",
            season = "season1",
            date = "",
            status = "all",
            ownedCharacters = "all",
        },
        playerFilters = {
            search = "",
            season = "season1",
            dungeon = "all",
        },
        playerSort = {
            column = "runs",
            direction = "desc",
        },
        playerSearch = "",
        playersView = "index",
        selectedRunId = nil,
        selectedPlayer = nil,
        runViewMode = "list",
        completionPopupPoint = {"CENTER", "CENTER", 0, 40},
    },
}

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function NormalizeOwnedCharactersTable(owner, value)
    local normalized = {}

    if type(value) ~= "table" then
        return normalized
    end

    for fullName, enabled in pairs(value) do
        if enabled then
            local normalizedName = owner:NormalizePlayerName(fullName) or owner:TrimText(fullName)
            if normalizedName and normalizedName ~= "" then
                normalized[normalizedName] = true
            end
        end
    end

    return normalized
end

local function TableHasEntries(value)
    return type(value) == "table" and next(value) ~= nil
end

local function DatabaseHasHistoryData(value)
    if type(value) ~= "table" then
        return false
    end

    if type(value.runs) == "table" and #value.runs > 0 then
        return true
    end
    if TableHasEntries(value.playerNotes) or TableHasEntries(value.ownedCharacters) then
        return true
    end
    if type(value.debug) == "table" and type(value.debug.reports) == "table" and #value.debug.reports > 0 then
        return true
    end
    if type(value.nextRunId) == "number" and value.nextRunId > 1 then
        return true
    end

    return false
end

local function ShouldUseLegacyDatabase(current, legacy)
    if not DatabaseHasHistoryData(legacy) then
        return false
    end

    if type(current) ~= "table" or next(current) == nil then
        return true
    end

    local currentRunCount = type(current.runs) == "table" and #current.runs or 0
    local legacyRunCount = type(legacy.runs) == "table" and #legacy.runs or 0
    if currentRunCount == 0 and legacyRunCount > 0 then
        return true
    end

    return not DatabaseHasHistoryData(current)
end

function MythicTools:InitializeDB()
    local migratedLegacyDB = false
    if ShouldUseLegacyDatabase(SkyMythicHistoryDB, MythicToolsDB) then
        SkyMythicHistoryDB = MythicToolsDB
        migratedLegacyDB = true
    else
        SkyMythicHistoryDB = SkyMythicHistoryDB or {}
    end

    if migratedLegacyDB then
        MythicToolsDB = nil
    end

    self.db = SkyMythicHistoryDB

    ApplyDefaults(self.db, defaults)

    self.db.version = self.DB_VERSION
    self.db.settings.maxRuns = self:Clamp(self.db.settings.maxRuns, 50, 5000)
    self.db.settings.completionPopupDelay = self:Clamp(self.db.settings.completionPopupDelay or 0, 0, 10)
    self.db.settings.completionPopupScale = self:Clamp(self.db.settings.completionPopupScale or 1, 0.7, 1.4)
    if self.db.settings.completionPopupTrigger ~= "COMPLETED" and self.db.settings.completionPopupTrigger ~= "LOOT_CLOSED" then
        self.db.settings.completionPopupTrigger = "COMPLETED"
    end
    self.db.debug.maxReports = self:Clamp(self.db.debug.maxReports or 20, 5, 50)
    self.db.debug.reports = type(self.db.debug.reports) == "table" and self.db.debug.reports or {}
    self.db.ui.width = self:Clamp(self.db.ui.width, 1280, 1600)
    self.db.ui.height = self:Clamp(self.db.ui.height, 720, 960)
    self.db.ownedCharacters = NormalizeOwnedCharactersTable(self, self.db.ownedCharacters)
    if (self.db.ui.playerFilters.search or "") == "" and (self.db.ui.playerSearch or "") ~= "" then
        self.db.ui.playerFilters.search = self.db.ui.playerSearch
    end
    if self.db.ui.playersView ~= "detail" then
        self.db.ui.playersView = "index"
    end

    self:TrimRunsToLimit()
    self:RebuildPlayerIndex()
end

function MythicTools:TrimRunsToLimit()
    local runs = self.db and self.db.runs
    if type(runs) ~= "table" then
        self.db.runs = {}
        return
    end

    local limit = self:Clamp(self.db.settings.maxRuns, 50, 5000)
    while #runs > limit do
        table.remove(runs, #runs)
    end
end

function MythicTools:GetPlayerDPS(run, stat)
    local recordedDPS = tonumber(stat and stat.dps)
    if recordedDPS ~= nil then
        return recordedDPS
    end

    local durationSeconds = GetDerivedStatDuration(run, stat, "damageActiveSeconds")
    if durationSeconds <= 0 then
        return 0
    end

    return (tonumber(stat and stat.damage) or 0) / durationSeconds
end

function MythicTools:GetPlayerHPS(run, stat)
    local recordedHPS = tonumber(stat and stat.hps)
    if recordedHPS ~= nil then
        return recordedHPS
    end

    local durationSeconds = GetDerivedStatDuration(run, stat, "healingActiveSeconds")
    if durationSeconds <= 0 then
        return 0
    end

    return (tonumber(stat and stat.healing) or 0) / durationSeconds
end

function MythicTools:RebuildPlayerIndex()
    local index = {}
    self.runLookup = {}

    for _, run in ipairs(self.db.runs) do
        if type(run) == "table" and run.runId then
            self.runLookup[run.runId] = run

            run.roster = self:NormalizeRunRoster(run)
            run.playerStats = type(run.playerStats) == "table" and run.playerStats or {}
            run.level = tonumber(run.level) or 0
            run.timeMS = tonumber(run.timeMS) or 0
            run.keystoneUpgradeLevels = tonumber(run.keystoneUpgradeLevels) or 0
            run.oldOverallDungeonScore = tonumber(run.oldOverallDungeonScore) or run.oldOverallDungeonScore
            run.newOverallDungeonScore = tonumber(run.newOverallDungeonScore) or run.newOverallDungeonScore
            run.combatTimeSeconds = tonumber(run.combatTimeSeconds) or nil
            run.outOfCombatSeconds = tonumber(run.outOfCombatSeconds) or nil
            run.totalDeaths = tonumber(run.totalDeaths) or 0
            run.deathPenaltySeconds = tonumber(run.deathPenaltySeconds) or 0
            run.endTime = tonumber(run.endTime) or 0
            run.season = self:GetRunSeason(run)
            run.result = self:GetRunResult(run)
            if run.result == "timed" then
                run.onTime = true
            elseif run.result == "overtime" then
                run.onTime = false
            end

            local stalePlayers = nil
            for playerName, stat in pairs(run.playerStats) do
                if not self:IsRunPlayerEntry(playerName, stat) then
                    stalePlayers = stalePlayers or {}
                    stalePlayers[#stalePlayers + 1] = playerName
                elseif type(stat) == "table" then
                    stat.name = playerName
                    stat.shortName = stat.shortName or self:GetShortName(playerName)
                    if stat.damage ~= nil then stat.damage = tonumber(stat.damage) or 0 end
                    if stat.healing ~= nil then stat.healing = tonumber(stat.healing) or 0 end
                    if stat.interrupts ~= nil then stat.interrupts = math.floor((tonumber(stat.interrupts) or 0) + 0.5) end
                    stat.score = tonumber(stat.score) or nil
                    stat.previousScore = tonumber(stat.previousScore) or nil
                    stat.itemLevel = tonumber(stat.itemLevel) or nil
                    stat.damageActiveSeconds = tonumber(stat.damageActiveSeconds) or nil
                    stat.healingActiveSeconds = tonumber(stat.healingActiveSeconds) or nil
                    stat.dps = tonumber(stat.dps) or nil
                    stat.hps = tonumber(stat.hps) or nil
                    stat.role = self:NormalizeRole(stat.role)
                    stat.specID = tonumber(stat.specID) or stat.specID
                    if stat.specID and (not stat.specName or not stat.specIconID or not stat.role) then
                        local specID, specName, specIconID, role = self:GetSpecInfo(stat.specID)
                        stat.specID = specID or stat.specID
                        stat.specName = stat.specName or specName
                        stat.specIconID = stat.specIconID or specIconID
                        stat.role = stat.role or role
                    end
                    stat.deaths = tonumber(stat.deaths) or 0
                    stat.loot = type(stat.loot) == "table" and stat.loot or {}
                    local normalizedLoot = {}
                    local seenLoot = {}
                    for _, itemLink in ipairs(stat.loot) do
                        local normalizedLink = NormalizeStoredItemLink(itemLink)
                        if normalizedLink and not seenLoot[normalizedLink] then
                            seenLoot[normalizedLink] = true
                            normalizedLoot[#normalizedLoot + 1] = normalizedLink
                        end
                    end
                    stat.loot = normalizedLoot
                end
            end

            if self.RefreshRunDerivedStats and RunNeedsDerivedStatRefresh(run) then
                self:RefreshRunDerivedStats(run)
            end

            if stalePlayers then
                for _, playerName in ipairs(stalePlayers) do
                    run.playerStats[playerName] = nil
                end
            end

            local roster = self:NormalizeRunRoster(run)
            local rosterSet = {}
            for _, fullName in ipairs(roster) do
                rosterSet[fullName] = true
            end

            local removedPlayers = nil
            for playerName in pairs(run.playerStats) do
                if not rosterSet[playerName] then
                    removedPlayers = removedPlayers or {}
                    removedPlayers[#removedPlayers + 1] = playerName
                end
            end

            if removedPlayers then
                for _, playerName in ipairs(removedPlayers) do
                    run.playerStats[playerName] = nil
                end
            end

            for _, fullName in ipairs(roster) do
                local playerEntry = index[fullName]
                if not playerEntry then
                    playerEntry = CreateAggregateEntry(self:GetShortName(fullName))
                    playerEntry.fullName = fullName
                    playerEntry.shortName = self:GetShortName(fullName)
                    playerEntry.lastSeenAt = 0
                    playerEntry.lastRunId = nil
                    playerEntry.lastResult = nil
                    playerEntry.runIds = {}
                    playerEntry.dungeons = {}
                    playerEntry.dungeonBreakdown = playerEntry.dungeons
                    playerEntry.roleBreakdown = {}
                    playerEntry.specBreakdown = {}
                    playerEntry.classFilename = nil
                    playerEntry.specIconID = nil
                    playerEntry.specID = nil
                    playerEntry.specName = nil
                    playerEntry.role = nil
                    index[fullName] = playerEntry
                end

                local stat = run.playerStats[fullName]
                local dps = (stat and stat.damage ~= nil) and self:GetPlayerDPS(run, stat) or nil
                local hps = (stat and stat.healing ~= nil) and self:GetPlayerHPS(run, stat) or nil
                AccumulateAggregate(playerEntry, run, dps, hps)
                if stat then
                    if stat.classFilename then
                        playerEntry.classFilename = stat.classFilename
                    end
                    if stat.specIconID then
                        playerEntry.specIconID = stat.specIconID
                    end
                    if stat.specID then
                        playerEntry.specID = stat.specID
                    end
                    if stat.specName then
                        playerEntry.specName = stat.specName
                    end
                    if stat.role then
                        playerEntry.role = stat.role
                    end
                end

                if playerEntry.lastRunId == nil or (run.endTime or 0) >= (playerEntry.lastSeenAt or 0) then
                    playerEntry.lastRunId = run.runId
                    playerEntry.lastSeenAt = run.endTime
                    playerEntry.lastDungeonName = run.dungeonName
                    playerEntry.lastLevel = run.level
                    playerEntry.lastOnTime = run.result == "timed"
                    playerEntry.lastResult = run.result
                end

                playerEntry.runIds[#playerEntry.runIds + 1] = run.runId

                local dungeonKey = tostring(run.mapChallengeModeID or run.mapID or run.dungeonName or "unknown")
                local dungeonEntry = playerEntry.dungeons[dungeonKey]
                if not dungeonEntry then
                    dungeonEntry = CreateAggregateEntry(run.dungeonName or "Unknown")
                    dungeonEntry.key = dungeonKey
                    dungeonEntry.name = run.dungeonName or "Unknown"
                    dungeonEntry.lastSeenAt = 0
                    playerEntry.dungeons[dungeonKey] = dungeonEntry
                end

                AccumulateAggregate(dungeonEntry, run, dps, hps)
                dungeonEntry.lastSeenAt = math.max(dungeonEntry.lastSeenAt, run.endTime or 0)

                if stat and stat.role then
                    local roleKey = stat.role
                    local roleEntry = playerEntry.roleBreakdown[roleKey]
                    if not roleEntry then
                        roleEntry = CreateAggregateEntry(self:GetRoleLabel(stat.role))
                        roleEntry.role = stat.role
                        playerEntry.roleBreakdown[roleKey] = roleEntry
                    end
                    AccumulateAggregate(roleEntry, run, dps, hps)
                end

                if stat and (stat.specID or stat.specName) then
                    local specKey = tostring(stat.specID or stat.specName)
                    local specEntry = playerEntry.specBreakdown[specKey]
                    if not specEntry then
                        specEntry = CreateAggregateEntry(stat.specName or ("Spec " .. specKey))
                        specEntry.specID = stat.specID
                        specEntry.specName = stat.specName or specEntry.label
                        specEntry.specIconID = stat.specIconID
                        specEntry.role = stat.role
                        playerEntry.specBreakdown[specKey] = specEntry
                    end
                    if stat.specIconID then
                        specEntry.specIconID = stat.specIconID
                    end
                    if stat.role then
                        specEntry.role = stat.role
                    end
                    AccumulateAggregate(specEntry, run, dps, hps)
                end
            end
        end
    end

    for _, playerEntry in pairs(index) do
        FinalizeAggregate(playerEntry)
        for _, dungeonEntry in pairs(playerEntry.dungeons or {}) do
            FinalizeAggregate(dungeonEntry)
        end
        for _, roleEntry in pairs(playerEntry.roleBreakdown or {}) do
            FinalizeAggregate(roleEntry)
        end
        for _, specEntry in pairs(playerEntry.specBreakdown or {}) do
            FinalizeAggregate(specEntry)
        end
    end

    self.db.playersIndex = index
end

function MythicTools:AddCompletedRun(run)
    if type(run) ~= "table" then
        return
    end

    run.runId = tonumber(run.runId) or self.db.nextRunId or 1
    self.db.nextRunId = math.max((self.db.nextRunId or 1), run.runId + 1)
    run.roster = self:NormalizeRunRoster(run)
    run.season = self:GetRunSeason(run)
    run.result = self:GetRunResult(run)
    run.keystoneUpgradeLevels = tonumber(run.keystoneUpgradeLevels) or 0
    run.oldOverallDungeonScore = tonumber(run.oldOverallDungeonScore) or run.oldOverallDungeonScore
    run.newOverallDungeonScore = tonumber(run.newOverallDungeonScore) or run.newOverallDungeonScore
    run.combatTimeSeconds = tonumber(run.combatTimeSeconds) or nil
    run.outOfCombatSeconds = tonumber(run.outOfCombatSeconds) or nil
    if self.HydrateRunCombatDuration and run.combatTimeSeconds == nil then
        self:HydrateRunCombatDuration(run)
    end
    if self.RefreshRunDerivedStats and RunNeedsDerivedStatRefresh(run) then
        self:RefreshRunDerivedStats(run)
    end
    if run.result == "timed" then
        run.onTime = true
    elseif run.result == "overtime" then
        run.onTime = false
    end

    table.insert(self.db.runs, 1, run)
    self:TrimRunsToLimit()
    self:RebuildPlayerIndex()

    if not self.db.ui.selectedRunId then
        self.db.ui.selectedRunId = run.runId
    end
end

function MythicTools:GetRunById(runId)
    if not runId then
        return nil
    end

    if self.runLookup and self.runLookup[runId] then
        return self.runLookup[runId]
    end

    for _, run in ipairs(self.db.runs) do
        if run.runId == runId then
            return run
        end
    end

    return nil
end

function MythicTools:RemoveRunById(runId)
    runId = tonumber(runId)
    if not runId then
        return false
    end

    for index, run in ipairs(self.db.runs or {}) do
        if run.runId == runId then
            table.remove(self.db.runs, index)
            self:RebuildPlayerIndex()

            if self.db.ui.selectedRunId == runId then
                self.db.ui.selectedRunId = self.db.runs[1] and self.db.runs[1].runId or nil
            end

            return true
        end
    end

    return false
end

function MythicTools:GetRunsForPlayer(fullName)
    local playerEntry = self.db.playersIndex[fullName]
    if not playerEntry then
        return {}
    end

    local runs = {}
    for _, runId in ipairs(playerEntry.runIds) do
        local run = self:GetRunById(runId)
        if run then
            runs[#runs + 1] = run
        end
    end

    return runs
end

function MythicTools:GetPlayerCount()
    local count = 0
    for _ in pairs(self.db.playersIndex) do
        count = count + 1
    end
    return count
end

function MythicTools:GetPlayerNote(fullName)
    if not (self.db and self.db.playerNotes) then
        return ""
    end

    fullName = self:NormalizePlayerName(fullName) or self:TrimText(fullName)
    if not fullName or fullName == "" then
        return ""
    end

    local note = self.db.playerNotes[fullName]
    if type(note) ~= "string" then
        return ""
    end

    return note
end

function MythicTools:RegisterOwnedCharacter(fullName)
    if not (self.db and self.db.ownedCharacters) then
        return nil
    end

    fullName = self:NormalizePlayerName(fullName) or self:TrimText(fullName)
    if not fullName or fullName == "" then
        return nil
    end

    self.db.ownedCharacters[fullName] = true
    return fullName
end

function MythicTools:IsOwnedCharacter(fullName)
    if not (self.db and self.db.ownedCharacters) then
        return false
    end

    fullName = self:NormalizePlayerName(fullName) or self:TrimText(fullName)
    return fullName ~= nil and self.db.ownedCharacters[fullName] == true
end

function MythicTools:RunHasOwnedCharacter(run)
    for _, fullName in ipairs(run and run.roster or {}) do
        if self:IsOwnedCharacter(fullName) then
            return true
        end
    end

    return false
end

function MythicTools:RunHasCharacter(run, fullName)
    fullName = self:NormalizePlayerName(fullName) or self:TrimText(fullName)
    if not fullName or fullName == "" then
        return false
    end

    for _, rosterName in ipairs(run and run.roster or {}) do
        if rosterName == fullName then
            return true
        end
    end

    return false
end

function MythicTools:GetOwnedCharacters()
    local characters = {}

    for fullName, enabled in pairs(self.db and self.db.ownedCharacters or {}) do
        if enabled then
            characters[#characters + 1] = fullName
        end
    end

    table.sort(characters, function(left, right)
        local leftShort = self:GetShortName(left)
        local rightShort = self:GetShortName(right)
        if leftShort ~= rightShort then
            return leftShort < rightShort
        end
        return left < right
    end)

    return characters
end

function MythicTools:SetPlayerNote(fullName, noteText)
    if not (self.db and self.db.playerNotes) then
        return
    end

    fullName = self:NormalizePlayerName(fullName) or self:TrimText(fullName)
    if not fullName or fullName == "" then
        return
    end

    noteText = self:TrimText(noteText)
    if noteText == "" then
        self.db.playerNotes[fullName] = nil
    else
        self.db.playerNotes[fullName] = noteText
    end
end

function MythicTools:HasPlayerHistory(fullName)
    if not (self.db and self.db.playersIndex) then
        return false
    end

    fullName = self:NormalizePlayerName(fullName) or self:TrimText(fullName)
    return fullName ~= nil and self.db.playersIndex[fullName] ~= nil
end

function MythicTools:SetChatAlertsEnabled(enabled)
    self.db.settings.chatAlerts = enabled and true or false
end

function MythicTools:SetMinimapButtonEnabled(enabled)
    self.db.settings.showMinimapButton = enabled and true or false
    if self.UpdateMinimapButton then
        self:UpdateMinimapButton()
    end
end

function MythicTools:SetMaxRuns(limit)
    self.db.settings.maxRuns = self:Clamp(limit, 50, 5000)
    self:TrimRunsToLimit()
    self:RebuildPlayerIndex()
end

function MythicTools:ClearHistory()
    self.db.runs = {}
    self.db.playersIndex = {}
    self.db.nextRunId = 1
    self.db.ui.selectedRunId = nil
    self.db.ui.selectedPlayer = nil
    self.db.ui.playersView = "index"
    self.db.ui.playerSearch = ""
    self.db.ui.playerFilters = {
        search = "",
        season = "season1",
        dungeon = "all",
    }
    self.db.ui.filters = {
        search = "",
        player = "",
        dungeon = "all",
        season = "season1",
        date = "",
        status = "all",
        ownedCharacters = "all",
    }
    self.runLookup = {}
    if self.runtime then
        self.runtime.pendingCompletionPopup = nil
    end
    if self.HideCompletionPopup then
        self:HideCompletionPopup()
    end
    self:RefreshAllViews()
end
