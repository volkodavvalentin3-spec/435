if not SERVER then return end

local okReq, reqErr = pcall(require, "bsbots")
if not okReq or not bsbots then
	print("[bsbots] модуль не загружен: " .. tostring(reqErr))
	return
end

-- Для работы шима нужна версия модуля с Tick/SetMode (1.7.0+: скрытые роли, полиция, цели режимов, предметы убийцы).
local function versionAtLeast(v, major, minor)
	local a, b = string.match(tostring(v), "^(%d+)%.(%d+)")
	a, b = tonumber(a) or 0, tonumber(b) or 0
	return a > major or (a == major and b >= minor)
end
if not (bsbots.Tick and bsbots.SetMode and bsbots.Version and versionAtLeast(bsbots.Version(), 1, 7)) then
	print("[bsbots] устаревшая версия модуля (" .. tostring(bsbots.Version and bsbots.Version()) .. "): нужна 1.7.0+, перезапустите игру с новой DLL")
	return
end

BSBots = BSBots or { Bots = {}, CurMode = nil, Sounds = {} }
BSBots.Sounds = BSBots.Sounds or {}

local MAX_VIEW = 4000
local FOV_COS = math.cos(math.rad(80)) -- поле зрения 160°
local ENEMY_REFRESH = 0.1              -- как часто пересчитывать видимость врагов (с)
local INV_REFRESH = 0.5

-- Бесконечные патроны у ботов (запас; магазин всё равно перезаряжается). Выключить: bsbots_infinite_ammo 0
local cvInfAmmo = CreateConVar("bsbots_infinite_ammo", "1", FCVAR_ARCHIVE, "Боты не расходуют запас патронов")
local function topUpAmmo(ply, st, now)
	if now < (st.nextAmmo or 0) or not cvInfAmmo:GetBool() then return end
	st.nextAmmo = now + 1
	for _, w in ipairs(ply:GetWeapons()) do
		local ammo = w:GetPrimaryAmmoType()
		local clip = w:GetMaxClip1()
		if ammo and ammo > 0 and clip > 0 then
			local want = math.max(clip * 6, 60)
			if ply:GetAmmoCount(ammo) < want then ply:SetAmmo(want, ammo) end
		end
	end
end

-- ---------- навмеш ----------
local function loadNav()
	local map = game.GetMap()
	local bytes = file.Read("maps/" .. map .. ".bsp", "GAME")
	if not bytes then print("[bsbots] не удалось прочитать maps/" .. map .. ".bsp") return false end
	file.CreateDir("bsbots")
	local ok, err = bsbots.LoadMap(bytes, "garrysmod/data/bsbots/" .. map .. ".nav")
	print(ok and ("[bsbots] навмеш готов: " .. map) or ("[bsbots] ошибка навмеша: " .. tostring(err)))
	return ok
end
hook.Add("InitPostEntity", "bsbots_load_nav", loadNav)
if CurTime() > 1 then loadNav() end

-- ---------- режим ----------
local MODE_NAMES = { [5] = "deathmatch", [6] = "zombies", [11] = "riot", [12] = "swat", [14] = "raid", [18] = "laststand",
	[20] = "firefight", [21] = "hotline", [22] = "protocol",
	[13] = "policeraid", [19] = "royale", [24] = "ambush",
	[2] = "shooter", [3] = "maniac", [10] = "terrorist",
	[1] = "classic", [4] = "traitor", [7] = "wildwest", [9] = "unknown", [25] = "policedept", [26] = "murder",
	[8] = "vip", [15] = "experiment", [16] = "storm", [17] = "gangs", [23] = "prisonbreak" }
local function modeName()
	return MuR and MODE_NAMES[MuR.Gamemode] or nil
end

-- Режимы с убийцей: номер режима -> true, если убийца активный (его видят все: Стрелок, Маньяк,
-- Террорист), false — если скрытый (мирные судят сами: свидетельство, подозрения, детектор, розыск).
-- Записи сливаются, а не заменяются: перезагрузка шима не теряет добавленные режимы.
BSBots.KillerModes = BSBots.KillerModes or {}
for k, v in pairs({ [2] = true, [3] = true, [10] = true, [1] = false, [4] = false, [7] = false,
	[9] = false, [25] = false, [26] = false, [8] = false, [16] = false }) do BSBots.KillerModes[k] = v end
local function killerMode() return MuR and BSBots.KillerModes[MuR.Gamemode] ~= nil end
local function activeKillerMode() return MuR and BSBots.KillerModes[MuR.Gamemode] == true end
local function isKiller(p)
	if not p.IsKiller then return false end
	local ok, r = pcall(p.IsKiller, p)
	return ok and r and true or false
end

-- Команда для ядра: в Заражении зомби — 2, остальные — 1; в командных режимах — номер команды движка.
local function teamOf(ply)
	if killerMode() then return isKiller(ply) and 1 or 2 end
	if MuR and MuR.Gamemode == 6 then
		return ply:GetNW2String("Class") == "Zombie" and 2 or 1
	end
	if MuR and MuR.Gamemode == 14 then return 1 end  -- в «Ready or Not» все игроки — один отряд
	-- Emergency Protocol: Entity и её твари — 2, остальные (ФБР) — 1; номера ролей тут не годятся
	if MuR and MuR.Gamemode == 22 then
		return ply:GetNW2String("Class") == "Entity" and 2 or 1
	end
	return ply:Team()
end

-- Какой видит бот команду другого игрока. Убийца знает всех; активного убийцу знают все.
-- В режимах со скрытым убийцей мирный враждебным считает только того, кто при нём напал (или ранил его).
local function seenTeam(viewer, other)
	if not killerMode() or activeKillerMode() or isKiller(viewer) then return teamOf(other) end
	local known = viewer.BSBKnown and viewer.BSBKnown[other]
	if known and known > CurTime() then return 1 end
	return 2
end

timer.Create("bsbots_mode", 1, 0, function()
	local m = modeName()
	if m ~= BSBots.CurMode then
		BSBots.CurMode = m
		if m then bsbots.SetMode(m) end
	end
end)

-- ---------- инвентарь ----------
local POOR_CLOSE = {
	["Bloodshed - Sniper Rifles"] = true, ["Bloodshed - Marksmans"] = true,
	["Bloodshed - Machine Guns"] = true, ["Bloodshed - Launchers"] = true,
}

-- Инструменты ролей: у тазера и перцового баллончика есть магазин, но это не огнестрел.
local TOOLS = {
	mur_taser = "taser", mur_handcuffs = "cuffs", mur_ziptie = "cuffs",
	mur_disguise = "disguise", mur_roledetector = "detector", mur_scanner = "scanner",
	mur_pepperspray = "tool",
	mur_cyanide = "cyanide", mur_ied = "ied", mur_beartrap = "beartrap",
	mur_loot_heroin = "heroin", mur_loot_adrenaline = "adrenaline",
	mur_poisoncanister = "canister", mur_trap_kit = "trapkit", mur_break_tool = "breaker",
	mur_flashbang = "grenade",
	mur_loot_hammer = "hammer", mur_loot_ducttape = "tape",
}

-- Оружие, которое есть только у убийцы: увидевший его в руках понимает, кто перед ним.
local KILLER_WEAPONS = { tfa_bs_combk = true, mur_cyanide = true, mur_ied = true, mur_poisoncanister = true,
	mur_trap_kit = true, mur_disguise = true, mur_scanner = true }

local function classify(w)
	if not IsValid(w) then return "hands" end
	local c = w:GetClass()
	if c == "mur_hands" then return "hands" end
	local tool = TOOLS[c]
	if tool then return tool end
	if c == "mur_loot_bandage" then return "bandage" end
	if c == "mur_loot_medkit" then return "medkit" end
	if c == "mur_f1" or c == "mur_m67" then return "grenade" end
	if c == "mur_zombie" then return "melee" end
	if c == "mur_entity_abilities" then return "melee" end  -- силовой удар Entity: прицелиться и нажать атаку
	-- у TFA-ножей флаг Melee не выставлен: смотрим категорию и базовый класс
	if w.Melee or w.Category == "Bloodshed - Melee" or (isstring(w.Base) and string.find(w.Base, "melee", 1, true)) then
		return "melee"
	end
	if w:GetMaxClip1() > 0 then return "firearm" end
	return "other"
end

-- Заряженное оружие всегда лучше пустого, дальше — по урону.
local function firearmScore(w)
	return (w:Clip1() > 0 and 1000 or 0) + (w.DamageMax or 0)
end

local function scanInventory(ply)
	local inv = { firearms = {} }
	for _, w in ipairs(ply:GetWeapons()) do
		local k = classify(w)
		if k == "firearm" then
			if (ply:GetAmmoCount(w:GetPrimaryAmmoType()) > 0 or w:Clip1() > 0) and not w.DisableSuicide then
				inv.firearms[#inv.firearms + 1] = w
				if not inv.firearm or firearmScore(w) > firearmScore(inv.firearm) then inv.firearm = w end
			end
		elseif k == "melee" then
			local d = w.Primary and w.Primary.Damage or 0
			if not inv.melee or d > (inv.melee.Primary and inv.melee.Primary.Damage or 0) then inv.melee = w end
		elseif k == "bandage" or k == "medkit" or k == "grenade" then
			inv[k] = w
		elseif k == "taser" then
			if w:Clip1() > 0 or ply:GetAmmoCount(w:GetPrimaryAmmoType()) > 0 then inv.taser = w end
		elseif k == "cuffs" or k == "disguise" or k == "detector" or k == "scanner" or k == "cyanide" or k == "ied"
			or k == "beartrap" or k == "heroin" or k == "adrenaline" or k == "canister" or k == "trapkit" or k == "breaker"
			or k == "hammer" or k == "tape" then
			inv[k] = w
		end
	end
	-- пустой ствол с патронами в запасе: в спокойной обстановке его стоит достать и перезарядить
	for _, w in ipairs(inv.firearms) do
		-- из регдолла стреляют только TFA-стволы (геймод держит их в руках через TPIK)
		if w.IsTFAWeapon and not w.TPIKDisabled and (not inv.tfa or firearmScore(w) > firearmScore(inv.tfa)) then inv.tfa = w end
		if w:Clip1() <= 0 and ply:GetAmmoCount(w:GetPrimaryAmmoType()) > 0 then
			if not inv.needReload or (w.DamageMax or 0) > (inv.needReload.DamageMax or 0) then inv.needReload = w end
		end
	end
	inv.closeOk = not (inv.firearm and POOR_CLOSE[inv.firearm.Category])
	return inv
end

-- ---------- видимость и точка прицеливания ----------
-- Целимся в кость груди (у лежачего — в регдолл), а не в центр модели.
local function aimPoint(target, rd)
	local ent = IsValid(rd) and rd or target
	local bone = ent:LookupBone("ValveBiped.Bip01_Spine2") or ent:LookupBone("ValveBiped.Bip01_Head1")
	if bone then
		local p = ent:GetBonePosition(bone)
		if p and p ~= vector_origin then return p end
	end
	return ent:WorldSpaceCenter()
end

local function canSee(ply, target)
	local rd = target.GetRD and target:GetRD() or nil
	local tpos = aimPoint(target, rd)
	local eye = ply:EyePos()
	local d = tpos - eye
	local dist = d:Length()
	if dist > MAX_VIEW then return false, tpos, IsValid(rd), rd end
	if dist > 250 and ply:EyeAngles():Forward():Dot(d:GetNormalized()) < FOV_COS then return false, tpos, IsValid(rd), rd end
	local tr = util.TraceLine({ start = eye, endpos = tpos, filter = { ply, target, rd }, mask = MASK_SHOT })
	return not tr.Hit, tpos, IsValid(rd), rd
end

-- Враждебные NPC режима: зомби («Заражение», Last Stand) или не сдавшиеся подозреваемые («Ready or Not»).
local ZOMBIE_NPCS = { "npc_bs_zombie", "npc_bs_nz_vermin", "npc_bs_nz_mangler", "npc_bs_nz_amalgam", "npc_bs_nz_mimic" }
-- наёмники «Last Stand - Ambush» (режим 24)
local PMC_NPCS = { "npc_bs_pmc", "npc_bs_pmc_armored", "npc_bs_pmc_explosive", "npc_bs_pmc_juggernaut", "npc_bs_pmc_flame", "npc_bs_pmc_gas" }
local POLICE_NPCS = { "npc_bs_police", "npc_bs_swat" }
local function hostileNpcs(ply)
	local out = {}
	local g = MuR and MuR.Gamemode
	if killerMode() then
		-- полиция и спецназ охотятся на убийцу; мирным они не враги
		if not isKiller(ply) then return out end
		for _, c in ipairs(POLICE_NPCS) do
			for _, z in ipairs(ents.FindByClass(c)) do
				if IsValid(z) and z:Health() > 0 then out[#out + 1] = { z = z } end
			end
		end
	elseif g == 6 or g == 18 or g == 22 then
		for _, c in ipairs(ZOMBIE_NPCS) do
			for _, z in ipairs(ents.FindByClass(c)) do
				if IsValid(z) and z:Health() > 0 then out[#out + 1] = { z = z } end
			end
		end
	elseif g == 24 then
		for _, c in ipairs(PMC_NPCS) do
			for _, z in ipairs(ents.FindByClass(c)) do
				if IsValid(z) and z:Health() > 0 then out[#out + 1] = { z = z } end
			end
		end
	elseif g == 17 then
		if not (MuR.Mode17 and MuR.Mode17.PoliceDisabled) then return out end
		for _, c in ipairs(POLICE_NPCS) do
			for _, z in ipairs(ents.FindByClass(c)) do
				if IsValid(z) and z:Health() > 0 then out[#out + 1] = { z = z } end
			end
		end
	elseif g == 14 then
		for _, z in ipairs(ents.FindByClass("npc_bs_suspect")) do
			if IsValid(z) and z:Health() > 0 and not z.Surrendering and (not z.IsCivilian or z.HasRevealed) then
				out[#out + 1] = { z = z }
			end
		end
	end
	return out
end

local function refreshEnemies(ply, st, now)
	if st.enemiesAt and now - st.enemiesAt < ENEMY_REFRESH then return st.enemies end
	local list = {}
	-- значок розыска видит только полиция; «видел нападение» — из памяти свидетеля (и детектора)
	local okC, cop = pcall(function() return ply.IsRolePolice and ply:IsRolePolice() end)
	cop = okC and cop and true or false
	local known = ply.BSBKnown or {}
	for _, other in ipairs(player.GetAll()) do
		if other ~= ply and other:Alive() then
			local vis, tpos, down, rd = canSee(ply, other)
			-- невидимую Entity замечают только вплотную или когда она бьёт
			if vis and MuR.Gamemode == 22 and other:GetNW2String("Class") == "Entity"
				and tpos:Distance(ply:EyePos()) > 300
				and not (ply.BSBAttacker == other:UserID() and CurTime() - (ply.BSBAttackedAt or -1e6) < 3) then
				vis = false
			end
			local v = vis and ((IsValid(rd) and rd:GetVelocity()) or other:GetVelocity()) or vector_origin
			local armed, yaw = 0, 0
			if vis then
				local aw = other:GetActiveWeapon()
				local k = classify(aw)
				armed = (IsValid(aw) and KILLER_WEAPONS[aw:GetClass()] and 3) or (k == "firearm" and 2) or (k == "melee" and 1) or 0
				yaw = other:EyeAngles().y
			end
			local okR, restrained = pcall(function() return other.IsRestrained and other:IsRestrained() end)
			list[#list + 1] = {
				id = other:UserID(), visible = vis, down = down or false,
				x = vis and tpos.x or 0, y = vis and tpos.y or 0, z = vis and tpos.z or 0, -- позиция невидимого не передаётся
				vx = v.x, vy = v.y, vz = v.z,
				health = other:Health(), team = seenTeam(ply, other),
				armed = armed, yaw = yaw,
				attackSeen = (known[other] or 0) > now,
				wanted = cop and other:GetNW2Float("ArrestState", 0) or 0,
				restrained = (okR and restrained) and true or false,
				vip = MuR.Gamemode == 8 and other:GetNW2String("Class") == "VIP",
				poisoned = ((ply.BSBPoisoned or {})[other] or 0) > now,
			}
		end
	end
	-- NPC-враги режима (зомби, подозреваемые), команда 2; ближайшие, чтобы не плодить трассы
	local npcs, epos = hostileNpcs(ply), ply:GetPos()
	for _, n in ipairs(npcs) do n.d = n.z:GetPos():DistToSqr(epos) end
	table.sort(npcs, function(a, b) return a.d < b.d end)
	for i = 1, math.min(#npcs, 12) do
		local z = npcs[i].z
		local vis, tpos = canSee(ply, z)
		local v = vis and z:GetVelocity() or vector_origin
		list[#list + 1] = {
			id = 100000 + z:EntIndex(), visible = vis, down = false,
			x = vis and tpos.x or 0, y = vis and tpos.y or 0, z = vis and tpos.z or 0,
			vx = v.x, vy = v.y, vz = v.z, health = z:Health(), team = 2,
		}
	end
	st.enemies, st.enemiesAt = list, now
	return list
end

-- ---------- предметы на полу ----------
local LOOT_REFRESH = 0.6
local LOOT_RANGE = 1800

local function lootKind(ply, e)
	local k = classify(e)
	if k == "melee" or k == "bandage" or k == "medkit" or k == "grenade" then return k end
	if k == "hammer" or k == "tape" then return "tool" end   -- заколотить дверь
	if k ~= "firearm" then return nil end
	if e:Clip1() <= 0 and not cvInfAmmo:GetBool() then return nil end
	-- патроны к оружию, которое у бота уже есть, подбираются как боеприпасы
	local ammo = e:GetPrimaryAmmoType()
	for _, w in ipairs(ply:GetWeapons()) do
		if w:GetClass() == e:GetClass() or (ammo > 0 and w:GetPrimaryAmmoType() == ammo) then return "ammo" end
	end
	return "firearm"
end

local PERKS = { "juggernog", "quickrevive", "doubletap", "speedcola", "staminup", "deadshot", "phd", "melee" }

local function perkAffordable(ply)
	if not (MuR.Mode18 and MuR.Mode18.State ~= "wave") then return false end
	local owned = ply.Mode18Perks or {}
	return ply:GetNWInt("MuR_ZombiesPoints", 0) >= 2000 + table.Count(owned) * 250 and table.Count(owned) < #PERKS
end

local function worldLootKind(ply, e)
	local c = e:GetClass()
	if c == "mode18_powerup" then return "powerup" end
	if c == "mode18_perkmachine" and MuR.Gamemode == 18 and perkAffordable(ply) then return "perk" end
end

local function scanLoot(ply, st, now)
	if st.lootAt and now - st.lootAt < LOOT_REFRESH then return st.loot end
	local out, eye = {}, ply:EyePos()
	for _, e in ipairs(ents.FindInSphere(ply:GetPos(), LOOT_RANGE)) do
		local isWeapon = IsValid(e) and e:IsWeapon() and not IsValid(e:GetOwner())
		if isWeapon or (IsValid(e) and MuR.Gamemode == 18) then
			local kind = isWeapon and lootKind(ply, e) or worldLootKind(ply, e)
			-- «Убийство» (26): убийца огнестрел не удержит — геймод заставляет его бросить
			if (kind == "firearm" or kind == "ammo") and MuR.Gamemode == 26 and isKiller(ply) then kind = nil end
			if kind then
				local p = e:WorldSpaceCenter()
				local tr = util.TraceLine({ start = eye, endpos = p, filter = { ply, e }, mask = MASK_SOLID_BRUSHONLY })
				if not tr.Hit then
					out[#out + 1] = { id = e:EntIndex(), kind = kind, x = p.x, y = p.y, z = p.z, ent = e }
					if #out >= 16 then break end
				end
			end
		end
	end
	st.loot, st.lootAt = out, now
	return out
end

-- ---------- блокер впереди (стекло, ломаемые объекты) ----------
local function scanBlocker(ply, st, now)
	if st.blockerAt and now - st.blockerAt < 0.25 then return st.blockerKind or 0, st.blockerDist or 1e9 end
	st.blockerAt = now
	st.blockerKind, st.blockerDist = 0, 1e9
	if ply:GetVelocity():Length2D() > 40 then return 0, 1e9 end
	local ang = Angle(0, ply:EyeAngles().y, 0)
	local pos = ply:GetPos() + Vector(0, 0, 36)
	local tr = util.TraceHull({
		start = pos, endpos = pos + ang:Forward() * 70,
		mins = Vector(-8, -8, -20), maxs = Vector(8, 8, 20), filter = ply,
	})
	local e = tr.Entity
	if tr.Hit and IsValid(e) and not e:IsPlayer() and not e:IsWorld() then
		local c = e:GetClass()
		if c == "func_breakable_surf" or (c == "func_breakable" and e:Health() > 0) then
			st.blockerKind, st.blockerDist = 1, tr.Fraction * 70
		elseif (c == "prop_physics" or c == "prop_dynamic") and e:Health() > 0 then
			st.blockerKind, st.blockerDist = 2, tr.Fraction * 70
		end
	end
	return st.blockerKind, st.blockerDist
end

-- ---------- звуки и направление урона ----------
local function addSound(pos, loud, owner)
	local list = BSBots.Sounds
	list[#list + 1] = { pos = pos, t = CurTime(), loud = loud, owner = owner }
	if #list > 64 then table.remove(list, 1) end
end

hook.Add("EntityFireBullets", "bsbots_sound_shot", function(ent, data)
	if IsValid(ent) and ent:IsPlayer() then addSound(data.Src or ent:EyePos(), true, ent) end
end)

hook.Add("PlayerFootstep", "bsbots_sound_step", function(ply, pos)
	if ply:GetVelocity():Length2D() > 150 then addSound(pos, false, ply) end
end)

local function collectSounds(ply, now)
	local out = {}
	for i = #BSBots.Sounds, 1, -1 do
		local s = BSBots.Sounds[i]
		local age = now - s.t
		if age > 6 then break end
		if s.owner ~= ply then
			out[#out + 1] = { x = s.pos.x, y = s.pos.y, z = s.pos.z, age = age, loud = s.loud }
			if #out >= 8 then break end
		end
	end
	return out
end

-- Кто и откуда ранил бота: приоритет цели и направление удара (с небольшим шумом).
hook.Add("EntityTakeDamage", "bsbots_hurt_dir", function(target, dmg)
	if not (IsValid(target) and target:IsPlayer() and target.BSB) then return end
	local att = dmg:GetAttacker()
	if IsValid(att) and att ~= target then
		local d = att:GetPos() - target:GetPos()
		target.BSBHurtYaw = d:Angle().y + math.Rand(-20, 20)
		target.BSBHurtAt = CurTime()
	end
end)

-- Свидетели нападения: бот запоминает нападавшего, если сам ранен им или видел удар своими глазами.
-- Удар по тому, кого бот уже считает убийцей, — самооборона и подозрения не вызывает.
hook.Add("PostEntityTakeDamage", "bsbots_witness", function(victim, dmg, took)
	if not took or not killerMode() or activeKillerMode() then return end
	local att = dmg:GetAttacker()
	if not (IsValid(att) and att:IsPlayer() and IsValid(victim) and victim:IsPlayer() and att ~= victim) then return end
	if att.IsRolePolice and att:IsRolePolice() then return end
	local now = CurTime()
	for _, b in pairs(BSBots.Bots) do
		if IsValid(b) and b ~= att and b:Alive() then
			b.BSBKnown = b.BSBKnown or {}
			local selfDefence = (b.BSBKnown[victim] or 0) > now
			if not selfDefence and (b == victim or canSee(b, att)) then
				b.BSBKnown[att] = now + 120
			end
		end
	end
end)

hook.Add("PlayerHurt", "bsbots_attacker", function(victim, attacker)
	if IsValid(victim) and victim.BSB and IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
		victim.BSBAttacker = attacker:UserID()
		victim.BSBAttackedAt = CurTime()
	end
end)

-- ---------- трупы ----------
-- Время смерти помечаем сами: на трупе геймод его не хранит. Предсмертный звук слышен рядом.
hook.Add("PlayerDeath", "bsbots_corpse_time", function(victim)
	if not IsValid(victim) then return end
	local t = CurTime()
	addSound(victim:GetPos() + Vector(0, 0, 40), false, victim)
	timer.Simple(0.3, function()
		for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
			if IsValid(rag) and rag.IsDead and rag.OwnerDead == victim and not rag.BSBDeathTime then
				rag.BSBDeathTime = t
			end
		end
	end)
end)

-- Свежие трупы в поле зрения (не старше минуты).
local function scanCorpses(ply, st, now)
	if st.corpsesAt and now - st.corpsesAt < 0.5 then return st.corpses end
	local out, eye = {}, ply:EyePos()
	local fwd = ply:EyeAngles():Forward()
	for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
		if IsValid(rag) and rag.IsDead and rag.BSBDeathTime and now - rag.BSBDeathTime <= 60 then
			local p = rag:WorldSpaceCenter()
			local d = p - eye
			local dist = d:Length()
			if dist < 2000 and (dist < 250 or fwd:Dot(d:GetNormalized()) >= FOV_COS) then
				local tr = util.TraceLine({ start = eye, endpos = p, filter = { ply, rag }, mask = MASK_SOLID_BRUSHONLY })
				if not tr.Hit then
					out[#out + 1] = { id = rag:EntIndex(), x = p.x, y = p.y, z = p.z, age = now - rag.BSBDeathTime }
					if #out >= 16 then break end
				end
			end
		end
	end
	st.corpses, st.corpsesAt = out, now
	return out
end

-- Сканер убийцы: раз в 6 с — где люди в радиусе 1600 (то же, что видит игрок-убийца).
local function scanContacts(ply, st, now, inv)
	if not (inv.scanner and isKiller(ply)) then return {} end
	if st.contactsAt and now - st.contactsAt < 6 then return st.contacts end
	local out, eye = {}, ply:EyePos()
	for _, other in ipairs(player.GetAll()) do
		if other ~= ply and other:Alive() and not isKiller(other) then
			local rd = other.GetRD and other:GetRD()
			local p = IsValid(rd) and rd:WorldSpaceCenter() or other:GetPos()
			if p:DistToSqr(eye) < 1600 * 1600 then
				out[#out + 1] = { x = p.x, y = p.y, z = p.z }
				if #out >= 12 then break end
			end
		end
	end
	st.contacts, st.contactsAt = out, now
	return out
end

-- ---------- наблюдение ----------
local HOLDABLE = { hands = true, firearm = true, melee = true, bandage = true, medkit = true, grenade = true,
	taser = true, cuffs = true, disguise = true, detector = true,
	cyanide = true, ied = true, beartrap = true, heroin = true, adrenaline = true }

local function collectAllies(ply, st, now)
	if st.alliesAt and now - st.alliesAt < 0.2 then return st.allies end
	local out = {}
	if BSBots.CurMode ~= "deathmatch" and BSBots.CurMode ~= "royale" and BSBots.CurMode ~= "experiment" then
		local mine = teamOf(ply)
		for _, other in ipairs(player.GetAll()) do
			if other ~= ply and other:Alive() and seenTeam(ply, other) == mine then
				local p, v = other:GetPos(), other:GetVelocity()
				out[#out + 1] = {
					id = other:UserID(), x = p.x, y = p.y, z = p.z, vx = v.x, vy = v.y, vz = v.z,
					human = not other:IsBot(),
					vip = other:GetNW2String("Class") == "VIP", guard = other:GetNW2String("Class") == "VIPGuard",
				}
				if #out >= 32 then break end
			end
		end
	end
	st.allies, st.alliesAt = out, now
	return out
end

-- ---------- цели режимов ----------
-- Торнадо (16): тревога — 20 с после того, как геймод выбрал новый центр; дальше — пока торнадо идёт.
local function tornadoHazard(now)
	if not (MuR.Gamemode == 16 and isvector(MuR.TornadoCenter)) then BSBots.TornadoSeen = nil return 0 end
	local c = MuR.TornadoCenter
	if MuR.TornadoActive then BSBots.TornadoSeen = c return 2, c end
	if BSBots.TornadoSeen ~= c then BSBots.TornadoSeen, BSBots.TornadoWarnAt = c, now end
	if now - (BSBots.TornadoWarnAt or -1e9) < 20 then return 1, c end
	return 0
end

-- Точки захвата (17): позиция и чья (номер команды, 0 — ничья).
local function captureObjectives()
	local out = {}
	if MuR.Gamemode ~= 17 or not (MuR.Mode17 and MuR.Mode17.Points) then return out end
	for _, p in pairs(MuR.Mode17.Points) do
		local pos = p.pos or (IsValid(p.entity) and p.entity:GetPos())
		if pos then
			out[#out + 1] = { x = pos.x, y = pos.y, z = pos.z, owner = p.team or 0 }
			if #out >= 8 then break end
		end
	end
	return out
end

local function buildObs(ply, st)
	local now = CurTime()
	local active = ply:GetActiveWeapon()
	local holding = classify(active)
	local activeEmpty = IsValid(active) and holding == "firearm" and active:Clip1() == 0
	if not st.inv or now - (st.invAt or 0) > INV_REFRESH or (activeEmpty and now - (st.invAt or 0) > 0.1) then
		st.inv, st.invAt = scanInventory(ply), now
	end
	local inv = st.inv
	local pos, eye, ang = ply:GetPos(), ply:EyePos(), ply:EyeAngles()
	local clip, clipMax, reserve = 0, 0, 0
	if IsValid(active) and (holding == "firearm" or holding == "taser") then
		clip, clipMax, reserve = active:Clip1(), active:GetMaxClip1(), ply:GetAmmoCount(active:GetPrimaryAmmoType())
	end
	local altLoaded = false
	for _, w in ipairs(inv.firearms or {}) do
		if IsValid(w) and w ~= active and w:Clip1() > 0 then altLoaded = true break end
	end
	local blockerKind, blockerDist = scanBlocker(ply, st, now)
	local ragdoll = IsValid(ply:GetRD())
	local canGetUp = false
	if ragdoll then
		local okG, res = pcall(function() return ply:TimeGetUp(true) and ply:CanGetUp() end)
		canGetUp = okG and res and true or false
	end
	-- занят: серверная анимация, без сознания или в наручниках — действовать нечем
	local busy = ply:GetNWString("SVAnim") ~= "" or ply:GetNW2Bool("IsUnconscious", false)
	if not busy and ply.IsRestrained then
		local okR, restrained = pcall(ply.IsRestrained, ply)
		busy = okR and restrained and true or false
	end
	-- Battle Royale: безопасная зона (за её границей газ)
	local zoneR, zc = 0, vector_origin
	local zone = MuR.Gamemode == 19 and MuR.Mode19 and MuR.Mode19.ZoneEntity
	if IsValid(zone) and zone.GetRadius then zoneR, zc = zone:GetRadius() or 0, zone:GetPos() end
	local roundActive = MuR.GameStarted and not MuR.Ending and (MuR.TimeCount or 0) + 13 < now
	local okP, police = pcall(function() return ply.IsRolePolice and ply:IsRolePolice() end)
	local hz, hc = tornadoHazard(now)
	hc = hc or vector_origin
	-- Побег из тюрьмы (23): до прихода охраны заключённые собираются у тайника
	local rally, rp = false, vector_origin
	if MuR.Gamemode == 23 and MuR.Mode23 and not MuR.Mode23.GuardsSpawned and ply:Team() == 1
		and isvector(MuR.Mode23.PrisonerLootSpawn) and MuR.Mode23.PrisonerLootSpawn ~= vector_origin then
		rally, rp = true, MuR.Mode23.PrisonerLootSpawn
	end
	local cls = ply:GetNW2String("Class")
	return {
		id = ply:UserID(), time = now, dt = engine.TickInterval(),
		px = pos.x, py = pos.y, pz = pos.z, ex = eye.x, ey = eye.y, ez = eye.z,
		yaw = ang.y, pitch = ang.p, health = ply:Health(),
		bleed = ply:GetNW2Float("BleedLevel"), team = teamOf(ply),
		alive = ply:Alive(), busy = busy and true or false, roundActive = roundActive and true or false,
		onGround = ply:OnGround(),
		hasFirearm = (ragdoll and inv.tfa ~= nil) or (not ragdoll and inv.firearm ~= nil), hasMelee = inv.melee ~= nil,
		hasBandage = inv.bandage ~= nil, hasMedkit = inv.medkit ~= nil, hasGrenade = inv.grenade ~= nil,
		zoneR = zoneR, zx = zc.x, zy = zc.y, zz = zc.z,
		ragdoll = ragdoll, canGetUp = canGetUp, loot = scanLoot(ply, st, now), allies = collectAllies(ply, st, now),
		holding = HOLDABLE[holding] and holding or "hands",
		stability = ply:GetNW2Float("Stability", 100),
		isKiller = isKiller(ply), isPolice = (okP and police) and true or false,
		isWitness = cls == "Witness", isVip = cls == "VIP", isGuard = cls == "VIPGuard",
		hasCyanide = inv.cyanide ~= nil, hasIed = inv.ied ~= nil,
		iedPlanted = inv.ied ~= nil and inv.ied.DetonateDrawed == true,
		hasBeartrap = inv.beartrap ~= nil, hasHeroin = inv.heroin ~= nil, hasAdrenaline = inv.adrenaline ~= nil,
		hasTool = inv.hammer ~= nil or inv.tape ~= nil,
		objectives = captureObjectives(), stormy = MuR.Gamemode == 16,
		hazard = hz, hx = hc.x, hy = hc.y, hz = hc.z, hr = hz > 0 and 2400 or 0,
		rally = rally, rx = rp.x, ry = rp.y, rz = rp.z, rr = rally and 600 or 0,
		hasDisguise = inv.disguise ~= nil, hasScanner = inv.scanner ~= nil, hasTaser = inv.taser ~= nil,
		hasCuffs = inv.cuffs ~= nil, hasDetector = inv.detector ~= nil,
		corpses = scanCorpses(ply, st, now), contacts = scanContacts(ply, st, now, inv),
		clip = clip, clipMax = clipMax, reserve = reserve,
		firearmCloseOk = inv.closeOk ~= false, altLoaded = altLoaded,
		blockerKind = blockerKind, blockerDist = blockerDist,
		hurtYaw = ply.BSBHurtYaw or 0, hurtAge = now - (ply.BSBHurtAt or -1e6),
		attackerId = ply.BSBAttacker or -1, attackerAge = now - (ply.BSBAttackedAt or -1e6),
		sounds = collectSounds(ply, now),
		enemies = refreshEnemies(ply, st, now),
	}
end

-- ---------- покупки Last Stand (режим 18) ----------
-- Автомат с перком открывается меню на клиенте; бот шлёт ту же покупку обработчику сети напрямую.
local function buyPerk(ply, machine)
	local recv = net.Receivers and net.Receivers["mur.mode18buyperk"]
	if not recv then return end
	ply.Mode18Perks = ply.Mode18Perks or {}
	local before = ply:GetNWInt("MuR_ZombiesPoints", 0)
	local order = table.Copy(PERKS)
	table.Shuffle(order)
	local oldEnt, oldStr = net.ReadEntity, net.ReadString
	for _, id in ipairs(order) do
		if not ply.Mode18Perks[id] then
			net.ReadEntity = function() return machine end
			net.ReadString = function() return id end
			pcall(recv, 0, ply)
			if ply:GetNWInt("MuR_ZombiesPoints", 0) < before then break end
		end
	end
	net.ReadEntity, net.ReadString = oldEnt, oldStr
end

-- Магазин за очки: самое дорогое из доступного, по одной покупке за раз.
local function shopPhase(ply, st, now)
	if not (MuR and MuR.Gamemode == 18 and MuR.Shop and ply.BuyItem) then return end
	if now < (st.nextShop or 0) then return end
	st.nextShop = now + 4
	local points = ply:GetNWInt("MuR_ZombiesPoints", 0)
	-- на автомат с перком копим, пока он есть на карте
	if #ents.FindByClass("mode18_perkmachine") > 0 and points < 2000 + table.Count(ply.Mode18Perks or {}) * 250 + 300 then return end
	local cands = {}
	for _, cat in ipairs({ "Soldier", "Civilian" }) do
		for id, item in pairs(MuR.Shop[cat] or {}) do
			local price = item.zombieprice
			if price and price > 0 and price <= points then cands[#cands + 1] = { cat = cat, id = id, price = price } end
		end
	end
	table.sort(cands, function(a, b) return a.price > b.price end)
	for _, c in ipairs(cands) do
		pcall(ply.BuyItem, ply, c.cat, c.id)
		if ply:GetNWInt("MuR_ZombiesPoints", 0) < points then st.invAt = 0 return end
	end
end

-- ---------- исполнение ----------
local function applyAction(ply, cmd, act, st)
	cmd:ClearMovement()
	cmd:ClearButtons()
	local speed = ply:GetRunSpeed()
	cmd:SetForwardMove(act.forward * speed)
	cmd:SetSideMove(act.side * speed)
	local ang = Angle(act.pitch, act.yaw, 0)
	cmd:SetViewAngles(ang)
	ply:SetEyeAngles(ang)

	local now = CurTime()
	-- TFA перезаряжает по отпусканию R, если её держали меньше 0.3 с; удержание лишь показывает патроны.
	-- Поэтому R — короткий импульс раз в 0.8 с, пока ядро просит перезарядку.
	if act.reload and now >= (st.reloadNext or 0) then
		st.reloadNext = now + 0.8
		st.reloadUntil = now + 0.06
	end
	local reloading = now < (st.reloadUntil or 0)

	local btn = 0
	if act.jump then btn = bit.bor(btn, IN_JUMP) end
	if act.crouch then btn = bit.bor(btn, IN_DUCK) end
	if act.attack then btn = bit.bor(btn, IN_ATTACK) end
	if act.attack2 then btn = bit.bor(btn, IN_ATTACK2) end
	if reloading then btn = bit.bor(btn, IN_RELOAD) end
	if act.sprint and not act.reload then btn = bit.bor(btn, IN_SPEED) end
	cmd:SetButtons(btn)

	-- пинок (серверная функция Bloodshed; поле MFNextKick обычно выставляет клиент)
	if act.kick and now >= (st.nextKickAt or 0) then
		st.nextKickAt = now + 1.2
		if not ply.MFNextKick then ply.MFNextKick = 0 end
		if MightyFootEngaged then pcall(MightyFootEngaged, ply) end
	end

	-- подбор предмета с пола (та же ветка, что и при подборе игроком)
	if act.use and now >= (st.nextUse or 0) then
		st.nextUse = now + 0.5
		local best, bd = nil, 110
		for _, l in ipairs(st.loot or {}) do
			if IsValid(l.ent) and l.kind ~= "powerup" and not IsValid(l.ent:GetOwner()) then
				local d = l.ent:WorldSpaceCenter():Distance(ply:GetPos() + Vector(0, 0, 32))
				if d < bd then best, bd = l.ent, d end
			end
		end
		if best and best:GetClass() == "mode18_perkmachine" then
			pcall(buyPerk, ply, best)
		elseif best then
			best.GiveToPlayer = ply
			pcall(hook.Run, "AllowPlayerPickup", ply, best)
			st.invAt = 0
		end
	end

	-- цианид: кого укололи — тот для этого убийцы уже отравлен
	if act.want == "cyanide" and act.attack then
		local eye = ply:EyePos()
		local tr = util.TraceLine({ start = eye, endpos = eye + ply:GetAimVector() * 64, filter = ply, mask = MASK_SHOT })
		local tar = tr.Entity
		if IsValid(tar) and tar.isRDRag and IsValid(tar.Owner) then tar = tar.Owner end
		if IsValid(tar) and tar.IsPlayer and tar:IsPlayer() then
			ply.BSBPoisoned = ply.BSBPoisoned or {}
			ply.BSBPoisoned[tar] = now + 90
		end
	end

	-- детектор ролей: щелчок по цели запускает скан; через 2 с израсходованный детектор сообщает роль
	if act.want == "detector" and act.attack and not st.scanTarget then
		local eye = ply:EyePos()
		local tr = util.TraceLine({ start = eye, endpos = eye + ply:GetAimVector() * 100, filter = ply, mask = MASK_SHOT })
		local tar = tr.Entity
		if IsValid(tar) and tar.isRDRag and IsValid(tar.Owner) then tar = tar.Owner end
		if IsValid(tar) and tar.IsPlayer and tar:IsPlayer() then st.scanTarget, st.scanAt = tar, now end
	end
	if st.scanTarget and now - st.scanAt > 2.2 then
		if not ply:HasWeapon("mur_roledetector") and IsValid(st.scanTarget) and isKiller(st.scanTarget) then
			ply.BSBKnown = ply.BSBKnown or {}
			ply.BSBKnown[st.scanTarget] = now + 600
		end
		st.scanTarget = nil
	end

	-- встать из регдолла
	if act.getUp then
		pcall(function()
			if ply:TimeGetUp(true) and ply:CanGetUp() then ply:StopRagdolling(false, true) end
		end)
	end

	-- регдолл: стрельба лёжа — стойка (как F у игрока) и TFA-ствол в руках; ползком — пустые руки,
	-- иначе поочерёдные нажатия кнопок ползания стреляли бы из ствола
	if IsValid(ply:GetRD()) then
		local active = ply:GetActiveWeapon()
		if act.state == "rdshoot" then
			ply.IsRagStanding = true
			local w = st.inv and st.inv.tfa
			if IsValid(w) and active ~= w and now >= (st.nextSelect or 0) then
				ply:SelectWeapon(w:GetClass()) st.nextSelect = now + 0.33
			end
		elseif IsValid(active) and classify(active) ~= "hands" and now >= (st.nextSelect or 0) then
			ply:SelectWeapon("mur_hands") st.nextSelect = now + 0.33
		end
	-- смена оружия (не чаще 3 раз в секунду)
	elseif now >= (st.nextSelect or 0) then
		local active = ply:GetActiveWeapon()
		if act.want == "hands" then
			if not IsValid(active) or classify(active) ~= "hands" then ply:SelectWeapon("mur_hands") st.nextSelect = now + 0.33 end
		else
			local w = st.inv and st.inv[act.want]
			if st.forceWeapon and ply:HasWeapon(st.forceWeapon) then w = ply:GetWeapon(st.forceWeapon) end
			local calm = act.state == "patrol" or act.state == "investigate" or act.state == "search"
			if act.want == "firearm" and calm and st.inv and IsValid(st.inv.needReload) then w = st.inv.needReload end
			if IsValid(w) and active ~= w then ply:SelectWeapon(w:GetClass()) st.nextSelect = now + 0.33 end
		end
	end
end

-- ---------- рефлексы игровых механик ----------
local function doorReflex(ply, st)
	local now = CurTime()
	if now < (st.nextDoor or 0) then return end
	st.nextDoor = now + 0.25
	local e = util.QuickTrace(ply:EyePos(), ply:GetForward() * 45, ply).Entity
	if not IsValid(e) then return end
	local c = e:GetClass()
	-- открываем только закрытую дверь: повторное «открыть» распахнутой створки толкает её в бота,
	-- и он упирается в неё боком (выход из такого упора — в ядре, отход назад-вбок)
	if c == "prop_door_rotating" then
		local s = e:GetInternalVariable("m_eDoorState")
		if s == nil or s == 0 then e:Fire("Unlock") e:Fire("OpenAwayFrom", ply, 0) end
	elseif c == "func_door_rotating" or c == "func_door" then
		local s = e:GetInternalVariable("m_toggle_state")
		if s == nil or s == 1 then e:Fire("Unlock") e:Fire("Open", ply, 0) end
	end
end

-- ---------- закупка в «Террористы против SWAT» (режим 12) ----------
-- Покупки идут через тот же обработчик сети, что и у игрока: он сам проверяет цену, команду и время закупки.
local function netBuy(receiver, ply, class)
	local recv = net.Receivers and net.Receivers[receiver]
	if not recv then return false end
	local before = ply:GetNW2Int("MuR.Mode12.Money", 0)
	local oldRead = net.ReadString
	net.ReadString = function() return class end
	local ok = pcall(recv, 0, ply)
	net.ReadString = oldRead
	return ok and ply:GetNW2Int("MuR.Mode12.Money", 0) < before
end

local LOADOUT = {
	SWAT = {
		rifles = { "tfa_bs_m4a1", "tfa_bs_hk416", "tfa_bs_aug", "tfa_bs_sg552" },
		smgs = { "tfa_bs_mp5a5", "tfa_bs_ump", "tfa_bs_mp7", "tfa_bs_vector" },
		shotguns = { "tfa_bs_m590", "tfa_bs_nova", "tfa_bs_m1014" },
		sidearms = { "tfa_bs_usp", "tfa_bs_glock", "tfa_bs_p320", "tfa_bs_m9" },
		armor = { "mur_armor_classII_armor", "mur_armor_classI_armor" },
		grenades = { "mur_flashbang", "mur_f1" },
	},
	Terrorist2 = {
		rifles = { "tfa_bs_akm", "tfa_bs_ak74", "tfa_bs_ak12", "tfa_bs_aks74u" },
		smgs = { "tfa_bs_uzi", "tfa_bs_mac11", "tfa_bs_mp7" },
		shotguns = { "tfa_bs_m500", "tfa_bs_spas", "tfa_bs_m37" },
		sidearms = { "tfa_bs_pm", "tfa_bs_colt", "tfa_bs_ruger", "tfa_bs_cobra" },
		armor = { "mur_armor_classII_armor", "mur_armor_classI_armor" },
		grenades = { "mur_f1", "mur_flashbang" },
	},
}

local function buyFirst(ply, list)
	local order = table.Copy(list)
	table.Shuffle(order)
	for _, class in ipairs(order) do
		if netBuy("mur.mode12.buy", ply, class) then return class end
	end
end

local function buyLoadout(ply)
	local set = LOADOUT[ply:GetNW2String("Class")]
	if not set then return end
	local r = math.random()
	local primary = r < 0.55 and set.rifles or (r < 0.8 and set.smgs or set.shotguns)
	local gun = buyFirst(ply, primary) or buyFirst(ply, set.smgs) or buyFirst(ply, set.shotguns)
	-- по приоритету, пока хватает денег
	for _, class in ipairs(set.armor) do if netBuy("mur.mode12.buy", ply, class) then break end end
	netBuy("mur.mode12.buy", ply, "mur_loot_bandage")
	buyFirst(ply, set.sidearms)
	netBuy("mur.mode12.buy", ply, "mur_loot_medkit")
	buyFirst(ply, set.grenades)
	if gun then
		for _ = 1, 2 do netBuy("mur.mode12.buyammo", ply, gun) end
	end
end

local function buyPhase(ply, st, now)
	if not (MuR and MuR.Gamemode == 12) then return end
	local endAt = GetGlobalFloat("MuR.Mode12.BuyTimeEnd", 0)
	if now >= endAt or st.boughtFor == endAt then return end
	if not st.buyAt or st.buyEnd ~= endAt then
		st.buyEnd = endAt
		st.buyAt = now + math.Rand(1, 6)
	end
	if now < st.buyAt then return end
	st.boughtFor = endAt
	pcall(buyLoadout, ply)
	st.invAt = 0
end

-- ---------- способности Entity (режим 22) ----------
-- Призывы при виде врага, EMP и блэкаут против группы, телепорт к ФБР, если долго никого не видно.
-- Перезарядку способностей проверяет сам геймод (MuR:EntityAbility).
local function entityPhase(ply, st, now)
	if not (MuR and MuR.Gamemode == 22 and MuR.EntityAbility and ply:GetNW2String("Class") == "Entity") then return end
	if now < (st.nextAbility or 0) then return end
	st.nextAbility = now + 1
	local seen, near = 0, 0
	local mine = teamOf(ply)
	for _, e in ipairs(st.enemies or {}) do
		if e.visible and e.team ~= mine then  -- свои твари в списке тоже есть
			seen = seen + 1
			if Vector(e.x, e.y, e.z):Distance(ply:GetPos()) < 1200 then near = near + 1 end
		end
	end
	local function use(name) pcall(MuR.EntityAbility, MuR, ply, name) end
	if seen > 0 then
		st.lastSeenAt = now
		use("summon_vermin")
		if near > 0 then use("summon_elite") end
		if near >= 2 then use("emp") end
		if near >= 3 then use("blackout") end
	elseif now - (st.lastSeenAt or now - 1) > 12 then
		st.lastSeenAt = now
		use("teleport")
	end
end

-- ---------- предметы убийцы: короткие действия шима ----------
-- Пока убийцу никто не видит и он спокоен, шим сам делает короткие действия (1–2.5 с) вместо ядра:
-- мажет ядом дверь, собирает и ставит ловушку на дверь, ломает лежащий ствол, взрывает СВУ.
local CALM = { wander = true, linger = true, lurk = true, hunt = true, leave = true, patrol = true, plant = true }
local DOORS = { prop_door_rotating = true, func_door = true, func_door_rotating = true }

local function unobserved(ply, st)
	local mine = teamOf(ply)
	for _, e in ipairs(st.enemies or {}) do
		if e.visible and e.team ~= mine then return false end
	end
	return true
end

local function nearDoor(ply, maxDist, skip)
	local eye = ply:EyePos()
	for _, e in ipairs(ents.FindInSphere(ply:GetPos(), maxDist + 40)) do
		if IsValid(e) and DOORS[e:GetClass()] and not (skip and skip(e)) then
			local p = e.NearestPoint and e:NearestPoint(eye) or e:WorldSpaceCenter()
			if p:Distance(eye) < maxDist then return e, p end
		end
	end
end

-- Сборка ловушки: тот же обработчик сети, что у игрока (чертёж «дверь + контакт + капкан»).
local function trapBuild(ply)
	local recv = net.Receivers and net.Receivers["mur.trapbuild"]
	if not recv then return false end
	local parts = { "door", "contact", "snare" }
	local i = 0
	local oldStr, oldUInt = net.ReadString, net.ReadUInt
	net.ReadString = function() i = i + 1 return parts[i] or "" end
	net.ReadUInt = function() return 0 end
	local ok = pcall(recv, 0, ply)
	net.ReadString, net.ReadUInt = oldStr, oldUInt
	return ok
end

local function startMacro(st, now, class, aim, btn, pressFrom, pressTo, length)
	st.macro = { w = class, aim = aim, btn = btn, from = now + pressFrom, to = now + pressTo, untilT = now + length }
end

-- Баррикада: спрятавшийся мирный с молотком или скотчем заколачивает ближайшую дверь (до двух раз).
-- Подходит к петлям (там у prop_door_rotating начало координат) и бьёт так, чтобы задеть и створку, и косяк.
local function barricadePhase(ply, st, now)
	if st.macro or isKiller(ply) or now < (st.nextBarricade or 0) then return end
	st.nextBarricade = now + 1
	local s = ply.BSBStatus or ""
	if s ~= "hide" and s ~= "panic" then return end
	local inv = st.inv
	local tool = inv and (IsValid(inv.hammer) and inv.hammer or (IsValid(inv.tape) and inv.tape or nil))
	if not tool then return end
	st.nailed = st.nailed or {}
	local eye = ply:EyePos()
	local best, bd
	for _, e in ipairs(ents.FindInSphere(ply:GetPos(), 260)) do
		if IsValid(e) and DOORS[e:GetClass()] and (st.nailed[e] or 0) < 2 then
			local d = e:GetPos():Distance(eye)
			if not bd or d < bd then best, bd = e, d end
		end
	end
	if not best then return end
	st.nailed[best] = (st.nailed[best] or 0) + 1
	local aim = best:GetPos() + Vector(0, 0, 45) + (best:WorldSpaceCenter() - best:GetPos()):GetNormalized() * 6
	st.macro = { w = tool:GetClass(), aim = aim, btn = IN_ATTACK, walk = true, pulse = true,
		from = now, to = now + 6, untilT = now + 6.5 }
end

local function itemPhase(ply, st, now)
	if st.macro or not isKiller(ply) then return end
	local inv = st.inv
	if not inv then return end
	-- СВУ: взрыв, когда у бомбы двое (на грани рассудка — один), а сам убийца далеко
	local ied = inv.ied
	if IsValid(ied) and ied.DetonateDrawed and IsValid(ied.ExplodeEntity) then
		local bomb = ied.ExplodeEntity:GetPos()
		local near = 0
		for _, p in ipairs(player.GetAll()) do
			if p ~= ply and p:Alive() and not isKiller(p) and p:GetPos():Distance(bomb) < 220 then near = near + 1 end
		end
		local need = ply:GetNW2Float("Stability", 100) < 40 and 1 or 2
		if near >= need and ply:GetPos():Distance(bomb) > 350 then
			local ang = ply:EyeAngles()
			startMacro(st, now, "mur_ied", ply:EyePos() + ang:Forward() * 100, IN_ATTACK2, 0.35, 0.6, 1.0)
			return
		end
	end
	if now < (st.nextItem or 0) then return end
	st.nextItem = now + 0.5
	if not CALM[ply.BSBStatus or ""] or not unobserved(ply, st) then
		st.forceWeapon = nil
		return
	end
	-- ловушка: сборка (держим набор в руках), затем установка на дверь
	if IsValid(inv.trapkit) then
		if ply.MuR_TrapBlueprint then
			st.forceWeapon = nil
			local door, p = nearDoor(ply, 70)
			if door then startMacro(st, now, "mur_trap_kit", p, IN_ATTACK, 0.4, 2.4, 2.6) return end
		elseif ply.MuR_TrapAssembly then
			st.forceWeapon = "mur_trap_kit"   -- сборка идёт, пока набор в руках
		elseif now >= (st.trapRetry or 0) then
			st.forceWeapon = "mur_trap_kit"
			local active = ply:GetActiveWeapon()
			if IsValid(active) and active:GetClass() == "mur_trap_kit" and trapBuild(ply) then st.trapRetry = now + 40 end
		else
			st.forceWeapon = nil   -- сборку сорвали — повторим позже
		end
	end
	-- яд на ручку двери
	if IsValid(inv.canister) then
		local door, p = nearDoor(ply, 60, function(e) return e.MuR_LacedWith ~= nil end)
		if door then startMacro(st, now, "mur_poisoncanister", p, IN_ATTACK, 0.4, 0.7, 1.4) return end
	end
	-- сломать лежащий ствол, пока его не подобрали мирные
	if IsValid(inv.breaker) then
		local eye = ply:EyePos()
		for _, e in ipairs(ents.FindInSphere(ply:GetPos(), 90)) do
			if IsValid(e) and e:IsWeapon() and not IsValid(e:GetOwner()) and not IsValid(e.BrokenAtt)
				and string.find(e:GetClass(), "tfa", 1, true) and e:WorldSpaceCenter():Distance(eye) < 70 then
				startMacro(st, now, "mur_break_tool", e:WorldSpaceCenter(), IN_ATTACK, 0.4, 0.7, 1.2)
				return
			end
		end
	end
end

-- Исполнение короткого действия: смотрим на цель, достаём предмет, жмём кнопку в своё окно.
local function applyMacro(ply, cmd, st, now)
	local m = st.macro
	if now > m.untilT or not ply:HasWeapon(m.w) then st.macro = nil return false end
	cmd:ClearMovement()
	cmd:ClearButtons()
	local ang = (m.aim - ply:EyePos()):Angle()
	ang.r = 0
	cmd:SetViewAngles(ang)
	ply:SetEyeAngles(ang)
	-- подойти, если цель дальше вытянутой руки
	local far = m.walk and m.aim:Distance(ply:EyePos()) > 62
	if far then cmd:SetForwardMove(ply.GetWalkSpeed and ply:GetWalkSpeed() or 100) end
	local active = ply:GetActiveWeapon()
	if not IsValid(active) or active:GetClass() ~= m.w then
		if now >= (st.nextSelect or 0) then ply:SelectWeapon(m.w) st.nextSelect = now + 0.33 end
	elseif not far and now >= m.from and now <= m.to and (not m.pulse or now % 1.2 < 0.15) then
		cmd:SetButtons(m.btn)
	end
	return true
end

-- ---------- рация командира ЧВК (режим 24) ----------
-- Раз в 3 с: павший есть и очков ≥ 500 — подъём (первым — живой игрок); ранены двое и больше — аптечки (250);
-- патроны кончаются при выключенных бесконечных патронах — патроны (500). На подъём всегда остаётся запас 250.
local REVIVE_PRICE, RESERVE = 500, 250

local function shopId(name)
	for id, item in pairs(MuR.Shop and MuR.Shop.Soldier or {}) do
		if item.name == name then return id end
	end
end

local function commanderPhase(ply, st, now)
	if not (MuR and MuR.Gamemode == 24 and MuR.Mode24 and MuR.Mode24.Commander == ply) then return end
	if now < (st.nextRadio or 0) then return end
	st.nextRadio = now + 3
	local points = ply:GetNWInt("MuR_Mode24Points", 0)
	local dead, hurt, dry = nil, 0, false
	for _, p in ipairs(player.GetAll()) do
		if p ~= ply then
			if not p:Alive() then
				if not dead or (dead:IsBot() and not p:IsBot()) then dead = p end
			elseif p:Team() == ply:Team() then
				if p:Health() < 60 then hurt = hurt + 1 end
				local w = p:GetActiveWeapon()
				if IsValid(w) and w:GetMaxClip1() > 0 and p:GetAmmoCount(w:GetPrimaryAmmoType()) <= 0 then dry = true end
			end
		end
	end
	if dead and points >= REVIVE_PRICE and MuR.Mode24Revive then
		if pcall(MuR.Mode24Revive, MuR, dead, ply) then ply:SetNWInt("MuR_Mode24Points", points - REVIVE_PRICE) end
		return
	end
	local function buy(name, price)
		local id = shopId(name)
		if id and points - price >= RESERVE and ply.BuyItem then pcall(ply.BuyItem, ply, "Soldier", id) return true end
	end
	if hurt >= 2 and buy("Squad Medkits", 250) then return end
	if dry and not cvInfAmmo:GetBool() then buy("Squad Ammo", 500) end
end

-- ---------- бот ----------
function BSBots.Add(name)
	if not bsbots.Ready() then print("[bsbots] навмеш не готов") return nil end
	local bot = player.CreateNextBot(name or "bsbot")
	if not IsValid(bot) then return nil end
	bot.BSB = true
	BSBots.Bots[bot:UserID()] = bot
	return bot
end

hook.Add("StartCommand", "bsbots_drive", function(ply, cmd)
	if not ply.BSB or not ply:IsBot() then return end
	local st = ply.BSBState
	if not st then st = {} ply.BSBState = st end

	ply:SetNWFloat("Hunger", 100)
	-- вину ботам обнуляем: иначе ошибки бота копятся между раундами и кончаются баном
	if ply:GetNW2Float("Guilt", 0) > 0 then ply:SetNW2Float("Guilt", 0) end
	topUpAmmo(ply, st, CurTime())
	if not ply:Alive() then return end

	if not BSBots.CurMode then return end
	doorReflex(ply, st)
	buyPhase(ply, st, CurTime())
	shopPhase(ply, st, CurTime())
	entityPhase(ply, st, CurTime())
	commanderPhase(ply, st, CurTime())
	itemPhase(ply, st, CurTime())
	barricadePhase(ply, st, CurTime())
	if st.macro and applyMacro(ply, cmd, st, CurTime()) then return end
	local obs = buildObs(ply, st)
	if not obs.roundActive then ply.BSBKnown = nil st.scanTarget = nil end
	local act = bsbots.Tick(ply:UserID(), obs)
	ply.BSBStatus = act.state
	applyAction(ply, cmd, act, st)
end)

-- Новая жизнь — новое знание: кого бот видел нападающим в прошлом раунде, больше не помнит.
hook.Add("PlayerSpawn", "bsbots_forget", function(ply)
	if ply.BSB then
		ply.BSBKnown = nil
		ply.BSBPoisoned = nil
		ply.BSBAttacker, ply.BSBAttackedAt = nil, nil
		if ply.BSBState then
			ply.BSBState.scanTarget, ply.BSBState.macro, ply.BSBState.forceWeapon, ply.BSBState.trapRetry = nil, nil, nil, nil
			ply.BSBState.nailed = nil
		end
	end
end)

hook.Add("PlayerDisconnected", "bsbots_release", function(ply)
	if ply.BSB then
		bsbots.Release(ply:UserID())
		BSBots.Bots[ply:UserID()] = nil
	end
end)

-- ---------- команды ----------
local function allowed(ply) return not IsValid(ply) or ply:IsSuperAdmin() end

concommand.Add("bsbots_add", function(ply, _, args)
	if not allowed(ply) then return end
	for _ = 1, math.Clamp(tonumber(args[1]) or 1, 1, 16) do BSBots.Add() end
end)

concommand.Add("bsbots_status", function(ply)
	if not allowed(ply) then return end
	print("[bsbots] режим: " .. tostring(BSBots.CurMode))
	for id, bot in pairs(BSBots.Bots) do
		if IsValid(bot) then
			print(("[bsbots] #%d %s hp=%d pos=%s state=%s"):format(id, bot:Nick(), bot:Health(), tostring(bot:GetPos()), tostring(bot.BSBStatus)))
		end
	end
end)

concommand.Add("bsbots_kick", function(ply)
	if not allowed(ply) then return end
	for id, bot in pairs(BSBots.Bots) do
		if IsValid(bot) then bot:Kick("bsbots_kick") end
		bsbots.Release(id)
		BSBots.Bots[id] = nil
	end
end)
