-- Оружие NPC: описания вместо SWEP'ов на weapon_vj_base.
--
-- Nextbot не носит SWEP: Entity:Give есть только у игрока и движкового NPC.
-- Поэтому оружие здесь — данные, а в руке у NPC висит bs_npc_weapon: обычная
-- anim-сущность с моделью, приклеенная к attachment кисти.

MuR = MuR or {}
MuR.NPC = MuR.NPC or {}

--------------------------------------------------------------------------------
-- Наборы анимаций
--------------------------------------------------------------------------------
--
-- Наборов ДВА, потому что модели разные, и это проверено на самих моделях:
--
--   citizen — models/murdered/npc/police/*: полный набор HL2-гражданина.
--             Есть пистолетные, винтовочные и дробовиковые позы, включая
--             отдельные перезарядки ACT_RELOAD_PISTOL/SMG1/SHOTGUN.
--
--   combine — models/murdered/npc/swat/*: набор комбайна. Пистолетных поз нет
--             ВООБЩЕ, как нет и обычных ACT_WALK/ACT_RUN — только их
--             винтовочные и дробовиковые варианты. Перезарядка одна на всё:
--             ACT_RELOAD.
--
-- Ни один из них не HL2MP: все ACT_HL2MP_* у обеих моделей отсутствуют.

MuR.NPC.AnimSets = {
	citizen = {
		pistol = {
			idle = ACT_IDLE_ANGRY_PISTOL,
			walk = ACT_WALK_PISTOL,
			run = ACT_RUN_PISTOL,
			fire = ACT_RANGE_ATTACK_PISTOL,
			reload = ACT_RELOAD_PISTOL,
			crouchFire = ACT_RANGE_ATTACK_PISTOL_LOW,
		},
		smg = {
			idle = ACT_IDLE_ANGRY_SMG1,
			walk = ACT_WALK_RIFLE,
			run = ACT_RUN_RIFLE,
			fire = ACT_RANGE_ATTACK_SMG1,
			reload = ACT_RELOAD_SMG1,
			crouchFire = ACT_RANGE_ATTACK_SMG1_LOW,
		},
		shotgun = {
			idle = ACT_IDLE_SHOTGUN_AGITATED,
			walk = ACT_WALK_RIFLE,
			run = ACT_RUN_RIFLE,
			fire = ACT_RANGE_ATTACK_SHOTGUN,
			reload = ACT_RELOAD_SHOTGUN,
		},
		melee = {
			idle = ACT_IDLE,
			walk = ACT_WALK,
			run = ACT_RUN,
		},
	},

	combine = {
		-- Пистолетных поз у модели нет, поэтому пистолет держится как винтовка.
		pistol = {
			idle = ACT_IDLE_ANGRY_SMG1,
			walk = ACT_WALK_RIFLE,
			run = ACT_RUN_RIFLE,
			fire = ACT_RANGE_ATTACK_SMG1,
			reload = ACT_RELOAD,
		},
		smg = {
			idle = ACT_IDLE_ANGRY_SMG1,
			walk = ACT_WALK_RIFLE,
			run = ACT_RUN_RIFLE,
			fire = ACT_RANGE_ATTACK_SMG1,
			reload = ACT_RELOAD,
			crouchFire = ACT_RANGE_ATTACK_SMG1_LOW,
		},
		shotgun = {
			idle = ACT_IDLE_ANGRY_SHOTGUN,
			walk = ACT_WALK_AIM_SHOTGUN,
			run = ACT_RUN_AIM_SHOTGUN,
			fire = ACT_RANGE_ATTACK_SHOTGUN,
			reload = ACT_RELOAD,
		},
		melee = {
			idle = ACT_IDLE_ANGRY,
			walk = ACT_WALK_RIFLE,
			run = ACT_RUN_RIFLE,
		},
	},

	--
	-- player — models/murdered/npc/amb/*: модели ЧВК собраны на скелете ИГРОКА.
	--
	-- Замерено на всех шести: из обычных NPC-активити у них нет НИ ОДНОГО, даже
	-- ACT_IDLE, ACT_WALK и ACT_RUN. Всё лежит в ACT_HL2MP_*.
	--
	-- Стрельба и перезарядка помечены gesture: у игроцкого скелета это
	-- ACT_HL2MP_GESTURE_*, то есть жесты для верха тела. Сыгранные как основная
	-- последовательность они обнуляют позу ног.
	--
	player = {
		gesture = true,
		pistol = {
			idle = ACT_HL2MP_IDLE_PISTOL,
			walk = ACT_HL2MP_WALK_PISTOL,
			run = ACT_HL2MP_RUN_PISTOL,
			fire = ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL,
			reload = ACT_HL2MP_GESTURE_RELOAD_PISTOL,
			crouchFire = ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL,
		},
		smg = {
			idle = ACT_HL2MP_IDLE_SMG1,
			walk = ACT_HL2MP_WALK_SMG1,
			run = ACT_HL2MP_RUN_SMG1,
			fire = ACT_HL2MP_GESTURE_RANGE_ATTACK_SMG1,
			reload = ACT_HL2MP_GESTURE_RELOAD_SMG1,
			crouchFire = ACT_HL2MP_GESTURE_RANGE_ATTACK_SMG1,
		},
		shotgun = {
			idle = ACT_HL2MP_IDLE_SHOTGUN,
			walk = ACT_HL2MP_WALK_SHOTGUN,
			run = ACT_HL2MP_RUN_SHOTGUN,
			fire = ACT_HL2MP_GESTURE_RANGE_ATTACK_SHOTGUN,
			reload = ACT_HL2MP_GESTURE_RELOAD_SHOTGUN,
		},
		melee = {
			idle = ACT_HL2MP_IDLE_MELEE,
			walk = ACT_HL2MP_WALK_MELEE,
			run = ACT_HL2MP_RUN_MELEE,
		},
	},
}

-- Совместимость: раньше набор был один.
MuR.NPC.WeaponAnims = MuR.NPC.AnimSets.citizen

function MuR.NPC.GetAnimSet(setName, weaponSet)
	local set = MuR.NPC.AnimSets[setName or "citizen"] or MuR.NPC.AnimSets.citizen

	return set[weaponSet or "pistol"] or set.smg or set.pistol
end

-- Играет ли этот набор стрельбу и перезарядку жестом поверх ходьбы.
function MuR.NPC.AnimSetUsesGestures(setName)
	local set = MuR.NPC.AnimSets[setName or "citizen"]

	return set ~= nil and set.gesture == true
end

--------------------------------------------------------------------------------
-- Реестр
--------------------------------------------------------------------------------

MuR.NPC.Weapons = MuR.NPC.Weapons or {}

function MuR.NPC.AddWeapon(class, data)
	data.class = class
	MuR.NPC.Weapons[class] = data
end

function MuR.NPC.GetWeapon(class)
	return MuR.NPC.Weapons[class]
end

--------------------------------------------------------------------------------
-- Импорт из SWEP (TFA и любых других)
--------------------------------------------------------------------------------
--
-- Дать nextbot настоящий SWEP нельзя: Entity:Give есть только у игрока и
-- движкового NPC, а TFA вдобавок рассчитывает на владельца-игрока (вьюмодель,
-- KeyDown, GetEyeTrace). Зато сама таблица SWEP — готовое описание оружия, и
-- её достаточно: модель, звук, урон, клип, темп и разброс лежат в Primary.
--
-- Так любое оружие TFA становится доступно NPC без правки самого оружия.

local holdToAnim = {
	pistol = "pistol", revolver = "pistol", duel = "pistol", camera = "pistol",
	smg = "smg", ar2 = "smg", rpg = "smg", crossbow = "smg", physgun = "smg", normal = "smg",
	shotgun = "shotgun",
	melee = "melee", melee2 = "melee", knife = "melee", fist = "melee",
	grenade = "melee", slam = "melee", passive = "melee", magic = "melee",
}

local meleeHold = {melee = true, melee2 = true, knife = true, fist = true}

--
-- Положение world-модели в руке. Своих смещений не изобретаем: у TFA они уже
-- подобраны под каждый ствол и лежат в SWEP.WorldModelOffset (старое имя того
-- же поля — SWEP.Offset, псевдоним объявлен в самой TFA, lua/tfa/modules/tfa_data.lua).
--
-- Формат: Pos и Ang по осям кости кисти (Forward/Right/Up) плюс Scale. TFA
-- применяет их к ValveBiped.Bip01_R_Hand именно в таком порядке — сначала
-- сдвиг по НЕповёрнутому базису кости, потом три поворота по очереди
-- (client/mods.lua, WorldModelOffsetUpdate). Порядок важен: перепутав его,
-- получаем ствол, воткнутый в предплечье.
--
-- Считаем один раз при импорте и храним готовыми local-координатами кости.
--
local function tfaOffsetToBoneLocal(off)
	local p, a = off.Pos, off.Ang
	if not istable(p) or not istable(a) then return nil end

	-- Локальное пространство кости: базис единичного угла.
	local ang = Angle(0, 0, 0)
	local pos = ang:Forward() * (tonumber(p.Forward) or 0)
		+ ang:Right() * (tonumber(p.Right) or 0)
		+ ang:Up() * (tonumber(p.Up) or 0)

	ang:RotateAroundAxis(ang:Up(), tonumber(a.Up) or 0)
	ang:RotateAroundAxis(ang:Right(), tonumber(a.Right) or 0)
	ang:RotateAroundAxis(ang:Forward(), tonumber(a.Forward) or 0)

	return pos, ang, tonumber(off.Scale)
end

function MuR.NPC.ImportSWEP(class, overrides)
	local swep = weapons.Get(class)
	if not swep then return nil end

	local p = swep.Primary or {}
	local hold = swep.HoldType or "pistol"

	-- TFA задаёт темп в RPM, а Delay считает сама.
	local rpm = tonumber(p.RPM) or 0
	local delay = rpm > 0 and (60 / rpm) or tonumber(p.Delay) or 0.3

	local damage = tonumber(p.Damage) or 0
	-- Отрицательный урон у TFA означает снаряд (RPG, гранатомёт): такие
	-- стволы NPC не выдаём, стрелять ими нам нечем.
	if damage <= 0 and not meleeHold[hold] then return nil end

	local clip = tonumber(p.ClipSize) or 0
	local spread = tonumber(p.Spread) or 0
	local shots = tonumber(p.NumShots) or 1

	local animSet = holdToAnim[hold] or "smg"

	-- Дробовик узнаём по числу дробин, а не по держаку: TFA ставит всем
	-- длинноствольным HoldType = "ar2", и дробовики иначе получали бы
	-- винтовочные позы (проверено на m590, m1014, nova).
	if shots >= 3 then animSet = "shotgun" end

	local data = {
		name = swep.PrintName or class,
		model = swep.WorldModel,
		holdType = hold,
		animSet = animSet,
		damage = damage > 0 and damage or 25,
		delay = delay,
		clip = clip > 0 and clip or 30,
		shots = shots,
		-- У TFA разброс уже в единицах FireBullets, пересчитывать не надо.
		spreadRaw = spread > 0 and spread or 0.02,
		timeUntilFire = 0.15,
		fireSound = p.Sound,
		muzzleAttachment = tonumber(swep.MuzzleAttachment) or 1,
		reloadSound = swep.ReloadSound,
		reloadTime = tonumber(swep.Reload_TimeUntilAmmoIsSet) or 2,
		-- Очередь только у скорострельного автоматического: дробовик, снайперка
		-- и пистолет должны бить одиночными. Иначе пистолет на 400 RPM выдавал
		-- бы очередь в шесть патронов.
		burst = (animSet == "smg" and damage < 45 and delay <= 0.12) and {3, 6} or false,
		melee = meleeHold[hold] or false,
		importedFrom = class,
	}

	if data.melee then
		data.range = 70
		data.meleeAnims = {"swing", "thrust", "pushplayer"}
	end

	if tonumber(p.Range) and tonumber(p.Range) > 0 then
		data.range = tonumber(p.Range)
	end

	-- Смещения в руке — из самого SWEP'а, вместе с масштабом модели.
	local off = swep.WorldModelOffset or swep.Offset
	if istable(off) then
		local pos, ang, scale = tfaOffsetToBoneLocal(off)

		if pos then
			data.bonePos = pos
			data.boneAng = ang
			data.modelScale = scale
		end
	end

	for k, v in pairs(overrides or {}) do data[k] = v end

	return data
end

-- Зарегистрировать оружие TFA как оружие NPC, при желании подправив параметры.
function MuR.NPC.AddSWEP(class, overrides)
	local data = MuR.NPC.ImportSWEP(class, overrides)
	if not data then return false end

	MuR.NPC.AddWeapon(class, data)

	return true
end

--
-- Разворачивает описание в конкретный экземпляр: выбирает вариант и держак.
-- Возвращает плоскую таблицу, из которой bs_npc_weapon уже ничего не выбирает.
--
function MuR.NPC.BuildWeapon(class)
	local base = MuR.NPC.Weapons[class]

	-- Незнакомый класс пробуем прочитать как SWEP: так в списках оружия NPC
	-- можно писать имена стволов TFA напрямую.
	if not base then
		base = MuR.NPC.ImportSWEP(class)
		if not base then return nil end
		MuR.NPC.Weapons[class] = base
	end

	local out = table.Copy(base)
	out.variants = nil

	if base.variants then
		local v = base.variants[math.random(#base.variants)]
		for k, val in pairs(v) do out[k] = val end
	end

	out.holdType = MuR.Pick(out.holdType)
	out.anims = MuR.NPC.WeaponAnims[out.animSet or "pistol"]

	return out
end

--------------------------------------------------------------------------------
-- Полиция
--------------------------------------------------------------------------------

MuR.NPC.AddWeapon("bswep_glock", {
	name = "Glock 17",
	model = "models/sidearms/v_glock.mdl",
	animSet = "pistol",
	damage = 26,
	delay = 0.3,
	clip = 17,
	spread = 0.8,
	timeUntilFire = 0.15,
	fireSound = ")weapons/glock/glock17_close.wav",
	-- Был путь vj_base/weapons/glock17/reload.wav: звук приезжал с VJ Base и
	-- вместе с ней исчез, так что глок перезаряжался беззвучно. Соседние стволы
	-- тут и так на базовых звуках HL2.
	reloadSound = "weapons/pistol/pistol_reload1.wav",
	reloadTime = 1.5,
})

MuR.NPC.AddWeapon("bswep_m4a1", {
	name = "M4A1",
	model = "models/rifles/w_m4a1.mdl",
	animSet = "smg",
	damage = 16,
	delay = 0.09,
	clip = 30,
	spread = 1.5,
	timeUntilFire = 0.15,
	burst = {3, 6},
	fireSound = ")inss_wpns/tfa_inss_m4a1/fire2.wav",
	reloadSound = "weapons/smg1/smg1_reload.wav",
	reloadTime = 2,
})

MuR.NPC.AddWeapon("bswep_r870", {
	name = "Remington 870",
	model = "models/shotguns/w_m590.mdl",
	animSet = "shotgun",
	damage = 18,
	shots = 6,
	delay = 0.9,
	clip = 8,
	spread = 2.5,
	timeUntilFire = 0.2,
	-- Дробовик бьёт только вблизи: у VJ это был NPC_FiringDistanceScale.
	rangeScale = 0.5,
	fireSound = ")tfa_ins2_wpns/tfa_ins2_mossberg590/fire.wav",
	extraSound = "murdered/weapons/toz_shotgun/pump.wav",
	extraSoundDelay = 0.5,
	reloadSound = {"weapons/shotgun/shotgun_reload1.wav", "weapons/shotgun/shotgun_reload2.wav", "weapons/shotgun/shotgun_reload3.wav"},
	reloadTime = 2,
})

--------------------------------------------------------------------------------
-- Подозреваемые
--------------------------------------------------------------------------------
--
-- Стволы подозреваемых собираются из настоящих TFA того же пака, что у
-- полиции (tfa_bs_*): из SWEP берутся модель, звук и положение в руке
-- (bonePos/boneAng из WorldModelOffset). Без этих смещений оружие крепится
-- в начало координат NPC и висит невидимым внутри тела.
--
-- Боевые цифры — урон, темп, разброс — оставлены от старых VJ-конфигов:
-- это баланс режима, и TFA-значения для игрока здесь ни к чему.
--
-- Если SWEP вдруг недоступен при загрузке, вариант откатывается на ручное
-- описание: оружие останется рабочим, просто без смещений в руке.
--

local function SusVariant(swepClass, fallback, overrides)
	local data = MuR.NPC.ImportSWEP(swepClass, overrides)

	return data or fallback
end

MuR.NPC.AddWeapon("bswep_sus_primary", {
	name = "Suspect Primary",
	model = "models/weapons/w_rif_ak47.mdl",
	animSet = "smg",
	damage = 21,
	delay = 0.11,
	clip = 30,
	timeUntilFire = 0.2,
	variants = {
		SusVariant("tfa_bs_akm", {
			model = "models/weapons/w_rif_ak47.mdl",
			damage = 21, delay = 0.11, clip = 30, spread = 3, animSet = "smg", burst = {3, 7},
			fireSound = ")weapons/tfa_ins2/acr/fire.wav",
		}, {
			damage = 21, delay = 0.11,
		}),
		SusVariant("tfa_bs_mosin", {
			model = "models/weapons/w_snip_scout.mdl",
			damage = 65, delay = 0.6, clip = 30, spread = 1, animSet = "smg", burst = false,
			fireSound = ")weapons/m24sws/m24_shoot_default.wav",
		}, {
			damage = 65, delay = 0.6,
		}),
		SusVariant("tfa_bs_m1014", {
			model = "models/weapons/w_shot_m3super90.mdl",
			damage = 14, delay = 0.6, clip = 30, spread = 6, shots = 6, animSet = "shotgun", burst = false,
			rangeScale = 0.6,
			fireSound = ")weapons/tfa_ins2/m1014/m1014_fire.wav",
		}, {
			damage = 14, delay = 0.6, shots = 6, rangeScale = 0.6,
		}),
	},
})

MuR.NPC.AddWeapon("bswep_sus_secondary", {
	name = "Suspect Sidearm",
	model = "models/weapons/w_pist_glock18.mdl",
	animSet = "pistol",
	damage = 20,
	delay = 0.3,
	clip = 17,
	timeUntilFire = 0.2,
	variants = {
		SusVariant("tfa_bs_glock", {
			model = "models/weapons/w_pist_glock18.mdl",
			damage = 20, delay = 0.27, clip = 17, animSet = "pistol",
			fireSound = ")weapons/glock/glock17_close.wav",
		}, {
			damage = 20, delay = 0.27,
		}),
		SusVariant("tfa_bs_walther", {
			model = "models/weapons/w_pist_fiveseven.mdl",
			damage = 22, delay = 0.28, clip = 15, animSet = "pistol",
			fireSound = ")weapons/p99/fire.wav",
		}, {
			damage = 22, delay = 0.28,
		}),
		SusVariant("tfa_bs_deagle", {
			model = "models/weapons/w_pist_deagle.mdl",
			damage = 48, delay = 0.6, clip = 7, animSet = "pistol",
			fireSound = ")weapons/tfa_ins2/thanez_cobra/revolver_fp.wav",
		}, {
			damage = 48, delay = 0.6,
		}),
		SusVariant("tfa_bs_pm", {
			model = "models/weapons/w_pist_p228.mdl",
			damage = 24, delay = 0.35, clip = 8, animSet = "pistol",
			fireSound = ")weapons/tfa_ins2/pm/makarov_fp.wav",
		}, {
			damage = 24, delay = 0.35,
		}),
		-- TFA-пак ставит MAC-11 держаки револьвера; это ошибка пака,
		-- возвращаем ему пистолет-пулемётные позы и очередь.
		SusVariant("tfa_bs_mac11", {
			model = "models/weapons/w_smg_mac10.mdl",
			damage = 14, delay = 0.09, clip = 30, spread = 4, animSet = "smg", burst = {4, 8},
			fireSound = ")weapons/tfa_ins2/mp7/fp.wav",
		}, {
			damage = 14, delay = 0.09, animSet = "smg", burst = {4, 8}, spreadRaw = 0.04,
		}),
	},
})

-- Нож — Kitchen Knife из того же TFA-пака: holdtype knife, его модель
-- и его смещения в руке.
MuR.NPC.AddWeapon("bswep_sus_melee", SusVariant("tfa_bs_knife", {
	name = "Suspect Knife",
	model = "models/weapons/w_knife_t.mdl",
	animSet = "melee",
	holdType = "knife",
	melee = true,
	damage = 50,
	delay = 0.8,
	timeUntilFire = 0.4,
	range = 70,
	meleeAnims = {"swing", "thrust", "pushplayer"},
	hitSound = {")murdered/weapons/melee/knife_bayonet_hit1.wav", ")murdered/weapons/melee/knife_bayonet_hit2.wav"},
	missSound = {")murdered/weapons/melee/knife_bayonet_swing1.wav", ")murdered/weapons/melee/knife_bayonet_swing2.wav"},
}, {
	name = "Suspect Knife",
	damage = 50,
	delay = 0.8,
	timeUntilFire = 0.4,
	hitSound = {")murdered/weapons/melee/knife_bayonet_hit1.wav", ")murdered/weapons/melee/knife_bayonet_hit2.wav"},
	missSound = {")murdered/weapons/melee/knife_bayonet_swing1.wav", ")murdered/weapons/melee/knife_bayonet_swing2.wav"},
}))
