## GameStateMachine — Autoload singleton
## ADR-005: Game State Machine / Autoload
## GDD Req: TR-gsm-001
##
## Typed FSM for the four game states: PLAYING, GAME_OVER, RESETTING, EXPLORING.
## Valid transitions:
##   PLAYING    → GAME_OVER   (castle fell)
##   PLAYING    → EXPLORING   (hero enters portal — only between waves with ≥1 tower)
##   EXPLORING  → PLAYING     (hero returns to TD via return portal)
##   GAME_OVER  → RESETTING   (player taps restart)
##   RESETTING  → PLAYING     (auto — immediately after session_reset signal)
## Broadcast via signal — all systems subscribe, none pull-poll.
extends Node

## The four states of a Garrison session.
enum State {
	PLAYING,
	GAME_OVER,
	RESETTING,
	EXPLORING,
}

## Emitted on every valid state transition. Subscribers react to the new state.
signal game_state_changed(new_state: State)

## Emitted when RESETTING begins. All pooled nodes reset themselves on this signal.
## Followed immediately by PLAYING — do not transition again in response to this.
signal session_reset

## Current FSM state. Read-only from outside — use transition_to() to change.
var current_state: State = State.PLAYING

## Valid transition map: key = from-state, value = to-state set.
const _VALID_TRANSITIONS: Dictionary = {
	State.PLAYING:   [State.GAME_OVER, State.EXPLORING],
	State.GAME_OVER: [State.RESETTING],
	State.RESETTING: [State.PLAYING],
	State.EXPLORING: [State.PLAYING],
}

## Transition to [param new_state]. Invalid or duplicate transitions are silently rejected.
## RESETTING triggers [signal session_reset] and immediately auto-transitions to PLAYING.
func transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	if new_state not in _VALID_TRANSITIONS.get(current_state, []):
		return
	current_state = new_state
	game_state_changed.emit(new_state)
	if new_state == State.RESETTING:
		session_reset.emit()
		transition_to(State.PLAYING)

## Convenience wrapper — called by Castle when hp reaches 0.
func request_game_over() -> void:
	if current_state == State.PLAYING:
		transition_to(State.GAME_OVER)

## Convenience wrapper — called by GameOverOverlay on tap.
func request_restart() -> void:
	if current_state == State.GAME_OVER:
		transition_to(State.RESETTING)

## Convenience wrapper — called by Main when hero enters the exploration portal.
func request_explore() -> void:
	if current_state == State.PLAYING:
		transition_to(State.EXPLORING)

## Convenience wrapper — called by Main when hero taps the return portal.
func request_return_to_td() -> void:
	if current_state == State.EXPLORING:
		transition_to(State.PLAYING)
