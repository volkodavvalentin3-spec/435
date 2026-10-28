SWEP.PrintName = MuR.Language["mur_entity_abilities_name"]
SWEP.Author = "Hari"
SWEP.Instructions = MuR.Language["mur_entity_abilities_instr"]

SWEP.Spawnable = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false

SWEP.Slot = 0
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

function SWEP:Initialize()
    self:SetHoldType("normal")
    self.HeldObject = nil
    self.HeldPhys = nil
    self.HeldRagdoll = nil
end

function SWEP:Deploy()
    return true
end

function SWEP:Holster()
    if SERVER then
        self:DropHeldObject()
        self:DropHeldRagdoll()
    end
    return true
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + 0.5)

    local ply = self:GetOwner()
    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 800,
        filter = {ply, self.HeldObject, self.HeldRagdoll}
    })

    if IsValid(self.HeldObject) then
        self:ThrowObject()
        self:SetNextPrimaryFire(CurTime() + 1)
        return
    end

    if not tr.Hit then return end
    local ent = tr.Entity

    if not IsValid(ent) then return end
    local dist = ply:GetPos():Distance(ent:GetPos())

    if (ent:IsPlayer() or MuR.IsAI(ent)) and dist < 800 then
        MuR:EntityAbility(ply, "power_strike", ent)
        self:SetNextPrimaryFire(CurTime() + 5)
        return
    end

    if (ent:GetClass() == "func_door" or ent:GetClass() == "prop_door_rotating") and dist < 800 then
        ent:Fire("Close")
        ent:Fire("Lock")
        ply:EmitSound("doors/door_locked2.wav")
        self:SetNextPrimaryFire(CurTime() + 2)
        return
    end

    if ent:GetClass() == "prop_physics" then
        self:GrabObject(ent, tr.HitPos)
        return
    end

    if ent:GetClass() == "prop_ragdoll" and dist < 800 then
        self:GrabObject(ent, tr.HitPos)
        return
    end
end

function SWEP:SecondaryAttack()
    if CLIENT then return end

    if self:GetNextSecondaryFire() > CurTime() then return end
    self:SetNextSecondaryFire(CurTime() + 0.5)

    local ply = self:GetOwner()

    if IsValid(self.HeldRagdoll) then
        self:ThrowRagdoll()
        self:SetNextSecondaryFire(CurTime() + 2)
        return
    end

    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 150,
        filter = ply
    })

    if not tr.Hit or not IsValid(tr.Entity) then return end
    local ent = tr.Entity

    if ent:GetClass() == "func_door" or ent:GetClass() == "prop_door_rotating" then
        ent:Fire("Unlock")
        ent:Fire("Open")
        ply:EmitSound("doors/door1_move.wav")
        self:SetNextSecondaryFire(CurTime() + 2)
        return
    end
end

function SWEP:Reload()
end

function SWEP:Think()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    if SERVER and IsValid(self.HeldObject) and IsValid(self.HeldPhys) then
        local targetPos = ply:GetShootPos() + ply:GetAimVector() * 120
        local dir = (targetPos - self.HeldPhys:GetPos())
        local dist = dir:Length()
        dir:Normalize()

        local vel = dir * math.min(dist * 16, 2000)
        self.HeldPhys:SetVelocity(vel)
        self.HeldPhys:Wake()

        local owner = self.HeldObject.Owner
        if IsValid(owner) and owner:IsPlayer() then
            owner.IsRagStanding = false
        end
    elseif SERVER and IsValid(self.HeldObject) then
        self:DropHeldObject()
    end

    if SERVER and IsValid(self.HeldRagdoll) then
        local targetPos = ply:GetShootPos() + ply:GetAimVector() * 60

        self.HeldRagdoll:SetPos(targetPos - Vector(0,0,30))
        self.HeldRagdoll:SetAngles(ply:GetAngles())

        for i = 0, self.HeldRagdoll:GetPhysicsObjectCount() - 1 do
            local phys = self.HeldRagdoll:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                phys:Wake()
                phys:SetVelocity(Vector(0,0,0))
            end
        end
    end
end

function SWEP:GrabObject(ent, pos)
    if not IsValid(ent) then return end

    local closestPhys = nil
    local minDist = 999999

    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        local phys = ent:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            local dist = phys:GetPos():Distance(pos)
            if dist < minDist then
                minDist = dist
                closestPhys = phys
            end
        end
    end

    if not IsValid(closestPhys) then
        closestPhys = ent:GetPhysicsObject()
    end

    if not IsValid(closestPhys) then return end

    self.HeldObject = ent
    self.HeldPhys = closestPhys

    self.HeldPhys:EnableGravity(false)
    self.HeldPhys:EnableDrag(false)

    self:GetOwner():EmitSound("npc/scanner/scanner_scan2.wav")
    self:GetOwner():EmitSound("ambient/energy/zap1.wav", 75, 150)

    local ed = EffectData()
    ed:SetMagnitude(4)
    ed:SetEntity(ent)
    util.Effect("TeslaHitboxes", ed)
end

function SWEP:DropHeldObject()
    if IsValid(self.HeldObject) then
        if IsValid(self.HeldPhys) then
            self.HeldPhys:EnableGravity(true)
            self.HeldPhys:EnableDrag(true)
        end
        self.HeldObject = nil
        self.HeldPhys = nil
        self:GetOwner():EmitSound("physics/body/body_medium_impact_soft1.wav")
    end
end

function SWEP:ThrowObject()
    if IsValid(self.HeldObject) and IsValid(self.HeldPhys) then
        self.HeldPhys:EnableGravity(true)
        self.HeldPhys:EnableDrag(true)
        self.HeldPhys:ApplyForceCenter(self:GetOwner():GetAimVector() * 5000 * self.HeldPhys:GetMass())

        self:GetOwner():EmitSound("ambient/levels/citadel/weapon_disintegrate2.wav")

        local ed = EffectData()
        ed:SetOrigin(self.HeldPhys:GetPos())
        util.Effect("cball_explode", ed)

        self.HeldObject = nil
        self.HeldPhys = nil
    end
end

function SWEP:GrabRagdoll(ent)
    self.HeldRagdoll = ent
    ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:GetOwner():EmitSound("npc/scanner/scanner_scan2.wav")
    self:GetOwner():EmitSound("ambient/energy/zap1.wav", 75, 150)

    local ed = EffectData()
    ed:SetEntity(ent)
    ed:SetMagnitude(5)
    ed:SetScale(1)
    util.Effect("TeslaHitboxes", ed)
end

function SWEP:DropHeldRagdoll()
    if IsValid(self.HeldRagdoll) then
        self.HeldRagdoll:SetCollisionGroup(COLLISION_GROUP_NONE)
        self.HeldRagdoll = nil
        self:GetOwner():EmitSound("physics/body/body_medium_impact_soft1.wav")
    end
end

function SWEP:ThrowRagdoll()
    if IsValid(self.HeldRagdoll) then
        self.HeldRagdoll:SetCollisionGroup(COLLISION_GROUP_NONE)

        for i = 0, self.HeldRagdoll:GetPhysicsObjectCount() - 1 do
            local phys = self.HeldRagdoll:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                phys:ApplyForceCenter(self:GetOwner():GetAimVector() * 5000)
            end
        end

        self:GetOwner():EmitSound("ambient/levels/citadel/weapon_disintegrate2.wav")

        local ed = EffectData()
        ed:SetOrigin(self.HeldRagdoll:GetPos())
        ed:SetNormal(self:GetOwner():GetAimVector())
        ed:SetScale(2)
        util.Effect("AR2Impact", ed)

        self.HeldRagdoll = nil
    end
end
