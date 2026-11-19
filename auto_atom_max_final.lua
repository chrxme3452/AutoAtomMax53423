-- =====================================================================
--  AUTO ATOM MAX - versione finale
--  Rayfield UI + auto-farm Atom Max / Dungeon
-- =====================================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ---------------------------------------------------------------------
-- Rayfield
-- ---------------------------------------------------------------------
local loaded, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not loaded or not Rayfield then
    warn("[Auto Atom Max] Impossibile caricare Rayfield: " .. tostring(Rayfield))
    return
end

local Window = Rayfield:CreateWindow({
    Name = "Auto Atom Max",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by You",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RayConfig",
        FileName = "AutoAtomMax",
    },
    Discord = { Enabled = false },
    KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 4483362458)

-- ---------------------------------------------------------------------
-- Helper: ricerca oggetti e remote (mai WaitForChild: niente blocchi infiniti)
-- ---------------------------------------------------------------------

-- Il nome del campo nel payload delle skill contiene una "e" cirillica:
-- e' scritto con gli escape decimali per non perderla copiando il file.
local TYPE_KEY = "Typ\208\181"

local function resolve(root, ...)
    local node = root
    for _, name in ipairs({ ... }) do
        node = node and node:FindFirstChild(name)
        if not node then
            return nil
        end
    end
    return node
end

local remoteCache = {}

-- Prova prima il nuovo percorso ReplicatedStorage.Network.<Service>.<RE|RF>.<Nome>,
-- poi il vecchio percorso Knit (Packages._Index...).
local function getRemote(service, folder, name)
    local key = service .. "/" .. folder .. "/" .. name
    local cached = remoteCache[key]
    if cached and cached.Parent then
        return cached
    end

    local remote = resolve(ReplicatedStorage, "Network", service, folder, name)
        or resolve(ReplicatedStorage, "Packages", "_Index", "sleitnick_knit@1.4.7", "knit", "Services", service, folder, name)

    remoteCache[key] = remote
    return remote
end

local function getSkillRemote()
    return resolve(ReplicatedStorage, "Remotes", "SkillRemote")
end

local function getCharacter()
    local folder = workspace:FindFirstChild("Characters")
    return (folder and folder:FindFirstChild(LocalPlayer.Name)) or LocalPlayer.Character
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getEventMobs()
    return resolve(workspace, "World Mobs", "Event Mobs")
end

local function getAtomMax()
    return resolve(workspace, "World Mobs", "Event Mobs", "Atom Max")
end

-- I buff stanno in Status > Buffs > <nome>: ricerca ricorsiva nel personaggio
local function hasBuff(char, name)
    return char:FindFirstChild(name, true) ~= nil
end

-- Lancia una skill con camera, posizione e mira presi in tempo reale
local function fireSkill(skillId, sendToggle)
    local remote = getSkillRemote()
    local root = getRoot()
    if not remote or not root then
        return false
    end

    local camera = workspace.CurrentCamera

    local payload = {
        Camera = camera and camera.CFrame or root.CFrame,
        SkillId = skillId,
        Began = true,
        CFrame = root.CFrame,
        Aim = root.Position + root.CFrame.LookVector * 50,
    }
    payload[TYPE_KEY] = 1

    if sendToggle then
        payload.Toggle = true
    end

    remote:FireServer(payload)
    return true
end

-- ---------------------------------------------------------------------
-- Motore dei cicli: un solo ciclo per funzione, anche se attivi/disattivi in fretta
-- ---------------------------------------------------------------------
local Running = {}
local LastError = {}

local function stopLoop(key)
    Running[key] = (Running[key] or 0) + 1
end

local function startLoop(key, interval, step)
    local id = (Running[key] or 0) + 1
    Running[key] = id

    local function isActive()
        return Running[key] == id
    end

    task.spawn(function()
        while isActive() do
            local ok, err = pcall(step, isActive)
            if not ok then
                local message = tostring(err)
                if LastError[key] ~= message then
                    LastError[key] = message
                    warn("[Auto Atom Max] " .. key .. ": " .. message)
                end
            end
            task.wait(interval)
        end
    end)
end

local function loopToggle(name, flag, interval, step)
    return MainTab:CreateToggle({
        Name = name,
        CurrentValue = false,
        Flag = flag,
        Callback = function(Value)
            if Value then
                startLoop(flag, interval, step)
            else
                stopLoop(flag)
            end
        end,
    })
end

-- ==================== AUTO RANGE ATOM ====================
loopToggle("Auto Range Atom", "AutoRangeAtom", 0.2, function()
    local atom = getAtomMax()
    if not atom then
        return
    end

    local hitbox = atom:FindFirstChild("Hitbox")
        or atom:FindFirstChild("HumanoidRootPart")
        or atom.PrimaryPart

    if hitbox and hitbox:IsA("BasePart") then
        hitbox.Size = Vector3.new(700, 700, 700)
        hitbox.CanCollide = false
        hitbox.Massless = true
    end
end)

-- ==================== AUTO TRINH (skill 101) ====================
loopToggle("Auto Trình", "AutoTrinh", 0.1, function()
    fireSkill("101")
end)

-- ==================== AUTO DANH THUONG (attacco base) ====================
loopToggle("Auto đánh thường", "AutoDanhThuong", 0.25, function()
    fireSkill("1")
end)

-- ==================== AUTO MODE (skill 10, solo se il Mode non e' attivo) ====================
-- Unisce i vecchi "Auto Phê Pha V2" e "Auto Mode": facevano la stessa cosa.
loopToggle("Auto Mode", "AutoMode", 1, function()
    local char = getCharacter()
    if char and not char:FindFirstChild("Mode") then
        fireSkill("10")
    end
end)

-- ==================== AUTO EQUIPTOOLS ====================
local SelectedTool = 2

MainTab:CreateDropdown({
    Name = "Auto EquipTools DLS",
    Options = { "1", "2", "3", "4", "5", "6" },
    CurrentOption = { "2" },
    MultipleOptions = false,
    Flag = "EquipToolDropdown",
    Callback = function(Options)
        local value = type(Options) == "table" and Options[1] or Options
        SelectedTool = tonumber(value) or SelectedTool
    end,
})

loopToggle("Auto EquipTools", "AutoEquipTools", 0.1, function()
    local remote = getRemote("ToolService", "RE", "UpdatePlayerToolbarSelection")
    if remote then
        remote:FireServer(SelectedTool)
    end
end)

-- ==================== AUTO NEXTAREA ====================
loopToggle("Auto NextArea", "AutoNextArea", 0.2, function()
    if type(fireproximityprompt) ~= "function" then
        return
    end

    local nextArea = resolve(workspace, "Dungeon", "Stages", "0", "NextArea")
    local container = nextArea and nextArea:FindFirstChild("Container")
    if not container or not container:GetChildren()[4] then
        return
    end

    local prompt = resolve(nextArea, "Part", "Attachment", "ProximityPrompt")
    if prompt then
        fireproximityprompt(prompt)
    end
end)

-- ==================== AUTO SKILL + GODMODE V2 ====================
local HEIGHT_ABOVE = 14        -- altezza sopra il boss
local SKILL_RANGE = 30         -- distanza massima per lanciare la skill
local SKILL_INTERVAL = 0.1     -- secondi tra una skill e l'altra

local godConnection = nil
local lastSkillTime = 0

MainTab:CreateToggle({
    Name = "Auto Skill + Godmode V2 (Chạy Liên Tục)",
    CurrentValue = false,
    Flag = "AutoGodmodeV2",
    Callback = function(Value)
        if godConnection then
            godConnection:Disconnect()
            godConnection = nil
        end

        if not Value then
            return
        end

        godConnection = RunService.Heartbeat:Connect(function()
            local hrp = getRoot()
            local bossFolder = getEventMobs()
            if not hrp or not bossFolder then
                return
            end

            -- boss vivo piu' vicino
            local closestRoot = nil
            local closestDist = math.huge

            for _, mob in ipairs(bossFolder:GetChildren()) do
                local humanoid = mob:FindFirstChildOfClass("Humanoid")
                local root = mob:FindFirstChild("HumanoidRootPart")
                if humanoid and root and humanoid.Health > 0 then
                    local dist = (hrp.Position - root.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestRoot = root
                    end
                end
            end

            if not closestRoot then
                return
            end

            -- resta sopra il boss, senza cadere e senza scatti
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(
                closestRoot.Position + Vector3.new(0, HEIGHT_ABOVE, 0),
                closestRoot.Position
            )

            -- skill solo quando e' vicino, con intervallo minimo
            local now = os.clock()
            if closestDist <= SKILL_RANGE and now - lastSkillTime >= SKILL_INTERVAL then
                lastSkillTime = now

                local remote = getRemote("SkillManagerV2", "RE", "ExecuteSkill")
                if remote then
                    pcall(function()
                        remote:FireServer("Weapons_20_3", { TargetPos = closestRoot.Position }, 18)
                    end)
                end
            end
        end)
    end,
})

-- ==================== AUTO STARTDUNGEON ATOM MAX ====================
-- Parte quando Atom Max e' a vita piena, aspetta che muoia, poi dopo 2.8s avvia il dungeon.
loopToggle("Auto StartDungeon Atom Max", "AutoStartDungeonAtomMax", 0.2, function(isActive)
    local atom = getAtomMax()
    local hum = atom and atom:FindFirstChildOfClass("Humanoid")

    if not hum or hum.MaxHealth <= 0 or hum.Health < hum.MaxHealth then
        return
    end

    while isActive() and hum.Parent and hum.Health > 0 do
        task.wait(0.2)
    end

    if not isActive() then
        return
    end

    task.wait(2.8)

    if not isActive() then
        return
    end

    local remote = getRemote("DungeonLobbyService", "RF", "StartDungeon")
    if remote then
        remote:InvokeServer()
    end
end)

-- ==================== AUTO LOCK ATOM ====================
loopToggle("Auto Lock Atom", "AutoLockAtom", 0.2, function()
    local atom = getAtomMax()
    if not atom then
        return
    end

    local remote = getRemote("SkillManager", "RE", "LockedOnChanged")
    if remote then
        remote:FireServer(atom)
    end
end)

-- ==================== PULSANTI DELL'INTERFACCIA (spunta / Play Again / Start) ====================
-- Percorsi a partire da LocalPlayer.PlayerGui.MainGui. Si clicca solo se il
-- pulsante e' davvero visibile (tutti i genitori visibili), cosi' non parte
-- nulla mentre la schermata e' chiusa.
local GuiService = game:GetService("GuiService")

local okVim, VirtualInputManager = pcall(function()
    return game:GetService("VirtualInputManager")
end)
if not okVim then
    VirtualInputManager = nil
end

local function getMainGui()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    return playerGui and playerGui:FindFirstChild("MainGui")
end

local function isGuiVisible(gui)
    local node = gui
    while node and not node:IsA("LayerCollector") do
        if node:IsA("GuiObject") and not node.Visible then
            return false
        end
        node = node.Parent
    end
    return node ~= nil and node.Enabled
end

local function guiText(gui)
    local text = gui:IsA("TextButton") and gui.Text or ""
    if text == "" then
        local label = gui:FindFirstChildWhichIsA("TextLabel", true)
        text = label and label.Text or ""
    end
    return text
end

local CLICK_SIGNALS = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" }

-- Clicca un pulsante: prima i suoi segnali (firesignal), poi, come ripiego,
-- un click reale al centro dell'elemento.
local function clickGui(target)
    if not target:IsA("GuiObject") then
        return false
    end

    local button = target:IsA("GuiButton") and target or target:FindFirstChildWhichIsA("GuiButton", true)

    if button and type(firesignal) == "function" then
        if type(getconnections) == "function" then
            -- scatta il primo segnale che ha davvero un collegamento
            for _, signalName in ipairs(CLICK_SIGNALS) do
                local ok, connections = pcall(getconnections, button[signalName])
                if ok and connections and #connections > 0 then
                    if pcall(firesignal, button[signalName]) then
                        return true
                    end
                end
            end
        else
            local fired = pcall(firesignal, button.Activated)
            fired = pcall(firesignal, button.MouseButton1Click) or fired
            if fired then
                return true
            end
        end
    end

    if VirtualInputManager then
        local position = target.AbsolutePosition
        local size = target.AbsoluteSize
        local screenGui = target:FindFirstAncestorWhichIsA("ScreenGui")
        local insetY = 0
        if not (screenGui and screenGui.IgnoreGuiInset) then
            insetY = GuiService:GetGuiInset().Y
        end

        local x = position.X + size.X / 2
        local y = position.Y + size.Y / 2 + insetY

        return pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
    end

    return false
end

-- Spunta delle ricompense (Rewards Collected)
local function findRewardCheck()
    return resolve(getMainGui(), "Frame", "Dungeon", "CenterFrame", "RewardFrame", "Frame", "ImageButton")
end

-- Play Again: dentro Dungeon.Frame ci sono due TextButton con lo stesso nome,
-- quindi lo riconosce dal testo ("Play Again").
local function findPlayAgain()
    local frame = resolve(getMainGui(), "Frame", "Dungeon", "Frame")
    if not frame then
        return nil
    end

    local buttons = {}
    local anyText = false

    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("TextButton") then
            table.insert(buttons, child)

            local text = string.lower(guiText(child))
            if text ~= "" then
                anyText = true
                if string.find(text, "play again", 1, true) then
                    return child
                end
            end
        end
    end

    -- se nessun pulsante ha un testo leggibile, usa il secondo (come in Explorer)
    if not anyText then
        return buttons[2]
    end

    return nil
end

-- Start della lobby del dungeon
local function findStart()
    return resolve(
        getMainGui(),
        "Frame", "Windows", "DungeonTeleporter", "Body", "DungeonPreview", "MapPanel", "Footer", "Start"
    )
end

local function buttonToggle(name, flag, interval, finder)
    loopToggle(name, flag, interval, function()
        local target = finder()
        if target and isGuiVisible(target) then
            clickGui(target)
        end
    end)
end

buttonToggle("Auto Spunta ricompense", "AutoRewardCheck", 0.5, findRewardCheck)
buttonToggle("Auto Play Again", "AutoPlayAgain", 1, findPlayAgain)
buttonToggle("Auto Start (pulsante lobby)", "AutoStartButton", 1, findStart)

-- ==================== AUTO FUSIONE (sempre attiva) + KAIOKEN (click) ====================
-- SkillId e nomi dei buff si possono cambiare anche dai campi di testo nella UI.
local Cfg = {
    Fusion = {
        SkillId = "9",              -- SkillId della Fusione (dal remote spy)
        Toggle = true,              -- la fusione manda anche il campo Toggle = true
        Buff = "FusionBuff",        -- Status > Buffs > FusionBuff
    },
    Kaioken = {
        SkillId = "8",              -- SkillId del Kaioken (nessun campo Toggle)
        Buff = "TechniqueBuff",     -- Status > Buffs > TechniqueBuff ("" = solo cooldown)
        Cooldown = 3,               -- secondi di attesa dopo ogni click
    },
}

-- ---------- FUSIONE ----------
-- E' un interruttore on/off: viene lanciata SOLO quando il buff non c'e'
-- (anche dopo morte/respawn). Se dopo 3 tentativi il buff non compare,
-- il toggle si spegne da solo: SkillId o nome buff sono sbagliati e
-- continuare accenderebbe/spegnerebbe la fusione a ripetizione.
local FusionToggle = nil
local fusionMisses = 0

local function stopFusion(title, content)
    stopLoop("AutoFusion")
    pcall(function()
        Rayfield:Notify({ Title = title, Content = content, Duration = 6 })
    end)
    if FusionToggle then
        FusionToggle:Set(false)
    end
end

local function fusionStep()
    if Cfg.Fusion.Buff == "" then
        stopFusion("Auto Fusione", "Inserisci il nome del buff: serve per sapere se la fusione è già attiva.")
        return
    end

    local char = getCharacter()
    if not char then
        return
    end

    if hasBuff(char, Cfg.Fusion.Buff) then
        fusionMisses = 0
        return
    end

    fireSkill(Cfg.Fusion.SkillId, Cfg.Fusion.Toggle)
    fusionMisses = fusionMisses + 1

    if fusionMisses >= 3 then
        stopFusion("Auto Fusione", "Il buff non compare dopo 3 tentativi: controlla SkillId e nome buff.")
        return
    end

    task.wait(2) -- tempo per far comparire il buff prima di ricontrollare
end

MainTab:CreateInput({
    Name = "Fusione - SkillId",
    CurrentValue = Cfg.Fusion.SkillId,
    PlaceholderText = "es. 9",
    RemoveTextAfterFocusLost = false,
    Flag = "FusionSkillId",
    Callback = function(Text)
        if Text ~= "" then
            Cfg.Fusion.SkillId = Text
        end
    end,
})

MainTab:CreateInput({
    Name = "Fusione - nome buff",
    CurrentValue = Cfg.Fusion.Buff,
    PlaceholderText = "nome oggetto nel personaggio",
    RemoveTextAfterFocusLost = false,
    Flag = "FusionBuffName",
    Callback = function(Text)
        Cfg.Fusion.Buff = Text
    end,
})

FusionToggle = MainTab:CreateToggle({
    Name = "Auto Fusione (sempre attiva)",
    CurrentValue = false,
    Flag = "AutoFusion",
    Callback = function(Value)
        if Value then
            fusionMisses = 0
            startLoop("AutoFusion", 0.5, fusionStep)
        else
            stopLoop("AutoFusion")
        end
    end,
})

-- ---------- KAIOKEN ----------
local function kaiokenStep()
    local char = getCharacter()
    if not char then
        return
    end

    local buff = Cfg.Kaioken.Buff
    if buff ~= "" and hasBuff(char, buff) then
        return
    end

    fireSkill(Cfg.Kaioken.SkillId, false)
    task.wait(Cfg.Kaioken.Cooldown)
end

MainTab:CreateInput({
    Name = "Kaioken - SkillId",
    CurrentValue = Cfg.Kaioken.SkillId,
    PlaceholderText = "es. 8",
    RemoveTextAfterFocusLost = false,
    Flag = "KaiokenSkillId",
    Callback = function(Text)
        if Text ~= "" then
            Cfg.Kaioken.SkillId = Text
        end
    end,
})

MainTab:CreateInput({
    Name = "Kaioken - nome buff (vuoto = solo cooldown)",
    CurrentValue = Cfg.Kaioken.Buff,
    PlaceholderText = "nome oggetto nel personaggio",
    RemoveTextAfterFocusLost = false,
    Flag = "KaiokenBuffName",
    Callback = function(Text)
        Cfg.Kaioken.Buff = Text
    end,
})

MainTab:CreateInput({
    Name = "Kaioken - cooldown click (secondi)",
    CurrentValue = tostring(Cfg.Kaioken.Cooldown),
    PlaceholderText = "es. 3",
    RemoveTextAfterFocusLost = false,
    Flag = "KaiokenCooldown",
    Callback = function(Text)
        local n = tonumber(Text)
        if n and n >= 0.5 then
            Cfg.Kaioken.Cooldown = n
        end
    end,
})

loopToggle("Auto Kaioken (click)", "AutoKaioken", 0.3, kaiokenStep)
