MuR.Roles = {}
MuR.RolesList = {}

function MuR:RegisterRole(data)
    MuR.Roles[data.name] = data
    table.insert(MuR.RolesList, data.name)
end

function MuR:GetRole(name)
    return MuR.Roles[name]
end

local files = file.Find("bloodshed/gamemode/roles/*.lua", "LUA")
for _, f in pairs(files) do
    if SERVER then
        AddCSLuaFile("bloodshed/gamemode/roles/" .. f)
    end
    include("bloodshed/gamemode/roles/" .. f)
end
