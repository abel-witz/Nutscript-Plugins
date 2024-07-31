local PLUGIN = PLUGIN

----------------------------------
--[[ Create / Delete sessions ]]--
----------------------------------
PLUGIN.ServerSessions = PLUGIN.ServerSessions or {}

function PLUGIN:StartServerSession(door, client, item)
	local session = setmetatable({}, self.ServerSessionClass)

	session:Link(door, client, item)
	self.ServerSessions[session] = true
	session:StartingAction()
	
    return session
end

function PLUGIN:StopServerSession(session)
    session:Unlink()
    self.ServerSessions[session] = nil
    session = nil
end


------------------------------
--[[ Server session class ]]--
------------------------------
local Class = PLUGIN.ServerSessionClass or {}
Class.__index = Class
Class.Sounds = {}
Class.InnerLockAngle = 0
Class.PinAngle = 0
Class.Freeze = true


-- Link the session instance to the concerned objects (item, entity, player)
function Class:Link(door, client, item)
    self.Door = door
	self.Player = client
    self.Item = item
    client.LockpickingSession = self
    door.LockpickingSession = self
    item.LockpickingSession = self
end

-- Unink the session instance from the concerned objects (item, entity, player)
function Class:Unlink()
    local door = self.Door
    if ( IsValid(door) ) then
        door.LockpickingSession = nil
    end

    local client = self.Player
    if ( IsValid(client) ) then
        client.LockpickingSession = nil
    end

    local item = self.Item
    if ( item ) then
        item.LockpickingSession = nil
    end
end

-- Start the lockpicking session
function Class:Start()
	local cfg = PLUGIN.Config

	-- Generate unlock zone
	self.UnlockCenter = math.random(-180, 180)
	self.UnlockLimitA = self.UnlockCenter - cfg.UnlockSize
	self.UnlockLimitB = self.UnlockCenter + cfg.UnlockSize
	self.WeakLimitA = self.UnlockCenter - cfg.WeakSize
	self.WeakLimitB = self.UnlockCenter + cfg.WeakSize
	
	self.Freeze = false
	self.LastActivity = CurTime()
	netstream.Start(client, "lockpickingStart", self.Item:getID())
end

-- Stop the lockpicking session
function Class:Stop(share, msg)
    local cfg = PLUGIN.Config
	local client = self.Player
	local item = self.Item

	if ( self.ChangingPin ) then client:setAction() end -- Stop bobbypin changing action
	self:StopSound("tension")
	timer.Remove("lockpickingEnterSound")
	self:StopSound("enter")

	-- Unfreeze player and restore his old weapon after the ScreenFade is done
	timer.Simple(cfg.FadeTime,function()
		client:SelectWeapon(self.OldWep)
		timer.Simple(0.1, function()
			client:setWepRaised(self.OldWepRaise)
		end)
	end)
	
	if ( share ) then
		netstream.Start(client, "lockpickingStop", msg) -- Tell the client to stop the interface
	end

	-- Share rounded bobbypin health to client
	local oldHealth = item:getData("health", 100)
	item:setData("health", math.Round(oldHealth))
	item:setData("health", oldHealth, false)
	
	PLUGIN:StopServerSession(self)
end

local function netLag(player)
	return player:Ping() / 2000
end

-- Insert bobbypin
function Class:StartingAction()
    local cfg = PLUGIN.Config
	local client = self.Player
	local door = self.Door

		local wep = client:GetActiveWeapon()
		if (IsValid(wep)) then
			self.OldWep = wep:GetClass()
		end
		self.OldWepRaise = client:isWepRaised()
		client:SelectWeapon( "nut_hands" )

	local time = 1.2
	client:setAction("@lockpickingStarting", time)
	client:doStaredAction(door, function()
		if (IsValid(client)) then
            self:Start()
			client:setAction()
		end
	end, time, function()
		if (IsValid(client)) then
			client:setAction()
		end

		netstream.Start(client, "lockpickingStarting", false)
        PLUGIN:StopServerSession(self)
	end, cfg.MaxLookDistance)

	timer.Create("lockpickingEnterSound", time - 1, 1, function()
		self:PlaySound("lockpicking/enter.wav", 50, 1, "enter")
	end)

	netstream.Start(client, "lockpickingStarting", true, time - netLag(client))
end


-- Change bobbypin
function Class:ChangePinAction()
	local client = self.Player

	self.RotatingLock = false
	self.ChangingPin = true

	local time = 1.2
	timer.Create("lockpickingEnterSound", time - 1, 1, function()
		self:PlaySound("lockpicking/enter.wav", 50, 1, "enter")
	end)

	client:setAction("@lockpickingChange", time, function()
		self.ChangingPin = false
		self.Freeze = false
	end)

	netstream.Start(client, "lockpickingChange", time - netLag(client))
end


-- Play a lockpicking sound that can be stopped whenever we want
function Class:PlaySound(soundName, soundLevel, volume, id)
	local filter = RecipientFilter()
	filter:AddAllPlayers()
	filter:RemovePlayer( self.Player )
	
	local sound = CreateSound(self.Door, soundName, filter)
	sound:ChangeVolume(volume)
	sound:SetSoundLevel(soundLevel)
	sound:Play()
		
	if (id) then
		if ( not self.Door.LockpickSounds ) then
			self.Door.LockpickSounds = {}
		end
			
		self.Door.LockpickSounds[id] = sound
	end
end

-- Stop a lockpicking sound
function Class:StopSound(id)
	local e = self.Door
	local sounds = e.LockpickSounds

	if (sounds and sounds[id]) then
		sounds[id]:Stop()
		sounds[id] = nil
	end
end


-- Success hook
function Class:Success()
	self:StopSound("tension")
	self:PlaySound("lockpicking/unlock.wav", 50, 1)

	-- Unlock the door
	local door = self.Door
	if (IsValid(door:getDoorPartner())) then
		door:getDoorPartner():Fire("unlock")
	end

	door:Fire("unlock")

	-- Freeze and stop the session
	self.Freeze = true
	timer.Simple(0.5, function()
		self:Stop(true)
	end)
end


-- Fail hook
function Class:Fail()
	self:PlaySound("lockpicking/pickbreak_"..math.random(3)..".wav", 50, 1)
	
	-- Reinsert another bobbypin
	if (self.Item:PinBreak()) then
		self:ChangePinAction()
	else
		self:Stop()
		netstream.Start(self.Player, "lockpickingFail")
	end
end


-- Divide an angle to send it little by little to the client ( avoid cheating, the client need to wait while rotating the lock to know the angle limit )
function Class:MakeShareTable(maxAng)
	local cfg = PLUGIN.Config

	self.ShareTable = {}
	local tbl = self.ShareTable

	local angAmount = math.ceil(maxAng / -30)
	local index = 0

	for i=1, angAmount do
		local realAng = ((i - 1) * -30) + (math.max(maxAng - (i-1) * -30, -30))

		if (realAng ~= cfg.HardMaxAngle) then
			index = index + 1
			tbl[index] = {}
			tbl[index].RealAng = realAng
		end
	end

	tbl.AngAmount = index
end

-- Send an angle little by little ( avoid cheating, the client need to wait while rotating the lock to know the angle limit )
function Class:ShareAngle(maxAng)
	local cfg = PLUGIN.Config
	local tbl = self.ShareTable

	if (not tbl or tbl.Done) then return end

	local client = self.Player
	local latency = netLag(client)

	local angAmount = tbl.AngAmount

	for i=angAmount or 0, 1, -1 do
		local ang = tbl[i]

		if (not ang.Sent) then
			local realAng = tbl[i].RealAng
			local curAng = self.InnerLockAngle
			local limit = math.min(realAng + 30, 0)

			if (math.abs((limit - curAng) / cfg.TurningSpeed) - 0.12 > latency) then
				ang.Sent = true
				ang.SendTime = SysTime()
				netstream.Start(client, "lockpickingMax", self.PinAngle, realAng)

				if (i == angAmount) then
					tbl.Done = true
				end

				break
			end
		end
	end
end

-- Know the angle that have the client ( Sets the angle limit to the current client angle )
function Class:GetClientMaxAng()
	local cfg = PLUGIN.Config
	local tbl = self.ShareTable
	PrintTable(tbl)

	if (tbl) then
		local client = self.Player
		local latency = netLag(client)

		local angAmount = tbl.AngAmount
		for i=angAmount or 0, 1, -1 do
			local ang = tbl[i]
			local realAng = tbl[i].RealAng
			local isLastAng = (i == angAmount)

			if (ang.Received) then
				return realAng, isLastAng
			end

			if (ang.Sent) then
				if (SysTime() > ang.SendTime + latency) then
					ang.Received = true
					return realAng, isLastAng
				end
			end
		end

		if (angAmount == 0) then
			return cfg.HardMaxAngle, true
		end
	end
	
	return cfg.HardMaxAngle, false
end


local ZONE_UNLOCK = 1
local ZONE_WEAK_LEFT = 2
local ZONE_WEAK_RIGHT = 3
local ZONE_HARD = 4
function Class:GetLockZone()
	local ang = self.PinAngle

	if (ang > self.UnlockLimitA and ang < self.UnlockLimitB) then
		return ZONE_UNLOCK
	elseif (ang > self.WeakLimitA and ang < self.UnlockLimitA) then
		return ZONE_WEAK_LEFT
	elseif (ang < self.WeakLimitB and ang > self.UnlockLimitB) then
		return ZONE_WEAK_RIGHT
	else
		return ZONE_HARD
	end
end


function Class:GetMaxInnerLockAngle(zone)
	local cfg = PLUGIN.Config

	if (zone == ZONE_UNLOCK) then
		return cfg.UnlockMaxAngle
	elseif (zone == ZONE_WEAK_LEFT) then
		return math.min(cfg.UnlockMaxAngle * (1 - ((self.UnlockLimitA - self.PinAngle) / (cfg.WeakSize - cfg.UnlockSize))), cfg.HardMaxAngle)
	elseif (zone == ZONE_WEAK_RIGHT) then
		return math.min(cfg.UnlockMaxAngle * (1 - math.abs((self.UnlockLimitB - self.PinAngle) / (cfg.WeakSize - cfg.UnlockSize))), cfg.HardMaxAngle)
	else
		return cfg.HardMaxAngle
	end
end


-- Rotate hook
function Class:RotateLock(state, pickAng)
	local cfg = PLUGIN.Config
	local client = self.Player
	local latency = netLag(client)
	local time = CurTime()

	if (state and not self.ChangingPin) then
		if (pickAng and self.InnerLockAngle == 0) then
			
			self.PinAngle = pickAng

			local zone = self:GetLockZone()
			local maxAng = self:GetMaxInnerLockAngle(zone)

			if (not self.OldPinAngle or (self.OldPinAngle ~= self.PinAngle)) then
				self:MakeShareTable(maxAng)
			end
			self.OldPinAngle = pickAng

			local ang, isLastAng = self:GetClientMaxAng()
			self.InnerLockAngle = math.max(latency * -cfg.TurningSpeed, ang)

			-- Avoid spamming requests of the unlock angle
			if (self.LastRotating and (time - self.LastRotating < cfg.SpamTime)) then
				self:Stop()
				return
			end

			self.LastRotating = time
			self.RotatingLock = true
		end
	else
		self.InnerLockAngle = math.min(self.InnerLockAngle + (latency * cfg.ReleasingSpeed), 0)
		self.RotatingLock = false
	end

	self.LastActivity = time
end



-- Check that we can continue to lockpick
function Class:StopCheck()
	local cfg = PLUGIN.Config
	local client = self.Player
	local door = self.Door
	local time = CurTime()
	
	if ( not ( IsValid(client) and IsValid(door) and self.Item ) ) then
		self:Stop()
		return
	end

	-- Avoid afk
	if ( (time - self.LastActivity) > 20 ) then
        self:Stop(true, PLUGIN.StopAfk)
		return
	end

	-- Check that the player is looking the door and near from it
	if ( time > (self.NextDistCheck or 0) ) then
		if (PLUGIN:GetEntityLookedAt(client, cfg.MaxLookDistance) ~= door) then
            self:Stop(true, PLUGIN.StopTooFar)
            return
		end

		self.NextDistCheck = time + 0.1
	end
end

function Class:Think()
	local cfg = PLUGIN.Config

	self:StopCheck()

	-- Send max angle little by little to the player
	local zone = self:GetLockZone()
	self:ShareAngle( self:GetMaxInnerLockAngle(zone) )

	local curMaxInnerLockAngle, isLastAng = self:GetClientMaxAng()
	local exceedMax
	
	if (self.RotatingLock and not self.ChangingPin) then
		self.InnerLockAngle = self.InnerLockAngle - cfg.TurningSpeed * FrameTime()
		
		-- Check if the lock is forced
        if (self.InnerLockAngle < curMaxInnerLockAngle) then
            self.InnerLockAngle = curMaxInnerLockAngle

			exceedMax = true
		end
		
        if (not self.CylinderTurned) then
            self.CylinderTurned = true

			self:PlaySound("lockpicking/cylinderturn_"..math.random(8)..".wav", 50, 1, "cylinder")
			self:PlaySound("lockpicking/cylindersqueak_"..math.random(7)..".wav", 50, 1, "squeak")
		end
		
	else
		self.InnerLockAngle = self.InnerLockAngle + ( cfg.ReleasingSpeed * FrameTime())
		self.InnerLockAngle = math.min(self.InnerLockAngle, 0)
		self.CylinderTurned = false

		self:StopSound("cylinder")
		self:StopSound("squeak")
	end

	if (exceedMax) then
        if (self.AskingSuccess and self.InnerLockAngle == cfg.UnlockMaxAngle) then
            self:Success()
		else
			if ( not self.CylinderStopped ) then
				self.HoldTime = SysTime()
                self.CylinderStopped = true
                
				self:PlaySound("lockpicking/picktension.wav", 50, 1, "tension")
				self:PlaySound("lockpicking/cylinderstop_"..math.random(4)..".wav", 50, 1)
			end

			if ((SysTime() - self.HoldTime > (netLag(self.Player)) + 0.1)) then
				local item = self.Item

				local newHealth = item:getData("health", 100) - 65 * FrameTime()
				item:setData("health", newHealth, false)

				if (newHealth <= 0) then
					self:Fail()
				end
			end
		end
	else
		self.CylinderStopped = false
        self.HoldTime = nil
        
		self:StopSound("tension")
	end
end


PLUGIN.ServerSessionClass = Class



---------------------
--[[ Networking ]]---
---------------------
netstream.Hook("lockpickingRotate", function(client, state, pickAng)
	local session = client.LockpickingSession

	if ( session ) then
		session:RotateLock(state, pickAng)
	end
end)


netstream.Hook("lockpickingStop", function(client)
	local session = client.LockpickingSession

	if (session) then
		session:Stop()
	end
end)


netstream.Hook("lockpickingSuccess", function(client)
	local session = client.LockpickingSession

	if (session) then
		session.AskingSuccess = true
	end
end)



----------------
--[[ Hooks ]]---
----------------
function PLUGIN:Think()
	for session, _ in pairs(self.ServerSessions) do
		if ( session.Freeze ) then return end
		session:Think()
	end
end


local allowCommand
function PLUGIN:StartCommand(client, cmd)
	if ( not allowCommand and client.LockpickFreeze ) then
        cmd:SetButtons(0)
    end

    allowCommand = false
end

function PLUGIN:Move(client, mvd)
    if ( client.LockpickingSession ) then
        return true
    end
end

function PLUGIN:PlayerSwitchWeapon(client, oldWep, newWep)
    local allowCommand = (newWep:GetClass() == "nut_hands")

	if ( not allowCommand and client.LockpickingSession ) then
        return true
    end
end



--------------------------------------------
--[[ Events that must stop lockpicking ]]---
--------------------------------------------
function PLUGIN:EntityRemoved(ent)
    local session = ent.LockpickingSession

	if (session) then
        session:Stop()
	end
end

function PLUGIN:PlayerDeath(client, inflictor, attacker)
    local session = client.LockpickingSession

	if (session) then
        session:Stop()
	end
end

function PLUGIN:PlayerDisconnected(client)
    local session = client.LockpickingSession

	if (session) then
        session:Stop()
	end
end

resource.AddWorkshop( "2318212263" ) -- NS Lockpicking Content