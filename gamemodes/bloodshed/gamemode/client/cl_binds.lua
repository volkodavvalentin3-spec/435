MuR = MuR or {}
MuR.Binds = MuR.Binds or {}

local bindsFile = "bloodshed/client_binds.json"
local defaultBinds = {
    ["mur_ragdoll"] = KEY_B,
    ["mur_legkick"] = KEY_G,
    ["mur_armor_panel"] = KEY_NONE,
    ["mur_voicepanel"] = KEY_NONE,
    ["mur_wep_drop"] = KEY_NONE,
    ["mur_wep_unload"] = KEY_NONE,
    ["mur_shout"] = KEY_H,
    ["mur_hostage_capture"] = KEY_N,
    ["mur_hostage_execute"] = KEY_V,
    ["mur_ron_briefing"] = KEY_M
}

concommand.Add("mur_shout", function()
    net.Start("MuR.VoiceLines")
    net.WriteFloat(140)
    net.SendToServer()
end)

function MuR:LoadBinds()
    if file.Exists(bindsFile, "DATA") then
        local data = file.Read(bindsFile, "DATA")
        local storedBinds = util.JSONToTable(data)
        if storedBinds then
            for cmd, key in pairs(defaultBinds) do
                if storedBinds[cmd] then
                    MuR.Binds[cmd] = storedBinds[cmd]
                else
                    MuR.Binds[cmd] = key
                end
            end

            table.Merge(MuR.Binds, storedBinds)
        else
            MuR.Binds = table.Copy(defaultBinds)
        end
    else
        MuR.Binds = table.Copy(defaultBinds)
    end
end

function MuR:SaveBinds()
    if not file.Exists("bloodshed", "DATA") then
        file.CreateDir("bloodshed")
    end
    file.Write(bindsFile, util.TableToJSON(MuR.Binds))
end

function MuR:GetBind(cmd)
    return MuR.Binds[cmd] or defaultBinds[cmd] or KEY_NONE
end

function MuR:SetBind(cmd, key)
    MuR.Binds[cmd] = key
    MuR:SaveBinds()
end

MuR:LoadBinds()

hook.Add("PlayerButtonDown", "MuR_BindSystem_Press", function(ply, button)
    if not IsFirstTimePredicted() then return end
    if ply ~= LocalPlayer() then return end
    if vgui.GetKeyboardFocus() then return end
    if gui.IsGameUIVisible() then return end

    for cmd, key in pairs(MuR.Binds) do
        if key == button and key ~= KEY_NONE then
            RunConsoleCommand(cmd)
        end
    end
end)
