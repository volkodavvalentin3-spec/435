local function CallEffects(ply)
    local rnd = math.random(1,18)
    net.Start("MuR.WeaponryEffect")
    net.WriteInt(rnd, 32)
    net.Send(ply)
end

hook.Add("PlayerPostThink", "MuR.TraitorThinking", function(ply)
    if not MuR.Chem then return end

    local potency = MuR.Chem:GetPotency(ply, "pcp")
    if potency < 0.25 then return end

    if ply.PoisonVoiceTime and ply.PoisonVoiceTime >= CurTime() then return end

    ply.PoisonVoiceTime = CurTime() + math.Rand(15, 45) / math.max(potency, 0.25)
    CallEffects(ply)
end)
