-- Реакция на флешку. Зовётся bloodshed_flashbang.lua из обхода NPC:
--   npc:OnFlashbang(duration, intensity)
-- где duration — секунды ослепления (2..8, как у игроков), intensity — 0..1.
--
-- Ослеплённый не прекращает бой, а стреляет впустую: точность падает.
-- Сильная вспышка с большой вероятностью валит подозреваемого на колени —
-- ради этого флешки в режиме и существуют.

function ENT:OnFlashbang(duration, intensity)
	if self:Health() <= 0 then return end

	duration = duration or 5
	intensity = math.Clamp(intensity or 0.5, 0, 1)

	self.FlashbangEnd = CurTime() + duration

	-- Штраф к точности на время ослепления. У нашей базы множитель разброса,
	-- поэтому слепой = БОЛЬШЕ. Базовое значение помним, чтобы вернуть.
	self.BaseAccuracy = self.BaseAccuracy or self.Weapon_Accuracy
	self.Weapon_Accuracy = self.BaseAccuracy * (1 + 4 * intensity)

	-- Оглушение прерывает текущие действия и не даёт ходить.
	self:SetState(BS_STATE_ANIM, duration)
	self:PlayActivity(ACT_IDLE)

	self:AddSuppression(100 * intensity)

	-- Гражданский в панику, подозреваемый — на колени.
	if self.IsCivilian and not self.HasRevealed then
		self:AddFear(60)
		self.LastFearPos = self:GetPos()
	elseif intensity >= 0.5 and not self.Surrendering then
		if math.random(100) <= 85 then self:TrySurrender(true, self:GetEnemy()) end
	end
end
