AddCSLuaFile()
SWEP.Base = "mur_loot_base"
SWEP.PrintName = "M67"
SWEP.Slot = 4
SWEP.WorldModel = "models/simpnades/w_m67.mdl"
SWEP.ViewModel = "models/simpnades/v_m67.mdl"
SWEP.IEDSound = "murdered/weapons/ied.wav"
SWEP.InsurgencyHands = true
SWEP.Primary.Delay = 1
SWEP.WorldModelPosition = Vector(3.5, -2, 2)
SWEP.WorldModelAngle = Angle(0, 60, 180)
SWEP.ViewModelPos = Vector(0, 1, 0)
SWEP.ViewModelAng = Angle(0, 0, 5)
SWEP.ViewModelFOV = 90
SWEP.HoldType = "grenade"
SWEP.PinPulled = false

SWEP.TPIKForce = true
SWEP.TPIKPos = Vector(10,0,6)

SWEP.TripwireMode = false
SWEP.StakeEnt = nil
SWEP.StakePos = nil
SWEP.StakeNormal = nil
SWEP.MaxTripwireDistance = 250

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "TripwireMode")
	self:NetworkVar("Int", 0, "TripwireStage")
	self:NetworkVar("Vector", 0, "StakePosition")
	self:NetworkVar("Vector", 1, "StakeNormal")
end

function SWEP:Deploy(wep)
	self:SendWeaponAnim(ACT_VM_DRAW)
	self:SetHoldType(self.HoldType)
	self.PinPulled = false
	self:SetTripwireMode(false)
	self:SetTripwireStage(0)
end

function SWEP:CustomPrimaryAttack()
	if self.PinPulled then return end
	if self:GetTripwireMode() then return end

	local vm = self:GetOwner():GetViewModel()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

	if SERVER then
		self.Activated = true
		vm:SendViewModelMatchingSequence(vm:LookupSequence("pullbackhigh"))
		timer.Simple(0.5, function()
			if !IsValid(self) or !IsValid(self.Owner) then return end
			self:GetOwner():ViewPunch(Angle(2, 2, 0))
			self:GetOwner():EmitSound("murdered/weapons/grenade/f1_pinpull.wav", 60, math.random(90, 110))
		end)
		timer.Simple(1, function()
			if !IsValid(self) or !IsValid(self.Owner) then return end
			self:GetOwner():ViewPunch(Angle(-2, -2, 0))
			self.PinPulled = true
		end)
	end
end

function SWEP:Think()
	if self.PinPulled and !self:GetOwner():KeyDown(IN_ATTACK) then
		self:ThrowGrenade()
	end

	if CLIENT and self:GetTripwireMode() then
		self:UpdateGhostPreview()
	end
end

function SWEP:ThrowGrenade()
	if !self.PinPulled then return end

	local vm = self:GetOwner():GetViewModel()
	if SERVER then
		vm:SendViewModelMatchingSequence(vm:LookupSequence("throw"))
		self:GetOwner():EmitSound("murdered/weapons/universal/uni_ads_in_0" .. math.random(2, 6) .. ".wav", 60, math.random(90, 110))

		timer.Simple(0.3, function()
			if not IsValid(self) or not IsValid(self:GetOwner()) then return end
			local ent = ents.Create("murwep_grenade")
			ent:SetPos(self:GetOwner():EyePos() + self:GetOwner():GetAimVector() * 4 + self:GetOwner():GetRight() * 4)
			ent.PlayerOwner = self:GetOwner()
			ent:Spawn()
			ent:GetPhysicsObject():SetVelocity(self:GetOwner():GetAimVector() * 1024)
			self:GetOwner():ViewPunch(Angle(10, 0, 0))
		end)

		timer.Simple(0.9, function()
			if not IsValid(self) then return end
			self:Remove()
		end)
	end

	self.PinPulled = false
end

function SWEP:GetPlacementTrace()
	local owner = self:GetOwner()
	local tr = util.TraceLine({
		start = owner:EyePos(),
		endpos = owner:EyePos() + owner:GetAimVector() * 100,
		filter = function(ent) return ent != owner and !ent:IsPlayer() and !MuR.IsAI(ent) and ent:GetClass() != "prop_ragdoll" end
	})
	return tr
end

function SWEP:CustomSecondaryAttack()
	if self.PinPulled then return end

	self:SetNextSecondaryFire(CurTime() + 0.5)

	if SERVER then
		if not self:GetTripwireMode() then
			self:SetTripwireMode(true)
			self:SetTripwireStage(1)
		else
			local tr = self:GetPlacementTrace()

			if self:GetTripwireStage() == 1 then
				if tr.Hit then
					self:SetStakePosition(tr.HitPos)
					self:SetStakeNormal(tr.HitNormal)
					self:SetTripwireStage(2)

					local stake = ents.Create("prop_physics")
					stake:SetModel("models/props_c17/TrapPropeller_Lever.mdl")
					if game.GetWorld() != tr.Entity then
						stake:SetParent(tr.Entity)
					end
					stake:SetPos(tr.HitPos + tr.HitNormal * 2)
					stake:SetAngles(Angle(0, 0, 90))
					stake:Spawn()
					stake:GetPhysicsObject():EnableMotion(false)
					stake:SetNotSolid(true)
					self.StakeEnt = stake

					self:GetOwner():EmitSound("physics/metal/metal_solid_impact_bullet1.wav", 50, 100)
					self:GetOwner():ViewPunch(Angle(8, 0, 0))
				end
			elseif self:GetTripwireStage() == 2 then
				if tr.Hit and self:GetStakePosition() then
					local distance = tr.HitPos:Distance(self:GetStakePosition())

					if distance > self.MaxTripwireDistance then
						return
					end

					if distance < 10 then
						return
					end

					local traceCheck = util.TraceLine({
						start = tr.HitPos + Vector(0, 0, 5),
						endpos = self:GetStakePosition() + Vector(0, 0, 5),
						filter = {self:GetOwner(), tr.Entity},
						mask = MASK_SOLID
					})

					if traceCheck.Hit then
						local act = traceCheck.Entity
						if IsValid(act) then
							local alive = MuR.IsAI(act) or act:IsPlayer()
							if !IsValid(self:GetOwner()) or (!alive and (!IsValid(act:GetPhysicsObject()) or !act:GetPhysicsObject():IsMotionEnabled())) or act == self:GetOwner() or alive and act:Health() <= 0 or act:IsKiller() and self:GetOwner():IsKiller() then
							else
								return
							end
						else
							return
						end
					end

					local ent = ents.Create("murwep_grenade")
					ent:SetPos(tr.HitPos+tr.HitNormal * 2)
					if game.GetWorld() != tr.Entity then
						ent:SetParent(tr.Entity)
					end
					ent.PlayerOwner = self:GetOwner()
					ent.OwnerTrap = self:GetOwner()
					MuR:SetTrapOwner(ent, self:GetOwner())
					ent.StakeEnt = self.StakeEnt
					ent.F1 = false
					ent.StakeLimit = distance+10
					ent:Spawn()

					local const = constraint.Rope(ent, self.StakeEnt, 0, 0, Vector(0, 0, 3), self.StakeEnt:GetUp() * -5, distance, 0, 0, 0.3, "cable/cable", false)
					ent.StakeConst = const

					self:GetOwner():EmitSound("physics/metal/weapon_impact_soft2.wav", 50, 100)
					self:GetOwner():ViewPunch(Angle(4, 0, 0))
					self:Remove()
				end
			end
		end
	end
end

function SWEP:CustomInit()
	self.Activated = false
	self.PinPulled = false
	self:SetTripwireMode(false)
	self:SetTripwireStage(0)
end

function SWEP:OnDrop()
	if self.Activated then
		self:Remove()
	end
end

function SWEP:OnRemove()
	if SERVER and IsValid(self.StakeEnt) and self:GetTripwireStage() < 2 then
		self.StakeEnt:Remove()
	end
end

function SWEP:Holster()
	if SERVER and IsValid(self.StakeEnt) and self:GetTripwireStage() <= 2 then
		self.StakeEnt:Remove()
	end
	return true
end

if CLIENT then
	local mat_laser = Material("sprites/bluelaser1")
	local color_wire = Color(255, 255, 0, 150)
	local color_valid = Color(0, 255, 0, 200)
	local color_invalid = Color(255, 0, 0, 200)

	function SWEP:UpdateGhostPreview()
		if not self:GetTripwireMode() then return end

		local tr = self:GetPlacementTrace()

		if self:GetTripwireStage() == 1 then
			if tr.Hit then
				self.PreviewStakePos = tr.HitPos
				self.PreviewStakeAng = Angle(0, 0, 90)
				self.PreviewStakeValid = true
			end
		elseif self:GetTripwireStage() == 2 then
			if tr.Hit then
				self.PreviewGrenadePos = tr.HitPos + tr.HitNormal * 2
				self.PreviewGrenadeAng = Angle(0, 0, 0)

				local stakePos = self:GetStakePosition()
				if stakePos then
					local distance = tr.HitPos:Distance(stakePos)

					local distanceValid = distance >= 10 and distance <= self.MaxTripwireDistance

					local traceCheck = util.TraceLine({
						start = tr.HitPos + Vector(0, 0, 5),
						endpos = stakePos + Vector(0, 0, 5),
						filter = {LocalPlayer()},
						mask = MASK_SOLID
					})

					local pathClear = true
					if traceCheck.Hit then
						local act = traceCheck.Entity
						if IsValid(act) then
							local alive = MuR.IsAI(act) or act:IsPlayer()
							if !IsValid(LocalPlayer()) or (!alive and (!IsValid(act:GetPhysicsObject()) or !act:GetPhysicsObject():IsMotionEnabled())) or act == LocalPlayer() or alive and act:Health() <= 0 or act:IsKiller() and LocalPlayer():IsKiller() then
								pathClear = true
							else
								pathClear = false
							end
						else
							pathClear = false
						end
					end

					self.PreviewGrenadeValid = distanceValid and pathClear
					self.PreviewDistance = distance
					self.PreviewPathBlocked = not pathClear
				end
			end
		end
	end

	function SWEP:DrawHUD()
		local ply = self:GetOwner()

		if self:GetTripwireMode() then
			local stage = self:GetTripwireStage()
			local text1, text2, statusColor = "", "", color_white

			if stage == 1 then
				text1 = MuR.Language["loot_grenade_trap_stake"]
				text2 = MuR.Language["loot_grenade_trap_controls"]
				if self.PreviewStakeValid ~= nil then
					statusColor = self.PreviewStakeValid and color_valid or color_invalid
				end
			else
				text1 = MuR.Language["loot_grenade_trap_grenade"]
				text2 = MuR.Language["loot_grenade_trap_controls"]
				if self.PreviewGrenadeValid ~= nil then
					statusColor = self.PreviewGrenadeValid and color_valid or color_invalid
				end
			end

			draw.SimpleText(text1, "MuR_Font1", ScrW()/2, ScrH()-He(100), statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(text2, "MuR_Font1", ScrW()/2, ScrH()-He(85), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			if stage == 2 and self.PreviewDistance then
				local distText = MuR.Language["loot_grenade_trap_dist"] .. math.Round(self.PreviewDistance) .. " / " .. self.MaxTripwireDistance
				local distColor = self.PreviewGrenadeValid and color_valid or color_invalid
				draw.SimpleText(distText, "MuR_Font1", ScrW()/2, ScrH()-He(70), distColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			if stage == 1 and self.PreviewStakeValid ~= nil then
				local statusText = MuR.Language["loot_grenade_trap_place"]
				draw.SimpleText(statusText, "MuR_Font1", ScrW()/2, ScrH()/2 + He(50), color_valid, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			elseif stage == 2 and self.PreviewGrenadeValid ~= nil then
				local statusText
				if self.PreviewPathBlocked then
					statusText = MuR.Language["loot_grenade_trap_blocked"]
				elseif not self.PreviewGrenadeValid then
					statusText = MuR.Language["loot_grenade_trap_invalid"]
				else
					statusText = MuR.Language["loot_grenade_trap_place"]
				end
				local statusColor = self.PreviewGrenadeValid and color_valid or color_invalid
				draw.SimpleText(statusText, "MuR_Font1", ScrW()/2, ScrH()/2 + He(50), statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		else
			draw.SimpleText(MuR.Language["loot_grenade_1"], "MuR_Font1", ScrW()/2, ScrH()-He(100), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(MuR.Language["loot_grenade_2"], "MuR_Font1", ScrW()/2, ScrH()-He(85), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	local stake_model = ClientsideModel("models/props_c17/TrapPropeller_Lever.mdl")
	stake_model:SetNoDraw(true)
	local grenade_model = ClientsideModel("models/simpnades/w_m67.mdl")
	grenade_model:SetNoDraw(true)

	hook.Add("PostDrawTranslucentRenderables", "DrawTripwirePreview", function()
		local wep = LocalPlayer():GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "mur_m67" then return end
		if not wep:GetTripwireMode() then return end

		render.SetBlend(0.7)

		local stage = wep:GetTripwireStage()

		if stage == 1 and wep.PreviewStakePos then
			local modelColor = wep.PreviewStakeValid and Color(100, 255, 100, 255) or Color(255, 100, 100, 255)
			stake_model:SetPos(wep.PreviewStakePos)
			stake_model:SetAngles(wep.PreviewStakeAng)
			stake_model:SetColor(modelColor)
			stake_model:DrawModel()
		end

		if stage == 2 then
			local stakePos = wep:GetStakePosition()
			if stakePos and stakePos ~= Vector(0,0,0) then
				local stakeNormal = wep:GetStakeNormal()
				stake_model:SetPos(stakePos + stakeNormal * 2)
				stake_model:SetAngles(Angle(0, 0, 90))
				stake_model:SetColor(Color(150, 150, 150, 255))
				stake_model:DrawModel()
			end

			if wep.PreviewGrenadePos then
				local modelColor = wep.PreviewGrenadeValid and Color(100, 255, 100, 255) or Color(255, 100, 100, 255)
				grenade_model:SetPos(wep.PreviewGrenadePos)
				grenade_model:SetAngles(wep.PreviewGrenadeAng)
				grenade_model:SetColor(modelColor)
				grenade_model:DrawModel()

				if stakePos and stakePos ~= Vector(0,0,0) then
					local wireColor = wep.PreviewGrenadeValid and Color(255, 255, 0, 200) or Color(255, 100, 100, 200)
					render.SetMaterial(mat_laser)
					render.DrawBeam(stakePos + Vector(0, 0, 5), wep.PreviewGrenadePos + Vector(0,0,5), 3, 0, 1, wireColor)
				end
			end
		end

		render.SetBlend(1)
	end)
end

function SWEP:Reload()
	if self:GetTripwireMode() then
		if SERVER then
			self:SetTripwireMode(false)
			self:SetTripwireStage(0)
			self:SetStakePosition(Vector(0,0,0))
			self:SetStakeNormal(Vector(0,0,0))

			if IsValid(self.StakeEnt) then
				self.StakeEnt:Remove()
			end
		end
	end
end

SWEP.Category = "Bloodshed - Illegal"
SWEP.Spawnable = true
