AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.PrintName = "Scanner"
SWEP.Slot = 5

SWEP.WorldModel = "models/murdered/catsenya/props_pocox3nfc/catsenya_pocox3nfc.mdl"
SWEP.ViewModel = "models/weapons/c_bugbait.mdl"

SWEP.WorldModelPosition = Vector(4, -3, 3)
SWEP.WorldModelAngle =  Angle(180, 10, 0)

SWEP.ViewModelPos = Vector(0, -6, -7)
SWEP.ViewModelAng = Angle(0, -10, -45)
SWEP.ViewModelFOV = 70

SWEP.BobScale = 0
SWEP.SwayScale = 0

SWEP.HoldType = "slam"
SWEP.TPIKForce = true

SWEP.ViewModelBoneMods = {
	["ValveBiped.cube3"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(0, 0, 0), angle = Angle(0, 0, 0) }
}
SWEP.VElements = {
	["card"] = { type = "Model", model = "models/murdered/catsenya/props_pocox3nfc/catsenya_pocox3nfc.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "", pos = Vector(3, 3, 3), angle = Angle(180, 0, 12), size = Vector(1.1, 1.1, 1.1), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}

SWEP.ScanRange = 1600
SWEP.ScanDuration = 1.2
SWEP.ScanCost = 25
SWEP.ChargeRate = 4
SWEP.ContactLife = 6
SWEP.UnitsPerMetre = 25

SWEP.WallJitterDeg = 18
SWEP.WallBandMetres = 10
SWEP.MaxContacts = 12

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "Charge")
	self:NetworkVar("Float", 1, "ScanStart")
end

function SWEP:CustomInit()
	self:SetCharge(100)
	self:SetScanStart(0)
end

function SWEP:Deploy(wep)
	self:SetHoldType(self.HoldType)
	return true
end

function SWEP:IsScanning()
	local start = self:GetScanStart()
	return start > 0 and CurTime() < start + self.ScanDuration
end

function SWEP:CustomPrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.4)

	if self:IsScanning() then return end

	if self:GetCharge() < self.ScanCost then
		if CLIENT and IsFirstTimePredicted() then
			surface.PlaySound("buttons/button10.wav")
		end
		return
	end

	if CLIENT then return end

	self:SetCharge(self:GetCharge() - self.ScanCost)
	self:SetScanStart(CurTime())

	local ow = self:GetOwner()
	if IsValid(ow) then
		ow:EmitSound("buttons/blip1.wav", 70, 130)
	end

	timer.Simple(self.ScanDuration, function()
		if not IsValid(self) then return end
		self:RunSweep()
	end)
end

function SWEP:CustomSecondaryAttack()
end

function SWEP:Think()
	if CLIENT then return end

	local charge = self:GetCharge()
	if charge >= 100 then return end

	self:SetCharge(math.min(100, charge + self.ChargeRate * FrameTime()))
end

if SERVER then
	util.AddNetworkString("MuR.ScannerSweep")

	function SWEP:GatherContacts()
		local ow = self:GetOwner()
		if not IsValid(ow) then return {} end

		local origin = ow:EyePos()
		local ownerKiller = ow:IsKiller()
		local out = {}

		for _, ply in player.Iterator() do
			if ply == ow or not ply:Alive() then continue end
			if ownerKiller and ply:IsKiller() then continue end

			local ref = IsValid(ply:GetRD()) and ply:GetRD():WorldSpaceCenter() or ply:EyePos()
			local dist = origin:Distance(ref)
			if dist > self.ScanRange then continue end

			local tr = util.TraceLine({
				start = origin,
				endpos = ref,
				filter = {ow, ply, ow:GetRD(), ply:GetRD()},
				mask = MASK_SOLID_BRUSHONLY
			})

			out[#out + 1] = {
				dist = dist,
				z = ref.z - origin.z,
				yaw = (ref - origin):Angle().y,
				clear = not tr.Hit
			}
		end

		table.sort(out, function(a, b) return a.dist < b.dist end)

		return out
	end

	function SWEP:RunSweep()
		local ow = self:GetOwner()
		if not IsValid(ow) then return end

		local contacts = self:GatherContacts()
		local count = math.min(#contacts, self.MaxContacts)

		net.Start("MuR.ScannerSweep")
		net.WriteUInt(count, 4)

		for i = 1, count do
			local c = contacts[i]
			local dist = c.dist

			if not c.clear then
				local band = self.WallBandMetres * self.UnitsPerMetre
				dist = math.floor(dist / band) * band + band * 0.5
			end

			net.WriteUInt(math.Clamp(math.floor(dist), 0, 4095), 12)
			net.WriteUInt(math.floor((c.yaw % 360) * 4), 11)
			net.WriteInt(math.Clamp(math.floor(c.z / 32), -7, 7), 4)
			net.WriteBool(c.clear)
		end

		net.Send(ow)
	end
end

if CLIENT then
	local We = We or function(x) return x * (ScrW() / 1920) end
	local He = He or function(x) return x * (ScrH() / 1080) end

	local contacts = {}
	local sweepTime = 0

	net.Receive("MuR.ScannerSweep", function()
		local count = net.ReadUInt(4)
		local wep = LocalPlayer():GetActiveWeapon()
		local jitter = IsValid(wep) and wep.WallJitterDeg or 18

		contacts = {}
		sweepTime = CurTime()

		for i = 1, count do
			local dist = net.ReadUInt(12)
			local yaw = net.ReadUInt(11) / 4
			local z = net.ReadInt(4) * 32
			local clear = net.ReadBool()

			if not clear then
				yaw = yaw + math.Rand(-jitter, jitter)
			end

			contacts[#contacts + 1] = {dist = dist, yaw = yaw, z = z, clear = clear}
		end

		surface.PlaySound(count > 0 and "buttons/button17.wav" or "buttons/combine_button2.wav")
	end)

	local function contactAlpha(self)
		local age = CurTime() - sweepTime
		if age >= self.ContactLife then return 0 end
		return 1 - age / self.ContactLife
	end

	function SWEP:DrawHUD()
		local UI = MuR.UI
		local C = UI.Colors

		local size = He(230)
		local x = ScrW() - size - We(48)
		local y = ScrH() - size - He(120)
		local cx, cy = x + size / 2, y + size / 2
		local radius = size / 2 - He(16)

		UI.Rect(x, y, size, size, Color(12, 12, 13, 225))
		UI.Outline(x, y, size, size, C.line)

		surface.SetDrawColor(C.lineSoft)
		for ring = 1, 3 do
			local r = radius * ring / 3
			local segs = 48
			local px, py
			for i = 0, segs do
				local a = math.rad(i / segs * 360)
				local nx, ny = cx + math.cos(a) * r, cy + math.sin(a) * r
				if px then surface.DrawLine(px, py, nx, ny) end
				px, py = nx, ny
			end
		end

		surface.SetDrawColor(C.lineSoft)
		surface.DrawLine(cx - radius, cy, cx + radius, cy)
		surface.DrawLine(cx, cy - radius, cx, cy + radius)

		local scanning = self:IsScanning()
		if scanning then
			local frac = (CurTime() - self:GetScanStart()) / self.ScanDuration
			local a = math.rad(frac * 720)
			surface.SetDrawColor(C.accent)
			surface.DrawLine(cx, cy, cx - math.sin(a) * radius, cy - math.cos(a) * radius)
		end

		local alpha = contactAlpha(self)
		local eyeYaw = LocalPlayer():EyeAngles().y

		if alpha > 0 then
			for _, c in ipairs(contacts) do
				local rel = math.rad(c.yaw - eyeYaw)
				local r = radius * math.Clamp(c.dist / self.ScanRange, 0, 1)
				local bx, by = cx - math.sin(rel) * r, cy - math.cos(rel) * r

				local col = c.clear and Color(219, 52, 48, 255 * alpha)
					or Color(196, 154, 74, 190 * alpha)

				local blip = c.clear and He(5) or He(4)
				UI.Rect(bx - blip / 2, by - blip / 2, blip, blip, col)

				if not c.clear then
					UI.Outline(bx - blip, by - blip, blip * 2, blip * 2, ColorAlpha(col, 70 * alpha))
				end

				if c.z > 64 then
					draw.SimpleText("^", "MuR_Font0", bx, by - He(11), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				elseif c.z < -64 then
					draw.SimpleText("v", "MuR_Font0", bx, by + He(11), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end
		end

		UI.Rect(cx - He(2), cy - He(2), He(4), He(4), C.text)

		local label
		if scanning then
			label = MuR.Language["scanner_sweeping"] or "SWEEPING"
		elseif alpha <= 0 then
			label = MuR.Language["scanner_idle"] or "IDLE"
		elseif #contacts == 0 then
			label = MuR.Language["scanner_clear"] or "NO CONTACTS"
		else
			local nearest = contacts[1]
			label = string.format("%d %s | %d %s", #contacts,
				MuR.Language["scanner_contacts"] or "CONTACTS",
				math.floor(nearest.dist / self.UnitsPerMetre),
				MuR.Language["scanner_metres"] or "M")
		end

		draw.SimpleText(label, "MuR_Font0", cx, y + size + He(10),
			alpha > 0 and C.text or C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		local charge = self:GetCharge()
		UI.Meter(x, y - He(12), size, He(5), charge / 100,
			charge >= self.ScanCost and C.accent or C.sev2, 20)

		draw.SimpleText(MuR.Language["scanner_hint"] or "LMB - sweep", "MuR_Font0",
			cx, y - He(30), C.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end

function SWEP:CalcViewModelView(ViewModel, OldEyePos, OldEyeAng, EyePos, EyeAng)
	if IsValid(self:GetOwner()) then
		local pos = EyePos + (EyeAng:Forward() * -5 + EyeAng:Right() * -7 + EyeAng:Up() * -6)
		EyeAng.z = -45

		return pos, EyeAng
	end
end

function SWEP:OnDrop()
	if self.Called then
		self:Remove()
	end
end

SWEP.Category = "Bloodshed - Illegal"
SWEP.Spawnable = true
