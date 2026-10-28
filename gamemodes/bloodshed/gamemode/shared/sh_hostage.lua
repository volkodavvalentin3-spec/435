local meta = FindMetaTable("Player")

function meta:IsInHostage(isAttacker)
	if isAttacker then
		return IsValid(self:GetNW2Entity("HostageVictim"))
	else
		return IsValid(self:GetNW2Entity("HostageAttacker"))
	end
end

hook.Add("CalcMainActivity", "MuR.HostageAnimations", function(ply, vel)
	if ply:GetNW2String("SVAnim") ~= "" then return end

	if ply:IsInHostage(true) then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetActivity() == ACT_VM_RELOAD and wep.HoldType == "pistol" then
			return -1, ply:LookupSequence("mur_hostage_attacker_reload")
		end

		if ply:GetNW2Bool("HostageShooting") then
			return -1, ply:LookupSequence("mur_hostage_attacker_shoot")
		end

		if vel:Length2D() > 1 then
			local fwd = ply:GetForward()
			local dot = fwd:Dot(vel)
			if dot > 0 then
				ply:SetCycle(1 - (CurTime() % 1) / 1)
			else
				ply:SetCycle((CurTime() % 1) / 1)
			end
			return -1, ply:LookupSequence("mur_hostage_attacker_move")
		end

		return -1, ply:LookupSequence("mur_hostage_attacker_loop")
	elseif ply:IsInHostage(false) then
		local attacker = ply:GetNW2Entity("HostageAttacker")
		if IsValid(attacker) and attacker:GetVelocity():Length2D() > 1 then
			local fwd = attacker:GetForward()
			local dot = fwd:Dot(attacker:GetVelocity())
			if dot > 0 then
				ply:SetCycle(1 - (CurTime() % 1) / 1)
			else
				ply:SetCycle((CurTime() % 1) / 1)
			end
			return -1, ply:LookupSequence("mur_hostage_victim_move")
		end
		return -1, ply:LookupSequence("mur_hostage_victim_loop")
	end
end)

hook.Add("SetupMove", "MuR.HostageMove", function(ply, mv, cmd)
	if ply:IsInHostage(false) then
		mv:SetForwardSpeed(0)
		mv:SetSideSpeed(0)
		mv:SetUpSpeed(0)
		mv:SetButtons(0)
	elseif ply:IsInHostage(true) then
		if mv:GetForwardSpeed() > 0 then
			mv:SetForwardSpeed(math.min(mv:GetForwardSpeed(), 40))
		end

		if mv:GetForwardSpeed() < 0 then
			mv:SetForwardSpeed(math.max(mv:GetForwardSpeed(), -40))
		end

		mv:SetSideSpeed(0)
	end
end)

hook.Add("StartCommand", "MuR.HostageWeaponRestrict", function(ply, cmd)
	if ply:IsInHostage(false) then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep.HoldType ~= "pistol" then
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_RELOAD)
		end
	end
end)
