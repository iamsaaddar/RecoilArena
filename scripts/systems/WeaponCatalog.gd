extends RefCounted
## Shared weapon definitions used by the selection UI and combat scripts.

const PULSE := "pulse_blaster"
const HEAVY := "heavy_cannon"
const RAPID := "rapid_blaster"
const RAIL := "railgun"

const DEFINITIONS := {
	PULSE: {"name": "PULSE BLASTER", "cooldown": 0.34, "recoil": 520.0, "projectile_speed": 720.0, "projectile_radius": 5.0, "charge_time": 0.0, "accent": Color("38d9ff")},
	HEAVY: {"name": "HEAVY CANNON", "cooldown": 0.82, "recoil": 760.0, "projectile_speed": 610.0, "projectile_radius": 9.0, "charge_time": 0.0, "accent": Color("f59e0b")},
	RAPID: {"name": "RAPID BLASTER", "cooldown": 0.14, "recoil": 310.0, "projectile_speed": 790.0, "projectile_radius": 3.5, "charge_time": 0.0, "accent": Color("a78bfa")},
	RAIL: {"name": "RAILGUN", "cooldown": 0.95, "recoil": 900.0, "projectile_speed": 1250.0, "projectile_radius": 6.0, "charge_time": 0.85, "accent": Color("f472b6")},
}

static func get_definition(weapon_id: String) -> Dictionary:
	return DEFINITIONS.get(weapon_id, DEFINITIONS[PULSE]).duplicate()


static func get_ids() -> Array[String]:
	return [PULSE, HEAVY, RAPID, RAIL]
