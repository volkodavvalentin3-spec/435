local ROLE = {}

ROLE.name = "Entity"
ROLE.team = 1
ROLE.flashlight = false
ROLE.models = {"models/player/charple.mdl"}
ROLE.health = 100
ROLE.langName = "entity"
ROLE.color = Color(100, 0, 0)
ROLE.desc = "entity_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("mur_entity_abilities", true)
    ply:GiveWeapon("mur_hands", true)
    ply:SetRunSpeed(500)
    ply:SetWalkSpeed(250)
    ply:SetJumpPower(400)
    ply:SetRenderMode(RENDERMODE_TRANSALPHA)
	ply:SetColor(Color(255, 255, 255, 0))
	ply:SetNoDraw(true)
    timer.Simple(1, function()
        if !IsValid(ply) then return end
        ply:SelectWeapon("mur_entity_abilities")
        ply:StripWeapon("mur_hands")
        ply:SetNWString("Name", "")
    end)
end

MuR:RegisterRole(ROLE)
