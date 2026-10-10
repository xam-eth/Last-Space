class_name EconomyConfig
extends Resource
## Konfigurasi ekonomi awal (data-driven — DATA_CONTRACTS.md §2.1).

@export var starting_resources: Dictionary = {"energy": 200, "minerals": 100}
@export var storage_caps: Dictionary = {"energy": 1000, "minerals": 500}
