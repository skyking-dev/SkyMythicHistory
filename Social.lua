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

    return ("You already ran %d keys with %s (%d timed)"):format(
        playerEntry.totalRuns or 0,
        displayName,
        playerEntry.timedRuns or 0
    )
end

function MythicTools:PrintHistoryAlert(message)
    print(("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0|t |cffcfa85dSky Mythic History|r: %s"):format(tostring(message or "")))
end

function MythicTools:ScanKnownPlayersInGroup()
    if not self.db or not self.db.settings.chatAlerts then
        return
    end

    local roster = self:GetCurrentGroupRoster()
    local previousGroupPlayers = self.runtime.currentGroupPlayers or {}
    local currentGroupPlayers = {}

    if #roster <= 1 then
        self.runtime.currentGroupPlayers = currentGroupPlayers
        return
    end

    for _, entry in ipairs(roster) do
        currentGroupPlayers[entry.name] = true

        if entry.name ~= self.playerName then
            local playerEntry = self.db.playersIndex[entry.name]
            if playerEntry and not previousGroupPlayers[entry.name] then
                self:PrintHistoryAlert(self:BuildKnownPlayerMessage(entry.name, playerEntry))
            end
        end
    end

    self.runtime.currentGroupPlayers = currentGroupPlayers
end
