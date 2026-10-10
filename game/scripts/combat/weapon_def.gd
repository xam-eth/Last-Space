class_name WeaponDef
extends Resource
## Definisi senjata (data-driven — DATA_CONTRACTS.md §2.4).

@export var id: StringName
@export var weapon_type: String  ## laser | missile | cannon
@export var damage: int
@export var range: float
@export var cooldown_ticks: int
@export var projectile_speed: float
@export var tracking: bool  ## missile: mengejar target
@export var vs_structure_multiplier: float = 1.0  ## damage ke bangunan/turret
@export var vs_shield_multiplier: float = 1.0
