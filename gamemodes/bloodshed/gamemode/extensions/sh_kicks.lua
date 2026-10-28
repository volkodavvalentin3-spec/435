AddCSLuaFile()

sound.Add({
    name = "foot.kickbody",
    channel = CHAN_AUTO,
    level = 70,
    volume = 1,
    pitch = {80, 110},
    sound = {"weapons/melee/rifle_swing_hit_infected7.wav", "weapons/melee/rifle_swing_hit_infected8.wav", "weapons/melee/rifle_swing_hit_infected9.wav", "weapons/melee/rifle_swing_hit_infected10.wav", "weapons/melee/rifle_swing_hit_infected11.wav", "weapons/melee/rifle_swing_hit_infected12.wav"}
})

sound.Add({
    name = "foot.kickwall",
    channel = CHAN_AUTO,
    level = 70,
    volume = 1,
    pitch = {80, 110},
    sound = {"codmelee/melee_hit_world_01.ogg", "codmelee/melee_hit_world_02.ogg", "codmelee/melee_hit_world_03.ogg", "codmelee/melee_hit_world_04.ogg", "codmelee/melee_hit_world_05.ogg"}
})

sound.Add({
    name = "foot.fire",
    channel = CHAN_AUTO,
    level = 65,
    volume = 1,
    pitch = {80, 110},
    sound = {"player/shove_01.wav", "player/shove_02.wav", "player/shove_03.wav", "player/shove_04.wav", "player/shove_05.wav"}
})

sound.Add({
    name = "foot.kickdoor",
    channel = CHAN_AUTO,
    level = 80,
    volume = 1,
    pitch = {90, 110},
    sound = {"physics/wood/wood_furniture_break1.wav", "physics/wood/wood_furniture_break2.wav", "physics/wood/wood_panel_break1.wav"}
})

util.PrecacheSound("foot.kickbody")
util.PrecacheSound("foot.kickwall")
util.PrecacheSound("foot.fire")

local powerscale = 1
local simpletrace = false
local dropkickmult = 2.00
local kickrange = 1.00
local kickdelay = 1
local kickspeed = 1
local blowdoorlocked = false
local blowdoorsliding = false
local blowdoorchance = 0
local doorgib = false
local doorgibcount = 10
local blowdoorforce = 1
local doorkick = true
local doorkickany = false
local slowdown = 0
local effect = true
local maxdamage = 20
local mindamage = 15
local disarmply = false
local disarmnpc = false
local unlock = false
local physforce = 1
local hitshake = false
local viewpunchscale = 1
local ragforce = 8
local doorrespawntime = 25
local doordamage = false
local damagebyspeed = false
local damagebyspeedmult = 1
local parry = false
local parrymult = 1
local propscaledforce = false
local pushback = 100
local heldpropkick = true
local trollphysics = false
local kickholster = false
local kickfast = false
local doorscaledamage = 4
local doorlastdamageunlock = true
local playerragdollchance = 40

local tick = engine.TickInterval()

function MFEngaged()
    local ply = LocalPlayer()
    if !IsValid(ply) then return end
    if ply.GetObserverMode and ply:GetObserverMode() != 0 then return end
    local speed, delay, fast = kickspeed, kickdelay, kickfast
    local ct, time = CurTime(), (fast and 0.3 or 0.75) / speed + delay + engine.TickInterval()
    if ply:GetMoveType() == 10 or !ply:Alive() or ply:IsFrozen() or ply:InVehicle() or IsValid(ply:GetNW2Entity("RD_Ent")) or ply:GetNW2String("SVAnim") != "" or ply:GetNW2Bool("LegBroken") then return end
    if ply:GetNW2Float("Stamina") < 20 then return end

    if !ply.MFNextKick then
        ply.MFNextKick = ct + time
    elseif ply.MFNextKick and ply.MFNextKick <= ct then
        SafeRemoveEntity(ply.MFRig)
        SafeRemoveEntity(ply.MFLeg)
        ply.MFKickTime = ct or 0
        ply.MFNextKick = ply.MFKickTime + time
        ply.MFDrawTime = 0.75 / speed
        net.Start("EngageMF")
        net.SendToServer()
    end
end

if CLIENT then
    local mfLockUntil = 0
    local mfForceStance = nil

    net.Receive("MF_StanceLock", function()
        mfForceStance = net.ReadString()

        local speed = math.max(kickspeed, 0.01)
        local duration = 0.9 / speed

        mfLockUntil = CurTime() + duration
    end)

    hook.Add("CreateMove", "MF_ForceClientStance", function(cmd)
        if CurTime() > mfLockUntil then return end
        if not mfForceStance then return end

        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        if mfForceStance == "crouch" then
            cmd:AddKey(IN_DUCK)
        elseif mfForceStance == "stand" then
            cmd:RemoveKey(IN_DUCK)
        elseif mfForceStance == "air" then
            cmd:RemoveKey(IN_JUMP)
        end
    end)
end

if CLIENT then
    concommand.Add("mur_legkick", function()
        net.Start("EngageMF")
        net.SendToServer()
    end)
end

if SERVER then
    util.AddNetworkString("EngageMF")
    net.Receive("EngageMF", function(_, ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        MightyFootEngaged(ply)
    end)
end

if CLIENT then
    local function MFInitStateClient()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local time = 0.3 / math.max(kickspeed, 0.0001)
        ply.MFKickTime = 0
        ply.MFNextKick = (ply.MFKickTime or 0) + time
        ply.MFDrawTime = 0
    end
    hook.Add("InitPostEntity", "MFInitStateClient", MFInitStateClient)
    hook.Add("PlayerSpawn", "MFInitStateClientSpawn", MFInitStateClient)

    hook.Add("StartCommand", "MFMoveHook_Client", function(ply, cmd)
        if ply ~= LocalPlayer() then return end
        local stopmove = slowdown
        local time = (ply.MFKickTime or 0) + (0.6 / math.max(kickspeed, 0.0001))
        if time > CurTime() then
            if kickholster then
                cmd:ClearButtons()
            end
            local mt = ply:GetMoveType()
            if stopmove >= 0 and mt ~= MOVETYPE_NOCLIP then
                if stopmove == 2 then
                    cmd:ClearMovement()
                elseif stopmove == 1 then
                    cmd:AddKey(IN_WALK)
                end
            end
        end
    end)
end

if SERVER then
    hook.Add("SetupMove", "MF_SlowdownHandler", function(ply, mv, cmd)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        local stopmove = slowdown
        if stopmove < 0 then return end

        local speedMult = 1
        local activeWindow = (ply.MFKickTime or 0) + (0.6 / math.max(kickspeed, 0.0001))

        if CurTime() < activeWindow then
            if stopmove == 2 then
                mv:SetForwardSpeed(0)
                mv:SetSideSpeed(0)
                return
            elseif stopmove == 1 then
                speedMult = ply:GetWalkSpeed() / ply:GetRunSpeed()
            elseif stopmove == 0 then
                speedMult = 0.6
            end

            mv:SetMaxClientSpeed(ply:GetRunSpeed() * speedMult)
            mv:SetMaxSpeed(ply:GetRunSpeed() * speedMult)
        end
    end)
end

local function MFEffect(tr, sf)
    if effect then
        local fx = EffectData()
        fx:SetStart(tr.HitPos)
        fx:SetOrigin(tr.HitPos)
        fx:SetNormal(tr.HitNormal)
        util.Effect(string.find(sf.name, "glass") and "GlassImpact" or "mf_groundhit", fx)
    end
end

if SERVER then
    local hullvec, offvec = Vector(4, 4, 4), Vector(0,0,16)
    local movetypo = { false, false, false, true, true, true}
    local DoorClasses = {
        prop_door_rotating = true,
        func_door = true,
        func_door_rotating = true
    }

    util.AddNetworkString("EngageMF")
    util.AddNetworkString("MFDoorBust")
    util.AddNetworkString("MF_StanceLock")

    function MFHit(ply)
        ply:LagCompensation(true)
        local dropkicking = (!ply:OnGround() and ply:WaterLevel() < 2) and ply:GetMoveType() ~= MOVETYPE_LADDER and ply:GetMoveType() ~= MOVETYPE_NOCLIP
        local damage = string.find(engine.ActiveGamemode(), "nzombies") and (30 + (45 / nzRound:GetNumber()) or 75) or math.random(mindamage, maxdamage) * powerscale * (dropkicking and dropkickmult or 1)
        local _, b = ply:GetHull()
        local pos = simpletrace and ply:EyePos() or ply:WorldSpaceCenter()
        local dist = (ply:GetEyeTraceNoCursor().HitPos - pos):GetNormalized() * (b.z * kickrange)
        local aimvector = ply:GetAimVector() * powerscale * (dropkicking and dropkickmult or 1)
        local pitch = ply:EyeAngles().pitch

        if pitch < -1 then
            dist = ply:GetForward() * (b.z * kickrange)
        else
            dist = (ply:GetEyeTraceNoCursor().HitPos - pos):GetNormalized() * (b.z * kickrange)
        end

        local trable = {
            start = pos,
            endpos = pos + dist,
            filter = {ply},
            mins = -hullvec,
            maxs = hullvec,
            mask = 1174421515
        }
        local trace = util.TraceLine(trable)
        if not trace.Hit then trace = util.TraceHull(trable) end

        local velocity = ply:GetVelocity():Length()

        if trace.Hit and not trace.HitSky then
            local ent, dir = trace.Entity, LerpVector(0.5, trace.Normal, aimvector)

            if ent:IsPlayer() and not ent:Alive() then return end

            local entclass = ent:GetClass()
            local phys = IsValid(ent:GetPhysicsObjectNum(trace.PhysicsBone)) and ent:GetPhysicsObjectNum(trace.PhysicsBone) or IsValid(ent:GetPhysicsObject()) and ent:GetPhysicsObject()
            local isliving = (ent:IsPlayer() or ent:IsNextBot() or ent:IsNPC())
            local physcalc = dir * (propscaledforce and phys and phys:GetMass() or ply:GetPhysicsObject():GetMass()) ^ 2
            local force = physcalc * physforce
            local ragf = physcalc * ragforce
            if damagebyspeed then
                local speed1, speed2 = ent:GetVelocity():Length() > 0 and ent:GetVelocity():Length(), velocity > 0 and velocity
                local formula, formula2 = damage * (ent:GetVelocity():GetNormalized() - trace.Normal):Length() , damage * (ply:GetVelocity():GetNormalized() + trace.Normal):Length()
                damage = (formula + formula2) * 0.5 * damagebyspeedmult
            end

            local isDoor = (ent:GetClass() == "prop_door_rotating" or ent:GetClass() == "func_door" or ent:GetClass() == "func_door_rotating")
            local lowHp = false
            if isDoor and ent:GetMaxHealth() > 0 and (ent:Health() / ent:GetMaxHealth()) < 0.2 then
                lowHp = true
            end

            if doorscaledamage and isDoor then
                if doorlastdamageunlock and lowHp then
                    damage = damage * 0.5
                else
                    damage = damage * doorscaledamage
                end
            end

            local kickinfo = DamageInfo()
            kickinfo:SetDamage(damage)
            kickinfo:SetDamageForce((ent:IsRagdoll() or isliving) and ragf or force)
            kickinfo:SetAttacker(ply)
            kickinfo:SetInflictor(ply)
            kickinfo:SetDamagePosition(trace.HitPos)
            kickinfo:SetReportedPosition(trace.StartPos)
            kickinfo:SetDamageType(DMG_CLUB)
            kickinfo:SetDamageCustom(67)

            if hitshake then
                util.ScreenShake(trace.HitPos, 5, 100, 0.5, 100)
            end

            local surfprop = util.GetSurfaceData(trace.SurfaceProps) or util.GetSurfaceData(0)
            local sndpos = trace.HitPos + trace.HitNormal * 4
            if string.find(surfprop.name, "flesh") or string.find(surfprop.name, "antlion") then
                sound.Play("foot.kickbody", sndpos, 65, math.random(90, 110), 1)
            else
                MFEffect(trace, surfprop)
                sound.Play("foot.kickwall", sndpos, 65, math.random(90, 110), 1)
            end

            sound.Play(surfprop.impactSoftSound, sndpos, 65, math.random(90, 110), 1)

            if string.find(engine.ActiveGamemode(), "nzombies") then
                if ent:IsNextBot() or ent:IsNPC() then
                    kickinfo:SetDamageForce(ragf)
                    ent:TakeDamageInfo(kickinfo)
                elseif entclass == "func_breakable_surf" then
                    ent:Fire("Shatter", "0.5 0.5 256")
                end
            end

            local pushbackamt = aimvector * -pushback

            if movetypo[ent:GetMoveType()] then
                ent:SetPhysicsAttacker(ply, 3)
                if ent:IsPlayerHolding() then
                    if heldpropkick then
                        ent:ForcePlayerDrop()
                    end
                    if ent:GetPhysicsAttacker() == ply and not trollphysics then
                        pushbackamt = vector_origin
                    end
                elseif parry and (ent:GetVelocity() + ent:GetBaseVelocity()):LengthSqr() >= 10000 then
                    kickinfo:SetDamage(0)
                    dir = ply:GetAimVector()
                    if phys then
                        if ent:GetInternalVariable("m_bLaunched") then
                            phys:ClearGameFlag(FVPHYSICS_NO_NPC_IMPACT_DMG)
                            phys:AddGameFlag(FVPHYSICS_DMG_DISSOLVE+FVPHYSICS_HEAVY_OBJECT)
                        end
                        phys:SetVelocity(dir * phys:GetVelocity():Length() * parrymult)
                        phys:SetAngleVelocity(-phys:GetAngleVelocity())
                    else
                        ent:SetVelocity(dir * (ent:GetVelocity():Length() + ent:GetBaseVelocity():Length()))
                    end
                    if not isliving then ent:SetOwner(ply) end
                end
            end

            if not ent:IsWorld() then
                ent:TakeDamageInfo(kickinfo)
                if math.random(1, 100) <= playerragdollchance then
                    if ent:IsPlayer() then
                        ent:StartRagdolling(0, 50)
                        ent.IsRagStanding = false
                    elseif ent:IsRagdoll() and IsValid(ent.Owner) and ent.Owner:IsPlayer() then
                        ent.Owner.IsRagStanding = false
                    end
                end
            end

            ply:SetVelocity(pushbackamt)

            if string.find(entclass, "button") then
                ent:Use(ply)
            elseif entclass == "func_breakable_surf" then
                ent:Fire("Shatter", "0.5 0.5 256")
            elseif doorkick and DoorClasses[(IsValid(ent:GetMoveParent()) and ent:GetMoveParent():GetClass()) or entclass] then
                local door = IsValid(ent:GetMoveParent()) and ent:GetMoveParent() or ent
                local class = door:GetClass()
                local slider = class == "func_door"
                if not ( (string.find(class, "func") and door:HasSpawnFlags(256+1024)) or (string.find(class, "prop") and not door:HasSpawnFlags(32768)) or doorkickany ) then return end
                ply.oldname = ply:GetName()
                ply:SetName("kickingpl" .. ply:EntIndex())

                if unlock and door:GetInternalVariable("m_bLocked") then
                    door:SetSaveValue("m_bLocked", false)
                end

                if (blowdoorlocked or not door:GetInternalVariable("m_bLocked")) and (not slider or blowdoorsliding) and (blowdoorchance and math.Rand(0, 100) <= blowdoorchance) then
                    local prop = MFDoorBust(door, ent)
                    if prop then
                        prop:SetPhysicsAttacker(ply, 3)
                        prop:GetPhysicsObject():ApplyForceOffset(physcalc * blowdoorforce, LerpVector(0.75,pos,prop:WorldSpaceCenter())+offvec)
                    end
                end

                local oldSpeed, oldDist = door:GetInternalVariable("m_flSpeed") or 100, door:GetInternalVariable("m_flDistance") and door:GetInternalVariable("m_flDistance") or 90
                local oldDirection = door:GetInternalVariable("opendir")
                local oldDmg = door:GetInternalVariable("dmg")
                local flags = door:GetSpawnFlags()

                if (not (door:GetInternalVariable("m_toggle_state") == 0 or door:GetInternalVariable("m_eDoorState") == 2) and not door:GetInternalVariable("m_bLocked")) or (doorlastdamageunlock and lowHp) then
                    sound.Play("MetalVent.ImpactHard", door:WorldSpaceCenter(), 80, math.random(90, 110), 1)
                    local snd = CreateSound(door, "foot.kickdoor")
                    snd:Play()
                    snd:FadeOut(not slider and 1 or 0)
                    door:Fire("unlock")
                    door:SetKeyValue("speed", oldSpeed*5)
                    door:Fire("close", "kickingpl" .. ply:EntIndex())
                    if string.find(class, "func") then
                        if not door:GetNWBool("dooropened") then
                            door:Use(ply)
                            door:SetNWBool("dooropened", true)
                        end
                        if door:HasSpawnFlags(18) then
                            door:SetSaveValue("m_vecAngle2", door:HasSpawnFlags(2) and -door:GetInternalVariable("m_vecAngle2") or door:GetInternalVariable("m_vecAngle2"))
                            door:SetKeyValue("spawnflags", flags - (door:HasSpawnFlags(16) and 16 or 0))
                            timer.Simple(0.015, function()
                                door:SetKeyValue("spawnflags", flags)
                                door:SetSaveValue("m_vecAngle2", door:HasSpawnFlags(2) and -door:GetInternalVariable("m_vecAngle2") or door:GetInternalVariable("m_vecAngle2"))
                            end)
                        end
                        door:Fire("open", "kickingpl" .. ply:EntIndex())
                        door:SetKeyValue("speed", oldSpeed)
                    else
                        door:SetKeyValue("opendir", 0)
                        door:Fire("openawayfrom", "kickingpl" .. ply:EntIndex())
                        timer.Simple(((oldDist / oldSpeed)), function()
                            if not IsValid(door) then return end
                            door:SetKeyValue("spawnflags", flags)
                            door:SetKeyValue("speed", oldSpeed)
                            door:SetKeyValue("opendir", oldDirection)
                            if timer.Exists("MFDoorTimer"..door:EntIndex()) then return end
                            door.MFKickedDown = false
                        end)
                    end
                    door.MFKickedDown = true
                end

                if doordamage then
                    door:SetKeyValue("dmg", oldSpeed * 0.5)
                    timer.Simple(0.25, function()
                        if not IsValid(door) then return end
                        door:SetKeyValue("dmg", oldDmg or 0)
                    end)
                end
            end
        end
        ply:LagCompensation(false)
    end

    hook.Add( "AcceptInput", "MFBlockInput", function( ent, name, activator, caller, data )
        if DoorClasses[ent:GetClass()] and (activator:IsPlayer() or activator:IsNPC() or activator:IsNextBot()) and ent.MFKickedDown then
            return true
        end
    end )

    function MFDoorBust(door, ent)
        local rety = door:GetClass() == "prop_door_rotating" and "returndelay" or "m_flWait"
        local object = door == ent and door or ent
        if IsValid(object:GetPhysicsObject()) then
            local pos = object:GetPos()
            local ang = object:GetAngles()
            local model = object:GetModel()
            local skin = object:GetSkin()
            local bg = object:GetBodygroup(1)
            local rendermode = object:GetRenderMode()
            local renderfx = object:GetRenderFX()
            local color = object:GetColor()
            local resettime = door:GetInternalVariable(rety)
            if resettime != -1 then
                door:SetSaveValue(rety, resettime + doorrespawntime)
            end
            door:SetNotSolid(true)
            door:SetNoDraw(true)

            local prop = ents.Create("prop_physics_multiplayer")
            prop:SetPos(pos)
            prop:SetAngles(ang)
            prop:SetModel(model)
            prop:SetSkin(skin or 0)
            prop:SetBodygroup(1,bg or 0)
            prop:SetRenderMode(rendermode)
            prop:SetRenderFX(renderfx)
            prop:SetColor(color)
            prop:SetHealth(door:Health())
            if doorgib then
                prop:SetSaveValue("m_takedamage", 1)
                prop:SetMaxHealth(1)
                prop:SetHealth(1)
                if prop:GetInternalVariable("m_iszBreakableModel") != nil then
                    prop:SetSaveValue("m_iBreakableCount", doorgibcount)
                    prop:SetSaveValue("m_iNumBreakableChunks", doorgibcount)
                    prop:SetSaveValue("m_iszBreakableModel", "WoodChunks")
                end
                prop:PrecacheGibs()
                prop:Spawn()
                prop:Fire("SetHealth", 0)
            else
                for k, v in ipairs(door:GetChildren()) do
                    if not IsValid(v:GetModel()) then continue end
                    v:SetNotSolid(true)
                    v:SetNoDraw(true)
                    local extra = ents.Create("prop_dynamic")
                    extra:SetPos(v:GetPos())
                    extra:SetAngles(v:GetAngles())
                    extra:SetModel(v:GetModel())
                    extra:SetSkin(v:GetSkin() or 0)
                    extra:SetBodygroup(1,v:GetBodygroup(1) or 0)
                    extra:SetRenderMode(v:GetRenderMode())
                    extra:SetRenderFX(v:GetRenderFX())
                    extra:SetColor(v:GetColor())
                    extra:SetHealth(v:Health())
                    extra:Spawn()
                    extra:SetParent(prop)
                    extra:SetCollisionGroup(10)
                    extra:SetCollisionGroup(COLLISION_GROUP_WEAPON)
                    extra:PhysicsInit(SOLID_NONE)
                end
            end
            prop:PhysicsInit(SOLID_VPHYSICS)
            prop:SetModelScale(0.95, 0.1)
            prop:Activate()
            prop:SetModelScale(1, 1)
            local snd = CreateSound(prop, "Wood_Box.Break")
            snd:Play()
            snd:FadeOut(1)

            timer.Simple(0, function()
                if not IsValid(prop) then return end
                net.Start("MFDoorBust")
                net.WriteEntity(prop)
                net.Broadcast()
            end)

            timer.Create("MFDoorBust" .. door:EntIndex(), 2, 1, function()
                if not IsValid(prop) or not IsValid(prop:GetPhysicsObject()) then return end
                local phys = prop:GetPhysicsObject()
                prop:SetCollisionGroup(COLLISION_GROUP_WEAPON)
                phys:RecheckCollisionFilter()
            end)

            timer.Create("MFDoorTimer" .. door:EntIndex(), doorrespawntime, 1, function()
                if door:IsValid() then
                    door:SetSaveValue(rety, resettime)
                    for k, v in ipairs(table.Add({[1] = door}, door:GetChildren())) do
                        v:SetNoDraw(false)
                        v:SetRenderMode(2)
                        v:SetRenderFX(24)
                        timer.Simple(1, function()
                            if not v:IsValid() then return end
                            v:SetNotSolid(false)
                            v:SetRenderMode(rendermode)
                            v:SetColor(color)
                            v:SetRenderFX(renderfx)
                        end)
                    end
                    timer.Simple(1, function()
                        door.MFKickedDown = false
                    end)
                end
                if prop:IsValid() then
                    for k, v in ipairs(table.Add({[1] = prop}, prop:GetChildren())) do
                        v:SetRenderMode(2)
                        v:SetRenderFX(24)
                    end
                end

                SafeRemoveEntityDelayed(prop, 1)
            end)
            return IsValid(prop:GetPhysicsObject()) and prop
        end
    end

    local vt = file.Exists("wos/dynabase/registers/wos_gamemode_mur_registers.lua", "LUA")

    local anims = file.Exists("wos/dynabase/registers/wos_gamemode_mur_registers.lua", "LUA")
    local anim1, anim2, anim3, anim4, anim5, anim6, anim7, anim8, anim9, anim10 = 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

    if vt then
        anim1, anim2, anim3, anim4, anim5, anim6, anim7, anim8, anim9, anim10 = 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    end

    function MightyFootEngaged(ply)
        if ply:GetObserverMode() ~= 0 then return end
        local mt = ply:GetMoveType()
        if mt == 10 or not ply:Alive() or ply:IsFrozen() or ply:InVehicle() or IsValid(ply:GetNW2Entity("RD_Ent")) or ply:GetNW2String("SVAnim") != "" or ply:GetNW2Bool("LegBroken") then return false end
        local speed, delay, fast = kickspeed, kickdelay, kickfast
        local rate = (fast and 0.3 or 0.75) / speed
        local ct, time = CurTime(), rate + delay
        local dropkicking = (not ply:OnGround() and ply:WaterLevel() < 2) and mt ~= MOVETYPE_LADDER and mt ~= MOVETYPE_NOCLIP
        local anim = anim1

        if anims then
            local pitch = ply:EyeAngles().x

            if dropkicking then
                if pitch > 75 then
                    anim = anim6
                elseif pitch > 45 then
                    anim = anim10
                elseif pitch > 25 then
                    anim = anim8
                else
                    anim = anim2
                end
            elseif ply:Crouching() then
                if pitch > 65 then
                    anim = anim5
                else
                    anim = anim4
                end
            else
                if pitch > 75 then
                    anim = anim3
                elseif pitch > 45 then
                    anim = anim9
                elseif pitch > 25 then
                    anim = anim7
                else
                    anim = anim1
                end
            end
        end

        if ply.MFNextKick and ply.MFNextKick <= ct then
            if ply:GetNW2Float("Stamina") < 20 then return end
            ply:SetNW2Float("Stamina", ply:GetNW2Float("Stamina") - 20)

            ply.MFKickTime = ct
            ply.MFNextKick = ply.MFKickTime + time
            local wep = ply:GetActiveWeapon()
            local stance = "stand"

            if dropkicking then
                stance = "air"
            elseif ply:Crouching() then
                stance = "crouch"
            end

            net.Start("MF_StanceLock")
            net.WriteString(stance)
            net.Send(ply)

            ply:DoCustomAnimEvent(PLAYERANIMEVENT_ATTACK_GRENADE, 670 + anim)
            if kickholster then
                ply:SetActiveWeapon(NULL)
            end

            timer.Simple(0.2 / speed, function()
                if not IsValid(ply) or not ply:Alive() then return end
                ply:ViewPunch(Angle(-10, math.Rand(-2, 2), 0) * viewpunchscale)
                ply:EmitSound("foot.fire")
            end)

            timer.Simple(0.3 / speed, function()
                if not IsValid(ply) or not ply:Alive() then return end
                MFHit(ply)
                if kickholster and IsValid(wep) then
                    ply:SelectWeapon(wep)
                end
            end, ply)
        end
    end

    net.Receive("EngageMF", function(l,ply) MightyFootEngaged(ply) end)

    function MFInitState(ply)
        local time = 0.3 / math.max(kickspeed, 0.0001)
        ply.MFKickTime = 0
        ply.MFNextKick = ply.MFKickTime + time
    end

    hook.Add("PlayerSpawn", "MFInitState", MFInitState)
    hook.Add("PlayerDeath", "MFInitState", MFInitState)

    hook.Add("PostEntityTakeDamage", "CATMFDamageModifiers", function(ent, dinfo, took)
        if not (IsValid(ent) and ((!took and dinfo:GetDamage() == 0) or took) and dinfo:GetDamageCustom() == 67 and ent.GetActiveWeapon) then return end
        if (ent:IsPlayer() and disarmply or (ent:IsNPC() or ent:IsNextBot()) and disarmnpc) and IsValid(ent:GetActiveWeapon()) then
            ent:DropWeapon()
        end
    end)
end

local anims_table = {
    ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND,
    ACT_MP_STAND_MELEE,
    ACT_MP_JUMP_MELEE,
    ACT_MP_ATTACK_STAND_MELEE_SECONDARY,
    ACT_MP_CROUCH_MELEE,
    ACT_MP_ATTACK_CROUCH_MELEE_SECONDARY,
    ACT_MP_ATTACK_SWIM_MELEE,
    ACT_MP_RUN_MELEE,
    ACT_MP_JUMP_LAND_MELEE,
    ACT_MP_WALK_MELEE,
    ACT_MP_AIRWALK_SECONDARY
}

hook.Add("PlayerSwitchWeapon", "MFEngaged_SwitchBlock", function(ply, old, new)
    if not kickholster then return end
    local ct, speed = CurTime(), 0.3 / math.max(kickspeed, 0.0001)
    if ply.MFKickTime and ply.MFKickTime + speed > ct then
        return true
    end
end)

hook.Add("DoAnimationEvent", "MFEngaged_DoAnim", function(ply, event, data)
    if event == PLAYERANIMEVENT_ATTACK_GRENADE and (data >= 671 and data <= 681) then
        local anim = anims_table[data-670]
        ply:AnimRestartGesture(GESTURE_SLOT_GRENADE, anim, true)
        ply:SetLayerDuration(GESTURE_SLOT_GRENADE, 1 / math.max(kickspeed, 0.0001))
        return ACT_INVALID
    end
end)
