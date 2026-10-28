MuR.RegisterMode(22, {
	name = "Emergency Protocol",
	chance = 10,
	need_players = 4,
	spawn_type = "tdm",
	kteam = "Entity",
	dteam = "FBIOperative",
	iteam = "FBIOperative",
	kteam_count = 1,
	timer = 600,
	win_condition = "tdm",
	tdm_end_logic = true,
	win_screen_team1 = "entity_win",
	win_screen_team2 = "fbi_win",
	disables = true,
	disables_police = true,
	no_guilt = true,
	disable_loot = true,

	OnModeStarted = function(mode)
		if SERVER then
			MuR.Mode22 = {
				Cooldowns = {},
				BlackoutActive = false,
				EMPActive = false
			}

			for _, ply in player.Iterator() do
				if ply:GetNW2String("Class") == "Entity" then
					ply:SetNoTarget(true)
				end
			end
		end
	end,

	OnModeThink = function(mode)
		if SERVER then
			for _, ply in player.Iterator() do
				if ply:GetNW2String("Class") == "Entity" then
					ply:SetNoDraw(false)
					ply:SetRenderMode(RENDERMODE_TRANSALPHA)
					ply:SetColor(Color(255, 255, 255, 0))
					ply:DrawShadow(false)
					ply:SetMaterial("models/effects/vol_light001")
					ply:SetNoTarget(true)
				end
			end
		end
	end,

	OnModeEnded = function(mode)
		if SERVER then
			MuR.Mode22 = nil

			for _, ply in player.Iterator() do
				ply:SetRenderMode(RENDERMODE_NORMAL)
				ply:SetColor(Color(255, 255, 255, 255))
				ply:DrawShadow(true)
				ply:SetMaterial("")
				ply:SetNoDraw(false)
			end
		end
	end
})

if SERVER then
	function MuR:EntityAbility(ply, ability, target)
		if MuR.Gamemode ~= 22 then return end
		if ply:GetNW2String("Class") ~= "Entity" then return end

		local cd = MuR.Mode22.Cooldowns[ability] or 0
		if CurTime() < cd then
			return
		end

		if ability == "summon_vermin" then
			local count = math.random(3, 4)

			for i = 1, count do
				--
				-- Раньше в семи случаях из десяти сюда подставлялся
				-- npc_vj_smod_infected_runner из VJ Base. Класса нет, ents.Create
				-- отдавал NULL, и способность молча призывала втрое меньше
				-- тварей, чем обещала.
				--
				local class = "npc_bs_nz_vermin"

				local pos = MuR:GetRandomPos(true, ply:GetPos(), 200, 800, false) or (ply:GetPos() + VectorRand() * 100)
				local ent = ents.Create(class)
				if IsValid(ent) then
					ent:SetPos(pos)
					ent:Spawn()
                    ent.EnemyXRayDetection = true
				end
			end
			ply:EmitSound("murdered/nz/announce_laugh" .. math.random(1, 5) .. ".mp3")
			MuR.Mode22.Cooldowns[ability] = CurTime() + 20
			ply:SetNW2Float("MuR.Mode22.CD." .. ability, MuR.Mode22.Cooldowns[ability])

		elseif ability == "summon_elite" then
			local classes = {"npc_bs_nz_amalgam", "npc_bs_nz_mangler", "npc_bs_nz_mimic"}
			local cls = table.Random(classes)
			local pos = MuR:GetRandomPos(true, ply:GetPos(), 200, 800, false) or (ply:GetPos() + ply:GetForward() * 100)
			local ent = ents.Create(cls)
			if IsValid(ent) then
				ent:SetPos(pos)
				ent:Spawn()
                ent.EnemyXRayDetection = true
			end
			ply:EmitSound("murdered/nz/announce_laugh" .. math.random(1, 5) .. ".mp3")
			MuR.Mode22.Cooldowns[ability] = CurTime() + 60
			ply:SetNW2Float("MuR.Mode22.CD." .. ability, MuR.Mode22.Cooldowns[ability])

		elseif ability == "emp" then
			net.Start("MuR.Mode22.EMP")
			net.Broadcast()
			ply:EmitSound("ambient/energy/zap1.wav")
			MuR.Mode22.Cooldowns[ability] = CurTime() + 60
			ply:SetNW2Float("MuR.Mode22.CD." .. ability, MuR.Mode22.Cooldowns[ability])

		elseif ability == "blackout" then
			net.Start("MuR.Mode22.Blackout")
			net.WriteUInt(15, 8)
			net.Broadcast()
			ply:EmitSound("ambient/energy/power_off1.wav")

			for _, v in player.Iterator() do
				if v:GetNW2String("Class") ~= "Entity" and v:Alive() then
					local wep = v:GetActiveWeapon()
					if IsValid(wep) then
						v:DropWeapon(wep)
					end
				end
			end

			MuR.Mode22.Cooldowns[ability] = CurTime() + 120
			ply:SetNW2Float("MuR.Mode22.CD." .. ability, MuR.Mode22.Cooldowns[ability])

		elseif ability == "teleport" then
			local targets = {}
			for _, v in player.Iterator() do
				if v:GetNW2String("Class") == "FBIOperative" and v:Alive() then
					table.insert(targets, v)
				end
			end

			local target = table.Random(targets)
			local pos = nil

			if IsValid(target) then

				pos = MuR:GetRandomPos(nil, target:GetPos(), 600, 1200, true)
			end

			if not pos then
				pos = MuR:GetRandomPos(nil, ply:GetPos(), 1000, 3000, true)
			end

			if pos then
				ply:SetPos(pos)
				ply:EmitSound("ambient/levels/citadel/portal_beam_shoot1.wav")
				MuR.Mode22.Cooldowns[ability] = CurTime() + 15
				ply:SetNW2Float("MuR.Mode22.CD." .. ability, MuR.Mode22.Cooldowns[ability])
			else
				ply:ChatPrint(MuR.Language["mode22_no_teleport"])
			end

		elseif ability == "power_strike" then
			if not IsValid(target) then return end

			if target:IsPlayer() then
				if target:Alive() then
                    target:SetPos(target:GetPos() + Vector(0,0,8))
                    target:SetVelocity(ply:GetAimVector() * 1000 + Vector(0,0,100))
                    timer.Simple(0.1, function()
                        if !IsValid(target) then return end
                        target:StartRagdolling(0, 14, nil)
                        target.IsRagStanding = false
                    end)

				end
				ply:EmitSound("physics/flesh/flesh_bloody_break.wav")

			elseif target:GetClass() == "prop_door_rotating" or target:GetClass() == "func_door" then
				local model = target:GetModel()
				local pos = target:GetPos()
				local ang = target:GetAngles()
				local skin = target:GetSkin()

				target:Fire("Open")
				target:SetNoDraw(true)
				target:SetNotSolid(true)

				local ent = ents.Create("prop_physics")
				ent:SetModel(model)
				ent:SetPos(pos)
				ent:SetAngles(ang)
				ent:SetSkin(skin)
				ent:Spawn()

				local phys = ent:GetPhysicsObject()
				if IsValid(phys) then
					phys:ApplyForceCenter(ply:GetAimVector() * 50000)
				end
				ply:EmitSound("physics/wood/wood_crate_break3.wav")

				timer.Simple(10, function()
					if IsValid(ent) then ent:Remove() end
					if IsValid(target) then
						target:SetNoDraw(false)
						target:SetNotSolid(false)
						target:Fire("Close")
					end
				end)

			elseif target:GetClass() == "prop_physics" then
				local phys = target:GetPhysicsObject()
				if IsValid(phys) then
					phys:ApplyForceCenter(ply:GetAimVector() * 50000)
				end
				ply:EmitSound("physics/metal/metal_box_break1.wav")
			end

			MuR.Mode22.Cooldowns[ability] = CurTime() + 5
			ply:SetNW2Float("MuR.Mode22.CD." .. ability, MuR.Mode22.Cooldowns[ability])
		end
	end

	util.AddNetworkString("MuR.Mode22.EMP")
	util.AddNetworkString("MuR.Mode22.Blackout")

	hook.Add("EntityTakeDamage", "MuR_Mode22_PowerStrike", function(target, dmg)
		if MuR.Gamemode ~= 22 then return end
		local att = dmg:GetAttacker()
		local infl = dmg:GetInflictor()

		if IsValid(infl) and (infl:GetClass() == "prop_physics" or infl:GetClass() == "prop_ragdoll") then
			if target:IsPlayer() then
				dmg:SetDamage(0)
				if target:GetNW2String("Class") ~= "Entity" then
					target:StartRagdolling(0, 3, nil)
				end
				return true
			end
		end

		if target:IsPlayer() and target:GetNW2String("Class") == "Entity" and MuR.IsAI(att) then
			dmg:SetDamage(0)
			return true
		end

		if IsValid(att) and att:IsPlayer() and att:GetNW2String("Class") == "Entity" then
			local wep = att:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "mur_hands" then

				if target:IsPlayer() then
					dmg:SetDamage(0)
					if target:Alive() then
						target:StartRagdolling(0, 14, nil)
					end
					return
				end

				dmg:SetDamage(500)
				dmg:SetDamageType(DMG_BLAST)

				if target:GetClass() == "func_door" or target:GetClass() == "prop_door_rotating" then
					local model = target:GetModel()
					local pos = target:GetPos()
					local ang = target:GetAngles()
					local skin = target:GetSkin()

					target:Fire("Open")
					target:SetNoDraw(true)
					target:SetNotSolid(true)

					local ent = ents.Create("prop_physics")
					ent:SetModel(model)
					ent:SetPos(pos)
					ent:SetAngles(ang)
					ent:SetSkin(skin)
					ent:Spawn()

					local phys2 = ent:GetPhysicsObject()
					if IsValid(phys2) then
						phys2:ApplyForceCenter(att:GetAimVector() * 50000)
					end
					att:EmitSound("physics/wood/wood_crate_break3.wav")

					timer.Simple(10, function()
						if IsValid(ent) then ent:Remove() end
						if IsValid(target) then
							target:SetNoDraw(false)
							target:SetNotSolid(false)
							target:Fire("Close")
						end
					end)
				else

					local phys = target:GetPhysicsObject()
					if IsValid(phys) then
						phys:ApplyForceCenter(att:GetAimVector() * 50000)
					end
				end
			end
		end
	end)

	hook.Add("PlayerButtonDown", "MuR_Mode22_Input", function(ply, button)
		if MuR.Gamemode ~= 22 then return end
		if ply:GetNW2String("Class") ~= "Entity" then return end

		if button == KEY_H then
			MuR:EntityAbility(ply, "teleport")
		elseif button == KEY_G then
			ply.Mode22_HoldStart_G = CurTime()
		elseif button == KEY_F then
			ply.Mode22_HoldStart_F = CurTime()
		elseif button == KEY_R then
			ply.Mode22_HoldStart_R = CurTime()
		end
	end)

	hook.Add("PlayerButtonUp", "MuR_Mode22_InputUp", function(ply, button)
		if MuR.Gamemode ~= 22 then return end
		if ply:GetNW2String("Class") ~= "Entity" then return end

		if button == KEY_G then
			ply.Mode22_HoldStart_G = nil
		elseif button == KEY_F then
			ply.Mode22_HoldStart_F = nil
		elseif button == KEY_R then
			if ply.Mode22_HoldStart_R then
				local dur = CurTime() - ply.Mode22_HoldStart_R
				if dur > 2 then
					MuR:EntityAbility(ply, "summon_elite")
				else
					MuR:EntityAbility(ply, "summon_vermin")
				end
			end
			ply.Mode22_HoldStart_R = nil
		end
	end)

	hook.Add("Think", "MuR_Mode22_HoldCheck_SV", function()
		if MuR.Gamemode ~= 22 then return end
		for _, ply in player.Iterator() do
			if ply:GetNW2String("Class") == "Entity" then
				if ply.Mode22_HoldStart_G and CurTime() - ply.Mode22_HoldStart_G > 3 then
					MuR:EntityAbility(ply, "emp")
					ply.Mode22_HoldStart_G = nil
				end
				if ply.Mode22_HoldStart_F and CurTime() - ply.Mode22_HoldStart_F > 3 then
					MuR:EntityAbility(ply, "blackout")
					ply.Mode22_HoldStart_F = nil
				end
			end
		end
	end)

	hook.Add("PlayerFootstep", "MuR_Mode22_SilentSteps", function(ply)
		if MuR.Gamemode ~= 22 then return end
		if ply:GetNW2String("Class") == "Entity" then
			return true
		end
	end)

	hook.Add("PlayerCanHearPlayersVoice", "MuR_Mode22_Interference_Voice", function(listener, talker)
		if MuR.Gamemode ~= 22 then return end

		local entity = nil
		for _, v in player.Iterator() do
			if v:GetNW2String("Class") == "Entity" then entity = v break end
		end

		if IsValid(entity) and listener ~= entity then
			if listener:GetPos():Distance(entity:GetPos()) < 800 then
				return false, false
			end
		end
	end)

	hook.Add("PlayerSwitchFlashlight", "MuR_Mode22_NoFlashlight", function(ply, enabled)
		if MuR.Gamemode ~= 22 then return end
		if ply:GetNW2String("Class") == "Entity" then
			return false
		end
	end)

	hook.Add("CanDropWeapon", "MuR_Mode22_NoDrop", function(ply, wep)
		if MuR.Gamemode ~= 22 then return end
		if IsValid(wep) and wep:GetClass() == "mur_entity_abilities" then
			return false
		end
	end)

	hook.Add("GetFallDamage", "MuR_Mode22_NoFallDamage", function(ply, speed)
		if MuR.Gamemode ~= 22 then return end
		if ply:GetNW2String("Class") == "Entity" then
			return 0
		end
	end)

	hook.Add("OnPlayerHitGround", "MuR_Mode22_HeavyLanding", function(ply, inWater, onFloater, speed)
		if MuR.Gamemode ~= 22 then return end
		if ply:GetNW2String("Class") ~= "Entity" then return end
		if inWater or onFloater then return end

		if speed > 400 then

			local effectdata = EffectData()
			effectdata:SetOrigin(ply:GetPos())
			effectdata:SetScale(200)
			util.Effect("ThumperDust", effectdata)

			ply:EmitSound("physics/concrete/concrete_break2.wav")
			util.ScreenShake(ply:GetPos(), 10, 5, 1, 1000)

			for _, v in player.Iterator() do
				if v ~= ply and v:Alive() and v:GetPos():Distance(ply:GetPos()) < 300 then
					if v:GetNW2String("Class") ~= "Entity" then
						v:StartRagdolling(0, 4, nil)
					end
				end
			end
		end
	end)

	hook.Add("PlayerDeath", "MuR_Mode22_EntityDeath", function(ply)
		if MuR.Gamemode ~= 22 then return end
		if ply:GetNW2String("Class") == "Entity" then

			timer.Simple(0, function()
				if not IsValid(ply) then return end
				local rag = ply:GetRagdollEntity()
				if IsValid(rag) then rag:Remove() end

				local rd = ply:GetNW2Entity("RD_EntCam")
				if IsValid(rd) then rd:Remove() end
			end)

			local effectdata = EffectData()
			effectdata:SetOrigin(ply:GetPos())
			util.Effect("Explosion", effectdata)

			local fire = ents.Create("env_fire")
			if IsValid(fire) then
				fire:SetPos(ply:GetPos())
				fire:SetKeyValue("health", "30")
				fire:SetKeyValue("firesize", "128")
				fire:SetKeyValue("fireattack", "4")
				fire:SetKeyValue("damagescale", "1.0")
				fire:SetKeyValue("startdisabled", "0")
				fire:SetKeyValue("firetype", "0")
				fire:SetKeyValue("ignitionpoint", "0")
				fire:Spawn()
				fire:Fire("StartFire", "", 0)
				fire:Fire("Kill", "", 15)
			end

			ply:EmitSound("ambient/fire/ignite.wav")
		end
	end)

	hook.Add("KeyPress", "MuR_Mode22_Interactions", function(ply, key)
		if MuR.Gamemode ~= 22 then return end
		if ply:GetNW2String("Class") ~= "Entity" then return end

		if key == IN_ATTACK then
			local tr = util.TraceLine({
				start = ply:EyePos(),
				endpos = ply:EyePos() + ply:GetAimVector() * 2000,
				filter = ply
			})

			if IsValid(tr.Entity) and (tr.Entity:GetClass() == "func_button" or tr.Entity:GetClass() == "func_rot_button") then
				tr.Entity:Input("Press", ply, ply)
				ply:EmitSound("buttons/button14.wav")
			end
		end
	end)

	hook.Add("Think", "MuR_Mode22_Telekinesis", function()
		if MuR.Gamemode ~= 22 then return end

		for _, ply in player.Iterator() do
			if ply:GetNW2String("Class") == "Entity" and ply:Alive() then
				if ply:KeyDown(IN_ATTACK2) then
					if not IsValid(ply.Mode22_HeldEnt) then
						local tr = util.TraceLine({
							start = ply:EyePos(),
							endpos = ply:EyePos() + ply:GetAimVector() * 300,
							filter = ply
						})

						if IsValid(tr.Entity) and not tr.Entity:IsPlayer() then
							local phys = tr.Entity:GetPhysicsObject()
							if IsValid(phys) and phys:IsMoveable() then
								ply.Mode22_HeldEnt = tr.Entity
								ply:SetNW2Entity("Mode22_Held", tr.Entity)
								tr.Entity:SetOwner(ply)
							end
						end
					else
						local ent = ply.Mode22_HeldEnt
						if IsValid(ent) then
							local phys = ent:GetPhysicsObject()
							if IsValid(phys) then
								local targetPos = ply:EyePos() + ply:GetAimVector() * 150
								local vec = targetPos - ent:GetPos()
								local len = vec:Length()
								vec:Normalize()

								local vel = vec * math.min(len * 10, 1000)
								phys:SetVelocity(vel)
								phys:Wake()
							end
						else
							ply.Mode22_HeldEnt = nil
							ply:SetNW2Entity("Mode22_Held", NULL)
						end
					end
				else
					if IsValid(ply.Mode22_HeldEnt) then
						ply.Mode22_HeldEnt:SetOwner(NULL)
						ply.Mode22_HeldEnt = nil
						ply:SetNW2Entity("Mode22_Held", NULL)
					end
				end
			end
		end
	end)
end

if CLIENT then
	local EMPEndTime = 0
	local BlackoutEndTime = 0
	local StaticSound = nil

	net.Receive("MuR.Mode22.EMP", function()
		EMPEndTime = CurTime() + 8
		surface.PlaySound("ambient/energy/zap2.wav")
		timer.Create("MuR_Mode22_Shake", 0.01, 800, function()
            local ply = LocalPlayer()
            if !IsValid(ply) or !ply:Alive() or ply:GetNW2String("Class") == "Entity" then return end
            ply:SetEyeAngles(ply:EyeAngles() + Angle(math.Rand(-2,2), math.Rand(-2,2), 0))
        end)
	end)

	net.Receive("MuR.Mode22.Blackout", function()
		local dur = net.ReadUInt(8)
		BlackoutEndTime = CurTime() + dur
		surface.PlaySound("ambient/energy/power_off1.wav")
	end)

	hook.Add("SetupWorldFog", "MuR_Mode22_Fog", function()
		if MuR.GamemodeCount ~= 22 then return end
		if CurTime() < BlackoutEndTime then
			local ply = LocalPlayer()
			if ply:GetNW2String("Class") == "Entity" then
				render.FogMode(MATERIAL_FOG_LINEAR)
				render.FogStart(20)
				render.FogEnd(600)
				render.FogMaxDensity(0.5)
				render.FogColor(0, 0, 0)
			else
				render.FogMode(MATERIAL_FOG_LINEAR)
				render.FogStart(20)
				render.FogEnd(300)
				render.FogMaxDensity(1)
				render.FogColor(0, 0, 0)
			end
			return true
		end
	end)

	hook.Add("RenderScreenspaceEffects", "MuR_Mode22_Effects", function()
		if MuR.GamemodeCount ~= 22 then return end

		local ply = LocalPlayer()
		if ply:GetNW2String("Class") == "Entity" then
			local tab = {
				[ "$pp_colour_addr" ] = 0.1,
				[ "$pp_colour_addg" ] = 0,
				[ "$pp_colour_addb" ] = 0,
				[ "$pp_colour_brightness" ] = 0.05,
				[ "$pp_colour_contrast" ] = 1.1,
				[ "$pp_colour_colour" ] = 0.5,
				[ "$pp_colour_mulr" ] = 0,
				[ "$pp_colour_mulg" ] = 0,
				[ "$pp_colour_mulb" ] = 0
			}
			DrawColorModify(tab)
			DrawSharpen(1.2, 1.2)

			surface.SetDrawColor(255, 0, 0, 10)
			for i = 0, ScrH(), 4 do
				surface.DrawLine(0, i, ScrW(), i)
			end
		end

		if CurTime() < EMPEndTime then
			DrawMotionBlur(0.1, 0.8, 0.01)
			local tab = {
				[ "$pp_colour_addr" ] = 0.1,
				[ "$pp_colour_addg" ] = 0,
				[ "$pp_colour_addb" ] = 0.1,
				[ "$pp_colour_brightness" ] = 0,
				[ "$pp_colour_contrast" ] = 1,
				[ "$pp_colour_colour" ] = 1,
				[ "$pp_colour_mulr" ] = 0,
				[ "$pp_colour_mulg" ] = 0,
				[ "$pp_colour_mulb" ] = 0
			}
			DrawColorModify(tab)

			if (ply.NextEMPShake or 0) < CurTime() then
				util.ScreenShake(ply:GetPos(), 5, 5, 0.5, 500)
				ply.NextEMPShake = CurTime() + math.Rand(0.2, 0.6)
			end
		end

		if CurTime() < BlackoutEndTime then
			local tab = {
				[ "$pp_colour_addr" ] = 0,
				[ "$pp_colour_addg" ] = 0,
				[ "$pp_colour_addb" ] = 0,
				[ "$pp_colour_brightness" ] = -0.2,
				[ "$pp_colour_contrast" ] = 0.6,
				[ "$pp_colour_colour" ] = 0.1,
				[ "$pp_colour_mulr" ] = 0,
				[ "$pp_colour_mulg" ] = 0,
				[ "$pp_colour_mulb" ] = 0
			}
			if ply:GetNW2String("Class") == "Entity" then
				tab["$pp_colour_brightness"] = -0.1
				tab["$pp_colour_contrast"] = 0.8
				tab["$pp_colour_colour"] = 0.5
			end
			DrawColorModify(tab)
		end
	end)

	hook.Add("PostDrawTranslucentRenderables", "MuR_Mode22_Lasers", function()
		if MuR.GamemodeCount ~= 22 then return end

		if CurTime() < EMPEndTime then return end

		render.SetMaterial(Material("cable/redlaser"))

		local lp = LocalPlayer()

		for _, ply in player.Iterator() do
			if ply:Alive() and ply:GetNW2String("Class") == "FBIOperative" and not ply:GetNoDraw() then
				local isLocal = ply == lp
				local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
				local pos
				if bone then
					pos = ply:GetBonePosition(bone) + ply:GetForward() * 2 + ply:GetUp() * 4
				else
					pos = ply:EyePos() - ply:GetRight() * 10 - ply:GetUp() * 10
				end
				if isLocal then
					pos = ply:EyePos() - ply:GetRight() * 10 - ply:GetUp() * 10
				end

				local tr = util.TraceLine({
					start = ply:EyePos(),
					endpos = ply:EyePos() + ply:GetAimVector() * 3000,
					filter = {ply, ply:GetActiveWeapon()}
				})

				local beamAlpha = isLocal and 100 or 20
				local dotAlpha = isLocal and 255 or 40
				local beamWidth = isLocal and 2 or 1
				local dotSize = isLocal and 4 or 2

				render.DrawBeam(pos, tr.HitPos, beamWidth, 0, 1, Color(255, 0, 0, beamAlpha))
				render.DrawSprite(tr.HitPos, dotSize, dotSize, Color(255, 0, 0, dotAlpha))
			end
		end
	end)

	hook.Add("PreDrawHalos", "MuR_Mode22_Echolocation", function()
		if MuR.GamemodeCount ~= 22 then return end
		local ply = LocalPlayer()
		if ply:GetNW2String("Class") ~= "Entity" then return end

		local players = {}
		for _, v in player.Iterator() do
			if v ~= ply and v:Alive() and v:GetPos():Distance(ply:GetPos()) < 1500 then
				table.insert(players, v)
			end
		end

		local npcs = {}
		for _, v in ents.Iterator() do
			if MuR.IsAI(v) and v:GetPos():Distance(ply:GetPos()) < 1500 then
				table.insert(npcs, v)
			end
		end

		halo.Add(players, Color(255, 0, 0), 2, 2, 1, true, true)
		halo.Add(npcs, Color(0, 255, 0), 2, 2, 1, true, true)
	end)

	hook.Add("PrePlayerDraw", "MuR_Mode22_Camouflage", function(ply)
		if MuR.GamemodeCount ~= 22 then return end
		if ply:GetNW2String("Class") ~= "Entity" then return end

		local localPly = LocalPlayer()
		if localPly == ply then

			render.SetBlend(0.4)
			return
		end

		local dist = localPly:GetPos():Distance(ply:GetPos())
		local alpha = 0

		if dist < 250 then
			alpha = math.Clamp((250 - dist) / 250, 0, 0.3)
		end

		if alpha <= 0 then
			return true
		end

		render.SetBlend(alpha)
	end)

	hook.Add("PostPlayerDraw", "MuR_Mode22_Camouflage_Post", function(ply)
		if MuR.GamemodeCount ~= 22 then return end
		if ply:GetNW2String("Class") == "Entity" then
			render.SetBlend(1)
		end
	end)

	hook.Add("Think", "MuR_Mode22_Interference", function()
		if MuR.GamemodeCount ~= 22 then
			if StaticSound then StaticSound:Stop() StaticSound = nil end
			return
		end
		local ply = LocalPlayer()
		if ply:GetNW2String("Class") == "Entity" then
			if StaticSound then StaticSound:Stop() StaticSound = nil end

			local dlight = DynamicLight(ply:EntIndex())
			if ( dlight ) then
				dlight.pos = ply:GetPos()
				dlight.r = 255
				dlight.g = 0
				dlight.b = 0
				dlight.brightness = 2
				dlight.Decay = 1000
				dlight.Size = 256
				dlight.DieTime = CurTime() + 1
			end

			local tr = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * 2000, filter = ply})
			if tr.Hit then
				local dlight2 = DynamicLight(ply:EntIndex() + 1)
				if ( dlight2 ) then
					dlight2.pos = tr.HitPos
					dlight2.r = 255
					dlight2.g = 0
					dlight2.b = 0
					dlight2.brightness = 1
					dlight2.Decay = 1000
					dlight2.Size = 128
					dlight2.DieTime = CurTime() + 1
				end
			end
			return
		end

		if CurTime() < EMPEndTime then
			if ply:FlashlightIsOn() then ply:Flashlight(false) end
		end
	end)

	hook.Add("HUDPaint", "MuR_Mode22_DangerHUD", function()
		if MuR.GamemodeCount ~= 22 then return end
		local ply = LocalPlayer()
		if ply:GetNW2String("Class") == "Entity" then return end
		if not ply:Alive() then return end

		local entity = nil
		for _, v in player.Iterator() do
			if v:GetNW2String("Class") == "Entity" then entity = v break end
		end

		if IsValid(entity) then
			local dist = ply:GetPos():Distance(entity:GetPos())
			if dist < 800 then
				local bars = math.Clamp(8 - math.floor(dist / 100), 0, 8)
				local w, h = ScrW(), ScrH()
				local bw, bh = 40, 10
				local startX = w/2 - (bw * 4) - 15
				local startY = h - 150

				draw.SimpleText(MuR.Language["mode22_danger"], "MuR_Font2", w/2, startY - 30, Color(255, 0, 0, 150 + math.sin(CurTime()*10)*50), TEXT_ALIGN_CENTER)

				for i = 1, 8 do
					local col = Color(50, 0, 0, 100)
					if i <= bars then
						col = Color(255, 0, 0, 200)
					end
					surface.SetDrawColor(col)
					surface.DrawRect(startX + (i-1)*(bw+5), startY, bw, bh)
				end

				if (ply.NextDangerBeep or 0) < CurTime() then
					local pitch = 100 + (bars * 10)
					ply:EmitSound("buttons/blip1.wav", 60, pitch)
					ply.NextDangerBeep = CurTime() + (dist/800) * 1.0 + 0.2
				end
			end
		end
	end)

	hook.Add("HUDPaint", "MuR_Mode22_HUD", function()
		if MuR.GamemodeCount ~= 22 or !MuR.DrawHUD then return end
		local ply = LocalPlayer()
		if ply:GetNW2String("Class") ~= "Entity" then return end

		local w, h = ScrW(), ScrH()
		local x, y = w - 320, h - 380

		surface.SetDrawColor(20, 0, 0, 180)
		surface.DrawRect(x - 15, y - 15, 300, 320)

		surface.SetDrawColor(255, 0, 0, 200)
		local l = 20
		surface.DrawRect(x - 15, y - 15, l, 2)
		surface.DrawRect(x - 15, y - 15, 2, l)

		surface.DrawRect(x + 285 - l, y - 15, l, 2)
		surface.DrawRect(x + 283, y - 15, 2, l)

		surface.DrawRect(x - 15, y + 305 - 2, l, 2)
		surface.DrawRect(x - 15, y + 305 - l, 2, l)

		surface.DrawRect(x + 285 - l, y + 305 - 2, l, 2)
		surface.DrawRect(x + 283, y + 305 - l, 2, l)

		draw.SimpleText(MuR.Language["mode22_abilities_title"], "MuR_Font2", x + 135, y - 40, Color(255, 0, 0), TEXT_ALIGN_CENTER)

		local abilities = {
			{id = "summon_vermin", name = MuR.Language["mode22_summon_vermin"], cd = 20},
			{id = "summon_elite", name = MuR.Language["mode22_summon_elite"], cd = 60},
			{id = "emp", name = MuR.Language["mode22_emp"], cd = 60},
			{id = "blackout", name = MuR.Language["mode22_blackout"], cd = 120},
			{id = "teleport", name = MuR.Language["mode22_teleport"], cd = 15},
			{id = "power_strike", name = MuR.Language["mode22_power_strike"], cd = 5}
		}

		for i, ab in ipairs(abilities) do
			local ay = y + (i - 1) * 48
			local cd_end = ply:GetNW2Float("MuR.Mode22.CD." .. ab.id, 0)
			local remaining = math.max(0, cd_end - CurTime())
			local ratio = math.Clamp(1 - (remaining / ab.cd), 0, 1)

			local col = remaining > 0 and Color(200, 200, 200, 150) or Color(255, 255, 255, 255)
			draw.SimpleText(ab.name, "MuR_Font1", x, ay, col, TEXT_ALIGN_LEFT)

			surface.SetDrawColor(40, 40, 40, 200)
			surface.DrawRect(x, ay + 22, 240, 6)

			if remaining > 0 then
				surface.SetDrawColor(255, 0, 0, 200)
				surface.DrawRect(x, ay + 22, 240 * ratio, 6)

				if math.random() > 0.9 then
					draw.SimpleText(math.ceil(remaining) .. "s", "MuR_Font1", x + 245 + math.random(-2,2), ay + 16, Color(255, 0, 0, 100), TEXT_ALIGN_LEFT)
				else
					draw.SimpleText(math.ceil(remaining) .. "s", "MuR_Font1", x + 245, ay + 16, Color(255, 0, 0), TEXT_ALIGN_LEFT)
				end
			else
				surface.SetDrawColor(0, 255, 0, 200)
				surface.DrawRect(x, ay + 22, 240, 6)
				draw.SimpleText("+", "MuR_Font1", x + 245, ay + 16, Color(0, 255, 0), TEXT_ALIGN_LEFT)
			end
		end

		if ply.Mode22_HoldStart_G then
			local progress = math.Clamp((CurTime() - ply.Mode22_HoldStart_G) / 3.0, 0, 1)
			surface.SetDrawColor(0, 0, 0, 200)
			surface.DrawRect(w/2 - 100, h/2 + 100, 200, 20)
			surface.SetDrawColor(0, 255, 255, 200)
			surface.DrawRect(w/2 - 100, h/2 + 100, 200 * progress, 20)
			draw.SimpleText(MuR.Language["mode22_emp_charging"], "MuR_Font2", w/2, h/2 + 75, Color(0, 255, 255), TEXT_ALIGN_CENTER)
		end

		if ply.Mode22_HoldStart_F then
			local progress = math.Clamp((CurTime() - ply.Mode22_HoldStart_F) / 3.0, 0, 1)
			surface.SetDrawColor(0, 0, 0, 200)
			surface.DrawRect(w/2 - 100, h/2 + 130, 200, 20)
			surface.SetDrawColor(255, 0, 0, 200)
			surface.DrawRect(w/2 - 100, h/2 + 130, 200 * progress, 20)
			draw.SimpleText(MuR.Language["mode22_blackout_starting"], "MuR_Font2", w/2, h/2 + 155, Color(255, 0, 0), TEXT_ALIGN_CENTER)
		end

		local tr = util.TraceLine({
			start = ply:EyePos(),
			endpos = ply:EyePos() + ply:GetAimVector() * 2000,
			filter = ply
		})

		local activeWep = ply:GetActiveWeapon()
		if IsValid(activeWep) and activeWep:GetClass() == "mur_entity_abilities" then
			draw.SimpleText(MuR.Language["mode22_abilities_active"], "MuR_Font2", w/2, h - 100, Color(255, 0, 0, 200), TEXT_ALIGN_CENTER)
		end

		if IsValid(tr.Entity) and tr.Entity:IsPlayer() then
			local ent = tr.Entity
			local tx, ty = w/2 + 20, h/2 - 20
			draw.SimpleText(MuR.Language["mode22_target"] .. ent:Nick(), "MuR_Font2", tx, ty, Color(255, 0, 0), TEXT_ALIGN_LEFT)
			draw.SimpleText(MuR.Language["mode22_class"] .. ent:GetNW2String("Class", "Unknown"), "MuR_Font1", tx, ty + 25, Color(255, 0, 0), TEXT_ALIGN_LEFT)
			draw.SimpleText(MuR.Language["mode22_health"] .. ent:Health(), "MuR_Font1", tx, ty + 45, Color(255, 0, 0), TEXT_ALIGN_LEFT)

			draw.SimpleText(MuR.Language["mode22_strike_hint"], "MuR_Font1", tx, ty + 70, Color(255, 255, 255), TEXT_ALIGN_LEFT)

			surface.SetDrawColor(255, 0, 0, 200)
			surface.DrawLine(w/2 - 10, h/2 - 10, w/2 - 5, h/2 - 10)
			surface.DrawLine(w/2 - 10, h/2 - 10, w/2 - 10, h/2 - 5)

			surface.DrawLine(w/2 + 10, h/2 - 10, w/2 + 5, h/2 - 10)
			surface.DrawLine(w/2 + 10, h/2 - 10, w/2 + 10, h/2 - 5)

			surface.DrawLine(w/2 - 10, h/2 + 10, w/2 - 5, h/2 + 10)
			surface.DrawLine(w/2 - 10, h/2 + 10, w/2 - 10, h/2 + 5)

			surface.DrawLine(w/2 + 10, h/2 + 10, w/2 + 5, h/2 + 10)
			surface.DrawLine(w/2 + 10, h/2 + 10, w/2 + 10, h/2 + 5)
		elseif IsValid(tr.Entity) then
			local ent = tr.Entity
			local tx, ty = w/2 + 20, h/2 - 20
			local class = ent:GetClass()

			if class == "prop_door_rotating" or class == "func_door" then
				draw.SimpleText(MuR.Language["mode22_object_door"], "MuR_Font2", tx, ty, Color(255, 0, 0), TEXT_ALIGN_LEFT)
				draw.SimpleText(MuR.Language["mode22_door_close"], "MuR_Font1", tx, ty + 25, Color(255, 255, 255), TEXT_ALIGN_LEFT)
				draw.SimpleText(MuR.Language["mode22_door_open"], "MuR_Font1", tx, ty + 45, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			elseif class == "func_button" or class == "func_rot_button" then
				draw.SimpleText(MuR.Language["mode22_object_button"], "MuR_Font2", tx, ty, Color(255, 0, 0), TEXT_ALIGN_LEFT)
				draw.SimpleText(MuR.Language["mode22_press_lmb"], "MuR_Font1", tx, ty + 25, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			elseif class == "prop_physics" then
				draw.SimpleText(MuR.Language["mode22_object_item"], "MuR_Font2", tx, ty, Color(255, 0, 0), TEXT_ALIGN_LEFT)
				draw.SimpleText(MuR.Language["mode22_grab_throw"], "MuR_Font1", tx, ty + 25, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			elseif class == "prop_ragdoll" then
				draw.SimpleText(MuR.Language["mode22_object_body"], "MuR_Font2", tx, ty, Color(255, 0, 0), TEXT_ALIGN_LEFT)
				draw.SimpleText(MuR.Language["mode22_grab_throw"], "MuR_Font1", tx, ty + 25, Color(255, 255, 255), TEXT_ALIGN_LEFT)
			end
		end
	end)

	hook.Add("PlayerButtonDown", "MuR_Mode22_Input_CL", function(ply, button)
		if MuR.GamemodeCount ~= 22 then return end
		if ply ~= LocalPlayer() then return end
		if ply:GetNW2String("Class") ~= "Entity" then return end

		if button == KEY_G then
			ply.Mode22_HoldStart_G = CurTime()
		elseif button == KEY_F then
			ply.Mode22_HoldStart_F = CurTime()
		end
	end)

	hook.Add("PlayerButtonUp", "MuR_Mode22_InputUp_CL", function(ply, button)
		if MuR.GamemodeCount ~= 22 then return end
		if ply ~= LocalPlayer() then return end

		if button == KEY_G then
			ply.Mode22_HoldStart_G = nil
		elseif button == KEY_F then
			ply.Mode22_HoldStart_F = nil
		end
	end)
end
