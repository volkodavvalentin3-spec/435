AddCSLuaFile()

SWEP.Base = "mur_med_base"
DEFINE_BASECLASS("mur_med_base")
SWEP.PrintName = "Pills"
SWEP.Slot = 5
SWEP.Spawnable = false

SWEP.WorldModel = "models/murdered/medicine/w_phalanx.mdl"
SWEP.ViewModel = "models/murdered/medicine/v_item_phalanx.mdl"

SWEP.WorldModelPosition = Vector(4, -2, -2)
SWEP.WorldModelAngle = Angle(0, 0, 0)

SWEP.ViewModelPos = Vector(0, 0, -2)
SWEP.ViewModelAng = Angle(0, 0, 0)
SWEP.ViewModelFOV = 65

SWEP.HoldType = "slam"

SWEP.TPIKForce = true
SWEP.TPIKPos = Vector(0, -6, 4)

SWEP.HealTimeSelf = 4.5
SWEP.HealTimeTarget = 2

SWEP.SoundTable = {
	[0.3] = "weapons/eft/pills/item_pillsbottle_01_open.wav",
	[1.6] = "weapons/eft/pills/item_pillsbottle_02_pilltake.wav",
	[2.9] = "weapons/eft/pills/item_pillsbottle_03_use.wav",
	[4.0] = "weapons/eft/pills/item_pillsbottle_04_close.wav"
}

SWEP.AnimTable = {
	idle = "idle",
	use_self = "pills",
	use_mate = "give",
	holster = "holster",
	draw = "draw"
}

SWEP.Substance = nil
SWEP.CanLace = false
SWEP.LaceDistance = 64
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

function SWEP:Think()
	local owner = self:GetOwner()

	if self.CanLace and IsValid(owner) and self:GetHealState() == 0 and owner:KeyDown(IN_ATTACK2) then
		local tr = util.TraceLine({
			start = owner:GetShootPos(),
			endpos = owner:GetShootPos() + owner:GetAimVector() * self.LaceDistance,
			filter = owner,
			ignoreworld = true,
			mask = MASK_SHOT_HULL
		})

		local target = tr.Entity
		if IsValid(target) and not target:IsPlayer() and not target.MuR_LacedWith then
			if SERVER then
				target.MuR_LacedWith = self.Substance
				target.MuR_LacedBy = owner
				MuR:GiveMessage(self.MessageLace or "poison_use", owner)
				self:EmitSound("weapons/eft/pills/item_pillsbottle_02_pilltake.wav", 45)
				self:Remove()
			end

			return
		end
	end

	return BaseClass.Think(self)
end
