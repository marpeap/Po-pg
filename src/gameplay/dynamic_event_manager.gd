## DynamicEventManager — spawns world events on a random timer during exploration.
## 7 event types keep the world feeling alive and reward attentive players.
## Fires a signal that ExplorationMap and HUD react to (banner announcement).
## Events fire every 90-180 seconds while the hero is in EXPLORING state.
extends Node

enum EventType {
	CARAVAN_PASSAGE    = 0,  ## Travelling merchant caravan — bonus trade window
	METEOR_SHOWER      = 1,  ## Star_dust falls in a zone — temporary bonus nodes
	TREMOR             = 2,  ## Earthquake reveals hidden resources in one zone
	BANDIT_AMBUSH      = 3,  ## Enemy camp spawns between hero and castle
	ANCIENT_BROADCAST  = 4,  ## Sage's voice — grants all heroes XP burst
	MIGRATION          = 5,  ## Animal herd passes — feather/frog_skin/bone drops
	RIFT_OPENING       = 6,  ## Dimensional rift — spawns rare/epic enemy camp
}

const EVENT_NAMES: Array[String] = [
	"Caravane Marchande !",
	"Pluie de Meteorites !",
	"Tremblement de Terre !",
	"Embuscade de Bandits !",
	"Voix de l'Ancien...",
	"Grande Migration !",
	"Faille Dimensionnelle !",
]

const EVENT_DESCRIPTIONS: Array[String] = [
	"Une caravane passe — echanges favorables pour 60 secondes.",
	"Des meteorites s'ecrasent — recolte de Poussieres d'Etoiles.",
	"Le sol tremble — des ressources rares emergent.",
	"Des bandits bloquent la route — defense requise !",
	"L'Ancien parle — tous les heros gagnent de l'experience.",
	"Un troupeau passe — plumes et peaux a ramasser.",
	"Une faille s'ouvre — entites puissantes emergent.",
]

## Event weights for random selection (higher = more frequent).
const EVENT_WEIGHTS: Array[int] = [
	25,  ## CARAVAN_PASSAGE — common
	20,  ## METEOR_SHOWER — common
	20,  ## TREMOR — common
	15,  ## BANDIT_AMBUSH — moderate
	10,  ## ANCIENT_BROADCAST — rare
	20,  ## MIGRATION — common
	10,  ## RIFT_OPENING — rare
]

const MIN_INTERVAL := 90.0
const MAX_INTERVAL := 180.0

## Duration (seconds) each event stays active.
const EVENT_DURATIONS: Array[float] = [
	60.0,  ## CARAVAN_PASSAGE
	45.0,  ## METEOR_SHOWER
	40.0,  ## TREMOR
	30.0,  ## BANDIT_AMBUSH
	 0.0,  ## ANCIENT_BROADCAST (instant)
	50.0,  ## MIGRATION
	60.0,  ## RIFT_OPENING
]

signal event_started(event_type: int, name_str: String, description: String, duration: float)
signal event_ended(event_type: int)
## Emitted so ExplorationMap can act on specific event types.
signal spawn_ambush_requested(world_pos: Vector2)
signal spawn_meteor_nodes_requested(zone_idx: int)
signal spawn_migration_drops_requested(world_pos: Vector2)
signal spawn_rift_camp_requested(world_pos: Vector2)
signal reveal_zone_resources_requested(zone_idx: int)

var _active: bool   = false
var _timer:  float  = 0.0
var _next_fire: float = 90.0
var _rng: RandomNumberGenerator = null
var _current_event: int  = -1
var _event_timer:   float = 0.0

## Reference to hero node for positioning events near/ahead of hero.
var _hero_ref: Node = null

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_next_fire = _rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)

## Called by ExplorationMap when exploration begins.
func start_events(hero_node: Node) -> void:
	_hero_ref = hero_node
	_active   = true
	_timer    = 0.0

## Called by ExplorationMap when hero returns to TD mode.
func stop_events() -> void:
	_active = false
	if _current_event >= 0:
		event_ended.emit(_current_event)
		_current_event = -1

func _process(delta: float) -> void:
	if not _active:
		return

	## Countdown to next event
	_timer += delta
	if _timer >= _next_fire:
		_timer     = 0.0
		_next_fire = _rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)
		_fire_random_event()

	## Active event countdown
	if _current_event >= 0:
		var dur: float = EVENT_DURATIONS[_current_event]
		if dur > 0.0:
			_event_timer -= delta
			if _event_timer <= 0.0:
				event_ended.emit(_current_event)
				_current_event = -1

func _fire_random_event() -> void:
	var evt_type: int = _weighted_random()
	_current_event = evt_type
	_event_timer   = EVENT_DURATIONS[evt_type]
	event_started.emit(evt_type, EVENT_NAMES[evt_type], EVENT_DESCRIPTIONS[evt_type], _event_timer)
	_apply_event(evt_type)

func _apply_event(evt_type: int) -> void:
	var hero_pos: Vector2 = Vector2.ZERO
	if _hero_ref != null and _hero_ref.has_method("get_global_position"):
		hero_pos = _hero_ref.get_global_position()
	elif _hero_ref != null:
		hero_pos = _hero_ref.global_position

	match evt_type:
		EventType.CARAVAN_PASSAGE:
			## Spawn a temporary merchant NPC ahead of hero
			var ahead: Vector2 = hero_pos + Vector2(_rng.randf_range(400, 800), 0)
			get_tree().call_group("exploration_map", "spawn_caravan", ahead)

		EventType.METEOR_SHOWER:
			## Add Star_dust nodes to a random zone
			var zone: int = _rng.randi_range(0, 14)
			spawn_meteor_nodes_requested.emit(zone)

		EventType.TREMOR:
			## Reveal hidden resources in a zone near hero
			var zone_x: int = int(hero_pos.x / 3200.0)
			var zone: int   = clampi(zone_x + _rng.randi_range(-1, 1), 0, 14)
			spawn_meteor_nodes_requested.emit(zone)
			reveal_zone_resources_requested.emit(zone)

		EventType.BANDIT_AMBUSH:
			## Spawn an enemy camp between hero and castle
			var midpoint: Vector2 = Vector2(
				hero_pos.x * 0.5 + _rng.randf_range(-200, 200),
				_rng.randf_range(720, 1440)
			)
			spawn_ambush_requested.emit(midpoint)

		EventType.ANCIENT_BROADCAST:
			## Instant XP grant to hero — no spatial component
			HeroProgression.add_xp(100)

		EventType.MIGRATION:
			## Drop collectible items along hero's path
			var mig_pos: Vector2 = hero_pos + Vector2(_rng.randf_range(200, 600), 0)
			spawn_migration_drops_requested.emit(mig_pos)

		EventType.RIFT_OPENING:
			## Powerful enemy camp spawns ahead of hero
			var rift_pos: Vector2 = hero_pos + Vector2(_rng.randf_range(500, 1000), 0)
			spawn_rift_camp_requested.emit(rift_pos)

## Weighted random selection from EventType.
func _weighted_random() -> int:
	var total: int = 0
	for w: int in EVENT_WEIGHTS:
		total += w
	var roll: int = _rng.randi_range(0, total - 1)
	var cumulative: int = 0
	for i: int in range(EVENT_WEIGHTS.size()):
		cumulative += EVENT_WEIGHTS[i]
		if roll < cumulative:
			return i
	return 0
