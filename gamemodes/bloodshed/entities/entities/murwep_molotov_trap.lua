AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Molotov Trap"
ENT.Spawnable = false

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/murdered/weapons/w_molotov.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:Sleep()
            phys:EnableMotion(false)
        end

        self.Activated = false
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
        self:SetUseType(SIMPLE_USE)

        if self.StakeLimit then
            self.Limited = true
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

        if not IsValid(self.StakeEnt) then return end

        if self.Limited and self:WorldSpaceCenter():Distance(self.StakeEnt:WorldSpaceCenter()) > self.StakeLimit then
            self:ActivateTrap()
            return
        end

        local pos1 = self:GetPos() + Vector(0, 0, 5)
        local pos2 = self.StakeEnt:GetPos() + Vector(0, 0, 5)
        local tr = util.TraceLine({
            start = pos1,
            endpos = pos2,
            filter = {self, self.OwnerTrap, self:GetParent(), self.StakeEnt, self.StakeEnt:GetParent()},
            mask = MASK_SOLID
        })

        local hitEntity = tr.Hit and IsValid(tr.Entity) and tr.Entity or nil

        if IsValid(hitEntity) then
            local shouldActivate = false

            if hitEntity:IsPlayer() then
                shouldActivate = hitEntity:Alive() and hitEntity:Health() > 0
            elseif MuR.IsAI(hitEntity) then
                shouldActivate = hitEntity:Health() > 0 and MuR.Gamemode != 14
            else
                local phys = hitEntity:GetPhysicsObject()
                shouldActivate = IsValid(phys) and phys:IsMotionEnabled()
            end

            if MuR:TrapIgnoresVictim(self, hitEntity) then
                shouldActivate = false
            end

            if shouldActivate then
                self:ActivateTrap()
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
            self.DisarmInProgress = false
            self.DisarmPlayer = nil
        end)
    end

    function ENT:OnTakeDamage(dmg)
        if self.Activated then return end
        if dmg:GetDamage() > 5 then
            self:ActivateTrap()
        end
    end

    function ENT:ActivateTrap()
        if self.Activated then return end
        self.Activated = true

        if IsValid(self.StakeConst) then
            self.StakeConst:Remove()
            self:EmitSound("weapons/tripwire/ropeshoot.wav", 60, math.random(80, 120))
        end

        timer.Simple(0.1, function()
            if not IsValid(self) then return end
            self:StopSound("weapons/tripwire/ropeshoot.wav")
            self:Ignite2()
        end)
    end

    function ENT:Ignite2()
        local pos = self:GetPos()
        local owner = IsValid(self.PlayerOwner) and self.PlayerOwner or self

        local fire = ents.Create("bloodshed_molotov")
        if IsValid(fire) then
            fire:SetPos(pos + Vector(0, 0, 4))
            fire:SetAngles(self:GetAngles())
            fire:SetOwner(owner)
            fire:Spawn()
            fire:Activate()
            fire.Armed = true

            local trace = util.TraceLine({
                start = pos + Vector(0, 0, 4),
                endpos = pos - Vector(0, 0, 64),
                filter = {self, fire},
                mask = MASK_SOLID
            })

            fire:Explode(trace.Hit and trace.HitPos or pos, trace.Hit and trace.HitNormal or Vector(0, 0, 1))
        end

        SafeRemoveEntity(self)
    end

    function ENT:OnRemove()
        timer.Remove("MuR_TripwireDisarm_" .. self:EntIndex())
    end
else
    function ENT:Draw()
        self:DrawModel()
    end
end
