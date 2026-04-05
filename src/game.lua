-- src/game.lua: Master state machine and game loop orchestration.
--
-- States: MENU → MODE_SELECT → SERVE → PLAYING → POINT_SCORED
--         → SUDDEN_DEATH → GAME_OVER
--
-- Exposes: Game.load(), .update(dt), .draw(),
--          .keypressed(key), .keyreleased(key), .mousepressed(x,y,btn),
--          .mousemoved(x,y)

local C       = require("src.constants")
local Assets  = require("src.assets")
local Ball    = require("src.ball")
local Player  = require("src.player")
local AI      = require("src.ai")
local Hud     = require("src.hud")
local Storage = require("src.storage")

local Game = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Menu button zones (screen-space, after scaling menu_background to 800×600)
-- ─────────────────────────────────────────────────────────────────────────────
local MENU_BUTTONS = {
    { id = "start",   x = 42,  y = 510, w = 175, h = 65 },
    { id = "options", x = 237, y = 510, w = 175, h = 65 },
    { id = "credits", x = 432, y = 510, w = 175, h = 65 },
    { id = "exit",    x = 627, y = 510, w = 175, h = 65 },
}

-- Mode-select overlay buttons (computed at draw time, stored for hit testing)
local MODE_BUTTONS = {
    { id = "pvp", x = 160, y = 260, w = 180, h = 56 },
    { id = "cpu", x = 460, y = 260, w = 180, h = 56 },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Initialise / load
-- ─────────────────────────────────────────────────────────────────────────────

function Game.load()
    Assets.load()

    -- Court background: scale uniformly to fill the 600 px window height,
    -- then centre horizontally (crops left/right edges of the wide gym image).
    Game.courtBgScale = 600 / Assets.courtBg:getHeight()
    Game.courtBgOffX  = math.floor((800 - Assets.courtBg:getWidth() * Game.courtBgScale) / 2)

    -- Menu background: stretch to fill 800×600 exactly (it's designed for that).
    Game.menuScaleX = 800 / Assets.menuBg:getWidth()
    Game.menuScaleY = 600 / Assets.menuBg:getHeight()

    -- Default scores and state
    Game.scores      = { 0, 0 }
    Game.matchTimer  = C.MATCH_TIME
    Game.state       = "MENU"
    Game.mode        = "pvp"
    Game.lastScorer  = nil
    Game.flashTimer  = 0
    Game.stateTimer  = 0   -- general countdown for timed states
    Game.winner      = nil
    Game.matchHistory = {}
    Game.hoveredBtn  = nil

    -- Screen shake
    Game.shakeTimer  = 0
    Game.shakeX      = 0
    Game.shakeY      = 0

    -- Match start time (for duration tracking)
    Game.matchStartTime = love.timer.getTime()

    -- Players (controls assigned; AI overrides p2 input in CPU mode)
    Game.players = {
        Player.new(1, { left = "a", right = "d", jump = "w",
                        dig = "s", hit = "lshift" }),
        Player.new(2, { left = "left", right = "right", jump = "up",
                        dig = "down", hit = "rctrl" }),
    }
    Game.ai   = AI.new()
    Game.ball = Ball.new()
    Game.ball:reset(1)

    -- Spike-landing flag (set by ball physics, consumed by game for screen shake)
    Game._lastSpike = false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal: reset for a new match
-- ─────────────────────────────────────────────────────────────────────────────

local function resetMatch(server)
    Game.scores      = { 0, 0 }
    Game.matchTimer  = C.MATCH_TIME
    Game.lastScorer  = nil
    Game.flashTimer  = 0
    Game.winner      = nil
    Game.matchStartTime = love.timer.getTime()
    Game.ai          = AI.new()
    for _, p in ipairs(Game.players) do p:reset() end
    Game.ball = Ball.new()
    Game.ball:reset(server or 1)
    Game.state     = "SERVE"
    Game.stateTimer = C.SERVE_DELAY
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal: set up SERVE state after a point
-- ─────────────────────────────────────────────────────────────────────────────

local function enterServe(server)
    for _, p in ipairs(Game.players) do p:reset() end
    Game.ball = Ball.new()
    Game.ball:reset(server)
    Game.state      = "SERVE"
    Game.stateTimer = C.SERVE_DELAY
    Game.flashTimer = 0
    Game.lastScorer = nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal: award a point and transition to POINT_SCORED
-- ─────────────────────────────────────────────────────────────────────────────

local function awardPoint(scoringSide, wasSpike)
    Game.scores[scoringSide] = Game.scores[scoringSide] + 1
    Game.lastScorer  = scoringSide
    Game.flashTimer  = C.FLASH_DURATION
    Game.state       = "POINT_SCORED"
    Game.stateTimer  = C.POINT_DELAY
    -- The loser serves next
    Game.nextServer  = (scoringSide == 1) and 2 or 1

    -- Screen shake on spike landing
    if wasSpike then
        Game.shakeTimer = C.SHAKE_DURATION
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal: end the match
-- ─────────────────────────────────────────────────────────────────────────────

local function endMatch()
    local s1, s2 = Game.scores[1], Game.scores[2]
    if s1 > s2 then
        Game.winner = "player1"
    elseif s2 > s1 then
        Game.winner = "player2"
    else
        Game.winner = "draw"
    end

    local dur = love.timer.getTime() - Game.matchStartTime
    Storage.save(Game.mode, s1, s2, Game.winner, dur)
    Game.matchHistory = Storage.recent(5)
    Game.state = "GAME_OVER"
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Menu hit-test helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function menuButtonAt(mx, my)
    for _, btn in ipairs(MENU_BUTTONS) do
        if mx >= btn.x and mx <= btn.x + btn.w
        and my >= btn.y and my <= btn.y + btn.h then
            return btn.id
        end
    end
    return nil
end

local function modeButtonAt(mx, my)
    for _, btn in ipairs(MODE_BUTTONS) do
        if mx >= btn.x and mx <= btn.x + btn.w
        and my >= btn.y and my <= btn.y + btn.h then
            return btn.id
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Update
-- ─────────────────────────────────────────────────────────────────────────────

function Game.update(dt)
    local state = Game.state

    -- ── Screen shake ───────────────────────────────────────────────────────
    if Game.shakeTimer > 0 then
        Game.shakeTimer = Game.shakeTimer - dt
        Game.shakeX = (math.random() * 2 - 1) * C.SHAKE_MAGNITUDE
        Game.shakeY = (math.random() * 2 - 1) * C.SHAKE_MAGNITUDE
    else
        Game.shakeX, Game.shakeY = 0, 0
    end

    -- ── Flash timer ───────────────────────────────────────────────────────
    if Game.flashTimer > 0 then
        Game.flashTimer = math.max(0, Game.flashTimer - dt)
    end

    -- ── State-specific logic ──────────────────────────────────────────────

    if state == "MENU" or state == "MODE_SELECT" then
        -- Nothing to update; handled by mousepressed
        return
    end

    -- ── SERVE ─────────────────────────────────────────────────────────────
    if state == "SERVE" then
        Game.stateTimer = Game.stateTimer - dt

        -- Update server player (for visual movement)
        local srv = Game.ball.serverSide
        local serverPlayer = Game.players[srv]
        local input
        if Game.mode == "cpu" and srv == 2 then
            input = Game.ai:update(dt, serverPlayer, Game.ball)
        else
            input = serverPlayer:readInput()
        end
        serverPlayer:update(dt, input)

        -- Keep ball glued to server
        Game.ball:update(dt, Game.players)

        -- Banner shown for SERVE_DELAY, then player can launch
        if Game.stateTimer <= 0 then
            -- Switch to waiting for hit press (keep state = SERVE, timer expired)
            -- Server launches on hit press (handled in keypressed / ai update)
        end

        -- AI auto-serve: if ai:update returned wantHit on a serving ball
        if Game.mode == "cpu" and srv == 2 and Game.stateTimer <= 0 then
            if input and input.wantHit then
                Game.ball:launch(srv)
                Game.state = "PLAYING"
            end
        end

        return
    end

    -- ── POINT_SCORED ──────────────────────────────────────────────────────
    if state == "POINT_SCORED" then
        Game.stateTimer = Game.stateTimer - dt
        if Game.stateTimer <= 0 then
            -- Check win conditions before next serve
            if Game.state == "POINT_SCORED" then  -- may have been changed
                enterServe(Game.nextServer or 1)
            end
        end
        return
    end

    -- ── GAME_OVER ─────────────────────────────────────────────────────────
    if state == "GAME_OVER" then
        return
    end

    -- ── PLAYING or SUDDEN_DEATH ───────────────────────────────────────────
    if state == "PLAYING" or state == "SUDDEN_DEATH" then
        -- Timer (only in PLAYING)
        if state == "PLAYING" then
            Game.matchTimer = Game.matchTimer - dt
            if Game.matchTimer <= 0 then
                Game.matchTimer = 0
                if Game.scores[1] ~= Game.scores[2] then
                    endMatch()
                    return
                else
                    Game.state = "SUDDEN_DEATH"
                end
            end
        end

        local p1 = Game.players[1]
        local p2 = Game.players[2]
        local ball = Game.ball

        -- ── Player 1 input (always human) ────────────────────────────────
        local p1Input = p1:readInput()
        local p1HitEdge = p1:update(dt, p1Input)

        -- ── Player 2 input (human or AI) ──────────────────────────────────
        local p2HitEdge
        if Game.mode == "cpu" then
            local aiInput = Game.ai:update(dt, p2, ball)
            -- Normalise _aiVX back to moveX so player:update applies it correctly
            -- (player:update does self.vx = input.moveX * PLAYER_SPEED)
            aiInput.moveX = aiInput._aiVX / C.PLAYER_SPEED
            p2HitEdge = p2:update(dt, aiInput)
        else
            local p2Input = p2:readInput()
            p2HitEdge = p2:update(dt, p2Input)
        end

        -- ── Ball physics ─────────────────────────────────────────────────
        ball:update(dt, Game.players)

        -- ── Hit logic ─────────────────────────────────────────────────────
        -- Determine if hit is a spike: player airborne
        local function tryPlayerHit(player, hitEdge)
            if not hitEdge then return end
            local isSpike = not player.onGround
            local hit = ball:tryHit(player, isSpike)
            if hit then
                player:triggerHitAnim(isSpike)
                -- Touch limit check
                if ball.touchCount > C.MAX_TOUCHES then
                    -- Opponent scores
                    local opponent = (player.side == 1) and 2 or 1
                    awardPoint(opponent, false)
                end
            end
        end

        tryPlayerHit(p1, p1HitEdge)
        tryPlayerHit(p2, p2HitEdge)

        -- ── Ball landed on floor ──────────────────────────────────────────
        if ball.hitFloor then
            local scorer = ball.pointSide
            -- Was the last hit a spike? (vy was very high on impact)
            local wasSpike = ball.vy > 350
            awardPoint(scorer, wasSpike)
            -- In sudden death → end immediately
            if state == "SUDDEN_DEATH" then
                endMatch()
            end
            return
        end

        -- ── Out of bounds (very wide) ────────────────────────────────────
        if ball.x < 0 or ball.x > 800 then
            -- Award to the side NOT where the ball went out
            local scorer = (ball.x < 400) and 2 or 1
            awardPoint(scorer, false)
            if state == "SUDDEN_DEATH" then endMatch() end
            return
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Draw
-- ─────────────────────────────────────────────────────────────────────────────

function Game.draw()
    love.graphics.push()
    love.graphics.translate(Game.shakeX, Game.shakeY)

    local state = Game.state

    -- ── Backgrounds ───────────────────────────────────────────────────────
    if state == "MENU" or state == "MODE_SELECT" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Assets.menuBg, 0, 0, 0,
            Game.menuScaleX, Game.menuScaleY)

        -- Title text on the wooden board (top-centre area)
        love.graphics.setFont(Assets.fontLarge)
        love.graphics.setColor(0.95, 0.85, 0.3, 1)
        local title = "SPIKE ARENA"
        local tw = Assets.fontLarge:getWidth(title)
        love.graphics.print(title, (800 - tw) / 2, 48)

        -- ── Debug: show clickable button zones ────────────────────────────
        if C.DEBUG then
            for _, btn in ipairs(MENU_BUTTONS) do
                love.graphics.setColor(1, 0, 0, 0.3)
                love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
            end
        end

        -- ── Mode-select overlay ───────────────────────────────────────────
        if state == "MODE_SELECT" then
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("fill", 100, 180, 600, 200, 12, 12)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(Assets.fontMedium)
            local sub = "Choose Mode"
            local sw = Assets.fontMedium:getWidth(sub)
            love.graphics.print(sub, (800 - sw) / 2, 200)

            -- Draw mode buttons
            for _, btn in ipairs(MODE_BUTTONS) do
                local hov = (Game.hoveredBtn == btn.id)
                Hud.drawButton(btn.x, btn.y, btn.w, btn.h, btn.id == "pvp" and "Player vs Player" or "Player vs CPU", hov)
            end
        end
    else
        -- Court background: uniform scale, centred horizontally
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Assets.courtBg,
            Game.courtBgOffX, 0, 0,
            Game.courtBgScale, Game.courtBgScale)

        -- ── Players ───────────────────────────────────────────────────────
        for _, p in ipairs(Game.players) do
            p:draw()
        end

        -- ── Ball ──────────────────────────────────────────────────────────
        if Game.ball then
            Game.ball:draw()
        end

        -- ── HUD (always on top) ───────────────────────────────────────────
        Hud.draw(Game)
    end

    love.graphics.pop()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Input callbacks
-- ─────────────────────────────────────────────────────────────────────────────

function Game.keypressed(key)
    if key == "escape" then
        if Game.state == "PLAYING" or Game.state == "SUDDEN_DEATH" then
            Game.state = "MENU"
        elseif Game.state == "MODE_SELECT" then
            Game.state = "MENU"
        end
        return
    end

    -- SERVE: player 1 launches on LShift, player 2 on RCtrl (if PvP)
    if Game.state == "SERVE" and Game.stateTimer <= 0 then
        local srv = Game.ball.serverSide
        if Game.mode ~= "cpu" or srv == 1 then
            local hitKey = (srv == 1) and "lshift" or "rctrl"
            if key == hitKey then
                Game.ball:launch(srv)
                Game.state = "PLAYING"
            end
        end
    end
end

function Game.keyreleased(key)
    -- nothing needed at module level; Player handles its own edge detection
end

function Game.mousemoved(x, y)
    Game.hoveredBtn = nil
    if Game.state == "MENU" then
        -- no hover needed (buttons are painted in background)
    elseif Game.state == "MODE_SELECT" then
        for _, btn in ipairs(MODE_BUTTONS) do
            if x >= btn.x and x <= btn.x + btn.w
            and y >= btn.y and y <= btn.y + btn.h then
                Game.hoveredBtn = btn.id
            end
        end
    elseif Game.state == "GAME_OVER" then
        Game.hoveredBtn = Hud.gameOverButtonAt(x, y)
    end
end

function Game.mousepressed(x, y, btn)
    if btn ~= 1 then return end

    if Game.state == "MENU" then
        local id = menuButtonAt(x, y)
        if id == "start" then
            Game.state = "MODE_SELECT"
        elseif id == "exit" then
            love.event.quit()
        elseif id == "credits" then
            -- future: show credits overlay
        end

    elseif Game.state == "MODE_SELECT" then
        local id = modeButtonAt(x, y)
        if id == "pvp" or id == "cpu" then
            Game.mode = id
            resetMatch(1)
        end

    elseif Game.state == "GAME_OVER" then
        local id = Hud.gameOverButtonAt(x, y)
        if id == "again" then
            resetMatch(1)
        elseif id == "menu" then
            Game.state = "MENU"
        elseif id == "clear" then
            Storage.clear()
            Game.matchHistory = {}
        end
    end
end

return Game
