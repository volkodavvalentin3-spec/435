if not SERVER then return end

MuR = MuR or {}

MuR.MapItemReplacements = {
	["item_healthkit"]    = "mur_loot_medkit",
	["item_healthvial"]   = "mur_loot_bandage",
	["item_battery"]      = {"mur_loot_adrenaline", "mur_morphine", "mur_naloxone", "mur_atropine", "mur_mannitol"},

	["weapon_frag"]       = {"mur_f1", "mur_m67"},
	["weapon_slam"]       = "mur_ied",
	["weapon_rpg"]        = "tfa_bs_rpg7",
	["weapon_357"]        = {"tfa_bs_mateba", "tfa_bs_cobra"},
	["weapon_pistol"]     = "tfa_bs_usp",
	["weapon_smg1"]       = "tfa_bs_mp7",
	["weapon_shotgun"]    = "tfa_bs_spas",
	["weapon_stunstick"]  = "tfa_bs_baton",
	["weapon_crowbar"]    = "tfa_bs_crowbar",
	["weapon_crossbow"]   = {"tfa_bs_mosin", "tfa_bs_kar98"}
}

local function pickReplacement(class)
	local repl = MuR.MapItemReplacements[class]
	if istable(repl) then return repl[math.random(#repl)] end
	return repl
end

local function isLooseWorldItem(ent)
	if IsValid(ent:GetOwner()) then return false end
	if IsValid(ent:GetParent()) then return false end
	if ent:GetSolid() == SOLID_NONE then return false end

	return true
end

function MuR.ReplaceMapItem(ent)
	if not IsValid(ent) then return end
	if ent.MuR_Replacement then return end

	local class = pickReplacement(ent:GetClass())
	if not class then return end
	if not isLooseWorldItem(ent) then return end

	local pos, ang = ent:GetPos(), ent:GetAngles()

	local new = ents.Create(class)
	if not IsValid(new) then
		local attempts = (ent.MuR_ReplaceAttempts or 0) + 1
		ent.MuR_ReplaceAttempts = attempts

		if attempts <= 5 then
			timer.Simple(2, function()
				MuR.ReplaceMapItem(ent)
			end)
		end

		return
	end

	new.MuR_Replacement = true
	new:SetPos(pos)
	new:SetAngles(ang)
	new:Spawn()
	new:Activate()

	ent:Remove()

	return new
end

hook.Add("OnEntityCreated", "MuR.ReplaceMapItems", function(ent)
	if not IsValid(ent) then return end
	if not MuR.MapItemReplacements[ent:GetClass()] then return end

	timer.Simple(0.01, function()
		MuR.ReplaceMapItem(ent)
	end)
end)

function MuR.ReplaceExistingMapItems()
	local count = 0

	for class in pairs(MuR.MapItemReplacements) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if MuR.ReplaceMapItem(ent) then count = count + 1 end
		end
	end

	return count
end

hook.Add("MuR.GameState", "MuR.ReplaceMapItemsInitial", function(state)
	if state != true then return end
	timer.Simple(1, MuR.ReplaceExistingMapItems)
end)
