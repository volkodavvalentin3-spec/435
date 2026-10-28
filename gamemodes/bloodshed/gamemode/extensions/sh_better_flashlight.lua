if SERVER then
	hook.Add("PlayerDeath", "PlayerDeath_MurderedFlashlight", function(ply)
		if ply:GetNW2Bool("FlashlightIsOn", false) then
			ply:SetNW2Bool("FlashlightIsOn", false)
		end
	end)

	hook.Add("PlayerEnteredVehicle", "PlayerEnteredVehicle_MurderedFlashlight", function(ply, veh, role)
		if ply:GetNW2Bool("FlashlightIsOn", false) then
			ply:SetNW2Bool("FlashlightIsOn", false)
		end
	end)

	hook.Add("StartCommand", "StartCommand_MurderedFlashlight", function(ply, ccmd)
		if ccmd:GetImpulse() == 100 then
			ccmd:SetImpulse(0)
			if ply:Health() <= 0 then return end
			local plyFlashlight = ply:GetNW2Bool("FlashlightIsOn", false)
			plyFlashlight = not plyFlashlight
			local canSwitchFlashlight = hook.Run("PlayerSwitchFlashlight", ply, plyFlashlight)
			if canSwitchFlashlight == true then
				ply:SetNW2Bool("FlashlightIsOn", plyFlashlight)
				ply:EmitSound("HL2Player.FlashLight" .. (plyFlashlight and "On" or "Off"))
			end
		end
	end)
end

if CLIENT then
	local PlayerFlashlights = {}
	local GlowMaterial = Material("sprites/light_ignorez")
	local BeamMaterial = Material("sprites/beam_flashlight")
	local GlobalPixVis = util.GetPixelVisibleHandle()
	local MASK_FLASHLIGHT = game.SinglePlayer() and bit.bor(MASK_OPAQUE_AND_NPCS) or bit.bor(bit.band(MASK_OPAQUE_AND_NPCS, bit.bnot(CONTENTS_HITBOX)), CONTENTS_WINDOW)

	local color, color0, colorbeam = Color(215, 255, 255), Color(215, 255, 255, 0), Color(215, 255, 255)
	hook.Add("PostDrawTranslucentRenderables", "PostDrawTranslucentRenderables_MurderedFlashlight", function()
		for i, ply in player.Iterator() do
			if PlayerFlashlights[ply] and ply:GetNW2Bool("FlashlightIsOn", false) then
				local inThirdPerson = (ply ~= LocalPlayer()) or (ply == LocalPlayer() and ply:ShouldDrawLocalPlayer())
				if inThirdPerson then
					local glowPos = ply:EyePos()
					local glowAng = ply:EyeAngles()
					local glowDir = glowAng:Forward()
					local glowFOV = 70

					local viewNormal = glowPos - EyePos()
					local dist = viewNormal:Length()
					viewNormal:Normalize()
					local viewDot = viewNormal:Dot(glowDir)

					local viewDotInv = viewNormal:Dot(glowDir * -1)
					if viewDotInv >= 0 then
						local visible = util.PixelVisible(glowPos, 16, GlobalPixVis)
						if visible > 0 then
							local spriteSize = math.Clamp(dist * visible * viewDotInv * 1, 64, 512)
							local spriteColor = color
							dist = math.Clamp(dist, 32, 800)
							spriteColor.a = math.Clamp((1000 - dist) * visible * viewDotInv, 0, 100)
							render.SetMaterial(GlowMaterial)
							render.DrawSprite(glowPos, spriteSize, spriteSize, spriteColor)
							spriteColor.a = 255
							render.DrawSprite(glowPos, spriteSize * 0.3, spriteSize * 0.3, spriteColor)
						end
					end

					local beamDot = 1 - math.abs(viewDot ^ 2)
					local beamAlpha = 25 * beamDot
					local beamWidth = glowFOV * 2.5
					local beamMaxLength = 450
					local beamLength = beamMaxLength
					colorbeam.a = beamAlpha
					local hull = 1
					local traceData = {
						start = glowPos,
						endpos = glowPos + glowDir * beamLength,
						maxs = Vector(1, 1, 1) * hull,
						mins = Vector(1, 1, 1) * -hull,
						mask = MASK_FLASHLIGHT,
					}

					local traceResult = util.TraceHull(traceData)
					if traceResult.Hit then beamLength = traceResult.Fraction * beamMaxLength end
					if beamLength > 4 then
						render.SetMaterial(BeamMaterial)
						render.StartBeam(3)
						render.AddBeam(glowPos, beamWidth, 0, colorbeam)
						render.AddBeam(glowPos + glowDir * beamLength * 0.5, beamWidth, (beamLength * 0.5) / beamMaxLength, colorbeam)
						render.AddBeam(glowPos + glowDir * beamLength, beamWidth, beamLength / beamMaxLength, color0)
						render.EndBeam()
					end
				end
			end
		end
	end)

	hook.Add("PreRender", "PreRender_MurderedFlashlight", function()
		for i, ply in player.Iterator() do
			local flashlightRemove = false
			if not ply:GetNW2Bool("FlashlightIsOn", false) then flashlightRemove = true end
			if flashlightRemove then
				if PlayerFlashlights[ply] then
					PlayerFlashlights[ply].ProjectedTexture:Remove()
					PlayerFlashlights[ply] = nil
				end

				continue
			end

			local flashlightData = PlayerFlashlights[ply]
			local flashlightEntity = flashlightData and flashlightData.ProjectedTexture or nil
			if not flashlightData or not flashlightEntity then
				flashlightEntity = ProjectedTexture()
				flashlightEntity:SetTexture("effects/flashlight001")
				flashlightEntity:SetFOV(60)
				flashlightEntity:SetNearZ(12)
				flashlightEntity:SetFarZ(750)
				flashlightEntity:SetEnableShadows(true)
				flashlightEntity:SetLinearAttenuation(100)
				flashlightEntity:Update()
				flashlightEntity:SetBrightness(2)
				PlayerFlashlights[ply] = {}
				PlayerFlashlights[ply].ProjectedTexture = flashlightEntity
				flashlightData = PlayerFlashlights[ply]
			end

			local eyePos = ply:EyePos()
			local eyeAng = ply:EyeAngles()
			local flashlightPos = eyePos
			local flashlightAng = eyeAng
			local flashlightNearZ = 12
			local flashlightShadows = false

			local inThirdPerson = (ply ~= LocalPlayer()) or (ply == LocalPlayer() and ply:ShouldDrawLocalPlayer())
			local isLocalPlayer = LocalPlayer() == ply

			local lerpamt = 12
			if lerpamt > 0.01 then
				flashlightData.AngleLerp = flashlightData.AngleLerp or flashlightAng
				flashlightData.AngleLerp = LerpAngle(lerpamt * RealFrameTime(), flashlightData.AngleLerp, flashlightAng)
				flashlightAng = flashlightData.AngleLerp
			end

			if true then
				flashlightAng = flashlightAng + ply:GetViewPunchAngles()
			end

			flashlightShadows = true
			if inThirdPerson then
				local hull = 8
				local startPos = flashlightPos
				startPos = startPos + flashlightAng:Up() * -20
				startPos = startPos + flashlightAng:Up() * math.abs((startPos + flashlightAng:Forward() * -12)[3] - startPos[3])
				local traceData = {
					start = startPos,
					endpos = startPos + (flashlightAng:Forward() * 96),
					maxs = Vector(1, 1, 1) * hull,
					mins = Vector(1, 1, 1) * -hull,
					mask = MASK_FLASHLIGHT,
				}

				local frontTrace = util.TraceHull(traceData)
				flashlightNearZ = flashlightNearZ + math.max(0, frontTrace.StartPos:Distance(frontTrace.HitPos) - 10)
			end

			if isLocalPlayer then
				flashlightData.HL2StyleDistance = flashlightData.HL2StyleDistance or 0
				flashlightPos = flashlightPos + flashlightAng:Up() * -20
				flashlightPos = flashlightPos + flashlightAng:Up() * math.abs((flashlightPos + flashlightAng:Forward() * -12)[3] - flashlightPos[3])
				local hull = 4
				local traceData = {
					start = flashlightPos,
					endpos = flashlightPos + (flashlightAng:Forward() * flashlightEntity:GetFarZ()),
					maxs = Vector(1, 1, 1) * hull,
					mins = Vector(1, 1, 1) * -hull,
					mask = MASK_FLASHLIGHT,
					filter = ply,
				}

				local frontTrace = util.TraceHull(traceData)
				local pullbackFactor = 5 * FrameTime()
				local dist = frontTrace.StartPos:Distance(frontTrace.HitPos)
				if dist < 128 then
					local plyOnLadder = ply:GetMoveType() == MOVETYPE_LADDER
					local pullBackDist = plyOnLadder and GetConVar("r_flashlightladderdist"):GetFloat() or 128 - dist
					flashlightData.HL2StyleDistance = Lerp(pullbackFactor, flashlightData.HL2StyleDistance, pullBackDist)
					if not plyOnLadder then
						traceData.endpos = flashlightPos - flashlightAng:Forward() * (pullBackDist - 0.1)
						local backTrace = util.TraceHull(traceData)
						if backTrace.Hit then
							local maxDist = (backTrace.HitPos - flashlightPos):Length() - 0.1
							if flashlightData.HL2StyleDistance > maxDist then flashlightData.HL2StyleDistance = maxDist end
						end
					end
				else
					flashlightData.HL2StyleDistance = Lerp(pullbackFactor, flashlightData.HL2StyleDistance, 0)
				end

				flashlightPos = flashlightPos - flashlightAng:Forward() * flashlightData.HL2StyleDistance
				flashlightNearZ = flashlightNearZ + flashlightData.HL2StyleDistance
			end

			flashlightEntity:SetAngles(flashlightAng)
			flashlightEntity:SetPos(flashlightPos)
			flashlightEntity:SetColor(color)
			flashlightEntity:SetNearZ(flashlightNearZ)
			flashlightEntity:SetTexture("effects/flashlight001")
			flashlightEntity:SetEnableShadows(flashlightShadows)
			flashlightEntity:SetFOV(70)
			flashlightEntity:Update()
		end
	end)
end
