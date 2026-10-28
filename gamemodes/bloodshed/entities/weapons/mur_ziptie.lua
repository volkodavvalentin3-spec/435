AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.PrintName = "Zip Ties"
SWEP.Category = "Bloodshed - Illegal"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Slot = 5
SWEP.SlotPos = 3

SWEP.WorldModel = "models/props_c17/tools_wrench01a.mdl"
SWEP.ViewModel = "models/murdered/handcuffs/c_hand_cuffs.mdl"

SWEP.WorldModelPosition = Vector(4, -2, 0)
SWEP.WorldModelAngle = Angle(0, 0, 90)

SWEP.ViewModelPos = Vector(0, -1, -2)
SWEP.ViewModelAng = Angle(0, 0, 5)
SWEP.ViewModelFOV = 80

SWEP.HoldType = "slam"
SWEP.TPIKForce = true
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.BindDistance = 64

function SWEP:CustomInit()
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_DRAW)
    self:SetHoldType(self.HoldType)
    return true
end

function SWEP:FindBindTarget()
    local ow = self:GetOwner()
    if not IsValid(ow) then return NULL end

    local tr = util.TraceLine({
        start = ow:GetShootPos(),
        endpos = ow:GetShootPos() + ow:GetAimVector() * self.BindDistance,
        filter = ow,
        mask = MASK_SHOT_HULL
    })

    local tar = tr.Entity
    if IsValid(tar) and tar.isRDRag and IsValid(tar.Owner) then
        tar = tar.Owner
    end

    if not IsValid(tar) or not tar:IsPlayer() then return NULL end
    return tar
end

function SWEP:CanBind(target)
    if not IsValid(target) or not target:IsPlayer() then return false end
    if not target:Alive() then return false end
    if target:IsRestrained() then return false end

    local ow = self:GetOwner()
    if not IsValid(ow) or target == ow then return false end

    if IsValid(target:GetRD()) then return true end
    if target:GetNW2Bool("IsUnconscious", false) then return true end
    if target:GetNW2Bool("Surrender", false) then return true end

    return ow:IsAtBack(target)
end

function SWEP:CustomPrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 1.5)
    if CLIENT then return end

    local ow = self:GetOwner()
    local target = self:FindBindTarget()
    if not self:CanBind(target) then return end

    target:StopRagdolling()

    timer.Simple(0.01, function()
        if not IsValid(target) or not IsValid(ow) then return end
        target:SetPos(ow:GetPos())
        target:SetEyeAngles(ow:EyeAngles())
    end)

    local id = math.random(1, 6)
    local anim = "sequence_ron_arrest_start_player_0" .. id
    local _, dur = ow:LookupSequence(anim)

    timer.Simple(0.001, function()
        if not IsValid(target) then return end
        target:Surrender(true, true, id, dur, "ziptie")
    end)

    ow:EmitSound("physics/plastic/plastic_box_strain" .. math.random(1, 4) .. ".wav", 60, math.random(95, 110))
    ow:ViewPunch(Angle(3, 0, 0))
    ow:Freeze(true)
    ow:SetNotSolid(true)
    ow:SetSVAnimation(anim, true)

    timer.Simple(dur, function()
        if not IsValid(ow) then return end
        ow:Freeze(false)
        ow:SetNotSolid(false)
    end)

    self:Remove()
end

function SWEP:CustomSecondaryAttack()
end

if CLIENT then
    function SWEP:DrawHUD()
        local text = MuR.Language["loot_ziptie_hint"]
        if not text then return end

        draw.SimpleText(text, "MuR_Font1", ScrW() / 2, ScrH() - He(100), color_white,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end
