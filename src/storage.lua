-- src/storage.lua: Persist match history to scores.txt via love.filesystem.
-- Each line: date|mode|score_p1|score_p2|winner|duration

local Storage = {}

local FILE = "scores.txt"
local MAX_RECORDS = 10   -- keep at most this many lines

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- Parse a single CSV line into a record table.
local function parseLine(line)
    local date, mode, sp1, sp2, winner, dur =
        line:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
    if not date then return nil end
    return {
        date     = date,
        mode     = mode,
        score_p1 = tonumber(sp1) or 0,
        score_p2 = tonumber(sp2) or 0,
        winner   = winner,
        duration = tonumber(dur) or 0,
    }
end

-- Format a record as a single CSV line (no trailing newline).
local function formatLine(r)
    return string.format("%s|%s|%d|%d|%s|%d",
        r.date, r.mode, r.score_p1, r.score_p2, r.winner, r.duration)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Load all stored records (up to MAX_RECORDS, newest-first).
--- Returns a list of record tables.
function Storage.load()
    local records = {}
    if not love.filesystem.getInfo(FILE) then
        return records
    end
    local content = love.filesystem.read(FILE)
    if not content then return records end

    for line in content:gmatch("[^\n]+") do
        local rec = parseLine(line)
        if rec then
            table.insert(records, rec)
        end
    end
    return records
end

--- Save a new match result.
--- @param mode     string  "pvp" or "cpu"
--- @param score_p1 number
--- @param score_p2 number
--- @param winner   string  "player1", "player2", or "draw"
--- @param duration number  match duration in seconds
function Storage.save(mode, score_p1, score_p2, winner, duration)
    -- Build new record
    local now = os.date("%Y-%m-%d %H:%M")
    local rec = {
        date     = now,
        mode     = mode,
        score_p1 = score_p1,
        score_p2 = score_p2,
        winner   = winner,
        duration = math.floor(duration),
    }

    -- Load existing, prepend new, trim to MAX_RECORDS
    local existing = Storage.load()
    table.insert(existing, 1, rec)
    while #existing > MAX_RECORDS do
        table.remove(existing)
    end

    -- Write back
    local lines = {}
    for _, r in ipairs(existing) do
        table.insert(lines, formatLine(r))
    end
    love.filesystem.write(FILE, table.concat(lines, "\n") .. "\n")
end

--- Delete all stored records.
function Storage.clear()
    if love.filesystem.getInfo(FILE) then
        love.filesystem.remove(FILE)
    end
end

--- Return only the last `n` records (default 5).
function Storage.recent(n)
    n = n or 5
    local all = Storage.load()
    local out = {}
    for i = 1, math.min(n, #all) do
        out[i] = all[i]
    end
    return out
end

return Storage
