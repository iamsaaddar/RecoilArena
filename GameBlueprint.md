# Recoil Arena

**Engine:** Godot 4.7 (GDScript)
**Platforms:** Desktop and Android
**Genre:** 1v1 physics-based arcade duel

## Overview

Recoil Arena is a local two-player duel in a closed 2D arena. Players cannot steer their guns directly. They move by firing: each shot sends the projectile forward and pushes the gun in the opposite direction. Players use recoil, rotation and wall-bouncing shots to line up hits and avoid incoming fire.

A player is eliminated after taking three hits. The winner can start another round from the result screen.

## Gameplay

### Gun movement

- Movement is driven by recoil from firing.
- Light gravity, linear drag and angular drag keep movement readable.
- Guns rotate continuously and bounce off the arena boundaries.
- Gun-to-gun collisions resolve overlap and apply a restrained impulse.

### Projectiles

- Bullets travel at a constant speed and leave a short trail.
- The first wall contact reflects the projectile using the collision normal.
- A projectile disappears on its next wall contact.
- A bullet cannot damage the gun that fired it.
- A direct hit damages the opponent and applies knockback.

### Match flow

- Each player can take three hits.
- The third hit eliminates that player and ends the round.
- The result screen offers a replay with a short countdown.
- Wins are not accumulated between rounds.

## Controls

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Fire on desktop | A | L or Left Arrow |
| Fire on mobile | Tap the left half of the screen | Tap the right half of the screen |
| Pause / resume | Esc or the on-screen pause control | Esc or the on-screen pause control |

Mobile gameplay uses landscape orientation. Both screen halves support simultaneous touches.

## Project structure

```text
RecoilArena/
├── assets/audio/                # Gameplay sound effects
├── scenes/
│   ├── arena/Arena.tscn         # Arena wall collision bodies
│   ├── effects/HitSpark.tscn    # Hit and elimination effect
│   ├── main/Main.tscn           # Application entry point
│   ├── player/Gun.tscn          # Player collision body
│   └── projectiles/Bullet.tscn  # Projectile collision body
├── scripts/
│   ├── effects/HitSpark.gd
│   ├── player/Gun.gd
│   ├── projectiles/Bullet.gd
│   └── systems/
│       ├── Arena.gd
│       ├── HealthHUD.gd
│       └── Main.gd
├── GameBlueprint.md
├── project.godot
└── samplefile.html              # Standalone legacy browser prototype
```

## Code responsibilities

- **Main.gd:** Builds the main menu, controls and settings panels, pause flow, and active arena instance.
- **Arena.gd:** Creates the players, camera, projectile container and health HUD. Handles hits, audio, screen shake, elimination and replay.
- **Gun.gd:** Handles recoil movement, wall and player collisions, firing input, hit reactions and gun drawing. The frozen RigidBody2D provides collision participation while movement is integrated in GDScript.
- **Bullet.gd:** Moves projectiles with CharacterBody2D collision queries, reflects the first wall hit and removes the projectile after its next wall contact.
- **HealthHUD.gd:** Draws the three-hit health display and round result/countdown overlay.
- **HitSpark.gd:** Draws the particle bursts used for hits and eliminations.

## Project status

- [x] Core recoil movement, aiming through rotation and gun collisions
- [x] Projectile hits, owner immunity and one-wall bounce limit
- [x] Three-hit elimination and replay countdown
- [x] Desktop keyboard and mobile split-screen touch input
- [x] Pause menu, controls screen and master volume setting
- [x] Health display, screen shake, sound effects and particle effects
- [ ] Validate final desktop and Android exports
- [ ] Prepare public-facing setup documentation and gameplay capture

Power-ups and arena hazards are possible future additions and are outside the scope of the current release.

## Reference

`samplefile.html` is an earlier standalone browser prototype. It is retained as a visual and gameplay reference; the current game is the Godot project described above.
