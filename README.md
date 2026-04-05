# Spike Arena

A fast-paced 2D volleyball game built with LÖVE2D. Play against a friend or challenge the CPU in this arcade-style volleyball showdown!

---

## Screenshots

<!-- Paste your image links below -->
<img width="1581" height="1257" alt="grafik" src="https://github.com/user-attachments/assets/18048903-9fe0-495f-aeb6-4b8d94b4b8b2" />


<img width="1597" height="1247" alt="grafik" src="https://github.com/user-attachments/assets/4950cdca-6381-48a4-93b8-bcb3c7e905cb" />


---

## How to Run

### Prerequisites

- Install [LÖVE2D](https://love2d.org/) version 11.4 or higher

### Running the Game

```bash
# Run with LÖVE
love .
```

## How to Play

### Game Modes

- **Player vs Player (PvP):** Two players on the same keyboard
- **Player vs CPU:** Face off against an AI opponent

### Controls

#### Player 1 (Left Side - Blue)
| Key | Action |
|-----|--------|
| `A` | Move Left |
| `D` | Move Right |
| `W` | Jump |
| `S` | Dig (defensive stance) |
| `Left Shift` | Hit / Serve |

#### Player 2 (Right Side - Red)
| Key | Action |
|-----|--------|
| `←` (Left Arrow) | Move Left |
| `→` (Right Arrow) | Move Right |
| `↑` (Up Arrow) | Jump |
| `↓` (Down Arrow) | Dig (defensive stance) |
| `Right Ctrl` | Hit / Serve |

### Gameplay Mechanics

- **Serving:** Stand still and press your hit key to serve the ball
- **Spiking:** Hit the ball while airborne for a powerful spike
- **Digging:** Hold down (S or ↓) to enter defensive stance
- **Touch Limit:** Maximum 3 touches per side before the ball must go over
- **Match Timer:** 2 minutes per match
- **Sudden Death:** If tied when time expires, first point wins!

### Scoring

- Points are awarded when the ball lands on the opponent's side
- Spikes that score trigger a dramatic screen shake effect
- Win by having the most points when time runs out

### Menu Navigation

- Use your **mouse** to click buttons in menus
- Press `Escape` during gameplay to return to menu

---

## Project Structure

```
volleyball2d/
├── conf.lua              # LÖVE2D configuration (window, title, modules)
├── main.lua              # Entry point - wires up all callbacks
├── README.md             # This file
├── assets/
│   ├── backgrounds/
│   │   ├── court_background.png   # Gameplay background
│   │   └── menu_background.png    # Menu screen background
│   └── sprites/
│       ├── ball_sheet.png         # Animated ball sprites
│       ├── ball_shadow.png        # Ball shadow effect
│       ├── draw_banners.png       # Score banners
│       └── player1_sheet.png      # Player animations
│       └── ...                    # Additional player sprites
└── src/
    ├── ai.lua              # CPU opponent AI logic
    ├── assets.lua          # Asset loading and management
    ├── ball.lua            # Ball physics and collision
    ├── constants.lua       # Game tuning values
    ├── game.lua            # Main game state machine
    ├── hud.lua             # Heads-up display (scores, timers)
    ├── player.lua          # Player physics and animation
    └── storage.lua         # Match history persistence
```
