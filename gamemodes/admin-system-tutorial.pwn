#include <a_samp>
#include <samp_bcrypt>
#include <zcmd>
#include <sscanf2>

#define SERVER_DATABASE "server.db"

#define REGISTER_DIALOG 0
#define LOGIN_DIALOG 1

#define PLAYER 0
#define HELPER 1
#define ADMIN 2
#define OWNER 3

new DB:server_database;
new DBResult:database_result;

enum player_data
{
	player_admin,
	player_kills,
	player_deaths,
	bool:player_logged
};
new PlayerData[MAX_PLAYERS][player_data];

stock GetName(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	return name;
}

stock DB_Escape(text[])//Credits: Y_Less
{
    new ret[80 * 2], ch, i, j;
    while ((ch = text[i++]) && j < sizeof (ret))
    {
        if (ch == '\'')
        {
            if (j < sizeof (ret) - 2)
            {
                ret[j++] = '\'';
                ret[j++] = '\'';
            }
        }
        else if (j < sizeof (ret))
        {
            ret[j++] = ch;
        }
        else
        {
            j++;
        }
    }
    ret[sizeof (ret) - 1] = '\0';
    return ret;
}

stock SaveAccount(playerid)
{
    new query[256];
	if(PlayerData[playerid][player_logged] == true)
	{
	    format(query, sizeof(query),
		"UPDATE `USERS` SET ADMIN = '%d', SCORE = '%d', KILLS = '%d', DEATHS = '%d' WHERE `NAME` = '%s' COLLATE NOCASE", PlayerData[playerid][player_admin], GetPlayerScore(playerid), PlayerData[playerid][player_kills], PlayerData[playerid][player_deaths], DB_Escape(GetName(playerid)));
		database_result = db_query(server_database, query);
		db_free_result(database_result);
	}
	return 1;
}

main() { }

public OnGameModeInit()
{
	SetGameModeText("Blank Script");
	
	AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);
	
	server_database = db_open(SERVER_DATABASE);
	
	db_query(server_database, "CREATE TABLE IF NOT EXISTS `USERS` (`NAME`, `PASS`, `ADMIN`, `SCORE`, `KILLS`, `DEATHS`)");
	return 1;
}

public OnGameModeExit()
{
    db_close(server_database);
	return 1;
}

public OnPlayerConnect(playerid)
{
	SetPlayerScore(playerid, 0);
	
	PlayerData[playerid][player_kills] = 0;
	PlayerData[playerid][player_deaths] = 0;
	
	PlayerData[playerid][player_logged] = false;
	
    new query[128];
	format(query, sizeof(query), "SELECT `NAME` FROM `USERS` WHERE `NAME` = '%s' COLLATE NOCASE", DB_Escape(GetName(playerid)));
  	database_result = db_query(server_database, query);
  	if(db_num_rows(database_result))
	{
		ShowPlayerDialog(playerid, LOGIN_DIALOG, DIALOG_STYLE_PASSWORD, "{FFFFFF}Account Login", "{FFFFFF}Please enter your password below to login to your account:", "Enter", "Leave");
	}
	else
	{
		ShowPlayerDialog(playerid, REGISTER_DIALOG, DIALOG_STYLE_PASSWORD, "{FFFFFF}Register Account", "{FFFFFF}Please enter a password below to register an account:", "Enter", "Leave");
	}
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	SaveAccount(playerid);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    if(killerid != INVALID_PLAYER_ID)
	{
	    SetPlayerScore(killerid, GetPlayerScore(killerid) + 1);
		PlayerData[killerid][player_kills]++;
	}

	SetPlayerScore(playerid, GetPlayerScore(playerid) - 1);
    PlayerData[playerid][player_deaths]++;
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if(dialogid == REGISTER_DIALOG)
	{
	    if(response)
	    {
	        if(strlen(inputtext) < 3 || strlen(inputtext) > 24)
			{
				SendClientMessage(playerid, -1, "SERVER: Your password must be from 3-24 characters.");
				return ShowPlayerDialog(playerid, REGISTER_DIALOG, DIALOG_STYLE_PASSWORD, "{FFFFFF}Register Account", "{FFFFFF}Please enter a password below to register an account:", "Enter", "Leave");
			}
			
			bcrypt_hash(playerid, "OnPlayerRegister", inputtext, 12);
			return 1;
	    }
	    else
	    {
	        Kick(playerid);
	    }
	}
	else if(dialogid == LOGIN_DIALOG)
	{
	    if(response)
	    {
	        new query[256], field[64];
	        format(query, sizeof(query), "SELECT `PASS` FROM `USERS` WHERE `NAME` = '%s' COLLATE NOCASE", DB_Escape(GetName(playerid)));
			database_result = db_query(server_database, query);
		  	if(db_num_rows(database_result))
			{
				db_get_field_assoc(database_result, "PASS", field, sizeof(field));
			  	bcrypt_verify(playerid, "OnPlayerLogin", inputtext, field);
			}
			return 1;
	    }
	    else
	    {
	        Kick(playerid);
	    }
	}
	return 1;
}

forward OnPlayerLogin(playerid, bool:success);
public OnPlayerLogin(playerid, bool:success)
{
 	if(success)
	{
		new query[256], field[24];
	    format(query, sizeof(query), "SELECT * FROM `USERS` WHERE `NAME` = '%s' COLLATE NOCASE", DB_Escape(GetName(playerid)));
		database_result = db_query(server_database, query);
		if(db_num_rows(database_result))
		{
			db_get_field_assoc(database_result, "ADMIN", field, sizeof(field));
			PlayerData[playerid][player_admin] = strval(field);

			db_get_field_assoc(database_result, "SCORE", field, sizeof(field));
			SetPlayerScore(playerid, strval(field));

			db_get_field_assoc(database_result, "KILLS", field, sizeof(field));
			PlayerData[playerid][player_kills] = strval(field);

			db_get_field_assoc(database_result, "DEATHS", field, sizeof(field));
			PlayerData[playerid][player_deaths] = strval(field);
		}

		db_free_result(database_result);
		
		PlayerData[playerid][player_logged] = true;

		SendClientMessage(playerid, -1, "SERVER: You have successfully logged into your account.");
		return 1;
 	}
	else
 	{
 		Kick(playerid);
 	}
	return 1;
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
	new password[64];
	bcrypt_get_hash(password);

	new query[256];
	format(query, sizeof(query), "INSERT INTO `USERS` (`NAME`, `PASS`, `ADMIN`, `SCORE`, `KILLS`, `DEATHS`) VALUES ('%s', '%s', '%d', '%d', '%d', '%d')", DB_Escape(GetName(playerid)), password, PLAYER, GetPlayerScore(playerid), PlayerData[playerid][player_kills], PlayerData[playerid][player_deaths]);
	database_result = db_query(server_database, query);
	db_free_result(database_result);

	PlayerData[playerid][player_logged] = true;
	
	SendClientMessage(playerid, -1, "SERVER: You have successfully registered an account.");
	return 1;
}

CMD:setlevel(playerid, params[])
{
	new query[128], string[128], name[MAX_PLAYER_NAME], level[16], admin;
	if(!IsPlayerAdmin(playerid) && PlayerData[playerid][player_admin] < OWNER) return SendClientMessage(playerid, -1, "SERVER: You do not have access to this command.");
	if(sscanf(params, "s[MAX_PLAYER_NAME]s[16]", name, level)) return SendClientMessage(playerid, -1, "USAGE: /setlevel [name] [player/helper/admin/owner]");
	
	if(!strcmp(level, "player", true))
	{
	    admin = PLAYER;
	}
	else if(!strcmp(level, "helper", true))
	{
	    admin = HELPER;
	}
	else if(!strcmp(level, "admin", true))
	{
	    admin = ADMIN;
	}
	else if(!strcmp(level, "owner", true))
	{
	    admin = OWNER;
	}
	else
	{
	    return SendClientMessage(playerid, -1, "SERVER: Invalid admin level. Must be: player/helper/admin/owner");
	}
	
	format(query, sizeof(query), "SELECT `ADMIN` FROM `USERS` WHERE `NAME` = '%s' COLLATE NOCASE", DB_Escape(name));
	database_result = db_query(server_database, query);
	if(db_num_rows(database_result))
	{
		format(query, sizeof(query), "UPDATE `USERS` SET ADMIN = '%d' WHERE `NAME` = '%s' COLLATE NOCASE", admin, DB_Escape(name));
		database_result = db_query(server_database, query);
		db_free_result(database_result);
		
		for(new i = 0; i < MAX_PLAYERS; i++)
		{
			if(IsPlayerConnected(i) && !IsPlayerNPC(i))
			{
				if(!strcmp(GetName(i), name, true))
				{
					PlayerData[i][player_admin] = admin;
					break;
				}
			}
		}
		
		format(string, sizeof(string), "SERVER: That player's admin level has been updated to: %s", level);
		SendClientMessage(playerid, -1, string);
	}
	else
	{
	    SendClientMessage(playerid, -1, "SERVER: That player name does not exist in the database.");
	}
	return 1;
}

CMD:kick(playerid, params[])
{
	new targetid, string[128], reason[32];
	if(PlayerData[playerid][player_admin] < ADMIN) return SendClientMessage(playerid, -1, "SERVER: You do not have access to this command.");
    if(sscanf(params, "us[32]", targetid, reason)) return SendClientMessage(playerid, -1, "USAGE: /kick [player] [reason]");
    if(strlen(reason) < 2 || strlen(reason) > 32) return SendClientMessage(playerid, -1, "SERVER: The reason must be from 2-32 characters.");
	if(!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "SERVER: That player is not connected.");
	if(IsPlayerNPC(targetid)) return SendClientMessage(playerid, -1, "SERVER: That player is an NPC.");
	
	format(string, sizeof(string), "ADMIN: %s (%d) has been kicked by %s (%d) for: %s", GetName(targetid), targetid, GetName(playerid), playerid, reason);
	SendClientMessageToAll(-1, string);
	
	Kick(targetid);
	return 1;
}

CMD:ban(playerid, params[])
{
	new targetid, string[128], reason[32];
	if(PlayerData[playerid][player_admin] < ADMIN) return SendClientMessage(playerid, -1, "SERVER: You do not have access to this command.");
    if(sscanf(params, "us[32]", targetid, reason)) return SendClientMessage(playerid, -1, "USAGE: /ban [player] [reason]");
    if(strlen(reason) < 2 || strlen(reason) > 32) return SendClientMessage(playerid, -1, "SERVER: The reason must be from 2-32 characters.");
	if(!IsPlayerConnected(targetid)) return SendClientMessage(playerid, -1, "SERVER: That player is not connected.");
	if(IsPlayerNPC(targetid)) return SendClientMessage(playerid, -1, "SERVER: That player is an NPC.");

	format(string, sizeof(string), "ADMIN: %s (%d) has been banned by %s (%d) for: %s", GetName(targetid), targetid, GetName(playerid), playerid, reason);
	SendClientMessageToAll(-1, string);

	Ban(targetid);
	return 1;
}

