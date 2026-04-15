local _, ns = ...
local MythicTools = ns.MythicTools

function MythicTools:InitializeSlashCommands()
    SLASH_SKYMYTHICHISTORY1 = "/smh"

    SlashCmdList.SKYMYTHICHISTORY = function(message)
        MythicTools:HandleSlashCommand(message)
    end
end

function MythicTools:PrintHelp()
    self:Print("/smh — open / close the main window")
    self:Print("/smh player Name-Realm — open a player's history")
    self:Print("/smh test — preview the completion popup")
    self:Print("/smh debug — show debug logging status")
    self:Print("/smh debug on|off — enable / disable debug logging")
    self:Print("/smh debug last — print the latest debug report")
    self:Print("/smh debug clear — clear all saved debug reports")
end

function MythicTools:HandleSlashCommand(message)
    message = self:TrimText(message)
    if message == "" then
        self:ToggleMainFrame()
        return
    end

    local command, rest = message:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""

    if command == "help" then
        self:PrintHelp()
        return
    end

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
            self:Print("Type /smh debug on|off|last|clear for debug options.")
            return
        end

        self:Print(("Unknown debug subcommand: %s"):format(subcommand))
        self:Print("Type /smh help for a list of commands.")
        return
    end

    self:Print(("Unknown command: %s"):format(command))
    self:Print("Type /smh help for a list of commands.")
end
