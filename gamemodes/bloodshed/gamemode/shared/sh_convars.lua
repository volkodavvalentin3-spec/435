local convars = {
    ["blsd_execution_3rd_person"] = {
        help = "You can enable or disable thirdperson for execution cutscenes.",
        min = 0,
        max = 1,
        default = 1,
        type = "bool",
    },
    ["blsd_ragdoll_hold_grab"] = {
        help = "You can enable or disable hold for buttons that used for grabbing function in ragdoll state.",
        min = 0,
        max = 1,
        default = 0,
        type = "bool",
    },

    ["blsd_crosshair_ragdoll"] = {
        help = "You can enable or disable crosshair in ragdoll state.",
        min = 0,
        max = 1,
        default = 1,
        type = "bool",
    },
    ["blsd_nohud"] = {
        help = "You can enable or disable hud.",
        min = 0,
        max = 1,
        default = 0,
        type = "bool",
    },
    ["blsd_tpik"] = {
        help = "You can enable or disable Third Person Inverse Kinematics.",
        min = 0,
        max = 1,
        default = 1,
        type = "bool",
    },
    ["blsd_viewbob"] = {
        help = "You can enable or disable First Person Viewbob.",
        min = 0,
        max = 1,
        default = 1,
        type = "bool",
    },
    ["blsd_viewperson"] = {
        help = "You can change view for your camera.",
        min = 0,
        max = 2,
        default = 0,
        type = "integer",
    },

    ["blsd_character_female"] = {
        help = "You can change gender of your character.",
        min = 0,
        max = 1,
        default = 0,
        type = "bool",
    },
    ["blsd_character_name_male"] = {
        help = "You can change name of your male character.",
        default = "",
        type = "string",
    },
    ["blsd_character_name_female"] = {
        help = "You can change name of your female character.",
        default = "",
        type = "string",
    },
    ["blsd_character_pitch"] = {
        help = "You can change pitch for voice of your character.",
        min = 86,
        max = 114,
        default = 100,
        type = "integer",
    },
    ["blsd_character_executionstyle"] = {
        help = "You can change execution style for traitor role.",
        default = "default",
        type = "string",
    },

    ["blsd_killerclass_1"] = {
        help = "Killer class for the Classic and Wild West scenarios.",
        default = "murderer",
        type = "string",
    },
    ["blsd_killerclass_3"] = {
        help = "Killer class for the Serial Killer scenario.",
        default = "jason",
        type = "string",
    },
    ["blsd_killerclass_4"] = {
        help = "Killer class for the State of Emergency and VIP Protection scenarios.",
        default = "shooter",
        type = "string",
    },
}

if CLIENT then
    for name, tab in pairs(convars) do
        CreateConVar(name, tab.default, {FCVAR_ARCHIVE, FCVAR_USERINFO}, tab.help, tab.min, tab.max)
    end

    function MuR:GetClient(name)
        local con = GetConVar(name)
        local type = convars[name] and convars[name].type or "none"
        if type == "bool" then
            return con:GetBool()
        elseif type == "integer" then
            return con:GetInt()
        elseif type == "string" then
            return con:GetString()
        end
        return false
    end
end
