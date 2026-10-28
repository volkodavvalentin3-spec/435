local spawnEvents = {
    "PlayerSpawnEffect",
    "PlayerSpawnNPC",
    "PlayerSpawnObject",
    "PlayerSpawnProp",
    "PlayerSpawnRagdoll",
    "PlayerSpawnSENT",
    "PlayerSpawnSWEP",
    "PlayerSpawnVehicle",
}

for _, eventName in ipairs(spawnEvents) do
    hook.Add(eventName, "BlockSpawn_" .. eventName, function(ply, ...)
        return ply:IsSuperAdmin() or MuR.EnableDebug
    end)
end

hook.Add("CanProperty", "MuR.BlockPropertiesExploit", function(ply, property, ent)
    if not MuR.EnableDebug then
        return false
    end
end)

hook.Add("PlayerGiveSWEP", "BlockSpawn_FixSWEP", function(ply, class)
    -- The gamemode's pickup rules reject a regular `ply:Give`, so the weapon is
    -- handed over manually. That must happen synchronously and the hook must
    -- report success: returning false made sandbox print "Object creation was
    -- blocked" even though the weapon had already been given.
    if not ply:HasWeapon(class) then
        ply:GiveWeapon(class, nil, true)
    end
    return true
end)

hook.Add("PlayerNoClip", "MuR.NoclipDebugOnly", function(ply, desiredState)
	if desiredState == false then
		return true
	elseif ply:IsSuperAdmin() and MuR.EnableDebug then
		return true
	end
end)

local function CanBePushed(ply)
    return ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE and ply:IsSolid()
        and not ply:IsInHostage(true)
end

hook.Add("ShouldCollide", "MuR_FixStucks", function(ent1, ent2)
    if ent1:IsPlayer() and ent2:IsPlayer() and CanBePushed(ent1) and CanBePushed(ent2) then
        local b1, t1 = ent1:OBBMins(), ent1:OBBMaxs()
        local b2, t2 = ent2:OBBMins(), ent2:OBBMaxs()
        local p1 = ent1:GetPos()
        local p2 = ent2:GetPos()
        local min1 = p1 + b1
        local max1 = p1 + t1
        local min2 = p2 + b2
        local max2 = p2 + t2
        local overlap = min1.x <= max2.x and max1.x >= min2.x and
                        min1.y <= max2.y and max1.y >= min2.y and
                        min1.z <= max2.z and max1.z >= min2.z
        if overlap then
            local dir = (p1 - p2):GetNormalized()
            ent1:SetVelocity(dir * 10)
            ent2:SetVelocity(-dir * 10)
            return false
        end
    end
end)

CreateConVar("mur_disableguilt", 0, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "", 0, 1)
cvars.AddChangeCallback("mur_disableguilt", function(name, ov, nv)
    if nv == "1" then
        for _, ply in player.Iterator() do
            ply:ChangeGuilt("Guilt", -10)
        end
    end
end)
