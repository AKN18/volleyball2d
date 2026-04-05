-- main.lua: Löve2D entry point for Spike Arena.
-- Wires all love callbacks to the Game module.

local Game = require("src.game")

-- ─────────────────────────────────────────────────────────────────────────────

function love.load()
    -- Linear filter: all sprites are downscaled from large source images,
    -- so bilinear gives cleaner results than nearest-neighbour.
    love.graphics.setDefaultFilter("linear", "linear")
    Game.load()
end

function love.update(dt)
    -- Cap dt to avoid huge physics steps when window is dragged / lagged
    dt = math.min(dt, 0.05)
    Game.update(dt)
end

function love.draw()
    Game.draw()
end

function love.keypressed(key, scancode, isrepeat)
    if isrepeat then return end   -- ignore key-repeat events
    Game.keypressed(key)
end

function love.keyreleased(key)
    Game.keyreleased(key)
end

function love.mousepressed(x, y, button)
    Game.mousepressed(x, y, button)
end

function love.mousemoved(x, y)
    Game.mousemoved(x, y)
end
