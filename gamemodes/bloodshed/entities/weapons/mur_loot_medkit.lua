AddCSLuaFile()

SWEP.Base = "mur_med_base"
SWEP.PrintName = "Medkit"
SWEP.Slot = 5

SWEP.WorldModel = "models/medicine/medkit/w_firstaidkit.mdl"
SWEP.ViewModel = "models/medicine/medkit/v_item_firstaid.mdl"
SWEP.BandageSound = "murdered/medicals/medkit.wav"

SWEP.WorldModelPosition = Vector(10, -2, 0)
SWEP.WorldModelAngle =  Angle(-90, 90, -90)

SWEP.ViewModelPos = Vector(0, -1, -3)
SWEP.ViewModelAng = Angle(-5, -8, 10)
SWEP.ViewModelFOV = 65

SWEP.HoldType = "slam"

SWEP.TPIKForce = true
SWEP.TPIKPos = Vector(0, 0, 2)

SWEP.CanRevive = true
SWEP.HealTimeSelf = 8
SWEP.HealTimeTarget = 6

SWEP.SoundTable = {
    [0.5] = "murdered/medicals/medkit.wav",
	[1.8] = "weapons/eft/pills/item_pillsbottle_01_open.wav",
	[2.8] = "weapons/eft/pills/item_pillsbottle_02_pilltake.wav",
	[3.8] = "weapons/eft/pills/item_pillsbottle_03_use.wav",
	[4.4] = "weapons/eft/pills/item_pillsbottle_04_close.wav",
	[5.4] = "weapons/eft/salewa/item_medkit_salewa_00_draw.wav",
	[6.8] = "weapons/eft/salewa/item_medkit_salewa_03_use.wav"
}

SWEP.AnimTable = {
    idle = "idle",
    use_self = "medkit",
    use_mate = "give",
    holster = "holster",
    draw = "draw"
}

function SWEP:CanHeal(target)
	if target.HasBleedingWoundsAtOrAbove and target:HasBleedingWoundsAtOrAbove(2) then return true end
	if target:GetNW2Float('BleedLevel') <= 0 and not target:GetNW2Bool('LegBroken') and target:Health() >= 100 then return false end
    return true
end

function SWEP:FinishHeal(target, isSelf)
    if not IsValid(target) or not target:Alive() then return end

    local bleedLevel = target:GetNW2Float('BleedLevel')
    local hardBleed = target:GetNW2Bool('HardBleed')
    local deepWounds = target:GetNW2Int('DeepBleedWounds', 0)
    local arterialWounds = target:GetNW2Int('ArterialBleedWounds', 0)
    local msg = isSelf and "medkit_use" or "medkit_use_target"

    local healAmount = 40
    local bleedHealCount = 3

    if hardBleed or arterialWounds > 0 then
        target:DamagePlayerSystem("hard_blood", true)
        healAmount = 50
        bleedHealCount = 2
        msg = msg .. "_critical"
    elseif deepWounds > 0 or bleedLevel >= 3 then
        healAmount = 45
        bleedHealCount = 3
        msg = msg .. "_severe"
    end

    if target.ClearAllBleedingWounds then
        target:ClearAllBleedingWounds()
    end
    if target.StabilizeLimbArteries then
        target:StabilizeLimbArteries("clear")
    end

    for i=1, bleedHealCount do
        target:DamagePlayerSystem("blood", true)
    end

    target:SetHealth(math.Clamp(target:Health() + healAmount, 1, 100))
    target:DamagePlayerSystem("bone", true)

    if target.ClearBloodEffects then
        target:ClearBloodEffects()
    end

    MuR:GiveMessage(msg, self:GetOwner())

    self:Remove()
end

SWEP.Category = "Bloodshed - Civilian"
SWEP.Spawnable = true
