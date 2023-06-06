class_name Gameplay extends Node2D

#-- worlds messiest gameplay script --#

# multiplayer handling logic shits
@onready var main_menu:PanelContainer = $MultiplayerGUI/MainMenu
@onready var players:Node2D = $Players
@onready var chat_box:LineEdit = $HUD/ChatBox
@onready var chat_messages := $HUD/ChatMenu/MarginContainer/ScrollContainer/VBoxContainer
@onready var chat_messages_container := $HUD/ChatMenu/MarginContainer/ScrollContainer
@onready var settings_username_entry := $HUD/SettingsMenu/MarginContainer/VBoxContainer/UsernameEntry
@onready var address_entry: LineEdit = $MultiplayerGUI/MainMenu/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/AddressEntry
@onready var port_entry: SpinBox = $MultiplayerGUI/MainMenu/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/PortEntry

const PLAYER := preload("res://characters/player.tscn")

var MULTIPLAYER_ADDRESS:String = "localhost"
var MULTIPLAYER_PORT:int = 9999
var MULTIPLAYER_USERNAME:String

var MULTIPLAYER_PEER := ENetMultiplayerPeer.new()

func _ready():
	MULTIPLAYER_USERNAME = Settings.get_setting("username")
	MULTIPLAYER_ADDRESS = Settings.get_setting("address")
	MULTIPLAYER_PORT = int(Settings.get_setting("port"))
	
	# i'm not tired here, i'm just lazy
	$MultiplayerGUI/MainMenu/MarginContainer/VBoxContainer/UsernameEntry.text = MULTIPLAYER_USERNAME
	$MultiplayerGUI/MainMenu/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/AddressEntry.text = MULTIPLAYER_ADDRESS
	$MultiplayerGUI/MainMenu/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/PortEntry.value = MULTIPLAYER_PORT

func start_checking_invalid_state():
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(check_invalid_state)
	add_child(timer)
	timer.start()

func check_invalid_state():
	if players.get_child_count() < 1:
		Global.last_error = "The server host has disconnected!"
		get_tree().change_scene_to_file("res://scenes/menus/ErrorScreen.tscn")

func _on_host_button_pressed():
	main_menu.hide()
	set_default_info()
	correct_address()
	Global.player_name = MULTIPLAYER_USERNAME
	
	print('Creating Server %s@%s:%s' % [Global.player_name, MULTIPLAYER_ADDRESS, MULTIPLAYER_PORT])
	
	MULTIPLAYER_PEER.create_server(MULTIPLAYER_PORT)
	multiplayer.multiplayer_peer = MULTIPLAYER_PEER
	
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	show_hud()
	add_player(multiplayer.get_unique_id())
	
	start_checking_invalid_state()

func _on_join_button_pressed():
	main_menu.hide()
	set_default_info()
	correct_address()
	Global.player_name = MULTIPLAYER_USERNAME
	
	MULTIPLAYER_PEER.create_client(MULTIPLAYER_ADDRESS, MULTIPLAYER_PORT)
	multiplayer.multiplayer_peer = MULTIPLAYER_PEER
	
	show_hud()
	start_checking_invalid_state()
	
# if you have a port in your address,
# this function will set the port textbox's contents
# to that port
func correct_address():
	if not ":" in MULTIPLAYER_ADDRESS:
		return
		
	var split:PackedStringArray = MULTIPLAYER_ADDRESS.split(":")
	MULTIPLAYER_ADDRESS = split[0]
	MULTIPLAYER_PORT = int(split[1])
	Settings.set_setting("port", str(MULTIPLAYER_PORT))
	
	address_entry.text = MULTIPLAYER_ADDRESS
	port_entry.value = MULTIPLAYER_PORT
	
func show_hud():
	$HUD.visible = true

func add_player(peer_id:int):
	var player = PLAYER.instantiate()
	player.name = str(peer_id)
	players.add_child(player)
	rpc("_assign_player_ids")
	return player
	
func remove_player(peer_id:int):
	var player:PlayerCharacter = players.get_node_or_null(str(peer_id))
	if player != null:
		print("Player #%s left: %s:%s" % [players.get_child_count(), Global.player_name, str(peer_id)])
		rpc("_submit_raw_message", "[color=%s]%s[/color] left the game!" % [player.sprite.self_modulate.to_html(false), player.player_name], "Sent by Player #%s" % players.get_child_count())
		player.queue_free()
		players.remove_child(player)
		rpc("_assign_player_ids")
		
@rpc("any_peer", "call_local", "unreliable")
func _assign_player_ids():
	for i in players.get_child_count():
		var p = players.get_child(i)
		p.player_id = i+1
		p.is_host = p.player_id < 2

func set_default_info():
	if MULTIPLAYER_ADDRESS.is_empty():
		MULTIPLAYER_ADDRESS = "localhost"
	if MULTIPLAYER_USERNAME.is_empty():
		MULTIPLAYER_USERNAME = "player_%s" % str(randi_range(0, 99999))
		
	Settings.set_setting("username", MULTIPLAYER_USERNAME)
	Settings.set_setting("address", MULTIPLAYER_ADDRESS)
	Settings.set_setting("port", str(MULTIPLAYER_PORT))
	Settings.flush()

func _on_address_changed(new_text: String) -> void:
	MULTIPLAYER_ADDRESS = new_text
	correct_address()

func _on_port_changed(value: float) -> void:
	MULTIPLAYER_PORT = int(value)
	Settings.set_setting("port", str(MULTIPLAYER_PORT))

func _on_username_changed(new_text: String) -> void:
	MULTIPLAYER_USERNAME = new_text
	$HUD/SettingsMenu/MarginContainer/VBoxContainer/UsernameEntry.text = new_text

@rpc("any_peer", "call_local", "reliable")
func _submit_message(peer_id:int, text:String):
	var player:PlayerCharacter = players.get_node_or_null(str(peer_id))
	
	if player == null:
		printerr("Got submitted message with invalid player %s." % str(peer_id))
		return
	
	_submit_raw_message("[color=%s]%s[/color] > %s" % [player.sprite.self_modulate.to_html(false), player.player_name, text], "Sent by Player #%s" % player.player_id)
	
@rpc("any_peer", "call_local", "reliable")
func _submit_raw_message(text:String, tooltip:String):
	var message:RichTextLabel = load("res://scenes/multiplayer/chat_message.tscn").instantiate()
	message.text = text
	message.tooltip_text = tooltip
	message.name = "message_%s" % chat_messages.get_child_count()
	chat_messages.add_child(message, true)
	
	await get_tree().create_timer(0.01).timeout
	chat_messages_container.scroll_vertical = chat_messages.size.y

func _on_chat_message_submitted(new_text:String):
	print("Submitted chat message: %s" % new_text)
	if parse_command(new_text, get_tree().get_multiplayer().get_unique_id()):
		rpc("_submit_message", get_tree().get_multiplayer().get_unique_id(), new_text)
	chat_box.text = ""

func _on_settings_button_pressed():
	var menu = $HUD/SettingsMenu
	menu.visible = not menu.visible
	if not menu.visible:
		Settings.flush()
	$HUD/Settings/Button.release_focus()

func _on_setting_username_changed(new_text:String):
	MULTIPLAYER_USERNAME = new_text
	Global.current_player.player_name = new_text
	Settings.set_setting("username", new_text)

func _on_leave_game_button_pressed():
	MULTIPLAYER_PEER.close()
	get_tree().reload_current_scene()

func parse_command(command, peer_id):
	if command.begins_with('/'):
		var inputs = command.lstrip('/').split(' ')
		match inputs[0]:
			'sendraw':
				var strarr = inputs
				strarr.remove_at(0)
				var out = ' '.join(PackedStringArray(strarr))
				rpc('_submit_raw_message', out, '')
			'gay':
				if players.get_node_or_null(str(peer_id)) != null and players.get_node_or_null(str(peer_id)).tags.has('gay'):
					rpc('remove_player_tag', peer_id, 'gay')
				else:
					rpc('add_player_tag', peer_id, 'gay')
			'hat':
				if inputs[1] == 'none':
					rpc('remove_player_tag', peer_id, 'hat')
				else:
					rpc('add_player_tag', peer_id, 'hat', inputs[1])
		return false
	else:
		return true

@rpc("any_peer", "call_local", "reliable")
func add_player_tag(peer_id,tag, value = true):
	var player:PlayerCharacter = players.get_node_or_null(str(peer_id))
	
	if player == null:
		printerr("Got submitted message with invalid player %s." % str(player))
		return
		
	player.tags[tag] = value
	player.tag_changed(tag,value)
	
@rpc("any_peer", "call_local", "reliable")
func remove_player_tag(peer_id,tag):
	var player:PlayerCharacter = players.get_node_or_null(str(peer_id))
	
	if player == null:
		printerr("Got submitted message with invalid player %s." % str(player))
		return
	
	player.tags.erase(tag)
	player.tag_changed(tag,null)
