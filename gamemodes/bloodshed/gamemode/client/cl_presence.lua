if not util.IsBinaryModuleInstalled("steamrichpresencer") then
    print("This session supports Steam Rich Presence, but you do not have the module installed.")
else
    require("steamrichpresencer")
    print("Steam Rich Presence initialized successfully.")

    timer.Create("SteamRichPresenceTimer", 5, 0, function()
        local s0 = MuR.Language["gamedesc0"]
        local s1 = MuR.Language["startscreen_gamemode"] .. (MuR.Language["gamename"..MuR.GamemodeCount] or "Unknown")
        local s2 = player.GetCount()
        local s3 = game.MaxPlayers()

        local steamStatus = string.format("%s Bloodshed: Redux | %s | Players: [%d/%d]", s0, s1, s2, s3)
        if MuR.EnableDebug == true then
            steamStatus = "Bloodshed: Redux | Sandbox Mode"
        end

        steamworks.SetRichPresence("generic", steamStatus)
    end)
end

if not util.IsBinaryModuleInstalled("gdiscord") then
    print("This session supports GDiscord Rich Presence, but you do not have the module installed.")
else
    require("gdiscord")
    print("GDiscord Rich Presence initialized successfully.")

    local map_restrict = false
    local map_list = {
        gm_flatgrass = true,
        gm_construct = true
    }
    local image_fallback = "default"
    local discord_id = "1398640364637917266"
    local discord_start = discord_start or -1

    function DiscordUpdate()
        local rpc_data = {}

        local cnt = MuR.GamemodeCount >= 1 and MuR.GamemodeCount <= 15 or 0
        local s2 = MuR.Language["startscreen_gamemode"] .. (MuR.Language["gamename"..MuR.GamemodeCount] or "Unknown")
        local s3 = player.GetCount()
        local s4 = game.MaxPlayers()

        if MuR.EnableDebug == true then
            s2 = "Sandbox Mode"
        end
        rpc_data["details"] = s2

        if game.SinglePlayer() then
            rpc_data["state"] = "Singleplayer"
        else
            rpc_data["state"] = "Players"
        end

        rpc_data["buttonPrimaryLabel"] = "Download Gamemode"
        rpc_data["buttonPrimaryUrl"] = "https://steamcommunity.com/sharedfiles/filedetails/?id=3508448413"
        rpc_data["partySize"] = s3
        rpc_data["partyMax"] = s4
        if game.SinglePlayer() then rpc_data["partyMax"] = 0 end

        rpc_data["largeImageKey"] = game.GetMap()
        rpc_data["largeImageText"] = game.GetMap()
        if map_restrict and not map_list[game.GetMap()] then
            rpc_data["largeImageKey"] = image_fallback
        end

        rpc_data["startTimestamp"] = discord_start

        DiscordUpdateRPC(rpc_data)
    end

    hook.Add("Initialize", "UpdateDiscordStatus", function()
        discord_start = os.time()
        DiscordRPCInitialize(discord_id)
        DiscordUpdate()

    end)
    timer.Create("DiscordRPCTimer", 5, 0, DiscordUpdate)
end
