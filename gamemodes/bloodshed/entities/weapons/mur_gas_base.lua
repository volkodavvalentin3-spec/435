AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.PrintName = "Gas Canister"
SWEP.Slot = 4
SWEP.Spawnable = false

SWEP.WorldModel = "models/props_junk/garbage_plasticbottle003a.mdl"
SWEP.ViewModel = "models/props_junk/garbage_plasticbottle003a.mdl"
SWEP.Primary.Delay = 1
SWEP.WorldModelPosition = Vector(3.5, -2, 2)
SWEP.WorldModelAngle = Angle(0, 0, 0)
SWEP.ViewModelPos = Vector(16, 4, -6)
SWEP.ViewModelAng = Angle(0, 0, 5)
SWEP.ViewModelFOV = 90
SWEP.HoldType = "grenade"
SWEP.PinPulled = false

SWEP.TPIKForce = true
SWEP.TPIKPos = Vector(10, 0, 6)

SWEP.Substance = "chlorine"
SWEP.CloudRadius = 300
SWEP.CloudLifetime = 10
SWEP.SmokeColor = "200 255 100"
SWEP.CloudVisible = true

function SWEP:Deploy(wep)
	self:SendWeaponAnim(ACT_VM_DRAW)
	self:SetHoldType(self.HoldType)
	self.PinPulled = false
end

function SWEP:CustomPrimaryAttack()
	if self.PinPulled then return end

	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

	if SERVER then
		self.Activated = true
		self.PinPulled = true
	end
end

function SWEP:Think()
	if self.PinPulled and !self:GetOwner():KeyDown(IN_ATTACK) then
		self:ThrowGrenade()
	end
end

function SWEP:ThrowGrenade()
	if !self.PinPulled then return end

	if SERVER then
		self:SendWeaponAnim(ACT_VM_THROW)
		self:GetOwner():EmitSound("weapon.Swing")

		timer.Simple(0.3, function()
			if not IsValid(self) or not IsValid(self:GetOwner()) then return end

			local ow = self:GetOwner()
			local ent = ents.Create("mur_gas_cloud")
			if not IsValid(ent) then return end

			ent:SetPos(ow:EyePos() + ow:GetAimVector() * 4 + ow:GetRight() * 4)
			ent.PlayerOwner = ow
			ent.Substance = self.Substance
			ent.Radius = self.CloudRadius
			ent.Lifetime = self.CloudLifetime
			ent.SmokeColor = self.SmokeColor
			ent.Visible = self.CloudVisible
			ent:Spawn()

			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then
				phys:SetVelocity(ow:GetAimVector() * 1000)
				phys:AddAngleVelocity(Vector(600, 0, 0))
			end

			ow:ViewPunch(Angle(5, 0, 0))
		end)

		timer.Simple(0.9, function()
			if not IsValid(self) then return end
			self:Remove()
		end)
	end

	self.PinPulled = false
end

function SWEP:CustomInit()
	self.Activated = false
	self.PinPulled = false
end

function SWEP:OnDrop()
	if self.Activated then
		self:Remove()
	end
end

function SWEP:DrawHUD()
	draw.SimpleText(MuR.Language["loot_grenade_1"] or "Hold LMB to throw", "MuR_Font1", ScrW()/2, ScrH()-He(100), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
