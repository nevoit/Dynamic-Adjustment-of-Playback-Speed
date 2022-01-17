--[[----- Slow sub ------------------------
"psm_looper_intf.lua" - Put this VLC Interface Lua script file in \lua\intf\ folder
--------------------------------------------
Requires "slowsub.lua" > Put the VLC Extension Lua script file in \lua\extensions\ folder

* The Interface script can be activated from the CLI (batch script or desktop shortcut icon):
vlc.exe --extraintf=luaintf --lua-intf=psm_looper_intf
* Otherwise the Extension script (First run: "Time > SETTINGS" dialog_msg box) will help you to set appropriate VLC preferences for automatic activation of the Interface script or you can do it manually:
VLC Preferences:
Tools > Preferences > Show settings=All > Interface >
> Main interfaces: Extra interface modules [luaintf]
> Main interfaces > Lua: Lua interface [psm_looper_intf]
Then use the Extension ("Slowsub" dialog_msg box) to control the active Interface script.
The installed Extension is available in VLC menu "View" or "Vlc > Extensions" on Mac OS X.

INSTALLATION directory:
* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\intf\
* Windows (current user): %APPDATA%\VLC\lua\intf\
* Linux (all users): /usr/lib/vlc/lua/intf/
* Linux (current user): ~/.local/share/vlc/lua/intf/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/intf/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/intf/
--]]----------------------------------------


-- Constants
UTF8BOM = string.char(0xEF, 0xBB, 0xBF)
--MAXTIMEDIFFERENCE = 3 --Time in seconds
--NORMALRATE = 1.0

-- Global variables
subtitles = {}

--**********************LOAD SUBS****************************
function load_subtitles()
    local subtitles_uri = subtitle_path()
    -- read file subtitles_uri
    local s = vlc.stream(subtitles_uri)
    if s == nil then
        return false
    end
    --Read max 500000 chars -> enough
    local data = s:read(500000)
    --replace the "\r" char with an empty char
    data = string.gsub( data, "\r", "")
    -- UTF-8 BOM detection
    if string.sub(data, 1, 3) ~= UTF8BOM then
        data = vlc.strings.from_charset("Windows-1250", data)
    end
    -- parse datavlc.object.
    subtitles = {}
    srt_pattern = "(%d%d):(%d%d):(%d%d),(%d%d%d) %-%-> (%d%d):(%d%d):(%d%d),(%d%d%d).-\n(.-)\n\n"
    --Find string match for find time value in the srt file
    for h1, m1, s1, ms1, h2, m2, s2, ms2, text in string.gmatch(data, srt_pattern) do
        --If the text is empty then add a space
        if text:find('%[') and text:find('%]') then
            vlc.msg.dbg("continued since the text is: "..text)
        elseif text:find('%♪') then
            vlc.msg.dbg("continued since the text is: "..text)
        else
            if text == "" then
                text ="  "
            else --Add value start/stop time and text in the table subtitles
                table.insert(subtitles, {format_time(h1, m1, s1, ms1), format_time(h2, m2, s2, ms2), text})
            end
        end
    end
    if #subtitles ~= 0 then
        return true
    else
        return false
    end
end

function format_time(h,m,s,ms) -- time to seconds
    --ToDO : add millisecond + tonumber(ms)
    return tonumber(h)*3600 + tonumber(m)*60 + tonumber(s)
end

function subtitle_path()
    local media_uri = vlc.input.item():uri()
    media_uri = string.gsub(media_uri, "^(.*)%..-$","%1") .. ".srt"
    return media_uri
end

--***************************ENDOF LOAD SUBS*********************************


--******************************SLOWSPEED************************************
-- |------i------------i-----|-----i+1----------i+1-----|
-- |-----SUB-----|+++++++++++|-----SUB-----|++++++++++++|
function rate_adjustment(sub_index)
    local input = vlc.object.input()
    local currentSpeed = vlc.var.get(input,"rate")
    local speedup = tonumber(cfg.general.speedup)
    local updatedSpeed = tonumber(cfg.general.rate)
    local maxdiff = tonumber(cfg.general.maxdiff)

    actual_time = get_elapsed_time()
    time_gap = tonumber(speedup)
    prev_subtitle_start_early = subtitles[sub_index][1] - time_gap
    prev_subtitle_end_late = subtitles[sub_index][2] + time_gap
    next_subtitle_start_early = subtitles[sub_index + 1][1] - time_gap
    vlc.msg.dbg("Current rate: "..vlc.var.get(input,"rate"))
    if  subtitles[sub_index + 1] == nil then
        --check for the last subs and avoid error with the table subtitles
        --log_msg("Where are we: after the last sub")
        if currentSpeed ~= speedup then
            vlc.var.set(input, "rate", speedup)
        end
    elseif actual_time < subtitles[1][1] then 
        --avoid loop/reindexing while waiting the first sub
        --log_msg("Where are we: before first subtitle")
        if currentSpeed ~= speedup then
            vlc.var.set(input, "rate", speedup)
        end
        sub_index = 1
    elseif actual_time >= prev_subtitle_start_early and actual_time <= subtitles[sub_index][2] then         ----  (start_time=id1)| [here] CURRENT SUBTITLE [here] | (end_time=id2) -----
        --if find the next sub return the index and avoid the while/reindexing
        log_msg("Where are we: in the current sub"..subtitles[sub_index][1])
        if currentSpeed ~= updatedSpeed then
            vlc.var.set(input, "rate", updatedSpeed)
        end
    elseif actual_time > prev_subtitle_end_late and actual_time < next_subtitle_start_early then   ----  |PREV SUBTITLE|(end_time=id2)   --  [here]  --   (start_time=id1)|NEXT SUBTITLE| -----
        --if we are in the middle from two consecutive subs return and avoid the while/reindexing
        --log_msg("Where are we: between two subs")
        --don't change the rate if two subs are near
        if currentSpeed ~= speedup and (subtitles[sub_index + 1][1] - subtitles[sub_index][2]) >= maxdiff then
            vlc.var.set(input, "rate", speedup)
        end
    elseif actual_time >= next_subtitle_start_early and actual_time <= subtitles[sub_index + 1][2] then     ----  (start_time=id1)| [here] NEXT SUBTITLE [here] | (end_time=id2) -----
         --if we are in the next Sub update sub_index
        --log_msg("Where are we: in the next sub")
        if currentSpeed ~= updatedSpeed then
            vlc.var.set(input, "rate", updatedSpeed)
        end
        sub_index = sub_index + 1
    else --if user change the elapsed time check all subs and wait for the new index
        --log_msg("Where are we: do not know, reindexing")
        local i = 1
        while subtitles[i] do
            if actual_time >= subtitles[i][1] and actual_time < subtitles[i + 1][1] then
                sub_index = i
                break
            end
            i = i + 1
        end
    end
    return sub_index
end

function get_elapsed_time()
    local input = vlc.object.input()
    --VLC 3 : elapsed_time must be divided by 1000000 -> to seconds
    --VLC2.1+ : Don't need the division -> already in seconds
    local elapsed_time = vlc.var.get(input, "time") / 1000000

    return elapsed_time
end

--*****************************ENDOF SLOWSPEED*********************************


--*********************************LOOPER**************************************
function looper()
    local last_sub_index = 1
    local curi = nil -- Path to the media file currently playing
    
    -- This settings are set as soon as VLC starts, before any user interaction
    cfg = load_config()
    cfg.general.speedup = 2
    cfg.general.rate = 1
    cfg.general.maxdiff = 10  --Time in seconds
    cfg.status.enabled = false
    cfg.status.restarted = true
    save_config(cfg)

    while true do
        if vlc.volume.get() == -256 then -- inspired by syncplay.lua; kills vlc.exe process in Task Manager
            break
        end
        cfg = load_config()
        if not cfg.status.enabled then
            sleep(1)
        elseif vlc.playlist.status() == "playing" then
            uri = vlc.input.item():uri()
            if not curi or curi ~= uri then -- new input (first input or changed input)
                curi = uri
                subs_ready = false
            end
            if subs_ready then
                last_sub_index = rate_adjustment(last_sub_index)
            else
                -- Keep trying loading the subtitles. This allows the extension to start 
                -- as soon as the name of the subtitles matches that of the video file
                subs_ready = load_subtitles()
                sleep(1)
            end
            sleep(0.1)
        elseif vlc.playlist.status() == "stopped" then -- no input or stopped input
            curi = nil
            sleep(1)
        elseif vlc.playlist.status() == "paused" then
            sleep(0.3)
        else -- ?
            log_msg("unknown. Playlist status: ".. vlc.playlist.status())
            sleep(1)
        end
    end
end

function log_msg(lm)
    vlc.msg.info(lm)
end

function sleep(st) -- seconds
    vlc.misc.mwait(vlc.misc.mdate() + st*1000000)
end

--- Returns a table containing all the data from the INI file.
--@param fileName The name of the INI file to parse. [string]
--@return The table containing all data from the INI file. [table]
function load_config()
    fileName = vlc.config.configdir() .. "slowsubrc"
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
    local file = io.open(fileName, 'r')
    if not file then
        --, 'Error loading file :' .. fileName);
        data = default_config();
        save_config(data)
        return data
    end
    local data = {};
    local section;
    for line in file:lines() do
        local tempSection = line:match('^%[([^%[%]]+)%]$');
        if(tempSection)then
            section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
            data[section] = data[section] or {};
        end
        local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$');
        if(param and value ~= nil)then
            if(tonumber(value))then
                value = tonumber(value);
            elseif(value == 'true')then
                value = true;
            elseif(value == 'false')then
                value = false;
            end
            if(tonumber(param))then
                param = tonumber(param);
            end
            data[section][param] = value;
        end
    end
    file:close();
    return data;
end

--- Saves all the data from a table to an INI file.
--@param fileName The name of the INI file to fill. [string]
--@param data The table containing all the data to store. [table]
function save_config(data)
    fileName = vlc.config.configdir() .. "slowsubrc"
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
    assert(type(data) == 'table', 'Parameter "data" must be a table.');
    local file = assert(io.open(fileName, 'w+b'), 'Error loading file :' .. fileName);
    local contents = '';
    for section, param in pairs(data) do
        contents = contents .. ('[%s]\n'):format(section);
        for key, value in pairs(param) do
            contents = contents .. ('%s=%s\n'):format(key, tostring(value));
        end
        contents = contents .. '\n';
    end
    file:write(contents);
    file:close();
end

function default_config()
    local data = {}
    data.general = {}
    data.general.speedup = 2
    data.general.rate = 1
    data.general.maxdiff = 10  --Time in seconds
    data.status = {}
    data.status.restarted = true
    return data
end
--- MAIN ---

looper()
