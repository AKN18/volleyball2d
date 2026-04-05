-- src/hud.lua: All on-screen UI drawing — scores, timer, banners, overlays.
-- Call Hud.draw(game) each frame AFTER the court and players are drawn.

local C      = require("src.constants")
local Assets = require("src.assets")

local Hud = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal drawing helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- Centre text horizontally between x1 and x2 at row y.
local function centreText(font, text, x1, x2, y)
    local w = font:getWidth(text)
    local cx = x1 + (x2 - x1 - w) / 2
    love.graphics.setFont(font)
    love.graphics.print(text, cx, y)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Panel dimensions in screen space
-- ─────────────────────────────────────────────────────────────────────────────
local PANEL_W  = 160
local PANEL_H  = 56
local P1_PX    = 20         -- left edge of P1 panel
local P2_PX    = 620        -- left edge of P2 panel
local PANEL_Y  = 10         -- top edge of both panels
local TIMER_W  = 120
local TIMER_H  = 48
local TIMER_X  = 340        -- left edge of timer box (centred on 800)
local TIMER_Y  = 8

-- ─────────────────────────────────────────────────────────────────────────────
-- Main draw entry point
-- ─────────────────────────────────────────────────────────────────────────────

function Hud.draw(game)
    -- ── Score panels ─────────────────────────────────────────────────────
    local p1Flash = (game.flashTimer > 0 and game.lastScorer == 1)
    local p2Flash = (game.flashTimer > 0 and game.lastScorer == 2)

    -- P1 panel
    if p1Flash then
        love.graphics.setColor(1, 0.85, 0, 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.draw(Assets.uiSheet, Assets.ui.scorePanel, P1_PX, PANEL_Y, 0,
        PANEL_W / (Assets.uiW * 0.5),
        PANEL_H / (Assets.uiH * 0.25))

    -- P2 panel (tinted slightly differently by the sprite itself)
    if p2Flash then
        love.graphics.setColor(1, 0.85, 0, 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.draw(Assets.uiSheet, Assets.ui.scorePanel, P2_PX, PANEL_Y, 0,
        PANEL_W / (Assets.uiW * 0.5),
        PANEL_H / (Assets.uiH * 0.25))

    -- ── Score numbers ─────────────────────────────────────────────────────
    love.graphics.setColor(1, 1, 1, 1)
    -- P1 score
    centreText(Assets.fontLarge,
        tostring(game.scores[1]),
        P1_PX, P1_PX + PANEL_W,
        PANEL_Y + 2)
    -- P2 score
    centreText(Assets.fontLarge,
        tostring(game.scores[2]),
        P2_PX, P2_PX + PANEL_W,
        PANEL_Y + 2)

    -- ── Timer background (plain box — the timerBox sprite contains stray
    --    green pixels so we draw a clean rectangle instead) ────────────────
    love.graphics.setColor(0.08, 0.08, 0.08, 0.88)
    love.graphics.rectangle("fill", TIMER_X, TIMER_Y, TIMER_W, TIMER_H, 6, 6)
    love.graphics.setColor(0.55, 0.55, 0.55, 1)
    love.graphics.rectangle("line", TIMER_X, TIMER_Y, TIMER_W, TIMER_H, 6, 6)

    local timeStr
    if game.state == "SUDDEN_DEATH" then
        timeStr = "SD"
    else
        local t = math.max(0, math.ceil(game.matchTimer))
        timeStr = string.format("%d", t)
    end
    love.graphics.setColor(1, 1, 0.2, 1)
    centreText(Assets.fontMedium, timeStr, TIMER_X, TIMER_X + TIMER_W, TIMER_Y + 8)

    -- ── Touch counter (above the active side's court) ─────────────────────
    local ball = game.ball
    if ball and not ball.serving and ball.touchCount > 0 and ball.touchSide then
        local touchStr = tostring(ball.touchCount)
        local tcx = (ball.touchSide == 1) and 180 or 580
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setFont(Assets.fontMedium)
        love.graphics.print(touchStr, tcx, C.NET_TOP_Y - 40)
    end

    -- ── SUDDEN DEATH text ─────────────────────────────────────────────────
    if game.state == "SUDDEN_DEATH" then
        love.graphics.setColor(1, 0.2, 0.2, 0.9)
        love.graphics.setFont(Assets.fontMedium)
        local sdw = Assets.fontMedium:getWidth("SUDDEN DEATH")
        love.graphics.print("SUDDEN DEATH", (800 - sdw) / 2, C.NET_TOP_Y - 40)
    end

    -- ── SERVE! banner ─────────────────────────────────────────────────────
    if game.state == "SERVE" then
        Hud.drawCentredBanner(Assets.ui.serveBanner, 360, 60)
    end

    -- ── POINT! banner ─────────────────────────────────────────────────────
    if game.state == "POINT_SCORED" then
        Hud.drawCentredBanner(Assets.ui.pointBanner, 360, 60)
    end

    -- ── GAME OVER overlay ─────────────────────────────────────────────────
    if game.state == "GAME_OVER" then
        Hud.drawGameOver(game)
    end

    -- ── Reset colour ──────────────────────────────────────────────────────
    love.graphics.setColor(1, 1, 1, 1)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Draw a UI banner centred horizontally at mid-y, with given pixel dimensions
-- ─────────────────────────────────────────────────────────────────────────────

function Hud.drawCentredBanner(quad, bw, bh)
    local _, _, qw, qh = quad:getViewport()
    -- Use uniform scaling to preserve aspect ratio and prevent cutting
    local scale = math.min(bw / qw, bh / qh)
    local drawW = qw * scale
    local drawH = qh * scale
    local bx = (800 - drawW) / 2
    local by = (600 - drawH) / 2 - 60
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Assets.uiSheet, quad, bx, by, 0, scale, scale)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Game-over overlay
-- ─────────────────────────────────────────────────────────────────────────────

function Hud.drawGameOver(game)
    -- Dim the court
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, 800, 600)

    -- ── Win / Draw banner (centred, large) ───────────────────────────────
    love.graphics.setColor(1, 1, 1, 1)
    local bannerW, bannerH = 500, 100
    local bx = (800 - bannerW) / 2
    local by = 60

    if game.winner == "draw" then
        local iw = Assets.drawBanner:getWidth()
        local ih = Assets.drawBanner:getHeight()
        love.graphics.draw(Assets.drawBanner, bx, by, 0,
            bannerW / iw, bannerH / ih)
    elseif game.winner == "player1" then
        local _, _, qw, qh = Assets.p1WinQuad:getViewport()
        love.graphics.draw(Assets.winBanners, Assets.p1WinQuad,
            bx, by, 0, bannerW / qw, bannerH / qh)
    elseif game.winner == "player2" then
        local _, _, qw, qh = Assets.p2WinQuad:getViewport()
        love.graphics.draw(Assets.winBanners, Assets.p2WinQuad,
            bx, by, 0, bannerW / qw, bannerH / qh)
    end

    -- ── Final scores ──────────────────────────────────────────────────────
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(Assets.fontLarge)
    local scoreStr = string.format("%d  –  %d", game.scores[1], game.scores[2])
    local sw = Assets.fontLarge:getWidth(scoreStr)
    love.graphics.print(scoreStr, (800 - sw) / 2, 175)

    -- ── Match history (last 5) ────────────────────────────────────────────
    love.graphics.setFont(Assets.fontSmall)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Match History:", 100, 240)

    local history = game.matchHistory or {}
    for i, rec in ipairs(history) do
        local line = string.format("%s | %s | %d – %d | %s",
            rec.date, rec.mode, rec.score_p1, rec.score_p2, rec.winner)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print(line, 100, 240 + i * 22)
    end

    -- ── Buttons ───────────────────────────────────────────────────────────
    -- Play Again
    Hud.drawButton(200, 480, 160, 44, "Play Again", game.hoveredBtn == "again")
    -- Main Menu
    Hud.drawButton(440, 480, 160, 44, "Main Menu",  game.hoveredBtn == "menu")
    -- Clear History
    Hud.drawButton(320, 540, 160, 30, "Clear History", game.hoveredBtn == "clear")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Simple button renderer
-- ─────────────────────────────────────────────────────────────────────────────

function Hud.drawButton(x, y, w, h, label, hovered)
    local r, g, b = 0.2, 0.2, 0.5
    if hovered then r, g, b = 0.4, 0.4, 0.9 end
    love.graphics.setColor(r, g, b, 0.85)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(Assets.fontSmall)
    local tw = Assets.fontSmall:getWidth(label)
    local th = Assets.fontSmall:getHeight()
    love.graphics.print(label, x + (w - tw) / 2, y + (h - th) / 2)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Hit-test a game-over button (returns button id or nil)
-- ─────────────────────────────────────────────────────────────────────────────

function Hud.gameOverButtonAt(mx, my)
    local buttons = {
        { id = "again", x = 200, y = 480, w = 160, h = 44 },
        { id = "menu",  x = 440, y = 480, w = 160, h = 44 },
        { id = "clear", x = 320, y = 540, w = 160, h = 30 },
    }
    for _, btn in ipairs(buttons) do
        if mx >= btn.x and mx <= btn.x + btn.w
        and my >= btn.y and my <= btn.y + btn.h then
            return btn.id
        end
    end
    return nil
end

return Hud
