local function StaminaRecoveryScale(ply)
	local scale = 1

	local lungStage = math.max(ply:GetNW2Int("OrganDamage_lungs", 0),
		ply:GetNW2Int("OrganDamage_lung_left", 0), ply:GetNW2Int("OrganDamage_lung_right", 0))
	scale = scale - lungStage * 0.25

	scale = scale - ply:GetNW2Int("ShockLevel", 0) * 0.2
	scale = scale - math.Clamp(ply:GetNW2Float("BleedLevel", 0) / 3, 0, 1) * 0.3

	if ply:GetNW2Bool("Pneumothorax", false) then scale = scale - 0.2 end
	if ply:GetNW2Bool("RibFracture", false) then scale = scale - 0.1 end

	if ply:GetNW2Bool("HardBleed", false) then return 0 end

	scale = scale * ply:GetNW2Float("ChemStaminaMul", 1)
	scale = scale * ply:GetNW2Float("KillerStaminaMul", 1)

	return math.Clamp(scale, 0, 1.6)
end

hook.Add("SetupMove", "MuR_Move", function(ply, mv, cmd)
	local hunger = ply:GetNW2Float("Hunger")
	local stam = ply:GetNW2Float("Stamina")
	local legBroken = ply:GetNW2Bool("LegBroken")
	local footFracture = ply:GetNW2Bool("FootFracture")
	local pelvisFracture = ply:GetNW2Bool("PelvisFracture")
	local ribFracture = ply:GetNW2Bool("RibFracture")
	local moving = math.abs(mv:GetForwardSpeed()) > 0 or math.abs(mv:GetSideSpeed()) > 0
	local wantsSprint = mv:KeyDown(IN_SPEED) and moving and not mv:KeyDown(IN_WALK)

	ply.RunMult = ply.RunMult or 0

	if ply:GetNW2Bool("Mode18Staminup") then
		ply:SetNW2Float("Stamina", 100)
		stam = 100
		if wantsSprint then
			ply.RunMult = math.min(ply.RunMult + FrameTime() * 250, ply:GetRunSpeed() * 1.2)
			mv:SetMaxSpeed(ply:GetWalkSpeed() + ply.RunMult)
			mv:SetMaxClientSpeed(ply:GetWalkSpeed() + ply.RunMult)
		else
			ply.RunMult = 0
		end
		return
	end

	if not ply:GetNW2Bool("GeroinUsed") then
		if wantsSprint then
			ply:SetNW2Float("Stamina",
				math.Clamp(stam - FrameTime() / 0.2 / ply:GetNW2Float("KillerStaminaMul", 1), 0, 100))

			ply.RunMult = math.min(ply.RunMult + FrameTime() * 180, ply:GetRunSpeed())
			mv:SetMaxSpeed(ply:GetWalkSpeed() + ply.RunMult)
			mv:SetMaxClientSpeed(ply:GetWalkSpeed() + ply.RunMult)
		else
			local recovery = (FrameTime() / 0.18) * StaminaRecoveryScale(ply)
			ply:SetNW2Float("Stamina", math.Clamp(stam + recovery, 0, 100))
			ply.RunMult = 0
		end

		if stam <= 0 then
			ply.RunMult = 0
		end

		if stam < 10 then
			mv:SetMaxSpeed(ply:GetWalkSpeed() + ply.RunMult / 4)
			mv:SetMaxClientSpeed(ply:GetWalkSpeed() + ply.RunMult / 4)
		elseif stam < 40 then
			mv:SetMaxSpeed(ply:GetWalkSpeed() + ply.RunMult / 2)
			mv:SetMaxClientSpeed(ply:GetWalkSpeed() + ply.RunMult / 2)
		end

        if SERVER then
            local jp = ply.SpawnDataSpeed[3]
            if pelvisFracture then
                ply:SetJumpPower(jp*0.35)
            elseif legBroken then
                ply:SetJumpPower(jp*0.5)
            elseif footFracture then
                ply:SetJumpPower(jp*0.75)
            elseif stam < 10 then
                ply:SetJumpPower(jp*0.6)
            elseif stam < 40 then
                ply:SetJumpPower(jp*0.8)
            else
                ply:SetJumpPower(jp)
            end
        end

		if stam <= 0 and (ply:WaterLevel() == 3 or IsValid(ply:GetRD()) and ply:GetRD():WaterLevel() == 3) then
			if ply.TakeDamageTime and ply.TakeDamageTime < CurTime() then
				ply.TakeDamageTime = CurTime() + 1
				ply:TakeDamage(5)
				ply:EmitSound("player/pl_drown" .. math.random(1, 3) .. ".wav", 40)
			end
		elseif stam > 0 and (ply:WaterLevel() == 3 or IsValid(ply:GetRD()) and ply:GetRD():WaterLevel() == 3) then
			ply:SetNW2Float("Stamina", math.Clamp(stam - FrameTime() / 0.1, 0, 100))
		end

		local hasAdrenaline = ply:GetNW2Float("AdrenalineEnd", 0) > CurTime()
		if pelvisFracture and not hasAdrenaline then
			mv:SetMaxSpeed(ply:GetWalkSpeed() / 3)
			mv:SetMaxClientSpeed(ply:GetWalkSpeed() / 3)
		elseif (hunger < 20 or legBroken) and not hasAdrenaline then
			mv:SetMaxSpeed(ply:GetWalkSpeed() / 2)
			mv:SetMaxClientSpeed(ply:GetWalkSpeed() / 2)
		elseif ply:GetNW2Float("BleedLevel") >= 3 then
			mv:SetMaxSpeed(ply:GetWalkSpeed() / 1.5)
			mv:SetMaxClientSpeed(ply:GetWalkSpeed() / 1.5)
		elseif hunger < 50 or ply:GetNW2Float("BleedLevel") == 2 or ply:GetNW2Float("Guilt") >= 40 then
			mv:SetMaxSpeed(ply:GetWalkSpeed())
			mv:SetMaxClientSpeed(ply:GetWalkSpeed())
		end

		if ply:GetNW2Float("peppereffect") > CurTime() then
			mv:SetMaxClientSpeed(40)
		end

		if not hasAdrenaline and footFracture then
			local footSpeed = ply:GetWalkSpeed() / 1.3
			mv:SetMaxSpeed(math.min(mv:GetMaxSpeed(), footSpeed))
			mv:SetMaxClientSpeed(math.min(mv:GetMaxClientSpeed(), footSpeed))
		end

		if not hasAdrenaline and ribFracture and (wantsSprint or ply:GetVelocity():Length() > 160) then
			local ribSpeed = ply:GetWalkSpeed() / 1.15
			mv:SetMaxSpeed(math.min(mv:GetMaxSpeed(), ribSpeed))
			mv:SetMaxClientSpeed(math.min(mv:GetMaxClientSpeed(), ribSpeed))
		end
	end
end)
