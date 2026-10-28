AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.PrintName = "Role Detector"
SWEP.Slot = 0
SWEP.ViewModel = "models/weapons/c_bugbait.mdl"
SWEP.WorldModel = "models/murdered/catsenya/props_pocox3nfc/catsenya_pocox3nfc.mdl"

SWEP.WorldModelPosition = Vector(4, -3, 3)
SWEP.WorldModelAngle =  Angle(180, 10, 0)

SWEP.ViewModelPos = Vector(0, -6, -7)
SWEP.ViewModelAng = Angle(0, -10, -40)
SWEP.ViewModelFOV = 70

SWEP.HoldType = "slam"

SWEP.ViewModelBoneMods = {
	["ValveBiped.cube3"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) }
}
SWEP.VElements = {
	["card"] = { type = "Model", model = "models/murdered/catsenya/props_pocox3nfc/catsenya_pocox3nfc.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "", pos = Vector(3, 3, 3), angle = Angle(180, 0, 12), size = Vector(1.1, 1.1, 1.1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Scanning")
	self:NetworkVar("Entity", 0, "ScanTarget")
	self:NetworkVar("Float", 0, "ScanStartTime")
end

function SWEP:Deploy( wep )
	self:SetHoldType(self.HoldType)
	self:SetScanning(false)
	self:SetScanTarget(nil)
end

function SWEP:CustomPrimaryAttack()
    if self:GetScanning() then return end

    local ow = self:GetOwner()
	local tr = util.TraceLine({
		start = ow:GetShootPos(),
		endpos = ow:GetShootPos() + ow:GetAimVector() * 100,
		filter = ow,
		mask = MASK_SHOT_HULL
	})
	local tar = tr.Entity
	if IsValid(tar) and (tar.isRDRag or tar:IsRagdoll()) and IsValid(tar.Owner) then
		tar = tar.Owner
	end
	if IsValid(tar) and tar:IsPlayer() then
        self:SetScanning(true)
		self:SetScanTarget(tar)
		self:SetScanStartTime(CurTime())
		if SERVER then
            self:EmitSound("buttons/combine_button1.wav")
		end
	end
end

function SWEP:Think()
	if self:GetScanning() then
		local ow = self:GetOwner()
		local tar = self:GetScanTarget()

		local tr = util.TraceLine({
			start = ow:GetShootPos(),
			endpos = ow:GetShootPos() + ow:GetAimVector() * 120,
			filter = ow,
			mask = MASK_SHOT_HULL
		})

		local valid = IsValid(tar) and (tr.Entity == tar or (tar:IsPlayer() and IsValid(tr.Entity) and tr.Entity.Owner == tar))

		if not valid or ow:GetShootPos():Distance(tar:GetPos()) > 150 then
			self:SetScanning(false)
			self:SetScanTarget(nil)
			if SERVER then
				self:EmitSound("buttons/combine_button_locked.wav")
			end
			return
		end

		if CurTime() - self:GetScanStartTime() >= 2 then
			if SERVER then
				self:EmitSound("buttons/button24.wav")
				self:Remove()
			else
				local role = tar:GetNW2String("Class", "none")
				local langStr = (MuR.Language["roledetector_detect"] or "Role: ") .. (MuR.Language[string.lower(role)] or role)
				ow:ChatPrint(langStr)
			end
			self:SetScanning(false)
		end
	end
end

function SWEP:Holster()
	self:SetScanning(false)
	self:SetScanTarget(nil)
	return true
end

function SWEP:OnDrop()
    self:SetScanning(false)
	self:SetScanTarget(nil)
end

function SWEP:CustomSecondaryAttack()

end

function SWEP:DrawHUD()
	local ply = self:GetOwner()
	local w, h = ScrW(), ScrH()

	if self:GetScanning() then
		local progress = math.Clamp((CurTime() - self:GetScanStartTime()) / 2, 0, 1)
		local barW, barH = We(300), He(10)
		local x, y = w/2 - barW/2, h/2 + He(100)

		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(x, y, barW, barH)

		surface.SetDrawColor(200, 20, 20, 255)
		surface.DrawRect(x + 2, y + 2, (barW - 4) * progress, barH - 4)

		draw.SimpleText("ANALYZING BIOMETRICS...", "MuR_Font1", w/2, y - He(20), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, math.random(5, 15))
		surface.DrawRect(0, 0, w, h)
	else
		draw.SimpleText(MuR.Language["roledetector_desc"], "MuR_Font1", w/2, h - He(100), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end
SWEP.Category = "Bloodshed - Civilian"
SWEP.Spawnable = true
