///////////////////////////////////////////////////
//
// Attract-Mode Frontend - Fightcade plugin
//
///////////////////////////////////////////////////
//
// Define use configurable settings
//
class UserConfig </ help="History.dat viewer for the Attract-Mode frontend" /> {
	</ label="Control", help="The button to press to display Fightcade view", is_input=true, order=1 />
	button="H";

	</ label="Fightcade username", help="Username of your Fightcade account", order=2 />
	username="johndoe";

	</ label="Fightcade password", help="Password of your Fightcade account", order=3 />
	password="mypassword";

	</ label="File Path", help="The full path to the fightcade.py file", order=4 />
	command="fightcade-headless";

	</ label="Chat input",
		help="The action that allows the user to send chat message",
		options="Custom1,Custom2,Custom3,Custom4,Custom5,Custom6",
		order=5 />
	trigger_input="Custom1";
}

fe.load_module( "submenu" );
fe.do_nut( "json.nut" );

local config=fe.get_config();
local player_list;
local chat;
local fightcade;
local status_bar_height = 50;
local state = {};

function fightcade_tick(ttime)
{
	if (chat) {
		chat.on_ticks(ttime);
	}
	if (player_list) {
		player_list.on_ticks(ttime);
	}
	if (fightcade) {
		fightcade.on_ticks(ttime);
	}
}

fe.add_ticks_callback( "fightcade_tick" );

class PlayerList
{
	player_list_update_time = 5000;
	last = 0;
	selection = -1;
	line_height = 60;
	players = []
	visible = true;

	constructor()
  {
		set_players();
		show();
	}

	function on_signal(sig)
	{
		if (!visible)
			return false;

		switch (sig)
		{
			case "up":
				if (selection > 0) {
					select(selection - 1);
				}
				return true;
			case "down":
				if (selection < players.len() - 1) {
					select(selection + 1);
				}
				return true;
			case "select":
				player_menu(players[selection].msg);
				return true;
		}
		return false;
	}

	function show() {
		fe.add_signal_handler(this, "on_signal");

		for (local i=0; i<players.len(); i++) {
			players[i].visible = true;
		}
	}

	function hide() {
		fe.remove_signal_handler(this, "on_signal");

		for (local i=0; i<players.len(); i++) {
			players[i].visible = false;
		}
	}

	function select(i) {
		if (i >= players.len()) {
			print("Invalid selection: " + i);
			return
		}

		if (selection != -1) {
			players[selection].set_rgb(155, 155, 155);
		}

		players[i].set_rgb(255, 255, 255);
		selection = i;
	}

	function player_menu(username) {
		local items = [ "Challenge", "Direct", "Ignore", "Back" ];
		for (local i = 0; i < state["challenge_sent"].len(); i++) {
			if (state["challenge_sent"][i] == username) {
				items[0] = "Cancel challenge";
				break;
			}
		}
		local res = fe.overlay.list_dialog(items, username, items.len()/2);
		if (res < 0)
			return;
		switch (items[res] ) {
			case "Direct":
				json_output(config["command"], "direct \"" + username + "\"");
				break;
			case "Challenge":
				json_output(config["command"], "challenge \"" + username + "\"");
				break;
			case "Cancel challenge":
				json_output(config["command"], "cancel \"" + username + "\"");
				break;
			case "Ignore":
				json_output(config["command"], "ignore \"" + username + "\"");
				break;
		}
		print("Selected " + items[res]);
	}

	function set_players() {
		local users = state["players"];
		local text;
		local i = 0;
		print(users + "\n");
		foreach (name, user in users) {
			if (name == config["username"])
				continue;

			if (i >= players.len()) {
				text = fe.add_text( name, fe.layout.width / 4 * 3, i * line_height + 10, fe.layout.width / 4, line_height);
				text.set_rgb(155, 155, 155);
				text.first_line_hint = 0;
				text.charsize = line_height - 10;
				text.visible = true;
				players.append(text);
			} else {
				players[i].msg = name;
			}
			i++;
		}

		for (; i<players.len(); i++) {
			players[i].visible = false;
			players.remove(i);
		}

		if (i && selection == -1) {
			select(0);
		}
	}

	function on_ticks(ttime)
	{
		if (ttime - last > player_list_update_time)	{
			last = ttime;
			set_players();
		}
	}
}

class Chat
{
	last_chat_update = 0;
	chat_update_time = 3000;
	text = null;
	line_height = 25;
	line_width = 500;

	constructor(txt)
  {
		text = fe.add_text( "", 0, 0, fe.layout.width / 4 * 3, 0);
		text.set_rgb(255, 255, 255);
		text.first_line_hint = 0;
		text.charsize = line_height;
		text.visible = true;
		text.align = Align.Left
		set_text(txt);
	}

	function set_text(txt)
	{
		text.msg = txt;
		local count = 0;
		for (local i = 0; i < txt.len(); i++) {
			if (txt[i] == '\n') {
				count++;
			}
		}
		local height = count * (line_height + 4);
		if (height > fe.layout.height - status_bar_height) {
			text.first_line_hint += line_height*count;
			height = fe.layout.height - status_bar_height;
		}

		text.height = height;
	}

	function show()
	{
		text.visible = true;
	}

	function hide()
	{
		text.visible = false;
	}

	function update_text()
	{
		local txt = state["chat"];
		set_text(txt);
	}

	function on_ticks(ttime)
	{
		if (ttime - last_chat_update > chat_update_time) {
			update_text();
			last_chat_update = ttime;
		}
	}

	function output(msg)
	{
		text.msg = text.msg + msg;
		if (text.height >= fe.layout.height - status_bar_height) {
			text.first_line_hint += line_height*2;
		}
		else {
			text.height += line_height + 4;
		}
	}

	function input_text()
	{
		local txt = fe.overlay.edit_dialog("Type text", "");
		if (!txt.len()) {
			return
		}
		if (txt[0] == '/') {
			txt = text_output(config["command"], txt.slice(1));
			state["chat"] += txt;
		} else {
			json_output(config["command"], "send " + txt);
			chat.update_text();
		}
	}
}

class Fightcade extends SubMenu
{
	users = [];
	exit = false;
	last_status_update = 0;
	status_update_time = 3000;
	last_input_update = 0;
	input_update_time = 1000;
	input_text = false;
	trigger_input = config["trigger_input"].tolower();
	mask = null;
	status_bar = null;

	constructor()
	{
		fe.plugin_command(config["command"], "stop");
		fe.plugin_command(config["command"], "start --username=" + config["username"] + " --password=" + config["password"]);

		get_state();

		for (local i=0; i<5; i++) {
			if (state["connected"] == true)
				break;
			local splash = fe.overlay.splash_message("Connecting...");
			get_state();
		}

		base.constructor(config["button"]);
		mask = fe.add_text("", 0, 0, fe.layout.width, fe.layout.height);
		mask.set_rgb(0, 0, 0);
		mask.first_line_hint = 0;
		mask.charsize = 10;
		mask.bg_alpha = 150;
		mask.visible = false;
		status_bar = fe.add_text("Welcome to Fightcade. Use <Up> and <Down> keys to select a player, <Select> for actions, <Custom1> to send a message",
		                         0, fe.layout.height - status_bar_height, fe.layout.width, status_bar_height);
		status_bar.charsize = 20;
	}

	function get_state()
	{
		state = json_output(config["command"], "status");
	}

	function output(text)
	{
		chat.msg = chat.msg + text;
	}

	function accept_challenge(player)
	{
		json_output(config["command"], "accept " + player);
	}

	function decline_challenge(player)
	{
		json_output(config["command"], "decline " + player);
	}

	function join(channel)
	{
		json_output(config["command"], "join " + channel);
	}

	function on_ticks(ttime)
	{
		if (ttime - last_input_update > input_update_time)
		{
			last_input_update = ttime;

			if (input_text) {
				chat.input_text();
				input_text = false;
			}
		}

		if (ttime - last_status_update > status_update_time)
		{
			local challenger;
			last_status_update = ttime;
			get_state();

			if (state["challenge_received"].len()) {
				challenger = state["challenge_received"][0];
				local items = ["Accept", "Decline"];

				local res = fe.overlay.list_dialog(items, challenger + " challenged you", items.len() / 2);
				if ( res < 0 )
					return;

				if (items[res] == "Accept") {
					accept_challenge(challenger);
				} else if (items[res] == "Decline") {
					decline_challenge(challenger);
				}
			}
		}
	}

	function on_signal(sig)
	{
		if (sig == trigger_input) {
			input_text = true;
			return true;
		}
		return false;
	}

	function on_show()
	{
		local channels = json_output(config["command"], "list-channels")
		if (fe.game_info(Info.Name) in channels) {
			join(fe.game_info(Info.Name));
		} else {
			join("lobby");
		}

		get_state();
		mask.visible = true;
		chat = Chat(state["chat"]);
		player_list = PlayerList();
		fe.add_signal_handler(this, "on_signal");
	}

	function on_hide()
	{
		mask.visible = false;
		player_list.hide();
		fe.remove_signal_handler(this, "on_signal");
		chat.hide();
	}

	function on_scroll_up()
	{
	}

	function on_scroll_down()
	{
	}
}

fightcade = Fightcade();
fe.plugin[ "Fightcade" ] <- fightcade;
