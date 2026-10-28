local meta = FindMetaTable("Player")

local outlast_exec_anims = {
	["long_choke"] = {
		"executions_quietchoke_",
		"executions_angrystrangler_",
		"executions_footschoke_",
	},
	["long_gib"] = {
		"executions_facestab_",
		"executions_gutting_",
		"executions_stabcutthroat_",
		"executions_knifeeat_",
		"executions_stampy_",
	},
}

local death_delay = {
	["executions_facestab_killer_front"] = 4.5,
	["executions_facestab_killer_left"] = 4.5,
	["executions_facestab_killer_right"] = 4.5,
	["executions_facestab_killer_back"] = 4.5,

	["executions_gutting_killer_front"] = 4.3,
	["executions_gutting_killer_left"] = 4.3,
	["executions_gutting_killer_right"] = 4.3,
	["executions_gutting_killer_back"] = 4.3,

    ["executions_stabcutthroat_killer_front"] = 3.2,
	["executions_stabcutthroat_killer_left"] = 3.2,
	["executions_stabcutthroat_killer_right"] = 3.2,
	["executions_stabcutthroat_killer_back"] = 3.2,

    ["executions_knifeeat_killer_front"] = 3.6,
	["executions_knifeeat_killer_left"] = 3.6,
	["executions_knifeeat_killer_right"] = 3.6,
	["executions_knifeeat_killer_back"] = 3.6,

    ["executions_footschoke_killer_front"] = 3.2,
	["executions_footschoke_killer_left"] = 3.2,
	["executions_footschoke_killer_right"] = 3.2,
	["executions_footschoke_killer_back"] = 3.2,

    ["executions_stampy_killer_front"] = 3.8,
	["executions_stampy_killer_left"] = 3.8,
	["executions_stampy_killer_right"] = 3.8,
	["executions_stampy_killer_back"] = 3.8,

    ["executions_quietchoke_killer_front"] = 5.5,
	["executions_quietchoke_killer_left"] = 5.5,
	["executions_quietchoke_killer_right"] = 5.5,
	["executions_quietchoke_killer_back"] = 5.5,

    ["executions_angrystrangler_killer_front"] = 3.6,
	["executions_angrystrangler_killer_left"] = 3.6,
	["executions_angrystrangler_killer_right"] = 3.6,
	["executions_angrystrangler_killer_back"] = 3.6,
}

local hatred_exec_anims = {
	["knife"] = {6,5},
	["pistol"] = {7,7},
	["rifle"] = {6,7},
	["shotgun"] = {3,2},
}

local hatred_anim_effects = {
    ["mur_hatred_rifle_back_attacker1"] = {[46/30] = "gunshot"},
    ["mur_hatred_rifle_back_attacker2"] = {[22/30] = "gunshot"},
    ["mur_hatred_rifle_back_attacker3"] = {[37/30] = "riflepunch"},
    ["mur_hatred_rifle_back_attacker4"] = {[46/30] = "gunshot"},
    ["mur_hatred_rifle_back_attacker5"] = {[21/30] = "riflepunch", [57/30] = "gunshot"},
    ["mur_hatred_rifle_back_attacker6"] = {[22/30] = "riflepunch"},
    ["mur_hatred_rifle_front_attacker1"] = {[25/30] = "gunshot", [29/30] = "gunshot", [33/30] = "gunshot", [36/30] = "gunshot"},
    ["mur_hatred_rifle_front_attacker2"] = {[32/30] = "gunshot"},
    ["mur_hatred_rifle_front_attacker3"] = {[48/30] = "neckbreak"},
    ["mur_hatred_rifle_front_attacker4"] = {[29/30] = "riflepunch"},
    ["mur_hatred_rifle_front_attacker5"] = {[53/30] = "gunshot"},
    ["mur_hatred_rifle_front_attacker6"] = {[46/30] = "gunshot"},
    ["mur_hatred_rifle_front_attacker7"] = {[59/30] = "gunshot", [63/30] = "gunshot", [67/30] = "gunshot", [78/30] = "gunshot"},

    ["mur_hatred_pistol_back_attacker1"] = {[50/30] = "gunshot"},
    ["mur_hatred_pistol_back_attacker2"] = {[23/30] = "gunshot"},
    ["mur_hatred_pistol_back_attacker3"] = {[29/30] = "lift", [60/30] = "gunshot"},
    ["mur_hatred_pistol_back_attacker4"] = {[36/30] = "lift", [63/30] = "pistolpunch", [78/30] = "pistolpunch", [94/30] = "pistolpunch"},
    ["mur_hatred_pistol_back_attacker5"] = {[40/30] = "stomp", [62/30] = "stomp", [80/30] = "stomp"},
    ["mur_hatred_pistol_back_attacker6"] = {[34/30] = "gunshot", [44/30] = "gunshot", [56/30] = "gunshot"},
    ["mur_hatred_pistol_back_attacker7"] = {[18/30] = "gunshot", [48/30] = "gunshot"},
    ["mur_hatred_pistol_front_attacker1"] = {[30/30] = "gunshot"},
    ["mur_hatred_pistol_front_attacker2"] = {[33/30] = "lift", [84/30] = "gunshot"},
    ["mur_hatred_pistol_front_attacker3"] = {[55/30] = "gunshot"},
    ["mur_hatred_pistol_front_attacker4"] = {[30/30] = "stomp"},
    ["mur_hatred_pistol_front_attacker5"] = {[48/30] = "gunshot", [62/30] = "gunshot", [81/30] = "gunshot"},
    ["mur_hatred_pistol_front_attacker6"] = {[52/30] = "gunshot", [102/30] = "gunshot"},
    ["mur_hatred_pistol_front_attacker7"] = {[24/30] = "lift", [49/30] = "pistolpunch"},

    ["mur_hatred_shotgun_back_attacker1"] = {[54/30] = "gunshot"},
    ["mur_hatred_shotgun_back_attacker2"] = {[47/30] = "gunshot"},
    ["mur_hatred_shotgun_back_attacker3"] = {[41/30] = "gunshot"},
    ["mur_hatred_shotgun_front_attacker1"] = {[28/30] = "lift", [77/30] = "gunshot"},
    ["mur_hatred_shotgun_front_attacker2"] = {[31/30] = "gunshot"},

	["mur_hatred_knife_back_attacker1"] = {[1.2] = "lift", [2.5] = "throat"},
    ["mur_hatred_knife_back_attacker2"] = {[1] = "lift", [1.8] = "stab", [3.9] = "stabout"},
    ["mur_hatred_knife_back_attacker3"] = {[1.0] = "stab", [1.7] = "stab", [2.3] = "stabout"},
    ["mur_hatred_knife_back_attacker4"] = {[1] = "throat", [2.3] = "stabout"},
    ["mur_hatred_knife_back_attacker5"] = {[0.5] = "lift", [1.2] = "stab", [2.1] = "stab", [2.5] = "stab", [2.9] = "stab"},
    ["mur_hatred_knife_back_attacker6"] = {[1.0] = "throat", [3.2] = "stabout"},
    ["mur_hatred_knife_front_attacker1"] = {[57/30] = "lift", [83/30] = "throat"},
    ["mur_hatred_knife_front_attacker2"] = {[25/30] = "stab", [60/30] = "stabout"},
    ["mur_hatred_knife_front_attacker3"] = {[25/30] = "stab", [40/30] = "stab", [55/30] = "stab"},
    ["mur_hatred_knife_front_attacker4"] = {[48/30] = "throat", [90/30] = "stabout"},
    ["mur_hatred_knife_front_attacker5"] = {[25/30] = "stab", [37/30] = "stab", [49/30] = "stab"},
}

local hatred_anim_deathtime = {
	["mur_hatred_knife_back_attacker1"] = 110/30,
    ["mur_hatred_knife_back_attacker2"] = 125/30,
    ["mur_hatred_knife_back_attacker3"] = 95/30,
    ["mur_hatred_knife_back_attacker4"] = 72/30,
    ["mur_hatred_knife_back_attacker5"] = 96/30,
    ["mur_hatred_knife_back_attacker6"] = 100/30,
    ["mur_hatred_knife_front_attacker1"] = 120/30,
    ["mur_hatred_knife_front_attacker2"] = 72/30,
    ["mur_hatred_knife_front_attacker3"] = 60/30,
    ["mur_hatred_knife_front_attacker4"] = 98/30,
    ["mur_hatred_knife_front_attacker5"] = 60/30,

	["mur_hatred_pistol_back_attacker1"] = 51/30,
    ["mur_hatred_pistol_back_attacker2"] = 42/30,
    ["mur_hatred_pistol_back_attacker3"] = 80/30,
    ["mur_hatred_pistol_back_attacker4"] = 95/30,
    ["mur_hatred_pistol_back_attacker5"] = 80/30,
    ["mur_hatred_pistol_back_attacker6"] = 57/30,
    ["mur_hatred_pistol_back_attacker7"] = 49/30,
    ["mur_hatred_pistol_front_attacker1"] = 41/30,
    ["mur_hatred_pistol_front_attacker2"] = 96/30,
    ["mur_hatred_pistol_front_attacker3"] = 56/30,
    ["mur_hatred_pistol_front_attacker4"] = 30/30,
    ["mur_hatred_pistol_front_attacker5"] = 82/30,
    ["mur_hatred_pistol_front_attacker6"] = 103/30,
    ["mur_hatred_pistol_front_attacker7"] = 52/30,

    ["mur_hatred_rifle_back_attacker1"] = 47/30,
    ["mur_hatred_rifle_back_attacker2"] = 50/30,
    ["mur_hatred_rifle_back_attacker3"] = 44/30,
    ["mur_hatred_rifle_back_attacker4"] = 47/30,
    ["mur_hatred_rifle_back_attacker5"] = 58/30,
    ["mur_hatred_rifle_back_attacker6"] = 45/30,
    ["mur_hatred_rifle_front_attacker1"] = 43/30,
    ["mur_hatred_rifle_front_attacker2"] = 45/30,
    ["mur_hatred_rifle_front_attacker3"] = 60/30,
    ["mur_hatred_rifle_front_attacker4"] = 41/30,
    ["mur_hatred_rifle_front_attacker5"] = 54/30,
    ["mur_hatred_rifle_front_attacker6"] = 47/30,
    ["mur_hatred_rifle_front_attacker7"] = 79/30,

    ["mur_hatred_shotgun_back_attacker1"] = 56/30,
    ["mur_hatred_shotgun_back_attacker2"] = 49/30,
    ["mur_hatred_shotgun_back_attacker3"] = 43/30,
    ["mur_hatred_shotgun_front_attacker1"] = 79/30,
    ["mur_hatred_shotgun_front_attacker2"] = 33/30,
}

local function PlayRandomSound(ent, min, max, str, format)
	if not format then
		format = ".mp3"
	end
	if !IsValid(ent) then return end
	sound.Play(str..math.random(min,max)..format, ent:GetPos(), 55)
end

local function MakeBloodParticleHatred(type, ent, tar, delay)
	local max = 1
	if type == "throat" then
		max = 8
	end
	timer.Simple(delay, function()
		if !IsValid(ent) or !IsValid(tar) or !ent:IsExecuting() or !tar:IsExecuting() then return end
		timer.Create("BloodParticlesHatred"..ent:EntIndex()..tar:EntIndex(), 0.2, max, function()
			if !IsValid(ent) or !IsValid(tar) or !ent:IsExecuting() or !tar:IsExecuting() then return end
			local effectdata = EffectData()
			effectdata:SetOrigin(ent:GetBonePosition(ent:LookupBone("ValveBiped.Bip01_R_Hand")))
			if type == "throat" then
				effectdata:SetOrigin(tar:GetBonePosition(tar:LookupBone("ValveBiped.Bip01_Head1")))
			elseif type == "gunshot" then
				local tab = ent:GetAttachment(ent:LookupAttachment("anim_attachment_RH"))
				local tr = util.TraceLine({
					start = tab.Pos,
					endpos = tab.Pos+tab.Ang:Forward()*32,
					filter = {ent, tar},
					mask = MASK_PLAYERSOLID,
				})
				effectdata:SetOrigin(tr.HitPos+Vector(0,0,4))
			end
			local origin = effectdata:GetOrigin()
			local normal = VectorRand(-1,1)
			effectdata:SetNormal(normal)
			effectdata:SetMagnitude(2)
			effectdata:SetRadius(24)
			effectdata:SetEntity(tar)
			if MuR.BroadcastBloodSplatterEffect then
				MuR:BroadcastBloodSplatterEffect(tar, origin, normal, 2, 24, 0)
			else
				util.Effect("mur_blood_splatter_effect", effectdata, true, true)
			end
			local downNormal = Vector(0,0,-1)
			effectdata:SetNormal(downNormal)
			if MuR.BroadcastBloodSplatterEffect then
				MuR:BroadcastBloodSplatterEffect(tar, origin, downNormal, 2, 24, 0)
			else
				util.Effect("mur_blood_splatter_effect", effectdata, true, true)
			end
		end)
	end)
end

local function PlayRandomHatredSound(ent, type, delay, att)
	delay = delay-0.2 or 0.001
	local str = ")murdered/gore/"
	if type == "stab" then
		str = str.."stab"..math.random(1,5)..".mp3"
		MakeBloodParticleHatred(type, att, ent, delay)
	elseif type == "throat" then
		str = str.."throat"..math.random(1,2)..".mp3"
		MakeBloodParticleHatred(type, att, ent, delay)
	elseif type == "stabout" then
		str = str.."stabout.mp3"
		MakeBloodParticleHatred(type, att, ent, delay)
	elseif type == "pistolpunch" then
		str = ")codmelee/melee_character_gun_sml_steel_plr_0"..math.random(1,5)..".ogg"
		MakeBloodParticleHatred(type, att, ent, delay)
	elseif type == "riflepunch" then
		str = ")codmelee/melee_character_gun_med_steel_plr_0"..math.random(1,5)..".ogg"
		MakeBloodParticleHatred(type, att, ent, delay)
	elseif type == "neckbreak" then
		str = str.."bonebreak"..math.random(1,6)..".mp3"
	elseif type == "stomp" then
		str = str.."flesh_squishy_impact_hard"..math.random(1,8)..".wav"
	elseif type == "lift" then
		str = str.."lift"..math.random(1,4)..".mp3"
	elseif type == "gunshot" then
		timer.Simple(delay, function()
			if !IsValid(att) or !att:IsExecuting() then return end

			local wep = att.AnimWeapon
			if !IsValid(wep) then return end
			att:EmitSound(wep.Primary.Sound, 100, math.random(90,110))
			BroadcastLua([[local e = Entity(]]..wep:EntIndex()..[[) if IsValid(e) then e:ShootEffectsCustom(true) end]])

			if !IsValid(ent) or !ent:IsExecuting() then return end
			MakeBloodParticleHatred(type, att, ent, 0)
		end)
		return
	end
	timer.Simple(delay, function()
		if !IsValid(ent) or !IsValid(att) or !ent:IsExecuting() or !att:IsExecuting() then return end
		sound.Play(str, ent:GetPos(), 55)
	end)
end

local function bloodeffect(att, ply)
	local id = ply:LookupAttachment(att)
	local tab = ply:GetAttachment(id)
	for i=1,5 do
		ParticleEffectAttach("blood_impact_red_01_droplets", PATTACH_POINT_FOLLOW, ply, id)
	end
end

local function effects_takedown(ply, targetModel, animName)
    if animName == "executions_angrystrangler_killer_front" then

		timer.Simple(0.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(2.9, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_AngryStrangler.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

	    timer.Simple(0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)
		timer.Simple(1.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)
		timer.Simple(2.6, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 7, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(11.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 7, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(12.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 7, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)

		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.6, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(3.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

	if animName == "executions_angrystrangler_killer_back" then

		timer.Simple(0.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(2.9, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_AngryStrangler.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

		timer.Simple(1.9, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

		timer.Simple(2.4, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

		timer.Simple(3.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

	if animName == "executions_angrystrangler_killer_left" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(2.9, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_AngryStrangler.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

		timer.Simple(1.9, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

		timer.Simple(2.4, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

		timer.Simple(3.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

	if animName == "executions_angrystrangler_killer_right" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(2.9, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_AngryStrangler.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

		timer.Simple(1.9, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

		timer.Simple(2.4, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

		timer.Simple(3.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

    if animName == "executions_footschoke_killer_front" then

		timer.Simple(0.4, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_FootChoke.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

	    timer.Simple(0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)
		timer.Simple(2.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(9.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)

		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

    if animName == "executions_footschoke_killer_back" then

		timer.Simple(0.2, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_FootChoke.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

	    timer.Simple(0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)
		timer.Simple(2.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(9.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)

		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

    if animName == "executions_footschoke_killer_right" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(2.6, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_FootChoke.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

	    timer.Simple(0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)
		timer.Simple(2.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(9.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)

		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

    if animName == "executions_footschoke_killer_left" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_FootChoke.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

	    timer.Simple(0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)
		timer.Simple(2.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(9.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)

		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

    if animName == "executions_quietchoke_killer_back" then

		timer.Simple(0.2, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(2.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_ChokeQuiet.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

	    timer.Simple(0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)
		timer.Simple(2.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(9.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(11.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(12.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)

		timer.Simple(1.9, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.6, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(3.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

    if animName == "executions_quietchoke_killer_front" then

		timer.Simple(0.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_ChokeQuiet.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

	    timer.Simple(0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)
		timer.Simple(2.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(9.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(11.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(12.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)

		timer.Simple(1.9, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.6, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(3.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

    if animName == "executions_quietchoke_killer_left" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(2.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_ChokeQuiet.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

	    timer.Simple(0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)
		timer.Simple(2.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(9.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(11.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(12.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)

		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

    if animName == "executions_quietchoke_killer_right" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(2.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_ChokeQuiet.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

	    timer.Simple(0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)
		timer.Simple(2.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(9.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(11.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 6, "trials/foley/FOL_BigGrunt_Torso_Long0")
        end)
		timer.Simple(12.0, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
            PlayRandomSound(ply, 1, 4, "trials/foley/FOL_BigGrunt_Legs_Long0")
        end)

		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)
		timer.Simple(2.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 4, "player/footsteps/concrete", ".wav")
        end)

	end

	if string.match(animName, "executions_knifeeat_killer_") then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_KnifeEat.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)

	end

    if string.match(animName, "executions_gutting_killer_") then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_Gutting.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(1.7, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)
	end

	if string.match(animName, "executions_stabcutthroat_killer_") then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_StabCutThroat.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(2, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end

        end)
	end

	if animName == "executions_stampy_killer_front" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_Stampy.mp3", ply:GetPos(), 55)
        end)
	end

	if animName == "executions_stampy_killer_right" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_Stampy.mp3", ply:GetPos(), 55)
        end)
	end

	if animName == "executions_stampy_killer_left" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(3.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_Stampy.mp3", ply:GetPos(), 55)
        end)
	end

	if animName == "executions_stampy_killer_back" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(4.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Scripted_Murder_Grunt_Stampy.mp3", ply:GetPos(), 55)
        end)
	end

	if animName == "executions_facestab_killer_front" then

		timer.Simple(0.5, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(4.83-0.2, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(5.83-0.2, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(6.5-0.2, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(7.6-0.2, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(8.26-0.2, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(9.33-0.2, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(10.83-0.2, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
	end

	if animName == "executions_facestab_killer_left" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(4.83-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(5.83-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(6.5-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(7.6-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(8.26-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(9.33-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(10.83-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
	end

	if animName == "executions_facestab_killer_left" then

		timer.Simple(0.1, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(4.83-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(5.83-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(6.5-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(7.6-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(8.26-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(9.33-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(10.83-0.8, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
	end

	if animName == "executions_facestab_killer_back" then

		if IsValid(ply.AnimEffects) then
			ply.AnimEffects:SetBodygroup(1,1)
		end
		timer.Simple(0.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			sound.Play("trials/executions/SFX_Murder_IntroKick.mp3", ply:GetPos(), 55)
        end)
		timer.Simple(4.83-0.4, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(5.83-0.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(6.5-0.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(7.6-0.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(8.26-0.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(9.33-0.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
		timer.Simple(10.83-0.3, function()
		    if !IsValid(targetModel) or !IsValid(ply) or !ply:IsExecuting() then return end
			PlayRandomSound(ply, 1, 8, "murdered/gore/flesh_squishy_impact_hard", ".wav")
			bloodeffect("eyes", targetModel)
        end)
	end

	local tab = hatred_anim_effects[animName]
	if tab then
		for k, v in pairs(tab) do
			PlayRandomHatredSound(targetModel, v, k, ply)
		end
	end
end
local function GetFinishingDirection(victim, attacker, hatred)
    local vec = (victim:GetPos() - attacker:GetPos()):GetNormal():Angle().y
    local targetAngle = attacker:GetAngles().y
    if targetAngle > 360 then
        targetAngle = targetAngle - 360
    end
    if targetAngle < 0 then
        targetAngle = targetAngle + 360
    end

    local angleAround = vec - targetAngle
    if angleAround > 360 then
        angleAround = angleAround - 360
    end
    if angleAround < 0 then
        angleAround = angleAround + 360
    end

    if angleAround <= 45 or angleAround > 315 then
        return "front"
    end
    if angleAround > 45 and angleAround <= 135 and not hatred then
        return "left"
    end
    if angleAround > 135 and angleAround <= 225 then
        return "back"
    end
    if angleAround > 225 and angleAround <= 315 and not hatred then
        return "right"
    end
	return math.random(0,1) == 1 and "back" or "front"
end

local function add_wepeff(ply, anim)
    local w = ents.Create("exec_anim")
    w:SetModel("models/murdered/trials_executions.mdl")
    w:SetPos(ply:GetPos())
    w:SetAngles(ply:GetAngles())
    w:Spawn()
    w:ResetSequence(anim)
    w.Target = ply
	ply.AnimEffects = w
	ply:SetNW2Entity("AnimCamera", w)
end

local fknife = {"mur_hatred_knife_back_attacker1", "mur_hatred_knife_back_attacker4", "mur_hatred_knife_back_attacker5", "mur_hatred_knife_front_attacker1", "mur_hatred_knife_front_attacker2", "mur_hatred_knife_front_attacker5"}
local function add_wepmod(ply, anim)
	local offsetVec = Vector(0, 1, -3)
	local offsetAng = Angle(0, 180, 180)
	if table.HasValue(fknife, anim) then
		offsetVec = Vector(0, -2, 5)
		offsetAng = Angle(0, 180, 0)
	end
	if !string.find(anim, "knife_") then return end
	if string.find(anim, "asdasd") then
		offsetVec = Vector(3, -2, -3.5)
        offsetAng = Angle(180, 180, 0)
	end
	local w = ents.Create("base_anim")
    w:SetModel("models/murdered/yurie/eft/weapons/world/izhmash_6x5.mdl")
    w:Spawn()
	w:SetModelScale(1.2, 0.000001)
    w:SetParent(ply, ply:LookupAttachment("anim_attachment_RH"))
	w:SetLocalPos(offsetVec)
	w:SetLocalAngles(offsetAng)
	ply:DeleteOnRemove(w)
	ply.AnimPropWeapon = w
end

local NON_LETHAL_EXECUTIONS = {
	"_quietchoke_",
	"_angrystrangler_",
	"_footschoke_"
}

local function isSurvivableExecution(anim)
	if not isstring(anim) then return false end

	for _, pattern in ipairs(NON_LETHAL_EXECUTIONS) do
		if string.find(anim, pattern, 1, true) then return true end
	end

	if string.find(anim, "_hatred_pistol_back_victim4", 1, true)
		or string.find(anim, "_hatred_pistol_back_victim5", 1, true)
		or string.find(anim, "_hatred_pistol_front_victim4", 1, true) then
		return true
	end

	return false
end

local function killtarget(tar, att)
    tar:SetNotSolid(false)
    tar:Freeze(false)
    tar:SetHealth(1)
    tar.Executor = nil

    local anim = tar:GetSVAnim()
    if isSurvivableExecution(anim) then
        tar:DamagePlayerSystem("hard_blood")
    else
        tar.MuR_StructuralDeath = true
    end

	if string.find(tar:GetSVAnim(), "_stampy_") then
		tar.DeathBlowHead = true
	elseif string.find(tar:GetSVAnim(), "_facestab_") then
		tar.DeathBlowHead = true
	elseif string.find(tar:GetSVAnim(), "_stabcutthroat_") then
		tar.DeathBlowHead = true
		tar.DeathBlowHeadCut = true
	elseif string.find(tar:GetSVAnim(), "_knifeeat_") then
		tar.DeathBlowHead = true
		tar.DeathBlowHeadCut = true
	elseif string.find(tar:GetSVAnim(), "_gutting_") or string.find(tar:GetSVAnim(), "_shotgun_back_victim2") or string.find(tar:GetSVAnim(), "_shotgun_front_victim2") then
		tar.DeathBlowSpine = true
	elseif string.find(tar:GetSVAnim(), "_shotgun_") or string.find(tar:GetSVAnim(), "_pistol_back_victim5") or string.find(tar:GetSVAnim(), "_pistol_back_victim5") or string.find(tar:GetSVAnim(), "_pistol_front_victim4") then
		tar.DeathBlowHead = true
	end

	if IsValid(tar.AnimEffects) then
		tar.AnimEffects.Target = nil
	end

    local dmg = DamageInfo()
    dmg:SetAttacker(att)
	att:PlayVoiceLine("execution_kill", true)
    dmg:SetDamage(10)
    dmg:SetDamageType(DMG_SLASH)
    dmg:SetDamagePosition(tar:GetBonePosition(tar:LookupBone("ValveBiped.Bip01_Spine4")))

    tar:TakeDamageInfo(dmg)
end

function meta:Takedown()
	if self:IsFlagSet(FL_FROZEN) or !self:OnGround() or !self:Alive() or self:GetNoDraw() or !self:IsKiller() or self:IsExecuting() then return end

	local tar = nil
	local tr = util.TraceLine( {
		start = self:EyePos(),
		endpos = self:EyePos() + self:GetAimVector()*64,
		filter = self
	})
	if IsValid(tr.Entity) and tr.Entity:IsPlayer() then
		tar = tr.Entity
	elseif IsValid(tr.Entity) and tr.Entity.isRDRag and IsValid(tr.Entity.Owner) then
		tar = tr.Entity.Owner
	end

	if IsValid(tar) then
		if tar:IsKiller() or tar:IsExecuting() then return end
		if tar.IsDying and tar:IsDying() then return end
		if IsValid(tar:GetRD()) and MuR:CheckHeight(tar:GetRD(), MuR:BoneData(tar:GetRD(), "ValveBiped.Bip01_Pelvis")) > 16 then
			tar:StopRagdolling(false)
		end
		if tar:GetNoDraw() then
			self.AnimWeapon = self:GetActiveWeapon()
			self:FullTakedown(tar)
		else
			self:Freeze(true)
			self:SetSVAnimation("mur_legsweep", true)
			self.AnimWeapon = self:GetActiveWeapon()
			tar:SetSVAnimation("mur_falldown", true)
			tar:Freeze(true)
			tar:SetActiveWeapon(nil)
			tar:EmitSound(")trials/legsweep.mp3", 55)
			timer.Simple(1.2, function()
				if IsValid(tar) then
					tar:Freeze(false)
				end
				if IsValid(self) and self:Alive() then
					self:Freeze(false)
					timer.Simple(0.001, function()
						if !IsValid(self) then return end
						self:FullTakedown(tar)
					end)
				end
			end)
		end
	end
end

local forcetype = {
	["tfa_bs_mp7"] = "pistol",
	["tfa_bs_uzi"] = "pistol",
}

function meta:FullTakedown(forceent)
	if !self:OnGround() or !self:Alive() or self:GetNoDraw() or !self:IsKiller() or self:IsExecuting() then return end

    local tar = forceent
    if !IsValid(tar) then return end
	if tar:IsKiller() or tar:IsExecuting() then return end
	if tar.IsDying and tar:IsDying() then return end

	local wep = self.AnimWeapon
	local spawncam = true
	local addang = 0
	local type = ""
	local choose = self:GetInfo("blsd_character_executionstyle", "default")
	local rnd_anim = istable(outlast_exec_anims[choose]) and table.Random(outlast_exec_anims[choose]) or ""
    local side = GetFinishingDirection(self, tar)
    local tar_anim, att_anim = rnd_anim.."victim_"..side, rnd_anim.."killer_"..side
	if !string.find(choose, "long_") then
		local rnd_anim = ""
		type = "knife"
		local side = GetFinishingDirection(self, tar, true)
		if IsValid(wep) and wep.IsTFAWeapon and choose != "default_knife" then
			if forcetype[wep:GetClass()] then
				type = forcetype[wep:GetClass()]
			elseif string.find(wep.Category, "Sidearms") then
				type = "pistol"
			elseif string.find(wep.Category, "Shotguns") or string.find(wep.Category, "Sniper Rifles") then
				type = "shotgun"
			else
				type = "rifle"
			end
		end
		rnd_anim = "mur_hatred_"..type.."_"
		local info = hatred_exec_anims[type]

		local id = math.random(1,info[1])
		if side == "front" then
			id = math.random(1,info[2])
		end
		tar_anim, att_anim = rnd_anim..side.."_victim"..id, rnd_anim..side.."_attacker"..id
		spawncam = false
	end

    local id, dur = self:LookupSequence(att_anim)
	if dur < 1 then return end

	self.CantBeStopped = false
    self:SetEyeAngles(tar:GetAngles())
    self:SetVelocity(Vector(50,0,0))
    self:SetSVAnimation(att_anim, true)
    self:Freeze(true)
	self:SetNW2Entity("ExecutionTarget", tar)

	tar:StopRagdolling()
    tar:SetSVAnimation(tar_anim, true)
    tar:SetPos(self:GetPos())
    tar:SetEyeAngles(self:EyeAngles())
	tar:SetVelocity(Vector(50,0,0))
    tar:SetNotSolid(true)
    tar:Freeze(true)
    tar.Executor = self
	if !string.find(choose, "long_choke") then
		tar:PlayVoiceLine("execution_mercy", true)
	end
	tar:SetNW2Entity("ExecutionTarget", self)
	self.ExecutingTar = tar

	if spawncam then
    	add_wepeff(self, att_anim)
		add_wepeff(tar, tar_anim)
	end

    effects_takedown(self, tar, att_anim)
	add_wepmod(self, att_anim)

	local dur2 = death_delay[att_anim] or dur-hatred_anim_deathtime[att_anim] or 1
    timer.Simple(dur-dur2, function()
        if IsValid(tar) and tar:Alive() and tar:IsExecuting() and IsValid(self) then
			self.CantBeStopped = true
            killtarget(tar, self)
        end
    end)
    timer.Simple(dur-0.02, function()
        if IsValid(self) and self:Alive() and self:IsExecuting() then
            self:Freeze(false)
			self.ExecutingTar = nil
			self.AnimWeapon = nil
        end
        if IsValid(w) then
            w:Remove()
        end
    end)
end

function meta:IsGunExecution()
    return self:IsExecuting() and ( tobool(string.find(self:GetSVAnim(), "shotgun_")) or tobool(string.find(self:GetSVAnim(), "rifle_")) or tobool(string.find(self:GetSVAnim(), "pistol_")) )
end

function meta:IsExecutor()
    return self:IsExecuting() and string.find(self:GetSVAnim(), "attacker")
end

hook.Add("PlayerPostThink", "MuR_Takedown", function(ply)
    if ply:IsExecuting() then
		if !ply:IsGunExecution() then
        	ply:SetActiveWeapon(nil)
		end
		ply:SetNW2Float("Stamina", 10)

        local att = ply.Executor
        if IsValid(att) then
            ply:SetPos(att:GetPos())
            ply:SetEyeAngles(att:EyeAngles())

            if !att:IsExecuting() then
                ply:SetSVAnimation("")
                ply:Freeze(false)
                ply:SetNotSolid(false)
            end
        end

		local tar = ply.ExecutingTar
		if (!IsValid(tar) or !tar:Alive() or !tar:IsExecuting()) and !IsValid(att) and !ply.CantBeStopped then
			ply.ExecutingTar = nil
			ply:SetSVAnimation("")
			ply:Freeze(false)
			ply:SetNotSolid(false)
		end
    else
		ply.ExecutingTar = nil
        ply.Executor = nil
		if !IsValid(ply:GetRD()) and bit.band(ply:GetSolidFlags(), FSOLID_NOT_SOLID) ~= 0 then
			ply:SetNotSolid(false)
		end
		if IsValid(ply.AnimPropWeapon) then
			ply.AnimPropWeapon:Remove()
		end
    end
end)

hook.Add("EntityTakeDamage", "MuR_StopExecution", function(ent, dmg)
	if ent:IsPlayer() and ent:IsExecutor() then
		ent:SetSVAnimation("")
		ent:Freeze(false)
		local ang = ent:GetAttachment(ent:LookupAttachment("eyes")).Ang
		ang.z = 0
		ent:SetEyeAngles(ang)
		if IsValid(ent.ExecutingTar) then
			ent.ExecutingTar:SetSVAnimation("")
			ent.ExecutingTar:StartRagdolling()
			ent.ExecutingTar:Freeze(false)
		end
	end
end)

hook.Add("PlayerButtonDown", "MuR_TakedownButton", function(ply, but)
    if but == KEY_V then
        ply:Takedown()
    end
end)
