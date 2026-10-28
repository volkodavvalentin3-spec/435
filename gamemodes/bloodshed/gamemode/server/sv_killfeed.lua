util.AddNetworkString("MuR.KillFeed")

hook.Add("PlayerDeath", "MuR.KillFeed", function(victim, inflictor, attacker)
    if not IsValid(victim) then return end

    net.Start("MuR.KillFeed")
    net.WriteEntity(victim)
    net.WriteEntity(attacker)
    net.WriteString(IsValid(inflictor) and inflictor:GetClass() or "")
    net.Broadcast()
end)
