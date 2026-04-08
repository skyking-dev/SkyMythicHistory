local _, ns = ...
local MythicTools = ns.MythicTools

local DAMAGE_DONE = Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone or 0
local HEALING_DONE = Enum and Enum.DamageMeterType and Enum.DamageMeterType.HealingDone or 2
local INTERRUPTS = Enum and Enum.DamageMeterType and Enum.DamageMeterType.Interrupts or 5
local DETAILS_ATTRIBUTE_DAMAGE = _G.DETAILS_ATTRIBUTE_DAMAGE or 1
local DETAILS_ATTRIBUTE_HEAL = _G.DETAILS_ATTRIBUTE_HEAL or 2
local DETAILS_ATTRIBUTE_MISC = _G.DETAILS_ATTRIBUTE_MISC or 4
local COMPLETION_RETRY_DELAY = 0.35
local MAX_COMPLETION_ATTEMPTS = 24
local INACTIVE_RESOLUTION_DELAY = 5
local LOOT_TRACKING_TIMEOUT = 45
local LOOT_POPUP_FALLBACK_DELAY = 8
local DEBUG_EVENT_BUFFER_SIZE = 30

local function GetChallengeCompletionInfoCompat()
    if C_ChallengeMode.GetChallengeCompletionInfo then
        local info = C_ChallengeMode.GetChallengeCompletionInfo()
        if type(info) == "table" and next(info) then
            return info
        end
    end

    if C_ChallengeMode.GetCompletionInfo then
        local mapChallengeModeID, level, timeMS, onTime, keystoneUpgradeLevels, practiceRun, oldOverallDungeonScore, newOverallDungeonScore, isMapRecord, isAffixRecord, primaryAffix, isEligibleForScore, members = C_ChallengeMode.GetCompletionInfo()
        if mapChallengeModeID then
            return {
                mapChallengeModeID = mapChallengeModeID,
                level = level,
                time = timeMS,
                onTime = onTime,
                keystoneUpgradeLevels = keystoneUpgradeLevels,
                practiceRun = practiceRun,
                oldOverallDungeonScore = oldOverallDungeonScore,
                newOverallDungeonScore = newOverallDungeonScore,
                isMapRecord = isMapRecord,
                isAffixRecord = isAffixRecord,
                primaryAffix = primaryAffix,
                isEligibleForScore = isEligibleForScore,
                members = members,
            }
        end
    end

    return nil
end

local function IsValidCompletionInfo(info)
    return type(info) == "table"
        and (tonumber(info.mapChallengeModeID) or 0) > 0
        and (tonumber(info.level) or 0) > 0
        and (tonumber(info.time) or 0) > 0
end

local function GetMapInfo(mapChallengeModeID)
    if not (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and mapChallengeModeID and mapChallengeModeID ~= 0) then
        return nil
    end

    local dungeonName, challengeMapID, timeLimit, textureFileID, backgroundTextureFileID, uiMapID = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
    return {
        dungeonName = dungeonName,
        mapID = uiMapID or challengeMapID,
        timeLimit = timeLimit,
        textureFileID = textureFileID,
        backgroundTextureFileID = backgroundTextureFileID,
    }
end

local function BuildCompletionMembersFromActiveRun(activeRun)
    if type(activeRun) ~= "table" then
        return nil
    end

    local members = {}
    for _, fullName in ipairs(activeRun.participantOrder or {}) do
        local stat = activeRun.playerStats and activeRun.playerStats[fullName] or nil
        members[#members + 1] = {
            name = fullName,
            guid = stat and stat.guid or nil,
            classFilename = stat and stat.classFilename or nil,
            role = stat and stat.role or nil,
            specID = stat and stat.specID or nil,
            specName = stat and stat.specName or nil,
            specIconID = stat and stat.specIconID or nil,
        }
    end

    return #members > 0 and members or nil
end

local function SetCachedCompletionInfo(activeRun, completionInfo, source)
    if type(activeRun) ~= "table" or not IsValidCompletionInfo(completionInfo) then
        return nil
    end

    activeRun.pendingCompletionInfo = completionInfo
    activeRun.pendingCompletionSource = source or activeRun.pendingCompletionSource or "unknown"
    return completionInfo
end

local function BuildRecoveredCompletionInfo(activeRun)
    if type(activeRun) ~= "table" then
        return nil
    end

    local mapChallengeModeID = tonumber(activeRun.mapChallengeModeID) or 0
    local level = tonumber(activeRun.keyLevel) or 0
    local completedAt = tonumber(activeRun.completedAt) or time()
    local startedAt = tonumber(activeRun.startedAt) or completedAt
    local elapsedMS = math.max(0, (completedAt - startedAt) * 1000)
    if mapChallengeModeID <= 0 or level <= 0 or elapsedMS <= 0 then
        return nil
    end

    local mapInfo = GetMapInfo(mapChallengeModeID)
    local timeLimitSeconds = tonumber(mapInfo and mapInfo.timeLimit) or tonumber(activeRun.timeLimitSeconds) or 0

    return {
        mapChallengeModeID = mapChallengeModeID,
        level = level,
        time = elapsedMS,
        onTime = timeLimitSeconds > 0 and elapsedMS <= (timeLimitSeconds * 1000) or nil,
        keystoneUpgradeLevels = 0,
        practiceRun = false,
        oldOverallDungeonScore = nil,
        newOverallDungeonScore = nil,
        isMapRecord = nil,
        isAffixRecord = nil,
        primaryAffix = nil,
        isEligibleForScore = nil,
        members = BuildCompletionMembersFromActiveRun(activeRun),
    }
end

local function CopySet(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function MergeSessionSet(target, source, excluded)
    local changed = false
    if type(target) ~= "table" then
        return false
    end

    for sessionID in pairs(source or {}) do
        if not (excluded and excluded[sessionID]) and not target[sessionID] then
            target[sessionID] = true
            changed = true
        end
    end

    return changed
end

local function CopyCompletionMembers(members)
    if type(members) ~= "table" then
        return nil
    end

    local copy = {}
    for index, member in ipairs(members) do
        if type(member) == "table" then
            copy[index] = {
                name = member.name,
                memberName = member.memberName,
                fullName = member.fullName,
                playerName = member.playerName,
                realm = member.realm,
                realmName = member.realmName,
                memberGUID = member.memberGUID,
                guid = member.guid,
                playerGUID = member.playerGUID,
                classFilename = member.classFilename or member.classFileName,
                classFileName = member.classFileName or member.classFilename,
                role = member.role,
                assignedRole = member.assignedRole,
                combatRole = member.combatRole,
                specID = member.specID or member.specId or member.specializationID,
                specId = member.specId or member.specID or member.specializationID,
                specializationID = member.specializationID or member.specID or member.specId,
                specName = member.specName or member.specializationName,
                specializationName = member.specializationName or member.specName,
                specIconID = member.specIconID or member.specIcon or member.specTexture,
                specIcon = member.specIcon or member.specIconID or member.specTexture,
                specTexture = member.specTexture or member.specIconID or member.specIcon,
            }
        end
    end

    return next(copy) and copy or nil
end

local function CopyCompletionInfo(completionInfo)
    if type(completionInfo) ~= "table" then
        return nil
    end

    return {
        mapChallengeModeID = completionInfo.mapChallengeModeID,
        level = completionInfo.level,
        time = completionInfo.time,
        onTime = completionInfo.onTime,
        keystoneUpgradeLevels = completionInfo.keystoneUpgradeLevels,
        practiceRun = completionInfo.practiceRun,
        oldOverallDungeonScore = completionInfo.oldOverallDungeonScore,
        newOverallDungeonScore = completionInfo.newOverallDungeonScore,
        isMapRecord = completionInfo.isMapRecord,
        isAffixRecord = completionInfo.isAffixRecord,
        primaryAffix = completionInfo.primaryAffix,
        isEligibleForScore = completionInfo.isEligibleForScore,
        members = CopyCompletionMembers(completionInfo.members),
    }
end

local function CopyActiveRunPlayerStats(self, playerStats)
    local copy = {}

    for fullName, stat in pairs(playerStats or {}) do
        if type(stat) == "table" then
            copy[fullName] = {
                name = stat.name or fullName,
                shortName = stat.shortName or self:GetShortName(fullName),
                guid = stat.guid,
                classFilename = stat.classFilename,
                role = stat.role,
                specID = stat.specID,
                specName = stat.specName,
                specIconID = stat.specIconID,
                score = stat.score,
                previousScore = stat.previousScore,
                itemLevel = stat.itemLevel,
                damageActiveSeconds = stat.damageActiveSeconds,
                healingActiveSeconds = stat.healingActiveSeconds,
                dps = stat.dps,
                hps = stat.hps,
                damage = stat.damage,
                healing = stat.healing,
                interrupts = stat.interrupts,
                deaths = tonumber(stat.deaths) or 0,
                loot = type(stat.loot) == "table" and self:CopyArray(stat.loot) or {},
            }
        end
    end

    return copy
end

local function CreateActiveRunSnapshot(self, activeRun)
    if type(activeRun) ~= "table" then
        return nil
    end

    return {
        runId = activeRun.runId,
        startedAt = activeRun.startedAt,
        completedAt = activeRun.completedAt,
        state = activeRun.state,
        mapChallengeModeID = activeRun.mapChallengeModeID,
        mapID = activeRun.mapID,
        dungeonName = activeRun.dungeonName,
        keyLevel = activeRun.keyLevel,
        timeLimitSeconds = activeRun.timeLimitSeconds,
        affixIDs = type(activeRun.affixIDs) == "table" and self:CopyArray(activeRun.affixIDs) or {},
        participants = CopySet(activeRun.participants),
        participantOrder = type(activeRun.participantOrder) == "table" and self:CopyArray(activeRun.participantOrder) or {},
        playerStats = CopyActiveRunPlayerStats(self, activeRun.playerStats),
        deathState = CopySet(activeRun.deathState),
        totalDeaths = tonumber(activeRun.totalDeaths) or 0,
        deathPenaltySeconds = tonumber(activeRun.deathPenaltySeconds) or 0,
        sessionIDs = CopySet(activeRun.sessionIDs),
        excludedSessionIDs = CopySet(activeRun.excludedSessionIDs),
        completionPending = activeRun.completionPending and true or false,
        pendingCompletionSource = activeRun.pendingCompletionSource,
        pendingCompletionInfo = CopyCompletionInfo(activeRun.pendingCompletionInfo),
        finalizationInProgress = false,
        completionSignals = CopySet(activeRun.completionSignals),
        restoredFromReload = activeRun.restoredFromReload and true or false,
        allowCompletionRecovery = activeRun.allowCompletionRecovery and true or false,
        scenarioCompletedAt = activeRun.scenarioCompletedAt,
        inactiveResolutionQueued = false,
        lootFinalizeDeadline = activeRun.lootFinalizeDeadline,
        damageMeterResetSuspected = activeRun.damageMeterResetSuspected and true or false,
        damageMeterResetVerified = activeRun.damageMeterResetVerified and true or false,
        damageMeterResetRecovered = activeRun.damageMeterResetRecovered and true or false,
        damageMeterResetSnapshot = CopySet(activeRun.damageMeterResetSnapshot),
        damageMeterResetAt = activeRun.damageMeterResetAt,
    }
end

function MythicTools:PushRuntimeDebug(message)
    if not (self.runtime and message) then
        return
    end

    local buffer = self.runtime.debugLog
    if type(buffer) ~= "table" then
        buffer = {}
        self.runtime.debugLog = buffer
    end

    buffer[#buffer + 1] = ("%s %s"):format(date("%H:%M:%S"), tostring(message))
    while #buffer > DEBUG_EVENT_BUFFER_SIZE do
        table.remove(buffer, 1)
    end
end

function MythicTools:UpdateActiveRunSnapshot(activeRun)
    if not (self.runtime and type(activeRun) == "table") then
        return
    end

    self.runtime.lastActiveRunSnapshot = CreateActiveRunSnapshot(self, activeRun)
end

function MythicTools:RememberPendingCompletionSnapshot(activeRun, reason)
    if not (self.runtime and type(activeRun) == "table") then
        return nil
    end

    local snapshot = CreateActiveRunSnapshot(self, activeRun)
    if type(snapshot) ~= "table" then
        return nil
    end

    snapshot.completionPending = true
    snapshot.allowCompletionRecovery = true
    snapshot.pendingSnapshotReason = reason or "unknown"

    local pending = self.runtime.pendingCompletionSnapshots
    if type(pending) ~= "table" then
        pending = {}
        self.runtime.pendingCompletionSnapshots = pending
    end

    for index, existing in ipairs(pending) do
        if type(existing) == "table" and existing.runId == snapshot.runId then
            pending[index] = snapshot
            self:PushRuntimeDebug(("refresh pending snapshot run %s from %s"):format(tostring(snapshot.runId), tostring(reason or "unknown")))
            return snapshot
        end
    end

    pending[#pending + 1] = snapshot
    self:PushRuntimeDebug(("remember pending snapshot run %s from %s"):format(tostring(snapshot.runId), tostring(reason or "unknown")))
    return snapshot
end

function MythicTools:ForgetRecoveryState(runId)
    runId = tonumber(runId)
    if not (self.runtime and runId) then
        return
    end

    if type(self.runtime.lastActiveRunSnapshot) == "table" and tonumber(self.runtime.lastActiveRunSnapshot.runId) == runId then
        self.runtime.lastActiveRunSnapshot = nil
    end

    local pending = self.runtime.pendingCompletionSnapshots
    if type(pending) ~= "table" then
        return
    end

    for index = #pending, 1, -1 do
        local snapshot = pending[index]
        if type(snapshot) == "table" and tonumber(snapshot.runId) == runId then
            table.remove(pending, index)
        end
    end
end

function MythicTools:GetRecoverableCompletionSnapshot(mapChallengeModeID, level)
    if not self.runtime then
        return nil
    end

    local expectedMapID = tonumber(mapChallengeModeID) or 0
    local expectedLevel = tonumber(level) or 0

    local function SnapshotMatches(snapshot)
        if type(snapshot) ~= "table" then
            return false
        end

        local snapshotMapID = tonumber(snapshot.mapChallengeModeID) or 0
        local snapshotLevel = tonumber(snapshot.keyLevel) or 0
        local mapMatches = expectedMapID <= 0 or snapshotMapID <= 0 or snapshotMapID == expectedMapID
        local levelMatches = expectedLevel <= 0 or snapshotLevel <= 0 or snapshotLevel == expectedLevel
        return mapMatches and levelMatches
    end

    local pending = self.runtime.pendingCompletionSnapshots
    if type(pending) == "table" then
        for index = #pending, 1, -1 do
            if SnapshotMatches(pending[index]) then
                return pending[index]
            end
        end
    end

    local snapshot = self.runtime.lastActiveRunSnapshot
    if SnapshotMatches(snapshot) then
        return snapshot
    end

    return nil
end

function MythicTools:RestoreActiveRunFromSnapshot(snapshot, reason, completionInfo)
    if type(snapshot) ~= "table" then
        return nil
    end

    local restoredRun = CreateActiveRunSnapshot(self, snapshot)
    if type(restoredRun) ~= "table" then
        return nil
    end

    if IsValidCompletionInfo(completionInfo) then
        restoredRun.pendingCompletionInfo = CopyCompletionInfo(completionInfo)
        restoredRun.pendingCompletionSource = restoredRun.pendingCompletionSource or reason or "recovered"
    end

    restoredRun.restoredFromReload = true
    restoredRun.allowCompletionRecovery = true
    restoredRun.finalizationInProgress = false
    restoredRun.inactiveResolutionQueued = false
    restoredRun.state = restoredRun.state or "running"

    self.runtime.activeRun = restoredRun
    self.EventFrame:RegisterEvent("UNIT_HEALTH")
    self:UpdateActiveRunSnapshot(restoredRun)
    self:PushRuntimeDebug(("restore active run %s from %s"):format(tostring(restoredRun.runId), tostring(reason or "snapshot")))
    return restoredRun
end

function MythicTools:QueuePendingCompletionProcessing(trigger)
    if not (self.runtime and not self.runtime.pendingCompletionProcessingQueued) then
        return
    end

    local pending = self.runtime.pendingCompletionSnapshots
    if type(pending) ~= "table" or #pending == 0 then
        return
    end

    self.runtime.pendingCompletionProcessingQueued = true
    self:Schedule(INACTIVE_RESOLUTION_DELAY, function()
        if not self.runtime then
            return
        end

        self.runtime.pendingCompletionProcessingQueued = false
        if C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
            return
        end

        if self.ProcessPendingCompletionSnapshots then
            self:ProcessPendingCompletionSnapshots(trigger or "PLAYER_ENTERING_WORLD", true)
        end
    end)
end

function MythicTools:SetActiveRunState(activeRun, newState)
    if type(activeRun) ~= "table" or activeRun.state == newState then
        return
    end

    activeRun.state = newState
    self:PushRuntimeDebug(("run %s state=%s"):format(tostring(activeRun.runId), tostring(newState)))
end

function MythicTools:MarkCompletionSignal(activeRun, signal)
    if type(activeRun) ~= "table" or type(signal) ~= "string" or signal == "" then
        return
    end

    local signals = type(activeRun.completionSignals) == "table" and activeRun.completionSignals or {}
    activeRun.completionSignals = signals
    signals[signal] = signals[signal] or time()
    self:PushRuntimeDebug(("run %s signal=%s"):format(tostring(activeRun.runId), signal))
end

function MythicTools:HasCompletionSignals(activeRun)
    if type(activeRun) ~= "table" then
        return false
    end

    for _ in pairs(activeRun.completionSignals or {}) do
        return true
    end

    return false
end

function MythicTools:HasCompletionSignal(activeRun, signal)
    return type(activeRun) == "table"
        and type(activeRun.completionSignals) == "table"
        and activeRun.completionSignals[signal] ~= nil
end

function MythicTools:ShouldUseEarlyCompletionRecovery(activeRun, attempt)
    if type(activeRun) ~= "table" then
        return false
    end

    attempt = tonumber(attempt) or 0
    if attempt < 2 then
        return false
    end

    if self.runtime and self.runtime.lastCompletionRewards ~= nil then
        return true
    end

    if self:HasCompletionSignal(activeRun, "SCENARIO_COMPLETED") and self:HasCompletionSignal(activeRun, "CHALLENGE_MODE_COMPLETED") then
        return true
    end

    if not (C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()) then
        return self:HasCompletionSignals(activeRun)
    end

    return false
end

function MythicTools:QueueInactiveRunResolution(activeRun, trigger)
    if type(activeRun) ~= "table" or activeRun.inactiveResolutionQueued then
        return
    end

    activeRun.inactiveResolutionQueued = true
    self:PushRuntimeDebug(("run %s queue inactive resolution from %s"):format(tostring(activeRun.runId), tostring(trigger or "unknown")))
    self:Schedule(INACTIVE_RESOLUTION_DELAY, function()
        if not self.runtime or self.runtime.activeRun ~= activeRun then
            return
        end

        activeRun.inactiveResolutionQueued = false
        if C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
            return
        end

        self:HandleChallengeModeInactive(trigger or "PLAYER_ENTERING_WORLD")
    end)
end

function MythicTools:ScheduleLootTrackingTimeout(tracking)
    if type(tracking) ~= "table" then
        return
    end

    self:Schedule(LOOT_TRACKING_TIMEOUT, function()
        if not (self.runtime and self.runtime.lootTracking == tracking) then
            return
        end

        if tracking.lootClosed then
            return
        end

        local deadline = tonumber(tracking.lootFinalizeDeadline) or 0
        if deadline > 0 and time() < deadline then
            self:ScheduleLootTrackingTimeout(tracking)
            return
        end

        self:PushRuntimeDebug(("loot tracking timeout run %s"):format(tostring(tracking.runId)))
        self:StopLootTracking()
    end)
end

function MythicTools:ScheduleLootPopupFallback(tracking)
    if type(tracking) ~= "table" then
        return
    end

    self:Schedule(LOOT_POPUP_FALLBACK_DELAY, function()
        if not (self.runtime and self.runtime.lootTracking == tracking) then
            return
        end

        if tracking.lootClosed or tracking.popupFallbackTriggered then
            return
        end

        local pendingPopup = self.runtime.pendingCompletionPopup
        if type(pendingPopup) ~= "table" or pendingPopup.runId ~= tracking.runId then
            return
        end

        tracking.popupFallbackTriggered = true
        self:PushRuntimeDebug(("loot popup fallback run %s after %ss"):format(
            tostring(tracking.runId),
            tostring(LOOT_POPUP_FALLBACK_DELAY)
        ))

        if self.ResolvePendingCompletionPopup then
            self:ResolvePendingCompletionPopup("LOOT_CLOSED")
        end
    end)
end

function MythicTools:RequestMythicPlusData()
    if not C_MythicPlus then
        return
    end

    if C_MythicPlus.RequestMapInfo then
        pcall(C_MythicPlus.RequestMapInfo)
    end

    if C_MythicPlus.RequestRewards then
        pcall(C_MythicPlus.RequestRewards)
    end
end

function MythicTools:GetMythicPlusRunHistory()
    if not (C_MythicPlus and C_MythicPlus.GetRunHistory) then
        return nil
    end

    if self.RequestMythicPlusData then
        self:RequestMythicPlusData()
    end

    local ok, runs = pcall(C_MythicPlus.GetRunHistory, true, true, true)
    if ok and type(runs) == "table" then
        return runs
    end

    ok, runs = pcall(C_MythicPlus.GetRunHistory, true, true)
    if ok and type(runs) == "table" then
        return runs
    end

    ok, runs = pcall(C_MythicPlus.GetRunHistory)
    if ok and type(runs) == "table" then
        return runs
    end

    return nil
end

function MythicTools:GetRunHistoryCompletionInfo(activeRun)
    local runs = self:GetMythicPlusRunHistory()
    if type(runs) ~= "table" or #runs == 0 then
        return nil
    end

    local expectedMapID = tonumber(activeRun and activeRun.mapChallengeModeID) or 0
    local expectedLevel = tonumber(activeRun and activeRun.keyLevel) or 0
    local expectedCompletedAt = tonumber(activeRun and activeRun.completedAt) or time()
    local bestRun, bestScore

    local function NormalizeHistoryTimestamp(value)
        value = tonumber(value) or 0
        if value <= 0 then
            return 0
        end
        if value > 1000000000000 then
            value = value / 1000
        end
        return value
    end

    for index, runInfo in ipairs(runs) do
        if type(runInfo) == "table" then
            local mapChallengeModeID = tonumber(runInfo.mapChallengeModeID or runInfo.challengeModeMapID or runInfo.mapID) or 0
            local level = tonumber(runInfo.level or runInfo.keystoneLevel) or 0
            local durationSeconds = tonumber(runInfo.durationSec or runInfo.time or runInfo.duration) or 0
            local completedAt = NormalizeHistoryTimestamp(runInfo.completedDate or runInfo.completedAt or runInfo.completedTime or runInfo.timestamp or runInfo.endTime)
            local completed = runInfo.completed
            local score = (#runs - index)
            local mapMatches = expectedMapID <= 0 or mapChallengeModeID == expectedMapID
            local levelMatches = expectedLevel <= 0 or level == expectedLevel
            local timeMatches = completedAt <= 0 or expectedCompletedAt <= 0 or math.abs(completedAt - expectedCompletedAt) <= 1800

            if completed ~= false and mapMatches and levelMatches and timeMatches and mapChallengeModeID > 0 and level > 0 and durationSeconds > 0 then
                if expectedMapID > 0 and mapChallengeModeID == expectedMapID then
                    score = score + 10
                end
                if expectedLevel > 0 and level == expectedLevel then
                    score = score + 6
                end
                if completedAt > 0 and expectedCompletedAt > 0 then
                    score = score + math.max(0, 4 - math.floor(math.abs(completedAt - expectedCompletedAt) / 300))
                end

                if not bestScore or score > bestScore then
                    bestRun = runInfo
                    bestScore = score
                end
            end
        end
    end

    if type(bestRun) ~= "table" then
        return nil
    end

    local mapChallengeModeID = tonumber(bestRun.mapChallengeModeID or bestRun.challengeModeMapID or bestRun.mapID) or 0
    local level = tonumber(bestRun.level or bestRun.keystoneLevel) or 0
    local durationSeconds = tonumber(bestRun.durationSec or bestRun.time or bestRun.duration) or 0
    local mapInfo = GetMapInfo(mapChallengeModeID)
    local timeLimitSeconds = tonumber(mapInfo and mapInfo.timeLimit) or tonumber(activeRun and activeRun.timeLimitSeconds) or 0

    if mapChallengeModeID <= 0 or level <= 0 or durationSeconds <= 0 then
        return nil
    end

    return {
        mapChallengeModeID = mapChallengeModeID,
        level = level,
        time = math.floor((durationSeconds * 1000) + 0.5),
        onTime = timeLimitSeconds > 0 and durationSeconds <= timeLimitSeconds or nil,
        keystoneUpgradeLevels = 0,
        practiceRun = false,
        oldOverallDungeonScore = nil,
        newOverallDungeonScore = nil,
        isMapRecord = nil,
        isAffixRecord = nil,
        primaryAffix = nil,
        isEligibleForScore = nil,
        members = BuildCompletionMembersFromActiveRun(activeRun),
    }
end

function MythicTools:GetResolvedChallengeCompletionInfo(activeRun, allowEstimated)
    local pendingInfo = type(activeRun) == "table" and activeRun.pendingCompletionInfo or nil
    if IsValidCompletionInfo(pendingInfo) then
        return pendingInfo
    end

    local completionInfo = GetChallengeCompletionInfoCompat()
    if IsValidCompletionInfo(completionInfo) then
        return SetCachedCompletionInfo(activeRun, completionInfo, "native")
    end

    local rewardsInfo = self.runtime and self.runtime.lastCompletionRewards or nil
    local mapChallengeModeID = tonumber(rewardsInfo and rewardsInfo.mapChallengeModeID) or tonumber(activeRun and activeRun.mapChallengeModeID) or 0
    local level = tonumber(activeRun and activeRun.keyLevel) or 0
    local mapInfo = GetMapInfo(mapChallengeModeID)
    local timeLimitSeconds = tonumber(mapInfo and mapInfo.timeLimit) or tonumber(activeRun and activeRun.timeLimitSeconds) or 0
    local endTimestamp = tonumber(activeRun and activeRun.completedAt) or tonumber(rewardsInfo and rewardsInfo.receivedAt) or time()
    local startedAt = tonumber(activeRun and activeRun.startedAt) or endTimestamp
    local rewardTimeMS = tonumber(rewardsInfo and rewardsInfo.timeMS) or 0

    if mapChallengeModeID > 0 and level > 0 and rewardTimeMS > 0 then
        local fallbackInfo = {
            mapChallengeModeID = mapChallengeModeID,
            level = level,
            time = rewardTimeMS,
            onTime = timeLimitSeconds > 0 and rewardTimeMS <= (timeLimitSeconds * 1000) or nil,
            keystoneUpgradeLevels = 0,
            practiceRun = false,
            oldOverallDungeonScore = nil,
            newOverallDungeonScore = nil,
            isMapRecord = nil,
            isAffixRecord = nil,
            primaryAffix = nil,
            isEligibleForScore = true,
            members = BuildCompletionMembersFromActiveRun(activeRun),
        }
        return SetCachedCompletionInfo(activeRun, fallbackInfo, "rewards")
    end

    local allowRecovery = allowEstimated and type(activeRun) == "table" and (activeRun.restoredFromReload or activeRun.allowCompletionRecovery)
    if allowRecovery then
        local historyInfo = self:GetRunHistoryCompletionInfo(activeRun)
        if IsValidCompletionInfo(historyInfo) then
            return SetCachedCompletionInfo(activeRun, historyInfo, "history")
        end
    end

    return nil
end

local function GetObservedPlayerMythicScore(fullName)
    if type(fullName) ~= "string" or fullName == "" then
        return nil
    end

    local shortName = MythicTools:GetShortName(fullName)
    local openRaidLib = LibStub and LibStub:GetLibrary("LibOpenRaid-1.0", true) or nil
    if openRaidLib and type(openRaidLib.GetKeystoneInfo) == "function" then
        local keystoneInfo = openRaidLib.GetKeystoneInfo(fullName) or openRaidLib.GetKeystoneInfo(shortName)
        local rating = keystoneInfo and tonumber(keystoneInfo.rating or keystoneInfo.currentSeasonScore) or nil
        if rating then
            return rating
        end
    end

    if _G.PlayerInfo and type(_G.GetPlayerInfo) == "function" then
        local playerInfo = _G.GetPlayerInfo(fullName) or _G.GetPlayerInfo(shortName)
        local keystoneInfo = type(playerInfo) == "table" and playerInfo.keystoneInfo or nil
        local rating = keystoneInfo and tonumber(keystoneInfo.rating or keystoneInfo.currentSeasonScore) or nil
        if rating then
            return rating
        end
    end

    if MythicTools.playerName == fullName and C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local ratingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
        local rating = ratingSummary and tonumber(ratingSummary.currentSeasonScore) or nil
        if rating then
            return rating
        end
    end

    return nil
end

local function GetCombatSourceTotalAmount(source)
    if type(source) ~= "table" then
        return 0
    end

    if type(source.totalAmount) == "number" then
        return source.totalAmount
    end

    if type(source.amount) == "number" then
        return source.amount
    end

    if type(source.totalInterrupts) == "number" then
        return source.totalInterrupts
    end

    if type(source.value) == "number" then
        return source.value
    end

    return 0
end

local function NormalizeStatNumber(value)
    local numberValue = tonumber(value)
    if numberValue == nil then
        return nil
    end

    return numberValue
end

local function NormalizeInterruptCount(value)
    local numberValue = tonumber(value)
    if numberValue == nil then
        return nil
    end

    return math.floor(numberValue + 0.5)
end

local function SafeDetailsMethod(target, methodName, ...)
    if type(target) ~= "table" then
        return nil
    end

    local method = target[methodName]
    if type(method) ~= "function" then
        return nil
    end

    local ok, result1, result2, result3, result4, result5, result6, result7, result8, result9, result10, result11 =
        pcall(method, target, ...)
    if not ok then
        return nil
    end

    return result1, result2, result3, result4, result5, result6, result7, result8, result9, result10, result11
end

local function GetDetailsActorMethodValue(actor, methodName)
    local value = SafeDetailsMethod(actor, methodName)
    if value ~= nil then
        return value
    end

    if type(actor) == "table" then
        local rawValue = actor[methodName]
        if type(rawValue) ~= "function" then
            return rawValue
        end
    end

    return nil
end

local function ExtractDetailsMythicInfo(details, combat)
    local mythicInfo = SafeDetailsMethod(combat, "GetMythicDungeonInfo")
    if type(mythicInfo) ~= "table" then
        return nil
    end

    local info = {
        raw = mythicInfo,
    }

    local unpack = details and details.UnpackMythicDungeonInfo
    if type(unpack) == "function" then
        local ok, isOverall, segmentID, level, ejID, mapID, zoneName, encounterID, encounterName, startedAt, endedAt, runID =
            pcall(unpack, details, mythicInfo)
        if ok then
            info.isOverall = isOverall and true or false
            info.segmentID = segmentID
            info.level = tonumber(level) or 0
            info.ejID = ejID
            info.mapID = tonumber(mapID) or 0
            info.zoneName = zoneName
            info.encounterID = encounterID
            info.encounterName = encounterName
            info.startedAt = tonumber(startedAt) or 0
            info.endedAt = tonumber(endedAt) or 0
            info.runID = runID
        end
    end

    info.level = info.level or tonumber(mythicInfo.level or mythicInfo.mythicLevel or mythicInfo.keyLevel) or 0
    info.mapID = info.mapID or tonumber(mythicInfo.mapID or mythicInfo.uiMapID or mythicInfo.mapId or mythicInfo.challengeMapID) or 0
    info.startedAt = info.startedAt or tonumber(mythicInfo.startedAt or mythicInfo.startTime or mythicInfo.started_at) or 0
    info.endedAt = info.endedAt or tonumber(mythicInfo.endedAt or mythicInfo.endTime or mythicInfo.ended_at) or 0
    info.runID = info.runID or mythicInfo.runID or mythicInfo.runId

    if info.isOverall == nil then
        local isOverallSegment = SafeDetailsMethod(combat, "IsMythicDungeonOverall")
        info.isOverall = isOverallSegment and true or false
    end

    return info
end

local function ScoreDetailsCombat(details, combat, run)
    local info = ExtractDetailsMythicInfo(details, combat)
    if not info then
        return nil, nil
    end

    local score = 0
    local isMythicDungeon = SafeDetailsMethod(combat, "IsMythicDungeon")
    if isMythicDungeon then
        score = score + 4
    end
    if info.isOverall then
        score = score + 8
    end

    if info.mapID ~= 0 and (info.mapID == (run.mapID or 0) or info.mapID == (run.mapChallengeModeID or 0)) then
        score = score + 8
    end
    if info.zoneName and run.dungeonName and MythicTools:Lower(info.zoneName) == MythicTools:Lower(run.dungeonName) then
        score = score + 5
    end
    if info.level ~= 0 and info.level == (run.level or 0) then
        score = score + 6
    end
    if info.startedAt ~= 0 and run.startTime and math.abs(info.startedAt - run.startTime) <= 900 then
        score = score + 3
    end
    if info.endedAt ~= 0 and run.endTime and math.abs(info.endedAt - run.endTime) <= 900 then
        score = score + 4
    end
    if info.runID then
        score = score + 1
    end

    return score, info
end

local function GetDetailsActorsIterator(container)
    local listActors = type(container) == "table" and container.ListActors
    if type(listActors) ~= "function" then
        return nil
    end

    local ok, iterator, state, initial = pcall(listActors, container)
    if not ok then
        return nil
    end

    return iterator, state, initial
end

local function GetDetailsCombatContainer(combat, attribute)
    local container = SafeDetailsMethod(combat, "GetContainer", attribute)
    if type(container) == "table" then
        return container
    end

    if type(combat) ~= "table" then
        return nil
    end

    local rawContainer = combat[attribute]
    if type(rawContainer) == "table" then
        return rawContainer
    end

    return nil
end

local function GetDetailsActorIdentity(actor)
    local actorName = GetDetailsActorMethodValue(actor, "Name")
    if type(actorName) ~= "string" or actorName == "" then
        actorName = GetDetailsActorMethodValue(actor, "name")
    end
    if type(actorName) ~= "string" or actorName == "" then
        actorName = GetDetailsActorMethodValue(actor, "GetOnlyName")
    end
    if type(actorName) ~= "string" or actorName == "" then
        actorName = GetDetailsActorMethodValue(actor, "GetDisplayName")
    end

    local actorGUID = GetDetailsActorMethodValue(actor, "GetGUID")
    if type(actorGUID) ~= "string" or actorGUID == "" then
        actorGUID = GetDetailsActorMethodValue(actor, "guid")
    end
    if (type(actorGUID) ~= "string" or actorGUID == "") and type(actor) == "table" then
        actorGUID = actor.serial or actor.guid
    end

    local classFilename = GetDetailsActorMethodValue(actor, "Class")
    if type(classFilename) ~= "string" or classFilename == "" then
        classFilename = GetDetailsActorMethodValue(actor, "class")
    end
    if (type(classFilename) ~= "string" or classFilename == "") and type(actor) == "table" then
        classFilename = actor.class or actor.classe
    end

    return actorName, actorGUID, classFilename
end

local function GetDetailsActorSpecID(actor)
    local specID = GetDetailsActorMethodValue(actor, "Spec")
    if specID == nil then
        specID = GetDetailsActorMethodValue(actor, "spec")
    end

    return tonumber(specID) or nil
end

local function GetDetailsActorScore(actor, actorName, fullName)
    local rating = type(actor) == "table" and actor.mrating or nil
    if type(rating) == "table" then
        rating = rating.currentSeasonScore or rating.score or rating.value or rating.rating
    end

    local score = tonumber(rating) or 0
    local previousScore = score

    if _G.Details and type(_G.Details.PlayerRatings) == "table" then
        local candidates = {}
        if type(fullName) == "string" and fullName ~= "" then
            candidates[#candidates + 1] = fullName
            candidates[#candidates + 1] = MythicTools:GetShortName(fullName)
        end
        if type(actorName) == "string" and actorName ~= "" then
            candidates[#candidates + 1] = actorName
            local normalizedActorName = MythicTools:NormalizePlayerName(actorName)
            if normalizedActorName then
                candidates[#candidates + 1] = normalizedActorName
                candidates[#candidates + 1] = MythicTools:GetShortName(normalizedActorName)
            end
        end

        for _, candidate in ipairs(candidates) do
            local value = tonumber(_G.Details.PlayerRatings[candidate])
            if value then
                previousScore = value
                break
            end
        end
    end

    return score, previousScore
end

local function GetDetailsActorAmount(actor, fieldName)
    if type(actor) ~= "table" then
        return nil
    end

    if fieldName == "damage" or fieldName == "healing" then
        local total = NormalizeStatNumber(actor.total)
        if total ~= nil then
            return total
        end

        total = NormalizeStatNumber(actor.total_without_pet)
        if total ~= nil then
            return total
        end

        return nil
    end

    if fieldName == "interrupts" then
        local interrupts = NormalizeInterruptCount(actor.interrupt)
        if interrupts ~= nil then
            return interrupts
        end

        interrupts = NormalizeInterruptCount(actor.interrupts)
        if interrupts ~= nil then
            return interrupts
        end

        interrupts = NormalizeInterruptCount(actor.total)
        if interrupts ~= nil then
            return interrupts
        end
    end

    return nil
end

local function AddUniqueDetailsCombat(candidates, seen, combat)
    if type(combat) ~= "table" or seen[combat] then
        return
    end

    seen[combat] = true
    candidates[#candidates + 1] = combat
end

local function GetDetailsTimeDistance(info, run)
    local distance = 0

    if type(info) ~= "table" or type(run) ~= "table" then
        return math.huge
    end

    local function CanCompareTimestamp(leftValue, rightValue)
        if not leftValue or not rightValue or leftValue == 0 or rightValue == 0 then
            return false
        end

        local leftEpochLike = leftValue > 100000000
        local rightEpochLike = rightValue > 100000000
        return leftEpochLike == rightEpochLike
    end

    if CanCompareTimestamp(info.startedAt, run.startTime) then
        distance = distance + math.abs(info.startedAt - run.startTime)
    end

    if CanCompareTimestamp(info.endedAt, run.endTime) then
        distance = distance + math.abs(info.endedAt - run.endTime)
    end

    return distance
end

local function DetailsCombatMatchesRun(info, run, referenceInfo, requireOverall)
    if type(info) ~= "table" or type(run) ~= "table" then
        return false
    end

    if requireOverall and not info.isOverall then
        return false
    end

    if info.level and info.level ~= 0 and run.level and run.level ~= 0 and info.level ~= run.level then
        return false
    end

    local runMapID = tonumber(run.mapID) or 0
    local challengeMapID = tonumber(run.mapChallengeModeID) or 0
    if info.mapID and info.mapID ~= 0 and runMapID ~= 0 and challengeMapID ~= 0 and info.mapID ~= runMapID and info.mapID ~= challengeMapID then
        if not (info.zoneName and run.dungeonName and MythicTools:Lower(info.zoneName) == MythicTools:Lower(run.dungeonName)) then
            return false
        end
    end

    if info.zoneName and run.dungeonName and MythicTools:Lower(info.zoneName) ~= MythicTools:Lower(run.dungeonName) and info.mapID == 0 and runMapID == 0 and challengeMapID == 0 then
        return false
    end

    if referenceInfo and referenceInfo.runID and info.runID then
        return referenceInfo.runID == info.runID
    end

    local referenceStart = referenceInfo and tonumber(referenceInfo.startedAt) or tonumber(run.startTime) or 0
    local referenceEnd = referenceInfo and tonumber(referenceInfo.endedAt) or tonumber(run.endTime) or 0
    local infoStart = tonumber(info.startedAt) or 0
    local infoEnd = tonumber(info.endedAt) or 0

    local startComparable = (infoStart > 100000000 and referenceStart > 100000000) or (infoStart > 0 and infoStart <= 100000000 and referenceStart > 0 and referenceStart <= 100000000)
    local endComparable = (infoEnd > 100000000 and referenceEnd > 100000000) or (infoEnd > 0 and infoEnd <= 100000000 and referenceEnd > 0 and referenceEnd <= 100000000)

    if startComparable and referenceStart ~= 0 and infoStart ~= 0 and math.abs(infoStart - referenceStart) > 900 then
        return false
    end

    if endComparable and referenceEnd ~= 0 and infoEnd ~= 0 and math.abs(infoEnd - referenceEnd) > 900 then
        return false
    end

    return true
end

local function HasAnyRunStats(run)
    for _, stat in pairs(run.playerStats or {}) do
        if stat.damage ~= nil or stat.healing ~= nil or stat.interrupts ~= nil then
            return true
        end
    end

    return false
end

function MythicTools:GetAvailableCombatSessionSet()
    local sessionSet = {}

    if not C_DamageMeter then
        return sessionSet
    end

    local sessions
    if C_DamageMeter.GetAvailableCombatSessions then
        sessions = C_DamageMeter.GetAvailableCombatSessions()
    elseif C_DamageMeter.GetSessions then
        sessions = C_DamageMeter.GetSessions()
    end

    if type(sessions) ~= "table" then
        return sessionSet
    end

    for _, sessionInfo in ipairs(sessions) do
        local sessionID = type(sessionInfo) == "number" and sessionInfo or (sessionInfo and (sessionInfo.sessionID or sessionInfo.sessionId or sessionInfo.id))
        if type(sessionID) == "number" then
            sessionSet[sessionID] = true
        end
    end

    return sessionSet
end

function MythicTools:GetSortedSessionIDs(sessionSet)
    local sorted = {}

    for sessionID in pairs(sessionSet or {}) do
        sorted[#sorted + 1] = sessionID
    end

    table.sort(sorted)
    return sorted
end

function MythicTools:EnsureActiveRunPlayerStat(activeRun, fullName)
    activeRun.playerStats[fullName] = activeRun.playerStats[fullName] or {
        name = fullName,
        shortName = self:GetShortName(fullName),
        damage = nil,
        healing = nil,
        interrupts = nil,
        deaths = 0,
        loot = {},
        role = nil,
        specID = nil,
        specName = nil,
        specIconID = nil,
        score = nil,
        previousScore = nil,
        itemLevel = nil,
    }

    local stat = activeRun.playerStats[fullName]
    stat.loot = type(stat.loot) == "table" and stat.loot or {}
    return stat
end

function MythicTools:AddParticipantToActiveRun(activeRun, playerInfo)
    local fullName = playerInfo and playerInfo.name
    if not fullName then
        return
    end

    if playerInfo.guid and not self:IsPlayerGUID(playerInfo.guid) then
        return
    end

    if not activeRun.participants[fullName] then
        activeRun.participants[fullName] = true
        activeRun.participantOrder[#activeRun.participantOrder + 1] = fullName
    end

    local stat = self:EnsureActiveRunPlayerStat(activeRun, fullName)
    stat.name = fullName
    stat.shortName = self:GetShortName(fullName)

    if not stat.guid and playerInfo.guid then
        stat.guid = playerInfo.guid
    end

    if not stat.classFilename and playerInfo.classFilename then
        stat.classFilename = playerInfo.classFilename
    end

    local observedScore = GetObservedPlayerMythicScore(fullName)
    if observedScore then
        if stat.previousScore == nil then
            stat.previousScore = observedScore
        end
        if stat.score == nil then
            stat.score = observedScore
        end
    end

    if not stat.role and playerInfo.role then
        stat.role = self:NormalizeRole(playerInfo.role)
    end

    if not stat.specID and playerInfo.specID then
        stat.specID = tonumber(playerInfo.specID) or playerInfo.specID
    end

    if not stat.specName and playerInfo.specName then
        stat.specName = playerInfo.specName
    end

    if not stat.specIconID and playerInfo.specIconID then
        stat.specIconID = playerInfo.specIconID
    end

    if stat.specID and (not stat.specName or not stat.specIconID or not stat.role) then
        local specID, specName, specIconID, role = self:GetSpecInfo(stat.specID)
        stat.specID = specID or stat.specID
        stat.specName = stat.specName or specName
        stat.specIconID = stat.specIconID or specIconID
        stat.role = stat.role or role
    end

    activeRun.deathState[fullName] = playerInfo.isDead and true or false
    self:UpdateActiveRunSnapshot(activeRun)
end

function MythicTools:UpdateActiveRunParticipants()
    local activeRun = self.runtime.activeRun
    if not activeRun then
        return
    end

    for _, rosterEntry in ipairs(self:GetCurrentGroupRoster()) do
        self:AddParticipantToActiveRun(activeRun, rosterEntry)
    end

    self:UpdateActiveRunSnapshot(activeRun)
end

function MythicTools:UpdateActiveRunFromCompletionMembers(activeRun, members)
    if type(members) ~= "table" then
        return
    end

    for _, member in ipairs(members) do
        local fullName = self:NormalizePlayerName(member.name or member.memberName or member.fullName or member.playerName, member.realm or member.realmName)
        if fullName then
            local guid = member.memberGUID or member.guid or member.playerGUID
            if guid and not self:CanAccessValue(guid) then
                guid = nil
            end

            if guid and not self:IsPlayerGUID(guid) then
                guid = nil
                fullName = nil
            end

            if fullName and not guid and not activeRun.participants[fullName] then
                fullName = nil
            end

            if fullName then
                self:AddParticipantToActiveRun(activeRun, {
                    name = fullName,
                    guid = guid,
                    classFilename = member.classFilename or member.classFileName,
                    role = member.role or member.assignedRole or member.combatRole,
                    specID = member.specID or member.specId or member.specializationID,
                    specName = member.specName or member.specializationName,
                    specIconID = member.specIconID or member.specIcon or member.specTexture,
                    isDead = false,
                })
            end
        end
    end

    self:UpdateActiveRunSnapshot(activeRun)
end

function MythicTools:CreateNewActiveRun(restored)
    local mapChallengeModeID = C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID() or 0
    local keyLevel, affixIDs = 0, {}

    if C_ChallengeMode.GetActiveKeystoneInfo then
        keyLevel, affixIDs = C_ChallengeMode.GetActiveKeystoneInfo()
    end

    local mapInfo = GetMapInfo(mapChallengeModeID)
    local activeRun = {
        runId = self.db.nextRunId or 1,
        startedAt = time(),
        completedAt = nil,
        state = "running",
        mapChallengeModeID = mapChallengeModeID,
        mapID = mapInfo and mapInfo.mapID or mapChallengeModeID,
        dungeonName = mapInfo and mapInfo.dungeonName or "Unknown",
        keyLevel = keyLevel or 0,
        timeLimitSeconds = mapInfo and mapInfo.timeLimit or 0,
        affixIDs = type(affixIDs) == "table" and self:CopyArray(affixIDs) or {},
        participants = {},
        participantOrder = {},
        playerStats = {},
        deathState = {},
        totalDeaths = 0,
        deathPenaltySeconds = 0,
        sessionIDs = {},
        excludedSessionIDs = restored and {} or self:GetAvailableCombatSessionSet(),
        completionPending = false,
        pendingCompletionSource = nil,
        pendingCompletionInfo = nil,
        finalizationInProgress = false,
        completionSignals = {},
        restoredFromReload = restored and true or false,
        allowCompletionRecovery = restored and true or false,
        scenarioCompletedAt = nil,
        inactiveResolutionQueued = false,
        lootFinalizeDeadline = nil,
        damageMeterResetSuspected = false,
        damageMeterResetVerified = false,
        damageMeterResetRecovered = false,
        damageMeterResetSnapshot = nil,
        damageMeterResetAt = nil,
    }

    self.runtime.activeRun = activeRun
    if self.runtime then
        self.runtime.lastCompletionRewards = nil
    end
    self:PushRuntimeDebug(("create active run %s map=%s level=%s restored=%s"):format(
        tostring(activeRun.runId),
        tostring(activeRun.mapChallengeModeID),
        tostring(activeRun.keyLevel),
        tostring(restored and true or false)
    ))
    self.EventFrame:RegisterEvent("UNIT_HEALTH")

    self:UpdateActiveRunParticipants()
    self:HandleChallengeDeathCountUpdated()
    self:UpdateActiveRunSnapshot(activeRun)

    return activeRun
end

function MythicTools:EnsureCompletionActiveRun(completionInfo, trigger)
    if self.runtime and type(self.runtime.activeRun) == "table" then
        return self.runtime.activeRun
    end

    local mapChallengeModeID = tonumber(completionInfo and completionInfo.mapChallengeModeID) or 0
    local level = tonumber(completionInfo and completionInfo.level) or 0
    local snapshot = self:GetRecoverableCompletionSnapshot(mapChallengeModeID, level)
    if type(snapshot) == "table" then
        return self:RestoreActiveRunFromSnapshot(snapshot, trigger or "completion", completionInfo)
    end

    if C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        local activeRun = self:CreateNewActiveRun(true)
        if IsValidCompletionInfo(completionInfo) then
            activeRun.pendingCompletionInfo = CopyCompletionInfo(completionInfo)
            activeRun.pendingCompletionSource = trigger or "completion"
            self:UpdateActiveRunSnapshot(activeRun)
        end
        return activeRun
    end

    return nil
end

function MythicTools:BeginActiveRunCompletion(trigger, completionInfo, source)
    local activeRun = self:EnsureCompletionActiveRun(completionInfo, trigger)
    if type(activeRun) ~= "table" then
        return nil
    end

    if activeRun.state == "finalized_completed" or activeRun.state == "finalized_abandoned" then
        return activeRun
    end

    self:UpdateActiveRunParticipants()
    self:HandleChallengeDeathCountUpdated()
    self:MarkCompletionSignal(activeRun, trigger or "unknown")

    activeRun.completedAt = tonumber(activeRun.completedAt) or time()
    activeRun.completionPending = true
    activeRun.allowCompletionRecovery = true
    activeRun.pendingCompletionSource = source or activeRun.pendingCompletionSource or trigger or "unknown"
    activeRun.scenarioCompletedAt = trigger == "SCENARIO_COMPLETED" and (activeRun.scenarioCompletedAt or time()) or activeRun.scenarioCompletedAt
    self:SetActiveRunState(activeRun, "finishing_completed")

    if IsValidCompletionInfo(completionInfo) then
        activeRun.pendingCompletionInfo = CopyCompletionInfo(completionInfo)
    elseif (trigger == "SCENARIO_COMPLETED" or trigger == "CHALLENGE_MODE_COMPLETED") and not IsValidCompletionInfo(activeRun.pendingCompletionInfo) then
        local recoveredInfo = BuildRecoveredCompletionInfo(activeRun)
        if IsValidCompletionInfo(recoveredInfo) then
            activeRun.pendingCompletionInfo = CopyCompletionInfo(recoveredInfo)
            activeRun.pendingCompletionSource = "runtime_recovery"
            self:PushRuntimeDebug(("run %s seeded recovered completion info from %s"):format(tostring(activeRun.runId), tostring(trigger)))
        end
    end

    local tracking = self.runtime and self.runtime.lootTracking or nil
    if self.StartLootTracking and (not tracking or tracking.runId ~= activeRun.runId) then
        self:StartLootTracking(activeRun.runId)
    elseif type(tracking) == "table" then
        tracking.lootFinalizeDeadline = time() + LOOT_TRACKING_TIMEOUT
        activeRun.lootFinalizeDeadline = tracking.lootFinalizeDeadline
    end

    if not activeRun.finalizationInProgress then
        self:FinalizeActiveRun(0)
    end

    self:UpdateActiveRunSnapshot(activeRun)

    return activeRun
end

function MythicTools:ClearDamageMeterResetSuspicion(activeRun)
    if type(activeRun) ~= "table" then
        return
    end

    activeRun.damageMeterResetSuspected = false
    activeRun.damageMeterResetRecovered = true
end

function MythicTools:ClearActiveRun()
    if self.runtime and self.runtime.activeRun then
        self:PushRuntimeDebug(("clear active run %s"):format(tostring(self.runtime.activeRun.runId)))
    end
    self.runtime.activeRun = nil
    self.EventFrame:UnregisterEvent("UNIT_HEALTH")
end

function MythicTools:TryRestoreActiveRun()
    if self.runtime.activeRun then
        return
    end

    local snapshot = self:GetRecoverableCompletionSnapshot()
    if type(snapshot) == "table" and (snapshot.state == "running" or snapshot.state == "finishing_completed") then
        self:RestoreActiveRunFromSnapshot(snapshot, "TryRestoreActiveRun")
        return
    end

    if C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        self:CreateNewActiveRun(true)
    end
end

function MythicTools:TryFinalizeInactiveActiveRun(activeRun, trigger, preResolvedInfo)
    if type(activeRun) ~= "table" then
        return false
    end

    local completionInfo = preResolvedInfo
    if not IsValidCompletionInfo(completionInfo) then
        completionInfo = self:GetResolvedChallengeCompletionInfo(activeRun, true)
    end
    if not IsValidCompletionInfo(completionInfo) then
        return false
    end

    self:BeginActiveRunCompletion(trigger or "inactive", completionInfo, activeRun.pendingCompletionSource)
    return true
end

function MythicTools:ForceFinalizeCompletedRun(activeRun, trigger)
    if type(activeRun) ~= "table" then
        return false
    end

    activeRun.allowCompletionRecovery = true
    activeRun.completionPending = true
    activeRun.completedAt = tonumber(activeRun.completedAt) or time()
    self:SetActiveRunState(activeRun, "finishing_completed")

    if self:FinalizeActiveRun(MAX_COMPLETION_ATTEMPTS) then
        return true
    end

    if self.runtime and self.runtime.activeRun == activeRun then
        local recoveredInfo = activeRun.pendingCompletionInfo
        if not IsValidCompletionInfo(recoveredInfo) then
            recoveredInfo = BuildRecoveredCompletionInfo(activeRun)
        end
        if IsValidCompletionInfo(recoveredInfo) then
            SetCachedCompletionInfo(activeRun, recoveredInfo, activeRun.pendingCompletionSource or "runtime_recovery")
            return self:FinalizeActiveRun(MAX_COMPLETION_ATTEMPTS)
        end
    end

    self:PushRuntimeDebug(("run %s force finalize failed from %s"):format(tostring(activeRun.runId), tostring(trigger or "unknown")))
    return self.runtime and self.runtime.activeRun ~= activeRun or false
end

function MythicTools:HandleChallengeModeInactive(trigger)
    local activeRun = self.runtime and self.runtime.activeRun or nil
    if type(activeRun) ~= "table" then
        return
    end

    activeRun.inactiveResolutionQueued = false
    self:PushRuntimeDebug(("run %s resolve inactive from %s"):format(tostring(activeRun.runId), tostring(trigger or "unknown")))

    local recoveredCompletionInfo = self:GetResolvedChallengeCompletionInfo(activeRun, true)
    local hasCompletionSignal = activeRun.completionPending
        or self:HasCompletionSignals(activeRun)
        or IsValidCompletionInfo(recoveredCompletionInfo)
        or (self.runtime and self.runtime.lastCompletionRewards ~= nil)

    if hasCompletionSignal then
        activeRun.allowCompletionRecovery = true

        if self:TryFinalizeInactiveActiveRun(activeRun, trigger, recoveredCompletionInfo) then
            return
        end

        if self:ForceFinalizeCompletedRun(activeRun, trigger) then
            return
        end

        self:UpdateActiveRunSnapshot(activeRun)
        self:QueueInactiveRunResolution(activeRun, tostring(trigger or "inactive") .. "_retry")
        return
    end

    self:FinalizeAbandonedActiveRun(activeRun)
end

function MythicTools:HandleChallengeModeStart()
    local activeRun = self.runtime and self.runtime.activeRun or nil

    if activeRun then
        if activeRun.completionPending or self:HasCompletionSignals(activeRun) then
            if not self:ForceFinalizeCompletedRun(activeRun, "CHALLENGE_MODE_START") and self.runtime and self.runtime.activeRun == activeRun then
                self:RememberPendingCompletionSnapshot(activeRun, "CHALLENGE_MODE_START")
                self:PushRuntimeDebug(("run %s could not be persisted before new start; preserving snapshot and clearing runtime state"):format(tostring(activeRun.runId)))
                self:ClearActiveRun()
            end
        else
            self:FinalizeAbandonedActiveRun(activeRun)
        end
    end

    self:ProcessPendingCompletionSnapshots("CHALLENGE_MODE_START", false)
    self:CreateNewActiveRun(false)
end

function MythicTools:HandleChallengeModeReset()
    local activeRun = self.runtime.activeRun
    if not activeRun then
        return
    end

    if activeRun.completionPending or self:HasCompletionSignals(activeRun) then
        activeRun.allowCompletionRecovery = true
        self:HandleChallengeModeInactive("CHALLENGE_MODE_RESET")
        return
    end

    self:FinalizeAbandonedActiveRun(activeRun)
end

function MythicTools:HandleChallengeDeathCountUpdated()
    local activeRun = self.runtime.activeRun
    if not activeRun or not C_ChallengeMode.GetDeathCount then
        return
    end

    local totalDeaths, timeLost = C_ChallengeMode.GetDeathCount()
    activeRun.totalDeaths = totalDeaths or 0
    activeRun.deathPenaltySeconds = timeLost or 0
    self:UpdateActiveRunSnapshot(activeRun)
end

function MythicTools:HandleUnitHealth(unit)
    local activeRun = self.runtime.activeRun
    if not activeRun or not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
        return
    end

    local fullName = self:GetUnitFullName(unit)
    if not fullName then
        return
    end

    if not activeRun.participants[fullName] then
        local role, specID, specName, specIconID = self:GetUnitRoleSpecInfo(unit)
        self:AddParticipantToActiveRun(activeRun, {
            name = fullName,
            guid = UnitGUID(unit),
            classFilename = select(2, UnitClass(unit)),
            role = role,
            specID = specID,
            specName = specName,
            specIconID = specIconID,
            isDead = UnitIsDeadOrGhost(unit) and not UnitIsFeignDeath(unit) or false,
        })
    end

    local isDead = UnitIsDeadOrGhost(unit) and not UnitIsFeignDeath(unit) or false
    local wasDead = activeRun.deathState[fullName] and true or false

    if isDead and not wasDead then
        local stat = self:EnsureActiveRunPlayerStat(activeRun, fullName)
        stat.deaths = (stat.deaths or 0) + 1
    end

    activeRun.deathState[fullName] = isDead
end

function MythicTools:TrackDamageMeterSessionsFromAvailableList()
    local activeRun = self.runtime.activeRun
    if not activeRun then
        return
    end

    for sessionID in pairs(self:GetAvailableCombatSessionSet()) do
        if not activeRun.excludedSessionIDs[sessionID] then
            activeRun.sessionIDs[sessionID] = true
        end
    end

    self:UpdateActiveRunSnapshot(activeRun)
end

function MythicTools:HandleDamageMeterSessionUpdated(...)
    local activeRun = self.runtime.activeRun
    if not activeRun then
        return
    end

    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "number" and not activeRun.excludedSessionIDs[value] then
            activeRun.sessionIDs[value] = true
        end
    end

    self:TrackDamageMeterSessionsFromAvailableList()

    if activeRun.damageMeterResetSuspected then
        self:ClearDamageMeterResetSuspicion(activeRun)
    end

    self:UpdateActiveRunSnapshot(activeRun)
end

function MythicTools:HandleDamageMeterCurrentSessionUpdated(...)
    self:HandleDamageMeterSessionUpdated(...)
end

function MythicTools:HandleDamageMeterReset()
    local activeRun = self.runtime.activeRun
    if not activeRun then
        return
    end

    if activeRun.completionPending then
        self:TrackDamageMeterSessionsFromAvailableList()
        return
    end

    activeRun.damageMeterResetSuspected = true
    activeRun.damageMeterResetVerified = false
    activeRun.damageMeterResetRecovered = false
    activeRun.damageMeterResetAt = time()
    activeRun.damageMeterResetSnapshot = self:GetAvailableCombatSessionSet()
    activeRun.excludedSessionIDs = activeRun.damageMeterResetSnapshot or {}
    self:UpdateActiveRunSnapshot(activeRun)
end

function MythicTools:GetTrackedSessionIDsForRun(activeRun)
    self:TrackDamageMeterSessionsFromAvailableList()
    return self:GetSortedSessionIDs(activeRun.sessionIDs)
end

function MythicTools:RefreshSavedRunStatsContext(activeRunContext)
    if type(activeRunContext) ~= "table" then
        return false
    end

    activeRunContext.sessionIDs = type(activeRunContext.sessionIDs) == "table" and activeRunContext.sessionIDs or {}
    activeRunContext.excludedSessionIDs = type(activeRunContext.excludedSessionIDs) == "table" and activeRunContext.excludedSessionIDs or {}

    local availableSessionSet = self:GetAvailableCombatSessionSet()
    local changed = MergeSessionSet(activeRunContext.sessionIDs, availableSessionSet, activeRunContext.excludedSessionIDs)
    return changed
end

function MythicTools:EnsureCompletedRunPlayer(run, fullName)
    if not run.playerStats[fullName] then
        run.playerStats[fullName] = {
            name = fullName,
            shortName = self:GetShortName(fullName),
            damage = nil,
            healing = nil,
            dps = nil,
            hps = nil,
            interrupts = nil,
            deaths = 0,
            loot = {},
            role = nil,
            specID = nil,
            specName = nil,
            specIconID = nil,
            score = nil,
            previousScore = nil,
            itemLevel = nil,
            damageActiveSeconds = nil,
            healingActiveSeconds = nil,
        }
        run.roster[#run.roster + 1] = fullName
    end

    local stat = run.playerStats[fullName]
    stat.loot = type(stat.loot) == "table" and stat.loot or {}
    return stat
end

function MythicTools:ResolveCompletedRunSource(run, guidMap, source)
    if not source then
        return nil
    end

    local sourceGUID = source.sourceGUID or source.guid or source.unitGUID or source.playerGUID or source.memberGUID
    if sourceGUID and self:CanAccessValue(sourceGUID) and not self:IsPlayerGUID(sourceGUID) then
        return nil
    end

    if sourceGUID and self:CanAccessValue(sourceGUID) and guidMap[sourceGUID] then
        return guidMap[sourceGUID]
    end

    local sourceName = source.name or source.fullName or source.unitName or source.playerName or source.memberName
    if sourceName and self:CanAccessValue(sourceName) then
        local normalized = self:NormalizePlayerName(sourceName)
        if normalized and run.playerStats[normalized] then
            return normalized
        end

        local shortName = self:GetShortName(normalized or sourceName)
        for fullName in pairs(run.playerStats) do
            if self:GetShortName(fullName) == shortName then
                return fullName
            end
        end
    end

    return nil
end

function MythicTools:ApplySourceMetadataToStat(stat, source)
    if type(stat) ~= "table" or type(source) ~= "table" then
        return
    end

    if not stat.classFilename then
        local classFilename = source.classFilename or source.classFileName or source.classToken or source.class
        if type(classFilename) == "string" and classFilename ~= "" then
            stat.classFilename = classFilename
        end
    end

    if not stat.role then
        stat.role = self:NormalizeRole(source.role or source.assignedRole or source.combatRole)
    end

    if not stat.specID then
        local specID = source.specID or source.specId or source.specializationID
        if specID then
            stat.specID = tonumber(specID) or specID
        end
    end

    if not stat.specName and type(source.specName or source.specializationName) == "string" then
        stat.specName = source.specName or source.specializationName
    end

    if not stat.specIconID then
        local specIconID = source.specIconID or source.specIcon or source.specTexture
        if type(specIconID) == "number" and specIconID ~= 0 then
            stat.specIconID = specIconID
        end
    end

    if stat.specID and (not stat.specName or not stat.specIconID or not stat.role) then
        local resolvedSpecID, specName, specIconID, role = self:GetSpecInfo(stat.specID)
        stat.specID = resolvedSpecID or stat.specID
        stat.specName = stat.specName or specName
        stat.specIconID = stat.specIconID or specIconID
        stat.role = stat.role or role
    end
end

function MythicTools:GetBestDetailsCombatForRun(run)
    local details = _G.Details
    if type(details) ~= "table" or type(run) ~= "table" then
        return nil, nil, nil
    end

    local candidates = {}
    local seen = {}

    AddUniqueDetailsCombat(candidates, seen, SafeDetailsMethod(details, "GetCurrentCombat"))

    local combatSegments = SafeDetailsMethod(details, "GetCombatSegments")
    if type(combatSegments) == "table" then
        for _, combat in ipairs(combatSegments) do
            AddUniqueDetailsCombat(candidates, seen, combat)
        end
    end

    local bestCombat, bestInfo
    local bestScore, bestDistance = nil, math.huge

    for _, combat in ipairs(candidates) do
        local score, info = ScoreDetailsCombat(details, combat, run)
        if score and info and info.isOverall and DetailsCombatMatchesRun(info, run, nil, true) then
            local distance = GetDetailsTimeDistance(info, run)
            if not bestScore or score > bestScore or (score == bestScore and distance < bestDistance) then
                bestCombat = combat
                bestInfo = info
                bestScore = score
                bestDistance = distance
            end
        end
    end

    if not bestCombat or not bestInfo or not bestScore then
        return details, nil, nil
    end

    if bestScore < 18 then
        return details, nil, nil
    end

    return details, bestCombat, bestInfo
end

function MythicTools:GetDetailsRunCombatSegments(details, run, overallInfo)
    if type(details) ~= "table" or type(run) ~= "table" or type(overallInfo) ~= "table" then
        return {}
    end

    local segments = {}
    local seen = {}

    local function TryAppendCombat(combat)
        if type(combat) ~= "table" or seen[combat] then
            return
        end

        local info = ExtractDetailsMythicInfo(details, combat)
        if not info or info.isOverall then
            return
        end

        if not SafeDetailsMethod(combat, "IsMythicDungeon") then
            return
        end

        if not DetailsCombatMatchesRun(info, run, overallInfo, false) then
            return
        end

        local combatTime = tonumber(SafeDetailsMethod(combat, "GetCombatTime")) or 0
        if combatTime <= 0 then
            return
        end

        seen[combat] = true
        segments[#segments + 1] = combat
    end

    TryAppendCombat(SafeDetailsMethod(details, "GetCurrentCombat"))

    local combatSegments = SafeDetailsMethod(details, "GetCombatSegments")
    if type(combatSegments) == "table" then
        for _, combat in ipairs(combatSegments) do
            TryAppendCombat(combat)
        end
    end

    return segments
end

function MythicTools:GetDetailsItemLevel(details, guid)
    if type(details) ~= "table" or type(guid) ~= "string" or guid == "" then
        return nil
    end

    local itemLevel = SafeDetailsMethod(details, "GetItemLevelFromGuid", guid)
    if tonumber(itemLevel) and tonumber(itemLevel) > 0 then
        return tonumber(itemLevel)
    end

    local ilevel = type(details.ilevel) == "table" and details.ilevel or nil
    local info = ilevel and SafeDetailsMethod(ilevel, "GetIlvl", guid) or nil
    if type(info) == "table" and tonumber(info.ilvl) and tonumber(info.ilvl) > 0 then
        return tonumber(info.ilvl)
    end

    return nil
end

function MythicTools:AccumulateDetailsContainer(details, run, combat, guidMap, attribute, fieldName, matchedPlayers)
    local container = GetDetailsCombatContainer(combat, attribute)
    if type(container) ~= "table" then
        return false
    end

    local iterator, state, initial = GetDetailsActorsIterator(container)
    if not iterator then
        return false
    end

    local foundValues = false
    local ok = pcall(function()
        for _, actor in iterator, state, initial do
            if type(actor) == "table" then
                local actorName, actorGUID, classFilename = GetDetailsActorIdentity(actor)
                local isPlayerActor = GetDetailsActorMethodValue(actor, "IsPlayer")
                local isGroupPlayer = GetDetailsActorMethodValue(actor, "IsGroupPlayer")
                if classFilename ~= "UNGROUPPLAYER" and isPlayerActor ~= false and isGroupPlayer ~= false then
                    local fullName = self:ResolveCompletedRunSource(run, guidMap, {
                        name = actorName,
                        guid = actorGUID,
                        classFilename = classFilename,
                    })
                    if fullName then
                        local stat = self:EnsureCompletedRunPlayer(run, fullName)
                        local amount = GetDetailsActorAmount(actor, fieldName)
                        if amount ~= nil then
                            stat[fieldName] = amount
                            foundValues = true
                        end

                        local score, previousScore = GetDetailsActorScore(actor, actorName, fullName)
                        if stat.score == nil or score > 0 then
                            stat.score = score
                            stat.previousScore = previousScore
                        end
                        local specID = GetDetailsActorSpecID(actor)
                        if specID and not stat.specID then
                            stat.specID = specID
                        end

                        if fieldName == "damage" then
                            local activeSeconds = tonumber(GetDetailsActorMethodValue(actor, "Tempo")) or nil
                            if activeSeconds and activeSeconds > 0 then
                                stat.damageActiveSeconds = activeSeconds
                            end
                        elseif fieldName == "healing" then
                            local activeSeconds = tonumber(GetDetailsActorMethodValue(actor, "Tempo")) or nil
                            if activeSeconds and activeSeconds > 0 then
                                stat.healingActiveSeconds = activeSeconds
                            end
                        end

                        if actorGUID and self:CanAccessValue(actorGUID) and self:IsPlayerGUID(actorGUID) and not stat.guid then
                            stat.guid = actorGUID
                            guidMap[actorGUID] = fullName
                        end

                        local itemLevel = self:GetDetailsItemLevel(details or _G.Details, actorGUID or stat.guid)
                        if itemLevel and itemLevel > 0 then
                            stat.itemLevel = itemLevel
                        end

                        self:ApplySourceMetadataToStat(stat, {
                            name = actorName,
                            guid = actorGUID,
                            classFilename = classFilename,
                            specID = specID,
                        })
                        matchedPlayers[fullName] = true
                    end
                end
            end
        end
    end)

    if not ok then
        return false
    end

    return foundValues
end

function MythicTools:AccumulateDetailsData(run)
    local details, combat, combatInfo = self:GetBestDetailsCombatForRun(run)
    if type(details) ~= "table" or type(combat) ~= "table" or type(combatInfo) ~= "table" then
        return false
    end

    local guidMap = {}
    for fullName, stat in pairs(run.playerStats or {}) do
        if stat.guid then
            guidMap[stat.guid] = fullName
        end
    end

    local matchedPlayers = {}
    local foundValues = false

    foundValues = self:AccumulateDetailsContainer(details, run, combat, guidMap, DETAILS_ATTRIBUTE_DAMAGE, "damage", matchedPlayers) or foundValues
    foundValues = self:AccumulateDetailsContainer(details, run, combat, guidMap, DETAILS_ATTRIBUTE_HEAL, "healing", matchedPlayers) or foundValues
    foundValues = self:AccumulateDetailsContainer(details, run, combat, guidMap, DETAILS_ATTRIBUTE_MISC, "interrupts", matchedPlayers) or foundValues

    local totalCombatSeconds = tonumber(SafeDetailsMethod(combat, "GetCombatTime"))
        or tonumber(combat.combatTime)
        or tonumber(combat.tempo)
        or tonumber(combat.elapsedCombatTime)
        or 0
    if totalCombatSeconds <= 0 then
        for _, segment in ipairs(self:GetDetailsRunCombatSegments(details, run, combatInfo)) do
            totalCombatSeconds = totalCombatSeconds + (
                tonumber(SafeDetailsMethod(segment, "GetCombatTime"))
                or tonumber(segment.combatTime)
                or tonumber(segment.tempo)
                or tonumber(segment.elapsedCombatTime)
                or 0
            )
        end
    end
    if totalCombatSeconds > 0 then
        run.combatTimeSeconds = totalCombatSeconds
        run.outOfCombatSeconds = math.max(0, ((tonumber(run.timeMS) or 0) / 1000) - totalCombatSeconds)
    end

    for fullName in pairs(matchedPlayers) do
        local stat = self:EnsureCompletedRunPlayer(run, fullName)
        if stat.damage == nil then
            stat.damage = 0
        end
        if stat.healing == nil then
            stat.healing = 0
        end
        if stat.interrupts == nil then
            stat.interrupts = 0
        end
    end

    return foundValues or next(matchedPlayers) ~= nil
end

local PARTY_DATA_DAMAGE_FIELDS = {"damageDone", "totalDamage", "damage", "damageTotal", "totalDamageDone", "totalAmount", "amount", "value"}
local PARTY_DATA_HEALING_FIELDS = {"healingDone", "totalHealing", "totalHeal", "healing", "healAmount", "totalHealingDone", "totalAmount", "amount", "value"}
local PARTY_DATA_INTERRUPT_FIELDS = {"interrupts", "totalInterrupts", "interruptCount", "successfulInterrupts", "interruptAmount", "totalAmount", "amount", "value"}

local function GetEntryAmount(entry, keys)
    if type(entry) ~= "table" then
        return nil
    end

    for _, key in ipairs(keys) do
        local value = entry[key]
        if type(value) == "number" then
            return value
        end
        if type(value) == "table" then
            for _, nestedKey in ipairs({"totalAmount", "amount", "damageDone", "healingDone", "totalDamage", "totalHealing", "totalHeal", "totalInterrupts", "interrupts", "value", "count"}) do
                if type(value[nestedKey]) == "number" then
                    return value[nestedKey]
                end
            end
        end
    end

    if type(entry.totalAmount) == "number" then
        return entry.totalAmount
    end

    if type(entry.amount) == "number" then
        return entry.amount
    end

    return nil
end

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

function MythicTools:GetPartyDataEntries(partyData)
    if type(partyData) ~= "table" then
        return {}
    end

    if #partyData > 0 then
        return partyData
    end

    if (partyData.name or partyData.guid or partyData.unitGUID or partyData.playerGUID) and (partyData.damageDone ~= nil or partyData.totalDamage ~= nil or partyData.healingDone ~= nil or partyData.totalHeal ~= nil or partyData.interrupts ~= nil or partyData.totalInterrupts ~= nil) then
        return {partyData}
    end

    for _, key in ipairs({"players", "party", "partyData", "members", "partyMembers", "combatSources"}) do
        local entries = partyData[key]
        if type(entries) == "table" and #entries > 0 then
            return entries
        end
    end

    local entries = {}
    for _, value in pairs(partyData) do
        if type(value) == "table" then
            entries[#entries + 1] = value
        end
    end

    return entries
end

local function GetCombatSessionDurationFromData(sessionData)
    if type(sessionData) ~= "table" then
        return nil
    end

    local duration = tonumber(sessionData.durationSeconds)
        or tonumber(sessionData.duration)
        or tonumber(sessionData.combatTime)
        or tonumber(sessionData.elapsedCombatTime)
        or tonumber(sessionData.totalTimeSeconds)
        or nil

    if duration and duration > 0 then
        return duration
    end

    local startedAt = tonumber(sessionData.startTime or sessionData.startedAt or sessionData.data_inicio) or 0
    local endedAt = tonumber(sessionData.endTime or sessionData.endedAt or sessionData.data_fim) or 0
    if startedAt > 0 and endedAt > startedAt then
        return endedAt - startedAt
    end

    return nil
end

local function SafeGetCombatSessionDuration(sessionProvider, ...)
    if type(sessionProvider) ~= "function" then
        return nil
    end

    local okSession, sessionData = pcall(sessionProvider, ...)
    if not okSession then
        return nil
    end

    local okDuration, duration = pcall(GetCombatSessionDurationFromData, sessionData)
    if not okDuration then
        return nil
    end

    if type(duration) ~= "number" or duration <= 0 then
        return nil
    end

    return duration
end

local function GetCurrentOverallCombatDurationFromDamageMeter()
    if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromType) then
        return nil
    end

    return SafeGetCombatSessionDuration(C_DamageMeter.GetCombatSessionFromType, 0, DAMAGE_DONE)
        or SafeGetCombatSessionDuration(C_DamageMeter.GetCombatSessionFromType, 0, HEALING_DONE)
        or SafeGetCombatSessionDuration(C_DamageMeter.GetCombatSessionFromType, 0, INTERRUPTS)
        or nil
end

local function RunNeedsExactCombatTime(run)
    if type(run) ~= "table" then
        return false
    end

    local runtimeSeconds = ((tonumber(run.timeMS) or 0) / 1000)
    local combatTimeSeconds = tonumber(run.combatTimeSeconds) or 0
    if runtimeSeconds <= 0 then
        return combatTimeSeconds <= 0
    end

    -- Treat Details! combat time as valid as long as it is positive and
    -- within a reasonable tolerance of the full run duration.
    return combatTimeSeconds <= 0 or combatTimeSeconds > (runtimeSeconds + 5)
end

function MythicTools:RefreshRunDerivedStats(run)
    if type(run) ~= "table" then
        return
    end

    local durationSeconds = tonumber(run.combatTimeSeconds) or 0
    for _, stat in pairs(run.playerStats or {}) do
        if type(stat) == "table" then
            stat.dps = nil
            stat.hps = nil

            local damageDuration = durationSeconds > 0 and durationSeconds or (tonumber(stat.damageActiveSeconds) or 0)
            local healingDuration = durationSeconds > 0 and durationSeconds or (tonumber(stat.healingActiveSeconds) or 0)

            if stat.damage ~= nil and damageDuration > 0 then
                stat.dps = (tonumber(stat.damage) or 0) / damageDuration
            end
            if stat.healing ~= nil and healingDuration > 0 then
                stat.hps = (tonumber(stat.healing) or 0) / healingDuration
            end
        end
    end
end

function MythicTools:HydrateRunCombatDuration(run)
    if type(run) ~= "table" then
        return false
    end

    local runtimeSeconds = ((tonumber(run.timeMS) or 0) / 1000)
    local currentCombatSeconds = tonumber(run.combatTimeSeconds) or 0

    if currentCombatSeconds > 0 and runtimeSeconds > 0 and currentCombatSeconds <= (runtimeSeconds + 1) then
        currentCombatSeconds = math.min(currentCombatSeconds, runtimeSeconds)
        run.combatTimeSeconds = currentCombatSeconds
        run.outOfCombatSeconds = math.max(0, runtimeSeconds - currentCombatSeconds)
        return true
    end

    local runEndedAt = tonumber(run.endTime) or 0
    if runEndedAt > 0 and run.result ~= "abandoned" and math.abs(time() - runEndedAt) <= 30 then
        local duration = GetCurrentOverallCombatDurationFromDamageMeter()
        if duration and duration > 0 then
            if runtimeSeconds > 0 then
                duration = math.min(duration, runtimeSeconds)
            end

            run.combatTimeSeconds = duration
            run.outOfCombatSeconds = math.max(0, runtimeSeconds - duration)
            return true
        end
    end

    local sessionIDs = run.sessionIDs
    if type(sessionIDs) ~= "table" or #sessionIDs == 0 then
        return false
    end

    if not C_DamageMeter then
        return false
    end

    local totalCombatSeconds = 0
    local foundDuration = false

    for _, sessionID in ipairs(sessionIDs) do
        local duration = SafeGetCombatSessionDuration(C_DamageMeter.GetSessionInfo, sessionID)

        if not duration and C_DamageMeter.GetCombatSessionFromID then
            duration = SafeGetCombatSessionDuration(C_DamageMeter.GetCombatSessionFromID, sessionID, DAMAGE_DONE)
                or SafeGetCombatSessionDuration(C_DamageMeter.GetCombatSessionFromID, sessionID, HEALING_DONE)
                or SafeGetCombatSessionDuration(C_DamageMeter.GetCombatSessionFromID, sessionID, INTERRUPTS)
        end

        if duration and duration > 0 then
            totalCombatSeconds = totalCombatSeconds + duration
            foundDuration = true
        end
    end

    if not foundDuration or totalCombatSeconds <= 0 then
        return false
    end

    if runtimeSeconds > 0 then
        totalCombatSeconds = math.min(totalCombatSeconds, runtimeSeconds)
    end

    run.combatTimeSeconds = totalCombatSeconds
    run.outOfCombatSeconds = math.max(0, runtimeSeconds - totalCombatSeconds)
    return true
end

function MythicTools:AccumulatePartyData(run, sessionIDs)
    if not (C_DamageMeter and C_DamageMeter.GetPartyData) then
        return false, false
    end

    local guidMap = {}
    for fullName, stat in pairs(run.playerStats) do
        if stat.guid then
            guidMap[stat.guid] = fullName
        end
    end

    local foundValues = false
    local blocked = false

    for _, sessionID in ipairs(sessionIDs) do
        local partyData = C_DamageMeter.GetPartyData(sessionID)
        if partyData ~= nil and not self:CanAccessTable(partyData) then
            blocked = true
        elseif self:CanAccessTable(partyData) then
            for _, entry in ipairs(self:GetPartyDataEntries(partyData)) do
                local fullName = self:ResolveCompletedRunSource(run, guidMap, entry)
                if fullName then
                    local stat = self:EnsureCompletedRunPlayer(run, fullName)
                    local damage = GetEntryAmount(entry, PARTY_DATA_DAMAGE_FIELDS)
                    local healing = GetEntryAmount(entry, PARTY_DATA_HEALING_FIELDS)
                    local interrupts = GetEntryAmount(entry, PARTY_DATA_INTERRUPT_FIELDS)

                    if damage ~= nil then
                        stat.damage = (stat.damage or 0) + damage
                        foundValues = true
                    end
                    if healing ~= nil then
                        stat.healing = (stat.healing or 0) + healing
                        foundValues = true
                    end
                    if interrupts ~= nil then
                        stat.interrupts = NormalizeInterruptCount((stat.interrupts or 0) + interrupts)
                        foundValues = true
                    end

                    local entryGUID = entry.sourceGUID or entry.guid or entry.unitGUID or entry.playerGUID or entry.memberGUID
                    if not stat.guid and entryGUID and self:CanAccessValue(entryGUID) then
                        stat.guid = entryGUID
                        guidMap[entryGUID] = fullName
                    end

                    self:ApplySourceMetadataToStat(stat, entry)
                end
            end
        end
    end

    return foundValues, blocked
end

function MythicTools:GetMissingRunStatFields(run)
    local missing = {
        damage = {},
        healing = {},
        interrupts = {},
    }

    for fullName, stat in pairs(run.playerStats or {}) do
        if stat.damage == nil then
            missing.damage[fullName] = true
        end
        if stat.healing == nil then
            missing.healing[fullName] = true
        end
        if stat.interrupts == nil then
            missing.interrupts[fullName] = true
        end
    end

    return missing
end

local function HasMissingEntries(missingField)
    return type(missingField) == "table" and next(missingField) ~= nil
end

local function CountMissingEntries(missingField)
    local count = 0

    for _ in pairs(missingField or {}) do
        count = count + 1
    end

    return count
end

function MythicTools:AccumulatePlayerData(run, sessionIDs, requestedFields)
    if not (C_DamageMeter and C_DamageMeter.GetPlayerData) then
        return false, false
    end

    requestedFields = requestedFields or {damage = {}, healing = {}, interrupts = {}}

    local foundValues = false
    local blocked = false

    for _, sessionID in ipairs(sessionIDs) do
        for fullName, stat in pairs(run.playerStats) do
            local needsDamage = requestedFields.damage and requestedFields.damage[fullName]
            local needsHealing = requestedFields.healing and requestedFields.healing[fullName]
            local needsInterrupts = requestedFields.interrupts and requestedFields.interrupts[fullName]

            if stat.guid and (needsDamage or needsHealing or needsInterrupts) then
                local playerData = C_DamageMeter.GetPlayerData(sessionID, stat.guid)
                if playerData ~= nil and not self:CanAccessTable(playerData) then
                    blocked = true
                elseif self:CanAccessTable(playerData) then
                    local damage = needsDamage and GetEntryAmount(playerData, PARTY_DATA_DAMAGE_FIELDS) or nil
                    local healing = needsHealing and GetEntryAmount(playerData, PARTY_DATA_HEALING_FIELDS) or nil
                    local interrupts = needsInterrupts and GetEntryAmount(playerData, PARTY_DATA_INTERRUPT_FIELDS) or nil

                    if damage ~= nil then
                        stat.damage = (stat.damage or 0) + damage
                        foundValues = true
                    end
                    if healing ~= nil then
                        stat.healing = (stat.healing or 0) + healing
                        foundValues = true
                    end
                    if interrupts ~= nil then
                        stat.interrupts = NormalizeInterruptCount((stat.interrupts or 0) + interrupts)
                        foundValues = true
                    end

                    self:ApplySourceMetadataToStat(stat, playerData)
                end
            end
        end
    end

    return foundValues, blocked
end

function MythicTools:AccumulateCombatType(run, sessionIDs, damageType, fieldName, requestedPlayers)
    if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromID) then
        return false
    end

    local guidMap = {}
    for fullName, stat in pairs(run.playerStats) do
        if stat.guid then
            guidMap[stat.guid] = fullName
        end
    end

    local blocked = false
    for _, sessionID in ipairs(sessionIDs) do
        local session = C_DamageMeter.GetCombatSessionFromID(sessionID, damageType)
        if session ~= nil and not self:CanAccessTable(session) then
            blocked = true
        elseif self:CanAccessTable(session) and type(session.combatSources) == "table" then
            for _, source in ipairs(session.combatSources) do
                local fullName = self:ResolveCompletedRunSource(run, guidMap, source)
                if fullName and (not requestedPlayers or requestedPlayers[fullName]) then
                    local stat = self:EnsureCompletedRunPlayer(run, fullName)
                    local amount = GetCombatSourceTotalAmount(source)
                    if fieldName == "interrupts" then
                        stat[fieldName] = NormalizeInterruptCount((stat[fieldName] or 0) + amount)
                    else
                        stat[fieldName] = (stat[fieldName] or 0) + amount
                    end

                    if not stat.guid and source.sourceGUID and self:CanAccessValue(source.sourceGUID) then
                        stat.guid = source.sourceGUID
                        guidMap[source.sourceGUID] = fullName
                    end

                    self:ApplySourceMetadataToStat(stat, source)
                end
            end
        end
    end

    return blocked
end

function MythicTools:GetRosterNamesForTarget(target)
    if type(target) ~= "table" then
        return {}
    end

    if type(target.roster) == "table" and #target.roster > 0 then
        return target.roster
    end

    if type(target.participantOrder) == "table" and #target.participantOrder > 0 then
        return target.participantOrder
    end

    local roster = {}
    for fullName in pairs(target.playerStats or {}) do
        roster[#roster + 1] = fullName
    end
    table.sort(roster)
    return roster
end

function MythicTools:ResolvePlayerNameForTarget(target, rawName)
    rawName = self:TrimText(rawName)
    if rawName == "" or type(target) ~= "table" then
        return nil
    end

    if target.playerStats and target.playerStats[rawName] then
        return rawName
    end

    local normalized = self:NormalizePlayerName(rawName)
    if normalized and target.playerStats and target.playerStats[normalized] then
        return normalized
    end

    local shortName = self:GetShortName(normalized or rawName)
    for _, rosterEntry in ipairs(self:GetCurrentGroupRoster()) do
        if self:GetShortName(rosterEntry.name) == shortName and target.playerStats and target.playerStats[rosterEntry.name] then
            return rosterEntry.name
        end
    end

    local match = nil
    for _, fullName in ipairs(self:GetRosterNamesForTarget(target)) do
        if self:GetShortName(fullName) == shortName then
            match = fullName
            break
        end
    end

    return match
end

function MythicTools:AddLootToStat(stat, itemLink)
    if type(stat) ~= "table" or not itemLink or itemLink == "" then
        return false
    end

    itemLink = NormalizeStoredItemLink(itemLink)
    if not itemLink or itemLink == "" then
        return false
    end

    stat.loot = type(stat.loot) == "table" and stat.loot or {}
    for _, existingLink in ipairs(stat.loot) do
        if NormalizeStoredItemLink(existingLink) == itemLink then
            return false
        end
    end

    stat.loot[#stat.loot + 1] = itemLink
    return true
end

function MythicTools:RecordLootForTarget(target, rawName, itemLink)
    local fullName = self:ResolvePlayerNameForTarget(target, rawName)
    if not fullName then
        return false
    end

    local stat
    if target.participantOrder then
        stat = self:EnsureActiveRunPlayerStat(target, fullName)
    else
        stat = self:EnsureCompletedRunPlayer(target, fullName)
    end

    return self:AddLootToStat(stat, itemLink)
end

function MythicTools:RecordRunLoot(runId, rawName, itemLink)
    if not runId or not rawName or not itemLink then
        return false
    end

    local changed = false
    local savedRun = self:GetRunById(runId)
    if savedRun then
        changed = self:RecordLootForTarget(savedRun, rawName, itemLink) or changed
    elseif self.runtime and self.runtime.activeRun and self.runtime.activeRun.runId == runId then
        changed = self:RecordLootForTarget(self.runtime.activeRun, rawName, itemLink) or changed
        if changed then
            self:UpdateActiveRunSnapshot(self.runtime.activeRun)
        end
    end

    if changed then
        self:RefreshAllViews()
    end

    return changed
end

function MythicTools:StartLootTracking(runId)
    if not (self.runtime and runId) then
        return
    end

    local tracking = self.runtime.lootTracking
    if type(tracking) == "table" and tracking.runId ~= runId then
        self:PushRuntimeDebug(("replace loot tracking %s -> %s"):format(tostring(tracking.runId), tostring(runId)))
    end
    if type(tracking) == "table" and tracking.runId == runId then
        tracking.lootClosed = false
        tracking.popupFallbackTriggered = false
        tracking.lootFinalizeDeadline = time() + LOOT_TRACKING_TIMEOUT
        local activeRun = self.runtime.activeRun
        if type(activeRun) == "table" and activeRun.runId == runId then
            activeRun.lootFinalizeDeadline = tracking.lootFinalizeDeadline
        end
        self:ScheduleLootTrackingTimeout(tracking)
        self:ScheduleLootPopupFallback(tracking)
        return
    end

    tracking = {
        runId = runId,
        startedAt = GetTime and GetTime() or 0,
        lootClosed = false,
        lootFinalizeDeadline = time() + LOOT_TRACKING_TIMEOUT,
        popupFallbackTriggered = false,
    }
    self.runtime.lootTracking = tracking
    local activeRun = self.runtime.activeRun
    if type(activeRun) == "table" and activeRun.runId == runId then
        activeRun.lootFinalizeDeadline = tracking.lootFinalizeDeadline
    end
    self.EventFrame:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
    self.EventFrame:RegisterEvent("CHAT_MSG_LOOT")
    self.EventFrame:RegisterEvent("LOOT_CLOSED")
    self:PushRuntimeDebug(("start loot tracking run %s"):format(tostring(runId)))
    self:ScheduleLootTrackingTimeout(tracking)
    self:ScheduleLootPopupFallback(tracking)
end

function MythicTools:StopLootTracking()
    if not self.runtime then
        return
    end

    local tracking = self.runtime.lootTracking
    if type(tracking) == "table" then
        self:PushRuntimeDebug(("stop loot tracking run %s"):format(tostring(tracking.runId)))
    end
    local activeRun = self.runtime.activeRun
    if type(activeRun) == "table" and type(tracking) == "table" and activeRun.runId == tracking.runId then
        activeRun.lootFinalizeDeadline = nil
    end

    if self.ResolvePendingCompletionPopup and self.runtime.pendingCompletionPopup then
        self:PushRuntimeDebug(("resolve pending popup on loot stop run %s"):format(tostring(tracking and tracking.runId or "?")))
        self:ResolvePendingCompletionPopup("LOOT_CLOSED")
    end

    self.runtime.lootTracking = nil
    self.EventFrame:UnregisterEvent("ENCOUNTER_LOOT_RECEIVED")
    self.EventFrame:UnregisterEvent("CHAT_MSG_LOOT")
    self.EventFrame:UnregisterEvent("LOOT_CLOSED")
    self:RefreshAllViews()
end

function MythicTools:HandleEncounterLootReceived(...)
    local tracking = self.runtime and self.runtime.lootTracking
    if not tracking then
        return
    end

    local itemLink = select(3, ...)
    local unitName = select(5, ...)
    if not itemLink or not unitName then
        self:PushRuntimeDebug(("encounter loot ignored run %s item=%s unit=%s"):format(
            tostring(tracking.runId),
            tostring(itemLink),
            tostring(unitName)
        ))
        return
    end

    self:PushRuntimeDebug(("encounter loot run %s unit=%s item=%s"):format(
        tostring(tracking.runId),
        tostring(unitName),
        tostring(itemLink)
    ))
    local recorded = self:RecordRunLoot(tracking.runId, unitName, itemLink)
    if not recorded then
        self:PushRuntimeDebug(("encounter loot not matched run %s unit=%s"):format(
            tostring(tracking.runId),
            tostring(unitName)
        ))
    end
end

local function ExtractLootLinkFromChatMessage(message)
    if type(message) ~= "string" or message == "" then
        return nil
    end

    return message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
        or message:match("(|Hitem:.-|h%[.-%]|h)")
end

function MythicTools:GetLootTargetByRunId(runId)
    local target = self:GetRunById(runId)
    if not target and self.runtime and self.runtime.activeRun and self.runtime.activeRun.runId == runId then
        target = self.runtime.activeRun
    end

    if type(target) ~= "table" then
        return nil
    end

    return target
end

function MythicTools:ResolveLootRecipientFromGuid(runId, guid)
    if not self:CanAccessValue(guid) or not self:IsPlayerGUID(guid) then
        return nil
    end

    local target = self:GetLootTargetByRunId(runId)
    if type(target) ~= "table" then
        return nil
    end

    for _, fullName in ipairs(self:GetRosterNamesForTarget(target)) do
        local stat = target.playerStats and target.playerStats[fullName] or nil
        if type(stat) == "table" and stat.guid == guid then
            return fullName
        end
    end

    for _, rosterEntry in ipairs(self:GetCurrentGroupRoster()) do
        if rosterEntry.guid == guid then
            return self:ResolvePlayerNameForTarget(target, rosterEntry.name)
                or self:NormalizePlayerName(rosterEntry.name)
                or rosterEntry.name
        end
    end

    local playerGUID = UnitGUID and UnitGUID("player") or nil
    if playerGUID and playerGUID == guid then
        return self.playerName or self:GetUnitFullName("player")
    end

    return nil
end

function MythicTools:ResolveLootRecipientFromChat(runId, playerName, guid)
    local recipient = self:ResolveLootRecipientFromGuid(runId, guid)
    if recipient then
        return recipient
    end

    local target = self:GetLootTargetByRunId(runId)
    if type(target) ~= "table" then
        return nil
    end

    if self:CanAccessValue(playerName) and type(playerName) == "string" and playerName ~= "" then
        recipient = self:ResolvePlayerNameForTarget(target, playerName)
        if recipient then
            return recipient
        end
    end

    local localPlayer = self.playerName or self:GetUnitFullName("player")
    if type(localPlayer) == "string" and localPlayer ~= "" then
        return localPlayer
    end

    return nil
end

function MythicTools:HandleChatMsgLoot(message, playerName, _, _, _, _, _, _, _, _, _, guid)
    local tracking = self.runtime and self.runtime.lootTracking
    if not tracking then
        return
    end

    if not self:CanAccessValue(message) then
        self:PushRuntimeDebug(("chat loot inaccessible run %s"):format(tostring(tracking.runId)))
        return
    end

    local itemLink = ExtractLootLinkFromChatMessage(message)
    if not itemLink then
        return
    end

    local recipient = self:ResolveLootRecipientFromChat(tracking.runId, playerName, guid)
    if not recipient then
        self:PushRuntimeDebug(("chat loot recipient unresolved run %s guid=%s hasPlayerName=%s"):format(
            tostring(tracking.runId),
            tostring(guid),
            tostring(type(playerName) == "string" and playerName ~= "")
        ))
        return
    end

    self:PushRuntimeDebug(("chat loot run %s recipient=%s item=%s"):format(
        tostring(tracking.runId),
        tostring(recipient),
        tostring(itemLink)
    ))
    local recorded = self:RecordRunLoot(tracking.runId, recipient, itemLink)
    if not recorded then
        self:PushRuntimeDebug(("chat loot not matched run %s recipient=%s"):format(
            tostring(tracking.runId),
            tostring(recipient)
        ))
    end
end

function MythicTools:HandleLootClosed()
    local tracking = self.runtime and self.runtime.lootTracking
    if not tracking then
        return
    end

    tracking.lootClosed = true
    tracking.lootFinalizeDeadline = time()
    self:RefreshAllViews()
    if self.ResolvePendingCompletionPopup then
        self:ResolvePendingCompletionPopup("LOOT_CLOSED")
    end

    self:Schedule(1.0, function()
        if self.runtime and self.runtime.lootTracking == tracking then
            self:StopLootTracking()
        end
    end)
end


function MythicTools:BuildCompletedRun(activeRun, completionInfo)
    local mapChallengeModeID = completionInfo.mapChallengeModeID or activeRun.mapChallengeModeID or 0
    local mapInfo = GetMapInfo(mapChallengeModeID)
    local completedAt = tonumber(activeRun.completedAt) or time()
    local elapsedTimeMS = math.max(0, (completedAt - (tonumber(activeRun.startedAt) or completedAt)) * 1000)

    self:UpdateActiveRunFromCompletionMembers(activeRun, completionInfo.members)

    local run = {
        runId = activeRun.runId,
        startTime = activeRun.startedAt,
        endTime = completedAt,
        mapChallengeModeID = mapChallengeModeID,
        mapID = mapInfo and mapInfo.mapID or activeRun.mapID or mapChallengeModeID,
        season = "season1",
        dungeonName = mapInfo and mapInfo.dungeonName or activeRun.dungeonName or "Unknown",
        textureFileID = mapInfo and mapInfo.textureFileID or nil,
        backgroundTextureFileID = mapInfo and mapInfo.backgroundTextureFileID or nil,
        level = tonumber(completionInfo.level) or tonumber(activeRun.keyLevel) or 0,
        timeMS = tonumber(completionInfo.time) or elapsedTimeMS,
        onTime = completionInfo.onTime and true or false,
        result = completionInfo.onTime and "timed" or "overtime",
        keystoneUpgradeLevels = tonumber(completionInfo.keystoneUpgradeLevels) or 0,
        practiceRun = completionInfo.practiceRun and true or false,
        isEligibleForScore = completionInfo.isEligibleForScore == nil and true or (completionInfo.isEligibleForScore and true or false),
        oldOverallDungeonScore = completionInfo.oldOverallDungeonScore,
        newOverallDungeonScore = completionInfo.newOverallDungeonScore,
        timeLimitSeconds = mapInfo and mapInfo.timeLimit or activeRun.timeLimitSeconds or 0,
        totalDeaths = tonumber(activeRun.totalDeaths) or 0,
        deathPenaltySeconds = tonumber(activeRun.deathPenaltySeconds) or 0,
        affixIDs = self:CopyArray(activeRun.affixIDs),
        roster = self:CopyArray(activeRun.participantOrder),
        playerStats = {},
        sessionIDs = self:GetTrackedSessionIDsForRun(activeRun),
        combatTimeSeconds = nil,
        outOfCombatSeconds = nil,
        completionSource = activeRun.pendingCompletionSource,
        statsSource = nil,
        statsUnavailable = false,
        statsNote = nil,
    }

    for _, fullName in ipairs(run.roster) do
        local sourceStat = activeRun.playerStats[fullName] or {}
        run.playerStats[fullName] = {
            name = fullName,
            shortName = self:GetShortName(fullName),
            guid = sourceStat.guid,
            classFilename = sourceStat.classFilename,
            role = sourceStat.role,
            specID = sourceStat.specID,
            specName = sourceStat.specName,
            specIconID = sourceStat.specIconID,
            score = sourceStat.score,
            previousScore = sourceStat.previousScore,
            itemLevel = sourceStat.itemLevel,
            damageActiveSeconds = sourceStat.damageActiveSeconds,
            healingActiveSeconds = sourceStat.healingActiveSeconds,
            dps = sourceStat.dps,
            hps = sourceStat.hps,
            damage = nil,
            healing = nil,
            interrupts = nil,
            deaths = tonumber(sourceStat.deaths) or 0,
            loot = type(sourceStat.loot) == "table" and self:CopyArray(sourceStat.loot) or {},
        }
    end

    return run
end

function MythicTools:BuildAbandonedRun(activeRun)
    if type(activeRun) ~= "table" then
        return nil
    end

    local mapChallengeModeID = activeRun.mapChallengeModeID or 0
    local mapInfo = GetMapInfo(mapChallengeModeID)
    self:UpdateActiveRunParticipants()

    local startedAt = tonumber(activeRun.startedAt) or time()
    local run = {
        runId = activeRun.runId,
        startTime = startedAt,
        endTime = time(),
        mapChallengeModeID = mapChallengeModeID,
        mapID = mapInfo and mapInfo.mapID or activeRun.mapID or mapChallengeModeID,
        season = "season1",
        dungeonName = mapInfo and mapInfo.dungeonName or activeRun.dungeonName or "Unknown",
        textureFileID = mapInfo and mapInfo.textureFileID or nil,
        backgroundTextureFileID = mapInfo and mapInfo.backgroundTextureFileID or nil,
        level = tonumber(activeRun.keyLevel) or 0,
        timeMS = math.max(0, (time() - startedAt) * 1000),
        onTime = false,
        result = "abandoned",
        keystoneUpgradeLevels = 0,
        practiceRun = false,
        isEligibleForScore = false,
        oldOverallDungeonScore = nil,
        newOverallDungeonScore = nil,
        timeLimitSeconds = mapInfo and mapInfo.timeLimit or activeRun.timeLimitSeconds or 0,
        totalDeaths = tonumber(activeRun.totalDeaths) or 0,
        deathPenaltySeconds = tonumber(activeRun.deathPenaltySeconds) or 0,
        affixIDs = self:CopyArray(activeRun.affixIDs),
        roster = self:CopyArray(activeRun.participantOrder),
        playerStats = {},
        sessionIDs = self:GetTrackedSessionIDsForRun(activeRun),
        combatTimeSeconds = nil,
        outOfCombatSeconds = nil,
        completionSource = nil,
        statsSource = nil,
        statsUnavailable = false,
        statsNote = "Run was abandoned before completion.",
    }

    for _, fullName in ipairs(run.roster) do
        local sourceStat = activeRun.playerStats[fullName] or {}
        run.playerStats[fullName] = {
            name = fullName,
            shortName = self:GetShortName(fullName),
            guid = sourceStat.guid,
            classFilename = sourceStat.classFilename,
            role = sourceStat.role,
            specID = sourceStat.specID,
            specName = sourceStat.specName,
            specIconID = sourceStat.specIconID,
            score = sourceStat.score,
            previousScore = sourceStat.previousScore,
            itemLevel = sourceStat.itemLevel,
            damageActiveSeconds = sourceStat.damageActiveSeconds,
            healingActiveSeconds = sourceStat.healingActiveSeconds,
            dps = sourceStat.dps,
            hps = sourceStat.hps,
            damage = nil,
            healing = nil,
            interrupts = nil,
            deaths = tonumber(sourceStat.deaths) or 0,
            loot = type(sourceStat.loot) == "table" and self:CopyArray(sourceStat.loot) or {},
        }
    end

    self:FinalizeRunStats(activeRun, run, false)
    return run
end

function MythicTools:AddAbandonedRun(activeRun)
    local run = self:BuildAbandonedRun(activeRun)
    if not run then
        return
    end

    if self.RegisterOwnedCharacter then
        self:RegisterOwnedCharacter(self.playerName)
    end
    self:AddCompletedRun(run)
    self.db.ui.selectedRunId = run.runId
    self:RefreshAllViews()
end

local function AppendRunNote(run, noteText)
    if type(run) ~= "table" or type(noteText) ~= "string" or noteText == "" then
        return
    end

    if type(run.statsNote) == "string" and run.statsNote ~= "" then
        if not run.statsNote:find(noteText, 1, true) then
            run.statsNote = run.statsNote .. " " .. noteText
        end
    else
        run.statsNote = noteText
    end
end

local function ClearTransientRunNotes(run)
    if type(run) ~= "table" or type(run.statsNote) ~= "string" or run.statsNote == "" then
        return
    end

    local note = run.statsNote
    note = note:gsub("Waiting for damage meter sessions%.?", "")
    note = note:gsub("Waiting for damage meter totals%.?", "")
    note = note:gsub("Using Details! totals with Blizzard damage meter fallback for timing or missing players%.?", "")
    note = note:gsub("Using Details! totals%. Combat duration could not be verified, so DPS/HPS use player activity time when available%.?", "")
    note = note:gsub("Using Details! totals%. DPS/HPS use player activity time when full combat duration is unavailable%.?", "")
    note = note:gsub("Using Details! totals for this run%.?", "")
    note = note:gsub("%s%s+", " ")
    note = note:gsub("^%s+", ""):gsub("%s+$", "")
    run.statsNote = note ~= "" and note or nil
end

function MythicTools:QueueSavedRunStatsRefresh(runId, activeRunContext, attempt)
    if not (runId and type(activeRunContext) == "table") then
        return
    end

    self:Schedule(COMPLETION_RETRY_DELAY, function()
        if MythicTools and MythicTools.FinalizeSavedRunStats then
            MythicTools:FinalizeSavedRunStats(runId, activeRunContext, attempt or 1)
        end
    end)
end

function MythicTools:FinalizeSavedRunStats(runId, activeRunContext, attempt)
    runId = tonumber(runId)
    attempt = tonumber(attempt) or 1
    if not (runId and type(activeRunContext) == "table") then
        return false
    end

    local run = self:GetRunById(runId)
    if type(run) ~= "table" then
        return false
    end

    if self.RefreshSavedRunStatsContext then
        self:RefreshSavedRunStatsContext(activeRunContext)
        run.sessionIDs = self:GetSortedSessionIDs(activeRunContext.sessionIDs)
    end

    ClearTransientRunNotes(run)
    local ok, needsRetry = pcall(self.FinalizeRunStats, self, activeRunContext, run, attempt < MAX_COMPLETION_ATTEMPTS)
    if not ok then
        run.statsUnavailable = true
        AppendRunNote(run, "An error happened while collecting post-run stats.")
        if self.StoreDebugReport then
            self:StoreDebugReport("stats_refresh_error", {
                trigger = "FinalizeSavedRunStats",
                runId = runId,
                state = activeRunContext.state,
                mapChallengeModeID = activeRunContext.mapChallengeModeID,
                level = activeRunContext.keyLevel,
                error = tostring(needsRetry),
            })
        end
        self:RefreshAllViews()
        return false
    end

    if needsRetry and attempt < MAX_COMPLETION_ATTEMPTS then
        self:PushRuntimeDebug(("stats refresh retry run %s attempt=%s sessionCount=%s"):format(
            tostring(runId),
            tostring(attempt),
            tostring(#(run.sessionIDs or {}))
        ))
        self:QueueSavedRunStatsRefresh(runId, activeRunContext, attempt + 1)
        return false
    end

    if needsRetry then
        run.statsUnavailable = true
        AppendRunNote(run, "Damage meter data was not available in time for this key.")
        self:PushRuntimeDebug(("stats refresh exhausted run %s sessionCount=%s"):format(
            tostring(runId),
            tostring(#(run.sessionIDs or {}))
        ))
    else
        self:PushRuntimeDebug(("stats refresh completed run %s sessionCount=%s source=%s"):format(
            tostring(runId),
            tostring(#(run.sessionIDs or {})),
            tostring(run.statsSource or "unknown")
        ))
    end

    self:RefreshAllViews()
    if self.completionPopup and self.completionPopup:IsShown() and self.completionPopup.runId == runId and self.RefreshCompletionPopup then
        self:RefreshCompletionPopup()
    end

    return true
end

function MythicTools:UpdateSavedRunCompletionInfo(runId, completionInfo, source)
    runId = tonumber(runId)
    if not (runId and IsValidCompletionInfo(completionInfo)) then
        return false
    end

    local run = self:GetRunById(runId)
    if type(run) ~= "table" then
        return false
    end

    local mapChallengeModeID = tonumber(completionInfo.mapChallengeModeID) or tonumber(run.mapChallengeModeID) or 0
    local mapInfo = GetMapInfo(mapChallengeModeID)

    run.mapChallengeModeID = mapChallengeModeID
    run.mapID = mapInfo and mapInfo.mapID or run.mapID or mapChallengeModeID
    run.dungeonName = mapInfo and mapInfo.dungeonName or run.dungeonName or "Unknown"
    run.textureFileID = mapInfo and mapInfo.textureFileID or run.textureFileID
    run.backgroundTextureFileID = mapInfo and mapInfo.backgroundTextureFileID or run.backgroundTextureFileID
    run.level = tonumber(completionInfo.level) or tonumber(run.level) or 0
    run.timeMS = tonumber(completionInfo.time) or tonumber(run.timeMS) or 0
    run.onTime = completionInfo.onTime and true or false
    run.result = completionInfo.onTime and "timed" or "overtime"
    run.keystoneUpgradeLevels = tonumber(completionInfo.keystoneUpgradeLevels) or tonumber(run.keystoneUpgradeLevels) or 0
    run.practiceRun = completionInfo.practiceRun and true or false
    if completionInfo.isEligibleForScore ~= nil then
        run.isEligibleForScore = completionInfo.isEligibleForScore and true or false
    end
    if completionInfo.oldOverallDungeonScore ~= nil then
        run.oldOverallDungeonScore = completionInfo.oldOverallDungeonScore
    end
    if completionInfo.newOverallDungeonScore ~= nil then
        run.newOverallDungeonScore = completionInfo.newOverallDungeonScore
    end
    if mapInfo and mapInfo.timeLimit then
        run.timeLimitSeconds = mapInfo.timeLimit
    end
    run.completionSource = source or run.completionSource

    if self.db then
        self:RebuildPlayerIndex()
    end
    self:RefreshAllViews()

    if self.StoreDebugReport then
        self:StoreDebugReport("updated_completed_run", {
            trigger = source,
            result = run.result,
            runId = run.runId,
            mapChallengeModeID = run.mapChallengeModeID,
            level = run.level,
        })
    end

    return true
end

function MythicTools:TryUpdateLastCompletedRunCompletionInfo(completionInfo, source)
    if not (self.runtime and IsValidCompletionInfo(completionInfo)) then
        return false
    end

    local runId = tonumber(self.runtime.lastCompletedRunId)
    if not runId then
        return false
    end

    local run = self:GetRunById(runId)
    if type(run) ~= "table" then
        return false
    end

    local expectedMapID = tonumber(self.runtime.lastCompletedMapChallengeModeID) or tonumber(run.mapChallengeModeID) or 0
    local expectedLevel = tonumber(self.runtime.lastCompletedLevel) or tonumber(run.level) or 0
    local completionMapID = tonumber(completionInfo.mapChallengeModeID) or 0
    local completionLevel = tonumber(completionInfo.level) or 0

    if expectedMapID > 0 and completionMapID > 0 and expectedMapID ~= completionMapID then
        return false
    end

    if expectedLevel > 0 and completionLevel > 0 and expectedLevel ~= completionLevel then
        return false
    end

    return self:UpdateSavedRunCompletionInfo(runId, completionInfo, source)
end

function MythicTools:PersistCompletedRun(activeRun, completionInfo, trigger)
    if type(activeRun) ~= "table" or not IsValidCompletionInfo(completionInfo) then
        return nil
    end

    local run = self:BuildCompletedRun(activeRun, completionInfo)
    if type(run) ~= "table" then
        return nil
    end

    if activeRun.pendingCompletionSource == "runtime_recovery" then
        AppendRunNote(run, "Completion data was recovered from runtime state and may be approximate.")
    end

    run.statsUnavailable = true
    AppendRunNote(run, "Waiting for damage meter totals.")

    if self.RegisterOwnedCharacter then
        self:RegisterOwnedCharacter(self.playerName)
    end

    self:PushRuntimeDebug(("persist completed run %s source=%s trigger=%s"):format(
        tostring(run.runId),
        tostring(activeRun.pendingCompletionSource or "unknown"),
        tostring(trigger or "unknown")
    ))

    self:AddCompletedRun(run)
    self.db.ui.selectedRunId = run.runId
    self:PushRuntimeDebug(("saved run %s totalRuns=%s selectedRun=%s"):format(
        tostring(run.runId),
        tostring(self.db and self.db.runs and #self.db.runs or 0),
        tostring(self.db and self.db.ui and self.db.ui.selectedRunId or run.runId)
    ))

    if self.StartLootTracking then
        self:StartLootTracking(run.runId)
    end

    if self.runtime then
        self.runtime.lastCompletionRewards = nil
        self.runtime.lastCompletedRunId = run.runId
        self.runtime.lastCompletedAt = run.endTime
        self.runtime.lastCompletedMapChallengeModeID = run.mapChallengeModeID
        self.runtime.lastCompletedLevel = run.level
    end

    self:ForgetRecoveryState(run.runId)
    self:RefreshAllViews()

    if self.StoreDebugReport then
        self:StoreDebugReport("completed_run", {
            trigger = trigger,
            result = run.result,
            runId = run.runId,
            state = activeRun.state,
            mapChallengeModeID = run.mapChallengeModeID,
            level = run.level,
            completionSource = run.completionSource,
            statsUnavailable = run.statsUnavailable and true or false,
        })
    end

    local statsContext = CreateActiveRunSnapshot(self, activeRun)
    if type(statsContext) == "table" then
        local refreshOk = false
        local ok = pcall(function()
            refreshOk = self:FinalizeSavedRunStats(run.runId, statsContext, 1)
        end)
        if not ok and self.StoreDebugReport then
            self:StoreDebugReport("stats_refresh_crash", {
                trigger = trigger,
                runId = run.runId,
                state = activeRun.state,
                mapChallengeModeID = run.mapChallengeModeID,
                level = run.level,
            })
        end
    end

    if self.QueueCompletionPopup then
        self:QueueCompletionPopup(run.runId, "COMPLETED")
    elseif self.ShowCompletionPopup then
        self:ShowCompletionPopup(run.runId)
    end

    return run
end

function MythicTools:ProcessPendingCompletionSnapshots(trigger, forceRecovery)
    if not self.runtime then
        return false
    end

    local pending = self.runtime.pendingCompletionSnapshots
    if type(pending) ~= "table" or #pending == 0 then
        return false
    end

    for index = #pending, 1, -1 do
        local snapshot = pending[index]
        if type(snapshot) == "table" then
            local completionInfo = self:GetResolvedChallengeCompletionInfo(snapshot, true)
            if not IsValidCompletionInfo(completionInfo) and forceRecovery then
                completionInfo = BuildRecoveredCompletionInfo(snapshot)
                if IsValidCompletionInfo(completionInfo) then
                    completionInfo = SetCachedCompletionInfo(snapshot, completionInfo, snapshot.pendingCompletionSource or "runtime_recovery")
                end
            end

            if IsValidCompletionInfo(completionInfo) then
                snapshot.pendingCompletionInfo = CopyCompletionInfo(completionInfo)
                snapshot.pendingCompletionSource = snapshot.pendingCompletionSource or trigger or "pending"
                if self:PersistCompletedRun(snapshot, completionInfo, trigger or "pending") then
                    return true
                end
            end
        end
    end

    return false
end

function MythicTools:FinalizeRunStats(activeRun, run, allowRetry)
    if type(activeRun) ~= "table" or type(run) ~= "table" then
        return false
    end

    local foundDetailsStats = self:AccumulateDetailsData(run)
    local detailsMatchedRun = (tonumber(run.combatTimeSeconds) or 0) > 0 and not RunNeedsExactCombatTime(run)
    local hadDetailsStats = foundDetailsStats and HasAnyRunStats(run)

    if detailsMatchedRun then
        run.statsSource = "details"
        for _, fullName in ipairs(run.roster or {}) do
            local stat = self:EnsureCompletedRunPlayer(run, fullName)
            if stat.damage == nil then
                stat.damage = 0
            end
            if stat.healing == nil then
                stat.healing = 0
            end
            if stat.interrupts == nil then
                stat.interrupts = 0
            end
        end

        run.statsUnavailable = false
        activeRun.damageMeterResetVerified = false
        if activeRun.damageMeterResetSuspected then
            self:ClearDamageMeterResetSuspicion(activeRun)
        end
        self:RefreshRunDerivedStats(run)
        return false
    end

    if hadDetailsStats then
        run.statsSource = "details_partial"
        run.statsUnavailable = false
    end

    local preHydrateCombatTime = tonumber(run.combatTimeSeconds) or 0
    self:HydrateRunCombatDuration(run)
    local usedDamageMeterDuration = preHydrateCombatTime <= 0 and (tonumber(run.combatTimeSeconds) or 0) > 0

    local missingFields = self:GetMissingRunStatFields(run)
    local needsBlizzardFallback = HasMissingEntries(missingFields.damage) or HasMissingEntries(missingFields.healing) or HasMissingEntries(missingFields.interrupts)
    local damageMeterAvailable = C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable and C_DamageMeter.IsDamageMeterAvailable()
    local missingBeforeFallback = CountMissingEntries(missingFields.damage) + CountMissingEntries(missingFields.healing) + CountMissingEntries(missingFields.interrupts)

    if not damageMeterAvailable then
        if hadDetailsStats then
            run.statsUnavailable = false
            if (tonumber(run.combatTimeSeconds) or 0) <= 0 then
                AppendRunNote(run, "Using Details! totals. Combat duration could not be verified, so DPS/HPS use player activity time when available.")
            else
                AppendRunNote(run, "Using Details! totals for this run.")
            end
        else
            run.statsUnavailable = true
            AppendRunNote(run, "No Details! or C_DamageMeter totals were available for this run.")
        end
        self:RefreshRunDerivedStats(run)
        return false
    end

    if needsBlizzardFallback and #run.sessionIDs == 0 and allowRetry and not activeRun.damageMeterResetSuspected then
        run.statsNote = "Waiting for damage meter sessions."
        return true
    end

    if needsBlizzardFallback then
        local _, partyDataBlocked = self:AccumulatePartyData(run, run.sessionIDs)
        if partyDataBlocked and allowRetry then
            return true
        end
    end

    missingFields = self:GetMissingRunStatFields(run)
    if HasMissingEntries(missingFields.damage) or HasMissingEntries(missingFields.healing) or HasMissingEntries(missingFields.interrupts) then
        local _, playerDataBlocked = self:AccumulatePlayerData(run, run.sessionIDs, missingFields)
        if playerDataBlocked and allowRetry then
            return true
        end
    end

    missingFields = self:GetMissingRunStatFields(run)
    if HasMissingEntries(missingFields.damage) or HasMissingEntries(missingFields.healing) or HasMissingEntries(missingFields.interrupts) then
        local damageBlocked = HasMissingEntries(missingFields.damage) and self:AccumulateCombatType(run, run.sessionIDs, DAMAGE_DONE, "damage", missingFields.damage) or false
        local healingBlocked = HasMissingEntries(missingFields.healing) and self:AccumulateCombatType(run, run.sessionIDs, HEALING_DONE, "healing", missingFields.healing) or false
        local interruptsBlocked = HasMissingEntries(missingFields.interrupts) and self:AccumulateCombatType(run, run.sessionIDs, INTERRUPTS, "interrupts", missingFields.interrupts) or false

        if (damageBlocked or healingBlocked or interruptsBlocked) and allowRetry then
            return true
        end
    end

    local hasStats = HasAnyRunStats(run)
    if hasStats then
        local missingAfter = self:GetMissingRunStatFields(run)
        local missingAfterFallback = CountMissingEntries(missingAfter.damage) + CountMissingEntries(missingAfter.healing) + CountMissingEntries(missingAfter.interrupts)
        local usedDamageMeterFields = missingAfterFallback < missingBeforeFallback

        if hadDetailsStats then
            if detailsMatchedRun then
                run.statsSource = "details"
            elseif usedDamageMeterFields or usedDamageMeterDuration then
                run.statsSource = "details_hybrid"
                AppendRunNote(run, "Using Details! totals with Blizzard damage meter fallback for timing or missing players.")
            else
                run.statsSource = "details_partial"
                if (tonumber(run.combatTimeSeconds) or 0) <= 0 then
                    AppendRunNote(run, "Using Details! totals. DPS/HPS use player activity time when full combat duration is unavailable.")
                else
                    AppendRunNote(run, "Using Details! totals for this run.")
                end
            end
        else
            run.statsSource = "damage_meter"
        end

        run.statsUnavailable = false
        activeRun.damageMeterResetVerified = false
        if activeRun.damageMeterResetSuspected then
            self:ClearDamageMeterResetSuspicion(activeRun)
        end
        self:RefreshRunDerivedStats(run)
        return false
    end

    if allowRetry and not activeRun.damageMeterResetSuspected then
        run.statsNote = "Waiting for damage meter totals."
        return true
    end

    run.statsUnavailable = true
    if activeRun.damageMeterResetSuspected and not activeRun.damageMeterResetRecovered then
        activeRun.damageMeterResetVerified = true
    end

    if activeRun.damageMeterResetVerified then
        AppendRunNote(run, "The damage meter was reset during the run, so totals are incomplete.")
    else
        AppendRunNote(run, "No damage, healing, or interrupt session data was available for this run.")
    end

    self:RefreshRunDerivedStats(run)
    return false
end

function MythicTools:FinalizeAbandonedActiveRun(activeRun)
    if type(activeRun) ~= "table" then
        return
    end

    self:SetActiveRunState(activeRun, "finalized_abandoned")
    self:PushRuntimeDebug(("finalize abandoned run %s"):format(tostring(activeRun.runId)))

    if self.StopLootTracking then
        self:StopLootTracking()
    end

    if self.StoreDebugReport then
        self:StoreDebugReport("abandoned_run", {
            trigger = "FinalizeAbandonedActiveRun",
            result = "abandoned",
            runId = activeRun.runId,
            state = activeRun.state,
            mapChallengeModeID = activeRun.mapChallengeModeID,
            level = activeRun.keyLevel,
        })
    end

    self:AddAbandonedRun(activeRun)
    self:ForgetRecoveryState(activeRun.runId)

    if self.runtime and self.runtime.activeRun == activeRun then
        self:ClearActiveRun()
    end
end

function MythicTools:FinalizeActiveRun(attempt)
    local activeRun = self.runtime and self.runtime.activeRun or nil
    if type(activeRun) ~= "table" or (not activeRun.completionPending and not self:HasCompletionSignals(activeRun)) then
        return false
    end

    if activeRun.state == "finalized_completed" or activeRun.state == "finalized_abandoned" then
        return false
    end

    if activeRun.finalizationInProgress then
        return false
    end

    activeRun.finalizationInProgress = true
    self:SetActiveRunState(activeRun, "finishing_completed")

    if self.runtime and self.runtime.activeRun ~= activeRun then
        activeRun.finalizationInProgress = false
        return false
    end

    self:HandleChallengeDeathCountUpdated()
    activeRun.completedAt = tonumber(activeRun.completedAt) or time()

    local completionInfo = self:GetResolvedChallengeCompletionInfo(activeRun, true)
    if IsValidCompletionInfo(completionInfo) then
        activeRun.pendingCompletionInfo = completionInfo
    else
        completionInfo = activeRun.pendingCompletionInfo
    end

    if not completionInfo or not completionInfo.mapChallengeModeID or completionInfo.mapChallengeModeID == 0 then
        if attempt < MAX_COMPLETION_ATTEMPTS and not self:ShouldUseEarlyCompletionRecovery(activeRun, attempt) then
            activeRun.finalizationInProgress = false
            self:PushRuntimeDebug(("run %s waiting for completion info attempt=%s"):format(tostring(activeRun.runId), tostring(attempt)))
            self:Schedule(COMPLETION_RETRY_DELAY, function()
                if self.runtime.activeRun == activeRun then
                    self:FinalizeActiveRun(attempt + 1)
                end
            end)
        else
            local recoveredInfo = BuildRecoveredCompletionInfo(activeRun)
            if IsValidCompletionInfo(recoveredInfo) then
                completionInfo = SetCachedCompletionInfo(activeRun, recoveredInfo, activeRun.pendingCompletionSource or "runtime_recovery")
                self:PushRuntimeDebug(("run %s using recovered completion info attempt=%s"):format(tostring(activeRun.runId), tostring(attempt)))
            else
                activeRun.finalizationInProgress = false
                self:PushRuntimeDebug(("run %s missing completion info after retries"):format(tostring(activeRun.runId)))
                if self.StoreDebugReport then
                    self:StoreDebugReport("missing_completion_info", {
                        trigger = activeRun.pendingCompletionSource or "FinalizeActiveRun",
                        runId = activeRun.runId,
                        state = activeRun.state,
                        mapChallengeModeID = activeRun.mapChallengeModeID,
                        level = activeRun.keyLevel,
                    })
                end
                return false
            end
        end
        if not completionInfo or not completionInfo.mapChallengeModeID or completionInfo.mapChallengeModeID == 0 then
            return false
        end
    end

    local persistedRun = self:PersistCompletedRun(activeRun, completionInfo, activeRun.pendingCompletionSource or "FinalizeActiveRun")
    activeRun.finalizationInProgress = false
    if not persistedRun then
        return false
    end

    self:SetActiveRunState(activeRun, "finalized_completed")

    if self.runtime and self.runtime.activeRun == activeRun then
        self:ClearActiveRun()
    end

    return true
end

function MythicTools:HandleChallengeModeCompleted()
    local completionInfo = GetChallengeCompletionInfoCompat()
    if not (self.runtime and type(self.runtime.activeRun) == "table") and IsValidCompletionInfo(completionInfo) and self.TryUpdateLastCompletedRunCompletionInfo then
        self:TryUpdateLastCompletedRunCompletionInfo(completionInfo, "native")
    end
    if self.StoreDebugReport then
        self:StoreDebugReport("event_completed", {
            trigger = "CHALLENGE_MODE_COMPLETED",
            runId = self.runtime and self.runtime.activeRun and self.runtime.activeRun.runId or nil,
            mapChallengeModeID = completionInfo and completionInfo.mapChallengeModeID or nil,
            level = completionInfo and completionInfo.level or nil,
        })
    end
    self:BeginActiveRunCompletion("CHALLENGE_MODE_COMPLETED", completionInfo, IsValidCompletionInfo(completionInfo) and "native" or "completed")
end

function MythicTools:HandleScenarioCompleted()
    local completionInfo = GetChallengeCompletionInfoCompat()
    if not (self.runtime and type(self.runtime.activeRun) == "table") and IsValidCompletionInfo(completionInfo) and self.TryUpdateLastCompletedRunCompletionInfo then
        self:TryUpdateLastCompletedRunCompletionInfo(completionInfo, "scenario")
    end
    if self.StoreDebugReport then
        self:StoreDebugReport("event_scenario_completed", {
            trigger = "SCENARIO_COMPLETED",
            runId = self.runtime and self.runtime.activeRun and self.runtime.activeRun.runId or nil,
            mapChallengeModeID = completionInfo and completionInfo.mapChallengeModeID or nil,
            level = completionInfo and completionInfo.level or nil,
        })
    end
    self:BeginActiveRunCompletion("SCENARIO_COMPLETED", completionInfo, IsValidCompletionInfo(completionInfo) and "native" or "scenario")
end

function MythicTools:HandleChallengeModeCompletedRewards(mapChallengeModeID, medal, timeMS, money, rewards)
    if self.runtime then
        self.runtime.lastCompletionRewards = {
            mapChallengeModeID = tonumber(mapChallengeModeID) or 0,
            medal = tonumber(medal) or 0,
            timeMS = tonumber(timeMS) or 0,
            money = tonumber(money) or 0,
            rewards = rewards,
            receivedAt = time(),
        }
    end

    if self.StoreDebugReport then
        self:StoreDebugReport("event_completed_rewards", {
            trigger = "CHALLENGE_MODE_COMPLETED_REWARDS",
            runId = self.runtime and self.runtime.activeRun and self.runtime.activeRun.runId or nil,
            mapChallengeModeID = tonumber(mapChallengeModeID) or 0,
            level = self.runtime and self.runtime.activeRun and self.runtime.activeRun.keyLevel or nil,
            rewardsTimeMS = tonumber(timeMS) or 0,
        })
    end

    local rewardCompletionInfo = nil
    local rewardMapID = tonumber(mapChallengeModeID) or 0
    local rewardLevel = self.runtime and self.runtime.lastCompletedLevel or nil
    local mapInfo = GetMapInfo(rewardMapID)
    local timeLimitSeconds = tonumber(mapInfo and mapInfo.timeLimit) or 0
    if rewardMapID > 0 and tonumber(timeMS) and tonumber(timeMS) > 0 and tonumber(rewardLevel) and tonumber(rewardLevel) > 0 then
        rewardCompletionInfo = {
            mapChallengeModeID = rewardMapID,
            level = tonumber(rewardLevel),
            time = tonumber(timeMS),
            onTime = timeLimitSeconds > 0 and tonumber(timeMS) <= (timeLimitSeconds * 1000) or nil,
            keystoneUpgradeLevels = 0,
            practiceRun = false,
            oldOverallDungeonScore = nil,
            newOverallDungeonScore = nil,
            isMapRecord = nil,
            isAffixRecord = nil,
            primaryAffix = nil,
            isEligibleForScore = nil,
            members = nil,
        }
    end

    if not (self.runtime and type(self.runtime.activeRun) == "table") and IsValidCompletionInfo(rewardCompletionInfo) and self.TryUpdateLastCompletedRunCompletionInfo then
        self:TryUpdateLastCompletedRunCompletionInfo(rewardCompletionInfo, "rewards")
    end

    local activeRun = self.runtime and self.runtime.activeRun or nil
    local queuedSnapshot = self:GetRecoverableCompletionSnapshot(mapChallengeModeID, 0)
    if type(queuedSnapshot) == "table" and (type(activeRun) ~= "table" or (not activeRun.completionPending and not self:HasCompletionSignals(activeRun))) then
        if self:ProcessPendingCompletionSnapshots("CHALLENGE_MODE_COMPLETED_REWARDS", true) then
            return
        end
    end

    activeRun = self:EnsureCompletionActiveRun(nil, "CHALLENGE_MODE_COMPLETED_REWARDS")
    if type(activeRun) ~= "table" then
        return
    end

    local completionInfo = self:GetResolvedChallengeCompletionInfo(activeRun, activeRun.allowCompletionRecovery and true or false)
    self:BeginActiveRunCompletion("CHALLENGE_MODE_COMPLETED_REWARDS", completionInfo, "rewards")
end










