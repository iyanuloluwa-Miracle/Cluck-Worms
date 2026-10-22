extends Node
## Lagos Life / Vatar Games SDK bridge (web only).
## Outside the Vatar game player this stays idle so editor / itch builds still work.

const PRODUCT_EXTRA_LIFE := "extra_life"

var is_available: bool = false
var player_name: String = ""
var player_id: String = ""
var mode: String = ""
var _host_paused: bool = false
var _js_browser_pause_cb: JavaScriptObject
var _js_pause_cb: JavaScriptObject
var _js_resume_cb: JavaScriptObject
var _js_purchase_cb: JavaScriptObject
## Keep JS callbacks alive until their Promise settles (avoid GC).
var _pending_cbs: Array = []


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.game_state_changed.connect(_on_web_state)
	EventBus.game_over.connect(_on_game_over)
	EventBus.level_completed.connect(_on_level_completed)
	call_deferred("_boot")


func _boot() -> void:
	if not OS.has_feature("web"):
		return
	var has_bridge: bool = bool(JavaScriptBridge.eval("typeof window.CluckVatar !== 'undefined'"))
	if not has_bridge:
		push_warning("VatarBridge: CluckVatar missing — export with html/vatar_shell.html")
		return

	var win: Variant = JavaScriptBridge.get_interface("window")
	if win == null:
		return
	var bridge: Variant = win.CluckVatar

	_js_browser_pause_cb = JavaScriptBridge.create_callback(_on_browser_pause)
	bridge.onBrowserPause(_js_browser_pause_cb)
	_js_pause_cb = JavaScriptBridge.create_callback(_on_host_pause)
	_js_resume_cb = JavaScriptBridge.create_callback(_on_host_resume)
	_js_purchase_cb = JavaScriptBridge.create_callback(_on_host_purchase)
	bridge.onPause(_js_pause_cb)
	bridge.onResume(_js_resume_cb)
	bridge.onPurchase(_js_purchase_cb)

	var result: Variant = await _await_js_promise(bridge.init())
	if result == null:
		return
	var ok: bool = _js_prop_bool(result, "ok", false)
	if not ok:
		var reason: String = _js_prop_str(result, "reason", "init_failed")
		if reason != "not_framed":
			push_warning("VatarBridge: init failed (%s)" % reason)
		return

	is_available = true
	var player: Variant = _js_prop(result, "player")
	if player != null:
		player_name = _js_prop_str(player, "name", "")
		player_id = _js_prop_str(player, "id", "")
	mode = _js_prop_str(result, "mode", "")
	print("VatarBridge: ready as %s (%s)" % [player_name, mode])


func submit_score(score: int) -> void:
	if not is_available or not OS.has_feature("web"):
		return
	var bridge: Variant = _bridge()
	if bridge == null:
		return
	_await_js_promise(bridge.submitScore(score))


func buy_extra_life() -> bool:
	if not is_available or not OS.has_feature("web"):
		return false
	var bridge: Variant = _bridge()
	if bridge == null:
		return false
	var purchase: Variant = await _await_js_promise(bridge.purchase(PRODUCT_EXTRA_LIFE))
	if purchase == null:
		return false
	var purchase_id: String = _js_prop_str(purchase, "purchaseId", "")
	if purchase_id.is_empty():
		return false
	return await _claim_and_grant(purchase_id)


func _claim_and_grant(purchase_id: String) -> bool:
	var bridge: Variant = _bridge()
	if bridge == null:
		return false
	var claimed: Variant = await _await_js_promise(bridge.claim(purchase_id))
	if claimed == null:
		return false
	var product_id: String = _js_prop_str(claimed, "productId", PRODUCT_EXTRA_LIFE)
	_grant_product(product_id)
	return true


func _grant_product(product_id: String) -> void:
	match product_id:
		PRODUCT_EXTRA_LIFE:
			GameManager.grant_extra_life(1)
		_:
			push_warning("VatarBridge: unknown product %s" % product_id)


func _on_browser_pause(_args: Array = []) -> void:
	# Visibility/orientation pauses require the player's explicit Resume.
	if GameManager.state == GameManager.State.PLAYING:
		GameManager.pause_game()


func _on_host_pause(_args: Array = []) -> void:
	if _host_paused:
		return
	_host_paused = true
	AudioServer.set_bus_mute(0, true)
	if GameManager.state == GameManager.State.PLAYING:
		GameManager.pause_game()


func _on_host_resume(_args: Array = []) -> void:
	if not _host_paused:
		return
	_host_paused = false
	AudioManager.apply_mix(SaveService.master_volume, SaveService.sfx_volume, SaveService.music_volume, SaveService.mute_all)
	if GameManager.state == GameManager.State.PAUSED:
		GameManager.resume_game()


func _on_host_purchase(args: Array = []) -> void:
	if args.is_empty():
		return
	var purchase_id: String = _js_prop_str(args[0], "purchaseId", "")
	if purchase_id.is_empty():
		return
	_claim_and_grant(purchase_id)


func _on_game_over(final_score: int, _high: int, _is_new: bool) -> void:
	submit_score(final_score)


func _on_level_completed(_id: StringName, score: int, _lives: int) -> void:
	submit_score(maxi(score, GameManager.score))


func _bridge() -> Variant:
	var win: Variant = JavaScriptBridge.get_interface("window")
	if win == null:
		return null
	return win.CluckVatar


func _js_prop(obj: Variant, key: String) -> Variant:
	if obj == null:
		return null
	if typeof(obj) == TYPE_DICTIONARY:
		return (obj as Dictionary).get(key, null)
	if key in obj:
		return obj[key]
	return null


func _js_prop_str(obj: Variant, key: String, fallback: String) -> String:
	var v: Variant = _js_prop(obj, key)
	return fallback if v == null else str(v)


func _js_prop_bool(obj: Variant, key: String, fallback: bool) -> bool:
	var v: Variant = _js_prop(obj, key)
	return fallback if v == null else bool(v)


func _await_js_promise(promise: Variant) -> Variant:
	if promise == null:
		return null
	var done: Array = [false, null]
	var on_ok := JavaScriptBridge.create_callback(func(args: Array) -> void:
		done[0] = true
		done[1] = args[0] if not args.is_empty() else null
	)
	var on_err := JavaScriptBridge.create_callback(func(_args: Array) -> void:
		done[0] = true
		done[1] = null
	)
	_pending_cbs.append(on_ok)
	_pending_cbs.append(on_err)
	promise.then(on_ok).catch(on_err)
	while not done[0]:
		await get_tree().process_frame
	_pending_cbs.erase(on_ok)
	_pending_cbs.erase(on_err)
	return done[1]


func _on_web_state(_previous: int, next: int) -> void:
	var hide: String = "false" if next == GameManager.State.MAIN_MENU else "true"
	JavaScriptBridge.eval("var b = document.getElementById('fullscreen'); if (b) b.hidden = " + hide + " || !document.fullscreenEnabled;")
