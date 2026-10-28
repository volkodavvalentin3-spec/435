AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.PrintName = "Pepper Spray"
SWEP.Slot = 0
SWEP.DisableSuicide = true

SWEP.WorldModel = "models/murdered/weapons/pepperspray/pepperspray.mdl"
SWEP.ViewModel = "models/murdered/weapons/pepperspray/v_pepperspray.mdl"

SWEP.WorldModelPosition = Vector(3, -1, 1)
SWEP.WorldModelAngle =  Angle(180, 80, 0)

SWEP.ViewModelPos = Vector(0, -4, -4)
SWEP.ViewModelAng = Angle(-3, 3, -3)
SWEP.ViewModelFOV = 70

SWEP.HoldType = "pistol"

SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Battery"
SWEP.Primary.ClipSize = 5
SWEP.Primary.DefaultClip = 5
SWEP.Secondary.Ammo = ""

function SWEP:Deploy( wep )
	self:SendWeaponAnim(ACT_VM_DRAW)
	self:SetHoldType(self.HoldType)
end

function SWEP:CustomPrimaryAttack()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	if self:Clip1() <= 0 then return end

	ply:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	if CLIENT then return end

	self:TakePrimaryAmmo(1)
	ply:EmitSound('murdered/weapons/other/pepperspray.wav', 70, 100, 1, CHAN_WEAPON)

	local startPos = ply:EyePos()
	local fwd = ply:GetAimVector()
	local maxDist = 180

	local segments = {
		{dist = 50,  rad = 4},
		{dist = 100, rad = 6},
		{dist = 150, rad = 8},
		{dist = 180, rad = 10},
	}

	local hitEntities = {}
	local impactPos = startPos + fwd * maxDist
	for _, seg in ipairs(segments) do
		local tr = util.TraceHull({
			start = startPos,
			endpos = startPos + fwd * seg.dist,
			mins = Vector(-seg.rad, -seg.rad, -seg.rad),
			maxs = Vector(seg.rad, seg.rad, seg.rad),
			filter = {ply, ply:GetRD()}
		})
		if tr.Hit then
			impactPos = tr.HitPos
			if IsValid(tr.Entity) then
				table.insert(hitEntities, tr.Entity)
			end
			break
		end
	end

	local fx = EffectData()
	fx:SetOrigin(startPos)
	fx:SetStart(impactPos)
	fx:SetNormal(fwd)
	util.Effect("mur_pepper_spray", fx, true, true)
	local fx2 = EffectData()
	fx2:SetOrigin(impactPos)
	fx2:SetNormal(fwd)
	util.Effect("mur_pepper_impact", fx2, true, true)

	for _, e in ipairs(ents.FindInSphere(impactPos, 60)) do
		if IsValid(e) and e ~= ply then
			table.insert(hitEntities, e)
		end
	end

	local seen = {}
	for _, tar in ipairs(hitEntities) do
		if IsValid(tar) and not seen[tar] then
			seen[tar] = true
			if tar.isRDRag and IsValid(tar.Owner) then
				tar = tar.Owner
			end

			if tar:IsPlayer() then
				if not tar:Alive() or tar:GetObserverMode() > 0 then continue end

				local protection = tar.GetPepperProtectionLevel and tar:GetPepperProtectionLevel() or 0
				if protection >= 1 then continue end

				local dist = tar:EyePos():Distance(startPos)
				local dur = math.Clamp(18 - dist * 0.05, 8, 18)
				dur = dur * (1 - protection)

				if dur > 1 then
					tar.peppertimevoice = CurTime() + 0.2
					tar:SetNW2Float('peppereffect', CurTime() + dur)
					tar:ViewPunch(Angle(math.Rand(-2, -6), math.Rand(-2, 2), 0))
					tar:TakeDamage(1, ply)
				end
			elseif tar.SuspectNPC then
				if not tar.Surrendering and tar.FullSurrender then
					tar:FullSurrender()
				end
			elseif tar.IsCivilian then
				if tar.AddFear then tar:AddFear(60, ply:GetPos()) end
				if not tar.Surrendering then
					tar.Surrendering = true
					tar.PermanentSurrender = true
				end
			end
		end
	end

	timer.Simple(0.25, function()
		if IsValid(self) then self:SendWeaponAnim(ACT_VM_SECONDARYATTACK) end
	end)

	self:SetNextPrimaryFire(CurTime() + 1.2)
end

function SWEP:CustomInit()

end

function SWEP:CustomSecondaryAttack()

end

if CLIENT then
	local blur = Material("pp/blurscreen")

	hook.Add("HUDPaint", "MuRPepper", function()
		local untilTime = LocalPlayer():GetNW2Float('peppereffect')
		if untilTime > CurTime() then
			local sw, sh = ScrW(), ScrH()
			surface.SetMaterial(blur)
			for i=1,3 do
				blur:SetFloat("$blur", i * 32)
				blur:Recompute()
				render.UpdateScreenEffectTexture()
				surface.SetDrawColor(255,255,255, 90)
				surface.DrawTexturedRect(0, 0, sw, sh)
			end
			local t = untilTime - CurTime()
			local pulse = 35 + math.abs(math.sin(CurTime()*2))*50
			surface.SetDrawColor(200, 40, 10, pulse)
			surface.DrawRect(0, 0, sw, sh)
		end
	end)

	hook.Add("AdjustMouseSensitivity", "MuRPepper", function()
		if LocalPlayer():GetNW2Float('peppereffect') > CurTime() then
			return 0.3
		end
	end)
end
SWEP.Category = "Bloodshed - Civilian"
SWEP.Spawnable = true
