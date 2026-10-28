AddCSLuaFile()

ENT.Base = "bs_npc_human"
ENT.Type = "nextbot"
ENT.PrintName = "Police Officer"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true

if CLIENT then return end

ENT.Model = {
	"models/murdered/npc/police/male_01.mdl",
	"models/murdered/npc/police/male_03.mdl",
	"models/murdered/npc/police/male_04.mdl",
	"models/murdered/npc/police/male_05.mdl",
	"models/murdered/npc/police/male_06.mdl",
	"models/murdered/npc/police/male_07.mdl",
	"models/murdered/npc/police/male_08.mdl",
	"models/murdered/npc/police/male_09.mdl",
}
ENT.StartHealth = 50
ENT.Faction = "police"

-- Модель полицейского — гражданский набор HL2: пистолетные, винтовочные и
-- дробовиковые позы на месте.
ENT.AnimSet = "citizen"

ENT.DefaultWeapons = {"tfa_bs_glock", "tfa_bs_m9", "tfa_bs_p320", "tfa_bs_walther", "tfa_bs_m590", "tfa_bs_badger"}

ENT.AnimTbl_MeleeAttack = {"pushplayer", "swing", "thrust"}

ENT.DoorKickAnim = "adoorkick"
ENT.DoorKickSetBack = true
ENT.HaveTaser = true
-- Дальше этого разряд не достаёт. Читают обе стороны: и решение достать тазер,
-- и сам выстрел после анимации доставания.
ENT.TaserRange = 400

ENT.SoundTbl_Death = "BloodshedNPC_HumanDeath"
ENT.SoundTbl_FootStep = "BloodshedNPC_HumanFootstep"
ENT.SoundTbl_AllyDeath = {}
ENT.SoundTbl_PoliceSurrender = {}
ENT.SoundTbl_PoliceNoSurrender = {}

--------------------------------------------------------------------------------
-- Голос
--------------------------------------------------------------------------------

local function fillVoice(prefix, names, tab)
	for _, v in ipairs(file.Find("sound/" .. prefix .. "/" .. names .. "*", "GAME") or {}) do
		tab[#tab + 1] = prefix .. "/" .. v
	end
end

function ENT:SetupVoice()
	-- Один голос на всю жизнь NPC: иначе один и тот же офицер говорит разными.
	local folder = "murdered/npc/voice" .. math.random(1, 10)

	self.SoundTbl_PoliceSurrender = {}
	self.SoundTbl_PoliceNoSurrender = {}
	self.SoundTbl_AllyDeath = {}

	fillVoice(folder, "alert", self.SoundTbl_PoliceSurrender)
	fillVoice(folder, "combat", self.SoundTbl_PoliceNoSurrender)
	fillVoice(folder, "mandown", self.SoundTbl_AllyDeath)
end

-- Пока цель ещё может сдаться — требуем сдачи, после отказа — боевые команды.
function ENT:VoiceLogic()
	local en = self:GetEnemy()
	local refused = IsValid(en) and en:IsPlayer() and en:GetNW2Float("ArrestState") == 2

	local tab = refused and self.SoundTbl_PoliceNoSurrender or self.SoundTbl_PoliceSurrender

	self.SoundTbl_Alert = tab
	self.SoundTbl_CombatIdle = tab
end

--------------------------------------------------------------------------------
-- Инициализация
--------------------------------------------------------------------------------

function ENT:CustomOnInitialize()
	self.IsPolice = true
	self:SetupVoice()
end

function ENT:CustomOnThink()
	self:VoiceLogic()
	self:TaserLogic()
	self:DoorLogicBust()

	-- Игрока с notarget не преследуем: им пользуется отладка и режимы.
	local en = self:GetEnemy()
	if IsValid(en) and en:IsPlayer() and en:IsFlagSet(FL_NOTARGET) then
		self:ResetEnemy()
	end
end

--------------------------------------------------------------------------------
-- Кого полиция считает целью
--------------------------------------------------------------------------------

--
-- Игроков полиция берёт НЕ по фракции, а по уровню розыска:
--   ArrestState 0 — чист, не трогаем;
--   1 — в розыске, брать живым;
--   2 — в розыске, разрешено на поражение (см. WantsToArrest).
--
-- Без этой проверки офицеры игнорировали игроков вовсе: во враждебных
-- фракциях полиции игрока нет и быть не должно, иначе они стреляли бы в своих.
--
function ENT:IsValidEnemy(ent)
	if not IsValid(ent) or ent == self then return false end

	if ent:IsPlayer() then
		-- Полиция берёт игроков по своему правилу, минуя фракции, поэтому
		-- ai_ignoreplayers ей приходится проверять отдельно от базы.
		if MuR.NPC.IgnorePlayers() then return false end
		if not ent:Alive() then return false end
		if ent:IsFlagSet(FL_NOTARGET) then return false end
		if ent:IsRolePolice() then return false end

		return (ent:GetNW2Float("ArrestState") or 0) >= 1
	end

	if MuR.IsAI(ent) then
		if ent:Health() <= 0 then return false end

		return MuR.NPC.IsHostile(self, ent)
	end

	return false
end

--------------------------------------------------------------------------------
-- Арест
--------------------------------------------------------------------------------

-- С какого расстояния защёлкиваются наручники.
ENT.ArrestDistance = 64
-- На каком держаться, пока тазер заряжен и цель ещё на ногах.
ENT.ArrestTaserDistance = 200
-- Пауза после сорвавшейся попытки, чтобы не долбиться в неё каждый тик.
ENT.ArrestRetryDelay = 0.4

-- Уже связан — брать нечего.
local function IsRestrained(ply)
	return ply:GetNW2Bool("MuR.Cuffed") or ply:GetNW2Bool("MuR.Zipped")
end

-- Рэгдолл сбитого с ног. Метод живёт в геймдмоде, а NPC обязаны работать и в
-- песочнице, поэтому проверяем его наличие.
local function Ragdoll(ply)
	if not isfunction(ply.GetRD) then return nil end

	local rag = ply:GetRD()

	return IsValid(rag) and rag or nil
end

-- Идёт чужой арест: анимация уже задана, второй офицер только всё испортит.
local function IsBeingArrested(ply)
	return string.find(ply:GetSVAnim() or "", "sequence_ron_arrest_start_", 1, true) ~= nil
end

--
-- Сбит с ног: лежит рэгдоллом или уже поднял руки по команде. Такую цель
-- офицер обязан брать живой — она беспомощна.
--
function ENT:IsTargetDowned(ply)
	if Ragdoll(ply) then return true end

	return string.find(ply:GetSVAnim() or "", "sequence_ron_comply_start_0", 1, true) ~= nil
end

--
-- Кого берём живым, а не расстреливаем.
--
-- Сбитый с ног попадает сюда независимо от уровня розыска: даже отказавшийся
-- сдаваться (ArrestState 2), оказавшись на земле, задерживается, а не
-- добивается. Именно на это опирается связка «тазер — рэгдолл — наручники».
--
function ENT:WantsToArrest(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return false end
	if not ply:Alive() then return false end
	if ply.IsDying and ply:IsDying() then return false end
	if not isfunction(ply.Surrender) then return false end
	if IsRestrained(ply) or IsBeingArrested(ply) then return false end

	if self:IsTargetDowned(ply) then return true end

	return ply:GetNW2Float("ArrestState") == 1
end

--
-- Куда идти, чтобы защёлкнуть наручники. У сбитого с ног тело уезжает вместе с
-- рэгдоллом, а сущность игрока таскается за головой рэгдолла с отступом вниз —
-- для навигации таз рэгдолла надёжнее.
--
function ENT:GetArrestPos(ply)
	local rag = Ragdoll(ply)

	return rag and rag:GetPos() or ply:GetPos()
end

-- Пока тазер заряжен, а цель на ногах — держим дистанцию и роняем её разрядом,
-- вместо того чтобы лезть в руки к вооружённому человеку.
function ENT:ShouldKeepTaserDistance(ply)
	if not self.HaveTaser then return false end
	if self:IsTargetDowned(ply) then return false end

	return self:GetCooldown("taseruse") <= 0
end

--
-- Ветка боя целиком вместо перестрелки. Возврат true означает «этот кадр
-- обслужен здесь», обычный бой не запускается.
--
function ENT:CustomCombatBehaviour(enemy)
	if not self:WantsToArrest(enemy) then return false end

	local pos = self:GetArrestPos(enemy)
	local dist = self:GetPos():Distance(pos)

	-- Дошли — защёлкиваем.
	if dist <= self.ArrestDistance then
		if not self:PerformArrest(enemy) then coroutine.wait(self.ArrestRetryDelay) end

		return true
	end

	-- Ждём отката тазера на дистанции: подходить вплотную к стоящему на ногах
	-- вооружённому подозреваемому офицеру незачем.
	if self:ShouldKeepTaserDistance(enemy) and dist < self.ArrestTaserDistance then
		self:FaceTowards(pos)
		self:PlayActivity(ACT_IDLE)
		coroutine.wait(0.2)

		return true
	end

	local status = self:FollowPath(pos, {
		run = true,
		face = "enemy",
		tolerance = self.ArrestDistance * 0.75,
		lookahead = 150,
		repath = 0.4,
		maxage = 10,
		target = function() return self:GetArrestPos(enemy) end,
		abort = function()
			if not self:WantsToArrest(enemy) then return true end
			if self:GetEnemy() ~= enemy then return true end

			return self:GetPos():Distance(self:GetArrestPos(enemy)) <= self.ArrestDistance
		end,
	})

	-- Лежачий часто оказывается там, куда навмеш не достаёт: свалился с лестницы,
	-- заполз под столы. Идём напрямую, как это делают твари.
	if status == "unreachable" or status == "failed" then
		self:ApproachDirectly(pos, true)
		coroutine.wait(self.UnreachablePause)
	end

	return true
end

--
-- Сам арест: анимация офицера, Surrender у игрока.
--
-- BS_STATE_ANIM на время анимации обязателен — иначе офицер уедет по своим
-- делам, а игрок останется защёлкиваться в пустоту. Саму анимацию состояние не
-- перебьёт: PlayAnim с lockAnim ставит AnimLockUntil, а PlayActivity его уважает.
--
function ENT:PerformArrest(ply)
	if not self:WantsToArrest(ply) then return false end

	local id = math.random(1, 6)
	local anim = "sequence_ron_arrest_start_player_0" .. id
	local _, dur = ply:LookupSequence(anim)
	if not isnumber(dur) or dur <= 0 then dur = 5 end

	ply:SetEyeAngles(self:GetAngles())

	-- Модели обязаны совпасть позициями, иначе наручники надеваются в воздух.
	-- Лежачего подтягиваем к офицеру, к стоящему офицер встаёт сам.
	if Ragdoll(ply) then
		ply:SetPos(self:GetPos())
	else
		self:SetPos(ply:GetPos())
	end

	ply:Surrender(true, true, id, dur)
	self:EmitSound(")murdered/other/arrest_body.mp3", 60)
	self:PlayAnim(anim, true)
	self:SetState(BS_STATE_ANIM, dur)

	return true
end

--
-- Пока подозреваемый идёт под арест, стрелять нельзя. Возврат false запрещает
-- огонь — этот хук читает bs_npc_human/sv_weapon.lua.
--
function ENT:OnWeaponCanFire()
	local ply = self:GetEnemy()
	if not IsValid(ply) then return true end

	if self:WantsToArrest(ply) then return false end

	self.Weapon_RetreatDistance = 125

	return true
end

-- Удар в упор по тому, кого приказано брать живым, тоже кончается арестом.
function ENT:CustomOnMeleeAttack_AfterChecks(ent)
	if not self:WantsToArrest(ent) then return false end

	return self:PerformArrest(ent)
end

--------------------------------------------------------------------------------
-- Тазер
--------------------------------------------------------------------------------

function ENT:TaserLogic()
	if not self.HaveTaser then return end

	local en = self:GetEnemy()

	if not IsValid(en) or not en:IsPlayer() then
		self:SetCooldown("taseruse", math.Rand(30, 60))

		return
	end

	if en:GetNW2Float("ArrestState") ~= 1 then return end
	if self:GetCooldown("taseruse") > 0 then return end

	-- Лежачего ронять нечем: он уже на земле, его надо просто заковать.
	if self:IsTargetDowned(en) then return end

	--
	-- Дальность и видимость проверяем ДО того, как жечь откат. Раньше офицер
	-- начинал доставать тазер с любого расстояния, а UseTaser отбрасывал выстрел
	-- уже после анимации доставания — откат в 30-60 секунд уходил впустую, и
	-- ветка ареста всё это время ждала разряда, которого не будет.
	--
	if self:GetPos():Distance(en:GetPos()) >= self.TaserRange then return end
	if not self:HasLOS(en) then return end

	self:SetCooldown("taseruse", math.Rand(30, 60))
	self:UseTaser()
end

function ENT:UseTaser()
	if self.UsingTaser then return end

	local wep = self:GetActiveWeapon()
	local att = self:LookupAttachment(self.WeaponAttachment)
	if not att or att <= 0 then return end

	if IsValid(wep) then wep:SetNoDraw(true) end

	local taser = ents.Create("base_anim")
	if not IsValid(taser) then return end

	taser:SetModel("models/murdered/weapons/w_taser.mdl")
	taser:Spawn()
	taser:SetParent(self, att)
	taser:SetLocalAngles(Angle(270, 90, 0))
	taser:SetLocalPos(Vector(2, 0, 2))
	self:DeleteOnRemove(taser)

	self.UsingTaser = true

	local draw = self:PlayAnim("drawpistol", true)
	if draw <= 0 then draw = 1 end

	timer.Simple(draw, function()
		if not IsValid(self) then
			SafeRemoveEntity(taser)
			return
		end

		self:PlayAnim("drawpistol", true)
		self.UsingTaser = false

		if IsValid(wep) then wep:SetNoDraw(false) end
		SafeRemoveEntity(taser)

		local ent = self:GetEnemy()
		if not IsValid(ent) then return end
		if self:GetPos():Distance(ent:GetPos()) >= self.TaserRange then return end
		if not self:HasLOS(ent) then return end

		self:ShockTarget(ent, att)
	end)
end

function ENT:ShockTarget(ent, att)
	self:EmitSound(")murdered/other/taser.wav", 70)

	local from = self:GetAttachment(att)

	local effect = EffectData()
	effect:SetStart(from and from.Pos or self:GetEyeOrigin())
	effect:SetOrigin(ent:WorldSpaceCenter())
	effect:SetScale(1)
	effect:SetMagnitude(5)
	effect:SetFlags(0)
	util.Effect("ToolTracer", effect)

	if not ent:IsPlayer() then
		ent:TakeDamage(50, self, self)

		return
	end

	ent:StartRagdolling()
	ent:TimeGetUpChange(9, true)

	local name = "BSTasered" .. ent:EntIndex()
	timer.Create(name, 0.05, 50, function()
		if not IsValid(ent) or not ent:Alive() then
			timer.Remove(name)
			return
		end

		ent:SetEyeAngles(ent:EyeAngles() + Angle(math.Rand(-2, 2), math.Rand(-2, 2), 0))
		ent:ViewPunch(AngleRand(-2, 2))

		if math.random(1, 5) == 1 then
			ent:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 50)

			local ef = EffectData()
			ef:SetEntity(ent)
			ef:SetMagnitude(1)
			util.Effect("TeslaHitboxes", ef)
		end

		local rd = ent.GetRD and ent:GetRD()
		if IsValid(rd) then
			rd:StruggleBone()
			ent.IsRagStanding = false
		end
	end)
end

--------------------------------------------------------------------------------
-- Вышибание запертых дверей
--------------------------------------------------------------------------------

--
-- Отдельно от TryBreakObstacle базы: та открывает незапертые двери, упёршись
-- в них. Здесь офицер именно выбивает запертую, до того как застрянет.
--
function ENT:DoorLogicBust()
	if self.doorbusting then return end
	if CurTime() < (self.NextDoorBust or 0) then return end
	self.NextDoorBust = CurTime() + 1

	local eye = self:GetPos() + Vector(0, 0, 32)
	local fwd = self:GetAngles():Forward()

	local tr = util.TraceLine({
		start = eye,
		endpos = eye + fwd * 40,
		filter = function(ent) return MuR.NPC.IsDoor(ent) end,
	})

	local door = tr.Entity
	if not tr.Hit or not IsValid(door) then return end
	if not door:GetInternalVariable("m_bLocked") then return end

	self.doorbusting = true
	self:DoorKickUnlock(door, tr.Fraction)
end

function ENT:DoorKickUnlock(door, frac)
	self:PlayAnim(self.DoorKickAnim, true, 1.1)

	if self.DoorKickSetBack then
		self:SetPos(self:GetPos() - self:GetForward() * (24 * frac))
	end

	timer.Simple(0.75, function()
		if not IsValid(self) or not IsValid(door) then return end

		local dmg = DamageInfo()
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetDamage(math.random(200, 300))
		dmg:SetDamageForce(self:GetForward() * 100000)
		dmg:SetDamageType(DMG_CRUSH)
		dmg:SetDamagePosition(self:WorldSpaceCenter())
		door:TakeDamageInfo(dmg)
	end)

	timer.Simple(1.2, function()
		if not IsValid(self) then return end

		if self.DoorKickSetBack then
			self:SetPos(self:GetPos() + self:GetForward() * (24 * frac))
		end

		self.doorbusting = false
	end)
end

--------------------------------------------------------------------------------
-- Взаимодействие
--------------------------------------------------------------------------------

function ENT:AcceptInput(key, activator, caller, data)
	if key == "Use" then
		-- Кадр задержки: иначе приказ ловится в тот же тик, что и выстрел или
		-- перезарядка игрока, и офицер срывается следовать посреди боя.
		timer.Simple(0.1, function()
			if not IsValid(self) or not IsValid(activator) then return end
			if not activator:IsPlayer() or not activator:IsRolePolice() then return end
			if activator:KeyDown(IN_ATTACK) or activator:KeyDown(IN_ATTACK2) or activator:KeyDown(IN_RELOAD) then return end

			self:Follow(activator, true)
		end)
	elseif key == "StartScripting" then
		self:SetState(BS_STATE_FREEZE)
	elseif key == "StopScripting" then
		self:SetState(BS_STATE_NONE)
	elseif key == "break" then
		local dmginfo = DamageInfo()
		dmginfo:SetDamage(self:Health())
		dmginfo:SetDamageType(DMG_ALWAYSGIB)
		dmginfo:SetAttacker(activator)
		dmginfo:SetInflictor(activator)
		self:TakeDamageInfo(dmginfo)

		return true
	end

	return false
end
