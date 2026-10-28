local function StopHostage(attacker, victim, escaped)
	if IsValid(attacker) then
		attacker:SetNW2Entity("HostageVictim", NULL)
		attacker:SetNW2Bool("HostageShooting", false)
		if escaped then
			attacker:SetSVAnimation("mur_hostage_attacker_escape", true)
		else
			attacker:SetSVAnimation("")
		end
        attacker:EmitSound("murdered/gore/punch"..math.random(1, 4)..".mp3", 60)
	end

	if IsValid(victim) then
		victim:SetNW2Entity("HostageAttacker", NULL)
		victim:SetMoveType(MOVETYPE_WALK)
		victim:SetSVAnimation("mur_hostage_victim_escape", true)

        if escaped then
            MuR:GiveMessage2("hostage_escape", victim)
        end

		timer.Simple(0.5, function()
			if IsValid(victim) and victim:Alive() then
				victim:StartRagdolling()
                victim.IsRagStanding = false
			end
		end)
	end
end

local function StartHostage(attacker, victim)
	if not IsValid(attacker) or not IsValid(victim) then return end

	attacker:SetNW2Entity("HostageVictim", victim)
	victim:SetNW2Entity("HostageAttacker", attacker)

	victim:SetMoveType(MOVETYPE_NONE)

	local victimFwd = victim:GetForward()
	local attackFwd = attacker:GetForward()
	local dotFacing = victimFwd:Dot(attackFwd)

	if dotFacing < -0.5 then
		attacker:SetSVAnimation("mur_hostage_attacker_front", true)
		victim:SetSVAnimation("mur_hostage_victim_front", true)
	else
		attacker:SetSVAnimation("mur_hostage_attacker_behind", true)
		victim:SetSVAnimation("mur_hostage_victim_behind", true)
	end
    attacker:EmitSound("murdered/gore/punch"..math.random(1, 4)..".mp3", 60)
    MuR:GiveMessage2("hostage_taken", victim)
end

concommand.Add("mur_hostage_capture", function(ply)
	if not IsValid(ply) or not ply:IsKiller() then return end
	if ply.HostageCaptureDelay and ply.HostageCaptureDelay > CurTime() then return end
	ply.HostageCaptureDelay = CurTime() + 1

	local victim = ply:GetNW2Entity("HostageVictim")
	if IsValid(victim) then
		StopHostage(ply, victim, true)
		return
	end

	local tr = ply:GetEyeTrace()
	if IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity:Alive() and tr.HitPos:DistToSqr(ply:GetPos()) < 5000 then
		if not IsValid(ply:GetNW2Entity("HostageVictim")) and not IsValid(tr.Entity:GetNW2Entity("HostageAttacker")) and not IsValid(ply:GetNW2Entity("HostageAttacker")) and not IsValid(tr.Entity:GetNW2Entity("HostageVictim")) then
			StartHostage(ply, tr.Entity)
		end
	end
end)

concommand.Add("mur_hostage_execute", function(ply)
	if not IsValid(ply) or not ply:IsKiller() then return end

	local victim = ply:GetNW2Entity("HostageVictim")
	if IsValid(victim) then
		StopHostage(ply, victim, false)
		MuR:GiveMessage2("execution_victim", victim)
		timer.Simple(0.1, function()
			if IsValid(ply) and IsValid(victim) then
				ply:FullTakedown(victim)
			end
		end)
	end
end)

hook.Add("KeyPress", "MuR.HostageShooting", function(ply, key)
	if key == IN_ATTACK then
		if IsValid(ply:GetNW2Entity("HostageVictim")) then
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:Clip1() > 0 then
				ply:SetNW2Bool("HostageShooting", true)
				timer.Simple(1, function()
					if IsValid(ply) then ply:SetNW2Bool("HostageShooting", false) end
				end)
			end
		end
	elseif key == IN_JUMP and (!ply.HostageSpaceDelay or ply.HostageSpaceDelay < CurTime()) then
		local attacker = ply:GetNW2Entity("HostageAttacker")
		if IsValid(attacker) then
			ply.HostageEscapeProgress = (ply.HostageEscapeProgress or 0) + 2
            ply.HostageSpaceDelay = CurTime() + 0.05
			if ply.HostageEscapeProgress >= 100 then
				StopHostage(attacker, ply, true)
				ply.HostageEscapeProgress = 0
				ply:SetNW2Float("HostageResist", 0)
				attacker:SetNW2Float("HostageResist", 0)
			end
		end
	end
end)

hook.Add("Think", "MuR.HostageThink", function()
	for _, ply in player.Iterator() do
		local victim = ply:GetNW2Entity("HostageVictim")
		if IsValid(victim) then
			if not victim:Alive() or not ply:Alive() or IsValid(ply:GetRD()) or IsValid(victim:GetRD()) then
				StopHostage(ply, victim, false)
			else
				victim:SetPos(ply:GetPos() + ply:GetForward()*4)
				victim:SetEyeAngles(ply:GetAngles())
				victim:SetVelocity(Vector(0,0,0))
                victim:SetActiveWeapon(nil)

				if victim.HostageEscapeProgress and victim.HostageEscapeProgress > 0 then
					victim.HostageEscapeProgress = math.max(0, victim.HostageEscapeProgress - FrameTime() * 5)
					ply:SetNW2Float("HostageResist", victim.HostageEscapeProgress)
					victim:SetNW2Float("HostageResist", victim.HostageEscapeProgress)
				end
			end
		end
	end
end)

hook.Add("PlayerDisconnected", "MuR.HostageDisconnect", function(ply)
	local victim = ply:GetNW2Entity("HostageVictim")
	if IsValid(victim) then
		StopHostage(ply, victim, false)
	end

	local attacker = ply:GetNW2Entity("HostageAttacker")
	if IsValid(attacker) then
		StopHostage(attacker, ply, false)
	end
end)

hook.Add("ShouldCollide", "MuR.HostageCollision", function(ent1, ent2)
	if ent1:IsPlayer() and ent2:IsPlayer() then
		if ent1:GetNW2Entity("HostageVictim") == ent2 or ent2:GetNW2Entity("HostageVictim") == ent1 then
			return false
		end
	end
end)
