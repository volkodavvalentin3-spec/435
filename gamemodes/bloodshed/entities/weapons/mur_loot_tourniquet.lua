AddCSLuaFile()

SWEP.Base = "mur_med_base"
SWEP.PrintName = "Tourniquet"
SWEP.Slot = 5

SWEP.WorldModel = "models/murdered/medicine/w_meds_cat.mdl"
SWEP.ViewModel = "models/murdered/medicine/v_meds_cat.mdl"

SWEP.WorldModelPosition = Vector(0, -2, 4)
SWEP.WorldModelAngle =  Angle(90, 0, 0)

SWEP.ViewModelPos = Vector(6.5, 0, -3)
SWEP.ViewModelAng = Angle(-8, 0, 4)
SWEP.ViewModelFOV = 80

SWEP.HoldType = "slam"

SWEP.TPIKForce = true
SWEP.TPIKPos = Vector(10, 0, 3)

SWEP.HealTimeSelf = 3
SWEP.HealTimeTarget = 3

SWEP.SoundTable = {
    [0] = "weapons/eft/cat/item_cat_00_draw.wav",
	[1] = "weapons/eft/cat/item_cat_01_use.wav",
	[2] = "weapons/eft/cat/item_cat_02_fasten.wav",
	[2.9] = "weapons/eft/cat/item_cat_03_putaway.wav"
}

SWEP.AnimTable = {
    idle = "idle",
    use_self = "use_cat",
    use_mate = "out_cat",
    holster = "out_cat",
    draw = "in_cat"
}

SWEP.LimbArteries = {
    "ArmLeft",
    "ArmRight",
    "LegLeft",
    "LegRight"
}

function SWEP:CanHeal(target)
    local hasLimbBleed = false
    for _, art in ipairs(self.LimbArteries) do
        if target:GetNW2Bool("Artery_"..art) then hasLimbBleed = true break end
    end

    if not hasLimbBleed and target:GetNW2Int("ArterialBleedWounds", 0) <= 0 and target:GetNW2Float('BleedLevel') < 3 then
        return false
    end
    return true
end

function SWEP:FinishHeal(target, isSelf)
    if not IsValid(target) or not target:Alive() then return end

    target:DamagePlayerSystem("blood", true)
    target:DamagePlayerSystem("blood", true)

    local stabilized = 0
    if target.StabilizeLimbArteries then
        stabilized = target:StabilizeLimbArteries("deep")
    elseif target.DowngradeLimbArterialWounds then
        stabilized = target:DowngradeLimbArterialWounds()
    end

    local fixedLimb = false
    for _, art in ipairs(self.LimbArteries) do
        if target:GetNW2Bool("Artery_"..art) then
            target:SetNW2Bool("Artery_"..art, false)
            fixedLimb = true
        end
    end

    if target.RefreshLegacyArteryFlags then
        target:RefreshLegacyArteryFlags()
    end

    if fixedLimb or stabilized > 0 then
        local stillBleeding = false
        if target:GetNW2Bool("Artery_Neck") then stillBleeding = true end
        if target:GetNW2Bool("Artery_Heart") then stillBleeding = true end
        if target:GetNW2Bool("Artery_Generic") then stillBleeding = true end
        if target:GetNW2Bool("Artery_ArmLeft") or target:GetNW2Bool("Artery_ArmRight") then stillBleeding = true end
        if target:GetNW2Bool("Artery_LegLeft") or target:GetNW2Bool("Artery_LegRight") then stillBleeding = true end

        if not stillBleeding then
             target:DamagePlayerSystem("hard_blood", true)
        end
    end

    target:SetNW2Float("TourniquetTime", CurTime())

    if target.ClearBloodEffects then
        target:ClearBloodEffects()
    end

    local msg = isSelf and "tourniquet_applied" or "tourniquet_applied_target"
    MuR:GiveMessage(msg, self:GetOwner())

    if not isSelf then
         MuR:GiveMessage("tourniquet_applied", target)
    end

    self:Remove()
end

SWEP.Category = "Bloodshed - Civilian"
SWEP.Spawnable = true
