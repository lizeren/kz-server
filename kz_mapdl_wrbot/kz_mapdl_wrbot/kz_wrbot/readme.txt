KZ_WRBOT:
Usage command: 

amx_wrbotmenu - in console
/bot - in chat
 
You need flag u on addons/amxmodx/configs/users.ini for use this command
ADMIN_MENU - flag "u"

autodisable country flags for lan servers

Linux
add in addons/amxmodx/configs/modules.ini

;curl
amxxarch

CVARS:

# It shows the world record the country's flag over the head of bot. 
# 1 - active || 0 - inactive || default 1 & autodisable on localhost (listenserver)
kz_bot_flag 1

# Save or delete local bot files to run next time from folder /data/kz_wrbot
# 1 - save local bots file || 0 - delete local saved bots file || default - 1
kz_bot_local_wr 1

# Kick the bot when server is full, default "1"
kz_bot_kick 1

# hud message autostart bot.
# 1 - active || 0 - inactive || 
kz_bot_hud 1 

# The choice between instant bot start or delayed.
# Number second || 0 - Fast start || default - 5
kz_bot_cooldown 5

//Changelog 1.2 
//Fix Connections to servers - freeze on changelevel if community unreachable
//Added Cvar to kick bot if count of player reach maxplayers - count 
//Fixed Crashes on changelevel 
//Fixed Godmode
//Change cvars
//Changing config file
