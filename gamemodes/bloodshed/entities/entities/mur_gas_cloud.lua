AddCSLuaFile()

--
-- База была obj_vj_projectile_base из VJ Base. Её в сборке нет, поэтому класс
-- не регистрировался вовсе: ents.Create отдавал NULL, и граната просто не
-- появлялась — молча, без ошибки в консоли у того, кто её бросил.
--
-- Своей базе тут делать нечего: весь жизненный цикл (Initialize, Think,
-- PhysicsCollide, Explode, OnRemove) класс описывает сам. От VJ ему доставались
-- только физика в Initialize, которую теперь заводим явно, как это делает
-- рабочий bloodshed_flashbang.
--
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Gas Canister"

ENT.Substance = "chlorine"
ENT.Radius = 300
ENT.Lifetime = 10
ENT.FuseTime = 2
ENT.SmokeColor = "200 255 100"
ENT.Visible = true
ENT.CanisterModel = "models/props_junk/garbage_plasticbottle003a.mdl"

if not SERVER then return end

function ENT:Initialize()
	self:SetModel(self.CanisterModel)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:Wake() end

	self.Activated = false

	timer.Simple(self.FuseTime, function()
		if IsValid(self) then self:Explode() end
	end)
end

function ENT:EmitCloud()
	if not self.Visible then return end

	local smoke = ents.Create("env_smoketrail")
	if not IsValid(smoke) then return end

	smoke:SetPos(self:GetPos())
	smoke:SetKeyValue("startsize", "20")
	smoke:SetKeyValue("endsize", tostring(math.floor(self.Radius * 0.4)))
	smoke:SetKeyValue("spawnradius", "32")
	smoke:SetKeyValue("minspeed", "10")
	smoke:SetKeyValue("maxspeed", "50")
	smoke:SetKeyValue("startcolor", self.SmokeColor)
	smoke:SetKeyValue("endcolor", self.SmokeColor)
	smoke:SetKeyValue("opacity", "0.6")
	smoke:SetKeyValue("spawnrate", "20")
	smoke:SetKeyValue("lifetime", "1")
	smoke:Spawn()
	smoke:Activate()
	SafeRemoveEntityDelayed(smoke, 1)
end

function ENT:Think()
	if not self.Activated then return end

	if CurTime() > self.DieTime then
		self:Remove()
		return
	end

	if CurTime() > self.NextGasEmit then
		self.NextGasEmit = CurTime() + 0.5

		local pos = self:GetPos()
		local owner = IsValid(self.PlayerOwner) and self.PlayerOwner or nil

		self:EmitCloud()

		for _, ply in player.Iterator() do
			if ply:Alive() then
				local dist = ply:GetPos():Distance(pos)
				if dist < self.Radius then
					local tr = util.TraceLine({
						start = pos,
						endpos = ply:EyePos(),
						filter = self,
						mask = MASK_SOLID_BRUSHONLY
					})

					if not tr.Hit then
						local strength = 1 - (dist / self.Radius) * 0.6
						MuR.Chem:Apply(ply, self.Substance, strength, owner)
					end
				end
			end
		end
	end

	self:NextThink(CurTime())
	return true
end

function ENT:PhysicsCollide(data, phys)
	if data.Speed > 50 then
		self:EmitSound("physics/metal/metal_canister_impact_hard" .. math.random(1, 3) .. ".wav", 60, math.random(80, 120))
	end
end

function ENT:OnTakeDamage(dmg)
	if self.Activated then return end
	if dmg:GetDamage() > 5 then self:Explode() end
end

function ENT:Explode()
	if self.Activated then return end

	self.Activated = true
	self.DieTime = CurTime() + self.Lifetime
	self.NextGasEmit = 0

	self:EmitSound("physics/metal/metal_box_break1.wav", 80, 100)

	self.GasSound = CreateSound(self, "ambient/gas/steam_loop1.wav")
	if self.GasSound then self.GasSound:Play() end

	if self.Visible then
		local ed = EffectData()
		ed:SetOrigin(self:GetPos())
		util.Effect("GlassImpact", ed)
	end
end

function ENT:OnRemove()
	if self.GasSound then self.GasSound:Stop() end
end
