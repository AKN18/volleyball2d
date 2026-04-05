-- conf.lua: Löve2D window and module configuration for Spike Arena

function love.conf(t)
    t.title          = "Spike Arena"
    t.version        = "11.4"          -- minimum Löve version
    t.window.width   = 800
    t.window.height  = 600
    t.window.vsync   = 1               -- 1 = adaptive vsync
    t.window.resizable = false
    t.window.msaa    = 0

    -- disable unused modules to speed up startup
    t.modules.joystick = false
    t.modules.video    = false
    t.modules.touch    = false
end
