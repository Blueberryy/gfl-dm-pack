#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <gfldm>
#include <gfldm-chat>

int noscopes[MAXPLAYERS + 1];
int headshots[MAXPLAYERS + 1];
int annouce_kill_count = 4;

public Plugin myinfo = {
    name = "GFLDM NoScopes",
    author = "Dreae",
    description = "Announces noscopes",
    version = GFLDM_VERSION, 
    url = "https://github.com/GFLClan/gfl-dm-pack"
}

GlobalForward fwd_OnNoscope = null;

public void OnPluginStart() {
    if(GetEngineVersion() != Engine_CSGO && GetEngineVersion() != Engine_CSS) {
		SetFailState("Plugin supports CSS and CS:GO only.");
    }

    HookEvent("player_death", OnPlayerDeath);
    LoadTranslations("gfldm_noscopes.phrases");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    fwd_OnNoscope = new GlobalForward("GFLDM_OnNoscope", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float);
    CreateNative("GFLDM_GetNoscopes", native_GetNoscopes);
    CreateNative("GFLDM_GetNoscopeHeadshots", native_GetNoscopeHeadshots);
}

public void OnClientConnected(int client) {
    noscopes[client] = 0;
    headshots[client] = 0;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (!GFLDM_IsValidClient(victim, true) || !GFLDM_IsValidClient(attacker)) {
        return;
    }

    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));

    if ((StrContains(weapon, "awp") != -1 || StrContains(weapon, "ssg08") != -1 || StrContains(weapon, "scout") != -1) && !IsScoped(attacker)) {
        float distance = GetDistance(attacker, victim);
        bool headshot = event.GetBool("headshot");

        if (fwd_OnNoscope != INVALID_HANDLE) {
            Call_StartForward(fwd_OnNoscope);
            
            Call_PushCell(attacker);
            Call_PushCell(victim);
            Call_PushCell(headshot);
            Call_PushFloat(distance);

            Call_Finish();
        }

        noscopes[attacker]++;
        if (headshot) {
            headshots[attacker]++;
            GFLDM_PrintToChatAll("%t", "Headshot noscoped", attacker, victim, distance);
        } else {
            GFLDM_PrintToChatAll("%t", "Noscoped", attacker, victim, distance);
        }

        if (noscopes[attacker] % annouce_kill_count == 0) {
            GFLDM_PrintToChatAll("%t", "Total noscopes", attacker, noscopes[attacker], headshots[attacker]);
        }
    }
}

public int native_GetNoscopes(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    if (GFLDM_IsValidClient(client)) {
        return noscopes[client];
    }

    return 0;
}

public int native_GetNoscopeHeadshots(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    if (GFLDM_IsValidClient(client)) {
        return headshots[client];
    }

    return 0;
}

float GetDistance(int a, int b) {
    float a_origin[3];
    GetClientAbsOrigin(a, a_origin);

    float b_origin[3];
    GetClientAbsOrigin(b, b_origin);

    // Magic number from https://developer.valvesoftware.com/wiki/Dimensions
    return GetVectorDistance(a_origin, b_origin) / 52.49;
}

bool IsScoped(int client) {
    if (GetEngineVersion() != Engine_CSS) {
        return GetEntProp(client, Prop_Send, "m_bIsScoped") > 0;
    } else {
        return (0 < GetEntProp(client, Prop_Data, "m_iFOV") < GetEntProp(client, Prop_Data, "m_iDefaultFOV"));
    }
}