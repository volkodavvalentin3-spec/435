AddCSLuaFile()

SWEP.Base = "mur_med_base"
SWEP.PrintName = "Syringe"
SWEP.Slot = 5
SWEP.Spawnable = false

SWEP.WorldModel = "models/medicine/genetherapy/w_genetherapy.mdl"
SWEP.ViewModel = "models/medicine/genetherapy/v_item_genetherapy.mdl"

SWEP.WorldModelPosition = Vector(4, -3, -2)
SWEP.WorldModelAngle = Angle(0, 0, 0)

SWEP.ViewModelPos = Vector(0, 0, -2)
SWEP.ViewModelAng = Angle(0, 0, 0)
SWEP.ViewModelFOV = 65

SWEP.HoldType = "slam"

SWEP.TPIKForce = true
SWEP.TPIKPos = Vector(0, -6, 4)

SWEP.HealTimeSelf = 7.5
SWEP.HealTimeTarget = 2

SWEP.SoundTable = {
	[3.4] = "weapons/eft/injector/item_injector_01_kolpachok.wav",
	[4.2] = "weapons/eft/injector/item_injector_02_injection.wav",
	[7.5] = "weapons/eft/injector/item_injector_03_putaway.wav"
}

SWEP.AnimTable = {
	idle = "idle",
	use_self = "genetherapy",
	use_mate = "give",
	holster = "holster",
	draw = "draw"
}

SWEP.ViewModelBoneMods = {
	["main"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) },
	["button"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) },
	["cap"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) },
	["capup"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) }
}

SWEP.Substance = nil
SWEP.PhraseSelf = "loot_medic_left"
SWEP.PhraseTarget = "loot_medic_right"

function SWEP:FinishHeal(target, isSelf)
	if not IsValid(target) or not self.Substance then return end
	if not MuR.Chem then return end

	MuR.Chem:Apply(target, self.Substance, self.Dose or 1, self:GetOwner())

	if self.MessageSelf and self.MessageTarget then
		MuR:GiveMessage(isSelf and self.MessageSelf or self.MessageTarget, self:GetOwner())
	end

	self:Remove()
end
