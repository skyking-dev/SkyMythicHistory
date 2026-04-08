local _, ns = ...
local MythicTools = ns.MythicTools

function MythicTools:QueueGroupScan()
    if not self.runtime or self.runtime.groupScanQueued then
        return
    end

    self.runtime.groupScanQueued = true
    self:Schedule(0.15, function()
        if not self.runtime then
            return
        end

        self.runtime.groupScanQueued = false
        self:ScanKnownPlayersInGroup()
    end)
end

function MythicTools:BuildKnownPlayerMessage(fullName, playerEntry)
    local displayName = self:GetShortName(fullName)
    local latestRun = playerEntry.lastRunId and self:GetRunById(playerEntry.lastRunId) or nil

    if latestRun then
        return ("You already ran %d keys with %s (%d timed). Last run: %s +%d on %s."):format(
            playerEntry.totalRuns or 0,
            displayName,
            playerEntry.timedRuns or 0,
            latestRun.dungeonName or "Unknown",
            latestRun.level or 0,
            self:FormatDate(latestRun.endTime)
        )
    end

    return ("You already ran %d keys with %s (%d timed)."):format(
        playerEntry.totalRuns or 0,
        displayName,
        playerEntry.timedRuns or 0
    )
end

function MythicTools:ScanKnownPlayersInGroup()
    if not self.db or not self.db.settings.chatAlerts then
        return
    end

    local roster = self:GetCurrentGroupRoster()
    local rosterSignature = self:GetRosterSignature(roster)
    self.runtime.lastRosterSignature = rosterSignature

    if #roster <= 1 then
        return
    end

    for _, entry in ipairs(roster) do
        if entry.name ~= self.playerName then
            local playerEntry = self.db.playersIndex[entry.name]
            if playerEntry and self.runtime.announcedPlayers[entry.name] ~= rosterSignature then
                self.runtime.announcedPlayers[entry.name] = rosterSignature
                self:Print(self:BuildKnownPlayerMessage(entry.name, playerEntry))
            end
        end
    end
end
