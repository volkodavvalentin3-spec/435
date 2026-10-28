MuR.RegisterMode(16, {
	name = "Storm",
	chance = 20,
	need_players = 2,
	kteam = "Traitor",
	dteam = "Hunter",
	iteam = "Innocent",
	disables_police = true,
	roles = MuR.DefaultRoles,
	OnModeStarted = function(mode)
		RunConsoleCommand("sv_skyname", "sky_borealis01")
		net.Start("MuR.Storm.Start")
		net.Broadcast()
		MuR.StormDisabledEntities = {}
		MuR.TornadoActive = false
		MuR.TornadoProps = {}
		MuR.StormPhysCache = {}
		MuR.StormPhysList = {}
		MuR.StormPhysIndex = 1
		MuR.StormStartedAt = CurTime()
		MuR.StormWindDirection = Vector(math.random(-100, 100), math.random(-100, 100), 0):GetNormalized() * math.random(80, 140)
		net.Start("MuR.Storm.WindDirection")
		net.WriteVector(MuR.StormWindDirection)
		net.Broadcast()

		local function IsExposedWind(pos, ent)
			local t1 = util.TraceLine({start = pos, endpos = pos + Vector(0, 0, 2000), filter = ent, mask = MASK_SOLID_BRUSHONLY})
			if t1.HitSky or t1.Fraction > 0.8 then return true end
			for i = 1, 12 do
				local a = (i - 1) * 30
				local dir = Vector(math.cos(math.rad(a)), math.sin(math.rad(a)), 0)
				local t2 = util.TraceLine({start = pos + Vector(0, 0, 40), endpos = pos + dir * 4000, filter = ent, mask = MASK_SOLID})
				if t2.HitSky then return true end
			end
			return false
		end
		local function IsExposedTornado(pos, ent)
			local t1 = util.TraceLine({start = pos, endpos = pos + Vector(0, 0, 2200), filter = ent, mask = MASK_SOLID_BRUSHONLY})
			if t1.HitSky or t1.Fraction > 0.75 then return true end
			for i = 1, 12 do
				local a = (i - 1) * 30
				local dir = Vector(math.cos(math.rad(a)), math.sin(math.rad(a)), 0)
				local t2 = util.TraceLine({start = pos + Vector(0, 0, 40), endpos = pos + dir * 5000, filter = ent, mask = MASK_SOLID})
				if t2.HitSky then return true end
				if t2.Hit and t2.HitTexture then
					local n = string.lower(t2.HitTexture)
					if string.find(n, "glass") or string.find(n, "window") then return true end
				end
			end
			return false
		end

		timer.Create("Storm_PhysCache", 3, 0, function()
			if not MuR.GameStarted or MuR.Gamemode ~= 16 then return end
			local list = {}
			local function addAll(class)
				for _, ent in ipairs(ents.FindByClass(class)) do if IsValid(ent) then table.insert(list, ent) end end
			end
			addAll("prop_physics*")
			addAll("prop_ragdoll")
			addAll("weapon_*")
			addAll("item_*")
			addAll("gmod_*")
			MuR.StormPhysList = list
			MuR.StormPhysIndex = 1
		end)

		timer.Simple(30, function()
			if not MuR.GameStarted or MuR.Gamemode ~= 16 then return end
			timer.Create("Storm_WindDirection", 2.5, 0, function()
				if not MuR.GameStarted or MuR.Gamemode ~= 16 then return end
				if math.random(1, 5) == 1 then
					MuR.StormWindDirection = MuR.StormWindDirection:GetNormalized() * math.random(80, 160)
					MuR.StormWindDirection:Rotate(Angle(0, math.random(-35, 35), 0))
					net.Start("MuR.Storm.WindDirection")
					net.WriteVector(MuR.StormWindDirection)
					net.Broadcast()
				end
			end)

			timer.Create("Storm_WindOnEntities", 0.1, 0, function()
				if not MuR.GameStarted or MuR.Gamemode ~= 16 then
					timer.Remove("Storm_WindOnEntities")
					return
				end
				local mult = MuR.TornadoActive and 10 or 2
				if #MuR.StormPhysList == 0 then return end
				local batch = 60
				for i = 1, batch do
					if MuR.StormPhysIndex > #MuR.StormPhysList then MuR.StormPhysIndex = 1 break end
					local ent = MuR.StormPhysList[MuR.StormPhysIndex]
					MuR.StormPhysIndex = MuR.StormPhysIndex + 1
					if not IsValid(ent) then continue end
					if ent:IsPlayer() then continue end
					local cls = ent:GetClass()
					if string.find(cls, "npc_") then continue end
					local phys = ent:GetPhysicsObject()
					if not IsValid(phys) then continue end
					if phys:GetMass() >= 3000 then continue end
					local pos = ent:GetPos()
					if not IsExposedWind(pos, ent) then continue end
					local force = MuR.StormWindDirection * 0.6 * mult + VectorRand() * 8
					if cls == "prop_ragdoll" then
						for i = 0, math.min(ent:GetPhysicsObjectCount() - 1, 4) do
							local bone = ent:GetPhysicsObjectNum(i)
							if IsValid(bone) then bone:AddVelocity(force * 4) end
						end
					else
						phys:AddVelocity(force)
						if phys:GetMass() < 2000 then phys:AddAngleVelocity(VectorRand() * 6) end
					end
				end
			end)

			timer.Create("Storm_WindOnPlayers", 0.2, 0, function()
				if not MuR.GameStarted or MuR.Gamemode ~= 16 then timer.Remove("Storm_WindOnPlayers") return end
				local mult = MuR.TornadoActive and 2 or 1
				for _, ply in player.Iterator() do
					if not ply:Alive() or ply:IsFlagSet(FL_FROZEN) then continue end
					local p = ply:GetPos()
					local t1 = util.TraceLine({start = p, endpos = p + Vector(0, 0, 2000), filter = ply, mask = MASK_SOLID_BRUSHONLY})
					local outside = t1.HitSky or t1.Fraction > 0.8
					local nearOpen = 0
					for i = 1, 12 do
						local a = (i - 1) * 30
						local dir = Vector(math.cos(math.rad(a)), math.sin(math.rad(a)), 0)
						local t2 = util.TraceLine({start = p + Vector(0, 0, 40), endpos = p + dir * 2500, filter = ply, mask = MASK_SOLID})
						if t2.HitSky then nearOpen = nearOpen + 1 end
					end
					if outside or nearOpen > 0 then
						local base = outside and 0.45 or math.min(0.15 * nearOpen, 0.45)
						local f = MuR.StormWindDirection * base * mult + VectorRand() * 3 * mult
						local vel = ply:GetVelocity()
						ply:SetVelocity(f - vel * 0.01)
					end
				end
			end)

			timer.Create("Storm_Thunder", math.random(15, 35), 0, function()
				if not MuR.GameStarted or MuR.Gamemode ~= 16 then
					timer.Remove("Storm_Thunder")
					return
				end
				local thunderSounds = {
					"ambient/weather/thunder1.wav",
					"ambient/weather/thunder2.wav",
					"ambient/weather/thunder3.wav",
					"ambient/weather/thunder4.wav",
					"ambient/weather/thunder5.wav",
					"ambient/weather/thunder6.wav"
				}
				local s = table.Random(thunderSounds)
				for _, ply in player.Iterator() do
					ply:EmitSound(s, 90, math.random(90, 110), 0.8)
				end

				local ply = table.Random(player.GetAll())
				local base = IsValid(ply) and ply:GetPos() or Vector(0, 0, 0)
				local offset = VectorRand() * math.random(200, 900)
				local start = base + offset + Vector(0, 0, 1500)
				local tr = util.TraceLine({start = start, endpos = start - Vector(0, 0, 4000), mask = MASK_SOLID_BRUSHONLY})
				local hitPos = tr.HitPos
				local eff = EffectData()
				eff:SetOrigin(hitPos)
				eff:SetNormal(Vector(0, 0, 1))
				eff:SetMagnitude(5)
				eff:SetScale(2)
				util.Effect("Sparks", eff, true, true)
				util.Effect("StunstickImpact", eff, true, true)

				local lightsOut = math.random(1, 2) == 1
				local outageDuration = math.random(10, 45)

				net.Start("MuR.Storm.Thunder")
				net.WriteBool(true)
				net.WriteVector(hitPos)
				net.WriteUInt(300, 12)
				net.WriteBool(lightsOut)
				net.WriteUInt(outageDuration, 8)
				net.Broadcast()

				local radius = 300
				for _, p in player.Iterator() do
					if not p:Alive() then continue end
					if p:GetPos():Distance(hitPos) <= radius and IsExposedWind(p:GetPos(), p) then
						p:Ignite(math.random(2, 5), 0)
						p:TakeDamage(math.random(15, 35), game.GetWorld(), game.GetWorld())
					end
				end

				local lights = {}
				for _, ent in ipairs(ents.FindByClass("light")) do table.insert(lights, ent) end
				for _, ent in ipairs(ents.FindByClass("light_spot")) do table.insert(lights, ent) end
				for _, ent in ipairs(ents.FindByClass("light_dynamic")) do table.insert(lights, ent) end
				for _, e in ipairs(lights) do
					if IsValid(e) and e:GetPos():Distance(hitPos) < 1200 then
						e:Fire("TurnOff")
						timer.Simple(0.08, function() if IsValid(e) then e:Fire("TurnOn") end end)
						timer.Simple(0.16, function() if IsValid(e) then e:Fire("TurnOff") end end)
						timer.Simple(0.22, function() if IsValid(e) then e:Fire("TurnOn") end end)
					end
				end

				if lightsOut then
					local toToggle = {}
					for _, e in ipairs(lights) do if IsValid(e) and e:GetPos():Distance(hitPos) < 1500 then table.insert(toToggle, e) end end
					for _, e in ipairs(ents.FindByClass("func_door")) do if IsValid(e) and e:GetPos():Distance(hitPos) < 1500 then table.insert(toToggle, e) end end
					for _, e in ipairs(ents.FindByClass("trigger_*")) do if IsValid(e) and e:GetPos():Distance(hitPos) < 1500 then table.insert(toToggle, e) end end
					for _, e in ipairs(ents.FindByClass("func_button")) do if IsValid(e) and e:GetPos():Distance(hitPos) < 1500 then table.insert(toToggle, e) end end

					for _, e in ipairs(toToggle) do
						if not IsValid(e) then continue end
						if not MuR.StormDisabledEntities[e] then MuR.StormDisabledEntities[e] = {class = e:GetClass()} end
						local cls = e:GetClass()
						if cls == "func_door" then e:Fire("Lock") end
						if string.StartWith(cls, "trigger_") then e:Fire("Disable") end
						if cls == "func_button" then e.StormOriginalUse = e.StormOriginalUse or e.Use e.Use = function() end end
						if cls == "light" or cls == "light_spot" or cls == "light_dynamic" then e:Fire("TurnOff") end
					end
					timer.Simple(outageDuration, function()
						for _, e in ipairs(toToggle) do
							if not IsValid(e) then continue end
							local cls = e:GetClass()
							if cls == "func_door" then e:Fire("Unlock") end
							if string.StartWith(cls, "trigger_") then e:Fire("Enable") end
							if cls == "func_button" and e.StormOriginalUse then e.Use = e.StormOriginalUse e.StormOriginalUse = nil end
							if cls == "light" or cls == "light_spot" or cls == "light_dynamic" then e:Fire("TurnOn") end
							MuR.StormDisabledEntities[e] = nil
						end
					end)
				end

				local brk = ents.FindInSphere(hitPos, 600)
				for _, e in ipairs(brk) do
					if not IsValid(e) then continue end
					local c = e:GetClass()
					if c == "func_breakable" then e:Fire("Break") end
					if c == "func_breakable_surf" then e:Fire("Shatter", "0.5 0.5 1024") end
				end

				timer.Adjust("Storm_Thunder", math.random(15, 35))
			end)

			timer.Create("Storm_TornadoScheduler", math.random(120, 240), 0, function()
				if not MuR.GameStarted or MuR.Gamemode ~= 16 or MuR.TornadoActive then return end
				local center
				if MuR.AI_Nodes and #MuR.AI_Nodes > 0 then
					local cands = {}
					for i = 1, #MuR.AI_Nodes do
						local pos = MuR.AI_Nodes[i].pos
						local t = util.TraceLine({start = pos, endpos = pos + Vector(0, 0, 2500), mask = MASK_SOLID_BRUSHONLY})
						if t.HitSky or t.Fraction > 0.9 then table.insert(cands, pos) end
					end
					if #cands > 0 then center = cands[math.random(1, #cands)] end
				end
				if not center then
					for _, s in ipairs(ents.FindByClass("info_player_*")) do
						local t = util.TraceLine({start = s:GetPos(), endpos = s:GetPos() + Vector(0, 0, 2500), filter = s, mask = MASK_SOLID_BRUSHONLY})
						if t.HitSky or t.Fraction > 0.9 then center = s:GetPos() break end
					end
				end
				if not center then center = Vector(0, 0, 0) end
				local top = center + Vector(0, 0, 1000)
				local down = util.TraceLine({start = top, endpos = center - Vector(0, 0, 5000), mask = MASK_SOLID_BRUSHONLY})
				if down.Hit then center = Vector(center.x, center.y, down.HitPos.z + 10) end
				MuR.TornadoCenter = center
				MuR.TornadoTarget = center
				for _, ply in player.Iterator() do
					ply:EmitSound("ambient/alarms/apc_alarm_loop1.wav", 100, 100, 1)
					ply:SendLua([[chat.AddText(Color(255,0,0),"[A.R.T. NEWS] ",Color(255,255,255),"HURRICANE WILL ARRIVE SOON! SEEK SHELTER IMMEDIATLY!")]])
				end
				timer.Simple(15, function()
					if not MuR.GameStarted or MuR.Gamemode ~= 16 then return end
					for _, ply in player.Iterator() do ply:StopSound("ambient/alarms/apc_alarm_loop1.wav") end
					MuR.TornadoActive = true
					MuR.TornadoProps = {}
					MuR.TornadoDisabledButtons = {}
					local R = 900
					game.GetWorld():SetNW2Bool("MuR_TornadoActive", true)
					game.GetWorld():SetNW2Vector("MuR_TornadoCenter", MuR.TornadoCenter)
					for _, b in ipairs(ents.FindByClass("func_button")) do
						if IsValid(b) and b:GetPos():Distance(MuR.TornadoCenter) < R + 200 then
							if not b.StormOriginalUse then b.StormOriginalUse = b.Use end
							b.Use = function() end
							table.insert(MuR.TornadoDisabledButtons, b)
						end
					end
					timer.Create("Tornado_Roar", 1, 0, function()
						if not MuR.TornadoActive then timer.Remove("Tornado_Roar") return end
						for _, ply in player.Iterator() do
							local d = ply:GetPos():Distance(MuR.TornadoCenter)
							if d < 1000 then
								local vol = math.Clamp(100 - (d / 15), 40, 100)
								local pit = math.Clamp(75 - (d / 40), 40, 75)
								ply:EmitSound("ambient/wind/wind_rooftop1.wav", vol, pit, 0.9)
								if d < 400 then util.ScreenShake(ply:GetPos(), 5, 5, 1, 600) end
							end
						end
					end)
					timer.Create("Tornado_Physics", 0.1, 600, function()
						if not MuR.GameStarted or MuR.Gamemode ~= 16 then timer.Remove("Tornado_Physics") timer.Remove("Tornado_Roar") MuR.TornadoActive = false game.GetWorld():SetNW2Bool("MuR_TornadoActive", false) for _, ply in player.Iterator() do ply:StopSound("ambient/wind/wind_rooftop1.wav") end return end

						if not MuR.TornadoTarget or MuR.TornadoCenter:Distance(MuR.TornadoTarget) < 200 then
							if MuR.AI_Nodes and #MuR.AI_Nodes > 0 then
								MuR.TornadoTarget = MuR.AI_Nodes[math.random(1, #MuR.AI_Nodes)].pos
							else
								MuR.TornadoTarget = Vector(math.random(-2000, 2000), math.random(-2000, 2000), MuR.TornadoCenter.z)
							end
						end
						local dir = (MuR.TornadoTarget - MuR.TornadoCenter):GetNormalized()
						MuR.TornadoCenter = MuR.TornadoCenter + dir * 35
						game.GetWorld():SetNW2Vector("MuR_TornadoCenter", MuR.TornadoCenter)

						local R = 2400
						local H = 1600
						local entsIn = ents.FindInSphere(MuR.TornadoCenter, R)
						for _, ent in ipairs(entsIn) do
							if not IsValid(ent) then continue end
							local phys = ent:GetPhysicsObject()
							if not IsValid(phys) then continue end
							if phys:GetMass() >= 4000 then continue end
							local pos = ent:WorldSpaceCenter()
							local exposed = IsExposedTornado(pos, ent)
							if not exposed then continue end
							local dist = pos:Distance(MuR.TornadoCenter)
							local fm = math.Clamp(1 - (dist / R), 0, 1)
							if not MuR.TornadoProps[ent] then MuR.TornadoProps[ent] = {start = CurTime(), angle = math.random(0, 360), radius = dist} end
							local dt = CurTime() - MuR.TornadoProps[ent].start
			    			local ang = (MuR.TornadoProps[ent].angle + dt * 195) % 360
							local rad = math.max(30, MuR.TornadoProps[ent].radius - dt * 8)
			    			local z = math.min(H, dt * 80)
							local target = MuR.TornadoCenter + Vector(math.cos(math.rad(ang)) * rad, math.sin(math.rad(ang)) * rad, z)
							local dir = (target - pos):GetNormalized()
			    			local base = 2400
			    			local m = math.Clamp(120 / math.max(phys:GetMass(), 1), 0.15, 1)
			    			local v = dir * base * fm * m
			    			phys:AddVelocity(v * 0.14)
			    			phys:AddAngleVelocity(VectorRand() * 160 * m)
							if ent:GetClass() == "prop_ragdoll" then
								for i = 0, math.min(ent:GetPhysicsObjectCount() - 1, 4) do
									local bone = ent:GetPhysicsObjectNum(i)
			    					if IsValid(bone) then bone:AddVelocity(v * 0.4) end
								end
							end
						end
						if math.random(1, 3) == 1 then
						for _, g in ipairs(ents.FindByClass("func_breakable_surf")) do
							if not IsValid(g) then continue end
							if g:GetPos():Distance(MuR.TornadoCenter) < R and math.random(1, 2) == 1 then g:Fire("Shatter", "0.5 0.5 1024") end
						end
						for _, b in ipairs(ents.FindByClass("func_breakable")) do
								if not IsValid(b) then continue end
								if b:GetPos():Distance(MuR.TornadoCenter) < R and math.random(1, 3) == 1 then b:Fire("Break") end
							end
						end
						local doors = ents.FindInSphere(MuR.TornadoCenter, R)
						for _, d in ipairs(doors) do
							if not IsValid(d) then continue end
							local cls = d:GetClass()
							if cls == "prop_door_rotating" then
								d:TakeDamage(math.random(12, 28), game.GetWorld(), game.GetWorld())
							elseif cls == "func_door" then
								MuR.TornadoDoorHP = MuR.TornadoDoorHP or {}
								if not MuR.TornadoDoorHP[d] then MuR.TornadoDoorHP[d] = math.random(160, 260) end
								MuR.TornadoDoorHP[d] = MuR.TornadoDoorHP[d] - math.random(6, 14)
								if MuR.TornadoDoorHP[d] <= 0 then
									d:Fire("Unlock")
									d:Fire("Open")
									d:EmitSound("Wood_Plank.Break", 100, 90)
									local mdl = d:GetModel()
									local pos = d:GetPos()
									local ang = d:GetAngles()
									local skin = d:GetSkin()
									local debris = ents.Create("prop_physics")
									if IsValid(debris) then
										debris:SetModel(mdl)
										debris:SetPos(pos)
										debris:SetAngles(ang)
										debris:SetSkin(skin)
										debris:Spawn()
										local phys = debris:GetPhysicsObject()
										if IsValid(phys) then
											phys:SetVelocity(VectorRand() * 500 + Vector(0,0,200))
											phys:AddAngleVelocity(VectorRand() * 200)
										end
										SafeRemoveEntity(d)
									end
									MuR.TornadoDoorHP[d] = nil
								end
							end
						end
						for _, ply in player.Iterator() do
							if not ply:Alive() then continue end
							local d = ply:GetPos():Distance2D(MuR.TornadoCenter)
							if d < R then
								if IsExposedTornado(ply:GetPos(), ply) then
									local angC = (MuR.TornadoCenter - ply:GetPos()):Angle().y
									local tanA = angC + 90
									local tanDir = Vector(math.cos(math.rad(tanA)), math.sin(math.rad(tanA)), 0)
									local fm = math.Clamp(1 - (d / R), 0, 1)
									local pull = (MuR.TornadoCenter - ply:GetPos()):GetNormalized() * 180
									local spin = tanDir * 220
									local lift = Vector(0, 0, 120)
									local total = (pull + spin + lift) * fm
									ply:SetVelocity(total)
									ply:ViewPunch(Angle(math.random(-2, 2) * fm, math.random(-2, 2) * fm, 0))
									if d < 200 and math.random(1, 8) == 1 then ply:TakeDamage(math.random(6, 18), game.GetWorld(), game.GetWorld()) end
									local st = ply:GetNW2Float("Stamina", 100)
									ply:SetNW2Float("Stamina", math.max(0, st - 1.8 * fm))
								end
							end
						end
					end)
					timer.Simple(60, function()
						MuR.TornadoActive = false
						MuR.TornadoProps = {}
						if MuR.TornadoDisabledButtons then
							for _, b in ipairs(MuR.TornadoDisabledButtons) do
								if IsValid(b) and b.StormOriginalUse then b.Use = b.StormOriginalUse b.StormOriginalUse = nil end
							end
							MuR.TornadoDisabledButtons = {}
						end
						timer.Remove("Tornado_Physics")
						timer.Remove("Tornado_Roar")
						game.GetWorld():SetNW2Bool("MuR_TornadoActive", false)
						for _, ply in player.Iterator() do ply:StopSound("ambient/wind/wind_rooftop1.wav") end
						for _, ply in player.Iterator() do
							ply:SendLua([[chat.AddText(Color(0,255,0),"[A.R.T. NEWS] ",Color(255,255,255),"HURRICANE HAS PASSED. BE CAREFUL.")]])
						end
					end)
				end)
				timer.Adjust("Storm_TornadoScheduler", math.random(160, 300))
			end)

			timer.Create("Storm_AntiFire", 1.5, 0, function()
				if not MuR.GameStarted or MuR.Gamemode ~= 16 then return end
				if math.random(1, 8) ~= 1 then return end
			for _, fire in ipairs(ents.FindByClass("vfire")) do
					if IsValid(fire) and IsExposedWind(fire:GetPos(), fire) then fire:Remove() end
				end
			end)
		end)
	end,
	OnModeEnded = function(mode)
		timer.Remove("Storm_PhysCache")
		timer.Remove("Storm_WindDirection")
		timer.Remove("Storm_WindOnEntities")
		timer.Remove("Storm_Thunder")
		timer.Remove("Storm_TornadoScheduler")
		timer.Remove("Tornado_Physics")
		timer.Remove("Tornado_Roar")
		timer.Remove("Storm_AntiFire")
		MuR.TornadoActive = false
		MuR.TornadoProps = {}
		MuR.StormPhysList = {}
		MuR.StormPhysIndex = 1
		game.GetWorld():SetNW2Bool("MuR_TornadoActive", false)
		if MuR.TornadoDisabledButtons then
			for _, b in ipairs(MuR.TornadoDisabledButtons) do
				if IsValid(b) and b.StormOriginalUse then b.Use = b.StormOriginalUse b.StormOriginalUse = nil end
			end
			MuR.TornadoDisabledButtons = {}
		end
		RunConsoleCommand("sv_skyname", MuR.DefaultSkyname)
		if MuR.StormDisabledEntities then
			for ent, data in pairs(MuR.StormDisabledEntities) do
				if IsValid(ent) then
					local cls = ent:GetClass()
					if cls == "func_door" then ent:Fire("Unlock") end
					if string.StartWith(cls, "trigger_") then ent:Fire("Enable") end
					if cls == "func_button" and ent.StormOriginalUse then ent.Use = ent.StormOriginalUse ent.StormOriginalUse = nil end
					if cls == "light" or cls == "light_spot" or cls == "light_dynamic" then ent:Fire("TurnOn") end
				end
			end
			MuR.StormDisabledEntities = {}
		end
		for _, ply in player.Iterator() do
			ply:StopSound("ambient/alarms/apc_alarm_loop1.wav")
			ply:StopSound("ambient/wind/wind_rooftop1.wav")
		end
		net.Start("MuR.Storm.End")
		net.Broadcast()
	end
})
