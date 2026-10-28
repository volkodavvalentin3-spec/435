local PARTICLE = true
local RED_DECAL_SCALE = 1
local YELLOW_DECAL_SCALE = 1.25
local DRIP_SCALE = 0.75
local DROP_CHANCE = 5
local SPLAT_BACK_CHANCE = 6
local IMPACT_SOUND = 1
local IMPACT_PARTICLE = 0
local SENSITIVITY = 100
local COUNT = 5
local FORCE_MULT = 1.25
local STAIN_ENTS = true
local GORE_KIND = "impact"
local MAX_STREAM_PARTICLES = 20

local function SpendRender(particleCost, decalCost)
	return MuR
		and MuR.SpendGoreRenderBudget
		and MuR:SpendGoreRenderBudget(GORE_KIND, particleCost, decalCost, false)
end

local function TryDecal(pos, cooldown)
	return MuR
		and MuR.TryGoreDecalCell
		and MuR:TryGoreDecalCell(pos, cooldown or 0.12)
end


--]]===========================================================================================]]


-- Use default blood stains as materials for the effect, and decals.
local blood_materials = {}
for i = 1,21 do
	local imat = Material("rlb/blood"..i)
	table.insert(blood_materials, imat)
end


-- Use default alien blood stains as materials for the effect, and decals.
local alienblood_materials = {}
for i = 1,6 do
	local imat = Material("decals/yblood"..i)
	table.insert(alienblood_materials, imat)
end


-- Random decal lenght and width:
local decal_randscale = {min=0.55,max=1.25}


-- Default HL2 impact effects:
local blood_impact_fx = {
	[BLOOD_COLOR_RED] = "blood_impact_red_01",
	[BLOOD_COLOR_ANTLION] = "blood_impact_antlion_01",
	[BLOOD_COLOR_ANTLION_WORKER] = "blood_impact_antlion_worker_01",
	[BLOOD_COLOR_GREEN] = "blood_impact_green_01",
	[BLOOD_COLOR_ZOMBIE] = "blood_impact_zombie_01",
	[BLOOD_COLOR_YELLOW] = "blood_impact_yellow_01",
}


local alien_blood_colors = {
	[BLOOD_COLOR_ANTLION] = true,
	[BLOOD_COLOR_ANTLION_WORKER] = true,
	[BLOOD_COLOR_GREEN] = true,
	[BLOOD_COLOR_ZOMBIE] = true,
	[BLOOD_COLOR_YELLOW] = true,
}


local CustomBloodMaterials = {}


-- Sounds:
local blood_drop_sounds = {
	")enh_blood_splatter_drips/drip_1.wav",
	")enh_blood_splatter_drips/drip_2.wav",
	")enh_blood_splatter_drips/drip_3.wav",
	")enh_blood_splatter_drips/drip_4.wav",
	")enh_blood_splatter_drips/drip_5.wav",
}


--]]===========================================================================================]]
function EFFECT:Init(data)
	-- Жидкая кровь из модуля gmcl_bsblood, если он стоит у игрока (client/cl_bsblood.lua).
	if MuR and MuR.BSBlood and MuR.BSBlood:Effect("mur_blood_splatter_effect", data) then return end
	local pos = data:GetOrigin()
	local magnitude = math.max(tonumber(data:GetMagnitude()) or 0, 0)
	local ent = data:GetEntity()
	local profile = MuR and MuR.GetGoreQualityProfile and MuR:GetGoreQualityProfile()
	if not profile then return end

	local blood_color = IsValid(ent) and ent:GetBloodColor() or BLOOD_COLOR_RED
	local damage = math.max(tonumber(data:GetRadius()) or 0, 0)
	local dataNrm = data:GetNormal()
	if not isvector(dataNrm) or dataNrm == vector_origin then
		dataNrm = VectorRand():GetNormalized()
	end
	local wtef = data:GetFlags() == 2
	local physdamage = magnitude < 1

	if IsValid(ent) and ent:GetClass() == "prop_ragdoll" and blood_color == -1 then
		blood_color = 0
	end

	local customBloodParticle = IsValid(ent) and ent:GetNWString("DynamicBloodSplatter_CustomBlood_Particle", "") or ""
	local blood_particle = customBloodParticle ~= "" and customBloodParticle or blood_impact_fx[blood_color]

	if PARTICLE and blood_particle and not wtef and SpendRender(1, 0) then
		ParticleEffect(blood_particle, pos, AngleRand())
	end

	local blood_mats
	local customBloodDecal = IsValid(ent) and ent:GetNWString("DynamicBloodSplatter_CustomBlood_Decal", "") or ""

	if blood_color == BLOOD_COLOR_RED then
		blood_mats = table.Copy(blood_materials)
	elseif alien_blood_colors[blood_color] then
		blood_mats = table.Copy(alienblood_materials)
	elseif customBloodDecal ~= "" then
		local decal_mat_name = util.DecalMaterial(customBloodDecal)
		CustomBloodMaterials[customBloodDecal] = CustomBloodMaterials[customBloodDecal] or {}

		if not CustomBloodMaterials[customBloodDecal][decal_mat_name] then
			local imat = Material(decal_mat_name)
			CustomBloodMaterials[customBloodDecal][decal_mat_name] = imat
		end

		blood_mats = table.Copy(CustomBloodMaterials[customBloodDecal])
	end

	if not blood_mats then return end

	local emitter = ParticleEmitter(pos, false)
	if not emitter then return end

	local particle_scale = DRIP_SCALE
	local hasDoneCollide = {}
	local requestedEffects = math.Clamp(math.floor(Lerp(math.Clamp(damage / SENSITIVITY, 0, 1), 1, COUNT) + 0.5), 1, COUNT)
	local effectCount = math.max(1, math.floor(requestedEffects * profile.particleScale + 0.5))

	for effectNum = 1, effectCount do
		local splash_back = DROP_CHANCE ~= 0 and magnitude > 0.9 and math.random(1, SPLAT_BACK_CHANCE) == 1
		local drip = DROP_CHANCE ~= 0 and math.random(1, DROP_CHANCE) == 1

		for streamIndex = 1, 3 do
			if (drip or streamIndex ~= 2) and (splash_back or streamIndex ~= 3) then
				local force = (streamIndex == 2 and VectorRand(-35, 35)) or (streamIndex == 3 and -65 * magnitude) or (150 * magnitude)
				local function forceVec()
					return dataNrm * force + VectorRand(-force * 0.35, force * 0.35)
				end

				if not physdamage then
					force = force * FORCE_MULT
				end

				local requestedParticles = math.Clamp(math.floor(5 * magnitude + 0.5), 0, MAX_STREAM_PARTICLES)
				if magnitude > 0 and requestedParticles == 0 then
					requestedParticles = 1
				end
				local particleCount = math.floor(requestedParticles * profile.particleScale + 0.5)
				if requestedParticles > 0 then
					particleCount = math.max(1, particleCount)
				end

				for particleIndex = 1, particleCount do
					if not SpendRender(1, 0) then break end

					local blood_material = table.Random(blood_mats)
					local length = math.Rand(20, 60)
					local particle = emitter:Add(blood_material, pos)
					if particle then
						particle:SetDieTime(1.8 * profile.lifetimeScale)
						particle:SetStartSize(math.Rand(1.9, 3.8) * particle_scale)
						particle:SetEndSize(0)
						particle:SetStartLength(length * particle_scale * 0.45)
						particle:SetEndLength(length * particle_scale)
						particle:SetGravity(Vector(0, 0, -500))
						particle:SetVelocity(forceVec())
						particle:SetCollide(true)

						if particleIndex == 1 then
							local function collideFunc(_, collidepos, normal, hitEnt)
								local effIndex = tostring(effectNum) .. "_" .. tostring(streamIndex)
								if hasDoneCollide[effIndex] then return end
								hasDoneCollide[effIndex] = true

								local producedVisual = false
								local decal_scale = (blood_color == BLOOD_COLOR_RED and RED_DECAL_SCALE)
									or (alien_blood_colors[blood_color] and YELLOW_DECAL_SCALE) or 1

								if SpendRender(0, 1) and TryDecal(collidepos, 0.12) then
									util.DecalEx(
										blood_material,
										IsValid(hitEnt) and hitEnt or Entity(0),
										collidepos,
										normal,
										Color(255, 255, 255),
										math.Rand(decal_randscale.min, decal_randscale.max) * decal_scale,
										math.Rand(decal_randscale.min, decal_randscale.max) * decal_scale
									)
									producedVisual = true
								end

								local requestedSplashCount = math.random(2, 5)
								local splashCount = math.max(1, math.floor(requestedSplashCount * profile.particleScale + 0.5))
								for splashIndex = 1, splashCount do
									if not emitter:IsValid() or not SpendRender(1, 0) then break end

									local splashMat = table.Random(blood_mats)
									local splashParticle = emitter:Add(splashMat, collidepos + normal * 0.5)
									if splashParticle then
										local splashVel = (normal + VectorRand(-0.5, 0.5)):GetNormalized() * math.Rand(20, 60)
										splashParticle:SetDieTime(math.Rand(0.8, 1.5) * profile.lifetimeScale)
										splashParticle:SetStartSize(math.Rand(0.8, 2.0))
										splashParticle:SetEndSize(0)
										splashParticle:SetStartLength(math.Rand(3, 8))
										splashParticle:SetEndLength(math.Rand(8, 15))
										splashParticle:SetGravity(Vector(0, 0, -400))
										splashParticle:SetVelocity(splashVel)
										splashParticle:SetCollide(true)
										splashParticle:SetBounce(0.1)
										producedVisual = true

										if splashIndex == 1 then
											local callbackMat = splashMat
											splashParticle:SetCollideCallback(function(_, splashPos, splashNormal)
												if math.random(1, 2) ~= 1 then return end
												if not SpendRender(0, 1) or not TryDecal(splashPos, 0.12) then return end

												util.DecalEx(
													callbackMat,
													Entity(0),
													splashPos,
													splashNormal,
													Color(255, 255, 255),
													math.Rand(0.2, 0.5),
													math.Rand(0.2, 0.5)
												)
											end)
										end
									end
								end

								if IMPACT_PARTICLE ~= 0 and blood_particle and SpendRender(1, 0) then
									ParticleEffect(blood_particle, collidepos, normal:Angle())
									producedVisual = true
								end

								if IMPACT_SOUND ~= 0 and producedVisual then
									sound.Play(table.Random(blood_drop_sounds), collidepos, 60, math.random(95, 120), 0.7)
								end
							end

							if STAIN_ENTS then
								local traceEnd = pos + forceVec()
								local function tracer()
									return util.TraceLine({
										start = pos,
										endpos = traceEnd,
										filter = ent,
									})
								end

								local tr = tracer()
								if tr.Hit and not tr.HitWorld then
									timer.Simple(tr.Fraction, function()
										local tr2 = tracer()
										if tr2.Hit and not tr2.HitWorld then
											collideFunc(nil, tr2.HitPos, tr2.HitNormal, tr2.Entity)
										end
									end)
								end
							end

							particle:SetCollideCallback(collideFunc)
						end
					end
				end
			end
		end
	end

	emitter:Finish()
end
--]]===========================================================================================]]
function EFFECT:Think() return false end
--]]===========================================================================================]]
function EFFECT:Render() end
--]]===========================================================================================]]
