local bdtab = {
    ["exp"] = {
        "deathrunning_09",
        "deathrunning_10",
        "deathrunning_11a",
        "deathrunning_11e",
        "deathrunning_11b",
        "deathrunning_11c",
        "DeathExplosion_01",
        "DeathExplosion_02",
        "DeathExplosion_03",
        "DeathExplosion_04",
        "DeathExplosion_05",
        "DeathExplosion_06",
        "DeathExplosion_07",
        "DeathExplosion_08",
    },
    ["club"] = {
        "club1",
        "club2",
        "club3",
        "club4",
        "bd_death_slasher_front",
        "bd_death_slasher_left",
        "bd_death_slasher_right",
        "bd_death_slasher_back",
    },
    ["moving"] = {
        "deathrunning_01",
        "deathrunning_03",
        "deathrunning_04",
        "deathrunning_05",
        "deathrunning_06",
        "deathrunning_07",
        "deathrunning_08",
        "deathrunning_11d",
        "deathrunning_11f",
        "deathrunning_11g",
        "deathrunning_12",
        "deathrunning_13",
        "deathrunning_14",
        "deathrunning_15",
        "deathrunning_16",
    },
    ["dying"] = {
        "death_01",
        "death_02a",
        "death_02c",
        "death_03",
        "death_05",
        "death_06",
        "death_07",
        "death_08",
        "death_08b",
        "death_09",
        "death_10ab",
        "death_10b",
        "death_10c",
        "death_11_01a",
        "death_11_01b",
        "death_11_02a",
        "death_11_02b",
        "death_11_02c",
        "death_11_02d",
        "death_11_03a",
        "death_11_03b",
        "death_11_03c",
        "dying1",
        "dying2",
        "dying3",
        "dying4",
        "dying5",
        "dying6",
        "dying7",
        "bd_death_leg_01",
        "bd_death_leg_02",
        "bd_death_leg_03",
        "bd_death_leg_04",
        "bd_death_leg_05",
        "bd_death_leg_06",
        "bd_death_leg_07",
        "bd_death_leg_08",
        "bd_death_legs_01",
    },
    ["bd_torso"] = {
        "bd_death_torso_long_01",
        "bd_death_torso_long_02",
        "bd_death_torso_long_03",
        "bd_death_torso_short_01",
        "bd_death_torso_short_02",
        "bd_death_torso_short_03",
        "bd_death_torso_short_04",
        "bd_death_torso_short_05",
        "bd_death_torso_short_06",
        "bd_death_torso_short_07",
        "bd_death_torso_short_08",
        "bd_death_torso_short_09",
        "bd_death_torso_short_10",
        "bd_death_torso_short_11",
        "bd_death_torso_short_12",
        "bd_death_torso_short_13",
        "bd_death_torso_short_14",
        "bd_death_torso_short_15",
        "bd_death_torso_short_16",
        "bd_death_torso_short_17",
        "bd_death_torso_short_18",
        "bd_death_torso_short_19",
        "bd_death_torso_short_20",
        "bd_death_torso_short_21",
        "bd_death_stomach_multi_01",
        "bd_death_stomach_single_01",
        "bd_death_stomach_single_02",
    },
    ["bd_head"] = {
        "bd_death_head_01",
        "bd_death_head_02",
        "bd_death_head_03",
        "bd_death_head_04",
        "bd_death_head_05",
        "bd_death_head_07",
        "bd_death_head_08",
        "bd_death_head_multi_01",
        "bd_death_head_multi_02",
        "bd_death_head_multi_03",
        "bd_death_head_single_01",
        "bd_death_head_single_02",
        "bd_death_head_single_03",
        "bd_death_head_short_01",
        "bd_death_head_short_02",
        "bd_death_head_short_03",
    },
    ["bd_neck"] = {
        "bd_death_neck_short_01",
        "bd_death_neck_short_02",
        "bd_death_neck_short_03",
        "bd_death_neck_short_04",
    },
    ["bd_larm"] = {
        "bd_death_leftarm_multi_01",
        "bd_death_leftarm_multi_02",
        "bd_death_leftarm_multi_03",
        "bd_death_leftarm_multi_04",
        "bd_death_leftarm_single_01",
        "bd_death_leftarm_single_02",
        "bd_death_leftarm_single_03",
        "bd_death_leftarm_short_01",
        "bd_death_leftarm_short_02",
        "bd_death_leftarm_short_03",
    },
    ["bd_rarm"] = {
        "bd_death_rightarm_01",
        "bd_death_rightarm_02",
        "bd_death_rightarm_multi_01",
        "bd_death_rightarm_multi_02",
        "bd_death_rightarm_single_01",
        "bd_death_rightarm_single_02",
        "bd_death_rightarm_single_03",
        "bd_death_rightarm_single_04",
    },
    ["bd_lleg"] = {
        "bd_death_leftleg_long_01",
        "bd_death_leftleg_long_02",
        "bd_death_leftleg_short_01",
        "bd_death_leftleg_short_02",
        "bd_death_leftleg_short_03",
        "bd_death_leftleg_short_04",
        "bd_death_leftleg_short_05",
        "bd_death_leftleg_short_06",
        "bd_death_leftleg_short_07",
        "bd_death_leftleg_short_08",
    },
    ["bd_rleg"] = {
        "bd_death_rightleg_multi_01",
        "bd_death_rightleg_multi_02",
        "bd_death_rightleg_multi_03",
        "bd_death_rightleg_short_01",
        "bd_death_rightleg_short_02",
        "bd_death_rightleg_single_01",
        "bd_death_rightleg_single_02",
        "bd_death_rightleg_single_03",
        "bd_death_rightleg_single_04",
        "bd_death_rightleg_single_05",
    },
}

local function ApplyRagdollSpasms(rag)
    if not IsValid(rag) then return end

    if math.random() > 0.7 then return end

    local spasmCount = math.random(5, 12)
    local spasmDelay = math.Rand(0.1, 0.3)

    timer.Create("RagdollSpasm_" .. rag:EntIndex(), spasmDelay, spasmCount, function()
        if not IsValid(rag) then return end

        local physCount = rag:GetPhysicsObjectCount()
        if physCount == 0 then return end

        local phys = rag:GetPhysicsObjectNum(math.random(0, physCount - 1))
        if IsValid(phys) then

            local force = VectorRand() * math.random(300, 800)
            phys:ApplyForceCenter(force)
        end
    end)
end

local LifeScale = 0.5
local CrawlChance = 10
local OtherAsDefault = false
local FaceExp = true
local DebugType = "none"
local AnimGenerate = true

local function choose_bd_anims(type, data)
    local anim = "dying1"
    local model = "models/brutal_deaths/model_anim.mdl"
    if DebugType != "none" then
        type = DebugType
    end
    if type == "fire" then
        anim = "bd_death_fire1"
    elseif type == "explosion" then
        anim = table.Random(bdtab["exp"])
    elseif type == "club" then
        anim = table.Random(bdtab["club"])
    elseif type == "crawling" then
        anim = "crawling"..math.random(6,7)
    elseif type == "moving" then
        anim = table.Random(bdtab["moving"])
    else
        anim = table.Random(bdtab["dying"])

        if data[1] == 1 then
            if data[2] then
                anim = table.Random(bdtab["bd_neck"])
            else
                anim = table.Random(bdtab["bd_head"])
            end
        elseif data[1] == 2 or data[1] == 3 then
            anim = table.Random(bdtab["bd_torso"])
        elseif data[1] == 4 then
            anim = table.Random(bdtab["bd_larm"])
        elseif data[1] == 5 then
            anim = table.Random(bdtab["bd_rarm"])
        elseif data[1] == 6 then
            anim = table.Random(bdtab["bd_lleg"])
        elseif data[1] == 7 then
            anim = table.Random(bdtab["bd_rleg"])
        end
    end
    return anim, model
end

local function play_anim_on_rag(rag, an, scale, rndang)
    if !IsValid(rag) then return end

    local tr2 = util.TraceLine( {
        start = rag:GetPos(),
        endpos = rag:GetPos()-Vector(0,0,50),
        mask = MASK_ALL,
        filter = function(ent)
            return ent != rag.AnimModule and ent != rag
        end
    })
    local pos = tr2.HitPos+Vector(0,0,2)

    if IsValid(rag.AnimModule) then
        rag.AnimModule:Remove()
    end
    local anim, mod = choose_bd_anims(an)
    local anm = ents.Create("bloodshed_ragdoll_animation")
    anm:SetPos(pos)
    anm:SetAngles(rag:GetAngles())
    if an == "crawling" then
        anm:SetAngles(rag:GetAngles()+Angle(0,math.random(-45,45),0))
    end
    if rndang then
        anm:SetAngles(rag:GetAngles()+Angle(0,math.random(0,360),0))
    end
    anm:Spawn()
    anm.Ragdoll = rag
    anm.Entity = nil
    anm:SetModel(mod)
    anm:ResetSequence(anim)
    anm.AnimString = anim
    anm.LerpScale = scale
    anm.FinishFunc = function()

    end

    rag.IsDeathRagdoll = true
    rag.RagHealth = rag.MaxRagHealth
    rag.AnimModule = anm
end

local function make_death_anim(ent, rag, type)
    local data = {ent.LastDamageHitgroup, ent.LastDamageIsNeck}
    if ent.LastDamageHitgroup == HITGROUP_HEAD and ent.LastDamageIsNeck then
        ent:GetBloodTrails("remove")
        rag:BloodTrailBone("ValveBiped.Bip01_Neck1", 10)
    end
    local anim, mod = choose_bd_anims(type, data)
    local anm = ents.Create("bloodshed_ragdoll_animation")
    anm:SetPos(rag:GetPos()-Vector(0,0,32))
    anm:SetAngles(ent:GetAngles())
    anm:Spawn()
    anm.Ragdoll = rag
    anm.Entity = nil
    anm:SetModel(mod)
    anm:ResetSequence(anim)
    anm.AnimGenerate = AnimGenerate
    anm.FinishFunc = function()
        if IsValid(rag) then
            ApplyRagdollSpasms(rag)
        end
    end
    local dur = select(2, anm:LookupSequence(anim))

    rag:SetFlexScale(0.4)
    rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
    if type == "fire" then
        rag:Ignite(30)
    end
    rag.IsDeathRagdoll = true
    rag.NPCClass = ent.GetNPCClass and ent:GetNPCClass() or ent.Classify and ent:Classify() or CLASS_BULLSEYE
    rag.RagHealth = ent:GetMaxHealth()*LifeScale
    rag.MaxRagHealth = rag.RagHealth
    rag.AnimModule = anm
    local physcount = rag:GetPhysicsObjectCount()
    for i = 0, physcount - 1 do
        local physObj = rag:GetPhysicsObjectNum(i)
        local pos, ang = ent:GetBonePosition(ent:TranslatePhysBoneToBone(i))
        if pos && ang then
            physObj:EnableMotion(true)
        end
    end
end

hook.Add("ScaleNPCDamage", "MuR_DeathAnimsBrutal", function(ent,hit, dmg)
	ent.LastDamageHitgroup = hit
    if ent:LookupBone("ValveBiped.Bip01_Head1") then
        ent.LastDamageIsNeck = dmg:GetDamagePosition().z < ent:GetBonePosition(ent:LookupBone("ValveBiped.Bip01_Head1")).z+2
    end
end)

hook.Add("ScalePlayerDamage", "MuR_DeathAnimsBrutal", function(ent,hit, dmg)
	ent.LastDamageHitgroup = hit
    if ent:LookupBone("ValveBiped.Bip01_Head1") then
        ent.LastDamageIsNeck = dmg:GetDamagePosition().z < ent:GetBonePosition(ent:LookupBone("ValveBiped.Bip01_Head1")).z+2
    end
end)

hook.Add("EntityTakeDamage", "MuR_DeathAnimsBrutal", function(ent, dmg)
    if ent.IsDeathRagdoll then
        ent.RagHealth = ent.RagHealth - dmg:GetDamage()
        if ent.RagHealth <= 0 and IsValid(ent.AnimModule) then
            ent.AnimModule:Remove()
        end
    end
    if MuR.IsAI(ent) and ent.IsPolice or ent:IsPlayer() then
        if dmg:GetDamageType() == DMG_BURN or ent:IsOnFire() then
            ent.DeathAnimType = "fire"
        elseif (dmg:GetDamageType() == 0 and !OtherAsDefault) or isfunction(ent.IsDowned) and ent:IsDowned() then
            ent.DeathAnimType = nil
        elseif dmg:IsExplosionDamage() or dmg:GetDamageType() == DMG_BLAST then
            ent.DeathAnimType = "explosion"
        elseif ent:IsOnGround() and (ent:IsPlayer() and ent:GetVelocity():Length() > ent:GetRunSpeed()-20 or MuR.IsAI(ent) and ent:GetIdealMoveSpeed() > 150) then
            ent.DeathAnimType = "moving"
        elseif dmg:IsBulletDamage() then
            ent.DeathAnimType = "bullet"
        elseif (dmg:GetDamageType() == DMG_CLUB or dmg:GetDamageType() == DMG_CRUSH) then
            ent.DeathAnimType = "club"
        elseif dmg:GetDamageType() == DMG_SLASH then
            ent.DeathAnimType = "slash"
        elseif OtherAsDefault then
            ent.DeathAnimType = "bullet"
        end
    end
end)

hook.Add("CreateEntityRagdoll", "MuR_DeathAnimsBrutal", function(ent, rag)
    if ent.DeathAnimType then
        if ent:IsPlayer() and ent:GetBloodTrails("Neck") then
            ent.LastDamageHitgroup, ent.LastDamageIsNeck = HITGROUP_HEAD, true
            ent.DeathAnimType = "bullet"
        end
        if !IsValid(rag) or MuR:CheckHeight(rag, MuR:BoneData(rag, "ValveBiped.Bip01_Pelvis")) <= 16 then return end
        local physcount = rag:GetPhysicsObjectCount()
        for i = 0, physcount - 1 do
            local physObj = rag:GetPhysicsObjectNum(i)
            local pos, ang = ent:GetBonePosition(ent:TranslatePhysBoneToBone(i))
            if pos && ang then
                physObj:EnableMotion(false)
            end
        end
        if !ent:IsPlayer() and (MuR.Gamemode != 14) then
            SafeRemoveEntityDelayed(rag, 15)
        elseif ent:IsPlayer() and ent:GetNW2Bool("IsUnconscious") then
            return
        end
        make_death_anim(ent, rag, ent.DeathAnimType)
    end
end)

hook.Add("PlayerDeath", "MuR_DeathRagdolls", function(ply)
    timer.Simple(0, function()
        if !IsValid(ply) then return end
        local rd = ply:GetNW2Entity("RD_EntCam")
        if IsValid(rd) then
            hook.Call("CreateEntityRagdoll", nil, ply, rd)

            local bleedLevel = ply:GetNW2Float("BleedLevel") or 0
            local hardBleed = ply:GetNW2Bool("HardBleed") or false

            if bleedLevel > 0 or hardBleed then
                rd.BleedingRagdoll = true
                rd.RagdollBleedLevel = bleedLevel
                rd.RagdollHardBleed = hardBleed

                timer.Create("RagdollBleeding_" .. rd:EntIndex(), 1, 0, function()
                    if not IsValid(rd) then
                        timer.Remove("RagdollBleeding_" .. rd:EntIndex())
                        return
                    end

                    if rd.RagdollHardBleed then
                        MuR:CreateBloodPool(rd, 0, math.random(2, 4))
                        rd:EmitSound("murdered/player/drip_" .. math.random(1, 5) .. ".wav", 60, math.random(60, 90))
                        if math.random(1, 3) == 1 then
                            rd:EmitSound("murdered/player/blood_drip_heavy.wav", 70, math.random(80, 120))
                        end
                    elseif rd.RagdollBleedLevel >= 3 then
                        MuR:CreateBloodPool(rd, 0, math.random(1, 3))
                        rd:EmitSound("murdered/player/drip_" .. math.random(1, 5) .. ".wav", 50, math.random(70, 110))
                    elseif rd.RagdollBleedLevel >= 2 then
                        if math.random(1, 2) == 1 then
                            MuR:CreateBloodPool(rd, 0, math.random(1, 2))
                            rd:EmitSound("murdered/player/drip_" .. math.random(1, 5) .. ".wav", 40, math.random(80, 120))
                        end
                    elseif rd.RagdollBleedLevel == 1 then
                        if math.random(1, 4) == 1 then
                            MuR:CreateBloodPool(rd, 0, 1)
                            rd:EmitSound("murdered/player/drip_" .. math.random(1, 5) .. ".wav", 30, math.random(90, 130))
                        end
                    end

                    rd.RagdollBleedLevel = math.max(rd.RagdollBleedLevel - 0.1, 0)
                    if rd.RagdollBleedLevel <= 0 and not rd.RagdollHardBleed then
                        timer.Remove("RagdollBleeding_" .. rd:EntIndex())
                    elseif rd.RagdollHardBleed and math.random(1, 10) == 1 then
                        rd.RagdollHardBleed = false
                        rd.RagdollBleedLevel = 2
                    end
                end)
            end
        end
    end)
end)
