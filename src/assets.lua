-- src/assets.lua: Load every image and pre-build all sprite quads.
-- Call Assets.load() once in love.load().  Everything lives in Assets.*

local C = require("src.constants")

local Assets = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- Build a row of `count` equally-wide quads from a single horizontal strip.
local function buildStrip(img, count)
    local iw, ih = img:getWidth(), img:getHeight()
    local fw = iw / count
    local quads = {}
    for i = 0, count - 1 do
        quads[i] = love.graphics.newQuad(i * fw, 0, fw, ih, iw, ih)
    end
    return quads, fw, ih
end

-- Replace grey background with transparent pixels.
-- Detects grey as: all channels similar (low saturation) AND not very dark.
-- This matches the 155–210 grey range baked into the sprite sheets.
local function removeGreyBackground(imagePath)
    local imgData = love.image.newImageData(imagePath)
    imgData:mapPixel(function(x, y, r, g, b, a)
        local hi = math.max(r, g, b)
        local lo = math.min(r, g, b)
        -- Grey = low colour variance (< ~20/255) AND bright enough (> 0.40)
        -- This leaves dark character pixels and coloured pixels intact.
        if (hi - lo) < 0.08 and hi > 0.40 then
            return 0, 0, 0, 0
        end
        return r, g, b, a
    end)
    return love.graphics.newImage(imgData)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public load function
-- ─────────────────────────────────────────────────────────────────────────────

function Assets.load()
    -- ── Backgrounds ──────────────────────────────────────────────────────────
    Assets.courtBg = love.graphics.newImage("assets/backgrounds/court_background.png")
    Assets.menuBg  = love.graphics.newImage("assets/backgrounds/menu_background.png")

    -- ── Player sheets (8 frames each) ────────────────────────────────────
    -- Remove the baked-in grey background so players render transparently.
    Assets.p1Sheet  = removeGreyBackground("assets/sprites/player1_sheet.png")
    Assets.p2Sheet  = removeGreyBackground("assets/sprites/player2_sheet.png")
    Assets.p1Sheet:setFilter("linear", "linear")
    Assets.p2Sheet:setFilter("linear", "linear")
    Assets.p1Quads, Assets.playerFrameW, Assets.playerFrameH =
        buildStrip(Assets.p1Sheet, C.PLAYER_FRAMES)
    Assets.p2Quads = buildStrip(Assets.p2Sheet, C.PLAYER_FRAMES)

    -- ── Ball sheet (7 usable frames) ─────────────────────────────────────
    Assets.ballSheet = removeGreyBackground("assets/sprites/ball_sheet.png")
    Assets.ballSheet:setFilter("nearest", "nearest")
    Assets.ballQuads, Assets.ballFrameW, Assets.ballFrameH =
        buildStrip(Assets.ballSheet, C.BALL_FRAMES)

    -- ── Ball shadow (3 frames: large / medium / small) ───────────────────
    Assets.shadowSheet = removeGreyBackground("assets/sprites/ball_shadow.png")
    Assets.shadowSheet:setFilter("nearest", "nearest")
    Assets.shadowQuads, Assets.shadowFrameW, Assets.shadowFrameH =
        buildStrip(Assets.shadowSheet, 3)

    -- ── UI elements sheet ─────────────────────────────────────────────────
    -- The sheet is a combined atlas.  We slice it proportionally so any
    -- resolution works without hardcoded pixel values.
    -- Remove grey background and use nearest filter for sharp pixels
    Assets.uiSheet = removeGreyBackground("assets/sprites/ui_elements.png")
    Assets.uiSheet:setFilter("nearest", "nearest")
    local uw = Assets.uiSheet:getWidth()
    local uh = Assets.uiSheet:getHeight()

    -- Proportional sub-regions (fractions of the full sheet).
    -- These match the visual layout described in the spec:
    --   Top-left  (0.0–0.5 x, 0.0–0.25 y)  → Score Panel (blue border)
    --   Top-right (0.5–1.0 x, 0.0–0.25 y)  → Timer Box
    --   Mid-left  (0.0–0.5 x, 0.25–0.5 y)  → SERVE! banner
    --   Mid-right (0.5–1.0 x, 0.25–0.5 y)  → POINT! banner
    --   Bot-left  (0.0–0.5 x, 0.5–0.75 y)  → GAME OVER banner
    --   Bot-ctr   (0.25–0.75 x, 0.75–0.875 y) → Net indicator bar
    --   Bot-right (0.75–1.0 x, 0.75–1.0 y)    → Volleyball icon (16×16 logical)
    local function uiQuad(fx, fy, fw, fh)
        return love.graphics.newQuad(
            math.floor(fx * uw), math.floor(fy * uh),
            math.floor(fw * uw), math.floor(fh * uh),
            uw, uh)
    end

    Assets.ui = {
        scorePanel  = uiQuad(0.0,  0.0,  0.5,  0.25),
        timerBox    = uiQuad(0.5,  0.0,  0.5,  0.25),
        -- Start banners slightly lower (y=0.278) to skip the annotation
        -- label rows baked into the sprite sheet at the section boundary.
        serveBanner = uiQuad(0.0,  0.278, 0.5,  0.222),
        pointBanner = uiQuad(0.5,  0.278, 0.5,  0.222),
        gameOver    = uiQuad(0.0,  0.5,  0.5,  0.25),
        netBar      = uiQuad(0.25, 0.75, 0.5,  0.125),
        ballIcon    = uiQuad(0.75, 0.75, 0.25, 0.25),
    }
    -- Store sheet dimensions for scaled drawing
    Assets.uiW = uw
    Assets.uiH = uh

    -- ── Win / draw banners ────────────────────────────────────────────────
    -- Remove grey backgrounds from banners too
    Assets.winBanners = removeGreyBackground("assets/sprites/win_banners.png")
    Assets.winBanners:setFilter("nearest", "nearest")
    local wbw = Assets.winBanners:getWidth()
    local wbh = Assets.winBanners:getHeight()
    Assets.p1WinQuad = love.graphics.newQuad(0, 0,       wbw, wbh / 2, wbw, wbh)
    Assets.p2WinQuad = love.graphics.newQuad(0, wbh / 2, wbw, wbh / 2, wbw, wbh)

    Assets.drawBanner = removeGreyBackground("assets/sprites/draw_banners.png")
    Assets.drawBanner:setFilter("nearest", "nearest")
    -- draw_banners is used as a single full-image quad (no slicing needed)

    -- ── Fonts ─────────────────────────────────────────────────────────────
    Assets.fontLarge  = love.graphics.newFont(48)
    Assets.fontMedium = love.graphics.newFont(28)
    Assets.fontSmall  = love.graphics.newFont(18)
    Assets.fontTiny   = love.graphics.newFont(13)
end

return Assets
