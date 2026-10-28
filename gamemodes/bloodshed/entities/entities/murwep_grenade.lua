AddCSLuaFile()

--
-- База была obj_vj_projectile_base из VJ Base. Её в сборке нет, поэтому класс
-- не регистрировался вовсе: ents.Create отдавал NULL, и граната просто не
-- появлялась — молча, без ошибки в консоли у того, кто её бросил.
--
-- Своей базе тут делать нечего: весь жизненный цикл (Initialize, Think,
-- PhysicsCollide, Explode, OnRemove) класс описывает сам. От VJ ему доставались
-- только физика в Initialize, которую теперь заводим явно, как это делает
-- рабочий bloodshed_flashbang.
--
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Grenade"

game.AddParticles("particles/ac_explosions.pcf")

if SERVER then
    function ENT:Initialize()
        if self.F1 then
            self:SetModel("models/simpnades/w_f1.mdl")
        else
            self:SetModel("models/simpnades/w_m67.mdl")
        end
        self:PhysicsInit(SOLID_VPHYSICS)
        -- Тип движения и солидность раньше выставляла база. Без них граната
        -- висит в воздухе там, где её выпустили из рук.
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
        self.Activated = false

        if !IsValid(self.OwnerTrap) then
            timer.Simple(4, function()
                if !IsValid(self) then return end
                self:Explode()
            end)
        else
            if IsValid(phys) then
                phys:Sleep()
                phys:EnableMotion(false)
            end
            self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
            self:SetUseType(SIMPLE_USE)
            if self.StakeLimit then
                self.Limited = true
            end
        end
    end

    function ENT:Think()
        if self.Activated then return end

        if self.DisarmInProgress then
            if not IsValid(self.DisarmPlayer) or not self.DisarmPlayer:Alive() then
                self.DisarmInProgress = false
                self.DisarmPlayer = nil
            end
            self:NextThink(CurTime())
            return true
        end

        if not IsValid(self.StakeEnt) then
            return
        end

        if self.Limited and self:WorldSpaceCenter():Distance(self.StakeEnt:WorldSpaceCenter()) > self.StakeLimit then
            self:ActivateGrenade()
            return
        end

        local hitEntity
        local pos1 = self:GetPos() + Vector(0, 0, 5)
        local pos2 = self.StakeEnt:GetPos() + Vector(0, 0, 5)
        local tr = util.TraceLine({
            start = pos1,
            endpos = pos2,
            filter = {self, self.OwnerTrap, self:GetParent(), self.StakeEnt, self.StakeEnt:GetParent()},
            mask = MASK_SOLID
        })
        if tr.Hit and IsValid(tr.Entity) then
            hitEntity = tr.Entity
        end

        if IsValid(hitEntity) then
            local shouldActivate = false
            if hitEntity:IsPlayer() then
                if hitEntity:Alive() and hitEntity:Health() > 0 then
                    shouldActivate = true
                end
            elseif MuR.IsAI(hitEntity) then
                if hitEntity:Health() > 0 and MuR.Gamemode != 14 then
                    shouldActivate = true
                end
            else
                local phys = hitEntity:GetPhysicsObject()
                if IsValid(phys) and phys:IsMotionEnabled() then
                    shouldActivate = true
                end
            end

            if MuR:TrapIgnoresVictim(self, hitEntity) then
                shouldActivate = false
            end

            if shouldActivate then
                self:ActivateGrenade()
            end
        end

        self:NextThink(CurTime())
        return true
    end

    function ENT:Use(activator, caller)
        local ply = IsValid(activator) and activator:IsPlayer() and activator or caller
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if self.Activated or not IsValid(self.OwnerTrap) then return end
        if self.DisarmInProgress then return end
        if ply:GetPos():DistToSqr(self:GetPos()) > (120 * 120) then return end

        self.DisarmInProgress = true
        self.DisarmPlayer = ply
        self.DisarmStart = CurTime()

        net.Start("MuR.TripwireMinigame")
        net.WriteEntity(self)
        net.Send(ply)

        timer.Create("MuR_TripwireDisarm_" .. self:EntIndex(), 6, 1, function()
            if not IsValid(self) then return end
            if self.DisarmInProgress then
                self.DisarmInProgress = false
                self.DisarmPlayer = nil
            end
        end)
    end

    function ENT:PhysicsCollide(data, phys)
        if data.Speed > 50 then
            self:EmitSound(")murdered/weapons/grenade/m67_bounce_01.wav", 60, math.random(80,120))
            sound.EmitHint(SOUND_DANGER, self:GetPos(), 400, 1, self)
        end
    end

    function ENT:OnTakeDamage(dmg)
        if self.Activated then return end
        if dmg:GetDamage() > 5 then
            self:Explode()
        end
    end

    function ENT:ActivateGrenade()
        if self.Activated then return end
        self.Activated = true
        if IsValid(self.StakeConst) then
            self.StakeConst:Remove()
            self:EmitSound("weapons/tripwire/ropeshoot.wav", 60, math.random(80,120))
        end
        timer.Simple(0.1, function()
            if !IsValid(self) then return end
            self:EmitSound(")murdered/weapons/grenade/f1_pinpull.wav", 60, math.random(80,120))
        end)
        timer.Simple(1, function()
            if !IsValid(self) then return end
            self:StopSound("weapons/tripwire/ropeshoot.wav")
            self:Explode()
        end)
    end

    function ENT:Bullets()
        local count, det = 14, 0
        timer.Create("grenbullets"..self:EntIndex(), 0.0001, count, function()
            if !IsValid(self) then return end
            det = det + 1
            for i = 1, 20 do
                local dir = VectorRand(-1,1)
                if self:OnGround() and dir.z < 0 then
                    dir.z = math.Rand(0,1)
                end
                local bullet = {}
                bullet.Attacker = self.PlayerOwner or game.GetWorld()
                bullet.Damage = 50
                bullet.Force = 5
                bullet.Num = 1
                bullet.Src = self:WorldSpaceCenter()
                bullet.Dir = dir
                bullet.Spread = Vector(0, 0, 0)
                bullet.Tracer = 1
                bullet.TracerName = "Tracer"
                bullet.IgnoreEntity = self

                self:FireBullets(bullet)
            end
            if det == count then
                SafeRemoveEntityDelayed(self, 0.2)
            end
        end)
    end

    function ENT:Explode()
        self.Activated = true
        local num = 1
        if self.SuperGrenade then
            num = math.random(10,100)
        end
        for i=1, num do
            timer.Simple(i/10, function()
                if !IsValid(self) then return end
                self:EmitSound(")murdered/weapons/other/ied_detonate_dist_0"..math.random(1,3)..".wav", 120, math.random(90,110))
                util.ScreenShake(self:GetPos(), 25, 25, 3, 2000)
                ParticleEffect("AC_grenade_explosion", self:GetPos(), Angle(0,0,0))
                ParticleEffect("AC_grenade_explosion_air", self:GetPos(), Angle(0,0,0))
                util.Decal("Scorch", self:GetPos(), self:GetPos()-Vector(0,0,8), self)
                local att = self
                if IsValid(self.PlayerOwner) then
                    att = self.PlayerOwner
                end
                if self.F1 then
                    util.BlastDamage(att, att, self:GetPos(), 400, 200)
                    MuR:ApplyConcussion(self:GetPos(), "grenade_f1", att)
                else
                    util.BlastDamage(att, att, self:GetPos(), 300, 250)
                    MuR:ApplyConcussion(self:GetPos(), "grenade_m67", att)
                end
                MakeExplosionReverb(self:GetPos())
                if i == num then
                    self:Bullets()
                end
            end)
        end
    end

    function ENT:OnRemove()
        timer.Remove("MuR_TripwireDisarm_" .. self:EntIndex())
    end
end
