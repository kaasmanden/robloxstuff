local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

local canAffectLocalPlayer = true
local shouldOutput = true
local prefix = "?"
local admins = {
	1990326539;
	game.Players.LocalPlayer.UserId;
}

local LocalPlayer: Player? = Players.LocalPlayer
local LocalCharacter: Model? = LocalPlayer.Character

local followConn: RBXScriptConnection? = nil
local stareConn: RBXScriptConnection? = nil

local commandFunctions: {(target: Player, arg1: string, arg2: string) -> (boolean)} = {
	["fling"] = function(target)
		if not target then
			warn("Target player not found!")
			return false
		end

		local LocalPlayer = game.Players.LocalPlayer
		local Character = LocalPlayer.Character
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		local RootPart = Humanoid and Humanoid.RootPart

		local TargetCharacter = target.Character
		if not Character or not Humanoid or not RootPart then
			warn("Local character not ready")
			return false
		end

		if not TargetCharacter then
			warn("Target character not found")
			return false
		end

		local TargetHumanoid = TargetCharacter:FindFirstChildOfClass("Humanoid")
		local TargetRootPart = TargetHumanoid and TargetHumanoid.RootPart
		local TargetHead = TargetCharacter:FindFirstChild("Head")

		local Accessory = TargetCharacter:FindFirstChildOfClass("Accessory")
		local Handle = Accessory and Accessory:FindFirstChild("Handle")

		if TargetHumanoid and TargetHumanoid.Sit then
			warn(`${target.Name} is sitting`)
			return false
		end

		local OriginalPosition = RootPart.CFrame

		local function flingPosition(part, offset, rotation)
			local cf = CFrame.new(part.Position) * offset * rotation

			RootPart.CFrame = cf
			Character:SetPrimaryPartCFrame(cf)

			RootPart.Velocity = Vector3.new(9e7, 9e7, 9e7)
			RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
		end

		local function flingPart(part)
			local startTime = tick()
			local angle = 0

			repeat
				if not RootPart or not TargetHumanoid then
					break
				end

				if part.Velocity.Magnitude < 50 then
					angle += 100

					for _, y in ipairs({1.5, -1.5, 1.5, -1.5}) do
						flingPosition(
							part,
							CFrame.new(0, y, 0) + TargetHumanoid.MoveDirection * (part.Velocity.Magnitude / 1.25),
							CFrame.Angles(math.rad(angle), 0, 0)
						)
						task.wait()
					end
				else
					for _, data in ipairs({
						{1.5, TargetHumanoid.WalkSpeed, math.rad(90)},
						{-1.5, -TargetHumanoid.WalkSpeed, 0},
						{1.5, TargetHumanoid.WalkSpeed, math.rad(90)},
						}) do
						flingPosition(
							part,
							CFrame.new(0, data[1], data[2]),
							CFrame.Angles(data[3], 0, 0)
						)
						task.wait()
					end
				end
			until tick() - startTime > 2
		end

		--workspace.FallenPartsDestroyHeight = math.huge

		local BodyVelocity = Instance.new("BodyVelocity")
		BodyVelocity.Parent = RootPart
		BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		BodyVelocity.Velocity = Vector3.zero

		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

		local TargetPart = TargetRootPart or TargetHead or Handle

		if not TargetPart then
			BodyVelocity:Destroy()
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

			warn(`${target.Name} has no valid fling part`)
			return false
		end

		flingPart(TargetPart)

		BodyVelocity:Destroy()
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

		RootPart.CFrame = OriginalPosition

		for _, part in ipairs(Character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Velocity = Vector3.zero
				part.RotVelocity = Vector3.zero
			end
		end

		return true
	end;

	["talk"] = function(message: string)
		sendMessage(message)
		return true
	end;

	["tp"] = function(target)
		local targetCharacter = target.Character
		if not targetCharacter then
			return false
		end

		LocalCharacter:PivotTo(targetCharacter:GetPivot())
	end,
	
	["chase"] = function(target, guard: string?)
		if followConn then
			followConn:Disconnect()
			followConn = nil
		end

		---- Jump configuration
		--local lastJumpTime = 0
		--local JUMP_COOLDOWN = 0 -- Seconds to wait between jumps

		local lastCheckTime = os.clock()
		local lastTargetPos = nil

		followConn = RunService.RenderStepped:Connect(function()
			local localCharacter = LocalCharacter

			local targetChar: Model? = target.Character
			if not targetChar then
				warn(`No target character found`)
				return false
			end

			local targetCharacter = targetChar

			if not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") or not targetCharacter or not targetCharacter:FindFirstChild("HumanoidRootPart") then
				followConn:Disconnect()
				return false
			end

			local curPv = localCharacter:GetPivot()
			local targetPv = targetCharacter:GetPivot()

			local currentTime = os.clock()

			if (curPv.Y + 1 < targetPv.Y) and (currentTime - lastJumpTime >= JUMP_COOLDOWN) then
				localCharacter.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				lastJumpTime = currentTime
			end

			local endPos

			if guard and guard ~= "" then
				endPos = (targetCharacter.HumanoidRootPart.CFrame * CFrame.new(Vector3.new(3, 0, 2))).Position
				localCharacter.Humanoid:MoveTo(endPos)
			else
				endPos = targetCharacter.HumanoidRootPart.Position
				localCharacter.Humanoid:MoveTo(endPos)
			end

			local targetHum = targetCharacter:FindFirstChildOfClass("Humanoid")
			local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")

			if targetHum and targetRoot then

				local dist = (localCharacter.PrimaryPart.Position - endPos).Magnitude

				if dist < 1 then
					local root = localCharacter.HumanoidRootPart

					local lookVector = targetRoot.CFrame.LookVector

					local targetFacing = CFrame.lookAt(
						root.Position,
						root.Position + Vector3.new(lookVector.X, 0, lookVector.Z)
					)

					root.CFrame = root.CFrame:Lerp(targetFacing, 0.25)
				elseif dist > 20 then
					localCharacter:PivotTo(targetRoot.CFrame)
				elseif dist > 10 then
					if currentTime - lastCheckTime >= 1 then
						local movedDist = (targetRoot.Position - lastTargetPos).Magnitude

						if movedDist <= 3 then
							localCharacter:PivotTo(targetRoot.CFrame)
						end

						lastTargetPos = targetRoot.Position
						lastCheckTime = currentTime
					end
				end

				if not lastTargetPos then
					lastTargetPos = targetRoot.Position
				end
			end
		end)
	end,
	
	["schase"] = function()
		if followConn then
			followConn:Disconnect()
			followConn = nil
		end
		
		local hum: Humanoid = LocalCharacter:WaitForChild("Humanoid", 3)
		if hum then
			hum:MoveTo(hum.RootPart.Position)
		end
		
		return true
	end,
	
	["r"] = function()
		local hum: Humanoid = LocalCharacter:WaitForChild("Humanoid", 3)
		if hum then
			hum.Health = 0
		end
	end,
	
	["output"] = function()
		shouldOutput = not shouldOutput
	end,
	
	["stare"] = function(targetPlayer)
		if stareConn then
			stareConn:Disconnect()
			stareConn = nil
		end

		stareConn = RunService.RenderStepped:Connect(function(dt)
			local localChar = LocalCharacter
			local targetChar = targetPlayer.Character

			if not localChar or not targetChar then
				return
			end

			local root = localChar:FindFirstChild("HumanoidRootPart")
			local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")

			if not root or not targetRoot then
				return
			end

			local targetCFrame = CFrame.lookAt(
				root.Position,
				Vector3.new(
					targetRoot.Position.X,
					root.Position.Y,
					targetRoot.Position.Z
				)
			)

			root.CFrame = root.CFrame:Lerp(targetCFrame, math.clamp(dt * 10, 0, 1))
		end)

		return true
	end,
	
	["ststare"] = function(targetPlayer)
		if stareConn then
			stareConn:Disconnect()
			stareConn = nil
		end
	end,
}

function sendMessage(message)
	TextChatService.TextChannels.RBXGeneral:SendAsync(message);
end

function getPlayer(userId: number) : (Player)
	return Players:GetPlayerByUserId(userId)
end

function getPlayerByUnfinishedName(name: string) : (Player?)
	for _, player in pairs(Players:GetPlayers()) do
		if string.find(string.lower(player.Name), name) then
			return player
		end
	end

	for _, player in pairs(Players:GetPlayers()) do
		if string.find(string.lower(player.DisplayName), name) then
			return player
		end
	end

	return nil
end

function getPlayerByName(name: string) : (Player?)
	if name == "r" then
		return Players:GetPlayers()[math.random(1,#Players:GetPlayers())]
	end
	
	local nameLowercase = string.lower(name)

	for _, player in pairs(Players:GetPlayers()) do
		if nameLowercase == string.lower(player.Name) then
			return player
		end
	end

	for _, player in pairs(Players:GetPlayers()) do
		if nameLowercase == string.lower(player.DisplayName) then
			return player
		end
	end

	return getPlayerByUnfinishedName(nameLowercase)
end

local commandsRequiringTarget = {
	fling = true,
	--talk = true,
	tp = true,
	chase = true,
	stare = true,
}

function onAdminMessageSent(userId: number, text: string)
	if text:sub(1, 1) ~= prefix then
		return
	end

	local textNoPrefix = text:sub(2)
	local splitText: {string} = string.split(textNoPrefix, " ")

	local commandName: string = splitText[1] or ""

	local commandFunction = commandFunctions[commandName]
	if not commandFunction then
		warn(`Command {commandName} not found!`)
		return
	end

	local targetPlayer: Player? = nil

	if commandsRequiringTarget[commandName] then
		local targetName = splitText[2]

		if not targetName or targetName == "" then
			warn(`Command {commandName} requires a target!`)
			return
		end

		targetPlayer = getPlayerByName(targetName)

		if not targetPlayer or (not canAffectLocalPlayer and targetPlayer == LocalPlayer) then
			warn(`No target player found or target player is the Local Player`)
			return
		end
	end

	local restOfMessage = textNoPrefix:match("^%S+%s+%S+%s+(.+)$") or ""

	if targetPlayer then
		print(`Executing {commandName} on {targetPlayer.Name}`)
		task.spawn(commandFunction, targetPlayer, restOfMessage)
		
		if shouldOutput then
			sendMessage(`Executing {commandName} on {targetPlayer.Name}`)
		end
	else
		print(`Executing {commandName}`)
		task.spawn(commandFunction)
		
		if shouldOutput then
			sendMessage(`Executing {commandName}`)
		end
	end
	
end

TextChatService.MessageReceived:Connect(function(message: TextChatMessage)
	local senderTextSource: TextSource? = message.TextSource
	if not senderTextSource then return end
	if table.find(admins, senderTextSource.UserId) then
		onAdminMessageSent(senderTextSource.UserId, message.Text, message)
	end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
	LocalCharacter = char
end)

warn(`Initiated script`)
