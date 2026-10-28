local meta = FindMetaTable("Entity")
util.AddNetworkString("MuR.EntityPlayerColor")

function meta:MakePlayerColor(col)
	timer.Simple(0.1, function()
		if not IsValid(self) then return end
		net.Start("MuR.EntityPlayerColor")
		net.WriteEntity(self)
		net.WriteVector(col)
		net.Broadcast()
	end)
end

MuR.BLOOD_POOL = {
    LARGE  = 0,
    DROPS  = 1,
    HUGE   = 2,
    MEDIUM = 3,
    GUSH   = 10,
    SMALL  = 11
}

function MuR:CreateBloodPool(rag, boneid, flags, needvel)
    local time = (flags == 0 or flags == 2) and 2 or 0.01
    timer.Simple(time, function()
        if not IsValid(rag) then return end
        local boneid = boneid or 0
        local flags = flags or 0
        local needvel = needvel or 0
        if MuR.BroadcastBloodPoolEffect then
            MuR:BroadcastBloodPoolEffect(rag, boneid, flags, needvel)
            return
        end

        local effectdata = EffectData()
        effectdata:SetEntity(rag)
        effectdata:SetAttachment(boneid)
        effectdata:SetFlags(flags)
        effectdata:SetRadius(needvel)
        effectdata:SetOrigin(rag:WorldSpaceCenter())
        util.Effect("bloodshed_blood_pool", effectdata, true, true)
    end)
end

local entMeta = FindMetaTable( "Entity" )

function meta:StealthOpenDoor()
    if !self.stealthopen then
        self.stealthopen = true

        local oldspeed = tonumber(self:GetInternalVariable( "speed" )) or tonumber(self:GetInternalVariable( "Speed" )) or 100
        self.oldspeed = oldspeed
        self:SetSaveValue( "Speed", self.oldspeed / 2 )

        local uniqueIdent = self:EntIndex() and self:EntIndex() or tostring( self:GetPos() )

        local distKey = self:GetClass() == "prop_door_rotating" and "distance" or "m_flMoveDistance"
        local dist = tonumber( self:GetInternalVariable( distKey ) or 0 )
        local speed = tonumber( self:GetInternalVariable( "speed" ) ) or self.oldspeed / 2

        local waitTime = 4
        if speed and speed > 0 and dist and dist > 0 then
            waitTime = 4 * ( speed / dist )
            if waitTime ~= waitTime or waitTime <= 0.05 then waitTime = 4 end
            waitTime = math.min( waitTime, 30 )
        end

        timer.Create( "resetdoorstealthval" .. uniqueIdent, waitTime, 1, function()
            if !IsValid(self) then return end

            local savetab = self:GetSaveTable()

            local busy = !savetab or savetab.m_eDoorState == 1 or savetab.m_eDoorState == 3

            if !busy then
                if isnumber(self.oldspeed) then
                    self:SetSaveValue( "Speed", self.oldspeed )
                end
                self.stealthopen = false
            else
                timer.Create( "checkfordoorreset" .. uniqueIdent, 0.1, 0, function()
                    if !IsValid(self) then
                        timer.Remove( "checkfordoorreset" .. uniqueIdent )
                        return
                    end

                    local savetab = self:GetSaveTable()

                    if savetab and savetab.m_eDoorState != 1 and savetab.m_eDoorState != 3 then
                        if isnumber(self.oldspeed) then
                            self:SetSaveValue( "Speed", self.oldspeed )
                        end
                        self.stealthopen = false
                        timer.Remove( "checkfordoorreset" .. uniqueIdent )
                    end
                end )
            end
        end )
    end
end

function meta:SDOIsDoor()
    return self:GetClass() == "prop_door_rotating" or self:GetClass() == "func_door_rotating"
end

hook.Add("AcceptInput", "MuR_StealthOpenDoors", function( ent, inp, act, ply, val )
    if inp == "Use" and ent:SDOIsDoor() and ( ply:Crouching() or ply:KeyDown( IN_WALK ) ) then
        ent:StealthOpenDoor()
        if ent:GetInternalVariable( "slavename" ) then
            for k,v in pairs( ents.FindByName( ent:GetInternalVariable( "slavename" ) ) ) do
                v:StealthOpenDoor()
            end
        end
        for _, v in ipairs(ents.FindByClass( ent:GetClass() )) do
            if ent == v:GetInternalVariable( "m_hMaster" ) then
                v:StealthOpenDoor()
            end
        end
        if ent:GetInternalVariable( "m_hMaster" ) and IsValid( ent:GetInternalVariable( "m_hMaster" ) ) and ent:GetInternalVariable( "m_hMaster" ):SDOIsDoor() then
            ent:GetInternalVariable( "m_hMaster" ):StealthOpenDoor()
        end
    end

end)

hook.Add("EntityEmitSound", "MuR_StealthOpenDoors_EmitSound", function( data )
    if IsValid( data.Entity ) and data.Entity:SDOIsDoor() and data.Entity.stealthopen then
        data.Volume = data.Volume * 0.2
		data.SoundLevel = 50
        return true
    end
end)

player_manager.AddValidModel("Hatred Antagonist", "models/murdered/pm/hatred_mh.mdl")
player_manager.AddValidHands("Hatred Antagonist", "models/weapons/c_arms_cstrike.mdl", 0, "00000000")

player_manager.AddValidModel("Soldier DM", "models/murdered/pm/t_grunts.mdl")
player_manager.AddValidHands("Soldier DM", "models/weapons/c_arms_cstrike.mdl", 0, "00000000")

player_manager.AddValidModel( "Police NYPD 01","models/murdered/pm/police/male_01.mdl" )
player_manager.AddValidHands( "Police NYPD 01", "models/murdered/pm/police/c_arms_nypd.mdl", 0, "00000000" )
player_manager.AddValidModel( "Police NYPD 03","models/murdered/pm/police/male_03.mdl" )
player_manager.AddValidHands( "Police NYPD 03", "models/murdered/pm/police/c_arms_nypd.mdl", 0, "00000000" )
player_manager.AddValidModel( "Police NYPD 04","models/murdered/pm/police/male_04.mdl" )
player_manager.AddValidHands( "Police NYPD 04", "models/murdered/pm/police/c_arms_nypd.mdl", 0, "00000000" )
player_manager.AddValidModel( "Police NYPD 05","models/murdered/pm/police/male_05.mdl" )
player_manager.AddValidHands( "Police NYPD 05", "models/murdered/pm/police/c_arms_nypd.mdl", 0, "00000000" )
player_manager.AddValidModel( "Police NYPD 06","models/murdered/pm/police/male_06.mdl" )
player_manager.AddValidHands( "Police NYPD 06", "models/murdered/pm/police/c_arms_nypd.mdl", 0, "00000000" )
player_manager.AddValidModel( "Police NYPD 07","models/murdered/pm/police/male_07.mdl" )
player_manager.AddValidHands( "Police NYPD 07", "models/murdered/pm/police/c_arms_nypd.mdl", 0, "00000000" )
player_manager.AddValidModel( "Police NYPD 08","models/murdered/pm/police/male_08.mdl" )
player_manager.AddValidHands( "Police NYPD 08", "models/murdered/pm/police/c_arms_nypd.mdl", 0, "00000000" )
player_manager.AddValidModel( "Police NYPD 09","models/murdered/pm/police/male_09.mdl" )
player_manager.AddValidHands( "Police NYPD 09", "models/murdered/pm/police/c_arms_nypd.mdl", 0, "00000000" )

player_manager.AddValidModel( "SWAT NYPD 01","models/murdered/pm/swat/male_01.mdl" )
player_manager.AddValidHands( "SWAT NYPD 01", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "SWAT NYPD 02","models/murdered/pm/swat/male_02.mdl" )
player_manager.AddValidHands( "SWAT NYPD 02", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "SWAT NYPD 03","models/murdered/pm/swat/male_03.mdl" )
player_manager.AddValidHands( "SWAT NYPD 03", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "SWAT NYPD 04","models/murdered/pm/swat/male_04.mdl" )
player_manager.AddValidHands( "SWAT NYPD 04", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "SWAT NYPD 05","models/murdered/pm/swat/male_05.mdl" )
player_manager.AddValidHands( "SWAT NYPD 05", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "SWAT NYPD 06","models/murdered/pm/swat/male_06.mdl" )
player_manager.AddValidHands( "SWAT NYPD 06", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "SWAT NYPD 07","models/murdered/pm/swat/male_07.mdl" )
player_manager.AddValidHands( "SWAT NYPD 07", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "SWAT NYPD 08","models/murdered/pm/swat/male_08.mdl" )
player_manager.AddValidHands( "SWAT NYPD 08", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "SWAT NYPD 09","models/murdered/pm/swat/male_09.mdl" )
player_manager.AddValidHands( "SWAT NYPD 09", "models/weapons/c_arms_combine.mdl", 0, "00000000" )

player_manager.AddValidModel( "Security Forces 01","models/murdered/pm/sf/guard_01.mdl" )
player_manager.AddValidHands( "Security Forces 01", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "Security Forces 02","models/murdered/pm/sf/guard_02.mdl" )
player_manager.AddValidHands( "Security Forces 02", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "Security Forces 03","models/murdered/pm/sf/guard_03.mdl" )
player_manager.AddValidHands( "Security Forces 03", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "Security Forces 04","models/murdered/pm/sf/guard_04.mdl" )
player_manager.AddValidHands( "Security Forces 04", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "Security Forces 05","models/murdered/pm/sf/guard_05.mdl" )
player_manager.AddValidHands( "Security Forces 05", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "Security Forces 06","models/murdered/pm/sf/guard_06.mdl" )
player_manager.AddValidHands( "Security Forces 06", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "Security Forces 07","models/murdered/pm/sf/guard_07.mdl" )
player_manager.AddValidHands( "Security Forces 07", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "Security Forces 08","models/murdered/pm/sf/guard_08.mdl" )
player_manager.AddValidHands( "Security Forces 08", "models/weapons/c_arms_combine.mdl", 0, "00000000" )
player_manager.AddValidModel( "Security Forces 09","models/murdered/pm/sf/male_09.mdl" )
player_manager.AddValidHands( "Security Forces 09", "models/weapons/c_arms_combine.mdl", 0, "00000000" )

player_manager.AddValidModel( "Merryweather 1","models/murdered/pm/pmc/male_01.mdl" )
player_manager.AddValidModel( "Merryweather 2","models/murdered/pm/pmc/male_02.mdl" )
player_manager.AddValidModel( "Merryweather 3","models/murdered/pm/pmc/male_03.mdl" )
player_manager.AddValidModel( "Merryweather 4","models/murdered/pm/pmc/male_04.mdl" )
player_manager.AddValidModel( "Merryweather 5","models/murdered/pm/pmc/male_05.mdl" )
player_manager.AddValidModel( "Merryweather 6","models/murdered/pm/pmc/male_06.mdl" )
player_manager.AddValidModel( "Merryweather 7","models/murdered/pm/pmc/male_07.mdl" )
player_manager.AddValidModel( "Merryweather 8","models/murdered/pm/pmc/male_08.mdl" )
player_manager.AddValidModel( "Merryweather 9","models/murdered/pm/pmc/male_09.mdl" )

player_manager.AddValidModel( "FBI UIU", "models/murdered/pm/FBI_UIU_Operative.mdl" )
player_manager.AddValidHands( "FBI UIU", "models/murdered/pm/enigma_vm.mdl", 0, "00" )

player_manager.AddValidModel( "Tony - Hotline Miami 2", "models/murdered/pm/Tony.mdl" )
player_manager.AddValidHands( "Tony - Hotline Miami 2", "models/murdered/pm/Tony_Hands.mdl", 0, "00000000" )

function ZBaseUpdateGuard() end

local netCooldowns = {}

function MuR:NetRateLimit(ply, key, interval)
    if not IsValid(ply) then return false end

    local store = netCooldowns[ply]
    if not store then
        store = {}
        netCooldowns[ply] = store
    end

    local now = CurTime()
    if store[key] and now < store[key] then return false end

    store[key] = now + (interval or 0.25)
    return true
end

hook.Add("PlayerDisconnected", "MuR.NetRateLimitCleanup", function(ply)
    netCooldowns[ply] = nil
end)

local TRAP_ARM_GRACE = 2

function MuR:SetTrapOwner(trap, owner)
    if not IsValid(trap) then return end

    trap.TrapOwner = IsValid(owner) and owner or nil
    trap.TrapArmTime = CurTime() + TRAP_ARM_GRACE
end

function MuR:TrapIgnoresVictim(trap, victim)
    if not IsValid(trap) or not IsValid(victim) then return true end
    if trap.TrapArmTime and CurTime() < trap.TrapArmTime then return true end

    local owner = trap.TrapOwner
    if not IsValid(owner) then
        owner = trap.OwnerTrap
    end
    if not IsValid(owner) and trap.GetOwner then
        owner = trap:GetOwner()
    end
    if not IsValid(owner) then return false end

    if victim == owner then return true end

    if victim.isRDRag and victim.Owner == owner then return true end
    if owner.GetRD and victim == owner:GetRD() then return true end

    if victim:IsPlayer() and owner:IsPlayer() and victim:IsKiller() and owner:IsKiller() then
        return true
    end

    if MuR.IsAI(owner) and MuR.IsAI(victim) then
        return true
    end

    return false
end

local BARRICADE_SOUND = "ambient/materials/door_hit1.wav"
local PUSH_FORCE = 400
local CHECK_DISTANCE = 48

local DOOR_CLASSES = {
    ["prop_door_rotating"] = true,
}

local function IsDoor(entity)
    if not IsValid(entity) then return false end
    return DOOR_CLASSES[entity:GetClass()] or false
end

local function IsDoorLocked(door)
    if door.IsLocked and isfunction(door.IsLocked) then
        return door:IsLocked()
    elseif door.m_bLocked ~= nil then
        return door.m_bLocked
    elseif door.GetInternalVariable and isfunction(door.GetInternalVariable) then
        return door:GetInternalVariable("m_bLocked")
    end
    return false
end

local function GetDoorOpenDirection(door, activator)
    local doorClass = door:GetClass()

    if doorClass == "prop_door_rotating" or doorClass == "func_door_rotating" then
        local doorForward = door:GetForward()
        local toActivator = (activator:GetPos() - door:GetPos())
        toActivator.z = 0
        toActivator:Normalize()

        local dot = doorForward:Dot(toActivator)

        if dot > 0 then
            return -doorForward
        else
            return doorForward
        end
    else
        return door:GetRight()
    end
end

local function DoorIsOpen(door)
	local doorClass = door:GetClass()

	if doorClass == "func_door" or doorClass == "func_door_rotating" then
		return door:GetInternalVariable( "m_toggle_state" ) == 0
	elseif doorClass == "prop_door_rotating" then
		return door:GetInternalVariable( "m_eDoorState" ) ~= 0
	else
		return false
	end
end

local function CheckSize(ent)
    return ent:OBBMaxs():Length()
end

local function CheckDoorObstacles(door, openDirection)
    local doorPos = Vector(door:WorldSpaceCenter().x, door:WorldSpaceCenter().y, door:GetPos().z)
    local doorAng = door:GetAngles()
    local doorMins, doorMaxs = door:OBBMins(), door:OBBMaxs()

    local hullMins = door:LocalToWorld(doorMins)
    local hullMaxs = door:LocalToWorld(doorMaxs)

    local hullCenter = (hullMins + hullMaxs) / 2
    local hullSize = (hullMaxs - hullMins)

    local traceStart = doorPos + openDirection * 16
    local traceEnd = doorPos + openDirection * CHECK_DISTANCE

    debugoverlay.Box(traceStart, -hullSize / 2, hullSize / 2, 1, Color(255, 25, 25, 100), true)
    debugoverlay.Box(traceEnd, -hullSize / 2, hullSize / 2, 1, Color(25, 255, 25, 100), true)

    local trace = util.TraceHull({
        start = traceStart,
        endpos = traceEnd,
        mins = -hullSize / 2,
        maxs = hullSize / 2,
        ignoreworld = true,
        filter = function(ent)
            if ent == door or ent:IsWorld() then return false end
            if ent:IsPlayer() or (IsValid(ent:GetPhysicsObject()) and ent:GetPhysicsObject():IsMoveable() and CheckSize(ent) > 25) then
                return true
            end
            return false
        end
    })

    return trace.Hit, trace.Entity
end

local function PushBackEntity(door, entity, direction)
    if not IsValid(entity) then return end

    if entity:IsPlayer() then
        entity:SetVelocity(direction * PUSH_FORCE)
        entity:TakeDamage(math.random(2,4))
    elseif entity:GetPhysicsObject() and entity:GetPhysicsObject():IsValid() then
        local phys = entity:GetPhysicsObject()
        if phys:IsMoveable() then
            phys:ApplyForceCenter(direction * PUSH_FORCE * phys:GetMass())
        end
        entity:TakeDamage(math.random(10,20))
    end
end

local function HandleDoorBarricade(activator, door)
    if IsDoorLocked(door) or DoorIsOpen(door) then return false end
    if door.BarricadeDelay and door.BarricadeDelay > CurTime() then return true end

    local openDirection = GetDoorOpenDirection(door, activator)

    local isObstructed, obstruction = CheckDoorObstacles(door, openDirection)
    if isObstructed then
        door:EmitSound(BARRICADE_SOUND, 60, math.random(80,110))
        door:Fire("Open", "", 0, activator)
        door:Fire("Close", "", 0.05)

        PushBackEntity(door, obstruction, openDirection)
        door.BarricadeDelay = CurTime()+0.5

        return true
    end
end

hook.Add("AcceptInput", "DoorBarricadeSystem", function(ent, str, act, caller)
    if IsDoor(ent) and str == "Use" then
        return HandleDoorBarricade(act, ent)
    end
end)

function MuR:RefreshNoTarget(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    ply:SetNoTarget(ply:IsDying() or ply:IsRestrained())
end
