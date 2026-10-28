AddCSLuaFile()

SWEP.Base = "mur_med_base"
SWEP.PrintName = "Surgical Kit"
SWEP.Slot = 5

SWEP.WorldModel = "models/murdered/medicine/w_meds_surgicalkit.mdl"
SWEP.ViewModel = "models/murdered/medicine/v_meds_surgicalkit.mdl"
SWEP.BandageSound = "murdered/medicals/medkit.wav"

SWEP.WorldModelPosition = Vector(3, -8, 0)
SWEP.WorldModelAngle =  Angle(-90, 0, -90)

SWEP.ViewModelPos = Vector(0, -1, -3)
SWEP.ViewModelAng = Angle(-5, -8, 10)
SWEP.ViewModelFOV = 65

SWEP.HoldType = "slam"

SWEP.TPIKForce = true
SWEP.TPIKPos = Vector(18, -4, 3)

SWEP.CanRevive = true
SWEP.HealTimeSelf = 15
SWEP.HealTimeTarget = 15

SWEP.SoundTable = {
    [1] = "murdered/medicals/medkit.wav"
}

SWEP.AnimTable = {
    idle = "idle",
    use_self = "use",
    use_mate = "use",
    holster = "idle",
    draw = "idle"
}

function SWEP:CanHeal(target)
    local internalBleed = target:GetNW2Float("InternalBleedEnd", 0) > CurTime()
    local pneumo = target:GetNW2Bool("Pneumothorax") or target:GetNW2Bool("PneumothoraxLeft") or target:GetNW2Bool("PneumothoraxRight")
    local toxin = target:GetNW2Float("ToxinLevel", 0) > 0
    local hardBleed = target:GetNW2Bool("HardBleed")
    local spine = target:GetNW2Bool("SpineBroken")
    local deepWounds = target:GetNW2Int("DeepBleedWounds", 0) > 0
    local arterialWounds = target:GetNW2Int("ArterialBleedWounds", 0) > 0

    if not internalBleed and not pneumo and not toxin and not hardBleed and not spine and not deepWounds and not arterialWounds then
        return false
    end
    return true
end

function SWEP:FinishHeal(target, isSelf)
    if not IsValid(target) or not target:Alive() then return end

    target:SetNW2Float("InternalBleedEnd", 0)
    target:SetNW2Bool("Pneumothorax", false)
    target:SetNW2Bool("PneumothoraxLeft", false)
    target:SetNW2Bool("PneumothoraxRight", false)
    if target.CriticalOrganStates then
        target.CriticalOrganStates.lungs = nil
        target.CriticalOrganStates.lung_left = nil
        target.CriticalOrganStates.lung_right = nil
    end
    if target.OrganDamageStages then
        target.OrganDamageStages.lungs = 0
        target.OrganDamageStages.lung_left = 0
        target.OrganDamageStages.lung_right = 0
    end
    target:SetNW2Int("OrganDamage_lungs", 0)
    target:SetNW2Int("OrganDamage_lung_left", 0)
    target:SetNW2Int("OrganDamage_lung_right", 0)
    target:SetNW2Float("ToxinLevel", 0)
    target:SetNW2Bool("RibFracture", false)
    target:SetNW2Bool("SpineBroken", false)
    if target.ClearAllBleedingWounds then
        target:ClearAllBleedingWounds()
    end
    if target.StabilizeLimbArteries then
        target:StabilizeLimbArteries("clear")
    end

    for _, flag in ipairs({"Artery_Neck", "Artery_Heart", "Artery_Generic"}) do
        target:SetNW2Bool(flag, false)
    end
    target:SetNW2Bool("Artery_neck", false)
    target:SetNW2Bool("Artery_heart", false)

    for _, key in ipairs({"carotid", "heart", "neck", "liver"}) do
        if target.ClearCriticalOrganState then
            target:ClearCriticalOrganState(key)
        end
    end

    if target.StabilizeAllCriticalOrgans then
        target:StabilizeAllCriticalOrgans()
    end

    if target.RefreshLegacyArteryFlags then
        target:RefreshLegacyArteryFlags()
    end
    target:SetNW2Bool("HardBleed", false)

    if target.ClearBloodEffects then
        target:ClearBloodEffects()
    end

    local msg = isSelf and "surgical_success" or "surgical_success_target"
    MuR:GiveMessage(msg, self:GetOwner())
    if not isSelf then MuR:GiveMessage("surgical_success", target) end

    self:Remove()
end

SWEP.Category = "Bloodshed - Civilian"
SWEP.Spawnable = true
