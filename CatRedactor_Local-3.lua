-- CatRedactor (всё в одном LocalScript, всё видишь только ты)
-- Тип: LocalScript  |  Куда: StarterPlayer > StarterPlayerScripts
-- В Workspace должна лежать модель (или Part) с именем "Cat". Лучше, чтобы она была Anchored.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

-- ===== НАСТРОЙКИ =====
local IMAGE_ID = "rbxassetid://136476233036438"
local SOUND_ID = "rbxassetid://88060724643515"
local TITLE_TEXT = "Котость.CatRedactor"
local LOAD_TIME = 5

local CAT_NAME = "Cat"
local SIZE_STEP = 0.5        -- на сколько меняется масштаб за одно нажатие
local MIN_SCALE = 0.2
local MAX_SCALE = 20
local CHARGE_TIME = 6        -- сколько секунд кот раскручивается
local PULL_TIME = 3          -- последние N секунд из них тебя тянет к коту
local KNOCK_DISTANCE = 40    -- откидывает на 40 блоков
local KNOCK_HEIGHT = 10      -- и на 10 блоков вверх
local RESPAWN_TIME = 4       -- через сколько секунд кот снова появляется
-- ======================

local player = Players.LocalPlayer

-- функции кота (заполним ниже, когда кот найдётся)
local Cat = {
	resize = function() end,
	resetSize = function() end,
	paint = function() end,
	resetColor = function() end,
	ultimate = function() end,
}

local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function corner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = obj
	return c
end

local gui = Instance.new("ScreenGui")
gui.Name = "CatRedactor"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------
-- ПАНЕЛЬ С КНОПКАМИ (создаём заранее, покажем после загрузки)
--------------------------------------------------------------------
local locked = false
local panelShown = false
local wraps = {}

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundTransparency = 1
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 16, 0.5, 0)
panel.Size = UDim2.fromOffset(240, 290)
panel.Parent = gui

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local function makeButton(text, order)
	local wrap = Instance.new("CanvasGroup")
	wrap.Size = UDim2.fromOffset(240, 50)
	wrap.BackgroundTransparency = 1
	wrap.GroupTransparency = 1
	wrap.LayoutOrder = order
	wrap.Parent = panel

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromScale(1, 1)
	btn.Position = UDim2.fromOffset(-50, 0)
	btn.BackgroundColor3 = Color3.fromRGB(34, 34, 48)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 18
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Text = text
	btn.Parent = wrap
	corner(btn, 12)

	table.insert(wraps, { wrap = wrap, btn = btn })
	return btn
end

local btnPlus = makeButton("+5 размер Cat", 1)
local btnMinus = makeButton("-5 размер Cat", 2)
local btnResetSize = makeButton("Вернуть размер Cat", 3)
local btnColor = makeButton("Выбрать цвет Cat", 4)
local btnUlt = makeButton("???", 5)

-- «???» плавно переливается чёрным и белым (текст меняет цвет в противофазе)
btnUlt.AutoButtonColor = false
btnUlt.TextSize = 26
RunService.RenderStepped:Connect(function()
	local s = math.sin(os.clock() * 1.6)
	local t = 0.5 + 0.5 * math.sign(s) * math.abs(s) ^ 0.6 -- дольше задерживается на чёрном и белом
	btnUlt.BackgroundColor3 = Color3.new(t, t, t)
	local c = t > 0.5 and 0 or 1
	btnUlt.TextColor3 = Color3.new(c, c, c)
end)

-- белая вспышка на весь экран (для взрыва)
local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 100
flash.Parent = gui

--------------------------------------------------------------------
-- ПАЛИТРА
--------------------------------------------------------------------
local palette = Instance.new("CanvasGroup")
palette.Name = "Palette"
palette.Size = UDim2.fromOffset(228, 236)
palette.AnchorPoint = Vector2.new(0, 0.5)
palette.Position = UDim2.new(0, 250, 0.5, 0)
palette.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
palette.BorderSizePixel = 0
palette.GroupTransparency = 1
palette.Visible = false
palette.Parent = gui
corner(palette, 14)

local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Position = UDim2.fromOffset(12, 12)
grid.Size = UDim2.fromOffset(204, 162)
grid.Parent = palette

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(36, 36)
gridLayout.CellPadding = UDim2.fromOffset(6, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local COLORS = {
	Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 128, 0), Color3.fromRGB(255, 221, 0),
	Color3.fromRGB(140, 255, 0), Color3.fromRGB(0, 200, 70), Color3.fromRGB(0, 220, 200),
	Color3.fromRGB(0, 150, 255), Color3.fromRGB(40, 70, 255), Color3.fromRGB(140, 60, 255),
	Color3.fromRGB(255, 0, 200), Color3.fromRGB(255, 105, 140), Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(200, 200, 200), Color3.fromRGB(120, 120, 120), Color3.fromRGB(50, 50, 50),
	Color3.fromRGB(0, 0, 0), Color3.fromRGB(139, 90, 43), Color3.fromRGB(255, 200, 150),
	Color3.fromRGB(100, 255, 150), Color3.fromRGB(255, 170, 255),
}

for i, color in ipairs(COLORS) do
	local sw = Instance.new("TextButton")
	sw.LayoutOrder = i
	sw.Text = ""
	sw.BackgroundColor3 = color
	sw.BorderSizePixel = 0
	sw.Parent = grid
	corner(sw, 8)
	sw.Activated:Connect(function()
		if locked then return end
		Cat.paint(color)
	end)
end

local resetBtn = Instance.new("TextButton")
resetBtn.Position = UDim2.fromOffset(12, 184)
resetBtn.Size = UDim2.fromOffset(204, 40)
resetBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
resetBtn.BorderSizePixel = 0
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 16
resetBtn.TextColor3 = Color3.new(1, 1, 1)
resetBtn.Text = "Вернуть прежний цвет"
resetBtn.Parent = palette
corner(resetBtn, 10)

local paletteOpen = false
local function setPalette(open)
	paletteOpen = open
	if open then
		palette.Visible = true
		palette.Position = UDim2.new(0, 250, 0.5, 0)
		tween(palette, 0.3, { GroupTransparency = 0, Position = UDim2.new(0, 268, 0.5, 0) })
	else
		local tw = tween(palette, 0.25, { GroupTransparency = 1, Position = UDim2.new(0, 250, 0.5, 0) })
		tw.Completed:Connect(function()
			if not paletteOpen then palette.Visible = false end
		end)
	end
end

local function setLocked(state)
	locked = state
	if not panelShown then return end
	if state then setPalette(false) end
	for _, w in ipairs(wraps) do
		tween(w.wrap, 0.25, { GroupTransparency = state and 0.6 or 0 })
	end
end

local function showPanel()
	panelShown = true
	for i, w in ipairs(wraps) do
		task.delay((i - 1) * 0.2, function()
			tween(w.wrap, 0.5, { GroupTransparency = locked and 0.6 or 0 })
			tween(w.btn, 0.5, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
		end)
	end
end

btnPlus.Activated:Connect(function()
	if locked then return end
	Cat.resize(1)
end)

btnMinus.Activated:Connect(function()
	if locked then return end
	Cat.resize(-1)
end)

btnResetSize.Activated:Connect(function()
	if locked then return end
	Cat.resetSize()
end)

btnColor.Activated:Connect(function()
	if locked then return end
	setPalette(not paletteOpen)
end)

resetBtn.Activated:Connect(function()
	if locked then return end
	Cat.resetColor()
end)

btnUlt.Activated:Connect(function()
	if locked then return end
	task.spawn(Cat.ultimate)
end)

--------------------------------------------------------------------
-- ФЕЙКОВАЯ ЗАГРУЗКА (5 секунд)
--------------------------------------------------------------------
local loading = Instance.new("CanvasGroup")
loading.Name = "Loading"
loading.Size = UDim2.fromScale(1, 1)
loading.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
loading.BorderSizePixel = 0
loading.Parent = gui

local logo = Instance.new("ImageLabel")
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Size = UDim2.fromOffset(160, 160)
logo.Position = UDim2.new(0.5, 0, -0.3, 0)
logo.BackgroundTransparency = 1
logo.Image = IMAGE_ID
logo.ImageTransparency = 1
logo.Parent = loading

local logoScale = Instance.new("UIScale")
logoScale.Parent = logo

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0.5, 150)
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 28
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = TITLE_TEXT
title.TextTransparency = 1
title.Parent = loading

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0)
barBack.Position = UDim2.new(0.5, 0, 0.5, 170)
barBack.Size = UDim2.fromOffset(240, 6)
barBack.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
barBack.BorderSizePixel = 0
barBack.Parent = loading
corner(barBack, 3)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.new(1, 1, 1)
barFill.BorderSizePixel = 0
barFill.Parent = barBack
corner(barFill, 3)

-- звук + пульсация картинки под звук
local sound = Instance.new("Sound")
sound.SoundId = SOUND_ID
sound.Looped = true
sound.Volume = 1
sound.Parent = SoundService
sound:Play()

local smooth = 0
local t0 = os.clock()
local pulseConn = RunService.RenderStepped:Connect(function(dt)
	local loud = math.clamp(sound.PlaybackLoudness / 500, 0, 1)
	smooth += (loud - smooth) * math.min(dt * 18, 1)
	local idle = 0.025 * math.sin((os.clock() - t0) * 6) -- лёгкая пульсация, даже если звук не загрузился
	logoScale.Scale = 1 + smooth * 0.3 + idle
end)

task.spawn(function()
	local start = os.clock()

	-- картинка плавно прилетает в центр
	tween(logo, 1.4, { Position = UDim2.fromScale(0.5, 0.5), ImageTransparency = 0 }, Enum.EasingStyle.Quint)
	task.wait(0.9)

	-- ниже появляется текст
	tween(title, 0.8, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 125) })
	task.wait(0.3)

	-- полоска идёт до конца загрузки
	tween(barFill, math.max(LOAD_TIME - (os.clock() - start), 0.1), { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	-- в последние полсекунды всё плавно гаснет
	task.wait(math.max(LOAD_TIME - 0.5 - (os.clock() - start), 0))
	tween(loading, 0.5, { GroupTransparency = 1 })
	tween(sound, 0.5, { Volume = 0 })
	task.wait(math.max(LOAD_TIME - (os.clock() - start), 0))

	pulseConn:Disconnect()
	sound:Stop()
	sound:Destroy()
	loading:Destroy()

	showPanel()
end)

--------------------------------------------------------------------
-- ПРИТЯГИВАНИЕ И ОТКИДЫВАНИЕ ИГРОКА
--------------------------------------------------------------------
local pullConn, pullLV, pullAO, pullAtt

local function getChar()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hrp, hum
end

local function stopPull()
	if pullConn then pullConn:Disconnect() pullConn = nil end
	if pullLV then pullLV:Destroy() pullLV = nil end
end

local function releaseFacing()
	if pullAO then pullAO:Destroy() pullAO = nil end
	if pullAtt then pullAtt:Destroy() pullAtt = nil end
	local _, hum = getChar()
	if hum then hum.AutoRotate = true end
end

-- тянет игрока к коту: персонаж остаётся на ногах, смотрит на кота и «прилипает»
local function startPull(targetPos, stickDist, duration)
	local hrp, hum = getChar()
	if not (hrp and hum) then return end
	stopPull()
	releaseFacing()

	hum.AutoRotate = false
	pullAtt = Instance.new("Attachment")
	pullAtt.Parent = hrp

	pullAO = Instance.new("AlignOrientation")
	pullAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
	pullAO.Attachment0 = pullAtt
	pullAO.RigidityEnabled = false
	pullAO.MaxTorque = 1e7
	pullAO.Responsiveness = 25
	pullAO.CFrame = hrp.CFrame.Rotation
	pullAO.Parent = hrp

	pullLV = Instance.new("LinearVelocity")
	pullLV.Attachment0 = pullAtt
	pullLV.MaxForce = math.huge
	pullLV.RelativeTo = Enum.ActuatorRelativeTo.World
	pullLV.VectorVelocity = Vector3.zero
	pullLV.Parent = hrp

	local startT = os.clock()
	pullConn = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startT
		if elapsed > duration or not hrp.Parent then
			stopPull()
			return
		end
		if hum:GetState() ~= Enum.HumanoidStateType.Freefall then
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end

		local offset = targetPos - hrp.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 0.1 then
			pullAO.CFrame = CFrame.lookAt(Vector3.zero, flat)
		end

		local dist = offset.Magnitude
		if dist > stickDist then
			-- разгоняется, а у самого кота плавно тормозит
			local speed = math.min(12 + elapsed * 40, 100, (dist - stickDist) * 8 + 3)
			pullLV.VectorVelocity = offset.Unit * speed
		else
			pullLV.VectorVelocity = Vector3.zero -- прилип
		end
	end)
end

local function knockback(fromPos)
	stopPull()
	local hrp, hum = getChar()
	if not (hrp and hum) then
		releaseFacing()
		return
	end

	local flat = Vector3.new(hrp.Position.X - fromPos.X, 0, hrp.Position.Z - fromPos.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, 1)
	end
	flat = flat.Unit

	-- скорость считаем так, чтобы улететь на KNOCK_DISTANCE вбок и подняться на KNOCK_HEIGHT
	local g = workspace.Gravity
	local vy = math.sqrt(2 * g * KNOCK_HEIGHT)
	local flightTime = 2 * vy / g
	local vx = KNOCK_DISTANCE / flightTime

	if pullAO then
		pullAO.CFrame = CFrame.lookAt(Vector3.zero, -flat) -- летит, глядя на взрыв
	end
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	hrp.AssemblyLinearVelocity = flat * vx + Vector3.new(0, vy, 0)

	task.delay(1, releaseFacing)
end

--------------------------------------------------------------------
-- МОДЕЛЬ CAT (все изменения только у тебя)
--------------------------------------------------------------------
local cat = workspace:WaitForChild(CAT_NAME, 15)
if not cat or not (cat:IsA("Model") or cat:IsA("BasePart")) then
	warn("[CatRedactor] В Workspace не найден Model/Part с именем '" .. CAT_NAME .. "'")
	return
end

-- запоминаем оригинал
local originalTransparency = {}
local originalCollide = {}
local colorTargets = {}

local function addTarget(inst, prop, isVector)
	local ok, value = pcall(function()
		return inst[prop]
	end)
	if ok and value ~= nil then
		table.insert(colorTargets, { inst = inst, prop = prop, original = value, vec = isVector })
	end
end

local items = cat:GetDescendants()
table.insert(items, cat)
for _, d in ipairs(items) do
	if d:IsA("BasePart") then
		originalTransparency[d] = d.Transparency
		originalCollide[d] = d.CanCollide
		addTarget(d, "Color")
	elseif d:IsA("Decal") or d:IsA("Texture") then
		originalTransparency[d] = d.Transparency
		addTarget(d, "Color3")
	elseif d:IsA("SurfaceAppearance") then
		addTarget(d, "Color")
	elseif d:IsA("SpecialMesh") then
		addTarget(d, "VertexColor", true)
	end
end

local isModel = cat:IsA("Model")
local originalSize = (not isModel) and cat.Size or nil
local baseScale = isModel and cat:GetScale() or 1
local targetScale = baseScale
local shownScale = baseScale

-- размер (низ кота остаётся на земле)
local function setScale(s)
	shownScale = s
	if isModel then
		local cf, size = cat:GetBoundingBox()
		local before = cf.Position
		local bottom = before.Y - size.Y / 2
		cat:ScaleTo(s)
		local cf2, size2 = cat:GetBoundingBox()
		local after = cf2.Position
		local bottom2 = after.Y - size2.Y / 2
		-- центр остаётся на месте, низ остаётся на земле
		cat:PivotTo(cat:GetPivot() + Vector3.new(before.X - after.X, bottom - bottom2, before.Z - after.Z))
	else
		local bottom = cat.Position.Y - cat.Size.Y / 2
		cat.Size = originalSize * s
		cat.CFrame = cat.CFrame + Vector3.new(0, bottom - (cat.Position.Y - cat.Size.Y / 2), 0)
	end
end

local scaleTween, scaleValue, scaleConn
local function stopScaleTween()
	if scaleTween then scaleTween:Cancel() scaleTween = nil end
	if scaleConn then scaleConn:Disconnect() scaleConn = nil end
	if scaleValue then scaleValue:Destroy() scaleValue = nil end
end

local function animateScale(target, time, style)
	stopScaleTween()
	local nv = Instance.new("NumberValue")
	nv.Value = shownScale
	scaleValue = nv
	scaleConn = nv.Changed:Connect(setScale)
	scaleTween = TweenService:Create(nv, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
	scaleTween:Play()
end

function Cat.resize(dir)
	targetScale = math.clamp(targetScale + dir * SIZE_STEP, MIN_SCALE, MAX_SCALE)
	animateScale(targetScale, 0.4)
end

function Cat.resetSize()
	targetScale = baseScale
	animateScale(targetScale, 0.4)
end

-- цвет: красим части, декали, текстуры, а сверху добавляем полупрозрачный оттенок,
-- чтобы цвет было видно даже у моделей с текстурами
local tintHL
local function applyTint(color)
	if color then
		if not tintHL then
			tintHL = Instance.new("Highlight")
			tintHL.Name = "CatTint"
			tintHL.FillColor = color
			tintHL.FillTransparency = 1
			tintHL.OutlineTransparency = 1
			tintHL.DepthMode = Enum.HighlightDepthMode.Occluded
			tintHL.Adornee = cat
			tintHL.Parent = workspace
		end
		tween(tintHL, 0.35, { FillColor = color, FillTransparency = 0.4 })
	elseif tintHL then
		tween(tintHL, 0.35, { FillTransparency = 1 })
	end
end

local function colorValue(target, color)
	if target.vec then
		return Vector3.new(color.R, color.G, color.B)
	end
	return color
end

function Cat.paint(color)
	for _, t in ipairs(colorTargets) do
		if t.inst.Parent then
			pcall(function()
				tween(t.inst, 0.35, { [t.prop] = colorValue(t, color) })
			end)
		end
	end
	applyTint(color)
end

function Cat.resetColor()
	for _, t in ipairs(colorTargets) do
		if t.inst.Parent then
			pcall(function()
				tween(t.inst, 0.35, { [t.prop] = t.original })
			end)
		end
	end
	applyTint(nil)
end

-- скрыть / показать кота
local function hideCat()
	for inst in pairs(originalTransparency) do
		if inst.Parent then
			inst.Transparency = 1
			if originalCollide[inst] ~= nil then inst.CanCollide = false end
		end
	end
end

local function showCat(animated)
	for inst, orig in pairs(originalTransparency) do
		if inst.Parent then
			if originalCollide[inst] ~= nil then inst.CanCollide = originalCollide[inst] end
			if animated then
				tween(inst, 0.6, { Transparency = orig })
			else
				inst.Transparency = orig
			end
		end
	end
end

--------------------------------------------------------------------
-- КНОПКА ??? (смешная версия: кот раскручивается и «извергает» коричневое)
--------------------------------------------------------------------
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local BROWN_LIGHT = Color3.fromRGB(139, 90, 43)
local BROWN_DARK = Color3.fromRGB(78, 48, 22)

local function getBox()
	if isModel then
		return cat:GetBoundingBox()
	end
	return cat.CFrame, cat.Size
end

local function newEffectPart(size, cf)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	return p
end

local function emitter(parent, cfg)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(cfg) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local function shake(hum, amp)
	if hum then
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, 0)
	end
end

local function heartbeat(phase)
	local b = (math.sin(phase) + 1) / 2
	return b * b
end

-- поворот кота вокруг вертикальной оси, проходящей через точку point
local function rotateAbout(point, angle)
	local rot = CFrame.new(point) * CFrame.Angles(0, angle, 0) * CFrame.new(-point)
	if isModel then
		cat:PivotTo(rot * cat:GetPivot())
	else
		cat.CFrame = rot * cat.CFrame
	end
end

local function restorePivot(cf)
	if isModel then
		cat:PivotTo(cf)
	else
		cat.CFrame = cf
	end
end

function Cat.ultimate()
	if locked then return end
	setLocked(true)

	stopScaleTween()
	setScale(targetScale)

	local cam = workspace.CurrentCamera
	local _, hum = getChar()
	local origFov = cam.FieldOfView
	local startPivot = isModel and cat:GetPivot() or cat.CFrame

	local junk = {}
	local function track(inst)
		table.insert(junk, inst)
		return inst
	end

	local ok, err = pcall(function()
		local cf, size = getBox()
		local center = cf.Position
		local radius = math.max(size.X, size.Y, size.Z) / 2
		local base = targetScale

		-- часть над котом: свет и «столб» дыма вверх
		local fx = track(newEffectPart(Vector3.new(size.X * 0.6, 0.5, size.Z * 0.6), CFrame.new(center + Vector3.new(0, size.Y / 2, 0))))
		fx.Name = "CatFX"
		fx.Parent = workspace

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(190, 120, 50)
		light.Brightness = 0
		light.Range = 8
		light.Shadows = false
		light.Parent = fx

		-- кот постепенно покрывается коричневым
		local mud = Instance.new("Highlight")
		mud.FillColor = BROWN_LIGHT
		mud.OutlineColor = BROWN_DARK
		mud.FillTransparency = 1
		mud.OutlineTransparency = 1
		mud.DepthMode = Enum.HighlightDepthMode.Occluded
		mud.Adornee = cat
		mud.Parent = fx

		-- коричневый оттенок всего экрана
		local cc = track(Instance.new("ColorCorrectionEffect"))
		cc.Parent = Lighting

		-- «сопло» в центре кота: вращается вместе с ним, струи получаются спиралью
		local nozzle = track(newEffectPart(Vector3.one * radius * 0.4, CFrame.new(center)))
		nozzle.Name = "CatNozzle"
		nozzle.Parent = workspace

		local function jetConfig(face)
			return {
				Texture = SMOKE,
				Rate = 0,
				EmissionDirection = face,
				SpreadAngle = Vector2.new(10, 10),
				Lifetime = NumberRange.new(1.2, 1.8),
				Speed = NumberRange.new(radius * 3, radius * 5),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-60, 60),
				LightEmission = 0,
				LightInfluence = 1,
				Color = ColorSequence.new(BROWN_LIGHT, BROWN_DARK),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, radius * 0.5),
					NumberSequenceKeypoint.new(1, radius * 2.2),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.15),
					NumberSequenceKeypoint.new(0.7, 0.5),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}
		end
		local jetA = emitter(nozzle, jetConfig(Enum.NormalId.Right))
		local jetB = emitter(nozzle, jetConfig(Enum.NormalId.Left))

		-- брызги коричневых комков
		local chunks = emitter(nozzle, {
			Texture = SMOKE,
			Rate = 0,
			SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(radius * 4, radius * 8),
			Acceleration = Vector3.new(0, -workspace.Gravity * 0.5, 0),
			LightEmission = 0,
			LightInfluence = 1,
			Color = ColorSequence.new(BROWN_DARK, BROWN_LIGHT),
			Size = NumberSequence.new(math.max(radius * 0.3, 0.35)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.8, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})

		-- столб дыма вверх
		local plume = emitter(fx, {
			Texture = SMOKE,
			Rate = 0,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(35, 35),
			Lifetime = NumberRange.new(1.5, 2.2),
			Speed = NumberRange.new(radius * 1.5, radius * 3),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-30, 30),
			LightInfluence = 1,
			Color = ColorSequence.new(BROWN_LIGHT, BROWN_DARK),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, radius * 0.8),
				NumberSequenceKeypoint.new(1, radius * 3),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})

		-- коричневое облако, которое втягивается внутрь, пока тебя тянет к коту
		local intake = track(newEffectPart(Vector3.one * radius * 7, CFrame.new(center)))
		intake.Name = "CatIntake"
		intake.Parent = workspace
		local intakeEm = emitter(intake, {
			Texture = SMOKE,
			Enabled = false,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			Rate = 40,
			Lifetime = NumberRange.new(1.0, 1.2),
			Speed = NumberRange.new(radius * 3, radius * 3.4),
			LightInfluence = 1,
			Color = ColorSequence.new(BROWN_LIGHT, BROWN_DARK),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, math.max(radius * 0.5, 0.5)),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})

		-- 1) раскрутка: чем дальше, тем быстрее вращается и тем больше коричневого
		local t, phase, angle = 0, 0, 0
		local pulling = false
		while t < CHARGE_TIME do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			local K = math.clamp(t / CHARGE_TIME, 0, 1)

			if not pulling and t >= CHARGE_TIME - PULL_TIME then
				pulling = true
				intakeEm.Enabled = true
				startPull(center, radius + 3, PULL_TIME + 0.4)
			end

			local da = (1 + 34 * K * K) * dt -- угловая скорость растёт от 1 до 35 рад/с
			angle += da
			phase += dt * (5 + 14 * K)
			setScale(base * (1 + (0.03 + 0.17 * K) * heartbeat(phase))) -- кот раздувается
			rotateAbout(center, da)
			nozzle.CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0)

			local strong = K ^ 1.5
			jetA.Rate = 3 + 70 * strong
			jetB.Rate = 3 + 70 * strong
			plume.Rate = 2 + 45 * strong
			chunks.Rate = 40 * K * K
			local speed = NumberRange.new(radius * (2 + 3 * K), radius * (3.5 + 5 * K))
			jetA.Speed = speed
			jetB.Speed = speed

			light.Brightness = 0.5 + 4 * K
			light.Range = math.clamp(radius * (3 + 4 * K), 8, 50)
			mud.FillTransparency = 1 - 0.65 * K
			mud.OutlineTransparency = 1 - 0.6 * K
			cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 222, 180), K)
			cc.Saturation = -0.2 * K
			cam.FieldOfView = origFov - 10 * K
			shake(hum, 0.03 + 0.22 * K)
		end

		-- 1.5) перед взрывом кот на миг сжимается, продолжая крутиться
		jetA.Rate = 120
		jetB.Rate = 120
		t = 0
		while t < 0.25 do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			local k = math.clamp(t / 0.25, 0, 1)
			local da = 35 * dt
			angle += da
			rotateAbout(center, da)
			nozzle.CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0)
			setScale(base * (1 - 0.45 * k * k))
			mud.FillTransparency = 0.35 - 0.25 * k
			light.Brightness = 4.5 + 10 * k
			shake(hum, 0.25 + 0.25 * k)
		end

		-- 2) взрыв (без урона)
		setScale(base)
		restorePivot(startPivot) -- кот перестаёт быть повёрнутым
		mud:Destroy()
		jetA.Rate = 0
		jetB.Rate = 0
		plume.Rate = 0
		chunks.Rate = 0
		intakeEm.Enabled = false
		if tintHL then tintHL.Enabled = false end

		local ex = Instance.new("Explosion")
		ex.Position = center
		ex.BlastRadius = math.min(100, radius * 2)
		ex.BlastPressure = 0
		ex.DestroyJointRadiusPercent = 0
		ex.ExplosionType = Enum.ExplosionType.NoCraters
		ex.Parent = workspace

		hideCat()

		-- коричневая вспышка на весь экран, удар по камере
		flash.BackgroundColor3 = Color3.fromRGB(125, 80, 38)
		flash.BackgroundTransparency = 0
		tween(flash, 1.4, { BackgroundTransparency = 1 })
		tween(cc, 1.4, { TintColor = Color3.new(1, 1, 1), Saturation = 0 })
		cam.FieldOfView = origFov + 18
		tween(cam, 1.0, { FieldOfView = origFov }, Enum.EasingStyle.Quint)

		light.Brightness = 20
		light.Range = 50
		tween(light, 0.9, { Brightness = 0 })

		-- ударная волна из «грязи»
		local wave = track(newEffectPart(Vector3.one * radius * 2, CFrame.new(center)))
		wave.Name = "CatWave"
		wave.Shape = Enum.PartType.Ball
		wave.Material = Enum.Material.Mud
		wave.Color = BROWN_LIGHT
		wave.Transparency = 0.15
		wave.Parent = workspace
		tween(wave, 0.7, { Size = Vector3.one * radius * 26, Transparency = 1 }, Enum.EasingStyle.Quint)

		-- брызги и клубы дыма во все стороны
		chunks:Emit(260)
		plume:Emit(50)
		local blast = emitter(fx, {
			Texture = SMOKE,
			Enabled = false,
			Rate = 0,
			SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(1.0, 1.8),
			Speed = NumberRange.new(radius * 3, radius * 7),
			Rotation = NumberRange.new(0, 360),
			LightInfluence = 1,
			Color = ColorSequence.new(BROWN_LIGHT, BROWN_DARK),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, radius * 2),
				NumberSequenceKeypoint.new(1, radius * 6),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
		blast:Emit(60)

		-- откидывание: 40 блоков в сторону и 10 вверх
		knockback(center)

		-- тряска камеры затухает
		local shakeT = 0
		while shakeT < 0.7 do
			local dt = RunService.Heartbeat:Wait()
			shakeT += dt
			shake(hum, 0.6 * (1 - shakeT / 0.7))
		end
		if hum then hum.CameraOffset = Vector3.zero end

		-- 3) кот возвращается: «выпрыгивает» из ничего
		task.wait(math.max(RESPAWN_TIME - 0.7, 0))
		if tintHL then tintHL.Enabled = true end
		setScale(base * 0.2)
		showCat(true)
		animateScale(base, 0.7, Enum.EasingStyle.Back)
		task.wait(0.9)
	end)

	if not ok then
		warn("[CatRedactor] Ошибка в кнопке ???: ", err)
		stopPull()
		releaseFacing()
		stopScaleTween()
		setScale(targetScale)
		restorePivot(startPivot)
		showCat(false)
		if tintHL then tintHL.Enabled = true end
		flash.BackgroundTransparency = 1
	end

	for _, inst in ipairs(junk) do
		inst:Destroy()
	end
	cam.FieldOfView = origFov
	if hum then hum.CameraOffset = Vector3.zero end

	setLocked(false)
end
