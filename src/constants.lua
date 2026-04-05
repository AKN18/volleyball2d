-- src/constants.lua: All tunable game values in one place.
-- Change these to tweak feel without touching game logic.

local C = {}

-- ── Physics ───────────────────────────────────────────────────────────────
C.GRAVITY         = 900    -- player gravity (px/s²)
C.BALL_GRAVITY    = 550    -- ball gravity (px/s²)
C.PLAYER_SPEED    = 200    -- horizontal move speed (px/s)
C.JUMP_FORCE      = -480   -- initial vertical velocity on jump (negative = up)

-- ── Ball ──────────────────────────────────────────────────────────────────
C.BALL_SPEED_BASE = 380    -- base hit speed (px/s)
C.SPIKE_BOOST     = 1.5    -- vx multiplier on spike
C.SPIKE_DOWN_VEL  = 200    -- extra downward vy added on spike
C.BALL_RADIUS     = 18     -- collision circle radius (px)
C.BALL_FRAMES      = 8     -- frames in ball_sheet (5856÷8=732 px each, all usable)

-- ── Court geometry ────────────────────────────────────────────────────────
C.NET_X           = 400    -- x-centre of the net
C.NET_TOP_Y       = 290    -- y of the top of the net (just above players' heads)
C.NET_HALF_W      = 8      -- half-width of the net collision zone
C.FLOOR_Y         = 520    -- y at which ball counts as grounded / landed
C.WALL_LEFT       = 20     -- left wall x
C.WALL_RIGHT      = 780    -- right wall x

-- ── Player start positions ────────────────────────────────────────────────
-- Adjusted to better center players visually on the court
C.PLAYER1_START_X = 220    -- moved right slightly for better visual center
C.PLAYER2_START_X = 580    -- moved left slightly for better visual center
C.PLAYERS_START_Y = 456    -- y at which players stand (feet level)

-- ── Player clamp ranges ───────────────────────────────────────────────────
C.P1_MIN_X        = 50
C.P1_MAX_X        = C.NET_X - 50
C.P2_MIN_X        = C.NET_X + 50
C.P2_MAX_X        = 750

-- ── Ball serve ────────────────────────────────────────────────────────────
C.BALL_SERVE_Y    = 320    -- y the ball is held at during serve

-- ── Rules ─────────────────────────────────────────────────────────────────
C.MATCH_TIME      = 120    -- seconds per match
C.MAX_TOUCHES     = 3      -- max consecutive touches per team
C.HIT_RANGE       = 60     -- max distance (px) from player centre for a hit

-- ── Hit cooldown ──────────────────────────────────────────────────────────
C.HIT_COOLDOWN    = 0.3    -- seconds before same player can hit again

-- ── Player sprite ─────────────────────────────────────────────────────────
-- Actual source frames are 352×1536 px (2816÷8 × 1536).
-- We scale NON-UNIFORMLY so the 48×64 logical design shows at exactly 2×:
--   scaleX = PLAYER_DISPLAY_W / (sheet_w / PLAYER_FRAMES)  →  96/352
--   scaleY = PLAYER_DISPLAY_H / sheet_h                    → 128/1536
C.PLAYER_DISPLAY_W = 96    -- desired on-screen width  (px)
C.PLAYER_DISPLAY_H = 128   -- desired on-screen height (px)
C.PLAYER_FRAMES    = 8     -- frames per player sheet

-- ── Ball sprite ───────────────────────────────────────────────────────────
-- Source frames are 732×704 px (5856÷8 × 704).  Scale uniformly.
C.BALL_DISPLAY_D   = 36    -- desired on-screen diameter (px)

-- ── State timers ──────────────────────────────────────────────────────────
C.SERVE_DELAY     = 1.5    -- seconds the SERVE banner stays up
C.POINT_DELAY     = 1.5    -- seconds the POINT_SCORED freeze lasts
C.FLASH_DURATION  = 0.5    -- seconds score panel flashes yellow

-- ── Screen shake ──────────────────────────────────────────────────────────
C.SHAKE_DURATION  = 0.3    -- seconds
C.SHAKE_MAGNITUDE = 5      -- ±px

-- ── AI ────────────────────────────────────────────────────────────────────
C.AI_SPEED_RATIO  = 0.85   -- fraction of PLAYER_SPEED the AI uses
C.AI_IDLE_RATIO   = 0.50   -- fraction used when drifting back
C.AI_DELAY_FRAMES = 6      -- ring-buffer depth (~0.1 s at 60 fps)
C.AI_MISS_CHANCE  = 0.15   -- probability of an intentional miss
C.AI_MISS_OFFSET  = 30     -- ±px added to target when missing

-- ── Debug ─────────────────────────────────────────────────────────────────
C.DEBUG           = false  -- draw hitboxes when true

return C
