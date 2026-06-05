## Mount — monture équipable par le héros en mode EXPLORING.
## Augmente la vitesse du héros d'un facteur MOUNT_SPEED_MULT.
## Fabriquée via crafting_system.gd (item MOUNT_SCROLL dans ItemInventory).
## Persistance : session uniquement (réinitialisé sur session_reset).
## Usage:
##   mount.is_mounted → bool
##   mount.try_mount(hero: Node2D) → bool  (active si héros a le MOUNT_SCROLL)
##   mount.dismount(hero: Node2D)
##   signal mounted_changed(is_mounted: bool)
extends Node

const MOUNT_SPEED_MULT := 2.2
## ID correspondant à ItemInventory.Item.MOUNT_SCROLL (ajouté en id=28).
const MOUNT_ITEM_ID := 28

signal mounted_changed(is_mounted: bool)

var is_mounted: bool = false

## Tente de monter la monture. Si déjà monté, descend (toggle).
## Retourne true si la monture a été activée, false sinon.
func try_mount(hero: Node2D) -> bool:
	if is_mounted:
		dismount(hero)
		return false
	if not ItemInventory.has_item(MOUNT_ITEM_ID):
		return false
	is_mounted = true
	_apply_mount(hero, true)
	mounted_changed.emit(true)
	return true

## Descend de la monture et restaure la vitesse normale.
func dismount(hero: Node2D) -> void:
	if not is_mounted:
		return
	is_mounted = false
	_apply_mount(hero, false)
	mounted_changed.emit(false)

## Applique ou retire le modificateur de vitesse et change le sprite du héros.
func _apply_mount(hero: Node2D, mounting: bool) -> void:
	if hero == null:
		return
	## Modifier _speed_mult via set() pour être null-safe si la propriété manque.
	if hero.get("_speed_mult") != null:
		hero.set("_speed_mult", MOUNT_SPEED_MULT if mounting else 1.0)
	## Changer le sprite : cavalier monté ou sprite cavalier piéton.
	var sprite: Node = hero.get_node_or_null("Sprite2D")
	if sprite == null:
		## Le héros utilise un AnimatedSprite2D — chercher par type.
		for child: Node in hero.get_children():
			if child is AnimatedSprite2D:
				sprite = child
				break
	if sprite == null:
		return
	if mounting:
		var tex: Texture2D = load("res://assets/sprites/garrison/mount_horse.png")
		if tex != null:
			if sprite is Sprite2D:
				(sprite as Sprite2D).texture = tex
				sprite.scale = Vector2(0.85, 0.85)
			## AnimatedSprite2D : on ne remplace pas les frames, on tinte juste (en attente sprite)
		else:
			## Sprite de monture absent : tinter le sprite existant en doré pour indiquer l'état.
			sprite.modulate = Color(1.0, 0.85, 0.30)
	else:
		## Restaurer : retirer le tint ou remettre la texture cavalier.
		if sprite is Sprite2D:
			var orig_tex: Texture2D = load("res://assets/sprites/garrison/cavalier.png")
			if orig_tex == null:
				orig_tex = load("res://assets/sprites/garrison/archer.png")
			if orig_tex != null:
				(sprite as Sprite2D).texture = orig_tex
				sprite.scale = Vector2(1.0, 1.0)
		## Dans tous les cas, retirer le tint.
		sprite.modulate = Color(1.0, 1.0, 1.0)

## Réinitialise l'état de la monture (appelé par session_reset ou retour TD).
func reset() -> void:
	is_mounted = false
