if not MuR or not MuR.Armor or not istable(MuR.Armor.Items) then return end

MuR.Armor.SpawnCategory = "Bloodshed - Armor"
MuR.Armor.SpawnClasses = MuR.Armor.SpawnClasses or {}

local function spawnClass(id)
	return "mur_armor_" .. id
end

MuR.Armor.SpawnClass = spawnClass

local function displayName(id)
	local name = MuR.Language and MuR.Language["armor_item_" .. id]
	if name and name ~= "" then return name end

	return id
end

do
	local ids = {}
	for id in pairs(MuR.Armor.Items) do ids[#ids + 1] = id end
	table.sort(ids)

	for _, id in ipairs(ids) do
		local class = spawnClass(id)

		scripted_ents.Register({
			Type = "anim",
			Base = "mur_armor_pickup",

			PrintName = displayName(id),
			Category = MuR.Armor.SpawnCategory,
			Spawnable = true,
			AdminOnly = false,

			ArmorId = id,

			IconOverride = "entities/" .. class .. ".png"
		}, class)

		MuR.Armor.SpawnClasses[id] = class
	end
end

if CLIENT then
	hook.Add("LanguageChanged", "MuR.ArmorSpawnNames", function()
		timer.Simple(0, function()
			for id, class in pairs(MuR.Armor.SpawnClasses) do
				local stored = scripted_ents.GetStored(class)
				if stored and stored.t then stored.t.PrintName = displayName(id) end
			end
		end)
	end)
end
