AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include('shared.lua')


function ENT:Initialize()
    self:SetModel("models/props_lab/citizenradio.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
end


function ENT:Use(activator, caller)
    if ( IsValid(caller) ) then
        local oldState = self:getNetVar("power")

        self:setNetVar("power", !oldState)
    end
end