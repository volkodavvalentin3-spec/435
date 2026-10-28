AddCSLuaFile()

SWEP.PrintName = "FPV Drone"
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 4
SWEP.SlotPos = 1

SWEP.Spawnable = true

SWEP.ViewModel = "models/murdered/weapons/drone_ex.mdl"
SWEP.WorldModel = "models/murdered/weapons/drone_ex.mdl"
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false

function SWEP:Initialize()
	self:SetHoldType("smg")
end

function SWEP:PrimaryAttack()
	if SERVER then
		local ply = self.Owner
		local tr = util.TraceLine({
			start = ply:EyePos(),
			endpos = ply:EyePos() + ply:GetAimVector()*48,
			filter = ply,
			mask = MASK_SHOT
		})
		if tr.Hit then return end
		local SpawnPos = tr.HitPos
		local prop = ents.Create('mur_drone_entity')
		prop:SetPos(SpawnPos)
		prop:SetAngles(ply:GetAngles())
		prop:SetCreator(ply)
		prop:Spawn()
		ply:ScreenFade(SCREENFADE.IN, color_black, 0.5, 0.5)
		self:Remove()
	end
end

function SWEP:SecondaryAttack() end

function SWEP:Reload() end

if CLIENT then
	local WorldModel = ClientsideModel(SWEP.WorldModel)
	WorldModel:SetNoDraw(true)

	function SWEP:DrawWorldModel()
		local _Owner = self:GetOwner()

		if (IsValid(_Owner)) then
			local offsetVec = Vector(20, -2, 0)
			local offsetAng = Angle(170, 180, 0)

			local boneid = _Owner:LookupBone("ValveBiped.Bip01_R_Hand")
			if !boneid then return end

			local matrix = _Owner:GetBoneMatrix(boneid)
			if !matrix then return end

			local newPos, newAng = LocalToWorld(offsetVec, offsetAng, matrix:GetTranslation(), matrix:GetAngles())

			WorldModel:SetPos(newPos)
			WorldModel:SetAngles(newAng)

            WorldModel:SetupBones()
		else
			WorldModel:SetPos(self:GetPos())
			WorldModel:SetAngles(self:GetAngles())
		end

		WorldModel:DrawModel()
	end

	function SWEP:CalcViewModelView(ViewModel, OldEyePos, OldEyeAng, EyePos, EyeAng)
		local pos = EyePos-EyeAng:Up()*16+EyeAng:Forward()*32
		local ang = EyeAng
		return pos, ang
	end
end
SWEP.Category = "Bloodshed - Illegal"
