local disableReverbList = {
	["tfa_bs_vp9"] = true,
	["tfa_bs_chainsaw"] = true,
}

util.AddNetworkString("MuR.Reverb")

local AMMOTYPE_MAP = {
	["357"] = "357",
	["AR2"] = "ar2",
	["Pistol"] = "pistol",
	["SMG1"] = "smg1",
	["Buckshot"] = "buckshot",
	["SniperRound"] = "357",
	["SniperPenetratedRound"] = "357",
	["AirboatGun"] = "ar2",
	["StriderMinigun"] = "ar2",
	["XBowBolt"] = "ar2",
	["Grenade"] = "explosions",
	["RPG_Round"] = "explosions",
	["SMG1_Grenade"] = "explosions"
}

local function GetAmmoType(weapon)
	if not IsValid(weapon) then return "other" end
	if !weapon.IsWeapon or !weapon:IsWeapon() or weapon:GetMaxClip1() <= 0 then return "none" end

	local ammoType = weapon:GetPrimaryAmmoType()
	if ammoType < 0 then return "other" end

	local ammoName = game.GetAmmoName(ammoType)
	return AMMOTYPE_MAP[ammoName] or "other"
end

local SKY_SAMPLE_OFFSETS = {
	Vector(0, 0, 16384),
	Vector(256, 0, 16384),
	Vector(-256, 0, 16384),
	Vector(0, 256, 16384),
	Vector(0, -256, 16384),
	Vector(192, 192, 16384),
	Vector(-192, 192, 16384),
	Vector(192, -192, 16384),
	Vector(-192, -192, 16384)
}

local function IsIndoors(pos)
	local skyHits = 0
	local solidHits = 0

	for _, offset in ipairs(SKY_SAMPLE_OFFSETS) do
		local tr = util.TraceLine({
			start = pos,
			endpos = pos + offset,
			mask = MASK_SOLID_BRUSHONLY
		})

		if tr.Hit then
			if tr.HitSky then
				skyHits = skyHits + 1
			else
				solidHits = solidHits + 1
			end
		else
			skyHits = skyHits + 1
		end
	end

	local total = skyHits + solidHits
	if total == 0 then return false end

	local skyRatio = skyHits / total
	return skyRatio < 0.35
end

local function GetDistanceType(listenerPos, shootPos)
	local dist = listenerPos:Distance(shootPos)
	return dist <= 1200 and "close" or "distant"
end

function MakeExplosionReverb(pos)
	local ammoType = "explosions"
	local envType = IsIndoors(pos) and "indoors" or "outdoors"

	for _, ply in player.Iterator() do
		if IsValid(ply) then
			local distType = GetDistanceType(ply:GetPos(), pos)

			net.Start("MuR.Reverb")
			net.WriteVector(pos)
			net.WriteString(ammoType)
			net.WriteString(envType)
			net.WriteString(distType)
			net.Send(ply)
		end
	end
end

hook.Add("EntityFireBullets", "MuR.Reverb", function(ent, data)
	if not IsValid(ent) then return end

	local weapon = ent:IsPlayer() and ent:GetActiveWeapon() or MuR.IsAI(ent) and ent:GetActiveWeapon() or ent:GetClass() == "murwep_ragdoll_weapon" and ent.Weapon or ent
	if not IsValid(weapon) then return end
	if disableReverbList[weapon:GetClass()] then return end

	local shootPos = data.Src or ent:GetPos()
	local ammoType = GetAmmoType(weapon)
	local envType = IsIndoors(shootPos) and "indoors" or "outdoors"

	for _, ply in player.Iterator() do
		if IsValid(ply) then
			local distType = GetDistanceType(ply:GetPos(), shootPos)

			net.Start("MuR.Reverb")
			net.WriteVector(shootPos)
			net.WriteString(ammoType)
			net.WriteString(envType)
			net.WriteString(distType)
			net.WriteEntity(ent)
			net.Send(ply)
		end
	end
end)
