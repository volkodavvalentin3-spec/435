local meta = FindMetaTable("Player")

util.AddNetworkString("MuR.CuffsFreed")
util.AddNetworkString("MuR.CuffsAborted")
util.AddNetworkString("MuR.ZipEscapeOpen")
util.AddNetworkString("MuR.ZipEscapeResult")
util.AddNetworkString("MuR.ZipEscapeState")

MuR.RestraintRescueRange = 140
local RESCUE_RANGE = MuR.RestraintRescueRange

MuR.Restraints = {
	cuffs = {
		flag = "MuR.Cuffed",
		progress = "MuR.CuffProgress",
		rescue_time = 10,
		wanted_time = 2,
		causes_wanted = true,
		counts_as_arrest = true,
		self_escape = false,
		message_on = "cuffed",
		message_off = "uncuffed"
	},
	ziptie = {
		flag = "MuR.Zipped",
		progress = "MuR.ZipProgress",
		rescue_time = 5,
		causes_wanted = false,
		counts_as_arrest = false,
		self_escape = true,
		escape_hits = 6,
		escape_stamina = 15,
		escape_lockout = 8,
		message_on = "ziptied",
		message_off = "unziptied"
	}
}

function meta:GetRestraint()
	if self:GetNW2Bool("MuR.Cuffed", false) then return "cuffs" end
	if self:GetNW2Bool("MuR.Zipped", false) then return "ziptie" end
	return nil
end

function MuR.RemoveCuffWelds(rag)
	if not IsValid(rag) then return end
	if IsValid(rag.CuffWeld) then
		rag.CuffWeld:Remove()
	end
	rag.CuffWeld = nil
end

function MuR.WeldCuffedHands(ply, rag)
	if not IsValid(rag) then return end

	MuR.RemoveCuffWelds(rag)

	local lbone = rag:LookupBone("ValveBiped.Bip01_L_Hand")
	local rbone = rag:LookupBone("ValveBiped.Bip01_R_Hand")
	if not lbone or not rbone or lbone < 0 or rbone < 0 then return end

	rag.CuffWeld = constraint.Weld(rag, rag,
		rag:TranslateBoneToPhysBone(lbone),
		rag:TranslateBoneToPhysBone(rbone), 10000, false, false)
end

function MuR.HoldCuffedHands(rag)
	if not IsValid(rag) then return end

	local spinePos, spineAng = MuR:BoneData(rag, "ValveBiped.Bip01_Spine2")
	local behind = spinePos - spineAng:Forward() * 7 - Vector(0, 0, 5)

	for _, bonename in ipairs({ "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand" }) do
		local bone = rag:LookupBone(bonename)
		if bone and bone >= 0 then
			local phys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(bone))
			if IsValid(phys) then
				local p = {}
				p.secondstoarrive = 0.25
				p.pos = behind
				p.angle = spineAng
				p.maxangular = 200
				p.maxangulardamp = 400
				p.maxspeeddamp = 60
				p.maxspeed = 80
				p.damp = 400
				phys:Wake()
				phys:ComputeShadowControl(p)
			end
		end
	end
end

function meta:RestrainToRagdoll(kind)
	kind = kind or "cuffs"
	local def = MuR.Restraints[kind]
	if not def then return end
	if not IsValid(self) or not self:Alive() then return end

	local rag = self:GetRD()
	if not IsValid(rag) then
		rag = self:StartRagdolling()
	end
	if not IsValid(rag) then return end

	self:Freeze(false)
	self:SetSVAnimation("")
	self:SetNotSolid(true)

	rag:GrabHand(false, false)
	rag:GrabHand(false, true)

	MuR.WeldCuffedHands(self, rag)

	rag:SetNW2Bool(def.flag, true)

	rag.CanStanding = false
	self.IsRagStanding = false
	self:SetNW2Bool("IsRagStanding", false)
	self:TimeGetUpChange(999999, true)

	self.CuffRag = rag
	self.CuffRescuers = nil
	self.RestraintKind = kind

	if not def.counts_as_arrest then
		self.CuffLawful = false
		self:SetNW2Bool("MuR.CuffLawful", false)
	end

	self:SetNW2Bool(def.flag, true)
	self:SetNW2Float(def.progress, 0)
	self:SetNW2Bool("ForceProneOnly", true)

	if def.self_escape then
		self.EscapeHits = 0
		self.EscapeLockout = 0
		self:SetNW2Float("MuR.ZipEscape", 0)
	end

	MuR:RefreshNoTarget(self)
	MuR:GiveMessage2(def.message_on, self)
end

function meta:CuffToRagdoll()
	self:RestrainToRagdoll("cuffs")
end

function meta:ZipTieToRagdoll()
	self:RestrainToRagdoll("ziptie")
end

function MuR.RemoveCuffRescuer(ply, notify)
	for _, victim in player.Iterator() do
		local rescuers = victim.CuffRescuers
		if rescuers and rescuers[ply] then
			rescuers[ply] = nil
			if notify then
				net.Start("MuR.CuffsAborted")
				net.WriteString("cuffs_interrupted")
				net.Send(ply)
			end
			return
		end
	end
end

function meta:UnrestrainPlayer(freed, died)
	local kind = self:GetRestraint()
	if not kind then return end

	local def = MuR.Restraints[kind]

	if self.CuffRescuers then
		for rescuer in pairs(self.CuffRescuers) do
			if IsValid(rescuer) then
				if freed then
					net.Start("MuR.CuffsFreed")
					net.Send(rescuer)
				else
					net.Start("MuR.CuffsAborted")
					net.WriteString("cuffs_target_lost")
					net.Send(rescuer)
				end
			end
		end
	end

	self:SetNW2Bool(def.flag, false)
	self:SetNW2Float(def.progress, 0)
	self:SetNW2Float("MuR.ZipEscape", 0)
	self:SetNW2Bool("MuR.CuffLawful", false)
	self.CuffLawful = nil
	self.CuffRescuers = nil
	self.RestraintKind = nil

	MuR:RefreshNoTarget(self)
	self.EscapeHits = nil
	self.EscapeLockout = nil

	local soundPlayed = false
	for _, rag in ipairs({ self:GetRD(), self.CuffRag }) do
		if IsValid(rag) then
			MuR.RemoveCuffWelds(rag)
			rag:SetNW2Bool(def.flag, false)
			if not soundPlayed then
				rag:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 55, 80, 0.6)
				soundPlayed = true
			end
		end
	end
	self.CuffRag = nil

	if died then return end
	if not self:Alive() or self:IsDying() then return end

	local rag = self:GetRD()
	if IsValid(rag) then
		rag.CanStanding = true
		self:TimeGetUpChange(3.5, true)
		self:StopRagdolling(false, true)
	end

	if self.CuffPrevArrestState then
		self:SetNW2Float("ArrestState", self.CuffPrevArrestState)
		self.CuffPrevArrestState = nil
	end

	if freed then
		MuR:GiveMessage2(def.message_off, self)
	end
end

function meta:UncuffPlayer(freed, died)
	self:UnrestrainPlayer(freed, died)
end

local function SendEscapeState(ply)
	local def = MuR.Restraints.ziptie
	net.Start("MuR.ZipEscapeState")
	net.WriteUInt(ply.EscapeHits or 0, 4)
	net.WriteUInt(def.escape_hits, 4)
	net.Send(ply)
end

net.Receive("MuR.ZipEscapeResult", function(_, ply)
	local success = net.ReadBool()

	if not IsValid(ply) or not ply:IsZipTied() then return end
	if not MuR:NetRateLimit(ply, "zip_escape", 0.3) then return end
	if not ply.EscapeOpen then return end

	ply.EscapeOpen = false

	local def = MuR.Restraints.ziptie
	local rag = ply:GetRD()
	local soundEnt = IsValid(rag) and rag or ply

	if success then
		ply.EscapeHits = math.min((ply.EscapeHits or 0) + 1, def.escape_hits)
		soundEnt:EmitSound("physics/plastic/plastic_box_strain" .. math.random(1, 4) .. ".wav", 65, math.random(95, 110))
	else
		ply.EscapeHits = math.floor((ply.EscapeHits or 0) / 2)
		soundEnt:EmitSound("physics/plastic/plastic_barrel_impact_hard" .. math.random(1, 4) .. ".wav", 75, math.random(90, 105))
		ply:SetNW2Float("Stamina", math.Clamp(ply:GetNW2Float("Stamina", 100) - def.escape_stamina, 0, 100))

		if ply:GetNW2Float("Stamina", 100) <= 0 then
			ply.EscapeLockout = CurTime() + def.escape_lockout
		end
	end

	ply:SetNW2Float("MuR.ZipEscape", ply.EscapeHits / def.escape_hits)

	if ply.EscapeHits >= def.escape_hits then
		ply:UnrestrainPlayer(true)
		return
	end

	SendEscapeState(ply)
end)

hook.Add("KeyPress", "MuR.ZipEscapeStart", function(ply, key)
	if key ~= IN_USE then return end
	if not ply:IsZipTied() then return end
	if ply.EscapeOpen then return end
	if (ply.EscapeLockout or 0) > CurTime() then return end
	if not MuR:NetRateLimit(ply, "zip_escape_open", 0.5) then return end

	ply.EscapeOpen = true

	local def = MuR.Restraints.ziptie
	net.Start("MuR.ZipEscapeOpen")
	net.WriteUInt(ply.EscapeHits or 0, 4)
	net.WriteUInt(def.escape_hits, 4)
	net.Send(ply)
end)

hook.Add("Think", "MuR.CuffedThink", function()
	for _, ply in player.Iterator() do
		local kind = ply:GetRestraint()
		if not kind then continue end

		local def = MuR.Restraints[kind]
		local alive = ply:Alive()

		if alive then
			ply:SetNW2Bool("ForceProneOnly", true)
			ply.IsRagStanding = false

			local rag = ply:GetRD()
			if not IsValid(rag) then
				ply:RestrainToRagdoll(kind)
			else
				if not IsValid(rag.CuffWeld) then
					MuR.WeldCuffedHands(ply, rag)
				end
				MuR.HoldCuffedHands(rag)
			end
		end

		local best = 0
		if alive and ply.CuffRescuers then
			for rescuer, rec in pairs(ply.CuffRescuers) do
				local ok = IsValid(rescuer) and rescuer:Alive() and not rescuer:IsDying()
					and not rescuer:IsRestrained() and not rescuer:GetNoDraw()
					and rescuer.MuR_BodyPanelOpen
					and rescuer:GetPos():DistToSqr(ply:GetPos()) <= RESCUE_RANGE * RESCUE_RANGE

				if not ok then
					MuR.RemoveCuffRescuer(rescuer, true)
					continue
				end

				rec.time = rec.time + FrameTime()
				best = math.max(best, rec.time)

				if def.causes_wanted and ply:GetNW2Bool("MuR.CuffLawful", false)
					and rec.time >= def.wanted_time and not rec.wanted
					and not rescuer:IsRolePolice() and rescuer:GetNW2Float("ArrestState", 0) == 0 then
					rec.wanted = true
					rescuer:SetNW2Float("ArrestState", 1)
					MuR:GiveMessage2("wanted_rescue", rescuer)
				end

				if rec.time >= def.rescue_time then
					ply:UnrestrainPlayer(true)
					break
				end
			end
		end

		ply:SetNW2Float(def.progress, best)

		local rag = ply:GetRD()
		if IsValid(rag) then
			rag:SetNW2Float(def.progress, best)
		end
	end
end)

hook.Add("PlayerDeath", "MuR.Cuffs", function(victim)
	if victim:IsRestrained() then
		victim:UnrestrainPlayer(false, true)
	end
end)

hook.Add("PlayerSpawn", "MuR.Cuffs", function(ply)
	ply:SetNW2Bool("MuR.Cuffed", false)
	ply:SetNW2Bool("MuR.Zipped", false)
	ply:SetNW2Float("MuR.CuffProgress", 0)
	ply:SetNW2Float("MuR.ZipProgress", 0)
	ply:SetNW2Float("MuR.ZipEscape", 0)
	ply:SetNW2Bool("MuR.CuffLawful", false)
	ply.CuffLawful = nil
	ply.CuffRescuers = nil
	ply.CuffRag = nil
	ply.RestraintKind = nil
	ply.EscapeHits = nil
	ply.EscapeLockout = nil
	ply.EscapeOpen = nil
	ply.CuffPrevArrestState = nil
end)

concommand.Add("mur_uncuff", function(ply, _, args)
	if IsValid(ply) and not ply:IsAdmin() then return end

	local targetName = args[1]
	for _, target in player.Iterator() do
		if not target:IsRestrained() then continue end
		if targetName and not string.find(string.lower(target:Nick()), string.lower(targetName), 1, true) then continue end
		target:UnrestrainPlayer(false)
		return
	end
end)
