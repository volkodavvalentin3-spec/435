ZGM3_CVARS = {

    ["zippygore3_enable"] = true,

    ["zippygore3_misc_bones_health_mult"] = 8,
    ["zippygore3_root_bone_health_mult"] = 12,

    ["zippygore3_phys_damage_mult"] = 0.5,
    ["zippygore3_explosion_damage_mult"] = 4,
    ["zippygore3_bullet_damage_highest"] = 250,

    ["zippygore3_disable_never_gib_damage"] = false,
    ["zippygore3_disable_always_gib_damage"] = false,
    ["zippygore3_gib_any_ragdoll"] = false,
    ["zippygore3_gib_dissolving_ragdoll"] = true,

    ["zippygore3_gib_limit"] = 180,
    ["zippygore3_gib_lifetime"] = 120,
    ["zippygore3_gib_edible"] = false,
    ["zippygore3_gib_heath_give"] = 5,

    ["zippygore3_bleed_effect"] = true,

    ["zippygore3_print_gibbed_bone"] = false,

    ["zippygore3_dismemberment"] = true,
    ["zippygore3_stumps"] = true,
}

local saved_cvars_file = "zippygore3_saved_cvars.json"
if !file.Exists(saved_cvars_file, "DATA") then file.Write(saved_cvars_file, "[]") end

local saved_cvars = util.JSONToTable( file.Read(saved_cvars_file) )

if SERVER then
    for k,v in pairs(saved_cvars) do
        RunConsoleCommand(k, v)
    end
end

if CLIENT then
    function ZippyGoreMod3_ChangeCvar( cvar, v )
        net.Start("ZippyGoreMod3_ChangeCvar")
        net.WriteString(cvar)
        net.WriteString(v)
        net.SendToServer()
    end
end

if SERVER then
    util.AddNetworkString("ZippyGoreMod3_ChangeCvar")

    net.Receive("ZippyGoreMod3_ChangeCvar", function( _, ply )
        if !ply:IsSuperAdmin() then return end

        local cvar = net.ReadString()
        local v = net.ReadString()

        RunConsoleCommand(cvar, v)

        saved_cvars[cvar] = v
        file.Write(saved_cvars_file, util.TableToJSON(saved_cvars))
    end)
end
