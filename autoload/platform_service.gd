extends Node

signal achievement_unlocked(achievement_id: String)

const ACHIEVEMENTS := {
	"FIRST_FLIGHT": "Complete the first level",
	"VERDANT_RESTORED": "Complete Verdant Ruins",
	"CRYSTAL_RESTORED": "Complete Crystal Cloudworks",
	"SKY_REUNITED": "Complete the story",
	"PERFECT_ORBIT": "Earn all 90 medals"
}

var unlocked: Dictionary = {}
var stats: Dictionary = {}

func provider_name() -> String:
	return "offline"

func unlock_achievement(achievement_id: String) -> void:
	if not ACHIEVEMENTS.has(achievement_id) or unlocked.has(achievement_id):
		return
	unlocked[achievement_id] = true
	achievement_unlocked.emit(achievement_id)

func set_stat(stat_id: String, value: float) -> void:
	stats[stat_id] = value

func flush() -> void:
	# Offline provider has no remote queue; Steam adapter will flush here.
	return
