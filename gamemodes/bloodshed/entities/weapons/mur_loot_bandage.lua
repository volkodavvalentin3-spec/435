AddCSLuaFile()

SWEP.Base = "mur_med_base"
SWEP.PrintName = "Bandage"
SWEP.Slot = 5

SWEP.WorldModel = "models/medicine/bandage/w_bandages.mdl"
SWEP.ViewModel = "models/medicine/bandage/v_item_bandages.mdl"

SWEP.WorldModelPosition = Vector(-4, 2, 0)
SWEP.WorldModelAngle =  Angle(0, 0, 0)

SWEP.ViewModelPos = Vector(-0.05, 0, -6)
SWEP.ViewModelAng = Angle(-15, 0, 8)
SWEP.ViewModelFOV = 70

SWEP.HoldType = "slam"

SWEP.TPIKForce = true
SWEP.TPIKPos = Vector(-2, -4, 3)

SWEP.HealTimeSelf = 3
SWEP.HealTimeTarget = 3

SWEP.SoundTable = {
    [1] = "murdered/medicals/bandage.wav"
}

SWEP.AnimTable = {
    idle = "idle",
    use_self = "bandage",
    use_mate = "bandage",
    holster = "holster",
    draw = "draw"
}

function SWEP:CanHeal(target)
    if target.HasBleedingWoundsAtOrAbove and target:HasBleedingWoundsAtOrAbove(1) then return true end
    if target:GetNW2Float('BleedLevel') <= 0 and target:Health() >= 100 then return false end
    return true
end

function SWEP:FinishHeal(target, isSelf)
    if not IsValid(target) or not target:Alive() then return end

    local bleedLevel = target:GetNW2Float('BleedLevel')
    local hardBleed = target:GetNW2Bool('HardBleed')
    local minorWounds = target.GetNW2Int and target:GetNW2Int("MinorBleedWounds", 0) or 0
    local deepWounds = target.GetNW2Int and target:GetNW2Int("DeepBleedWounds", 0) or 0
    local arterialWounds = target.GetNW2Int and target:GetNW2Int("ArterialBleedWounds", 0) or 0
    local msg = isSelf and "bandage_use" or "bandage_use_target"

    local healAmount = 20
    local bleedHealCount = 2

    if hardBleed or arterialWounds > 0 then
        healAmount = 5
        bleedHealCount = 0
        msg = msg .. "_ineffective"
    elseif deepWounds > 0 or bleedLevel >= 3 then
        healAmount = 10
        bleedHealCount = 1
        msg = msg .. "_weak"
    end

    target:SetHealth(math.Clamp(target:Health() + healAmount, 1, 100))

    local clearedMinor = 0
    if minorWounds > 0 and target.ClearMinorBleedingWounds then
        clearedMinor = target:ClearMinorBleedingWounds()
    end

    if clearedMinor <= 0 then
        for i=1, bleedHealCount do
            target:DamagePlayerSystem("blood", true)
        end
    end

    if (bleedHealCount > 0 or clearedMinor > 0) and target.ClearBloodEffects then
        target:ClearBloodEffects()
    end

    MuR:GiveMessage(msg, self:GetOwner())

    self:Remove()
end

SWEP.Category = "Bloodshed - Civilian"
SWEP.Spawnable = true
