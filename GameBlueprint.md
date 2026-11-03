# Project Blueprint: Recoil Arena

**Working Title:** Recoil Arena  
**Engine:** Godot 4.x (GDScript)  
**Target Platforms:** PC (Windows/Linux/Mac), Web (HTML5 / GitHub Pages), Mobile (Android)  
**Genre:** 1v1 Physics-Based Arcade Brawler / Duel  

---

## 1. Executive Summary & High Concept
**Recoil Arena** is a fast-paced, minimalist 2D physics-based 1v1 dueling game where two handguns float in a closed rectangular arena. Players have **no direct movement controls**. Navigation, aiming, and positioning depend entirely on **Newtonian third-law recoil momentum** generated whenever a player fires their weapon. 

The primary objective is to calculate bounce trajectories off wall boundaries to strike the opponent's gun while actively managing recoil to dodge incoming fire.

---

## 2. Core Mechanics & Game Loop

### 2.1 Locomotion & Physics
* **Zero Engine Propulsion:** No thrusters, joysticks, or WASD movement. Movement is $100\%$ recoil-driven.
* **Newton’s Third Law:** Firing a projectile exerts an instantaneous impulse force vector opposite to the firing angle ($F = ma$).
* **Torque & Rotational Drift:** Firing off-center introduces angular velocity, causing the gun to spin. A subtle ambient rotational drift ensures guns are never locked in static orientations.
* **Environmental Gravity & Air Resistance:** Constant light downward gravity force pulling weapons toward the floor, with linear and angular drag applied to stabilize continuous endless acceleration.
* **Boundary Dynamics:** Weapons bounce elasticaly off arena walls ($Restitution \approx 0.7$) without sustaining damage.

### 2.2 Combat & Ballistics
* **Specular Reflection:** Bullets bounce off walls following exact angle-of-incidence formulas ($Angle_{In} = Angle_{Out}$).
* **Max Bounce Count:** Bullets dissipate after a fixed number of reflections (default: 5 bounces).
* **Owner Immunity Window:** Bullets cannot damage their launcher on initial exit, but *can* kill their launcher if reflected off a wall back into them (Self-Harm Mechanics).
* **Instant-Kill Collisions:** A single bullet hit on an opponent's chassis triggers an elimination and awards a point.

### 2.3 Win Condition
* Matches run on a round-based structure. First player to reach **5 points** wins the match.

---

## 3. Visual & Audio Direction

### 3.1 Visual Aesthetics
* **Style:** Flat 2D low-poly vector geometry with neon accent lighting against a dark slate/grid background.
* **Color Palette:**
  * Background: `#1e2029` (Dark Charcoal) / `#262936` (Grid Lines)
  * Player 1 (Blue): `#3b82f6` base, `#60a5fa` highlights
  * Player 2 (Red): `#ef4444` base, `#f87171` highlights
* **Game Juice & VFX:**
  * Directional particle bursts for muzzle flashes.
  * Kinetic particle sparks when bullets impact wall boundaries.
  * Radial explosion particle emitters on player elimination.
  * Translucent motion trails tracking bullet paths.

### 3.2 Audio Requirements
* **Sound Effects (SFX):**
  * Punchy high-energy gunshots ("Pew / Blast").
  * Metallic/Synthesized wall ricochet chirps.
  * Heavy explosion impact for eliminations.
  * Win fanfare chime.

---

## 4. Technical Architecture (Godot 4)

### 4.1 Node Hierarchy & Object Structure

```text
recoil-arena/
├── .github/
│   └── workflows/
│       └── deploy-gh-pages.yml  # Automated Web Build deployment
├── assets/
│   ├── audio/                   # SFX files (.wav / .ogg)
│   ├── fonts/                   # Orbitron / Inter fonts
│   └── sprites/                 # UI icons / custom vector shapes
├── scenes/
│   ├── MainMenu.tscn            # Title screen & mode select
│   ├── Arena.tscn               # Primary game container
│   ├── Gun.tscn                 # Player entity (RigidBody2D)
│   ├── Bullet.tscn              # Projectile entity (Area2D / CharacterBody2D)
│   └── UI.tscn                  # HUD score overlay & banners
├── scripts/
│   ├── Autoload/
│   │   ├── GameManager.gd       # Scores, game states, scene switching
│   │   └── AudioManager.gd      # SFX & music pool management
│   ├── Arena.gd
│   ├── Gun.gd
│   └── Bullet.gd
├── project.godot
└── README.md
```

### 4.2 Class Roles & Responsibilities

1. **`GameManager.gd` (Autoload Singleton)**
   * Manages global game state (`MENU`, `PLAYING`, `ROUND_OVER`, `GAME_OVER`).
   * Tracks `p1_score` and `p2_score`.
   * Triggers round resets and victory screens.

2. **`Gun.gd` (Extends `RigidBody2D`)**
   * Configured as a physical body with mass, linear velocity, and angular dampening.
   * Handles user input mapping (`KeyA` for P1, `KeyL` / `ArrowLeft` for P2, On-Screen Touch for Mobile).
   * Calculates impulse vectors upon firing:
     $$\vec{v}_{impulse} = -\text{Vector2.RIGHT}.rotated(rotation) \times \text{RECOIL\_FORCE}$$
   * Controls rate-of-fire cooldowns.

3. **`Bullet.gd` (Extends `Area2D` or `CharacterBody2D`)**
   * Moves at constant high linear velocity.
   * Uses `RayCast2D` or collision normals to calculate vector reflections:
     $$\vec{v}_{reflected} = \vec{v}_{in} - 2(\vec{v}_{in} \cdot \vec{n})\vec{n}$$
   * Tracks bounce counts before freeing memory (`queue_free()`).

---

## 5. Controls & Input Mapping

| Action | PC Keyboard (Local 1v1) | Mobile (Android Same-Device) | Gamepad (Optional) |
| :--- | :--- | :--- | :--- |
| **Player 1 Shoot** | `Key A` | Left Side Screen Tap / Button | `L1` or `Left Trigger` |
| **Player 2 Shoot** | `Key L` / `Left Arrow` | Right Side Screen Tap / Button | `R1` or `Right Trigger` |
| **Pause / Menu** | `Key ESC` | Top Bar Pause Icon | `Start Button` |

---

## 6. GitHub Portfolio Optimization Strategy

To ensure this repository serves as a showcase piece on GitHub:

1. **README.md Structure:**
   * **Live Web Demo:** Embedded badge linking directly to the hosted GitHub Pages HTML5 build.
   * **Project Preview:** High-quality gameplay GIF demonstration.
   * **Key Highlights:** Bulleted breakdown of physics calculations, Godot node structure, and cross-platform compilation strategy.
   * **Releases Section:** Pre-compiled downloadable binaries: `.exe` (Windows) and `.apk` (Android).
2. **Clean Commit History:** Meaningful atomic commits following semantic conventions (e.g., `feat: implement vector bounce reflections`, `fix: tune gun rotational dampening`).
3. **Automated CI/CD Workflows:** A GitHub Actions script (`.github/workflows/deploy-gh-pages.yml`) to automatically compile and publish Godot web builds whenever updates are pushed to `main`.

---

## 7. Roadmap & Future Expansion Ideas

* **Phase 1 (Core Prototype):** Implement basic arena, Godot `RigidBody2D` guns, bullet bounce math, score state, and victory overlay.
* **Phase 2 (Game Polish & Juice):** Integrate particle systems, dynamic screen shake on recoil/hits, audio SFX synthesis/files, and UI transition animations.
* **Phase 3 (Mobile & Input Adaptation):** Add touch UI controls, optimize screen scaling for different aspect ratios, and export APKs.
* **Phase 4 (Power-Ups & Map Hazards):** Add destructible obstacles, gravity wells, portal edges, and weapon pickup drops (Shotgun, Sniper, Laser Sight).