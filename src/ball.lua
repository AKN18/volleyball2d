-- src/ball.lua: Ball physics, hit detection, trail rendering, shadow.

local C      = require("src.constants")
local Assets = require("src.assets")

local Ball = {}
Ball.__index = Ball

-- ─────────────────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────────────────

function Ball.new()
    local self = setmetatable({}, Ball)
    self:reset(1)   -- default: player 1 serves
    return self
end

-- Reset to serve state.  serverSide: 1 = left, 2 = right.
function Ball:reset(serverSide)
    self.serverSide    = serverSide or 1
    self.serving       = true      -- ball is held by server
    self.x             = (serverSide == 1) and C.PLAYER1_START_X or C.PLAYER2_START_X
    self.y             = C.BALL_SERVE_Y
    self.vx            = 0
    self.vy            = 0
    self.angle         = 0         -- visual rotation (radians)
    self.frame         = 0         -- current animation frame index
    self.frameTimer    = 0
    self.trail         = {}        -- {x, y} ghost positions
    self.lastHitPlayer = nil       -- 1 or 2
    self.lastHitTime   = -999      -- love.timer.getTime() of last hit
    self.touchSide     = nil       -- which side has been touching (1 or 2)
    self.touchCount    = 0         -- consecutive touches on current side
    self.bounced       = false     -- whether floor-bounce has already triggered
    self.hitFloor      = false     -- set true on floor contact (used by game.lua)
    self.pointSide     = nil       -- which side scored (set alongside hitFloor)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Launch ball from serve
-- ─────────────────────────────────────────────────────────────────────────────

function Ball:launch(serverSide)
    self.serving = false
    -- Serve toward the opponent side with a high arc over the net
    local dir = (serverSide == 1) and 1 or -1
    self.vx = dir * C.BALL_SPEED_BASE * 1.2  -- strong horizontal
    self.vy = -450  -- strong upward to clear the net
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Update
-- ─────────────────────────────────────────────────────────────────────────────

function Ball:update(dt, players)
    if self.serving then
        -- Stick just above the server's head
        local srv = players[self.serverSide]
        self.x = srv.x
        self.y = srv.y - C.PLAYER_DISPLAY_H * 0.55
        return
    end

    -- ── Gravity ────────────────────────────────────────────────────────────
    self.vy = self.vy + C.BALL_GRAVITY * dt

    -- ── Position ───────────────────────────────────────────────────────────
    local prevX = self.x
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- ── Visual rotation: faster spin with higher |vx| ─────────────────────
    self.angle = self.angle + self.vx * dt * 0.05

    -- ── Animation frame (advance by speed, wrap in 0..BALL_FRAMES-1) ──────
    self.frameTimer = self.frameTimer + math.abs(self.vx) * dt * 0.01
    self.frame = math.floor(self.frameTimer) % C.BALL_FRAMES

    -- ── Trail: prepend current pos, keep last 3 ───────────────────────────
    table.insert(self.trail, 1, { x = self.x, y = self.y })
    if #self.trail > 3 then
        table.remove(self.trail)
    end

    -- ── Wall bounces ───────────────────────────────────────────────────────
    if self.x - C.BALL_RADIUS < C.WALL_LEFT then
        self.x  = C.WALL_LEFT + C.BALL_RADIUS
        self.vx = math.abs(self.vx)
    elseif self.x + C.BALL_RADIUS > C.WALL_RIGHT then
        self.x  = C.WALL_RIGHT - C.BALL_RADIUS
        self.vx = -math.abs(self.vx)
    end

    -- ── Net collision (swept check to avoid tunnelling) ───────────────────
    local netLeft  = C.NET_X - C.NET_HALF_W
    local netRight = C.NET_X + C.NET_HALF_W
    local crossedNet = (prevX < netLeft and self.x + C.BALL_RADIUS > netLeft)
                    or (prevX > netRight and self.x - C.BALL_RADIUS < netRight)
    if crossedNet and self.y + C.BALL_RADIUS > C.NET_TOP_Y then
        self.vx = self.vx * -0.6
        -- Push ball back to the side it came from
        if self.vx > 0 then
            self.x = netLeft - C.BALL_RADIUS
        else
            self.x = netRight + C.BALL_RADIUS
        end
    end

    -- ── Floor ──────────────────────────────────────────────────────────────
    if self.y + C.BALL_RADIUS >= C.FLOOR_Y then
        if not self.bounced then
            -- One small bounce
            self.y  = C.FLOOR_Y - C.BALL_RADIUS
            self.vy = self.vy * -0.35
            self.bounced = true
        else
            -- Award point: ball landed on whichever side it's on
            self.hitFloor  = true
            self.pointSide = (self.x < C.NET_X) and 2 or 1  -- scorer is the OPPONENT
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Hit detection & response
-- ─────────────────────────────────────────────────────────────────────────────

-- Try to hit the ball.  Returns true if hit was made.
-- playerObj: the player table   isSpike: boolean
function Ball:tryHit(playerObj, isSpike)
    if self.serving then return false end

    -- Player hitbox centre (half display height above feet)
    local px = playerObj.x
    local py = playerObj.y - C.PLAYER_DISPLAY_H * 0.5

    local dx = self.x - px
    local dy = self.y - py
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > C.HIT_RANGE then return false end

    -- Cooldown: prevent same player from double-hitting
    local now = love.timer.getTime()
    if playerObj == self.lastHitPlayer and (now - self.lastHitTime) < C.HIT_COOLDOWN then
        return false
    end

    -- Touch counter: reset on side change, increment on same side
    local side = playerObj.side
    if side ~= self.touchSide then
        self.touchSide  = side
        self.touchCount = 1
    else
        self.touchCount = self.touchCount + 1
    end

    -- Power scales with proximity (closer = harder hit)
    local t     = 1 - (dist / C.HIT_RANGE)
    local power = C.BALL_SPEED_BASE * (0.5 + 0.5 * t)  -- range 50%–100% of base

    -- Direction: push ball away from player horizontally, arc upward
    local normX = (dist > 0) and (dx / dist) or (playerObj.side == 1 and 1 or -1)
    -- Ensure the ball always moves toward the opponent's side
    if playerObj.side == 1 then
        normX = math.max(normX, 0.2)   -- P1 must hit rightward
    else
        normX = math.min(normX, -0.2)  -- P2 must hit leftward
    end

    self.vx = normX * power
    self.vy = -power * 0.7

    if isSpike then
        self.vx = self.vx * C.SPIKE_BOOST
        self.vy = self.vy + C.SPIKE_DOWN_VEL
    end

    self.lastHitPlayer = playerObj
    self.lastHitTime   = now
    self.bounced       = false   -- reset floor-bounce so ball can land cleanly

    return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Draw
-- ─────────────────────────────────────────────────────────────────────────────

function Ball:draw()
    -- Actual frame size from the loaded sprite sheet
    local fw = Assets.ballFrameW   -- 732  (5856 ÷ 8)
    local fh = Assets.ballFrameH   -- 704
    -- Uniform scale so the ball appears BALL_DISPLAY_D pixels wide on screen
    local bs = C.BALL_DISPLAY_D / fw   -- ≈ 36/732 ≈ 0.049

    -- ── Shadow ────────────────────────────────────────────────────────────
    -- Choose frame: 0=large (near floor), 1=medium, 2=small (high up)
    local heightAboveFloor = math.max(0, C.FLOOR_Y - self.y)
    local maxH = C.FLOOR_Y - C.NET_TOP_Y
    local t = math.min(heightAboveFloor / maxH, 1)
    local shadowFrame = math.min(math.floor(t * 2 + 0.5), 2)

    local sw = Assets.shadowFrameW   -- 2816÷3 ≈ 938.67
    local sh = Assets.shadowFrameH   -- 1536
    -- Shadow oval: target ~64px wide × 16px tall, shrinks as ball rises
    local shadowSX = (C.BALL_DISPLAY_D * 1.9 / sw) * (1 - t * 0.45)
    local shadowSY = (C.BALL_DISPLAY_D * 0.48 / sh) * (1 - t * 0.45)
    love.graphics.setColor(1, 1, 1, 0.55 - t * 0.4)
    love.graphics.draw(
        Assets.shadowSheet,
        Assets.shadowQuads[shadowFrame],
        self.x, C.FLOOR_Y - 4,
        0,
        shadowSX, shadowSY,
        sw / 2, sh / 2)

    -- ── Trail ghosts ─────────────────────────────────────────────────────
    local alphas = { 0.25, 0.15, 0.08 }
    for i, ghost in ipairs(self.trail) do
        love.graphics.setColor(1, 1, 1, alphas[i] or 0)
        love.graphics.draw(
            Assets.ballSheet,
            Assets.ballQuads[self.frame],
            ghost.x, ghost.y,
            self.angle,
            bs, bs,
            fw / 2, fh / 2)
    end

    -- ── Ball ──────────────────────────────────────────────────────────────
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        Assets.ballSheet,
        Assets.ballQuads[self.frame],
        self.x, self.y,
        self.angle,
        bs, bs,
        fw / 2, fh / 2)

    -- ── Debug: collision circle ───────────────────────────────────────────
    if C.DEBUG then
        love.graphics.setColor(0, 1, 0, 0.5)
        love.graphics.circle("line", self.x, self.y, C.BALL_RADIUS)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Ball
