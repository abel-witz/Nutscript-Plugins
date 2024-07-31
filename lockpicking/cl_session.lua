local PLUGIN = PLUGIN
PLUGIN.ClientSession = PLUGIN.ClientSession

---------------------------------
--[[ Create / Delete session ]]--
---------------------------------
function PLUGIN:CreateClientSession()
    self.ClientSession = setmetatable({}, self.ClientSessionClass)
    return self.ClientSession
end

function PLUGIN:DeleteClientSession()
	PLUGIN.ClientSession = nil
end

------------------------------
--[[ Client session class ]]--
------------------------------
local Class = PLUGIN.ClientSessionClass or {}
Class.__index = Class
Class.Sounds = {}
Class.InnerLockAngle = 0
Class.OldPinRotation = 0
Class.NextPickSound = 1.5


-- Open session panel and enable lock movements
function Class:Start()
	self.Panel = vgui.Create("lockpickingInterface")
end

-- Close session panel and disable lock movements
function Class:Stop(share, message)
    if ( IsValid(self.Panel) ) then
        self.Panel:Remove()
	end

    self:StopSound("tension")

	-- Stop hooks
	if ( message )  then
		nut.util.notify(L(PLUGIN.Messages[msg]))
	end

    if ( share ) then
        netstream.Start("lockpickingStop")
	end
	
    PLUGIN:DeleteClientSession()
end


-- Insert bobbypin
function Class:StartingAction(state, enterMoment)
    if (state) then
		if (enterMoment) then
			timer.Create("lockpickingEnterSound", enterMoment - 1, 1, function()
				self:PlaySound("lockpicking/enter.wav", 50, 1, "enter")
			end)
		end

		if (IsValid(nut.gui.menu)) then
			nut.gui.menu:Remove()
		end
	end
end

-- Change bobbypin
function Class:ChangePinAction(time)
	self.RotatingLock = false
	self.ChangingPin = true
	timer.Simple(time, function()
		self.ChangingPin = false
	end)

	self:PlaySound("lockpicking/pickbreak_"..math.random(3)..".wav", 50, 1)

	timer.Create("lockpickingEnterSound" ,time - 1, 1, function()
		self:PlaySound("lockpicking/enter.wav", 50, 1, "enter")
	end)
end


-- Play a lockpicking sound that can be stopped whenever we want
function Class:PlaySound(soundName, soundLevel, volume, id)
    local sound = CreateSound(LocalPlayer(), soundName)
	sound:ChangeVolume(volume)
	sound:SetSoundLevel(soundLevel)
	sound:Play()
        
    local sounds = self.Sounds
	if (id) then
		sounds[id] = sound
    end
end

-- Stop a lockpicking sound
function Class:StopSound(id)
	local sounds = self.Sounds
	if (sounds[id]) then
		sounds[id]:Stop()
		sounds[id] = nil
	end
end


-- Cylinder movement
function Class:Think()
	local cfg = PLUGIN.Config

	self.MaxInnerLockAngle = self.MaxInnerLockAngle or cfg.HardMaxAngle

	self.exceedMax = false
	if (not self.Success) then
		if (self.RotatingLock and not self.ChangingPin) then
			self.InnerLockAngle = self.InnerLockAngle - (cfg.TurningSpeed * FrameTime())

			if (self.InnerLockAngle < self.MaxInnerLockAngle) then
				self.exceedMax = true
				self.InnerLockAngle = self.MaxInnerLockAngle
			end

			if (not self.CylinderTurned) then
				self:PlaySound("lockpicking/cylinderturn_"..math.random(8)..".wav", 50, 1, "cylinder")
				self:PlaySound("lockpicking/a/cylindersqueak_"..math.random(7)..".wav", 50, 1, "squeak")

				self.CylinderTurned = true
			end
		else
			self.InnerLockAngle = self.InnerLockAngle + (cfg.ReleasingSpeed * FrameTime())
			self.InnerLockAngle = math.min(self.InnerLockAngle, 0)
			self.CylinderTurned = nil

			self:StopSound("cylinder")
			self:StopSound("squeak")
		end
	end

	if (self.exceedMax) then
		if (self.InnerLockAngle <= cfg.UnlockMaxAngle) then
			self.Success = true
			netstream.Start("lockpickingSuccess")
			self:PlaySound("lockpicking/unlock.wav", 50, 1)
		else
			if (not self.CylinderStopped) then
				self.CylinderStopped = true

				self:PlaySound("lockpicking/picktension.wav", 50, 1, "tension")
				self:PlaySound("lockpicking/cylinderstop_"..math.random(4)..".wav", 50, 1)
			end
		end
		
	else
		self.CylinderStopped = false
		self:StopSound("tension")
	end
	
	-- Draw the bobbypin
	if (not self.RotatingLock and not self.Success and not self.ChangingPin) then
		local mX, mY = gui.MouseX(), gui.MouseY()
		self.PinAngle = math.deg(math.atan2(mY - ScrH() / 2, mX - ScrW() / 2))
			
		if (self.OldPinRotation ~= self.PinAngle) then
			self.MaxInnerLockAngle = nil
			self.LastPickMove = CurTime()

			if (CurTime() > self.NextPickSound) then
				self.NextPickSound = CurTime() + math.Rand(0.5, 1)
				self:PlaySound("lockpicking/pickmovement_"..math.random(13)..".wav", 50, 1)
			end
				
			self.OldPinRotation = self.PinAngle
		end
	end
end


PLUGIN.ClientSessionClass = Class



----------------
--[[ Hooks ]]---
----------------
-- Handle lock rotation and interface closing
function PLUGIN:PlayerButtonDown(client, btn)
	local cfg = self.Config
    local session = self.ClientSession

	if ( not session ) then return end

    local panel = session.Panel

	if (btn == KEY_D) then
		if (session.InnerLockAngle ~= 0) then return end
		if (session.Success) then return end
		if (session.ChangingPin) then return end
		if (session.LastRotating and CurTime() - session.LastRotating < cfg.SpamTime + 0.08) then return end

		netstream.Start("lockpickingRotate", true, session.PinAngle)

		session.LastRotating = CurTime()
		session.RotatingLock = true
	elseif (btn == KEY_E) then
		session:Stop(true)
	end
end

-- Stop lock rotation
function PLUGIN:PlayerButtonUp(client, btn)
	local session = self.ClientSession
    if ( not session ) then return end
    
	if (btn == KEY_D) then
		if (not session.RotatingLock) then return end
		if (session.Success) then return end
		if (session.ChangingPin) then return end

		netstream.Start("lockpickingRotate", false)

		session.RotatingLock = false
	end
end


local allowCommand
function PLUGIN:StartCommand(client, cmd)
	if ( not allowCommand and self.ClientSession and client == LocalPlayer() ) then
        cmd:SetButtons(0)
    end

    allowCommand = false
end

function PLUGIN:Move(client, mvd)
    if ( self.ClientSession and client == LocalPlayer() ) then
        return true
    end
end

function PLUGIN:PlayerSwitchWeapon(client, oldWep, newWep)
    local allowCommand = ( newWep:GetClass() == "nut_hands" )

	if ( not allowCommand and self.ClientSession and client == LocalPlayer() ) then
        return true
    end
end



--------------------
--[[ Networking ]]--
--------------------
netstream.Hook("lockpickingStarting", function(state, enterMoment)
    local session = PLUGIN:CreateClientSession()
    session:StartingAction(state, enterMoment)
end)


netstream.Hook("lockpickingChange", function(time)
    local session = PLUGIN.ClientSession
    if ( not session ) then return end

    session:ChangePinAction(time)
end)


netstream.Hook("lockpickingStart", function(itemId)
    local session = PLUGIN.ClientSession
	if ( not session ) then return end
	local item = nut.item.instances[itemId]
	if ( not item ) then return end

	session.Item = item
    session:Start()
end)

netstream.Hook("lockpickingStop", function(reason)
	local session = PLUGIN.ClientSession
    if ( not session ) then return end

    session:Stop(false, reason)
end)


netstream.Hook("lockpickingMax", function(pickAng, ang)
	local session = PLUGIN.ClientSession
    if ( not session ) then return end

	if (tostring(pickAng) == tostring(session.PinAngle)) then
		session.MaxInnerLockAngle = ang
	end
end)


netstream.Hook("lockpickingFail", function()
	local session = PLUGIN.ClientSession
	if ( not session ) then return end
	
	session:PlaySound("lockpicking/pickbreak_"..math.random(3)..".wav", 50, 1)
	session:Stop()
end)