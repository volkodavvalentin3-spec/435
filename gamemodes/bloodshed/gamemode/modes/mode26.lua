MuR.RegisterMode(26, {
	name = "Classic Murder",
	chance = 20,
	need_players = 3,
	disables = true,
	disables_police = true,
	disable_loot = true,
	no_default_roles = true,
	no_guilt = true,
	murder_classic = true,
	custom_spawning = true,
	custom_spawning_func = "Mode26SpawnPlayers",
	timer = 420,

	win_condition = "tdm",
	tdm_end_logic = true,
	win_screen_team1 = "traitor",
	win_screen_team2 = "innocent",
	kteam = "Killer",
	dteam = "Innocent",
	iteam = "Innocent",

	OnModeStarted = function(mode)
		if SERVER then
			timer.Simple(0.5, function()
				if MuR.Gamemode ~= 26 then return end
				MuR:Mode26SpawnRevolvers()
			end)
		end
	end
})

if SERVER then
	local REVOLVERS = {"tfa_bs_cobra", "tfa_bs_mateba", "tfa_bs_ruger"}
	local KILLER_KNIFE = "tfa_bs_knife"

	function MuR:Mode26SpawnPlayers()
		if MuR.Gamemode ~= 26 then return end

		local tab = {}
		for _, ply in player.Iterator() do
			if ply:Team() == 1 or ply:Team() == 2 or ply:Team() == 3 then
				tab[#tab + 1] = ply
			end
		end
		table.Shuffle(tab)

		local killer = table.remove(tab, 1)
		local gunman = table.remove(tab, 1)

		local function launch(ply, class, team)
			if not IsValid(ply) then return end

			ply:SetNW2String("Class", class)
			ply:SetTeam(team)
			ply.ForceSpawn = true
			ply:Spawn()
			ply:Freeze(true)
			ply:GodEnable()

			timer.Simple(12, function()
				if not IsValid(ply) then return end
				ply:Freeze(false)
				ply:GodDisable()
			end)
		end

		launch(killer, "Killer", 1)
		if IsValid(killer) then
			timer.Simple(0.2, function()
				if not IsValid(killer) then return end
				killer:StripWeapons()
				killer:GiveWeapon("mur_hands")
				killer:GiveWeapon(KILLER_KNIFE, true)
			end)
		end

		launch(gunman, "Innocent", 2)
		if IsValid(gunman) then
			timer.Simple(0.2, function()
				if not IsValid(gunman) then return end
				local class = REVOLVERS[math.random(1, #REVOLVERS)]
				gunman:GiveWeapon(class)
				gunman:GiveAmmo(6, "357", true)
			end)
		end

		for _, ply in ipairs(tab) do
			launch(ply, "Innocent", 2)
			timer.Simple(0.2, function()
				if not IsValid(ply) then return end
				ply:StripWeapons()
				ply:GiveWeapon("mur_hands")
			end)
		end
	end

	function MuR:Mode26SpawnRevolvers()
		local count = math.random(1, 2)

		for i = 1, count do
			local pos = MuR:GetRandomPos(tobool(math.random(0, 1)))
			if not isvector(pos) then continue end

			local ent = ents.Create(REVOLVERS[math.random(1, #REVOLVERS)])
			if not IsValid(ent) then continue end

			ent:SetPos(pos + Vector(0, 0, 5))
			ent:Spawn()
			ent:SetClip1(math.random(1, 3))
		end
	end

	local function IsClassicKiller(ply)
		return MuR.Gamemode == 26 and IsValid(ply) and ply:IsPlayer()
			and ply:GetNW2String("Class") == "Killer"
	end

	local function IsFirearm(wep)
		if not IsValid(wep) then return false end
		if not wep.Primary then return false end

		local ammo = wep.Primary.Ammo
		return isstring(ammo) and ammo ~= "" and ammo ~= "none"
	end

	hook.Add("WeaponEquip", "MuR.Mode26NoGuns", function(wep, ply)
		if not IsClassicKiller(ply) then return end
		if not IsFirearm(wep) then return end

		timer.Simple(0, function()
			if not IsValid(wep) or not IsValid(ply) then return end
			ply:DropWeapon(wep)
		end)
	end)

	hook.Add("EntityTakeDamage", "MuR.Mode26OneShot", function(ent, dmg)
		if MuR.Gamemode ~= 26 then return end
		if not IsValid(ent) or not ent:IsPlayer() then return end

		local att = dmg:GetAttacker()
		if not IsValid(att) or not att:IsPlayer() then return end

		local inflictor = dmg:GetInflictor()
		local class = IsValid(inflictor) and inflictor:GetClass() or ""

		if class == KILLER_KNIFE or table.HasValue(REVOLVERS, class) then
			dmg:SetDamage(10000)
		end
	end)
end
