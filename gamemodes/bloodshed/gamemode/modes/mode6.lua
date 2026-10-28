MuR.RegisterMode(6, {
	name = "Zombies",
	chance = 10,
	need_players = 1,
	disables = true,
	no_default_roles = true,
	win_condition = "zombie",
	zombie_spawning = true,
	escape_flare = true,
	no_guilt = true,
	kteam = "Zombie",
	dteam = "Soldier",
	iteam = "Soldier"
})

if not SERVER then return end

--------------------------------------------------------------------------------
-- Рывки орды
--------------------------------------------------------------------------------
--
-- Зомби в Заражении в основном ковыляют, но временами вся орда переходит на
-- рывок. Окна рывков становятся чаще и длиннее по двум причинам: чем дольше
-- идёт раунд и чем меньше осталось выживших.
--
-- Скорость раздаётся полем, а не через SpeedScale: у базы одна скорость на
-- шаг и бег в этом режиме, а анимацию она выбирает сама по величине.

MuR.Mode6 = MuR.Mode6 or {}

local SHAMBLE_SPEED = 70
local RUSH_SPEED = 250

local GAP_CALM, GAP_TENSE = 45, 14
local DUR_CALM, DUR_TENSE = 5, 13

local function survivorCount()
	local n = 0

	for _, ply in player.Iterator() do
		if ply:Alive() and ply:GetNW2String("Class") ~= "Zombie" then n = n + 1 end
	end

	return n
end

-- 0 — начало раунда и много выживших, 1 — орда на пределе.
local function pressure()
	local elapsed = MuR.TimeCount and math.max(0, CurTime() - MuR.TimeCount) or 0
	local byTime = math.Clamp(elapsed / 600, 0, 1)

	local alive = survivorCount()
	local byPrey = alive <= 1 and 1 or math.Clamp(1 - (alive - 1) / 7, 0, 1)

	return math.max(byTime, byPrey)
end

local function scheduleNextRush(f)
	MuR.Mode6.Rushing = false
	MuR.Mode6.RushEnd = 0
	MuR.Mode6.NextRush = CurTime() + Lerp(f, GAP_CALM, GAP_TENSE) + math.Rand(-4, 4)
end

timer.Create("MuR.Mode6.ZombieRush", 1, 0, function()
	if MuR.Gamemode ~= 6 or not MuR.GameStarted then
		MuR.Mode6.Rushing = nil
		MuR.Mode6.NextRush = nil

		return
	end

	local f = pressure()
	local now = CurTime()

	if not MuR.Mode6.NextRush then scheduleNextRush(f) end

	if MuR.Mode6.Rushing then
		if now >= MuR.Mode6.RushEnd then scheduleNextRush(f) end
	elseif now >= MuR.Mode6.NextRush then
		MuR.Mode6.Rushing = true
		MuR.Mode6.RushEnd = now + Lerp(f, DUR_CALM, DUR_TENSE)
	end

	-- Раздаём каждую секунду, а не по событию: так подхватываются и те зомби,
	-- что заспавнились уже внутри окна рывка.
	local speed = MuR.Mode6.Rushing and RUSH_SPEED or SHAMBLE_SPEED

	for _, z in ipairs(ents.FindByClass("npc_bs_zombie")) do
		z.WalkSpeed = speed
		z.RunSpeed = speed
	end
end)
