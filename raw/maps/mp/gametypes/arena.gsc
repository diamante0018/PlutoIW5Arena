// IW5 GSC SOURCE
// Decompiled by https://github.com/xensik/gsc-tool

main()
{
    if ( getdvar( "mapname" ) == "mp_background" )
        return;

    maps\mp\gametypes\_globallogic::init();
    maps\mp\gametypes\_callbacksetup::SetupCallbacks();
    maps\mp\gametypes\_globallogic::SetupCallbacks();

    maps\mp\_utility::registerRoundSwitchDvar( level.gameType, 0, 0, 9 );
    maps\mp\_utility::registerTimeLimitDvar( level.gameType, 10 );
    maps\mp\_utility::registerScoreLimitDvar( level.gameType, 500 );
    maps\mp\_utility::registerRoundLimitDvar( level.gameType, 1 );
    maps\mp\_utility::registerWinLimitDvar( level.gameType, 1 );
    maps\mp\_utility::registerNumLivesDvar( level.gameType, 0 );
    maps\mp\_utility::registerHalfTimeDvar( level.gameType, 0 );

    level.teamBased = 1;
    level.objectiveBased = 1;
    level.onPrecacheGameType = ::onPrecacheGameType;
    level.onStartGameType = ::onStartGameType;
    level.getSpawnPoint = ::getSpawnPoint;
    level.onSpawnPlayer = ::onSpawnPlayer;
    level.onNormalDeath = ::onNormalDeath;
    level.onPlayerKilled = ::onPlayerKilled;
    level.onDeadEvent = ::onDeadEvent;
    game["dialog"]["gametype"] = "arena";

    if ( getdvarint( "g_hardcore" ) )
        game["dialog"]["gametype"] = "hc_" + game["dialog"]["gametype"];
    else if ( getdvarint( "camera_thirdPerson" ) )
        game["dialog"]["gametype"] = "thirdp_" + game["dialog"]["gametype"];
    else if ( getdvarint( "scr_diehard" ) )
        game["dialog"]["gametype"] = "dh_" + game["dialog"]["gametype"];

    game["strings"]["overtime_hint"] = &"MP_FIRST_BLOOD";
}

onPrecacheGameType()
{
    precacheshader( "compass_waypoint_captureneutral" );
    precacheshader( "compass_waypoint_capture" );
    precacheshader( "compass_waypoint_defend" );
    precacheshader( "waypoint_captureneutral" );
    precacheshader( "waypoint_capture" );
    precacheshader( "waypoint_defend" );
}

onStartGameType()
{
    setclientnamemode( "auto_change" );

    if ( !isdefined( game["switchedsides"] ) )
        game["switchedsides"] = 0;

    if ( game["switchedsides"] )
    {
        var_0 = game["attackers"];
        var_1 = game["defenders"];
        game["attackers"] = var_1;
        game["defenders"] = var_0;
    }

    maps\mp\_utility::setObjectiveText( "allies", &"OBJECTIVES_ARENA" );
    maps\mp\_utility::setObjectiveText( "axis", &"OBJECTIVES_ARENA" );

    if ( level.splitscreen )
    {
        maps\mp\_utility::setObjectiveScoreText( "allies", &"OBJECTIVES_ARENA" );
        maps\mp\_utility::setObjectiveScoreText( "axis", &"OBJECTIVES_ARENA" );
    }
    else
    {
        maps\mp\_utility::setObjectiveScoreText( "allies", &"OBJECTIVES_ARENA_SCORE" );
        maps\mp\_utility::setObjectiveScoreText( "axis", &"OBJECTIVES_ARENA_SCORE" );
    }

    maps\mp\_utility::setObjectiveHintText( "allies", &"OBJECTIVES_ARENA_HINT" );
    maps\mp\_utility::setObjectiveHintText( "axis", &"OBJECTIVES_ARENA_HINT" );
    level.spawnMins = ( 0, 0, 0 );
    level.spawnMaxs = ( 0, 0, 0 );
    maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_tdm_spawn_allies_start" );
    maps\mp\gametypes\_spawnlogic::placeSpawnPoints( "mp_tdm_spawn_axis_start" );
    maps\mp\gametypes\_spawnlogic::addSpawnPoints( "allies", "mp_tdm_spawn" );
    maps\mp\gametypes\_spawnlogic::addSpawnPoints( "axis", "mp_tdm_spawn" );
    level.mapCenter = maps\mp\gametypes\_spawnlogic::findBoxCenter( level.spawnMins, level.spawnMaxs );
    setmapcenter( level.mapCenter );
    var_2[0] = "dom";
    var_2[1] = "airdrop_pallet";
    var_2[2] = "arena";
    maps\mp\gametypes\_rank::registerScoreInfo( "capture", 200 );
    maps\mp\gametypes\_gameobjects::main( var_2 );
    precacheFlag();
    thread arenaFlagWaiter();
    thread arenaTimeFlagWaiter();
}

precacheFlag()
{
    game["flagmodels"] = [];
    game["flagmodels"]["neutral"] = "prop_flag_neutral";
    game["flagmodels"]["allies"] = maps\mp\gametypes\_teams::getTeamFlagModel( "allies" );
    game["flagmodels"]["axis"] = maps\mp\gametypes\_teams::getTeamFlagModel( "axis" );
    precachemodel( game["flagmodels"]["neutral"] );
    precachemodel( game["flagmodels"]["allies"] );
    precachemodel( game["flagmodels"]["axis"] );
    precachestring( &"MP_CAPTURING_FLAG" );
    precachestring( &"MP_LOSING_FLAG" );
    precachestring( &"MP_DOM_YOUR_FLAG_WAS_CAPTURED" );
    precachestring( &"MP_DOM_ENEMY_FLAG_CAPTURED" );
    precachestring( &"MP_DOM_NEUTRAL_FLAG_CAPTURED" );
    precachestring( &"MP_ENEMY_FLAG_CAPTURED_BY" );
    precachestring( &"MP_NEUTRAL_FLAG_CAPTURED_BY" );
    precachestring( &"MP_FRIENDLY_FLAG_CAPTURED_BY" );
}

arenaTimeFlagWaiter()
{
    level endon( "down_to_one" );
    level endon( "game_end" );

    for (;;)
    {
        var_0 = maps\mp\gametypes\_gamelogic::getTimeRemaining();

        if ( var_0 < 61000 )
            break;

        wait 1;
    }

    level notify( "arena_flag_time" );
    thread arenaFlag();
}

arenaFlagWaiter()
{
    level endon( "game_end" );
    level endon( "arena_flag_time" );

    for (;;)
    {
        if ( level.inGracePeriod == 0 )
            break;

        wait 0.05;
    }

    for (;;)
    {
        if ( getteamplayersalive( "axis" ) == 1 )
        {
            thread arenaFlag();
            level notify( "down_to_one" );
            break;
        }

        if ( getteamplayersalive( "allies" ) == 1 )
        {
            thread arenaFlag();
            level notify( "down_to_one" );
            break;
        }

        wait 1;
    }
}

getSpawnPoint()
{
    var_0 = self.pers["team"];

    if ( game["switchedsides"] )
        var_0 = maps\mp\_utility::getOtherTeam( var_0 );

    if ( level.inGracePeriod )
    {
        var_1 = maps\mp\gametypes\_spawnlogic::getSpawnpointArray( "mp_tdm_spawn_" + var_0 + "_start" );
        var_2 = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random( var_1 );
    }
    else
    {
        var_1 = maps\mp\gametypes\_spawnlogic::getTeamSpawnPoints( var_0 );
        var_2 = maps\mp\gametypes\_spawnlogic::getSpawnpoint_NearTeam( var_1 );
    }

    return var_2;
}

onSpawnPlayer()
{
    self.usingObj = undefined;
    level notify( "spawned_player" );
}

onNormalDeath( var_0, var_1, var_2 )
{
    var_3 = maps\mp\gametypes\_rank::getScoreInfoValue( "kill" );
    var_1 maps\mp\gametypes\_gamescore::giveTeamScoreForObjective( var_1.pers["team"], var_3 );
    var_4 = var_0.team;

    if ( game["state"] == "postgame" )
        var_1.finalKill = 1;
}

onPlayerKilled( var_0, var_1, var_2, var_3, var_4, var_5, var_6, var_7, var_8, var_9 )
{
    thread checkAllowSpectating();
}

onTimeLimit()
{
    if ( game["status"] == "overtime" )
        var_0 = "forfeit";
    else if ( game["teamScores"]["allies"] == game["teamScores"]["axis"] )
        var_0 = "overtime";
    else if ( game["teamScores"]["axis"] > game["teamScores"]["allies"] )
        var_0 = "axis";
    else
        var_0 = "allies";

    thread maps\mp\gametypes\_gamelogic::endGame( var_0, game["strings"]["time_limit_reached"] );
}

checkAllowSpectating()
{
    wait 0.05;
    var_0 = 0;

    if ( !level.aliveCount[game["attackers"]] )
    {
        level.spectateOverride[game["attackers"]].allowEnemySpectate = 1;
        var_0 = 1;
    }

    if ( !level.aliveCount[game["defenders"]] )
    {
        level.spectateOverride[game["defenders"]].allowEnemySpectate = 1;
        var_0 = 1;
    }

    if ( var_0 )
        maps\mp\gametypes\_spectating::updateSpectateSettings();
}

arenaFlag()
{
    level.lastStatus["allies"] = 0;
    level.lastStatus["axis"] = 0;
    var_0 = getentarray( "flag_arena", "targetname" );
    var_1 = getentarray( "flag_primary", "targetname" );
    var_2 = getentarray( "flag_secondary", "targetname" );

    if ( !isdefined( var_0[0] ) )
    {
        if ( var_1.size + var_2.size < 1 )
        {
            maps\mp\gametypes\_callbacksetup::AbortLevel();
            return;
        }

        setupDomFlag( var_1, var_2 );
    }
    else
        level.arenaFlag = var_0[0];

    var_3 = level.arenaFlag;

    if ( isdefined( var_3.target ) )
        var_4[0] = getent( var_3.target, "targetname" );
    else
    {
        var_4[0] = spawn( "script_model", var_3.origin );
        var_4[0].angles = var_3.angles;
    }

    var_4[0] setmodel( game["flagmodels"]["neutral"] );
    var_0 = maps\mp\gametypes\_gameobjects::createUseObject( "neutral", var_3, var_4, ( 0, 0, 100 ) );
    var_0 maps\mp\gametypes\_gameobjects::allowUse( "enemy" );
    var_0 maps\mp\gametypes\_gameobjects::setUseTime( 20.0 );
    var_0 maps\mp\gametypes\_gameobjects::setUseText( &"MP_CAPTURING_FLAG" );
    var_5 = var_0 maps\mp\gametypes\_gameobjects::getLabel();
    var_0.label = var_5;
    var_0 maps\mp\gametypes\_gameobjects::set2DIcon( "friendly", "compass_waypoint_defend" );
    var_0 maps\mp\gametypes\_gameobjects::set3DIcon( "friendly", "waypoint_defend" );
    var_0 maps\mp\gametypes\_gameobjects::set2DIcon( "enemy", "compass_waypoint_captureneutral" );
    var_0 maps\mp\gametypes\_gameobjects::set3DIcon( "enemy", "waypoint_captureneutral" );
    var_0 maps\mp\gametypes\_gameobjects::setVisibleTeam( "any" );
    var_0.onUse = ::onUse;
    var_0.onBeginUse = ::onBeginUse;
    var_0.onUseUpdate = ::onUseUpdate;
    var_0.onEndUse = ::onEndUse;
    var_0.isArena = 1;
    iprintlnbold( "Arena flag spawned" );
    level.arenaFlag playsound( "flag_spawned" );
    var_6 = var_4[0].origin + ( 0, 0, 32 );
    var_7 = var_4[0].origin + ( 0, 0, -32 );
    var_8 = bullettrace( var_6, var_7, 0, undefined );
    var_9 = vectortoangles( var_8["normal"] );
    var_0.baseeffectforward = anglestoforward( var_9 );
    var_0.baseeffectright = anglestoright( var_9 );
    var_0.baseeffectpos = var_8["position"];
    var_0.levelFlag = level.arenaFlag;
    level.arenaFlag = var_0;
}

setupDomFlag( var_0, var_1 )
{
    for ( var_2 = 0; var_2 < var_0.size; var_2++ )
    {
        var_3 = var_0[var_2].script_label;

        if ( var_3 != "_b" )
        {
            var_0[var_2] delete();
            continue;
        }

        level.arenaFlag = var_0[var_2];
        return;
    }
}

onDeadEvent( var_0 )
{
    if ( var_0 == game["attackers"] )
        level thread arena_endGame( game["defenders"], game["strings"][game["attackers"] + "_eliminated"] );
    else if ( var_0 == game["defenders"] )
        level thread arena_endGame( game["attackers"], game["strings"][game["defenders"] + "_eliminated"] );
}

arena_endGame( var_0, var_1 )
{
    thread maps\mp\gametypes\_gamelogic::endGame( var_0, var_1 );
}

giveFlagCaptureXP( var_0 )
{
    level endon( "game_ended" );
    wait 0.05;
    maps\mp\_utility::WaitTillSlowProcessAllowed();
    var_1 = getarraykeys( var_0 );

    for ( var_2 = 0; var_2 < var_1.size; var_2++ )
    {
        var_3 = var_0[var_1[var_2]].player;
        var_3 thread [[ level.onXPEvent ]]( "capture" );
        maps\mp\gametypes\_gamescore::givePlayerScore( "capture", var_3 );
        var_3 thread maps\mp\_matchdata::logGameEvent( "capture", var_3.origin );
    }
}

onUse( player )
{
    var_1 = player.pers["team"];
    var_2 = maps\mp\gametypes\_gameobjects::getOwnerTeam();
    var_3 = maps\mp\gametypes\_gameobjects::getLabel();

    player logString( "flag captured: " + self.label );

    self.captureTime = gettime();
    maps\mp\gametypes\_gameobjects::setOwnerTeam( var_1 );
    maps\mp\gametypes\_gameobjects::set2DIcon( "enemy", "compass_waypoint_capture" );
    maps\mp\gametypes\_gameobjects::set3DIcon( "enemy", "waypoint_capture" );
    self.visuals[0] setmodel( game["flagmodels"][var_1] );

    if ( var_2 == "neutral" )
    {
        var_4 = maps\mp\_utility::getOtherTeam( var_1 );
        thread maps\mp\_utility::printAndSoundOnEveryone( var_1, var_4, &"MP_NEUTRAL_FLAG_CAPTURED_BY", &"MP_NEUTRAL_FLAG_CAPTURED_BY", "mp_war_objective_taken", undefined, player );
        statusDialog( "captured_a", var_1 );
        statusDialog( "enemy_has_a", var_4 );
    }
    else
        thread maps\mp\_utility::printAndSoundOnEveryone( var_1, var_2, &"MP_ENEMY_FLAG_CAPTURED_BY", &"MP_FRIENDLY_FLAG_CAPTURED_BY", "mp_war_objective_taken", "mp_war_objective_lost", player );

    thread giveFlagCaptureXP( self.touchList[var_1] );
    player notify( "objective", "captured" );
    thread flagCaptured( var_1, &"MP_DOM_NEUTRAL_FLAG_CAPTURED" );
}

onBeginUse( var_0 )
{
    var_1 = maps\mp\gametypes\_gameobjects::getOwnerTeam();
    self.didStatusNotify = 0;

    if ( var_1 == "neutral" )
    {
        var_2 = maps\mp\_utility::getOtherTeam( var_0.pers["team"] );
        statusDialog( "securing", var_0.pers["team"] );
        self.objPoints[var_0.pers["team"]] thread maps\mp\gametypes\_objpoints::startFlashing();
        statusDialog( "enemy_taking", var_2 );
        return;
    }

    if ( var_1 == "allies" )
        var_2 = "axis";
    else
        var_2 = "allies";

    self.objPoints["allies"] thread maps\mp\gametypes\_objpoints::startFlashing();
    self.objPoints["axis"] thread maps\mp\gametypes\_objpoints::startFlashing();
}

onUseUpdate( var_0, var_1, var_2 )
{
    if ( var_1 > 0.05 && var_2 && !self.didStatusNotify )
    {
        var_3 = maps\mp\_utility::getOtherTeam( var_0 );
        statusDialog( "losing_a", var_3 );
        statusDialog( "securing_a", var_0 );
        self.didStatusNotify = 1;
    }
}

onEndUse( var_0, var_1, var_2 )
{
    self.objPoints["allies"] thread maps\mp\gametypes\_objpoints::stopFlashing();
    self.objPoints["axis"] thread maps\mp\gametypes\_objpoints::stopFlashing();
}

statusDialog( dialog, team )
{
    if ( gettime() < level.lastStatus[team ] + 6000 )
        return;

    thread delayedLeaderDialog( dialog, team );
    level.lastStatus[team ] = gettime();
}

delayedLeaderDialog( sound, team )
{
    level endon( "game_ended" );
    wait 0.1;
    maps\mp\_utility::WaitTillSlowProcessAllowed();
    maps\mp\_utility::leaderDialog( sound, team );
}

delayedLeaderDialogBothTeams( sound1, team1, sound2, team2 )
{
    level endon( "game_ended" );
    wait 0.1;
    maps\mp\_utility::WaitTillSlowProcessAllowed();
    maps\mp\_utility::leaderDialogBothTeams( sound1, team1, sound2, team2  );
}

flagCaptured( var_0, var_1 )
{
    maps\mp\gametypes\_gamelogic::endGame( var_0, var_1 );
}
