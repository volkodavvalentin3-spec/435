local DMGNoBleed = {	 
	DMG_BURN,
	DMG_DROWN,
	DMG_DROWNRECOVER,
	DMG_RADIATION,
	DMG_NERVEGAS,
	DMG_DISSOLVE,
	DMG_SLOWBURN,
	DMG_SHOCK,
}

local function EnhancedSplatter( ent, pos, dir, intensity, damage )

	if ent:GetBloodColor() == BLOOD_COLOR_MECH then

		local spark = ents.Create("env_spark")
		spark:SetPos(pos)
		spark:Spawn()
		spark:Fire("StartSpark", "", 0)
		spark:Fire("StopSpark", "", 0.001)
		SafeRemoveEntityDelayed(spark, 0.1)

	else

		local effectdata = EffectData()
		effectdata:SetOrigin( pos )
		effectdata:SetNormal( dir:GetNormalized() )
		effectdata:SetMagnitude( intensity )
		effectdata:SetRadius(damage)
		effectdata:SetEntity( ent )
		util.Effect("mur_blood_splatter_effect", effectdata, true, true )

	end

end

local function DMG_NoBleed( dmginfo )

	for _, dmgType in ipairs(DMGNoBleed) do
		if dmginfo:IsDamageType(dmgType) then return true end
	end

end

local function IsBulletDamage( dmginfo )

	return dmginfo:IsBulletDamage() or dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_BUCKSHOT)

end

local function NetworkCustomBlood( ent )
	local CustomDecal
	local CustomParticle

	if ent.IsVJBaseSNPC or ent.IsVJBaseCorpse then

		CustomDecal = ent.CustomBlood_Decal && ent.CustomBlood_Decal[1]
		CustomParticle = ent.CustomBlood_Particle && ent.CustomBlood_Particle[1]

	elseif ent.IsZBaseNPC or ent.IsZBaseRag then

		CustomDecal = ent.CustomBloodDecals
		CustomParticle = ent.CustomBloodParticles && ent.CustomBloodParticles[1]

	end

	if CustomDecal && ent.DynSplatter_LastCustomDecal != CustomDecal then
		ent:SetNW2String( "DynamicBloodSplatter_CustomBlood_Decal", CustomDecal )
		ent.DynSplatter_LastCustomDecal = CustomDecal
	end

	if CustomParticle && ent.DynSplatter_LastCustomParticle != CustomParticle then
		ent:SetNW2String( "DynamicBloodSplatter_CustomBlood_Particle", CustomParticle )
		ent.DynSplatter_LastCustomParticle = CustomParticle
	end
end
MuR.Gamemode = 4
MuR.GameStarted = true

local function Damage( ent, dmginfo )

	if DMG_NoBleed(dmginfo) then return end

	if bit.band( ent:GetFlags(), FL_DISSOLVING ) == FL_DISSOLVING then return end

	local damage = dmginfo:GetDamage()
	local force = dmginfo:GetDamageForce()
	local infl = dmginfo:GetInflictor()

	local bullet_damage_type = IsBulletDamage( dmginfo )
	local phys_damage_type = dmginfo:IsDamageType(DMG_CRUSH)

	local phys_damage = damage > 10 && phys_damage_type
	local weapon_damage = (IsValid(infl) && infl:IsWeapon())
	local crossbow_damage = (IsValid(infl) && infl:GetClass() == "crossbow_bolt")

	local blood_pos = ( (bullet_damage_type or weapon_damage or phys_damage or crossbow_damage) && dmginfo:GetDamagePosition() ) or ent:WorldSpaceCenter()
	local magnitude = phys_damage&&0.5 or 1.2

	if (phys_damage or (!phys_damage_type && damage > 0)) and damage >= 10 then
		EnhancedSplatter( ent, blood_pos, force, magnitude, phys_damage && 1 or damage )
	end
end

hook.Add("EntityTakeDamage", "EnhancedSplatter", function( ent, dmginfo )
	if !ent:GetNW2Bool("DynSplatter") then return end

	ent.DynSplatter_Hits = ent.DynSplatter_Hits or {}
	table.insert(ent.DynSplatter_Hits, dmginfo:GetDamagePosition())
end)

hook.Add("EntityTakeDamage", "!EnhancedSplatter", function( ent, dmginfo )
	if !ent:GetNW2Bool("DynSplatter") then return end

	local tab = {dmginfo:GetAttacker() or game.GetWorld(), dmginfo:GetInflictor() or game.GetWorld(), dmginfo:GetDamage(), dmginfo:GetDamageType(), dmginfo:GetDamageForce(), dmginfo:GetDamagePosition()}

	timer.Simple(0.001, function()
		if !IsValid(ent) then return end

		if !IsValid(tab[1]) then
			tab[1] = game.GetWorld()
			tab[2] = game.GetWorld()
		end
		NetworkCustomBlood( ent )

		if ent.DynSplatter_Hits then
			for _, pos in ipairs(ent.DynSplatter_Hits) do
				local dmginfo2 = DamageInfo()
				dmginfo2:SetAttacker(tab[1])
				dmginfo2:SetInflictor(tab[1])
				dmginfo2:SetDamage(tab[3] / #ent.DynSplatter_Hits)
				dmginfo2:SetDamagePosition(pos)
				dmginfo2:SetDamageType(tab[4])
				dmginfo2:SetDamageForce(tab[5])
				Damage(ent, dmginfo2)
			end

		else

			local dmginfo2 = DamageInfo()
			dmginfo2:SetAttacker(tab[1])
			dmginfo2:SetInflictor(tab[1])
			dmginfo2:SetDamage(tab[3] or 0)
			dmginfo2:SetDamagePosition(tab[6] or Vector(0,0,0))
			dmginfo2:SetDamageType(tab[4] or DMG_GENERIC)
			dmginfo2:SetDamageForce(tab[5] or Vector(0,0,0))
			Damage(ent, dmginfo2)

		end

		ent.DynSplatter_Hits = nil
	end)
end)

hook.Add("OnEntityCreated", "OnEntityCreated_DynamicBloodSplatter", function( ent )
	if !DynSplatterFullyInitialized then return end

	timer.Simple(0, function()
		if !IsValid(ent) then return end

		if ent.IsVJBaseSNPC then

			function ent:SpawnBloodParticles() end
			function ent:SpawnBloodDecal() end

		elseif ent.IsZBaseNPC then

			function ent:CustomBleed() end

		end

		DynSplatterReturnEngineBlood = true
		local EngineBloodColor = ent:GetBloodColor()

		if MuR.IsAI(ent) or ent:IsPlayer() or ent:GetClass() == "prop_ragdoll" then
			ent:SetBloodColor(EngineBloodColor)
			ent:DisableEngineBlood()
			ent:SetNW2Bool("DynSplatter", true)
		end

		NetworkCustomBlood( ent )
	end)
end)

hook.Add("CreateEntityRagdoll", "CreateEntityRagdoll_DynamicBloodSplatter", function( own, ragdoll )
	if own.IsVJBaseSNPC then

		ragdoll.CustomBlood_Decal = own.CustomBlood_Decal
		ragdoll.CustomBlood_Particle = own.CustomBlood_Particle

	elseif own.IsZBaseNPC then

		ragdoll.CustomBloodDecals = own.CustomBloodDecals
		ragdoll.CustomBloodParticles = own.CustomBloodParticles

	end

	ragdoll:SetBloodColor(own:GetBloodColor())
	ragdoll:SetNW2Bool("DynSplatter", true)
end)

hook.Add("PlayerSpawn", "RemoveEngineBlood", function( ply )
	if true then

		if DynSplatterFullyInitialized then

			DynSplatterReturnEngineBlood = true
			local EngineBloodColor = ply:GetBloodColor()

			ply:DisableEngineBlood()
			ply:SetBloodColor(EngineBloodColor)
			ply:SetNW2Bool("DynSplatter", true)

		end

	else

		ply:SetNW2Bool("DynSplatter", false)

	end
end)
