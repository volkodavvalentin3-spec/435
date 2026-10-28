AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Trap"
ENT.Author = "Author"
ENT.Category = "Traps"
ENT.Spawnable = false
ENT.AdminSpawnable = false

if CLIENT then
    function ENT:Draw()
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        if self:GetIsOpen() then
            self:SetColor(Color(255, 255, 255, 75))
            self:DrawModel()
        else
            self:SetColor(Color(255, 255, 255, 255))
            self:DrawModel()
        end
    end
end

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "IsOpen")
end

function ENT:Initialize()
    if SERVER then
        self:SetModel("models/murdered/traps/trap.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:SetIsOpen(true)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        self.NextTrigger = 0
    end
end

function ENT:CheckVis(pos, ent)
    local p1, p2 = self:WorldSpaceCenter()+self:GetUp()*4, pos + Vector(0,0,2)
    local tr = util.TraceLine({
        startpos = p1,
        endpos = p2,
        filter = {self, ent},
        mask = MASK_SOLID,
        ignoreworld = true,
    })
    return !tr.Hit
end

local TRIGGER_RADIUS = 28

local OBJECT_SPEED = 45

local OBJECT_MASS = 3

function ENT:IsTriggeringObject(ent)
    if not IsValid(ent) or ent == self then return false end
    if ent:IsPlayer() or MuR.IsAI(ent) or ent:IsWeapon() then return false end
    if ent:GetParent() == self or ent:GetOwner() == self then return false end

    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return false end
    if phys:GetMass() < OBJECT_MASS then return false end

    local relative = phys:GetVelocity() - self:GetVelocity()
    if relative:LengthSqr() < OBJECT_SPEED * OBJECT_SPEED then return false end

    return self:CheckVis(ent:WorldSpaceCenter(), ent)
end

function ENT:SpringOnObject(ent)
    self:SetModel("models/murdered/traps/trap_close.mdl")
    self:SetIsOpen(false)
    self:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 60)

    local phys = IsValid(ent) and ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(phys:GetVelocity() * 0.2 + Vector(0, 0, 120))
    end
end

function ENT:Think()
    if SERVER and self:GetIsOpen() then
        local object

        for _, victim in ipairs(ents.FindInSphere(self:WorldSpaceCenter(), TRIGGER_RADIUS)) do
            local isTarget = false
            if victim:IsPlayer() then
                isTarget = victim:Alive() and not MuR:TrapIgnoresVictim(self, victim)
            elseif MuR.IsAI(victim) then
                isTarget = victim:Health() > 0 and not MuR:TrapIgnoresVictim(self, victim)
            end

            if isTarget then
                local _, pos = self:GetClosestLegBone(victim)
                if self:CheckVis(pos, victim) then
                    self:TriggerTrap(victim)
                    object = nil
                    break
                end
            elseif not object and self:IsTriggeringObject(victim) then
                object = victim
            end
        end

        if IsValid(object) then
            self:SpringOnObject(object)
        end
    end
    self:NextThink(CurTime() + 0.1)
    return true
end

local LEG_BONES = {
    "ValveBiped.Bip01_L_Foot",
    "ValveBiped.Bip01_R_Foot",
    "ValveBiped.Bip01_L_Calf",
    "ValveBiped.Bip01_R_Calf"
}

local ARM_BONES = {
    "ValveBiped.Bip01_L_Hand",
    "ValveBiped.Bip01_R_Hand",
    "ValveBiped.Bip01_L_Forearm",
    "ValveBiped.Bip01_R_Forearm"
}

local ARM_PRIORITY = 0.3

function ENT:GetClosestLegBone(ply)
    local fallbackBone = math.random(0, 1) == 1 and "ValveBiped.Bip01_R_Foot"
        or "ValveBiped.Bip01_L_Foot"

    if not IsValid(ply) then return fallbackBone, self:GetPos() end

    if ply:IsPlayer() and IsValid(ply:GetRD()) then
        ply = ply:GetRD()
    end

    ply:SetupBones()

    local trapPos = self:GetPos()

    local function nearest(list)
        local bestBone, bestDist

        for _, boneName in ipairs(list) do
            local boneID = ply:LookupBone(boneName)
            if boneID then
                local bonePos = ply:GetBonePosition(boneID)
                if bonePos then
                    local dist = trapPos:DistToSqr(bonePos)
                    if not bestDist or dist < bestDist then
                        bestBone, bestDist = boneName, dist
                    end
                end
            end
        end

        return bestBone, bestDist
    end

    local legBone, legDist = nearest(LEG_BONES)
    local armBone, armDist = nearest(ARM_BONES)

    local bone = legBone or fallbackBone

    if armBone and armDist and (not legDist or armDist < legDist * ARM_PRIORITY) then
        bone = armBone
    end

    local boneID = ply:LookupBone(bone)
    local bonePos = boneID and ply:GetBonePosition(boneID)

    return bone, bonePos or ply:GetPos()
end

function ENT:TriggerTrap(ply)
    if not IsValid(ply) then return end

    if not ply:IsPlayer() then
        self:SetModel("models/murdered/traps/trap_close.mdl")
        self:SetIsOpen(false)
        self:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 60)

        local dmg = DamageInfo()
        dmg:SetDamage(35)
        dmg:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_SLASH)
        ply:TakeDamageInfo(dmg)

        if ply.ProcessWound then
            ply:ProcessWound("leg", 35)
        end
        if ply.AddSuppression then
            ply:AddSuppression(40)
        end
        return
    end

    local rg = ply:GetRD()
    if IsValid(rg) then
        local bone = self:GetClosestLegBone(rg)
        ply.DeathBlowBone = {bone, true}
        ply:BreakRagdollBone()
    else
        local rag = ply:StartRagdolling()
        if IsValid(rag) then
            local bone = self:GetClosestLegBone(rag)
            ply.DeathBlowBone = {bone, true}
        else
            ply:TakeDamage(50, self:GetOwner(), self)
        end
    end

    self:SetModel("models/murdered/traps/trap_close.mdl")
    self:SetIsOpen(false)

    self:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 60)
end

function ENT:Use(activator, caller)
    if not IsValid(caller) or not caller:IsPlayer() then return end

    if self:GetIsOpen() then
        if self.DisarmInProgress then return end
        if caller:GetPos():DistToSqr(self:GetPos()) > (120 * 120) then return end

        self.DisarmInProgress = true
        self.DisarmPlayer = caller

        net.Start("MuR.TripwireMinigame")
        net.WriteEntity(self)
        net.Send(caller)

        timer.Create("MuR_TrapDisarm_" .. self:EntIndex(), 6, 1, function()
            if IsValid(self) then
                self.DisarmInProgress = false
                self.DisarmPlayer = nil
            end
        end)
        return
    end

    self:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 60)
    caller:GiveWeapon("mur_beartrap")
    self:Remove()
end
