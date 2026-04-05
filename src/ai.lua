-- src/ai.lua: CPU opponent controller (medium difficulty).
-- Uses a ring buffer to introduce ~0.1 s reaction delay, plus a 15% miss chance.

local C = require("src.constants")

local AI = {}
AI.__index = AI

-- ─────────────────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────────────────

function AI.new()
    local self = setmetatable({}, AI)
    -- Ring buffer for delayed ball positions
    self.buffer     = {}   -- circular list of {x, y}
    self.bufHead    = 1    -- next write position
    self.bufSize    = C.AI_DELAY_FRAMES
    -- Pre-fill buffer so reads are always valid
    for i = 1, self.bufSize do
        self.buffer[i] = { x = C.PLAYER2_START_X, y = C.BALL_SERVE_Y }
    end

    -- Miss state: regenerated each "engagement"
    self.missOffset  = 0
    self.lastMissGen = -1  -- timestamp of last miss-offset generation

    -- Internal state
    self.wantJump    = false
    self.jumpHeld    = false
    self.wantHit     = false
    self.hitCooldown = 0   -- seconds before AI can press hit again
    return self
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Update: decide input for this frame
-- ─────────────────────────────────────────────────────────────────────────────

-- Returns an input table compatible with Player:update()
function AI:update(dt, player, ball)
    -- ── Write current ball pos to ring buffer ─────────────────────────────
    self.buffer[self.bufHead] = { x = ball.x, y = ball.y }
    self.bufHead = (self.bufHead % self.bufSize) + 1

    -- ── Read delayed position (tail of ring buffer) ───────────────────────
    local delayedIdx = self.bufHead   -- head has just been advanced; tail = head
    local delayed = self.buffer[delayedIdx]
    local dbx = delayed.x
    local dby = delayed.y

    -- ── Tick hit cooldown ─────────────────────────────────────────────────
    if self.hitCooldown > 0 then
        self.hitCooldown = self.hitCooldown - dt
    end

    -- ── Decide movement ───────────────────────────────────────────────────
    local moveX    = 0
    local wantJump = false
    local wantHit  = false
    local wantDig  = false

    local ballOnMySide = ball.x > C.NET_X
    local speed = C.PLAYER_SPEED

    if ballOnMySide and not ball.serving then
        -- ── Generate / refresh miss offset when ball just crossed to my side ──
        if self.lastMissGen ~= math.floor(love.timer.getTime() * 2) then
            self.lastMissGen = math.floor(love.timer.getTime() * 2)
            if math.random() < C.AI_MISS_CHANCE then
                self.missOffset = (math.random() * 2 - 1) * C.AI_MISS_OFFSET
            else
                self.missOffset = 0
            end
        end

        local targetX = dbx + self.missOffset

        -- Move toward delayed ball x
        local dx = targetX - player.x
        if math.abs(dx) > 4 then
            moveX = (dx > 0) and 1 or -1
        end

        -- Chase speed
        speed = C.PLAYER_SPEED * C.AI_SPEED_RATIO

        -- Ball is HIGH (above mid-court) → jump and spike
        local ballHigh = dby < C.NET_TOP_Y + 100
        local closeToBall = math.abs(player.x - ball.x) < C.HIT_RANGE * 1.4
                         and math.abs(player.y - ball.y) < C.HIT_RANGE * 2.5

        if closeToBall and ballHigh and player.onGround then
            wantJump = true
        end

        -- In air and close → hit
        if closeToBall and not player.onGround and self.hitCooldown <= 0 then
            wantHit = true
            self.hitCooldown = C.HIT_COOLDOWN + 0.1
        end

        -- Ball coming in FAST and LOW → dig
        if ball.vy > 250 and closeToBall and player.onGround then
            wantDig  = true
            wantHit  = self.hitCooldown <= 0
            if wantHit then self.hitCooldown = C.HIT_COOLDOWN + 0.1 end
        end

        -- Grounded bump when ball is reachable and at head height
        local ballAtBumpHeight = ball.y > (player.y - C.PLAYER_DISPLAY_H)
                              and ball.y < player.y
        if closeToBall and player.onGround and ballAtBumpHeight
           and self.hitCooldown <= 0 then
            wantHit = true
            self.hitCooldown = C.HIT_COOLDOWN + 0.1
        end

    else
        -- Ball on player side or serving → drift back toward spawn
        speed = C.PLAYER_SPEED * C.AI_IDLE_RATIO
        local dx = C.PLAYER2_START_X - player.x
        if math.abs(dx) > 8 then
            moveX = (dx > 0) and 1 or -1
        end
    end

    -- ── Build input table ─────────────────────────────────────────────────
    -- AI also serves: press hit while ball.serving on player 2 side
    if ball.serving and ball.serverSide == 2 and self.hitCooldown <= 0 then
        -- Small random delay before serving (0.4–1.2 s simulated by cooldown)
        self.hitCooldown = 0.8
        wantHit = true
    end

    return {
        moveX    = moveX,
        speed    = speed,         -- ai can override speed; player.lua uses PLAYER_SPEED, so we handle below
        wantJump = wantJump,
        wantDig  = wantDig,
        wantHit  = wantHit,
        -- extra field: actual vx the AI wants (bypasses fixed PLAYER_SPEED)
        _aiVX    = moveX * speed,
    }
end

return AI
