AddCSLuaFile()

SWEP.Base = "mur_med_base"
SWEP.PrintName = "Adrenaline"
SWEP.Slot = 5

SWEP.WorldModel = "models/medicine/genetherapy/w_genetherapy.mdl"
SWEP.ViewModel = "models/medicine/genetherapy/v_item_genetherapy.mdl"
SWEP.BandageSound = "murdered/medicals/syringe_adrenaline.wav"

SWEP.WorldModelPosition = Vector(4, -3, -2)
SWEP.WorldModelAngle =  Angle(0, 0, 0)

SWEP.ViewModelPos = Vector(0, 0, -2)
SWEP.ViewModelAng = Angle(0, 0, 0)
SWEP.ViewModelFOV = 65

SWEP.HoldType = "slam"

SWEP.TPIKForce = true
SWEP.TPIKPos = Vector(0, -6, 4)

SWEP.HealTimeSelf = 8
SWEP.HealTimeTarget = 4

SWEP.SoundTable = {
	[3.4] = "weapons/eft/injector/item_injector_01_kolpachok.wav",
	[4.2] = "weapons/eft/injector/item_injector_02_injection.wav",
	[7.5] = "weapons/eft/injector/item_injector_03_putaway.wav",
}

SWEP.AnimTable = {
    idle = "idle",
    use_self = "genetherapy",
    use_mate = "give",
    holster = "holster",
    draw = "draw"
}

SWEP.VElements = {
	//["adrenaline"] = { type = "Model", model = "models/murdered/adrenaline/syringe/syringe_blood.mdl", bone = "main", rel = "", pos = Vector(0, -7.72, -0.288), angle = Angle(0, 90, -30), size = Vector(1.2, 1.2, 1.2), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}

SWEP.ViewModelBoneMods = {
	["main"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) },
	["button"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) },
	["cap"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) },
	["capup"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) }
}

function SWEP:FinishHeal(target, isSelf)
    if not IsValid(target) or not target:Alive() then return end

    local msg = isSelf and "adrenaline_use" or "adrenaline_use_target"
    MuR:GiveMessage(msg, self:GetOwner())

    local applied = MuR.Chem:UseAdr(target, self:GetOwner())

    if applied and target:GetNW2Bool("IsUnconscious") then
        target:WakeUpFromUnconsciousness()
    end

    if applied and target.AddBloodVolume and target.GetBleedRate and target:GetBleedRate() > 0 then
        target:AddBloodVolume(-4)
    end

    self:Remove()
end

SWEP.Category = "Bloodshed - Civilian"
SWEP.Spawnable = true
