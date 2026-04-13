local _, ns = ...
local MythicTools = ns.MythicTools

function MythicTools:InitializeSlashCommands()
    SLASH_MYTHICTOOLS1 = "/mtools"
    SLASH_MYTHICTOOLS2 = "/mythictools"
    SLASH_MYTHICTOOLS3 = "/smh"

    SlashCmdList.MYTHICTOOLS = function(message)
        MythicTools:HandleSlashCommand(message)
    end
end

function MythicTools:HandleSlashCommand(message)
    message = self:TrimText(message)
    if message == "" then
        self:ToggleMainFrame()
        return
    end

    local command, rest = message:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""

    if command == "player" and rest and rest ~= "" then
        self:OpenPlayerHistory(rest)
        return
    end

    if command == "test" then
        if self.ShowTestCompletionPopup then
            self:ShowTestCompletionPopup()
        end
        return
    end

    if command == "debug" then
        local subcommand = rest:match("^(%S+)")
        subcommand = subcommand and subcommand:lower() or "status"

        if subcommand == "on" then
            self.db.debug.enabled = true
            self:Print("Mythic+ debug logging enabled.")
            return
        end

        if subcommand == "off" then
            self.db.debug.enabled = false
            self:Print("Mythic+ debug logging disabled.")
            return
        end

        if subcommand == "clear" then
            self.db.debug.reports = {}
            self:Print("Saved debug reports cleared.")
            return
        end

        if subcommand == "last" then
            if self.PrintLatestDebugReport then
                self:PrintLatestDebugReport()
            end
            return
        end

        if subcommand == "status" or subcommand == "" then
            local reportCount = #(self.db.debug.reports or {})
            self:Print(("Debug logging is %s. Saved reports: %d."):format(self.db.debug.enabled ~= false and "ON" or "OFF", reportCount))
            self:Print("Commands: /mtools debug on, /mtools debug off, /mtools debug last, /mtools debug clear")
            return
        end

        self:Print(("Unknown debug command: %s"):format(subcommand))
        self:Print("Commands: /mtools debug on, /mtools debug off, /mtools debug last, /mtools debug clear")
        return
    end

    self:Print("Commands: /smh, /mtools, /mythictools, /mtools player Name-Realm, /mtools test, /mtools debug")
end

