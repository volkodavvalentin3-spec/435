AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("MuR_DroneCam")
util.AddNetworkString("MuR_DroneLost")

local rotorSounds = {
    "ambient/machines/spin_loop.wav",
    "ambient/machines/machine1_hit1.wav"
}

local damageSounds = {
    "physics/metal/metal_box_impact_bullet1.wav",
    "physics/metal/metal_box_impact_bullet2.wav",
    "physics/metal/metal_box_impact_bullet3.wav",
    "physics/metal/metal_computer_impact_bullet1.wav",
    "physics/metal/metal_computer_impact_bullet2.wav"
}

local startupSounds = {
    "buttons/button9.wav",
    "buttons/button17.wav"
}

function ENT:Initialize()
    self:SetModel("models/murdered/weapons/drone_ex.mdl")
    self:ResetSequence("idle")
    self:SetHealth(self.HealthCount)
    self:SetGravity(0)
    self.Velo = {x = 0, y = 0, z = 0}
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self.MultSpeed = 200
    self.MaxSpeed = 300
    self.BoostSpeed = 1250
    self.MaxPitch = 18
    self.MaxRoll = 22
    self.LinearDrag = 0.04
    self.GrenadeDelay = CurTime() + 5
    self.TakeDamageWall = 0
    self.DeltaTime = 0
    self.LastBoostSound = 0
    self.LastWindSound = 0
    self:SetNW2Float('RemoveTime', CurTime() + self.BatteryCount)

    self:EmitSound(startupSounds[math.random(#startupSounds)], 60, 100, 0.5)

    if CreateSound then
        self.RotorSound = CreateSound(self, rotorSounds[1])
        if self.RotorSound then
            self.RotorSound:PlayEx(0.2, 80)
        end

        self.WindSound = CreateSound(self, "ambient/wind/wind_snippet2.wav")
        if self.WindSound then
            self.WindSound:PlayEx(0, 100)
        end
    end

    timer.Simple(0.1, function()
        if not IsValid(self) then return end
        local ply = self:GetCreator()
        if not IsValid(ply) then return end
        ply.ControlDrone = self
        net.Start("MuR_DroneCam")
        net.WriteEntity(self)
        net.Send(ply)
    end)
end

function ENT:OnRemove()
    if self.RotorSound then
        self.RotorSound:Stop()
    end
    if self.WindSound then
        self.WindSound:Stop()
    end
    self:StopSound("ambient/machines/spin_loop.wav")
    self:StopSound("ambient/wind/wind_snippet2.wav")
    self:StopSound("vehicles/airboat/fan_blade_fullthrottle_loop1.wav")
end

function ENT:GetForwardAbs()
    local ang = self:GetAngles()
    ang.x = 0
    ang.z = 0
    return ang:Forward()
end

function ENT:GetForwardAbs()
    local ang = self:GetAngles()
    ang.x = 0
    ang.z = 0
    return ang:Forward()
end

function ENT:GetRightAbs()
    local ang = self:GetAngles()
    ang.x = 0
    ang.z = 0
    return ang:Right()
end

function ENT:GetUpAbs()
    local ang = self:GetAngles()
    ang.x = 0
    ang.z = 0
    return ang:Up()
end

function ENT:Think()
    local ply = self:GetCreator()
    if not IsValid(ply) then
        self:Remove()
    else
        local phys = self:GetPhysicsObject()
        local mu = self.MultSpeed
        local ms = self.MaxSpeed
        local deltatime = self.DeltaTime
        local vel = phys:GetVelocity()
        local pos = self:GetPos()
        local ang = ply:EyeAngles().y
        local sang = Angle(0, ang, 0)
        ply:SetActiveWeapon(nil)
        local trace = {start = self:GetPos(), endpos = self:GetPos(), filter = self}
        local tr = util.TraceEntity(trace, self)

        if self:GetNW2Bool('Boost') then
            local fwd = self:GetForward()
            phys:SetVelocityInstantaneous(fwd * self.Velo.x)
        else
            if tr.Hit then
                phys:SetVelocityInstantaneous((self:GetForwardAbs() * self.Velo.x + self:GetRightAbs() * self.Velo.y + self:GetUpAbs() * self.Velo.z) / 2)
                if self.TakeDamageWall < CurTime() then
                    self:TakeDamage(1)
                    self.TakeDamageWall = CurTime() + 0.2
                end
            else
                phys:SetVelocityInstantaneous(self:GetForwardAbs() * self.Velo.x + self:GetRightAbs() * self.Velo.y + self:GetUpAbs() * self.Velo.z + Vector(0,0,15))
            end
        end

        local ratioX = math.Clamp(self.Velo.x / ms, -1, 1)
        local ratioY = math.Clamp(self.Velo.y / ms, -1, 1)
        local targetPitch = ratioX * self.MaxPitch
        local targetRoll = ratioY * self.MaxRoll
        sang = Angle(targetPitch, ang, targetRoll)

        local b = {}
        b.secondstoarrive = 1
        b.pos = self:GetPos()
        b.angle = sang
        b.maxangular = 120
        b.maxangulardamp = 50
        b.maxspeed = 1000
        b.maxspeeddamp = 150
        b.dampfactor = 0.4
        b.teleportdistance = 0
        b.deltatime = CurTime() - self.DeltaTime
        phys:ComputeShadowControl(b)

        local tick = FrameTime()
        if ply:KeyDown(IN_FORWARD) or self:GetNW2Bool('Boost') then
            if self:GetNW2Bool('Boost') then
                self.Velo.x = math.Clamp(self.Velo.x + tick * mu * 2, -ms, self.BoostSpeed)
            else
                self.Velo.x = math.Clamp(self.Velo.x + tick * mu, -ms, ms)
            end
        elseif ply:KeyDown(IN_BACK) then
            self.Velo.x = math.Clamp(self.Velo.x - tick * mu, -ms, ms)
        end
        if ply:KeyDown(IN_MOVELEFT) then
            self.Velo.y = math.Clamp(self.Velo.y - tick * mu, -ms, ms)
        elseif ply:KeyDown(IN_MOVERIGHT) then
            self.Velo.y = math.Clamp(self.Velo.y + tick * mu, -ms, ms)
        end
        if ply:KeyDown(IN_DUCK) then
            self.Velo.z = math.Clamp(self.Velo.z - tick * mu, -ms, ms)
        elseif ply:KeyDown(IN_SPEED) then
            self.Velo.z = math.Clamp(self.Velo.z + tick * mu, -ms, ms)
        end

        local drag = 1 - math.Clamp(self.LinearDrag * tick, 0, 0.2)
        self.Velo.x = self.Velo.x * drag
        self.Velo.y = self.Velo.y * drag
        self.Velo.z = self.Velo.z * (0.98 * drag)

        if not ply:KeyDown(IN_FORWARD) and not ply:KeyDown(IN_BACK) and not self:GetNW2Bool('Boost') then
            if self.Velo.x > 5 or self.Velo.x < -5 then
                if self.Velo.x > 0 then
                    self.Velo.x = math.Clamp(self.Velo.x - tick * mu, -ms, ms)
                elseif self.Velo.x < 0 then
                    self.Velo.x = math.Clamp(self.Velo.x + tick * mu, -ms, ms)
                end
            else
                self.Velo.x = 0
            end
        end
        if not ply:KeyDown(IN_SPEED) and not ply:KeyDown(IN_DUCK) then
            if self.Velo.z > 5 or self.Velo.z < -5 then
                if self.Velo.z > 0 then
                    self.Velo.z = math.Clamp(self.Velo.z - tick * mu, -ms, ms)
                elseif self.Velo.z < 0 then
                    self.Velo.z = math.Clamp(self.Velo.z + tick * mu, -ms, ms)
                end
            else
                self.Velo.z = 0
            end
        end
        if not ply:KeyDown(IN_MOVELEFT) and not ply:KeyDown(IN_MOVERIGHT) then
            if self.Velo.y > 5 or self.Velo.y < -5 then
                if self.Velo.y > 0 then
                    self.Velo.y = math.Clamp(self.Velo.y - tick * mu, -ms, ms)
                elseif self.Velo.y < 0 then
                    self.Velo.y = math.Clamp(self.Velo.y + tick * mu, -ms, ms)
                end
            else
                self.Velo.y = 0
            end
        end

        local wasBoost = self:GetNW2Bool('Boost')
        self:SetNW2Bool('Boost', ply:KeyDown(IN_ATTACK))
        self:SetNW2Bool('Light', ply:KeyDown(IN_ATTACK2))

        if ply:KeyDown(IN_ATTACK) and not wasBoost then
            self:EmitSound("vehicles/airboat/fan_blade_fullthrottle_loop1.wav", 70, 150, 0.4)
            self.LastBoostSound = CurTime()
        elseif not ply:KeyDown(IN_ATTACK) and wasBoost then
            self:StopSound("vehicles/airboat/fan_blade_fullthrottle_loop1.wav")
        end

        if self.RotorSound then
            local spd = phys:GetVelocity():Length()
            local load = math.Clamp((math.abs(self.Velo.x) + math.abs(self.Velo.y) + math.abs(self.Velo.z)) / (self.BoostSpeed * 0.6), 0, 1)
            local timeLeft = math.max(self:GetNW2Float('RemoveTime') - CurTime(), 0)
            local battFrac = math.Clamp(timeLeft / self.BatteryCount, 0, 1)
            local basePitch = 80 + 45 * load + math.Clamp(spd * 0.025, 0, 35)
            local baseVol = 0.15 + 0.35 * load
            basePitch = basePitch * (0.85 + 0.15 * battFrac)

            if battFrac < 0.15 then
                basePitch = basePitch + math.sin(CurTime() * 15) * 5
            end

            self.RotorSound:ChangePitch(math.Clamp(basePitch, 55, 180), 0.08)
            self.RotorSound:ChangeVolume(math.Clamp(baseVol, 0.05, 0.55), 0.08)
        end

        if self.WindSound then
            local spd = phys:GetVelocity():Length()
            local windVol = math.Clamp(spd / 800, 0, 0.4)
            local windPitch = 80 + math.Clamp(spd * 0.05, 0, 40)
            self.WindSound:ChangeVolume(windVol, 0.15)
            self.WindSound:ChangePitch(windPitch, 0.15)
        end

        if self:Health() <= 0 then
            net.Start("MuR_DroneLost")
            net.Send(ply)
            self:Explode()
        end
        if self:GetNW2Float('RemoveTime') < CurTime() or not ply:Alive() or ply:GetSVAnim() ~= "" then
            net.Start("MuR_DroneLost")
            net.Send(ply)
            self:EmitSound("ambient/machines/machine1_hit2.wav", 70, 80, 0.6)
            self:Remove()
        elseif (ply:KeyDown(IN_RELOAD) and ply:GetPos():DistToSqr(self:GetPos()) < 50000) then
            ply:GiveWeapon("mur_drone")
            ply:SelectWeapon("mur_drone")
            self:EmitSound("buttons/button14.wav", 60, 100, 0.5)
            self:Remove()
        end
        self.DeltaTime = CurTime()
        self:NextThink(CurTime())
        return true
    end
end

function ENT:PhysicsCollide(col)
    if self.Velo.x > self.MaxSpeed and self:GetNW2Bool('Boost') then
        self:EmitSound("physics/metal/metal_solid_impact_hard"..math.random(1,5)..".wav", 80, 100, 0.8)
        self:TakeDamage(self:Health())
    end
end

function ENT:Explode()
    local explosion = ents.Create("env_explosion")
    explosion:SetPos(self:GetPos())
    explosion:Spawn()
    explosion:SetKeyValue("iMagnitude", "200")
    explosion:Fire("Explode", 0, 0)
    self:EmitSound("ambient/explosions/explode_4.wav", 100, 100, 1)
    self:Remove()
end

function ENT:OnTakeDamage(dmgt)
    local dmg = dmgt:GetDamage()
    local att = dmgt:GetAttacker()
    self:SetHealth(self:Health() - dmg)
    if IsValid(self:GetCreator()) then
        self:GetCreator():ViewPunch(AngleRand(-1, 1))
        local snd = damageSounds[math.random(#damageSounds)]
        self:EmitSound(snd, 75, math.random(90, 110))

        if self:Health() < self.HealthCount * 0.3 and math.random() < 0.3 then
            self:EmitSound("ambient/machines/machine1_hit1.wav", 65, math.random(120, 140), 0.4)
        end
    end
end

hook.Add("SetupPlayerVisibility", "GpincDroneCam", function(ply, viewEntity)
    local drone = ply.ControlDrone
    if IsValid(drone) then
        AddOriginToPVS(drone:GetPos())
    end
end)
