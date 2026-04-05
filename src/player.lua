-- src/player.lua: Player state, input, animation, physics, and rendering.
-- Each player is a table created with Player.new(side, controls).

local C      = require("src.constants")
local Assets = require("src.assets")

local Player = {}
Player.__index = Player

-- ─────────────────────────────────────────────────────────────────────────────
-- Frame indices (0-based to match quad table)
-- ─────────────────────────────────────────────────────────────────────────────
local FRAME_IDLE     = 0
local FRAME_WALK_A   = 1
local FRAME_WALK_B   = 2
local FRAME_JUMP_UP  = 3
local FRAME_JUMP_APX = 4
local FRAME_DIG      = 5
local FRAME_BUMP     = 6
local FRAME_SPIKE    = 7

-- ─────────────────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────────────────

-- side: 1 (left/blue) or 2 (right/red)
-- controls: table of key names { left, right, jump, dig, hit }
function Player.new(side, controls)
    local self = setmetatable({}, Player)
    self.side     = side
    self.controls = controls

    -- Sprite sheet & quads
    self.sheet = (side == 1) and Assets.p1Sheet or Assets.p2Sheet
    self.quads = (side == 1) and Assets.p1Quads or Assets.p2Quads

    self:reset()
    return self
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Reset to starting position
-- ─────────────────────────────────────────────────────────────────────────────

function Player:reset()
    self.x          = (self.side == 1) and C.PLAYER1_START_X or C.PLAYER2_START_X
    self.y          = C.PLAYERS_START_Y
    self.vx         = 0
    self.vy         = 0
    self.onGround   = true
    self.isDigging  = false
    self.frame      = FRAME_IDLE
    self.walkTimer  = 0        -- used to alternate walk frames
    self.hitCooldown = 0       -- seconds remaining on hit animation hold
    self.lastHitFrame = FRAME_BUMP   -- which hit frame to display
    self.jumpHeld   = false    -- track key-hold to avoid repeated jumps
    self.hitPressed = false    -- edge detect
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Input processing (called each frame for human players)
-- ─────────────────────────────────────────────────────────────────────────────

-- Returns { moveX, wantJump, wantDig, wantHit }
function Player:readInput()
    local k = love.keyboard
    local c = self.controls
    local mx = 0
    if k.isDown(c.left)  then mx = mx - 1 end
    if k.isDown(c.right) then mx = mx + 1 end
    return {
        moveX   = mx,
        wantJump = k.isDown(c.jump),
        wantDig  = k.isDown(c.dig),
        wantHit  = k.isDown(c.hit),
    }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Apply movement & physics
-- ─────────────────────────────────────────────────────────────────────────────

-- input table: { moveX, wantJump, wantDig, wantHit }
-- Returns true if player pressed hit this frame (edge: was not pressed before)
function Player:update(dt, input)
    -- ── Horizontal movement ────────────────────────────────────────────────
    self.vx = input.moveX * C.PLAYER_SPEED

    -- ── Digging: slow movement, lower stance ──────────────────────────────
    self.isDigging = input.wantDig and self.onGround

    -- ── Jump ──────────────────────────────────────────────────────────────
    if input.wantJump and self.onGround and not self.jumpHeld then
        self.vy       = C.JUMP_FORCE
        self.onGround = false
        self.jumpHeld = true
    end
    if not input.wantJump then
        self.jumpHeld = false
    end

    -- ── Gravity ───────────────────────────────────────────────────────────
    if not self.onGround then
        self.vy = self.vy + C.GRAVITY * dt
    end

    -- ── Integrate position ────────────────────────────────────────────────
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- ── Floor ─────────────────────────────────────────────────────────────
    if self.y >= C.PLAYERS_START_Y then
        self.y        = C.PLAYERS_START_Y
        self.vy       = 0
        self.onGround = true
    end

    -- ── X clamping ────────────────────────────────────────────────────────
    local minX = (self.side == 1) and C.P1_MIN_X or C.P2_MIN_X
    local maxX = (self.side == 1) and C.P1_MAX_X or C.P2_MAX_X
    self.x = math.max(minX, math.min(maxX, self.x))

    -- ── Hit cooldown ──────────────────────────────────────────────────────
    if self.hitCooldown > 0 then
        self.hitCooldown = self.hitCooldown - dt
    end

    -- ── Walk animation timer ──────────────────────────────────────────────
    if self.vx ~= 0 and self.onGround then
        self.walkTimer = self.walkTimer + dt
    else
        self.walkTimer = 0
    end

    -- ── Determine animation frame ──────────────────────────────────────────
    if self.hitCooldown > 0 then
        self.frame = self.lastHitFrame
    elseif not self.onGround then
        if self.vy < -80 then
            self.frame = FRAME_JUMP_UP
        else
            self.frame = FRAME_JUMP_APX
        end
    elseif self.isDigging then
        self.frame = FRAME_DIG
    elseif self.vx ~= 0 then
        -- Alternate walk frames at ~5 Hz
        self.frame = (math.floor(self.walkTimer * 10) % 2 == 0)
                     and FRAME_WALK_A or FRAME_WALK_B
    else
        self.frame = FRAME_IDLE
    end

    -- ── Hit detection edge ────────────────────────────────────────────────
    local hitEdge = input.wantHit and not self.hitPressed
    self.hitPressed = input.wantHit
    return hitEdge
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Trigger hit animation
-- ─────────────────────────────────────────────────────────────────────────────

-- Called by game.lua after a successful ball hit.
-- isSpike: whether this was a spike (determines which frame to hold)
function Player:triggerHitAnim(isSpike)
    self.lastHitFrame = isSpike and FRAME_SPIKE or FRAME_BUMP
    self.hitCooldown  = C.HIT_COOLDOWN
    self.frame        = self.lastHitFrame
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Getters for collision
-- ─────────────────────────────────────────────────────────────────────────────

-- Returns AABB { left, top, right, bottom } centred on player
function Player:getAABB()
    local hw = 18   -- half-width
    local hh = 45   -- half-height
    return {
        left   = self.x - hw,
        top    = self.y - hh * 2,
        right  = self.x + hw,
        bottom = self.y,
    }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Draw
-- ─────────────────────────────────────────────────────────────────────────────

function Player:draw()
    -- Actual pixel dimensions of one frame from the loaded sheet
    local fw = Assets.playerFrameW   -- 352  (2816 ÷ 8)
    local fh = Assets.playerFrameH   -- 1536

    -- Non-uniform scale: compensates for the sheet's non-square export resolution.
    -- Result: the 48×64 logical sprite appears at PLAYER_DISPLAY_W×PLAYER_DISPLAY_H.
    local scaleY = C.PLAYER_DISPLAY_H / fh                -- 128/1536 ≈ 0.0833
    local scaleX = C.PLAYER_DISPLAY_W / fw                -- 96/352  ≈ 0.2727
    if self.side == 2 then scaleX = -scaleX end           -- flip P2

    -- Origin: actual character centre-x (≈208) and feet-y (≈982) within the frame.
    -- Using the full-frame centre/bottom caused the sprite to appear offset because
    -- the character occupies only the middle portion of the large export frame.
    local ox = fw * 0.591   -- character horizontal centre  (208 / 352 ≈ 0.591)
    local oy = fh * 0.639   -- character feet bottom        (982 / 1536 ≈ 0.639)

    -- Clip rendering to just below the character's feet so that annotation
    -- text baked into the lower portion of the export frame is never shown.
    love.graphics.setScissor(0, 0, 800, math.ceil(self.y + 4))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        self.sheet,
        self.quads[self.frame],
        self.x, self.y,
        0,
        scaleX, scaleY,
        ox, oy)
    love.graphics.setScissor()

    -- ── Debug hitbox ──────────────────────────────────────────────────────
    if C.DEBUG then
        local box = self:getAABB()
        love.graphics.setColor(1, 0.3, 0, 0.5)
        love.graphics.rectangle("line",
            box.left, box.top,
            box.right - box.left,
            box.bottom - box.top)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Player
