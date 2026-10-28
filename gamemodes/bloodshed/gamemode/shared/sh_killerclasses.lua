MuR = MuR or {}
MuR.KillerClasses = {}
MuR.KillerClassSets = {}

MuR.KILLER_SANITY_MAX_MINUTES = 10

MuR.KILLER_SANITY_SECONDS = 1000

function MuR.KillerSanityMinutes(def)
	return def and def.minutes or nil
end

function MuR.KillerSanityDrain(def)
	if not def or not def.minutes then return nil end
	return MuR.KILLER_SANITY_SECONDS / (def.minutes * 60)
end

local function reg(def)
	MuR.KillerClasses[def.id] = def

	local modes = def.modes or {def.mode}
	def.modes = modes
	def.mode = modes[1]

	local set
	for _, m in ipairs(modes) do
		set = set or MuR.KillerClassSets[m]
	end

	if not set then
		set = {order = {}, ids = {}, modes = {}, key = modes[1]}
	end

	for _, m in ipairs(modes) do
		MuR.KillerClassSets[m] = set
		if not table.HasValue(set.modes, m) then set.modes[#set.modes + 1] = m end
	end

	set.order[#set.order + 1] = def.id
	set.ids[def.id] = true
	if def.default then set.default = def.id end
end

function MuR.GetKillerClass(mode, id)
	local set = MuR.KillerClassSets[mode]
	if not set then return nil end

	local def = MuR.KillerClasses[id]
	if def and set.ids[def.id] then return def end

	return MuR.KillerClasses[set.default]
end

function MuR.KillerClassConVar(mode)
	local set = MuR.KillerClassSets[mode]
	return "blsd_killerclass_" .. ((set and set.key) or mode)
end

local function give(ply, list, cantdrop)
	for _, class in ipairs(list) do
		ply:GiveWeapon(class, cantdrop)
	end
end

local function givePick(ply, pool, count, cantdrop)
	local copy = table.Copy(pool)

	for _ = 1, math.min(count, #copy) do
		local i = math.random(#copy)
		ply:GiveWeapon(copy[i], cantdrop)
		table.remove(copy, i)
	end
end

local STIM = {"mur_loot_heroin", "mur_loot_adrenaline"}
local GRENADES = {"mur_f1", "mur_m67"}
local EXPLOSIVES = {"mur_ied", "mur_c4", "mur_f1", "mur_m67", "mur_molotov", "mur_flashbang"}

local AGENTS_QUIET = {"mur_cyanide", "mur_tranq", "mur_succinylcholine", "mur_potassium", "mur_chloroform"}

local AGENTS_FULL = {
	"mur_cyanide", "mur_poisoncanister", "mur_tranq", "mur_bredogen", "mur_chloroform",
	"mur_ketamine", "mur_insulin", "mur_digoxin", "mur_potassium", "mur_succinylcholine",
	"mur_strychnine", "mur_nerve_agent", "mur_chlorine_gas", "mur_co_canister",
	"mur_pills_warfarin", "mur_pills_thallium"
}

MuR.KillerModeExtras = {
	[7] = function(ply)
		ply:GiveWeapon("tfa_bs_cobra")
		ply:GiveAmmo(18, "357", true)
	end
}

reg({
	id = "murderer", modes = {1, 7}, role = "Killer", default = true,
	minutes = 6, tier = "medium",
	loadout = function(ply)
		give(ply, {"tfa_bs_combk", "mur_poisoncanister", "mur_cyanide",
			"mur_disguise", "mur_scanner", "mur_break_tool", "mur_trap_kit", "mur_chemistry_illegal"}, true)
		ply:GiveWeapon(table.Random(STIM))
	end
})

reg({
	id = "psycho", modes = {1, 7}, role = "Killer",
	minutes = 4.5, tier = "low",
	loadout = function(ply)
		give(ply, {"tfa_bs_fireaxe_maniac", "mur_gasoline", "mur_break_tool"}, true)
		ply:GiveWeapon(table.Random(STIM))
	end
})

reg({
	id = "lurker", modes = {1, 7}, role = "Killer",
	minutes = 10, tier = "veryhigh",
	staminaMul = 1.35,
	loadout = function(ply)
		give(ply, {"tfa_bs_compactk", "mur_disguise", "mur_scanner"}, true)
	end
})

reg({
	id = "chemist", modes = {1, 7}, role = "Killer",
	minutes = 6, tier = "medium",
	loadout = function(ply)
		give(ply, {"tfa_bs_wrench", "mur_chemistry_illegal", "mur_trap_kit", "mur_break_tool"}, true)
		givePick(ply, AGENTS_FULL, 3, true)
	end
})

reg({
	id = "shooter", modes = {4, 8, 25}, role = "Traitor", default = true,
	minutes = 4.5, tier = "low",
	loadout = function(ply)
		ply:GiveWeapon("tfa_bs_vp9")
		ply:GiveAmmo(30, "Pistol", true)
		give(ply, {"tfa_bs_combk", "mur_disguise", "mur_scanner", "mur_break_tool",
			"mur_trap_kit", "mur_chemistry_illegal"}, true)
		ply:GiveWeapon(table.Random(STIM))
	end
})

reg({
	id = "hunter", modes = {4, 8, 25}, role = "Traitor",
	minutes = 3, tier = "verylow",
	loadout = function(ply)
		ply:GiveWeapon("tfa_bs_glock_t")
		ply:GiveAmmo(51, "Pistol", true)
		give(ply, {"tfa_bs_machete", "mur_break_tool"}, true)
		ply:GiveWeapon(table.Random(GRENADES), true)
		ply:GiveWeapon(table.Random(STIM))
	end
})

reg({
	id = "assassin", modes = {4, 8, 25}, role = "Traitor",
	minutes = 8, tier = "high",
	bypassDying = true,
	staminaMul = 1.6,
	loadout = function(ply)
		give(ply, {"tfa_bs_combk", "mur_disguise", "mur_scanner"}, true)
		givePick(ply, AGENTS_QUIET, 2, true)
	end
})

reg({
	id = "chemist_t", modes = {4, 8, 25}, role = "Traitor",
	minutes = 6, tier = "medium",
	loadout = function(ply)
		give(ply, {"tfa_bs_compactk", "mur_chemistry_illegal", "mur_trap_kit", "mur_break_tool"}, true)
		givePick(ply, EXPLOSIVES, 2, true)
		givePick(ply, AGENTS_FULL, 2, true)
	end
})

local MANIAC_KIT = {"mur_gasoline", "mur_loot_ducttape", "mur_ziptie", "mur_scanner", "mur_beartrap"}

local function maniacModels()
	local out = {}
	for _, id in ipairs({"jason", "leatherface", "myers", "ghostface"}) do
		local def = MuR.KillerClasses[id]
		if def and def.model then out[#out + 1] = def.model end
	end
	return out
end

MuR.ManiacClassModels = maniacModels

reg({
	id = "jason", modes = {3}, role = "Maniac", default = true,
	ability = "relentless",
	model = "models/murdered/pm/mkx_jason.mdl",
	armor = 150,
	walk = 170, run = 240,
	loadout = function(ply)
		give(ply, {"tfa_bs_fireaxe_maniac"}, true)
		give(ply, MANIAC_KIT, true)
	end
})

reg({
	id = "leatherface", modes = {3}, role = "Maniac",
	ability = "roar",
	model = "models/murdered/pm/leather.mdl",
	armor = 100,
	walk = 175, run = 285,
	loadout = function(ply)
		give(ply, {"tfa_bs_chainsaw"}, true)
		give(ply, MANIAC_KIT, true)
	end
})

reg({
	id = "myers", modes = {3}, role = "Maniac",
	ability = "stillness",
	model = "models/murdered/pm/mikemyerscodg.mdl",
	armor = 75,
	walk = 190, run = 300,
	loadout = function(ply)
		give(ply, {"tfa_bs_knife"}, true)
		give(ply, MANIAC_KIT, true)
	end
})

reg({
	id = "ghostface", modes = {3}, role = "Maniac",
	ability = "backstab",
	model = "models/murdered/pm/ghostface.mdl",
	armor = 60,
	walk = 200, run = 345,
	staminaMul = 1.5,
	loadout = function(ply)
		give(ply, {"tfa_bs_machete"}, true)
		give(ply, MANIAC_KIT, true)
	end
})
