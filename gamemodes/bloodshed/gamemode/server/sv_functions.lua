local meta = FindMetaTable("Player")
util.AddNetworkString("MuR.SendDataToClient")
util.AddNetworkString("MuR.PlaySoundOnClient")
util.AddNetworkString("MuR.ChatAdd")
util.AddNetworkString("MuR.Announce")
util.AddNetworkString("MuR.Message")
util.AddNetworkString("MuR.Message2")
util.AddNetworkString("MuR.Countdown")
util.AddNetworkString("MuR.Notify")
util.AddNetworkString("MuR.FinalScreen")
util.AddNetworkString("MuR.ViewPunch")
util.AddNetworkString("MuR.PainImpulse")
util.AddNetworkString("MuR.StartScreen")
util.AddNetworkString("MuR.SyncGamemode")
util.AddNetworkString("MuR.VoiceLines")
util.AddNetworkString("MuR.ShowLogScreen")
util.AddNetworkString("MuR.CalcView")
util.AddNetworkString("MuR.BodySearch")
util.AddNetworkString("MuR.RemoveItemFromSearch")
util.AddNetworkString("MuR.SetHull")
util.AddNetworkString("MuR.WeaponryEffect")
util.AddNetworkString("MuR.BloodDamageSound")
util.AddNetworkString("MuR.Storm.Start")
util.AddNetworkString("MuR.Storm.End")
util.AddNetworkString("MuR.Storm.Thunder")
util.AddNetworkString("MuR.Storm.WindDirection")
util.AddNetworkString("MuR.CraftingMessage")
util.AddNetworkString("MuR.ZombieDeathAnim")
util.AddNetworkString("MuR.ExecuteString")
util.AddNetworkString("MuR.ResetPain")
util.AddNetworkString("MuR.TripwireMinigame")
util.AddNetworkString("MuR.TripwireResult")

MuR.guiltSession = {}
file.CreateDir("bloodshed/guilt/")

timer.Simple(1, function()
	if MuR.EnableDebug then
		MuR.GameStarted = true
		MuR.Gamemode = 5
	end
end)

local WeaponCategories = {
	["Bloodshed - Shotguns"] = "Primary",
	["Bloodshed - Sniper Rifles"] = "Primary",
	["Bloodshed - Marksmans"] = "Primary",
	["Bloodshed - Submachine Guns"] = "Primary",
	["Bloodshed - Machine Guns"] = "Primary",
	["Bloodshed - Rifles"] = "Primary",
	["Bloodshed - Sidearms"] = "Secondary",
	["Bloodshed - Melee"] = "Melee"
}

function MuR:GenerateWeaponsTable()
	local weaponsTable = {
		["Primary"] = {},
		["Secondary"] = {},
		["Melee"] = {}
	}

	for id, weaponData in pairs(weapons.GetList()) do
		local category = weaponData.Category
		local weaponType = WeaponCategories[category]
		local className = weaponData.ClassName
		if weaponData.IsTraitorGun then continue end
		if weaponType then
			local ammoType = ""
			local ammoCount = 0

			if weaponData.Primary then
				ammoType = weaponData.Primary.Ammo or ""
				ammoCount = weaponData.Primary.ClipSize or 0
			end

			table.insert(weaponsTable[weaponType], {
				class = className,
				ammo = ammoType,
				count = ammoCount
			})
		end
	end

	return weaponsTable
end

-- Таблица оружия могла собраться до регистрации TFA-оружия и остаться пустой:
-- тогда roles/soldier.lua падает на table.Random(пусто) и лодаут не выдаётся.
function MuR:EnsureWeaponsTable()
	local t = MuR.WeaponsTable
	if t and t["Primary"] and #t["Primary"] > 0 and t["Secondary"] and #t["Secondary"] > 0 then return end
	MuR.WeaponsTable = MuR:GenerateWeaponsTable()
end

local function GetRandomPlayer(exclude)
    local players = {}
    for _, ply in player.Iterator() do
        if ply:Alive() and ply ~= exclude then
            table.insert(players, ply)
        end
    end
    return #players > 0 and players[math.random(#players)] or nil
end

function meta:PlayNZDeathAnim(pos, class)
	pos = pos or self:GetPos()
	class = class or ""

	for _, ent in ipairs(ents.FindInSphere(pos, 200)) do
		if MuR.IsAI(ent) then
			local cl = ent:GetClass()
			if MuR.DeathAnimClasses[cl] then
				class = cl
				break
			end
		end
	end

	net.Start("MuR.ZombieDeathAnim")
	net.WriteVector(pos)
	net.WriteString(class)
	net.Send(self)
end

local function GiveWeaponNow(ply, class, cantdrop)
	local ent = ents.Create(class)
	if not IsValid(ent) or not IsValid(ply) then return end
	ent:SetPos(ply:GetPos())
	ent.GiveToPlayer = ply
	ent.CantDrop = cantdrop

	if ent.IsTFAWeapon then
		ent.Primary.DefaultClip = ent.Primary.ClipSize
	end

	ent:Spawn()

	if ent.ClipSize then
		ent:SetClip1(ent.ClipSize)
		ent:SetClip2(0)
	end

	if IsValid(ent) then
		ply:PickupWeapon(ent)
		ent.GiveToPlayer = nil
	end
end

function meta:GiveWeapon(class, cantdrop, immediate)
	-- The spawnmenu path has to hand the weapon over before sandbox checks
	-- `HasWeapon`, otherwise sandbox gives a second copy through `ply:Give`.
	if immediate then
		GiveWeaponNow(self, class, cantdrop)
		return
	end

	timer.Simple(0.01, function()
		GiveWeaponNow(self, class, cantdrop)
	end)
end

function meta:NewHull()
	local tab = {Vector(-10, -10, 0), Vector(10, 10, 72), Vector(-10, -10, 0), Vector(10, 10, 38)}
	self:SetHull(tab[1], tab[2])
	self:SetHullDuck(tab[3], tab[4])
	net.Start("MuR.SetHull")
	net.WriteTable(tab)
	net.Send(self)
end

function meta:RandomSkin()
	if self.RandomSkinDisabled then return end

	local skinCount = self:SkinCount()
	local randomSkin = math.random(0, skinCount - 1)
	self:SetSkin(randomSkin)

	for i = 0, self:GetNumBodyGroups() - 1 do
		local bodyGroupCount = self:GetBodygroupCount(i)
		local randomBodyGroup = math.random(0, bodyGroupCount - 1)
		self:SetBodygroup(i, randomBodyGroup)
	end
end

local function isValidNameString(name)
    if not name then return false end
    if utf8.len(name) > 25 then return false end

	local havespace = false
    for p, c in utf8.codes(name) do
        local isLetter = (c >= 65 and c <= 90) or
                       (c >= 97 and c <= 122) or
                       (c >= 1040 and c <= 1103) or
                       c == 1025 or c == 1105 or
                       c == 32

        if not isLetter or havespace and c == 32 then
            return false
        end
		if c == 32 then
			havespace = true
		end
    end

    return true
end

local mumble = {
	en = {
		vowels = {
			["a"] = true, ["e"] = true, ["i"] = true, ["o"] = true, ["u"] = true, ["y"] = true,
			["A"] = true, ["E"] = true, ["I"] = true, ["O"] = true, ["U"] = true, ["Y"] = true
		},
		vowelLower = {"a", "e", "o", "u"},
		vowelUpper = {"A", "E", "O", "U"},
		consonantLower = {"m", "n", "h", "f", "w"},
		consonantUpper = {"M", "N", "H", "F", "W"}
	},
	ru = {
		vowels = {
			["а"] = true, ["е"] = true, ["ё"] = true, ["и"] = true, ["о"] = true, ["у"] = true, ["ы"] = true, ["э"] = true, ["ю"] = true, ["я"] = true,
			["А"] = true, ["Е"] = true, ["Ё"] = true, ["И"] = true, ["О"] = true, ["У"] = true, ["Ы"] = true, ["Э"] = true, ["Ю"] = true, ["Я"] = true
		},
		vowelLower = {"а", "э", "о", "у", "ы"},
		vowelUpper = {"А", "Э", "О", "У", "Ы"},
		consonantLower = {"м", "н", "л", "х", "ш", "ф"},
		consonantUpper = {"М", "Н", "Л", "Х", "Ш", "Ф"}
	}
}

local function charCode(ch)
	for _, code in utf8.codes(ch) do
		return code
	end
end

local function hasCyrillic(text)
	for _, code in utf8.codes(text) do
		if (code >= 1040 and code <= 1103) or code == 1025 or code == 1105 then
			return true
		end
	end

	return false
end

local function charInfo(ch)
	local code = charCode(ch)
	if not code then return end

	if code >= 65 and code <= 90 then
		return mumble.en, mumble.en.vowels[ch], true
	end

	if code >= 97 and code <= 122 then
		return mumble.en, mumble.en.vowels[ch], false
	end

	if (code >= 1040 and code <= 1071) or code == 1025 then
		return mumble.ru, mumble.ru.vowels[ch], true
	end

	if (code >= 1072 and code <= 1103) or code == 1105 then
		return mumble.ru, mumble.ru.vowels[ch], false
	end
end

local function slurChar(ch)
	local pool, isVowel, isUpper = charInfo(ch)
	if not pool then return ch end

	local variants
	if isVowel then
		variants = isUpper and pool.vowelUpper or pool.vowelLower
	else
		variants = isUpper and pool.consonantUpper or pool.consonantLower
	end

	return variants[math.random(#variants)]
end

local function slurWord(word)
	local chars = {}
	local letters = {}

	for _, code in utf8.codes(word) do
		local ch = utf8.char(code)
		chars[#chars + 1] = ch
		if charInfo(ch) then
			letters[#letters + 1] = #chars
		end
	end

	if #letters == 0 then return word end

	local changed = false
	local clearerWord = math.random(100) <= 28

	for i, idx in ipairs(letters) do
		local edge = i == 1 or i == #letters
		local keepChance

		if clearerWord then
			keepChance = edge and 75 or 55
		else
			keepChance = edge and 45 or 22
		end

		if math.random(100) > keepChance then
			changed = true
			if not edge and #letters >= 4 and math.random(100) <= (clearerWord and 5 or 15) then
				chars[idx] = false
			else
				chars[idx] = slurChar(chars[idx])
			end
		end
	end

	if not changed then
		local idx = letters[#letters > 2 and math.random(2, #letters - 1) or #letters]
		chars[idx] = slurChar(chars[idx])
	end

	local out = {}
	for i = 1, #chars do
		if chars[i] ~= false then
			out[#out + 1] = chars[i]
		end
	end

	return table.concat(out)
end

function MuR:CanTalkNormally(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return true end

	return not (
		ply:GetNW2Bool("JawFracture", false)
		or ply:GetNW2Bool("JawDislocation", false)
		or ply:GetNW2Bool("JawDislocated", false)
	)
end

function MuR:FilterSpeechText(ply, text)
	if type(text) ~= "string" then
		text = tostring(text or "")
	end

	if text == "" or self:CanTalkNormally(ply) then
		return text
	end

	if string.StartWith(text, "/") or string.StartWith(text, "!") then
		return text
	end

	local words = {}
	for word in string.gmatch(text, "%S+") do
		words[#words + 1] = slurWord(word)
	end

	if #words == 0 then
		return text
	end

	local garbled = table.concat(words, " ")
	if string.Trim(garbled) == "" then
		return hasCyrillic(text) and "ммф..." or "mmf..."
	end

	return garbled
end

function meta:SetNewName(force)
	local class = self:GetNW2String("Class", "")
	local roleData = class != "" and MuR:GetRole(class)

	if roleData and isfunction(roleData.getName) then
		local name = roleData.getName(self)

		if isstring(name) and name != "" then
			self:SetNWString("Name", name)
			return
		end
	end

	if self.Male then
		local name = force or self:GetInfo("blsd_character_name_male", "")
		local isValidName = isValidNameString(name)
		if name != "" and isValidName then
			self:SetNWString("Name", name)
		else
			self:SetNWString("Name", table.Random(MuR.MaleNames))
		end
	else
		local name = force or self:GetInfo("blsd_character_name_female", "")
		local isValidName = isValidNameString(name)
		if name != "" and isValidName then
			self:SetNWString("Name", name)
		else
			self:SetNWString("Name", table.Random(MuR.FemaleNames))
		end
	end
end

function meta:AddMoney(num)
	self:SetNW2Float("Money", self:GetNW2Float("Money") + num)
end

net.Receive("MuR.TripwireResult", function(_, ply)
	local ent = net.ReadEntity()
	local success = net.ReadBool()
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if not MuR:NetRateLimit(ply, "tripwire_result", 0.5) then return end
	if not IsValid(ent) then return end

	if ent:GetClass() == "mur_trap" then
		if ply:GetPos():DistToSqr(ent:GetPos()) > (140 * 140) then
			ent.DisarmInProgress = false
			ent.DisarmPlayer = nil
			return
		end

		ent:HandleDisarmResult(ply, success)
		return
	end

	if ent:GetClass() == "trap_entity" then
		if not ent.DisarmInProgress or ent.DisarmPlayer ~= ply then return end
		if ply:GetPos():DistToSqr(ent:GetPos()) > (140 * 140) then
			ent.DisarmInProgress = false
			ent.DisarmPlayer = nil
			return
		end

		ent.DisarmInProgress = false
		ent.DisarmPlayer = nil
		timer.Remove("MuR_TrapDisarm_" .. ent:EntIndex())

		if not success then
			MuR:GiveMessage2("tripwire_fail", ply)
			ent:TriggerTrap(ply)
			return
		end

		ent:SetModel("models/murdered/traps/trap_close.mdl")
		ent:SetIsOpen(false)
		ent:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 60)
		hook.Run("BloodshedTrapDisarmed", ply, ent)
		return
	end

	if ent:GetClass() ~= "murwep_grenade" then return end
	if ent.Activated or not IsValid(ent.OwnerTrap) then return end
	if not ent.DisarmInProgress or ent.DisarmPlayer ~= ply then return end
	if ply:GetPos():DistToSqr(ent:GetPos()) > (140 * 140) then
		ent.DisarmInProgress = false
		ent.DisarmPlayer = nil
		return
	end

	ent.DisarmInProgress = false
	ent.DisarmPlayer = nil

	if not success then
		MuR:GiveMessage2("tripwire_fail", ply)
		ent:ActivateGrenade()
		return
	end

	if IsValid(ent.StakeConst) then
		ent.StakeConst:Remove()
	end
	constraint.RemoveAll(ent)

	if IsValid(ent.StakeEnt) then
		ent.StakeEnt:Remove()
	end

	local grenadeClass = ent.F1 and "mur_f1" or "mur_m67"
	ply:GiveWeapon(grenadeClass)

	SafeRemoveEntity(ent)
end)

function meta:ChangeGuilt(mult)
	if MuR.Ending or GetConVar("mur_disableguilt"):GetBool() or MuR.EnableDebug then return end

	local currentMode = MuR.Mode(MuR.Gamemode)
	if currentMode and currentMode.no_guilt then return end

	local guilt = self:GetNW2Float("Guilt", 0)
	local plus = 10 * mult

	self:SetNW2Float("Guilt", math.Clamp(guilt + plus, 0, 100))

	local id, guilt = self:SteamID64(), self:GetNW2Float("Guilt")

	if guilt >= 100 then
		self:SetNW2Float("Guilt", 0)
		timer.Simple(0.1, function()
			if !IsValid(self) then return end
			self:Ban(30, true)
		end)
	end

	file.Write("bloodshed/guilt/"..id..".txt", self:GetNW2Float("Guilt", 0))
end

hook.Add("PlayerInitialSpawn", "MuR.Connect", function(ply)
	timer.Simple(1, function()
		if !IsValid(ply) then return end
		local id = ply:SteamID64()
		local f = file.Read("bloodshed/guilt/"..id..".txt", "DATA")
		local guilt = tonumber(f)
		if guilt then
			ply:SetNW2Float("Guilt", guilt)
		end

		if MuR.GameStarted and isnumber(MuR.Gamemode) then
			net.Start("MuR.SyncGamemode")
			net.WriteInt(MuR.Gamemode, 8)
			net.Send(ply)
		end
	end)
end)

function meta:ChangeHunger(num, ent)
	local hunger = math.Clamp(self:GetNW2Float("Hunger") + num, 0, 100)
	local stamina = math.Clamp(self:GetNW2Float("Stamina") + num / 2, 0, 100)
	local health = math.Clamp(self:Health() + num / 10, 0, self:GetMaxHealth())

	self:SetNW2Float("Hunger", hunger)
	self:SetNW2Float("Stamina", stamina)
	self:SetHealth(health)
end

function meta:IsAtBack(enemy)
	if not IsValid(enemy) then return end
	local enemyForward = enemy:GetForward()
	local enemyToPlayer = self:GetPos() - enemy:GetPos()
	local angle = enemyForward:Angle():Forward():Dot(enemyToPlayer:GetNormalized())
	local degrees = math.deg(math.acos(angle))

	return degrees > 100
end

function meta:ViewPunch(angle)
	net.Start("MuR.ViewPunch")
	net.WriteAngle(angle)
	net.Send(self)
end

function meta:ResetButtons()
	self:ConCommand("-attack")
	self:ConCommand("-attack2")
	self:ConCommand("-moveright")
	self:ConCommand("-moveleft")
	self:ConCommand("-back")
	self:ConCommand("-forward")
	self:ConCommand("-speed")
	self:ConCommand("-duck")
end

function meta:MakeRandomSound(iscough)
	if self.RandomPlayerSound > CurTime() then return end
	self.RandomPlayerSound = CurTime() + math.random(60, 300)
	local rnd, snd = math.random(1, 20), ""
	if iscough then
		rnd = 2
	end

	if rnd <= 10 then
		if self.Male then
			snd = "murdered/player/cough_m.wav"
		else
			snd = "murdered/player/cough_f.wav"
		end

		for i = 1, 2 do
			timer.Simple(i / 2 - 0.5, function()
				if not IsValid(self) then return end
				self:ViewPunch(Angle(4, 0, 0))
			end)
		end
	else
		if self.Male then
			snd = "murdered/player/sneeze_m.wav"
		else
			snd = "murdered/player/sneeze_f.wav"
		end

		timer.Simple(1, function()
			if not IsValid(self) then return end
			self:ViewPunch(Angle(8, 0, 0))
		end)
	end

	self:EmitSound(snd, 60, self.PitchVoice or 100)
end

function MuR:SendDataToClient(string, value, delay)
	if delay then
		timer.Simple(delay, function()
			net.Start("MuR.SendDataToClient")
			net.WriteString(string)

			net.WriteTable({value})

			net.Broadcast()
		end)
	else
		net.Start("MuR.SendDataToClient")
		net.WriteString(string)

		net.WriteTable({value})

		net.Broadcast()
	end
end

function MuR:ShowFinalScreen(type, allowvote)
	for _, ply in ipairs(MuR:GetAlivePlayers()) do
		if ply.IsDying and ply:IsDying() then
			local att = ply.MuR_DyingAttacker
			local byPolice = IsValid(att) and (att.IsPolice
				or att:GetNW2String("Class") == "Officer"
				or att:GetNW2String("Class") == "ArmoredOfficer"
				or att:GetNW2String("Class") == "Riot")

			ply:SetNW2Float("DeathStatus", byPolice and 2 or 1)
		end

		if not (ply.IsDying and ply:IsDying()) and ply:GetNW2Bool("MuR.Cuffed", false)
			and ply:GetNW2Bool("MuR.CuffLawful", false) then
			ply:SetNW2Float("DeathStatus", 3)
		end

		if type == "traitor" and ply:IsKiller() then
			ply:AddMoney(250)
		end

		if type == "innocent" and not ply:IsKiller() then
			ply:AddMoney(50)
		end
	end

	net.Start("MuR.FinalScreen")
	net.WriteString(type)
	net.WriteBool(allowvote)
	net.Broadcast()
end

function MuR:PlaySoundOnClient(string, ply)
	net.Start("MuR.PlaySoundOnClient")
	net.WriteString(string)
	if ply then
		net.Send(ply)
	else
		net.Broadcast()
	end
end

function MuR:GiveAnnounce(type, ply)
	net.Start("MuR.Announce")
	net.WriteString(type)
	if ply then
		net.Send(ply)
	else
		net.Broadcast()
	end
end

function MuR:GiveMessage(type, ply)
	net.Start("MuR.Message")
	net.WriteString(type)
	if ply then
		net.Send(ply)
	else
		net.Broadcast()
	end
end

function MuR:GiveMessage2(type, ply)

	if IsValid(ply) and ply:IsPlayer() then
		ply.MessageCooldowns = ply.MessageCooldowns or {}

		if ply.MessageCooldowns[type] and CurTime() < ply.MessageCooldowns[type] then
			return
		end
		ply.MessageCooldowns[type] = CurTime() + 3

        if ply.GlobalMessageCooldown and CurTime() < ply.GlobalMessageCooldown then
            return
        end
        ply.GlobalMessageCooldown = CurTime() + 0.5

		if not ply:Alive() then
			return
		end

		if ply:GetNW2Bool("IsUnconscious", false) then
			local utime = ply.UnconsciousStart or 0
			if CurTime() - utime > 1 then return end
		end
	end

	net.Start("MuR.Message2")
	net.WriteString(type)
	if ply then
		net.Send(ply)
	else
		net.Broadcast()
	end
end

function MuR:Notify(target, text, level)
	if text == nil then return end
	if type(text) != "string" then
		text = tostring(text or "")
	end
	text = string.Trim(text)
	if text == "" then return end
	level = math.Clamp(tonumber(level) or 0, 0, 3)

	local recipients
	if istable(target) then
		recipients = {}
		for _, ply in ipairs(target) do
			if IsValid(ply) and ply:IsPlayer() then
				table.insert(recipients, ply)
			end
		end
		if #recipients == 0 then return end
	elseif IsValid(target) and target:IsPlayer() then
		recipients = target
	end

	net.Start("MuR.Notify")
	net.WriteString(text)
	net.WriteUInt(level, 3)

	if recipients then
		net.Send(recipients)
	else
		net.Broadcast()
	end
end

function MuR:GiveCountdown(time, ply)
	net.Start("MuR.Countdown")
	net.WriteFloat(time)
	if ply then
		net.Send(ply)
	else
		net.Broadcast()
	end
end

hook.Add("PlayerInitialSpawn", "MuR.InitSpawn", function(ply)
	ply.SpawnDataSpeed = {100, 280, 190}
	ply:SetNW2Float("Guilt", 0)
	ply.SpectateMode = 6
	ply.SpectateIndex = 1
	ply:Spectate(ply.SpectateMode)
	ply.ViewOffsetZ = 64
end)

function GM:PlayerSpawn(ply)
	if not ply.ForceSpawn then
		if not MuR.GameStarted or !MuR.EnableDebug and MuR.GameStarted and MuR.TimeCount + 12 < CurTime() then
			local role = MuR:GetRole("Civilian")
			if role and role.models then
				local isMale = not tobool(ply:GetInfoNum("blsd_character_female", 0))
				local mdl
				if isfunction(role.models) then
					mdl = role.models(ply)
				elseif istable(role.models) then
					if role.models.male and role.models.female then
						mdl = table.Random(isMale and role.models.male or role.models.female)
					else
						mdl = table.Random(role.models)
					end
				end
				if isstring(mdl) then
					ply:SetModel(mdl)
				end
			end
			ply:KillSilent()
			return
		end
		if MuR.EnableDebug then
			ply:SetNW2String("Class", "Civilian")
			timer.Simple(0.1, function()
				if !IsValid(ply) then return end
				ply:Freeze(false)
			end)
		end
	else
		ply.ForceSpawn = false
	end

	--
	-- Расставленные точки игроков. Ставим ЗДЕСЬ, потому что обычный спавн идёт
	-- через движок (info_player_start) и никакого своего места не выбирает.
	--
	-- Режимы, которые расставляют людей сами — командные базы, спавн убийцы
	-- подальше от всех — делают это позже, отложенными таймерами, и спокойно
	-- перекрывают то, что выставлено тут.
	--
	if MuR:HasSpawns("players") then
		local spawnPos, spawnAng = MuR:GetPlayerSpawnPos()
		MuR:PlaceAtSpawn(ply, spawnPos, spawnAng)
	end

	local vars = {
		IsSurrenderBefore = false,
		MindController = nil,
		CurrentEyeAngle = ply:EyeAngles(),
		DamageTargetGuilt = 0,
		VoiceDelay = 0,
		TakeDamageTime = 0,
		UnInnocentTime = 0,
		HungerDelay = CurTime() + 5,
		PitchVoice = math.Clamp(ply:GetInfoNum("blsd_character_pitch", 100), 86, 114),
		RandomPlayerSound = CurTime() + math.random(30, 180),
		BleedTime = 0,
		SpectateMode = 6,
		SpectateIndex = 1,
		LastBleedBone = "",
		LastAlivePosition = nil,
		RandomSkinDisabled = false,
		peppertimevoice = 0,
		NextUnconsciousCheck = 0
	}

	for k, v in pairs(vars) do ply[k] = v end

	player_manager.OnPlayerSpawn(ply, transiton)
	player_manager.RunClass(ply, "Spawn")

	ply:ConCommand("soundfade 0 0")
	ply:Freeze(false)
	ply:SetNoTarget(false)
	ply:SetNotSolid(false)
	ply:SetSolid(SOLID_BBOX)
	ply:SetCollisionGroup(5)
	ply:GodDisable()
	ply:SetAvoidPlayers(true)
	ply:SetCustomCollisionCheck(true)
	ply:SetSVAnimation("")
	ply:StripWeapons()
	ply:StripAmmo()
	ply:SetSlowWalkSpeed(60)
	ply:SetWalkSpeed(100)
	ply:SetRunSpeed(280)
	ply:SetLadderClimbSpeed(60)
	ply:NewHull()
	ply:UnSpectate()

	for i = 0, ply:GetNumBodyGroups() - 1 do
		ply:SetBodygroup(i, 0)
	end

	timer.Simple(0.5, function()
		if IsValid(ply) then
			ply:UpdateBloodMovementSpeed()
		end
	end)

	local nwf = {
		Stability = 100,
		ArrestState = 0,
		Stamina = 100,
		BleedLevel = 0,
		Hunger = 90,
		DeathStatus = 0,
		ToxinLevel = 0,
		Blindness = 0,
		ConcussionEnd = 0,
		InternalBleedEnd = 0,
		CoordinationEnd = 0,
		AdrenalineEnd = 0,
		AdrenalineOverdoseEnd = 0,
		ConcussionIntensity = 0
	}

	for k, v in pairs(nwf) do ply:SetNW2Float(k, v) end

	local nwb = {
		LegBroken = false,
		ArmFracture = false,
		ClavicleFracture = false,
		ForearmFracture = false,
		FootFracture = false,
		JawFracture = false,
		PelvisFracture = false,
		RibFracture = false,
		HardBleed = false,
		GeroinUsed = false,
		Poison = false,
		Bredogen = false,
		FlashlightIsOn = false,
		ShockState = false,
		IsUnconscious = false,
		AdrenalineOverdosing = false,
		Pneumothorax = false,
		PneumothoraxLeft = false,
		PneumothoraxRight = false,
		SpineBroken = false,
		ForceProneOnly = false,
		Artery_Neck = false,
		Artery_Heart = false,
		Artery_Arm = false,
		Artery_Leg = false,
		Artery_ArmLeft = false,
		Artery_ArmRight = false,
		Artery_LegLeft = false,
		Artery_LegRight = false,
		Artery_Generic = false,
		Artery_neck = false,
		Artery_heart = false,
		Artery_arm = false,
		Artery_leg = false
	}

	for k, v in pairs(nwb) do ply:SetNW2Bool(k, v) end
	ply:SetNW2Int("ShockLevel", 0)
	ply:SetNW2Int("ConsciousLevel", 0)
	ply:ResetCriticalOrgans()

	ply:SetNW2Entity("CurrentTarget", NULL)

	ply:SetBloodColor(BLOOD_COLOR_RED)
	ply:SetColor(Color(255,255,255))
	ply:SetMaterial("")
	ply:SetEyeAngles(Angle(ply:EyeAngles().x, ply:EyeAngles().y, 0))
	ply:SetPlayerColor(ColorRand():ToVector())
	ply:SetViewOffset(Vector(0, 0, 64))
	ply:SetViewOffsetDucked(Vector(0, 0, 36))
	ply:SetJumpPower(190)

	local pos = MuR:GetRandomPos()
	if isvector(pos) then
		ply:SetPos(pos)
	else
		local currentPos = ply:GetPos()
		local offset = VectorRand() * 16
		offset.z = 0
		ply:SetPos(currentPos + offset)
		timer.Simple(0.1, function()
			if IsValid(ply) then
				ply:AllowFlashlight(true)
			end
		end)
	end

	local class = ply:GetNW2String("Class", "")
	if class == "" then
		ply:SetNW2String("Class", "Innocent")
		class = "Innocent"
	end

	ply.Male = not tobool(ply:GetInfoNum("blsd_character_female", 0))
    local innocentRole = MuR:GetRole("Innocent")
    if innocentRole and innocentRole.models then
        local mdl
        if isfunction(innocentRole.models) then
            mdl = innocentRole.models(ply)
        elseif istable(innocentRole.models) then
            if innocentRole.models.male and innocentRole.models.female then
                mdl = table.Random(ply.Male and innocentRole.models.male or innocentRole.models.female)
            else
                mdl = table.Random(innocentRole.models)
            end
        end
        if isstring(mdl) then
            ply:SetModel(mdl)
        end
    end

	ply:AllowFlashlight(false)
	ply:GiveWeapon("mur_hands", true)
	ply:SetTeam(2)
	ply:SetHealth(100)
	ply:SetMaxHealth(100)

    local roleData = MuR:GetRole(class)
    if roleData then
        if roleData.male != nil then
            ply.Male = roleData.male
        end

        if roleData.models then
            if isfunction(roleData.models) then
                ply:SetModel(roleData.models(ply))
            elseif istable(roleData.models) then
                if roleData.models.male and roleData.models.female then
                    ply:SetModel(table.Random(ply.Male and roleData.models.male or roleData.models.female))
                else
                    ply:SetModel(table.Random(roleData.models))
                end
            end
        end

        if roleData.flashlight != nil then
            ply:AllowFlashlight(roleData.flashlight)
        end

        if roleData.team then
            ply:SetTeam(roleData.team)
        end

        if roleData.health then
            ply:SetHealth(roleData.health)
            ply:SetMaxHealth(roleData.health)
        end

        if roleData.onSpawn then
            local skipOnSpawn = MuR.Gamemode == 23 and class == "PrisonGuard" and MuR.Mode23 and not MuR.Mode23.GuardsSpawned
            if not skipOnSpawn then
                roleData.onSpawn(ply)
            end
        end
    end

	if MuR.EnableDebug then
		ply:GiveWeapon("weapon_physgun")
		ply:GiveWeapon("gmod_tool")
	end

	ply.SpawnDataSpeed = {ply:GetWalkSpeed(), ply:GetRunSpeed(), ply:GetJumpPower()}
	ply:SetNewName()
	ply:SetupHands()
	ply:RandomSkin()
	net.Start("MuR.ResetPain")
	net.Send(ply)
end

function GM:PlayerDeathSound(ply)
	return true
end

function MuR:ExecuteString(type)
	if type == "decals" then
		type = [[RunConsoleCommand("r_decals", "9000000")]]
	end
	net.Start("MuR.ExecuteString")
	net.WriteString(type)
	net.Broadcast()
end

hook.Add("OnNPCKilled", "MuR.NPCLogic", function(ent, att)
	local allow = MuR.PoliceState > 0 and ent.IsPolice
	if ent.IsPolice then
		MuR.VoteLogDeadPolice = MuR.VoteLogDeadPolice + 1
	end
	if allow then
		timer.Simple(0.01, MuR.CheckPoliceReinforcment)
	end
end)

function meta:DeathEffect(att)
	local pos = self.LastAlivePosition or self:GetPos()
	local isNPC = IsValid(att) and MuR.IsAI(att)
	local playAnim = (MuR.Gamemode == 18) or (MuR.Gamemode == 22 and isNPC)

	if not playAnim then
		self:ConCommand("soundfade 100 5")
		self:ScreenFade(SCREENFADE.OUT, color_black, 0.1, 4.9)
	else
		self:ScreenFade(SCREENFADE.OUT, color_black, 0.1, 1.9)
		timer.Simple(2, function()
			if !IsValid(self) then return end
			self:PlayNZDeathAnim(pos)
		end)
	end
end

hook.Add("PlayerDroppedWeapon", "MuR.DropThrow", function(ply, wep)
	if not IsValid(ply) or not IsValid(wep) then return end

	timer.Simple(0, function()
		if not IsValid(ply) or not IsValid(wep) then return end

		local phys = wep:GetPhysicsObject()
		if not IsValid(phys) then return end

		local aim = ply:GetAimVector()
		local vel = ply:GetVelocity() * 0.15 + aim * 55 + Vector(0, 0, 14)

		phys:SetVelocityInstantaneous(vel)
		phys:AddAngleVelocity(VectorRand(-35, 35))
	end)
end)

function meta:DropDeathItem()
	local wep = self:GetActiveWeapon()
	if not IsValid(wep) or wep.CantDrop or wep.NeverDrop then return end

	self:DropWeapon(wep)
	self.RagdollStoredWeapon = nil
end

hook.Add("DoPlayerDeath", "MuR.DropDeathItem", function(ply)
	ply:DropDeathItem()
end)

function GM:PlayerDeath(ply, inf, att)
	if IsValid(att.MindController) then
		att = att.MindController
	end

	ply:DeathEffect(att)
	ply.DeathTime = CurTime()
	ply:Freeze(true)

	ply:SetNotSolid(true)
	ply:SetNoTarget(true)
	ply:GodEnable()
	net.Start("MuR.ResetPain")
	net.Send(ply)
	timer.Simple(0.1, function()
		if !IsValid(ply) or ply:Alive() then return end
		if isstring(ply.LastVoiceLine) then
			ply:StopSound(ply.LastVoiceLine)
		end
	end)

	if att.IsPolice or (att:GetNW2String("Class") == "Officer" or att:GetNW2String("Class") == "ArmoredOfficer" or att:GetNW2String("Class") == "Riot") then
		ply:SetNW2Float("DeathStatus", 2)
	else
		ply:SetNW2Float("DeathStatus", 1)
	end

	MuR:CheckPoliceReinforcment()

	timer.Simple(0.01, function()
		if !IsValid(ply) then return end
		local att2 = ply.LastAttacker
		if IsValid(att2) and att2:IsPlayer() then
			if att2:GetNW2String("Class") == "HeadHunter" and IsValid(att2:GetNW2Entity("CurrentTarget")) and att2:GetNW2Entity("CurrentTarget") == ply then
				MuR:GiveAnnounce("headhunter_kill", att2)
				MuR:GiveAnnounce("headhunter_killed", ply)
				att2:AddMoney(500)
			elseif att2:GetNW2String("Class") != "Soldier" and (ply:Team() == 2 or ply:Team() == 3) and (att2:Team() == 2 or att2:Team() == 3) and MuR.Gamemode ~= 11 and MuR.Gamemode ~= 12 and ply ~= att2 then
				if ply.UnInnocentTime < CurTime() then
					att2:ChangeGuilt(4)
					MuR:GiveAnnounce("innocent_kill", att2)
				else
					MuR:GiveAnnounce("innocent_att_kill", att2)
				end
			end
			if att2:IsKiller() and not ply:IsKiller() then
				att2:SetNW2Float("Stability", math.Clamp(att2:GetNW2Float("Stability")+75, 0, 100))
			end
			ply.LastAttacker = nil
		end
	end)

	if att:IsPlayer() and ply:IsKiller() and not att:IsKiller() then
		att:AddMoney(50)
	end

	if att:IsPlayer() and ply:GetNW2Float("ArrestState") ~= 2 and att:IsRolePolice() and ply ~= att and !ply:IsKiller() and not (MuR.Gamemode == 23 and ply:GetNW2String("Class") == "Prisoner") then
		if ply:GetNW2Float("ArrestState") == 1 then
			att:ChangeGuilt(1)
		else
			att:ChangeGuilt(2)
		end
		MuR:GiveAnnounce("officer_killer", att)
	end

	if MuR.Gamemode == 6 and ply:GetNW2String("Class") ~= "Zombie" then
		MuR:GiveAnnounce("you_zombie", ply)
		ply:SetNW2String("Class", "Zombie")
	end

	if att:IsPlayer() and MuR.Gamemode == 5 then
		att:AddMoney(50)
	end

	timer.Simple(5, function()
		if not IsValid(ply) then return end
		ply:SetNW2Entity("RD_EntCam", ply)
		ply:Freeze(false)

		if MuR.EnableDebug or ply:GetNW2String("Class") == "Zombie" then
			ply:ScreenFade(SCREENFADE.IN, color_black, 1, 0)
			ply.ForceSpawn = true
			ply:Spawn()
		end
	end)

	if ply:IsBot() and ply.KickAfterDeath then
		timer.Simple(1, function() if !IsValid(ply) then return end ply:Kick("Bot kicked after death.") end)
	end
end

function GM:PlayerDeathThink(ply)
	if ply.SpectateMode then
		ply:Spectate(ply.SpectateMode)
		local ent = MuR:GetAlivePlayers()[ply.SpectateIndex]
		if ply:GetCollisionGroup() != 10 then
			ply:SetCollisionGroup(10)
			ply:SetSolid(SOLID_NONE)
			ply:SetNotSolid(true)
			ply:SetAvoidPlayers(false)
		end

		if IsValid(ent) and ent:Health() > 0 and (ply:GetObserverMode() == 5 or ply:GetObserverMode() == 4) then
			ply:SpectateEntity(ent)
		else
			ply:SpectateEntity(NULL)
		end
	end

	if ply:EyeAngles().z != 0 then
		local ang = ply:EyeAngles()
		ang.z = 0
		ply:SetEyeAngles(ang)
	end

	if ply:GetNW2String("Class") == "Zombie" or MuR.EnableDebug then return true end
	if MuR.GameStarted then return false end
end

function GM:PlayerSay(ply, text, team)
	if MuR.GameStarted and MuR.TimeCount + 12 < CurTime() and ply:Alive() then
		if ply:GetNW2Bool("IsUnconscious", false) then
			return false
		end

		local spokenText = MuR.FilterSpeechText and MuR:FilterSpeechText(ply, text) or text

		for _, ply2 in player.Iterator() do
			local can = hook.Call("PlayerCanSeePlayersChat", GAMEMODE, text, team, ply2, ply)

			if can then
				net.Start("MuR.ChatAdd")
				net.WriteEntity(ply)
				net.WriteString(spokenText)
				net.Send(ply2)
			end
		end

		return false
	end

	return true
end

function meta:NextSpectateEntity()
	self.SpectateIndex = self.SpectateIndex + 1

	if not IsValid(MuR:GetAlivePlayers()[self.SpectateIndex]) then
		self.SpectateIndex = 1
	end
end

net.Receive("MuR.BodySearch", function(len, ply)
	local ent = net.ReadEntity()
	local cl = net.ReadString()

	if string.len(cl) > 256 then return end
	if !IsValid(ply) or !MuR:NetRateLimit(ply, "body_search", 0.2) then return end
	if !ply:Alive() or !IsValid(ent) or ply:GetPos():DistToSqr(ent:GetPos()) > 25000 or !istable(ent.Inventory) then return end

	if string.StartWith(cl, "mur_armor_") then
		local armorId = string.sub(cl, 11)
		local item = MuR.Armor.GetItem(armorId)
		if item then
			if table.HasValue(ent.Inventory, cl) then
				table.RemoveByValue(ent.Inventory, cl)
				local pickup
				if ent:GetClass() == "prop_ragdoll" then
					pickup = MuR:DropArmorFromRagdoll(ent, item.bodypart)
				else
					pickup = MuR:SpawnArmorPickup(ent:GetPos() + Vector(0, 0, 20), armorId)
				end

				if IsValid(pickup) then
					timer.Simple(0.1, function()
						if IsValid(ply) and IsValid(pickup) then
							pickup:Use(ply, ply)
						end
					end)
				end

				if item.unequip_sound then
					ply:EmitSound(item.unequip_sound, 50, 100)
				end
			end
		end
		return
	end

	if ply:HasWeapon(cl) then return end
	local prop = ent:GetClass() != "prop_ragdoll"

	local wep = nil
	for k, wp in pairs(ent.Inventory) do
		if IsValid(wp) and wp:GetClass() == cl or isstring(wp) and wp == cl then
			wep = wp
			break
		end
	end
	if !IsValid(wep) and !isstring(wep) or isstring(wep) and not prop then return end
	if isstring(wep) then
		wep = ents.Create(wep)
		if not IsValid(wep) then
			table.RemoveByValue(ent.Inventory, cl)
			return
		end
		wep:Spawn()
	end
	wep:SetNoDraw(false)
	wep:SetNotSolid(false)
	wep:SetPos(ent:GetPos()+Vector(0,0,24))
	local phys = wep:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(true)
		phys:SetVelocity(-phys:GetVelocity() + VectorRand(-50, 50))
	end
	if wep:IsWeapon() then
		ply:PickupWeapon(wep)
	else
		timer.Simple(0.1, function()
			if !IsValid(ply) then return end
			wep:Use(ply)
		end)
	end
	ply:SelectWeapon(cl)
	if prop then
		table.RemoveByValue(ent.Inventory, cl)
	else
		table.RemoveByValue(ent.Inventory, wep)
	end

	net.Start("MuR.RemoveItemFromSearch")
	net.WriteEntity(ent)
	net.WriteString(cl)
	net.Broadcast()
end)

hook.Add("PlayerButtonDown", "MuR_SButtons", function(ply, but)
	if ply:GetObserverMode() > 0 then
		if (ply:GetObserverMode() == 5 or ply:GetObserverMode() == 4) and but == KEY_SPACE then
			ply:UnSpectate()
			ply.SpectateMode = 6
		elseif ply:GetObserverMode() == 6 and but == KEY_SPACE then
			ply.SpectateMode = 5
		end

		if but == MOUSE_LEFT then
			ply:NextSpectateEntity(true)
		elseif but == MOUSE_RIGHT then
			if ply:GetObserverMode() == 5 then
				ply.SpectateMode = 4
			elseif ply:GetObserverMode() == 4 then
				ply.SpectateMode = 5
			end
		end
	end

	if ply:Alive() and but == KEY_E and (not ply:GetNoDraw() or IsValid(ply:GetRD())) then
		local tr = ply:GetEyeTrace().Entity

		if IsValid(ply:GetRD()) and tr == ply:GetRD() then return end

		if MuR.BodyPanelBlocked and MuR.BodyPanelBlocked(ply) then return end

		if IsValid(tr) and table.HasValue(MuR.LootableProps, tr:GetModel()) and istable(tr.Inventory) and tr:GetPos():DistToSqr(ply:GetPos()) < 10000 then
			MuR.MarkBodyPanelOpen(ply)

			net.Start("MuR.BodySearch")
			net.WriteTable(tr.Inventory)
			net.WriteEntity(tr)
			net.Send(ply)
		end
	end

	if ply:Alive() and but == KEY_SPACE and not ply:GetNoDraw() and ply:OnGround() then
		local stam = ply:GetNW2Float("Stamina")
		ply:SetNW2Float("Stamina", math.Clamp(stam - 5, 0, 100))
	end
end)

hook.Add("PlayerCanHearPlayersVoice", "MuR.Voice", function(listener, talker)
	if MuR.GameStarted and MuR.TimeCount + 12 > CurTime() or MuR.Ending then return true end

	if MuR.CanTalkNormally and not MuR:CanTalkNormally(talker) and talker:Alive() then
		return false
	end

	if talker:Alive() and talker:GetNW2String("Class") == "CombineSoldier" and listener:Alive() and listener:GetNW2String("Class") == "CombineSoldier" then return true end

	local listenerWep = listener:GetWeapon("mur_radio")
	local talkerWep = talker:GetActiveWeapon()

	if IsValid(listenerWep) and IsValid(talkerWep) and talkerWep:GetClass() == "mur_radio" then
		local listenerOn = listenerWep:GetNWBool("RadioOn", false)
		local talkerOn = talkerWep:GetNWBool("RadioOn", false)

		if listenerOn and talkerOn then
			local listenerChannel = listenerWep:GetNWInt("RadioChannel", 1)
			local talkerChannel = talkerWep:GetNWInt("RadioChannel", 1)

			if listenerChannel == talkerChannel then
				local dist = listener:GetPos():Distance(talker:GetPos())
				if dist <= 8000 then
					return true, false
				end
			end
		end
	end

	if MuR.PoliceState == 5 then
		local listenerIsPolice = (listener:GetNW2String("Class") == "Officer" or listener:GetNW2String("Class") == "ArmoredOfficer" or listener:GetNW2String("Class") == "SWAT")
		local talkerIsPolice = (talker:GetNW2String("Class") == "Officer" or talker:GetNW2String("Class") == "ArmoredOfficer" or talker:GetNW2String("Class") == "SWAT")
		local talkerIsCriminal = (talker:GetNW2String("Class") == "Criminal")

		if listenerIsPolice and talkerIsCriminal then
			return false
		end
	end

	if listener:GetPos():DistToSqr(talker:GetPos()) > 250000 and talker:Alive() or not listener:IsLineOfSightClear(talker) and talker:Alive() or not talker:Alive() and listener:Alive() then return false end
	if !talker:Alive() and !listener:Alive() then return true end
	return true, true
end)

hook.Add("PlayerCanSeePlayersChat", "MuR.Voice", function(text, team, listener, talker)
	if MuR.GameStarted and MuR.TimeCount + 12 > CurTime() or MuR.Ending then return true end

	if MuR.PoliceState == 5 then
		local listenerIsPolice = (listener:GetNW2String("Class") == "Officer" or listener:GetNW2String("Class") == "ArmoredOfficer" or listener:GetNW2String("Class") == "SWAT")
		local talkerIsPolice = (talker:GetNW2String("Class") == "Officer" or talker:GetNW2String("Class") == "ArmoredOfficer" or talker:GetNW2String("Class") == "SWAT")
		local talkerIsCriminal = (talker:GetNW2String("Class") == "Criminal")

		if listenerIsPolice and talkerIsCriminal then
			return false
		end
	end

	if listener:GetPos():DistToSqr(talker:GetPos()) > 250000 and talker:Alive() or not listener:IsLineOfSightClear(talker) and talker:Alive() or not talker:Alive() and listener:Alive() then return false end
end)

hook.Add("OnEntityCreated", "MuR_Remover", function(ent)
	if (MuR.Gamemode == 2 or MuR.Gamemode == 3) and (ent.Melee or ent.IsTFAWeapon) and not ent.CantDrop then end
end)

hook.Add("Think", "MuR_LogicPlayer", function()
	for _, ent in player.Iterator() do
		if not ent:Alive() then continue end

		ent.LastAlivePosition = IsValid(ent:GetRD()) and ent:GetRD():GetPos() or ent:GetPos()

		if ent:HaveStability() and not ent:GetNW2Bool("GeroinUsed", false) then
			local rate = MuR.KillerSanityRate and MuR.KillerSanityRate(ent) or 1
			ent:SetNW2Float("Stability", math.Clamp(ent:GetNW2Float("Stability") - FrameTime() / 10 * rate, 0, 100))
			if ent:GetNW2Float("Stability") <= 0 then
				ent:ConCommand("kill")
				if math.random(1,5) == 1 then
					ent:TakeDamage(1)
				end
			end
		end

		if ent:Alive() and ent:GetSVAnim() == "" and !IsValid(ent:GetRD()) then
			local num = 64
			local eyes = ent:LookupAttachment("eyes")
			if eyes > 0 then
				local att = ent:GetAttachment(eyes)
				local dif = math.sqrt(att.Pos:DistToSqr(ent:GetPos()))
				num = math.Clamp(dif, 8, 96)
			end
			ent.ViewOffsetZ = Lerp(FrameTime()/0.1, ent.ViewOffsetZ, num)
		else
			ent.ViewOffsetZ = 64
			if string.find(ent:GetSVAnim(), "sequence_ron_comply_start_0") then
				ent:SetActiveWeapon(nil)
			end
		end

		local wep = ent:GetActiveWeapon()

		if IsValid(wep) and wep:GetMaxClip1() > 0 and ent:GetNW2Float("Guilt") >= 70 and MuR.Gamemode ~= 5 then
			ent:DropWeapon(wep)
		end

		if ent:GetNW2Float("ArrestState") > 0 and ent:IsRolePolice() then
			ent:SetNW2Float("ArrestState", 0)
		end

		--
		-- Здесь выставлялся VJ_NPC_Class — фракция игрока для VJ-NPC. Читать его
		-- давно некому, а свои NPC спрашивают MuR.NPC.GetFaction, то есть поле
		-- BSFaction.
		--
		-- Разыскиваемому фракцию НЕ меняем: полиция и так берёт его в цели по
		-- ArrestState (npc_bs_police/shared.lua, IsValidEnemy), а перевод в
		-- "suspect" вдобавок сделал бы его своим для бандитов.
		--
		-- А вот игрок-зомби фракцию менять обязан, иначе он остаётся "player",
		-- и NPC-зомби в шестом режиме кидаются на своего же.
		--
		if ent:GetNW2String("Class") == "Zombie" then
			ent:SelectWeapon("mur_zombie")
			ent.BSFaction = "zombie"
		elseif ent.BSFaction == "zombie" then
			ent.BSFaction = nil
		end

		local lvl = ent:GetNW2Float("BleedLevel")
		local hbl = ent:GetNW2Bool("HardBleed")
		local moving = ent:GetVelocity():Length() > 50
		local running = ent:GetVelocity():Length() > 150

		local severity = math.Clamp(lvl, 0, 3)
		if hbl then severity = math.max(severity, 3.4) end

		if severity > 0 and ent.BleedTime < CurTime() then
			local frac = math.Clamp(severity / 3.4, 0, 1)

			local bleedDelay = Lerp(frac, 2.6, 0.4)
			if running then
				bleedDelay = bleedDelay * 0.7
			elseif moving then
				bleedDelay = bleedDelay * 0.85
			end
			ent.BleedTime = CurTime() + bleedDelay * math.Rand(0.85, 1.15)

			local damage = Lerp(frac, 0.5, 1.5)
			if running then
				damage = damage * 1.35
			elseif moving then
				damage = damage * 1.15
			end

			MuR:CreateBloodPool(ent, 0, severity >= 3 and math.random(1, 2) or 1)

			local bleedAttacker = IsValid(ent.LastAttacker) and ent.LastAttacker or ent
			ent:TakeDamage(damage, bleedAttacker, bleedAttacker)

			ent:EmitSound("murdered/player/drip_" .. math.random(1, 5) .. ".wav",
				Lerp(frac, 40, 50), math.random(70, 120))

			if severity >= 2 and math.random() < frac * 0.12 then
				ent:ViewPunch(Angle(math.random(-1, 1), math.random(-1, 1), 0))
			end

		end

		if not ent.BloodRegenTime then ent.BloodRegenTime = CurTime() + 30 end

		ent:SetNW2Bool("Surrender", ent:GetNW2Float("ArrestState") == 1 and (MuR:VisibleByNPCs(ent:WorldSpaceCenter()) or MuR.PoliceState == 2 or MuR.PoliceState == 4 or MuR.Gamemode == 11) and ent:Alive() and ent:GetSVAnimation() == "")
		ent:MakeRandomSound()

		if ent:GetNW2Float("peppereffect") > CurTime() and ent.peppertimevoice < CurTime() then
			ent.peppertimevoice = CurTime() + 2
			ent:ViewPunch(AngleRand(-10, 10))

			if ent.Male then
				ent:EmitSound("murdered/player/cough_m.wav", 60, math.random(80, 110))
			else
				ent:EmitSound("murdered/player/cough_f.wav", 60, math.random(80, 110))
			end
		end

		if ent.HungerDelay < CurTime() and not MuR:DisablesGamemode() then
			ent.HungerDelay = CurTime() + 5
			if MuR.Gamemode != 18 then
				ent:SetNW2Float("Hunger", math.Clamp(ent:GetNW2Float("Hunger") - 1, 0, 100))
			end

		end

		local rag = ent:GetRD()
		if !IsValid(rag) then
			rag = ent
		end
		if IsValid(rag) then
			local vel = rag:GetVelocity():Length()
			local height = MuR:CheckHeight(rag, rag:WorldSpaceCenter())
			if not rag:OnGround() and (vel > 1000 or height > 300 and vel > 300) and ent:GetMoveType() ~= MOVETYPE_NOCLIP then
				ent:PlayVoiceLine("death_fly")
				if rag:IsPlayer() then
					rag:StartRagdolling()
					rag:TimeGetUpChange(10, true)
				end
			end
		end
	end
end)

local function setFallFracture(ply, flag, message)
	if not IsValid(ply) or ply:GetNW2Bool(flag, false) then return false end

	ply:SetNW2Bool(flag, true)
	if message and MuR.GiveMessage2 then
		MuR:GiveMessage2(message, ply)
	end

	return true
end

local function applyFallTrauma(ply, speed)
	if not IsValid(ply) or not ply:Alive() then return end

	local severity = math.Clamp((speed - 500) / 550, 0, 1)
	if severity <= 0 then return end

	ply:ApplyCoordinationLoss(5 + severity * 7, 0.6 + severity * 0.9)

	if speed >= 620 then
		ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - (15 + severity * 30), 0))
	end

	if speed >= 650 and math.random() < (0.3 + severity * 0.25) then
		if math.random() < 0.5 then
			ply:DamagePlayerSystem("bone")
		else
			setFallFracture(ply, "FootFracture", "leg_fracture")
		end
	end

	if speed >= 760 and math.random() < (0.22 + severity * 0.28) then
		setFallFracture(ply, "PelvisFracture", "pelvis_fracture")
	end

	if speed >= 820 and math.random() < (0.18 + severity * 0.22) then
		setFallFracture(ply, "RibFracture", "rib_hit")
	end

	if speed >= 900 and math.random() < (0.08 + severity * 0.18) then
		ply:SetNW2Bool("SpineBroken", true)
		ply:SetNW2Bool("ForceProneOnly", true)
		if MuR.GiveMessage2 then
			MuR:GiveMessage2("spine_hit", ply)
		end
	end

	if speed >= 700 then
		ply:ApplyConcussion(nil, 2 + severity * 3, 0.7 + severity * 0.6)
	end

	if speed >= 820 and math.random() < (0.2 + severity * 0.35) then
		ply:ApplyUnconsciousness(4 + severity * 8)
	elseif speed >= 700 and math.random() < (0.12 + severity * 0.18) then
		ply:StartRagdolling(math.Round(1 + severity * 2), speed / 60)
	end

	timer.Simple(0, function()
		if not IsValid(ply) then return end
		if ply.UpdateBloodMovementSpeed then ply:UpdateBloodMovementSpeed() end
		if ply.CheckForceProneOnly then ply:CheckForceProneOnly() end
	end)
end

local fallspd = 500
hook.Add("OnPlayerHitGround", "MuR_DamageNPCThink", function(ply, onwater, onfloater, speed)
	if onwater or onfloater then return end
	if speed >= fallspd then
		local fatal = 1350
		local isfatal = fatal > 0 and speed >= fatal
		local damage = isfatal and ply:Health() + ply:Armor() or math.Clamp((speed - fallspd) / 18, 6, 72)

		if not isfatal and damage >= ply:Health() then
			damage = math.max(ply:Health() - math.random(1, 6), 1)
		end

		local dmg = DamageInfo()
		dmg:SetAttacker(game.GetWorld())
		dmg:SetInflictor(game.GetWorld())
		dmg:SetDamage(damage)
		dmg:SetDamageType(DMG_FALL)
		dmg:SetDamagePosition(ply:GetPos())
		dmg:SetDamageForce(Vector(0, 0, -speed * 45))
		ply:TakeDamageInfo(dmg)
		ply:EmitSound("Player.FallDamage", 75, math.random(90, 110), 0.5)

		if not isfatal and IsValid(ply) and ply:Alive() then
			applyFallTrauma(ply, speed)
		end
	end
end)

local cvExplosionScale = CreateConVar("blsd_explosion_damage_scale", "1",
	{FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"Share of explosion damage a standing player takes. 1 is full.", 0, 4)

hook.Add("EntityTakeDamage", "MuR_DamageNPCThink", function(ent, dmg)
	local att = dmg:GetAttacker()
	local inf = dmg:GetInflictor()
	if IsValid(att.MindController) then
		att = att.MindController
	end

	if dmg:IsExplosionDamage() and dmg:GetDamage() > 10 and (ent:GetClass() == "prop_door_rotating" or ent:GetClass() == "func_door_rotating") then
		ent:SetHealth(1)
	end

	if att.isRDRag and IsValid(att.Owner) then
		dmg:SetAttacker(att.Owner)
		att = dmg:GetAttacker()
	end

	if dmg:GetDamageType() == DMG_BURN then
		dmg:SetDamage(dmg:GetDamage()*5)
	end

	if att:IsPlayer() then
		local wep = dmg:GetInflictor()
		local df = dmg:GetDamageForce()
		if dmg:IsBulletDamage() then
			dmg:SetDamageForce(df/20)
		end
	end

	if ent:IsPlayer() then
		local force = dmg:GetDamageForce()
		if force:IsZero() and (att:IsPlayer() or MuR.IsAI(att)) then
			force = att:GetAimVector()*100
		end
		local bone1 = ent:GetNearestBoneFromPos(dmg:GetDamagePosition(), force)
		if IsValid(ent:GetRD()) then
			bone1 = ent:GetRD():GetNearestBoneFromPos(dmg:GetDamagePosition(), force)
		end

		if MuR.IsAI(att) and dmg:GetDamageType() == 1 then
			dmg:SetDamage(0)
		end

		if !IsValid(ent:GetRD()) then
			if (bone1 == "ValveBiped.Bip01_Head1" or bone1 == "ValveBiped.Bip01_Neck1") and dmg:IsBulletDamage() then
				dmg:SetDamage(dmg:GetDamage()*2)
			elseif dmg:IsExplosionDamage() then
				dmg:SetDamage(dmg:GetDamage() * cvExplosionScale:GetFloat())
			elseif dmg:IsFallDamage() then
				dmg:SetDamage(dmg:GetDamage()*1)
			end
		end

		if att:IsPlayer() and MuR.Gamemode == 6 and att:Team() == ent:Team() then
			dmg:SetDamage(0)
			return true
		end
	end

	if ent:IsPlayer() and ent:Alive() then
		if !att:IsWorld() or att:IsWorld() and dmg:GetDamage() > 1 then
			ent.LastAttacker = att
		end

		local wep = ent:GetActiveWeapon()

		if IsValid(wep) and wep.GetBlocking and wep:GetBlocking() then
			dmg:ScaleDamage(0.5)
		end

		local isHeadshotBone = bone1 == "ValveBiped.Bip01_Head1" or bone1 == "ValveBiped.Bip01_Neck1"

		if dmg:IsFallDamage() and !ent:IsRoleWithoutOrgans() then
			ent:DamagePlayerSystem("bone")
		elseif dmg:IsBulletDamage() and !ent:IsRoleWithoutOrgans() then
			if dmg:GetDamage() > 6 and math.random(1, 100) <= 35 then
				ent:DamagePlayerSystem("blood")
			end
		elseif dmg:IsExplosionDamage() and !ent:IsRoleWithoutOrgans() then
			ent:DamagePlayerSystem("blood")
			if dmg:GetDamage() >= 40 or (isHeadshotBone and dmg:GetDamage() >= 20) then
				ent:StartRagdolling(dmg:GetDamage() / 35, dmg:GetDamage() / 7, dmg)
			end
		end

		if att:IsPlayer() then
			local wep2 = att:GetActiveWeapon()

			if att:IsAtBack(ent) and IsValid(wep2) and wep2.Melee then
				ent:StartRagdolling(math.Round(dmg:GetDamage() / 50), math.Round(dmg:GetDamage() / 2), dmg)
			end

			att.DamageTargetGuilt = att.DamageTargetGuilt - 1
			att.UnInnocentTime = CurTime() + 15

			if att.DamageTargetGuilt <= 0 and MuR.Gamemode ~= 5 and MuR.Gamemode ~= 6 and (att:Team() == 2 or att:Team() == 3) then
				att.DamageTargetGuilt = 3
				att:ChangeGuilt(0.1)
			end

			if IsValid(wep2) and wep2.Melee and wep2.BladeWeapon and math.random(1, 2) == 1 then
				ent:DamagePlayerSystem("blood")
			end
		end

		local painImpulse = dmg:GetDamage()
		if dmg:IsBulletDamage() then
			painImpulse = painImpulse * (isHeadshotBone and 0.35 or 0.12)
		elseif dmg:IsExplosionDamage() then
			painImpulse = painImpulse * 0.4
		elseif dmg:IsFallDamage() then
			painImpulse = painImpulse * 0.3
		end

		net.Start("MuR.PainImpulse")
		net.WriteFloat(math.Clamp(painImpulse, 0, 20))
		net.Send(ent)

		if ent:GetNW2Float("Guilt") >= 90 then
			dmg:ScaleDamage(100)
		end
	end

	local canBeWanted = not att:IsPlayer() or att:CanBecomeWanted()

	if canBeWanted and (ent.IsPolice or ent:IsRolePolice()) and att:IsPlayer() then
		if dmg:GetDamage() >= 10 then
			att:SetNW2Float("ArrestState", 2)
		elseif att:GetNW2Float("ArrestState") < 1 then
			att:SetNW2Float("ArrestState", 1)
		end
	end

	if canBeWanted and ent:IsPlayer() and att:IsPlayer() and MuR:VisibleByNPCs(att:WorldSpaceCenter()) then
		if att:GetNW2Float("ArrestState") == 0 then
			att:SetNW2Float("ArrestState", 1)
		end

		att:SetNW2Float("ArrestState", 2)
	end

	if canBeWanted and ent:IsPlayer() and att:IsPlayer() and att:Team() == 1 and dmg:GetDamage() >= ent:Health() and att:GetNW2Float("ArrestState") == 0 then
		att:SetNW2Float("ArrestState", 1)
	end

	if ent:GetNW2Bool("BreakableThing") and not dmg:IsBulletDamage() then
		local frs = dmg:GetDamageForce()/4
		if dmg:IsExplosionDamage() then
			frs = frs * 20
		end
		local dmg = dmg:GetDamage()
		ent:SetHealth(ent:Health() - dmg)

		if ent:Health() <= 0 and not ent.SpawnedBreaked then
			ent.SpawnedBreaked = true

			if string.match(ent:GetClass(), "prop_door_rotating") then
				local fallingDoor = ents.Create("prop_physics")
				fallingDoor:SetPos(ent:GetPos() + Vector(0, 0, 2))
				fallingDoor:SetAngles(ent:GetAngles())
				fallingDoor:TransferModelData(ent)
				fallingDoor:Spawn()
				fallingDoor:EmitSound(")ambient/materials/door_hit1.wav", 70, math.random(90,110))
				local ef = EffectData()
				ef:SetOrigin(ent:GetPos()+Vector(0,0,16))
				ef:SetNormal(frs:GetNormalized())
				util.Effect("MetalSpark", ef)
				ef:SetOrigin(ent:GetPos()+Vector(0,0,56))
				util.Effect("MetalSpark", ef)
				timer.Simple(0.001, function()
					if !IsValid(fallingDoor) then return end
					fallingDoor:SetNW2Bool("BreakableThing", true)
					fallingDoor:SetMaxHealth(250)
					fallingDoor:SetHealth(250)
					local phys = fallingDoor:GetPhysicsObject()
					if IsValid(phys) then
						phys:SetMass(100)
						phys:ApplyForceCenter(frs)
					end
				end)
			elseif not string.match(ent:GetClass(), "ragdoll") then
				local eff = ents.Create("prop_physics")
				eff:SetModel("models/props_interiors/Furniture_shelf01a.mdl")
				eff:SetPos(ent:WorldSpaceCenter())
				eff:SetAngles(ent:GetAngles())
				eff:Spawn()
				eff:Fire("Break")
			end

			ent:Remove()
		else
			if dmg >= 5 then
				ent:EmitSound("physics/wood/wood_box_impact_hard" .. math.random(1, 6) .. ".wav")
			end
		end
	end

	if dmg:GetDamage() > 1 then
		ent.LastDamageInfo = {dmg:GetDamageType(), dmg:GetDamagePosition(), dmg:IsExplosionDamage(), dmg:GetDamageForce(), dmg:IsBulletDamage(), dmg:IsFallDamage()}
	end

end)

hook.Add("EntityRemoved", "MuR.FixDoors", function(ent)
	if string.match(ent:GetClass(), "_door_") then
		for _, ap in ipairs(ents.FindByClass("func_areaportal")) do
			if ap:GetInternalVariable("target") == ent:GetName() then
				ap:Fire("Open")
				ap:SetSaveValue("target", "")
				break
			end
		end
	end
end)

hook.Add("AllowPlayerPickup", "MuR_WeaponsFuck", function(ply, ent)
	if ent:IsWeapon() then
		local entAmmoType = ent:GetPrimaryAmmoType()
		local entClip = ent:Clip1()

		if ply:HasWeapon(ent:GetClass()) then
			if entClip > 0 and entAmmoType > 0 then
				ply:GiveAmmo(entClip, entAmmoType, true)
				ent:SetClip1(0)
				ply:EmitSound("items/ammocrate_open.wav", 60)
			end
			return
		end

		if entAmmoType > 0 and entClip > 0 then
			for _, wep in ipairs(ply:GetWeapons()) do
				if wep:GetPrimaryAmmoType() == entAmmoType and wep:GetClass() ~= ent:GetClass() then
					ply:GiveAmmo(entClip, entAmmoType, true)
					ent:SetClip1(0)
					ply:EmitSound("items/ammocrate_open.wav", 60)
					return
				end
			end
		end

		ply:PickupWeapon(ent)

		if ent:GetMaxClip1() > 0 then
			ply:EmitSound("items/ammocrate_open.wav", 60)
		else
			ply:EmitSound("Flesh.ImpactSoft", 55)
		end

		ply:SelectWeapon(ent:GetClass())
	end
end)

hook.Add("PlayerCanPickupWeapon", "MuR_WeaponsFuck", function(ply, weapon)
	local ent = weapon.GiveToPlayer

	if IsValid(ent) and ply == ent then
		weapon.GiveToPlayer = nil
		return true
	else
		return false
	end
end)

hook.Add("WeaponEquip", "MuR_Fixes", function( weapon, ply )
	if MuR.Gamemode == 3 and weapon.IsTFAWeapon and weapon.Base == "tfa_gun_base" then
		timer.Simple(0, function()
			ply:DropWeapon( weapon )
		end)
	end
end)

hook.Add("PlayerUse", "MuR_DoorUse", function(ply, door)
	if door:GetClass() == "prop_door_rotating" or door:GetClass() == "func_door_rotating" then
		if not door.AntiDoorSpam or CurTime() - door.AntiDoorSpam > 0.5 and ply:GetNW2String("Class") ~= "Zombie" then
			door.AntiDoorSpam = CurTime()
		else
			return false
		end
	end
end)

hook.Add("AllowPlayerPickup", "MuR_DisableUseProp", function(ply, ent) return false end)

function meta:DropSuicideWeapon(wep)
	if not IsValid(wep) or wep.CantDrop then return end
	if hook.Run("CanDropWeapon", self, wep) == false then return end

	local throwDir = self:GetAimVector()
	if throwDir:LengthSqr() <= 0 then
		throwDir = self:GetForward()
	end

	self:DropWeapon(wep)

	if not IsValid(wep) then return end

	local phys = wep:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(throwDir * 140 + self:GetVelocity() + VectorRand(-45, 45) + Vector(0, 0, 40))
		phys:AddAngleVelocity(VectorRand(-120, 120))
	else
		wep:SetVelocity(throwDir * 140 + self:GetVelocity() + Vector(0, 0, 40))
	end
end

function meta:Suicide()
	local wep = self:GetActiveWeapon()
	if timer.Exists("MindControl_" .. self:EntIndex()) or self.Suiciding or not IsValid(wep) or wep.DisableSuicide or self:GetSVAnim() != "" then return false end

	if not wep.Melee then
		local maxclip = wep:GetMaxClip1() or 0
		if maxclip > 0 then
			if wep:Clip1() <= 0 then return false end
		else
			local ammoType = wep:GetPrimaryAmmoType()
			if ammoType and ammoType > 0 then
				if self:GetAmmoCount(ammoType) <= 0 then return false end
			else
				return false
			end
		end
	end

	local delay, delay2, anim = 0.8, 1, "mur_suicide"

	if wep.IsTFAWeapon and wep.Category == "Bloodshed - Sidearms" then
		delay, delay2, anim = 3.5, 3.65, "mur_suicide_Pistol"
	else
		delay, delay2, anim = 3.5, 3.65, "mur_suicide_rifle"
	end

	if isnumber(wep.Primary.Damage) and wep.Primary.Damage >= 45 then
		self.DeathBlowHead = true
	end

	self:Freeze(true)
	self.Suiciding = true
	self:SetSVAnimation(anim, true)

	timer.Simple(delay, function()
		if not IsValid(self) then return end

		if IsValid(wep) and wep.Primary.Sound and not wep.Melee then
			self:EmitSound(wep.Primary.Sound, 70)
		else
			self:EmitSound("physics/flesh/flesh_bloody_break.wav", 70)
		end

		local ef = EffectData()
		ef:SetOrigin(self:GetBonePosition(self:LookupBone("ValveBiped.Bip01_Head1")))
		ef:SetColor(0)
		util.Effect("BloodImpact", ef)
	end)

	timer.Simple(delay2, function()
		if not IsValid(self) then return end
		self.Suiciding = false
		self:Freeze(false)
		self:SetHealth(1)
		if IsValid(wep) and self:GetActiveWeapon() == wep then
			self:DropSuicideWeapon(wep)
		end

		if IsValid(wep) and wep.ShootSound then
			local att = game.GetWorld()
			local dmginfo = DamageInfo()

			dmginfo:SetDamage(self:Health()*10 + self:Armor())
			dmginfo:SetAttacker(att)
			dmginfo:SetInflictor(att)
			dmginfo:SetDamageType(DMG_BULLET)
			dmginfo:SetDamageForce(self:GetForward()*-1)

			local headPos = self:GetBonePosition(self:LookupBone("ValveBiped.Bip01_Head1"))
			dmginfo:SetDamagePosition(headPos)
			self:TakeDamageInfo(dmginfo)
		else
			self:TakeDamage(self:Health()*10 + self:Armor())
		end
	end)
end

hook.Add("CanPlayerSuicide", "MuR_SuicideAnimation", function(ply)
	if ply:GetNW2String("Class") == "Zombie" then
		return true
	end

	-- A downed player is already helpless and has dropped their weapon, so the
	-- weapon-animation suicide can never start. Let `kill` finish them off through
	-- the normal dying death path instead of leaving them stuck on the ground.
	if ply.IsDying and ply:IsDying() then
		ply:FinishDying(ply)
		return false
	end

	ply:Suicide()
	return false
end)

hook.Add("PlayerUse", "MuR_UseThings", function(ply, ent)
	local tab = ent:GetChildren()
	for _, e in pairs(tab) do
		if IsValid(e) and e:GetClass() == "murwep_ied" and IsValid(e.PlayerOwner) and ply != e.PlayerOwner and not e.UsedAlready then
			e.UsedAlready = true
			e:EmitSound("murdered/weapons/grenade/ied.wav", 60)
			timer.Simple(0.8, function()
				if !IsValid(e) then return end
				e:Explode()
			end)
			break
		end
	end
	if ent.MuR_LacedWith and !ply:IsKiller() then
		local substance, source = ent.MuR_LacedWith, ent.MuR_LacedBy
		ent.MuR_LacedWith = nil
		ent.MuR_LacedBy = nil

		if MuR.Chem then
			MuR.Chem:Apply(ply, substance, 1, IsValid(source) and source or nil)
		end
	end

	if ent:GetModel() == "models/props/cs_office/fire_extinguisher.mdl" then
		if ply:HasWeapon("mur_extinguisher") then
			return
		end

		ply:GiveWeapon("mur_extinguisher")
		local tname = "MuR_ExtinguisherSelect_" .. ply:EntIndex()
		timer.Create(tname, 0.05, 6, function()
			if not IsValid(ply) then
				timer.Remove(tname)
				return
			end
			if ply:HasWeapon("mur_extinguisher") then
				ply:SelectWeapon("mur_extinguisher")
				timer.Remove(tname)
			end
		end)
		ent:Remove()
	end
end)

hook.Add("EntityEmitSound", "MuR_QuieterRagdollSounds", function(data)
	if not IsValid(data.Entity) then return end

    if (data.Entity:GetClass() == "prop_ragdoll" or data.Entity:IsWorld()) and string.find(data.SoundName, "physics/body/") then
        data.Volume = data.Volume * 1
		data.SoundLevel = 60
        return true
    end
end)

hook.Add("SetupPlayerVisibility", "MuR_PoliceVisibility", function(ply, viewEntity)
	if not IsValid(ply) then return end

	if MuR.PoliceState == 5 and (ply:GetNW2String("Class") == "Officer" or ply:GetNW2String("Class") == "ArmoredOfficer" or ply:GetNW2String("Class") == "SWAT") then
		for _, target in player.Iterator() do
			if IsValid(target) and target != ply then
				AddOriginToPVS(target:GetPos())
			end
		end
	end
end)
