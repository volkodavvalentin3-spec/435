AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Поведение твари: врага догоняем и бьём, без врага — бродим по навмешу.
-- Всё, что ниже, работает внутри корутины RunBehaviour базы.
function ENT:RunIdle()
	local enemy = self:GetEnemy()

	if IsValid(enemy) then
		self:CombatBehaviour(enemy)
		return
	end

	-- Цель потеряна, но наводка ещё свежая: идём проверять место, а не забываем
	-- о ней немедленно и уходим бродить.
	if self:SearchBehaviour() then return end

	self:PeaceBehaviour()
end

function ENT:CombatBehaviour(enemy)
	-- Порядок важен: удар в упор всегда приоритетнее прыжка, иначе тварь
	-- будет перепрыгивать вплотную стоящую цель вместо того, чтобы бить.
	if self:CanMeleeAttack() then
		coroutine.wait(self:StartMeleeAttack())
		return
	end

	if self:CanLeapAttack() then
		coroutine.wait(self:StartLeapAttack())
		return
	end

	if self:CanRangeAttack() then
		coroutine.wait(self:StartRangeAttack())
		return
	end

	-- Часть стаи заходит по дуге. Иначе все бегут по одному кратчайшему пути,
	-- выстраиваются в затылок и втягиваются в один дверной проём, где передний
	-- собой же и запирает остальных.
	if self:GetCombatRole() == "flank" and self:FlankBehaviour(enemy) then return end

	local status = self:ChaseEnemy(enemy)

	-- Троттлинг срабатывает только в вырожденном случае: путь закрылся
	-- мгновенно, а враг всё ещё далеко. Нормальный проход по пути длится
	-- дольше интервала, так что рывков в обычной погоне не будет.
	if status == "throttled" then
		self:ApproachDirectly(enemy:GetPos(), true)
		coroutine.wait(0.1)

		return
	end

	if status == "unreachable" or status == "failed" then
		-- Навмеш до врага не достаёт (он на крыше, за стеклом, в запертой
		-- комнате). Идём напрямую, чтобы тварь хотя бы упёрлась в преграду
		-- рядом с ним, а не встала на месте.
		--
		-- Пауза обязательна: без неё корутина крутит эту ветку каждый тик, а
		-- вместе с ней и проверку достижимости на каждого бота.
		self:ApproachDirectly(enemy:GetPos(), true)
		coroutine.wait(self.UnreachablePause)
	end
end

function ENT:PeaceBehaviour()
	if not self.CanWander then
		self:PlayActivity(ACT_IDLE)
		return
	end

	if CurTime() < (self.NextWander or 0) then
		self:PlayActivity(ACT_IDLE)
		return
	end

	self.NextWander = CurTime() + MuR.Roll(self.WanderInterval, 5)
	self:WanderOnce(self.WanderRadius)
end
