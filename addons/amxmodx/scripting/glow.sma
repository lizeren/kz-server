/*****************************************************************************************
 *
 *	plugin_glow
 *
 *	Copyright 2005, Bahrmanou <amiga5707@hotmail.com>
 *
 *****************************************************************************************/
#include <amxmodx>
#include <amxmisc>
#include <fun>

#define PLUGNAME		"plugin_glow"
#define VERSION			"1.3"
#define AUTHOR			"Bahrmanou (amiga5707@hotmail.com)"

#define ACCESS_LEVEL		ADMIN_LEVEL_A
#define ACCESS_ADMIN		ADMIN_ADMIN

#define CFG_FILE		"glow.ini"
#define MAX_TEXT_LENGTH		200
#define MAX_COMMENT_LENGTH	60
#define MAX_COLORS		200
#define MAX_NAME_LENGTH		32
#define MAX_PLAYERS		32


new CFG_PATH[MAX_TEXT_LENGTH]

new Players[MAX_PLAYERS]
new strobe[MAX_PLAYERS]
new color_names[MAX_COLORS][MAX_NAME_LENGTH+1]
new color_codes[MAX_COLORS]
new colors[MAX_COLORS][9]
new color_comments[MAX_COLORS][MAX_COMMENT_LENGTH]
new color_own_comments[MAX_COLORS][MAX_COMMENT_LENGTH]

new colors_got

public plugin_init() {
	register_plugin(PLUGNAME, VERSION, AUTHOR)

	register_concmd("amx_glow", "amx_glow", ACCESS_LEVEL, "<user> [flash] <color>: make user glowing.")
	register_concmd("amx_glowcustom", "amx_glowcustom", ACCESS_LEVEL, "<user> <r> <g> <b>: make user glowing custom color.")
	register_concmd("amx_glowfreq", "amx_glowfreq", ACCESS_ADMIN, "- <frequence>: frequence for multi color glowing.")
	register_concmd("amx_glowreload", "amx_glowreload", ACCESS_ADMIN, ": reload the list from file.")

	register_clcmd("say", "SayGlow", 0, "")
	register_cvar("amx_glow_freq", "1.0")

	colors_got = parse_file()
}

public client_disconnect(id) {
	if (task_exists(id)) remove_task(id)
}

public plugin_modules() {
	require_module("fun")
}

/*****************************************************************************************
 *
 *	amx_glow <user> [flash] <color>
 *
 *****************************************************************************************/
public amx_glow(id, level, cid) {
	new user[33], colorname[20], flash = 0
	new plName[MAX_NAME_LENGTH+1]

	if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
	if (!colors_got) {
		console_print(id, "There was a problem in reading the configuration file; cannot proceed.")
		return PLUGIN_HANDLED
	}

	read_argv(1, user, 32)
	read_argv(2, colorname, 20)

	new player = cmd_target(id, user, 6)
	if (!player) {
		console_print(id, "Unknown player: %s", user)
		return PLUGIN_HANDLED
	}
	get_user_name(player, plName, MAX_NAME_LENGTH)
	if (access(player, ADMIN_IMMUNITY)) {
		console_print(id, "You cannot do that to %s, you silly bear!", plName)
		return PLUGIN_HANDLED
	}
	if (!is_user_alive(player)) {
		console_print(id, "Only alive players, please!")
		return PLUGIN_HANDLED
	}
	if (equali(colorname, "off")) {
		new msg[MAX_TEXT_LENGTH]
		if (task_exists(player)) remove_task(player)
		set_user_rendering(player, 0, 0, 0, 0, 0, 0)
		client_print(player, print_chat, "You are no longer glowing.")
		format(msg, MAX_TEXT_LENGTH, "%s is no longer glowing.", plName)
		say_to_all(msg, player)
		return PLUGIN_HANDLED
	}
	if (equali(colorname, "flash")) {
		read_argv(3, colorname, 20)
		flash = 1
	}
	if (!colorname[0]) {
		console_print(id, "You must give a color name!")
		return PLUGIN_HANDLED
	}

	new col[3] = { -1, -1, -1 }
	for (new i=0; i<colors_got; i++) {
		if (equali(color_names[i], colorname)) {
			do_the_code(id, player, col, 1, flash)
			return PLUGIN_HANDLED
		}
	}
	console_print(id, "Unknown color!")

	return PLUGIN_HANDLED
}

/*****************************************************************************************
 *
 *	amx_glowcustom <user> <r> <g> <b>
 *
 *****************************************************************************************/
public amx_glowcustom(id, level, cid) {
	new user[33], r[4], g[4], b[4]

	if (!cmd_access(id, level, cid, 5)) return PLUGIN_HANDLED
	read_argv(1, user, 32)
	read_argv(2, r, 3)
	read_argv(3, g, 3)
	read_argv(4, b, 3)

	new player = cmd_target(id, user, 6)
	if (!player) {
		console_print(id, "Unknown player: %s", user)
		return PLUGIN_HANDLED
	}
	if (access(player, ADMIN_IMMUNITY)) {
		new plName[MAX_NAME_LENGTH+1]
		get_user_name(player, plName, MAX_NAME_LENGTH)
		console_print(id, "You cannot do that to %s, you silly bear!", plName)
		return PLUGIN_HANDLED
	}
	if (!is_user_alive(player)) {
		console_print(id, "Only alive players, please!")
		return PLUGIN_HANDLED
	}
	new red = str_to_num(r)
	new green = str_to_num(g)
	new blue = str_to_num(b)
	do_custom_color(id, player, red, green, blue)

	return PLUGIN_HANDLED
}

/*****************************************************************************************
 *
 *	amx_glowfreq <frequence>
 *
 *****************************************************************************************/
public amx_glowfreq(id, level, cid) {
	new arg1[6], Float:fr
	new playercount

	if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED

	read_argv(1, arg1, 6)
	fr = floatstr(arg1)
	if (fr<0.1 || fr>10.0) {
		console_print(id, "Frequence between 0.1 and 10.0 please.")
		return PLUGIN_HANDLED
	}
	set_cvar_float("amx_glow_freq", fr)

	if (colors_got) {
		get_players(Players, playercount)
		for (new i=0; i<playercount; i++) {
			if (task_exists(Players[i])) {
				change_task(Players[i], fr)
			}
		}
	}

	console_print(id, "Frequence set to %f", get_cvar_float("amx_glow_freq"))
	return PLUGIN_HANDLED
}

/*****************************************************************************************
 *
 *	amx_glowreload
 *
 *****************************************************************************************/
public amx_glowreload(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

	new playercount

	colors_got = 0
	get_players(Players, playercount)
	for (new i=0; i<playercount; i++) {
		if (task_exists(Players[i])) {
			remove_task(Players[i])
		}
	}
	colors_got = parse_file()
	if (colors_got) console_print(id, "Ok, list was succesfully reloaded.")
	return PLUGIN_HANDLED
}

/*****************************************************************************************
 *
 *	sayGlow
 *
 *****************************************************************************************/
public SayGlow(id, level, cid) {
	new args[128]

	if (!colors_got) return PLUGIN_CONTINUE
	read_args(args, 128)
	remove_quotes(args)

	if (equali(args, "glow", 4)) {
		new colname[3][MAX_NAME_LENGTH+1], plName[MAX_NAME_LENGTH+1], flash = 0

		get_user_name(id, plName, MAX_NAME_LENGTH)
		parse(args[5], colname[0], MAX_NAME_LENGTH, colname[1], MAX_NAME_LENGTH, colname[2], MAX_NAME_LENGTH)
		if (equali(colname[0], "off")) {
			new msg[MAX_TEXT_LENGTH]
			if (task_exists(id)) remove_task(id)
			set_user_rendering(id, 0, 0, 0, 0, 0, 0)
			client_print(id, print_chat, "You are no longer glowing.")
			format(msg, MAX_TEXT_LENGTH, "%s is no longer glowing.", plName)
			say_to_all(msg, id)
			return PLUGIN_CONTINUE
		}
		if (equali(colname[0], "help")) {
			if (!colors_got) return PLUGIN_CONTINUE
			do_glow_help(id)
			return PLUGIN_CONTINUE
		}
		if (equali(colname[0], "flash")) {
			if (!colname[1][0]) {
				client_print(id, print_chat, "You must give a color name!")
				return PLUGIN_CONTINUE
			}
			copy(colname[0], MAX_NAME_LENGTH, colname[1])
			if (colname[2][0]) {
				client_print(id, print_chat, "Only one flashing color, please!")
				return PLUGIN_CONTINUE
			}
			flash = 1
		}
		new col[3] = { -1, -1, -1 }
		if (flash || !colname[1][0]) {
			for (new i=0; i<colors_got; i++) {
				if (equali(color_names[i], colname[0])) {
					col[0] = i
					do_the_code(id, id, col, 0, flash)
					return PLUGIN_CONTINUE
				}
			}
			client_print(id, print_chat, "Sorry, %s, but I dont know the color '%s'...", plName, colname[0])
		} else {
			for (new j=0; j<3; j++) {
				if (!colname[j][0]) break
				for (new i=0; i<colors_got; i++) {
					if (equali(color_names[i], colname[j])) {
						col[j] = i
						break
					}
				}
				if (col[j]==-1) {
					client_print(id, print_chat, "Sorry, %s, but I dont know the color '%s'...", plName, colname[j])
					return PLUGIN_CONTINUE
				}
			}
			do_the_code(id, id, col, 0, 0)
		}
	}
	return PLUGIN_CONTINUE
}

public Plain(parms[], id) {
	new color = parms[0]
	set_user_rendering(id, kRenderFxGlowShell, colors[color][0], colors[color][1], colors[color][2], kRenderNormal, 0)
}

public Flash(parms[], id) {
	new color = parms[0]
	new r, g, b

	if (strobe[id]==0) {
		strobe[id] = 1
		r = colors[color][0]
		g = colors[color][1]
		b = colors[color][2]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	} else {
		strobe[id] = 0
		r = 0
		g = 0
		b = 0
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	}
}

public Glow2Named(parms[], id) {
	new color1 = parms[0]
	new color2 = parms[1]
	new r, g, b

	if (strobe[id]==0) {
		strobe[id] = 1
		r = colors[color1][0]
		g = colors[color1][1]
		b = colors[color1][2]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	} else {
		strobe[id] = 0
		r = colors[color2][0]
		g = colors[color2][1]
		b = colors[color2][2]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	}
}

public Glow3Named(parms[], id) {
	new color1 = parms[0]
	new color2 = parms[1]
	new color3 = parms[2]
	new r, g, b

	if (strobe[id]==0) {
		strobe[id] = 1
		r = colors[color1][0]
		g = colors[color1][1]
		b = colors[color1][2]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	} else if (strobe[id]==1) {
		strobe[id] = 2
		r = colors[color2][0]
		g = colors[color2][1]
		b = colors[color2][2]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	} else {
		strobe[id] = 0
		r = colors[color3][0]
		g = colors[color3][1]
		b = colors[color3][2]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	}
}

public Glow2(parms[], id) {
	new color = parms[0]
	new r, g, b

	if (strobe[id]==0) {
		strobe[id] = 1
		r = colors[color][0]
		g = colors[color][1]
		b = colors[color][2]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	} else {
		strobe[id] = 0
		r = colors[color][3]
		g = colors[color][4]
		b = colors[color][5]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	}
}

public Glow3(parms[], id) {
	new color = parms[0]
	new r, g, b

	if (strobe[id]==0) {
		strobe[id] = 1
		r = colors[color][0]
		g = colors[color][1]
		b = colors[color][2]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	} else if (strobe[id]==1) {
		strobe[id] = 2
		r = colors[color][3]
		g = colors[color][4]
		b = colors[color][5]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	} else {
		strobe[id] = 0
		r = colors[color][6]
		g = colors[color][7]
		b = colors[color][8]
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	}
}

public Strobe(id) {
	new r, g, b

	if (strobe[id]==0) {
		strobe[id] = 1
		r = random(256)
		g = random(256)
		b = random(256)
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	} else {
		strobe[id] = 0
		r = 0
		g = 0
		b = 0
		set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
	}
}

public Rotate(id) {
	new r, g, b

	r = random(256)
	g = random(256)
	b = random(256)
	set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, 0)
}

parse_file() {
	new got_line, line_num=0, full_line[MAX_TEXT_LENGTH], len=0
	new rest_line[MAX_TEXT_LENGTH], color_code[2], cc
	new r[3][4], g[3][4], b[3][4]
	new color_num=0
	new cfgdir[MAX_TEXT_LENGTH]
	new parsed

	get_configsdir(cfgdir, MAX_TEXT_LENGTH)
	format(CFG_PATH, MAX_TEXT_LENGTH, "%s/%s", cfgdir, CFG_FILE)
	if (!file_exists(CFG_PATH)) {
		log_amx("ERROR: Cannot find configuration file '%s'!", CFG_FILE)
		return 0
	}
	got_line = read_file(CFG_PATH, line_num, full_line, MAX_TEXT_LENGTH, len)
	if (got_line <=0) {
		log_amx("ERROR: Cannot read configuration file '%s'!", CFG_FILE)
		return 0
	}
	while (got_line>0) {
		if (!equal(full_line, "//", 2) && len) {
			strtok(full_line, color_names[color_num], MAX_NAME_LENGTH, rest_line, MAX_TEXT_LENGTH, ' ', 1)
			copy(full_line, MAX_TEXT_LENGTH, rest_line)
			strtok(full_line, color_code, 1, rest_line, MAX_TEXT_LENGTH, ' ', 1)
			copy(full_line, MAX_TEXT_LENGTH, rest_line)
			cc = str_to_num(color_code)
			color_codes[color_num] = cc
			if (cc<1 || cc>5) {
				log_amx("ERROR: Bad color code (%d), line %d in configuration file '%s'!", cc, 1+line_num, CFG_FILE)
				return 0
			}
			switch (cc) {
				case 1: {
						parsed = parse(full_line,r[0],3,g[0],3,b[0],3)
						if (parsed<3) {
							log_amx("ERROR: Not enough colors, line %d in configuration file '%s'!", 1+line_num, CFG_FILE)
							return 0
						}
						colors[color_num][0] = str_to_num(r[0])
						colors[color_num][1] = str_to_num(g[0])
						colors[color_num][2] = str_to_num(b[0])
					}
				case 2: {
						parsed = parse(full_line,r[0],3,g[0],3,b[0],3,r[1],3,g[1],3,b[1],3,color_comments[color_num],MAX_COMMENT_LENGTH, color_own_comments[color_num],MAX_COMMENT_LENGTH)
						if (parsed<6) {
							log_amx("ERROR: Not enough colors, line %d in configuration file '%s'!", 1+line_num, CFG_FILE)
							return 0
						}
						for (new i=0; i<2; i++) {
							colors[color_num][i*3]   = str_to_num(r[i])
							colors[color_num][i*3+1] = str_to_num(g[i])
							colors[color_num][i*3+2] = str_to_num(b[i])
						}
					}
				case 3: {
						parsed = parse(full_line,r[0],3,g[0],3,b[0],3,r[1],3,g[1],3,b[1],3,r[2],3,g[2],3,b[2],3,color_comments[color_num],MAX_COMMENT_LENGTH, color_own_comments[color_num],MAX_COMMENT_LENGTH)
						if (parsed<9) {
							log_amx("ERROR: Not enough colors, line %d in configuration file '%s'!", 1+line_num, CFG_FILE)
							return 0
						}
						for (new i=0; i<3; i++) {
							colors[color_num][i*3]   = str_to_num(r[i])
							colors[color_num][i*3+1] = str_to_num(g[i])
							colors[color_num][i*3+2] = str_to_num(b[i])
						}
					}
			}
			color_num++
			if (color_num>=MAX_COLORS) {
				log_amx("WARNING: Max colors reached in file '%s'!", CFG_FILE)
				return color_num
			}
		}
		line_num++
		got_line = read_file(CFG_PATH, line_num, full_line, MAX_TEXT_LENGTH, len)
	}
	return color_num
}

say_to_all(msg[], id) {
	new playercount

	get_players(Players, playercount)
	for (new i=0; i<playercount; i++) {
		if (Players[i]!=id) client_print(Players[i], print_chat, msg)
	}
}

say_to_all_nf(msg[], id, plName[]) {
	new playercount, msg2[101], txt[101], m

	m = containi(msg, "%s")
	if (m && m!=-1) {
		copy(msg2, m-1, msg)
		format(txt, 100, "%s%s%s", msg2, plName, msg[m+2])
		get_players(Players, playercount)
		for (new i=0; i<playercount; i++) {
			if (Players[i]!=id) client_print(Players[i], print_chat, txt)
		}
	}
}

do_custom_color(id, player, red, green, blue) {
	new plName[MAX_NAME_LENGTH+1], msg[MAX_TEXT_LENGTH]

	if (task_exists(player)) remove_task(player)
	get_user_name(player, plName, MAX_NAME_LENGTH)
	set_user_rendering(player, kRenderFxGlowShell, red, green, blue, kRenderNormal, 0)
	console_print(id, "Succeeded.")
	client_print(player, print_chat, "You begin to glow a custom color.")
	format(msg, MAX_TEXT_LENGTH, "%s begins glowing a custom color.", plName)
	say_to_all(msg, player)
}

do_glow_help(id) {
	new msg[200], clen=0

	console_print(id, "^nGlow Color List:^n^nPlain colors:")
	for (new i=0; i<colors_got; i++) {
		if (color_codes[i]==1) {
			clen += format(msg[clen], 199-clen, "%s ", color_names[i])
			if (clen > 80) {
				console_print(id, msg)
				copy(msg, 1, "")
				clen = 0
			}
		}
	}
	console_print(id, "^nOthers:")
	clen = 0
	for (new i=0; i<colors_got; i++) {
		if (color_codes[i]!=1) {
			clen += format(msg[clen], 199-clen, "%s ", color_names[i])
		}
		if (clen > 80) {
			console_print(id, msg)
			copy(msg, 1, "")
			clen = 0
		}
	}
	console_print(id, "^nFor all the plain colors, you can also say 'glow flash <color>'.")
	console_print(id, "You can name upto three plain colors, like 'glow red blue white' for instance.")
	client_print(id, print_chat, "The colors list has been displayed in your console.")
}

do_the_code(id, player, col[], console, flash) {
	new plName[MAX_NAME_LENGTH+1], msg[MAX_TEXT_LENGTH]
	new Float:freq = get_cvar_float("amx_glow_freq")

	if (task_exists(player)) {
		remove_task(player)
		set_user_rendering(player, 0, 0, 0, 0, 0, 0)
	}
	if (!is_user_alive(player)) {
		client_print(player, print_chat, "You must be alive and playing!")
		return
	}

	get_user_name(player, plName, MAX_NAME_LENGTH)

	if (flash && (color_codes[col[0]]!=1)) {
		if (console) {
			console_print(id, "flash is only applicable to plain colors!")
		} else {
			client_print(player, print_chat, "flash is only applicable to plain colors!")
		}
		return
	}
	if (col[1]!=-1) {
		if (color_codes[col[0]]!=1 || color_codes[col[1]]!=1) {
			if (console) {
				console_print(id, "Only plain colors, please!")
			} else {
				client_print(player, print_chat, "Only plain colors, please!")
			}
			return
		}
		if (col[2]!=-1) {
			if (color_codes[col[2]]!=1) {
				if (console) {
					console_print(id, "Only plain colors, please!")
				} else {
					client_print(player, print_chat, "Only plain colors, please!")
				}
				return
			}
			set_task(freq, "Glow3Named", player, col, 3, "b")
			client_print(player, print_chat, "You begin to glow %s, %s and %s.", color_names[col[0]], color_names[col[1]], color_names[col[2]])
			format(msg, MAX_TEXT_LENGTH, "%s begins glowing %s, %s and %s.", plName, color_names[col[0]], color_names[col[1]], color_names[col[2]])
			say_to_all(msg, player)
		} else {
			set_task(freq, "Glow2Named", player, col, 2, "b")
			client_print(player, print_chat, "You begin to glow %s and %s.", color_names[col[0]], color_names[col[1]])
			format(msg, MAX_TEXT_LENGTH, "%s begins glowing %s and %s.", plName, color_names[col[0]], color_names[col[1]])
			say_to_all(msg, player)
		}
	} else switch (color_codes[col[0]]) {
		case 1:	{
				if (flash) {
					set_task(freq, "Flash", player, col, 1, "b")
					client_print(player, print_chat, "You begin to glow flash %s.", color_names[col[0]])
					format(msg, MAX_TEXT_LENGTH, "%s begins glowing flash %s.", plName, color_names[col[0]])
					say_to_all(msg, player)
				} else {
					set_task(freq, "Plain", player, col, 1, "b")
					set_user_rendering(player, kRenderFxGlowShell, colors[col[0]][0], colors[col[0]][1], colors[col[0]][2], kRenderNormal, 0)
					client_print(player, print_chat, "You begin to glow %s.", color_names[col[0]])
					format(msg, MAX_TEXT_LENGTH, "%s begins glowing %s.", plName, color_names[col[0]])
					say_to_all(msg, player)
				}
			}
		case 2: {
				set_task(freq, "Glow2", player, col, 1, "b")
				if (color_own_comments[col[0]][0])
					client_print(player, print_chat, color_own_comments[col[0]])
				else
					client_print(player, print_chat, "You begin to glow %s.", color_names[col[0]])
				say_to_all_nf(color_comments[col[0]], player, plName)
			}
		case 3: {
				set_task(freq, "Glow3", player, col, 1, "b")
				if (color_own_comments[col[0]][0])
					client_print(player, print_chat, color_own_comments[col[0]])
				else
					client_print(player, print_chat, "You begin to glow %s.", color_names[col[0]])
				say_to_all_nf(color_comments[col[0]], player, plName)
			}
		case 4: {
				set_task(freq, "Strobe", player, "", 0, "b")
				client_print(player, print_chat, "You begin to strobe.")
				format(msg, MAX_TEXT_LENGTH, "%s begins strobing.", plName)
				say_to_all(msg, player)
			}
		case 5: {
				set_task(freq, "Rotate", player, "", 0, "b")
				client_print(player, print_chat, "You begin to change colors.")
				format(msg, MAX_TEXT_LENGTH, "%s begins changing colors.", plName)
				say_to_all(msg, player)
			}
	}
	if (console) console_print(id, "Succeeded.")
}

