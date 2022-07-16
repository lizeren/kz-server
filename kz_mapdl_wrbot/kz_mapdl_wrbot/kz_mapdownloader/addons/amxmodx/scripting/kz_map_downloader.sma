#include <amxmodx>
#include <amxmisc>
#include <curl>
#include <amxxarch>

#define PLUGIN 	"[KZ] Map downloader"
#define VERSION "1.2"
#define AUTHOR 	"Destroman"

#define KZMAPDL_LEVEL ADMIN_MAP

//#define DEBUG

#pragma dynamic 131071;
#pragma semicolon 1;

new Array:g_Maps, g_iLoadMaps;
new g_szCurrentMap[32];
new g_szPrefix[32];
new g_szDlMap[32];

new g_szDlFile[128];
new g_hDlFile;
new g_Files;

new bool:g_Filetime = false;

new update_file[] = "addons/amxmodx/data/kz_downloader/maps_filetime.ini";
new archive_dir[] 	= "addons/amxmodx/data/kz_downloader/archives";
new temp_dir[] 		= "addons/amxmodx/data/kz_downloader/mapdl";
new kzdl_dir[] 		= "addons/amxmodx/data/kz_downloader";
new config_dir[] 	= "addons/amxmodx/configs/mapdownloader";

new Array: update_file_data;
new Array: need_update_com;
new DLMap[64];
const COMMUNITIES = 3;

new const g_szDemoFiles[][][] = 
{
	{ "demofilesurl", "demosfilename", "rarfilelink", "community", "link", "file" },
	{ "https://xtreme-jumps.eu/demos.txt", "addons/amxmodx/data/kz_downloader/demos.txt", "http://files.xtreme-jumps.eu/maps/", "Xtreme-Jumps", ".rar", ".rar"  },
	{ "https://cosy-climbing.net/demoz.txt", "addons/amxmodx/data/kz_downloader/demoz.txt", "https://cosy-climbing.net/files/maps/", "Cosy-Climbing", ".rar", ".rar"  },
	{ "http://kz-rush.ru/xr_extended/world_records_update/cache/7e54c98f770108322b53ec33de682402.dat", "addons/amxmodx/data/kz_downloader/demokzr.txt", "https://kz-rush.ru/download/map/cs16/", "KZ-Rush", "", ".zip"}    /*, https://kz-rush.ru/cs16_demos.txt*/
};

enum _:RecordDemo
{
	URLS,
	DEMOS,
	LINK,
	NAME,
	LINKEXT,
	FILEEXT
};

enum _:GetMapState
{
	State_NoTask,
	State_Checking,
	State_Found,
	State_Downloading,
	State_Unpacking,
	State_NotFound,
	State_Finished,
	State_Failed,
	State_Exists
}

new g_State;


	
new g_CurServiceIndex;

enum _:pCvars
{
	CvarCanOverride,
	CvarCanDeleteSource,
	CvarMapsFile,
	CvarPrefix
};

new g_Cvars[pCvars];

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_concmd("kzmapdl", "ClCmd_Download", KZMAPDL_LEVEL, "<mapname>");

	g_Cvars[CvarCanOverride] = register_cvar("kz_mapdl_override", "1");																	 ///// kz_mapdl_override <0/1>  0 - keep files if exists, 1 - override all existing files
	g_Cvars[CvarCanDeleteSource] = register_cvar("kz_mapdl_delete_source", "1");   														 ///// kz_mapdl_delete_source <0/1>  0 - save rar fiel, 1 - delete rar file
	g_Cvars[CvarMapsFile] = register_cvar("kz_mapdl_maps_file", "addons/amxmodx/configs/mapdownloader/maps.ini");        				 ///// file must exist !!! file for mapcycle or mapmanager *.ini, append line with mapname
	g_Cvars[CvarPrefix] = register_cvar("kz_mapdl_chat_prefix", "[KZ_MAPDL]");
}

public plugin_cfg()
{
	static szConfigPath[64];

	if(!dir_exists(config_dir))
	{
		mkdir(config_dir);
	}
	formatex(szConfigPath, charsmax(szConfigPath), "%s/kz_mapdl.cfg", config_dir);
        
	if(file_exists(szConfigPath))
	{
		server_cmd("exec %s",szConfigPath);
		server_exec();
	}

	get_pcvar_string(g_Cvars[CvarPrefix], g_szPrefix, charsmax(g_szPrefix));

	// remove temporary files
	rmdir_recursive(temp_dir);
	if(!dir_exists(kzdl_dir))
	{
		mkdir(kzdl_dir); 
	}
	
	if(!file_exists(update_file))
	{
		new file = fopen(update_file, "w");
		fclose(file);
	}
	if(file_size(update_file, 1) < COMMUNITIES)
	{
		delete_file(update_file);
		new file = fopen(update_file, "w");
		for(new data = 1; data <= COMMUNITIES; data++)
		{
			new line[32];
			format(line, charsmax(line), "%d 1337%d", data, data);
			write_file(update_file, line, -1);
		}
		fclose(file);
	}

	
	if(!dir_exists(archive_dir))
	{
		mkdir(archive_dir); 
	}
	if(!dir_exists(temp_dir))
	{
		mkdir(temp_dir);
	}
	// load map list
	get_mapname(g_szCurrentMap, charsmax(g_szCurrentMap));
	update_file_data = ArrayCreate(32);
	need_update_com = ArrayCreate(COMMUNITIES);
	
	Load_MapList();
	Check_Demos( 1, false);
}

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public ClCmd_Download(id)
{
	DLMap = "";
	new szMsg[64];
	read_args(szMsg, charsmax(szMsg));
	
	remove_quotes(szMsg);
	trim(szMsg);
	
	if(equal(szMsg, "") || szMsg[0] == 0x40) // '@'
	{
		return PLUGIN_HANDLED_MAIN;
	}
	
	if(!(get_user_flags(id) & KZMAPDL_LEVEL) && is_user_connected(id)) 
	{
		client_print( id, print_chat, "%s* You have no access to this command", g_szPrefix );
		return PLUGIN_HANDLED;
	}
	formatex(g_szDlMap, charsmax(g_szDlMap), szMsg);
	
	if(g_szDlMap[0] && is_user_connected(id))
	{
		if(equali(g_szDlMap, g_szCurrentMap) || in_maps_array(g_szDlMap))
		{
			g_State = State_Exists;
			Show_DownloadMenu(id);
		}
		else if(g_State != State_NoTask)
		{
			Show_DownloadMenu(id);
		}
		else if(!is_empty_str(g_szDlMap))
		{
			Show_DownloadMenu(id);
		}
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}


////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////MENU/////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public Show_DownloadMenu(id)
{
	if(g_State == State_NoTask)
	{
		g_State = State_Checking;
		Start_Find(id, true);
	}
	
	new szMsg[256];

	switch(g_State)
	{
		case State_Checking: 	formatex(szMsg, charsmax(szMsg), "\dMapdownloader by \rDestroman^n^n\yTrying to find %s...", g_szDlMap);
		case State_Found:		formatex(szMsg, charsmax(szMsg), "\dMapdownloader by \rDestroman^n^n\y%s was found on %s. Download it?", DLMap, g_szDemoFiles[g_CurServiceIndex][NAME]);
		case State_Downloading: formatex(szMsg, charsmax(szMsg), "\dMapdownloader by \rDestroman^n^n\yDownloading %s...", DLMap);
		case State_Unpacking: 	formatex(szMsg, charsmax(szMsg), "\dMapdownloader by \rDestroman^n^n\yUnpacking %s...", DLMap);
		case State_NotFound: 	formatex(szMsg, charsmax(szMsg), "\dMapdownloader by \rDestroman^n^n\y%s was not found", g_szDlMap);
		case State_Finished: 	formatex(szMsg, charsmax(szMsg), "\dMapdownloader by \rDestroman^n^n\y%s was successfully installed!", DLMap);
		case State_Failed: 		formatex(szMsg, charsmax(szMsg), "\dMapdownloader by \rDestroman^n^n\yFailed to unpack %s. Archive corrupted.", DLMap);
		case State_Exists:		formatex(szMsg, charsmax(szMsg), "\dMapdownloader by \rDestroman^n^n\y%s exists in maps folder", g_szDlMap);
	}
	
	new iMenu = menu_create(szMsg, "DLMenu_Handler");

	switch(g_State)
	{
		case State_Found:
		{
			menu_additem(iMenu, "Yes", "1", 0);
			menu_additem(iMenu, "No", "2", 0);
		}
		case State_Finished, State_Failed, State_NotFound:
		{
			menu_additem(iMenu, "Quit", "3", 0);
		}
		default:
		{
			menu_additem(iMenu, "Cancel", "3", 0);
		}
	}

	menu_setprop(iMenu, MPROP_EXIT, MEXIT_NEVER);

	menu_display(id, iMenu, 0);

	if(g_State == State_NotFound || g_State == State_Finished || g_State == State_Failed || g_State == State_Exists)
	{
		g_State = State_NoTask;
	}
	return PLUGIN_HANDLED;
}


public DLMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		
		return PLUGIN_HANDLED;
	}
	
	static s_Data[6], s_Name[64], i_Access, i_Callback;
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback);
	new iItem = str_to_num(s_Data);

	switch(iItem)
	{
		case 1:
		{
			if(g_State == State_Found)
			{
				g_State = State_Downloading;
				Show_DownloadMenu(id);
				Start_Download(id);
			}
			else
			{
				return PLUGIN_HANDLED;
			}
		}
		case 2:
		{
			if(g_State == State_Found)
				g_State = State_NoTask;
			
			return PLUGIN_HANDLED;
		}
		case 3:
		{
			g_State = State_NoTask;
		}
	}
	
	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////Check Demos/////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public Check_Demos(Community, bool:Download)
{
	#if defined DEBUG
		server_print("PARSING CHECK COMMUNITY-%d, DOWNLOAD-%d", Community, Download );
	#endif
	new CURL:curl = curl_easy_init();	
	new data[2];
	data[1] = Community;
	curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, false);
	curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1);
	curl_easy_setopt(curl, CURLOPT_URL, g_szDemoFiles[Community][URLS]);
	#if defined DEBUG
		curl_easy_setopt(curl, CURLOPT_VERBOSE, 1);	//CURL ANALYZE OPTION
	#endif

	if(Download)
	{
		data[0] = fopen(g_szDemoFiles[Community][DEMOS], "wb");
		
		curl_easy_setopt(curl, CURLOPT_BUFFERSIZE, 512);
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, data[0]);
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, "write");
	}

	if(!Download) 
	{
		curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10);
		curl_easy_setopt(curl, CURLOPT_NOBODY, 1);	
		curl_easy_setopt(curl, CURLOPT_FILETIME, 1);
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, "write_null");
		
	}
	curl_easy_perform(curl, "complete", data, sizeof(data));
}


public write(data[], size, nmemb, file)
{
	new actual_size = size * nmemb;
	fwrite_blocks(file, data, actual_size, BLOCK_CHAR);
	return actual_size;
}

public write_null(data[], size, nmemb, file)
{
	new actual_size = size * nmemb;		
	return actual_size;
}

public complete(CURL:curl, CURLcode:code, data[])
{	
	new comm[64];
	new Community = data[1];
	static filetime, iResponceCode;
	curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, iResponceCode);
	curl_easy_getinfo(curl, CURLINFO_FILETIME, filetime);
	curl_easy_cleanup(curl);

	if(iResponceCode == 0 && filetime == -1)
	{
		#if defined DEBUG
			server_print("Can't Connect to %s", g_szDemoFiles[Community][NAME]);
		#endif
		return;
	}
	#if defined DEBUG
		server_print("Connection to %s successfull", g_szDemoFiles[Community][NAME]);
	#endif
	if(data[0])
	{
		fclose(data[0]);
	}
	else	
	{
		if(iResponceCode == 0 && filetime == -1)
		{
			return;
		}
		new com, dat;
		new Line[32], ExplodedString[3][33], needupdLine[2], newLine[32];
				
		new recordsfile  = fopen( update_file, "rb" );
		while (!feof(recordsfile))
		{
			fgets (recordsfile, Line, charsmax(Line));
			ExplodeString(ExplodedString, 2, 32, Line, ' ');
			
			if(strlen(Line) > 0) {

			
				com = str_to_num(ExplodedString[0]);
				dat = str_to_num(ExplodedString[1]);

				
				if(com == Community && dat)
				{
					if((filetime != dat && filetime > 0) || file_exists( g_szDemoFiles[Community][DEMOS]) == 0)
					{
						dat = filetime;

						format(needupdLine, charsmax(needupdLine), "%d", Community);
						ArrayPushString(need_update_com, needupdLine);
					}
					format(newLine, charsmax(newLine), "%d %d", Community, dat);
					ArrayPushString(update_file_data, newLine);				
				}
			}
		}
		fclose(recordsfile);
		if(Community == COMMUNITIES)
		{
			g_Filetime = true;
			new i_size = ArraySize(need_update_com);
			if(i_size)
			{
				g_Files = i_size;
				delete_file(update_file);
				new file = fopen(update_file, "w");
				for(new i = 0; i  < COMMUNITIES; i++)
				{
					ArrayGetString(update_file_data, i, comm, charsmax(comm));
					write_file(update_file, comm, i);
				}
				fclose(file);
			}
		}
		else
		{
			Check_Demos(Community + 1, false);
			return;
		}
	}
	if(g_Filetime)
	{
		if(g_Files > 0)
		{
			#if defined DEBUG
				server_print("UpdateNeeded() - %d", g_Files);
			#endif
			
			ArrayGetString(need_update_com, g_Files - 1, comm, charsmax(comm));
			g_Files--;
			new sz_num = str_to_num(comm);
			Check_Demos(sz_num, true);
			return;
		}
		else
		{
			g_Filetime = false;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////FIND-FUNC//////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

stock Start_Find(id, isFirst = false)
{
	if(isFirst)
	{
		g_CurServiceIndex = 1;
	}
	else
	{
		g_CurServiceIndex++;
	}
	
	if(g_CurServiceIndex > COMMUNITIES)
	{
		g_State = State_NotFound;
		if(is_user_connected(id))
		{
			Show_DownloadMenu(id);
		}		
		return;
	}

	#if defined DEBUG
		server_print( "Parsing %s Demo List", g_szDemoFiles[g_CurServiceIndex][NAME]);
	#endif

	new iDemosList  = fopen( g_szDemoFiles[g_CurServiceIndex][DEMOS], "rb" );


	new ExplodedString[7][128], Line[128], Extens[32], Mapa[32];
	while ( !feof( iDemosList ) )
	{
		fgets(iDemosList, Line, charsmax(Line));
		ExplodeString(ExplodedString, 6, 127, Line, ' ');
		new parsedmap[128];
		parsedmap = ExplodedString[0];
		trim(parsedmap);
		if (containi(parsedmap, g_szDlMap ) == 0 )
		{	
			split(parsedmap, Mapa, 31, Extens, 31, "[");
			trim(Mapa);
			if(equali(Mapa, g_szDlMap))
			{
				if(containi(parsedmap, "[" ) > -1)
				{
					format( DLMap, charsmax( Mapa ), "%s", Mapa );
				}
				else {
					format( DLMap, charsmax( DLMap ), "%s", Mapa );

				}
				break;				
			}
		}
	}
	fclose(iDemosList);

	new szPath[256];

	formatex(szPath, charsmax(szPath), "%s%s%s", g_szDemoFiles[g_CurServiceIndex][LINK], DLMap, g_szDemoFiles[g_CurServiceIndex][LINKEXT]);
	

	new CURL:hCurl;

	if((hCurl = curl_easy_init()))
	{
		curl_easy_setopt(hCurl, CURLOPT_URL, szPath);
		curl_easy_setopt(hCurl, CURLOPT_NOBODY, 1);
		curl_easy_setopt(hCurl, CURLOPT_SSL_VERIFYPEER, false);
		curl_easy_setopt(hCurl, CURLOPT_NOSIGNAL, 1);
		curl_easy_setopt(hCurl, CURLOPT_CONNECTTIMEOUT, 10);
		
		new szData[1];
		szData[0] = id;

		#if defined DEBUG
		server_print("Finding in %s", szPath);
		#endif

		curl_easy_setopt(hCurl, CURLOPT_WRITEFUNCTION, "@Find_Write_Callback");
		curl_easy_perform(hCurl, "@Find_Callback", szData, sizeof(szData));
	}
}

@Find_Callback(const CURL:hCurl, const CURLcode:iCode, const data[])
{
	new iResponceCode;
	curl_easy_getinfo(hCurl, CURLINFO_RESPONSE_CODE, iResponceCode);

	new id = data[0];

	#if defined DEBUG
	server_print("Handle: %d, Code: %d, id: %d, iCode = %d, is OK: %s", hCurl, iResponceCode, id, iCode, (iCode == CURLE_OK) ? "true" : "false");
	#endif

	curl_easy_cleanup(hCurl);

	if(g_State == State_NoTask)
	{
		return;
	}
	
	if(iCode != CURLE_OK || iResponceCode >= 400)
	{
		Start_Find(id);
	}
	else
	{
		g_State = State_Found;
		if(is_user_connected(id))
		{
			Show_DownloadMenu(id);
		}	
	}
}

@Find_Write_Callback(const data[], const size, const nmemb)
{
	return size * nmemb;
}

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////Downloading////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public Start_Download(id)
{

	new szPath[256];

	formatex(szPath, charsmax(szPath), "%s%s%s", g_szDemoFiles[g_CurServiceIndex][LINK], DLMap, g_szDemoFiles[g_CurServiceIndex][LINKEXT]);

	new CURL:hCurl;

	if((hCurl = curl_easy_init()))
	{
		// setup file		
		formatex(g_szDlFile, charsmax(g_szDlFile), "%s/%s%s", archive_dir, DLMap, g_szDemoFiles[g_CurServiceIndex][FILEEXT]);

		delete_file(g_szDlFile);
		g_hDlFile = fopen(g_szDlFile, "wb");

		// setup curl

		curl_easy_setopt(hCurl, CURLOPT_BUFFERSIZE, 512);
		curl_easy_setopt(hCurl, CURLOPT_URL, szPath);
		curl_easy_setopt(hCurl, CURLOPT_FAILONERROR, 1);
		curl_easy_setopt(hCurl, CURLOPT_SSL_VERIFYPEER, false);
		curl_easy_setopt(hCurl, CURLOPT_NOSIGNAL, 1);
		curl_easy_setopt(hCurl, CURLOPT_CONNECTTIMEOUT, 10);


		new szData[1];
		szData[0] = id;

		curl_easy_setopt(hCurl, CURLOPT_WRITEFUNCTION, "@Download_Write_Callback");
		curl_easy_perform(hCurl, "@Download_Complete_Callback", szData, sizeof(szData));
	}
}

@Download_Write_Callback(const data[], const size, const nmemb)
{
	new real_size = size * nmemb;
	fwrite_blocks(g_hDlFile, data, real_size, BLOCK_CHAR);
	
	return real_size;
}

@Download_Complete_Callback(const CURL:hCurl, const CURLcode:iCode, const szData[])
{
	new id = szData[0];

	// redirect check
	new iResponceCode;
	curl_easy_getinfo(hCurl, CURLINFO_RESPONSE_CODE, iResponceCode);

	if(iResponceCode >= 300 && iResponceCode <= 302)
	{
		new szRedirect[256];
		curl_easy_getinfo(hCurl, CURLINFO_REDIRECT_URL, szRedirect, charsmax(szRedirect));

		#if defined DEBUG
		server_print("redirect: %s", szRedirect);
		#endif

		curl_easy_setopt(hCurl, CURLOPT_URL, szRedirect);
		curl_easy_perform(hCurl, "@Download_Complete_Callback", szData, 1);

		return;
	}

	curl_easy_cleanup(hCurl);
	fclose(g_hDlFile);

	if(g_State == State_NoTask)
	{
		return;
	}
	if(iCode != CURLE_OK)
	{
		#if defined DEBUG
		server_print("[Error] http code: %d", iResponceCode);
		#endif
	}
	else
	{
		OnArchiveComplete(id);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////UNARCHIVE////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

public OnArchiveComplete(id)
{
	g_State = State_Unpacking;
	if(is_user_connected(id))
	{
		Show_DownloadMenu(id);
	}
	new szArchivePath[256];
	formatex(szArchivePath, charsmax(szArchivePath), "%s/%s%s", archive_dir, DLMap, g_szDemoFiles[g_CurServiceIndex][FILEEXT]);

	#if defined DEBUG
	server_print("Trying to unarchive %s ...", szArchivePath);
	#endif

	if(g_State == State_NoTask)
	{
		return;
	}
	AA_Unarchive(szArchivePath, temp_dir, "@OnComplete", id);
}	

@OnComplete(id, iError)
{
	if(iError != AA_NO_ERROR)
	{
		#if defined DEBUG
		server_print("Failed to unpack. Error code: %d", iError);
		#endif

		g_State = State_Failed;
		if(is_user_connected(id))
		{
			Show_DownloadMenu(id);
		}
	}
	else
	{
		#if defined DEBUG
		server_print("Done. Moving files to the directory.");
		#endif

		if(g_State == State_NoTask)
		{
			return;
		}

		if(get_pcvar_num(g_Cvars[CvarCanDeleteSource]))
		{
			delete_file(g_szDlFile);
		}

		new strmapsfile[64];

		get_pcvar_string(g_Cvars[CvarMapsFile], strmapsfile, 63);

		if(file_exists(strmapsfile))
		{
			write_file(strmapsfile, DLMap, -1);
		}
		MoveFiles_Recursive(temp_dir);
		set_task(1.0, "tsk_finish", id);
	}
}

public tsk_finish(id)
{
	rmdir_recursive(temp_dir);

	ArrayPushString(g_Maps, DLMap);

	g_State = State_Finished;
	if(is_user_connected(id))
	{
		Show_DownloadMenu(id);
		client_print(id, print_console, "%s %s was successfully installed!", g_szPrefix, DLMap);
	}

	#if defined DEBUG
	server_print("Finished.");
	#endif
}

///////////////////////////////////////

public MoveFiles_Recursive( work_dir[] )
{
	new szFileName[64];
	new hDir = open_dir(work_dir, szFileName, charsmax(szFileName));

	if(!hDir)
	{
		new file = fopen(work_dir, "rb");
		if(file)
		{
			fclose(file);
		}
		return;
	}

	do
	{
		if(szFileName[0] != '.' && szFileName[1] != '.')
		{
			new sz_dest[512], sz_dest1[512], copyfile[512], copydir[512]; 
			format(sz_dest, 511, "%s/%s", work_dir, szFileName);
			
			///wad files
			if(containi(sz_dest, ".wad") != -1 )
			{
				//filename
				format(copyfile, 511, "%s", szFileName );
				if(get_pcvar_num(g_Cvars[CvarCanOverride])) 
				{
					fmove(sz_dest, copyfile);
				}
				else 
				{
					if(!file_exists(copyfile))
					{
						fmove(sz_dest, copyfile);
					}
				}
				//server_print("szdest - %s and copyfile - %s", sz_dest, copyfile);
			}
			
			///maps
			
			if((containi(sz_dest, ".bsp") != -1 || containi(sz_dest, ".res") != -1 || containi(sz_dest, ".txt") != -1 || containi(sz_dest, ".nav") != -1 ||  containi(sz_dest, "maps/") != -1) && (containi(sz_dest, "taskfiledownload") == -1 ))
			{
				new iPos = strfind(sz_dest, "/");
				new LastPos = iPos;
				// addons/amxmodx/data/kz_downloader/temp/hb_Zzz/hb_Zzz.bsp
				// Find base filename from path ex: hb_Zzz.bsp ^
				while(iPos != -1)
				{
					LastPos = iPos;
					iPos = strfind(sz_dest, "/", .pos = iPos+1);					
				}
				
				substr(sz_dest1,511, sz_dest, LastPos, 0);			
				format(copyfile, 511, "maps%s", sz_dest1 );
				fmove(sz_dest, copyfile);
				//server_print("szdest1 - %s and copyfile - %s", sz_dest1, copyfile); 
			}
			
			
			///gfx
			
			if(((containi(sz_dest, ".tga") != -1 || containi(sz_dest, ".bmp") != -1 || containi(sz_dest, ".lst") != -1) || containi(sz_dest, "gfx/") != -1))
			{
				//foldername
				if(containi(szFileName, ".") == -1) 
				{
					new iPos = strfind(sz_dest, "gfx/");
					substr(sz_dest1,511, sz_dest, iPos, 0);
					format(copydir, 511, "%s", sz_dest1 );
					
					if(!dir_exists(copydir))
					{
						mkdir(copydir);
						
					}
					//server_print("szdest1 - %s and copydir - %s", sz_dest1, copydir);
				}
				//filename
				if(containi(szFileName, ".") != -1) 
				{
					new iPos = strfind(sz_dest, "gfx/");
					substr(sz_dest1,511, sz_dest, iPos, 0);
					format(copyfile, 511, "%s", sz_dest1 );
					
					if(get_pcvar_num(g_Cvars[CvarCanOverride]))
					{
						fmove(sz_dest, copyfile);
					}
					else 
					{
						if(!file_exists(copyfile))
						{
							fmove(sz_dest, copyfile);
						}
					}
					//server_print("szdest - %s and copyfile - %s", sz_dest, copyfile);
				}
			}
			
			///sound
			
			if((containi(sz_dest, ".wav") != -1 || containi(sz_dest, "sound/") != -1 )) 
			{
					//foldername
					if(containi(szFileName, ".") == -1) 
					{
						new iPos = strfind(sz_dest, "sound/");
						substr(sz_dest1,511, sz_dest, iPos, 0);
						format(copydir, 511, "%s", sz_dest1 );
						
						if(!dir_exists(copydir))
						{
							mkdir(copydir);
						}
						//server_print("szdest - %s and copydir - %s", sz_dest, copydir);
					}
					//filename
					if(containi(szFileName, ".wav") != -1) 
					{
						new iPos = strfind(sz_dest, "sound/");
						substr(sz_dest1,511, sz_dest, iPos, 0);
						format(copyfile, 511, "%s", sz_dest1 );
						fmove(sz_dest, copyfile);
						//server_print("szdest - %s and copyfile - %s", sz_dest, copyfile);
					}
			}
			
			///models
			if((containi(sz_dest, ".mdl") != -1 || containi(sz_dest, "models/") != -1))
			{
				//foldername
				if(containi(szFileName, ".") == -1) 
				{
					new iPos = strfind(sz_dest, "models/");
					substr(sz_dest1,511, sz_dest, iPos, 0);
					format(copydir, 511, "%s", sz_dest1 );
					if(!dir_exists(copydir))
					{
						mkdir(copydir);
					}
					//server_print("szdest - %s and copydir - %s", sz_dest, copydir);
				}
				//filename
				if(containi(szFileName, ".mdl") != -1) 
				{
					new iPos = strfind(sz_dest, "models/");
					substr(sz_dest1,511, sz_dest, iPos, 0);
					format(copyfile, 511, "%s", sz_dest1 );
					
					if(get_pcvar_num(g_Cvars[CvarCanOverride])) 
					{
						fmove(sz_dest, copyfile);
					}
					else 
					{
						if(!file_exists(copyfile))
						{
							fmove(sz_dest, copyfile);
						}
					}
					//server_print("szdest - %s and copyfile - %s", sz_dest, copyfile);
				}
			}

			///sprites
			if((containi(sz_dest, ".spr") != -1 || containi(sz_dest, "sprites/") != -1))
			{
				//foldername
				if(containi(szFileName, ".") == -1) 
				{
					new iPos = strfind(sz_dest, "sprites/");
					substr(sz_dest1,511, sz_dest, iPos, 0);
					format(copydir, 511, "%s", sz_dest1 );
					
					if(!dir_exists(copydir))
					{
						mkdir(copydir);
					}
					//server_print("szdest - %s and copydir - %s", sz_dest, copydir);
				}
				//filename
				if(containi(szFileName, ".spr") != -1) 
				{
					new iPos = strfind(sz_dest, "sprites/");
					substr(sz_dest1,511, sz_dest, iPos, 0);
					format(copyfile, 511, "%s", sz_dest1 );
					
					if(get_pcvar_num(g_Cvars[CvarCanOverride])) 
					{
						fmove(sz_dest, copyfile);
					}
					else 
					{
						if(!file_exists(copyfile))
						{
							fmove(sz_dest, copyfile);
						}
					}
					//server_print("szdest - %s and copyfile - %s", sz_dest, copyfile);
				}
			}
			
			MoveFiles_Recursive(sz_dest);
		}
	}
	while(next_file(hDir, szFileName, charsmax(szFileName)));
  	close_dir(hDir);
}

stock fmove(const read_path[], const dest_path[]) 
{ 
	static buffer[256];
	static readsize;
	new fp_read = fopen(read_path, "rb");
	if(file_exists(dest_path))
	{
		delete_file(dest_path);
	}
	new fp_write = fopen(dest_path, "wb");
     
	if (!fp_read)
	{
		fclose(fp_read);
		return 0;
    }
	fseek(fp_read, 0, SEEK_END); 
	new fsize = ftell(fp_read); 
	fseek(fp_read, 0, SEEK_SET); 
	for (new j = 0; j < fsize; j += 256) 
    { 
		readsize = fread_blocks(fp_read, buffer, 256, BLOCK_CHAR); 
		fwrite_blocks(fp_write, buffer, readsize, BLOCK_CHAR); 
    } 
	fclose(fp_read); 
	fclose(fp_write); 
	delete_file(read_path);
	return 1; 
}



bool:substr(dst[], const size, const src[], start, len = 0) 
{
	new srclen = strlen(src);
	start = (start < 0) ? srclen + start : start;

	if (start < 0 || start > srclen)
	{
		return false;
	}

	if (len == 0)
	{
		len = srclen;
	}
	else if (len < 0) 
	{
		if ((len = srclen - start + len) < 0)
		{
			return false;
		}
	}

	len = min(len, size);

	copy(dst, len, src[start]);
	return true;
}


stock is_empty_str(const str[], fl_spacecheck = false)
{
	new i = 0;
	if(fl_spacecheck)
	{
		while(str[i] == 32)
		{
			i++;
		}
	}
	return !str[i];
}

// For load maplist

Load_MapList()
{
	g_iLoadMaps = 0;
	g_Maps = ArrayCreate(33);

	new iDir, iLen, szFileName[64];
	iDir = open_dir("maps", szFileName, charsmax(szFileName));
	
	if(iDir)
	{
		while(next_file(iDir, szFileName, charsmax(szFileName)))
		{
			iLen = strlen(szFileName) - 4;
			
			if(iLen < 0) 
			{
				continue;
			}
			
			if(equali(szFileName[iLen], ".bsp") && !equali(szFileName, g_szCurrentMap))
			{
				szFileName[iLen] = '^0';
				g_iLoadMaps++;
				ArrayPushString(g_Maps, szFileName);
			}
		}
		close_dir(iDir);
	}

	if(!g_iLoadMaps)
	{
		set_fail_state("LOAD_MAPS: Nothing loaded");
		return;
	}
}


bool:in_maps_array(map[])
{
	new szMap[33], iMax = ArraySize(g_Maps);
	for(new i = 0; i < iMax; i++)
	{
		ArrayGetString(g_Maps, i, szMap, charsmax(szMap));
		if(equali(szMap, map))
		{
			return true;
		}
	}
	return false;
}

public rmdir_recursive(temp_dir[])
{
	new szFileName[64], sz_dest[512];
	new hDir = open_dir(temp_dir, szFileName, charsmax(szFileName));

	if(!hDir)
	{
		new file = fopen(temp_dir, "rb");
		if(file)
		{
			fclose(file);
		}
		return;
	}
	do
	{
		if(szFileName[0] != '.' && szFileName[1] != '.')
		{
			format(sz_dest, 511, "%s/%s", temp_dir, szFileName);
			
			if(!dir_exists(sz_dest)) 
			{
				delete_file(sz_dest);	
			}
			else {
				rmdir(sz_dest);	
				rmdir_recursive(sz_dest);
			}
		}
	}
	
	while (next_file(hDir, szFileName, charsmax(szFileName )));
  	close_dir(hDir);
}

stock ExplodeString( p_szOutput[][], p_nMax, p_nSize, p_szInput[], p_szDelimiter )
{
	new nIdx = 0, l = strlen( p_szInput );
	new nLen = (1 + copyc( p_szOutput[nIdx], p_nSize, p_szInput, p_szDelimiter ) );
	while ((nLen < l) && (++nIdx < p_nMax))
	{
		nLen += (1 + copyc( p_szOutput[nIdx], p_nSize, p_szInput[nLen], p_szDelimiter ) );
	}
	return(nIdx);
}