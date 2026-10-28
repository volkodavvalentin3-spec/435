AddCSLuaFile()
SWEP.PrintName = "Police Taser"
SWEP.Author = "Bloodshed"
SWEP.Category = "Bloodshed - Police"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true
SWEP.DisableSuicide = true
SWEP.ViewModelFOV = 70
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/murdered/weapons/c_taser.mdl"
SWEP.WorldModel = "models/murdered/weapons/w_taser.mdl"
SWEP.UseHands = true
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 3
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "GaussEnergy"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.HoldType = "revolver"
SWEP.HitDistance = 300
SWEP.TaseTime = 3.5
SWEP.TaseDamage = 5
SWEP.TPIKForce = true

local taserSounds = {
    fire = "murdered/other/taser_shoot.mp3",
    hit = "murdered/other/taser.mp3",
    empty = "weapons/ar2/ar2_empty.wav",
    reload = "weapons/pistol/pistol_reload1.wav"
}

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    self:SendWeaponAnim(ACT_VM_DRAW)
    return true
end

function SWEP:Holster()
    return true
end

function SWEP:Reload()
    if self:Clip1() >= self.Primary.ClipSize then return end
    if self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0 then return end

    self:DefaultReload(ACT_VM_RELOAD)
    timer.Simple(0.3, function() if !IsValid(self) then return end self:EmitSound(taserSounds.reload, 60, 100) end)
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if self:Clip1() <= 0 then
        self:EmitSound(taserSounds.empty, 60, 100)
        self:SetNextPrimaryFire(CurTime() + 0.5)
        return
    end

    self:SetNextPrimaryFire(CurTime() + 1.5)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:SetClip1(self:Clip1() - 1)
    owner:SetAnimation(PLAYER_ATTACK1)

    local startPos = owner:GetBonePosition(owner:LookupBone("ValveBiped.Bip01_R_Hand") or 0)
    local endPos = startPos + owner:GetAimVector() * self.HitDistance

    local tr = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = {owner, owner:GetRD()},
        mask = MASK_SHOT_HULL
    })

    local trHull = util.TraceHull({
        start = startPos,
        endpos = endPos,
        filter = {owner, owner:GetRD()},
        mask = MASK_SHOT_HULL,
        mins = Vector(-8, -8, -8),
        maxs = Vector(8, 8, 8)
    })

    local target = tr.Entity
    if IsValid(trHull.Entity) and (trHull.Entity:IsPlayer() or trHull.Entity.isRDRag) then
        target = trHull.Entity
    end

    local hitPos = tr.Hit and tr.HitPos or endPos

    local effect = EffectData()
    effect:SetStart(startPos)
    effect:SetOrigin(hitPos)
    effect:SetScale(1)
    effect:SetMagnitude(0.3)
    util.Effect("ToolTracer", effect)

    if SERVER then
        owner:EmitSound(taserSounds.fire, 70, 100)

        if IsValid(target) and target.isRDRag then
            target = target.Owner
        end

        if IsValid(target) and target:IsPlayer() then
            self:TasePlayer(target)
            self:TakePrimaryAmmo(1)
        elseif IsValid(target) and (target.SuspectNPC or target.IsCivilian) then
            self:TaseNPC(target)
            self:TakePrimaryAmmo(1)
        elseif tr.Hit then
            local spark = EffectData()
            spark:SetOrigin(tr.HitPos)
            spark:SetNormal(tr.HitNormal or Vector(0, 0, 1))
            util.Effect("ElectricSpark", spark)
        end
    end
end

function SWEP:TasePlayer(target)
    if not IsValid(target) then return end

    local owner = self:GetOwner()
    local targetID = target:EntIndex()
    local taseTime = self.TaseTime
    local taseDamage = self.TaseDamage

    target:EmitSound(taserSounds.hit, 70, 100)

    if target.StartRagdolling then
        target:StartRagdolling()
    end

    local tickCount = math.floor(taseTime * 100)
    local tickNum = 0

    timer.Create("Taser_" .. targetID, 0.01, tickCount, function()
        tickNum = tickNum + 1

        if not IsValid(target) or not target:Alive() then
            timer.Remove("Taser_" .. targetID)
            return
        end

        local ragdoll = target.GetRD and target:GetRD()
        local effectEnt = IsValid(ragdoll) and ragdoll or target

        if IsValid(ragdoll) and ragdoll.StruggleBone then
            ragdoll:StruggleBone()
            target.IsRagStanding = false
        end

        if tickNum % 3 == 0 then
            local fx = EffectData()
            fx:SetOrigin(effectEnt:WorldSpaceCenter())
            fx:SetMagnitude(1)
            fx:SetEntity(effectEnt)
            util.Effect("TeslaHitboxes", fx)
        end

        if tickNum % 5 == 0 then
            local shake = target:EyeAngles() + AngleRand(-8, 8)
            shake.z = 0
            target:SetEyeAngles(shake)
        end

        if tickNum % 50 == 0 and IsValid(owner) then
            target:TakeDamage(taseDamage, owner, owner)
        end
    end)
end

function SWEP:TaseNPC(target)
    if not IsValid(target) then return end

    local targetID = target:EntIndex()
    local taseTime = self.TaseTime

    target:EmitSound(taserSounds.hit, 70, 100)

    if target.FullSurrender then
        target:FullSurrender()
    end

    local tickCount = math.floor(taseTime * 100)

    timer.Create("Taser_" .. targetID, 0.01, tickCount, function()
        if not IsValid(target) then
            timer.Remove("Taser_" .. targetID)
            return
        end

        local fx = EffectData()
        fx:SetOrigin(target:WorldSpaceCenter())
        fx:SetMagnitude(1)
        fx:SetEntity(target)
        util.Effect("TeslaHitboxes", fx)
    end)
end

function SWEP:SecondaryAttack()
end
