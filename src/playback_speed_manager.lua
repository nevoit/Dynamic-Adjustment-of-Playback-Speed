--[[----------------------------------------
"playback_speed_manager.lua" > Put this VLC Extension Lua script file in \lua\extensions\ folder
--------------------------------------------
Requires "psm_looper_intf.lua" > Put the VLC Interface Lua script file in \lua\intf\ folder

* The Interface script can be activated from the CLI (batch script or desktop shortcut icon):
vlc.exe --extraintf=luaintf --lua-intf=psm_looper_intf
* Otherwise the Extension script (First run: "Slow sub > SETTINGS" dialog box) will help you to set appropriate VLC preferences for automatic activation of the Interface script or you can do it manually:
VLC Preferences:
Tools > Preferences > Show settings=All > Interface >
> Main interfaces: Extra interface modules [luaintf]
> Main interfaces > Lua: Lua interface [psm_looper_intf]
Then use the Extension ("Slow sub" dialog box) to control the active Interface script.
The installed Extension is available in VLC menu "View" or "Vlc > Extensions" on Mac OS X.

INSTALLATION directory:
* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\extensions\
* Windows (current user): %APPDATA%\VLC\lua\extensions\
* Linux (all users): /usr/lib/vlc/lua/extensions/
* Linux (current user): ~/.local/share/vlc/lua/extensions/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/extensions/
--]]----------------------------------------

speedupTable = {"1", "1.50", "2", "2.50", "3", "3.50", "4"}
rateTable = {"1.5", "1.25", "1", "0.9", "0.85", "0.80", "0.75", "0.70", "0.65", "0.60", "0.55", "0.50"}
maxdiffTable = {"2", "5", "10", "30", "45", "60"}

DIALOG_ENABLE = 1
DIALOG_RESTART = 2
DIALOG_SETTINGS = 3
DIALOG_ENABLE_ERROR = 4

---------------- Standard VLC extension functions that must/can be implemented ---------------------
function descriptor()
    return {
        title = "Playback speed manager";
        version = "3.0";
        author = "Michele Gaiarin, Simone Gaiarin";
        url = "https://github.com/ilgaiaz/playback-speed-manager";
        description = [[
Playback speed manager

This extension allows you to increase the playback speed when there are no subtitles and to reduce it when the subtitles appear.
]];
        capabilities = {"menu"}
    }
end

function activate()
    cfg = load_config()
    -- The second check is required to manage crashes of VLC
    if not cfg.status.restarted and vlc.config.get("lua-intf") == "psm_looper_intf" then
        create_dialog_restart()
        return
    end
    if vlc.config.get("lua-intf") ~= "psm_looper_intf" then
        create_dialog_enable_extension()
        return
    end
    cfg.status.enabled = true
    save_config(cfg)
    create_dialog_settings()
end

function deactivate()
    cfg.status.enabled = false
    cfg.general.speedup = "1"
    cfg.general.rate = "1"
    cfg.general.maxdiff = "5"
    save_config(cfg)
end

--- Called when a dialog is closed with the X button
function close()
    if dlg_id == DIALOG_ENABLE or dlg_id == DIALOG_RESTART then
        vlc.deactivate()
    end
end

function menu()
    return {"Settings"}
end

function trigger_menu(id)
    close_dialog()
    if id == 1 then
        create_dialog_settings()
    end
end

function meta_changed()
end

---------------------------- Functions specific to this extension ----------------------------------

function log_msg(lm)
    vlc.msg.info("[Playback speed manager config interface] " .. lm)
end

function close_dialog()
    if dlg then
        dlg:delete()
        dlg = nil
    end
end

function create_dialog_enable_extension()
    dlg_id = DIALOG_ENABLE
    close_dialog()
    dlg = vlc.dialog(descriptor().title .. " > First run")
    message = dlg:add_label("To run the extension Playback speed manager a VLC loop interface needs to<br>be activated the first time. Do you want to enable it now?", 1, 1, 2, 1)
    dlg:add_button("Enable", on_click_enable, 1, 2, 1, 1)
    dlg:add_button("Cancel", on_click_cancel, 2, 2, 1, 1)
end

function create_dialog_enable_error(currentLuaIntf)
    dlg_id = DIALOG_ENABLE_ERROR
    close_dialog()
    dlg = vlc.dialog(descriptor().title .. " > Extension enable error")
    message = dlg:add_label("An extension is currently using the LUA interface (" .. currentLuaIntf .. ").<br>Enabling Playback speed manager will make the other extension stop working.<br>Do you want to enable PLayback speed manager? ", 1, 1, 2, 1)
    dlg:add_button("Enable", enable_extension, 1, 2, 1, 1)
    dlg:add_button("Cancel", on_click_cancel, 2, 2, 1, 1)
end

function create_dialog_restart()
    close_dialog()
    dlg_id = DIALOG_RESTART
    dlg = vlc.dialog(descriptor().title .. " > Restart required")
    message = dlg:add_label("VLC needs to be restarted to use the Playback speed manager extension.", 1, 1, 5, 1)
    dlg:add_button("Ok", on_click_cancel, 3, 2, 1, 1)
end

function create_dialog_settings()
    dlg_id = DIALOG_SETTINGS
    cfg = load_config()

    dlg = vlc.dialog(descriptor().title .. " > Settings")

    -- SPEEDUP
    dlg:add_label("Playback speed (no subtitles): ", 1, 1, 1, 1)
    dd_speedup = dlg:add_dropdown(2, 1, 2, 1)
    dd_speedup:add_value(tostring(cfg.general.speedup)) -- Workaround to show the current value reliably (set_text is not reliable)
    for i, v in ipairs(speedupTable) do
        dd_speedup:add_value(v, i)
    end
    dd_speedup:set_text(tostring(cfg.general.speedup)) -- Required otherwise it is not possible to save sometimes

    -- *******

    -- Rate
    dlg:add_label("Playback speed (subtitles): ", 1, 3, 1, 1)
    dd_rate = dlg:add_dropdown(2, 3, 2, 1)
    dd_rate:add_value(tostring(cfg.general.rate)) -- Workaround to show the current value reliably (set_text is not reliable)
    for i, v in ipairs(rateTable) do
        dd_rate:add_value(v, i)
    end
    dd_rate:set_text(tostring(cfg.general.rate)) -- Required otherwise it is not possible to save sometimes
    -- *******

    -- Maximum difference
    dlg:add_label("Maximum difference (between subtitles): ", 1, 5, 1, 1)
    dd_maxdiff = dlg:add_dropdown(2, 5, 2, 1)
    dd_maxdiff:add_value(tostring(cfg.general.maxdiff)) -- Workaround to show the current value reliably (set_text is not reliable)
    for i, v in ipairs(maxdiffTable) do
        dd_maxdiff:add_value(v, i)
    end
    dd_maxdiff:set_text(tostring(cfg.general.maxdiff)) -- Required otherwise it is not possible to save sometimes

    -- *******


    cb_extraintf = dlg:add_check_box("Loop interface enabled", true, 1, 7, 1, 1)
    dlg:add_button("Save", on_click_save, 2, 6, 1, 1)
    dlg:add_button("Cancel", on_click_cancel , 3, 6, 1, 1)
end

function on_click_cancel()
    dlg:hide()
    if dlg_id == DIALOG_ENABLE or dlg_id == DIALOG_ENABLE_ERROR or dlg_id == DIALOG_RESTART then
        vlc.deactivate()
    end
end

function enable_extension()
    vlc.config.set("extraintf", "luaintf")
    vlc.config.set("lua-intf", "psm_looper_intf")
    cfg.status.restarted = false
    save_config(cfg)
    dlg:hide()
    vlc.deactivate()
end

function on_click_enable()
    local currentLuaIntf = vlc.config.get("lua-intf")
    if currentLuaIntf ~= "" then --Another extension is using the LUA interface
        create_dialog_enable_error(currentLuaIntf)
        return
    end
    enable_extension()
end

function on_click_save()
    --Verify the checkbox and set the config file
    if not cb_extraintf:get_checked() then
        vlc.config.set("lua-intf", "")
        cfg.general.speedup = "1"
        cfg.general.rate = "1"
        cfg.general.maxdiff = "5"
        save_config(cfg)
        vlc.deactivate()
        return
    end
    
    cfg.general.speedup = dd_speedup:get_text()
    cfg.general.rate = dd_rate:get_text()
    cfg.general.maxdiff = dd_maxdiff:get_text()
    save_config(cfg)
    dlg:hide()
end

---------------------------- Config management functions -------------------------------------------

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
    data.general.speedup = 1
    data.general.rate = 1
    data.general.maxdiff = 5
    data.status = {}
    data.status.enabled = true
    data.status.restarted = true
    return data
end
