LockpickingPlugin = LockpickingPlugin or PLUGIN

PLUGIN.name = "Lockpicking"
PLUGIN.author = "Abel Witz"
PLUGIN.desc = "Allows to pick locks with bobby pins"

PLUGIN.Config = {
    UnlockSize = 1,
    WeakSize = 20,
    UnlockMaxAngle = -90,
    HardMaxAngle = -30,
    TurningSpeed = 90,
    ReleasingSpeed = 200,
    SpamTime = 0.1,
	MaxLookDistance = 50,
	FadeTime = 4
}


-- Lockpick stop messages
PLUGIN.StopAfk = 1
PLUGIN.StopTooFar = 2

PLUGIN.Messages = {
	"lockpickingAfk",
	"lockpickingTooFar"
}

function PLUGIN:GetEntityLookedAt(player, maxDistance)
    local data = {}
    data.filter = player
    data.start = player:GetShootPos()
    data.endpos = data.start + player:GetAimVector()*maxDistance

    return util.TraceLine(data).Entity
end

nut.util.include("sv_sessions.lua")
nut.util.include("cl_session.lua")

nut.util.include("ui/cl_interface.lua")
nut.util.include("ui/cl_button.lua")
nut.util.include("ui/cl_label.lua")