-- LuaRocks
pcall(require, "luarocks.loader")

-- ライブラリを読み込む
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local menubar = require("menubar")
local icon_theme = require("menubar.icon_theme")
local hotkeys_popup = require("awful.hotkeys_popup")
local freedesktop = require("freedesktop")
require("awful.hotkeys_popup.keys")
local dpi = beautiful.xresources.apply_dpi
-- local os = require("os")

-- {{{ 起動時にエラーが発生したら表示
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- 起動したあとのエラーを表示
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- 無限ループにしない
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

awful.spawn("fcitx5")
awful.spawn("picom")

-- {{{ 変数の宣言
-- テーマの設定
beautiful.init("~/.config/awesome/themes/default/theme.lua")

awful.layout.layouts = {
    awful.layout.suit.floating
}

-- デフォルトのModキー
modkey = "Mod4"
-- }}}

-- 文字列の分割用
function split(str)
    local list = {}
    local i = 1
    for s in string.gmatch(str, "([^" .. "\n" .. "]+)") do
        list[i] = s
        i = i + 1
    end
    return list
end

-- デスクトップエントリの取得
local command = io.popen("ls /usr/share/applications | cat")
local list_string = command:read("*a")
command:close()
app_list = split(list_string)

entries = {}
for _, app in ipairs(app_list) do
    local entry = menubar.utils.parse_desktop_file("/usr/share/applications/" .. app)
    if entry ~= nil then
        if not entry.NoDisplay then
            table.insert(entries, entry)
        end
    end
end

-- デスクトップエントリのウィジェット
function appmenu_widget(icon, name, exec)
    local widget = wibox.widget {
        {
            {
                {
                    image = icon_theme():find_icon_path(icon, dpi(16)),
                    forced_width = dpi(16),
                    forced_height = dpi(16),
                    widget = wibox.widget.imagebox
                },
                {
                    text = name,
                    valign = "bottom",
                    widget = wibox.widget.textbox,
                },
                spacing = dpi(4),
                layout = wibox.layout.fixed.horizontal
            },
            top = dpi(4), bottom = dpi(4), left = dpi(6), right = dpi(6),
            widget = wibox.container.margin
        },
        id = "background_role",
        widget = wibox.container.background,
    }

    widget.pushed = false
    widget.set_color = function()
        widget.fg = "#ffffff"
        widget.bg = "#00000080"
    end
    widget.clear_color = function()
        widget.fg = "#000000"
        widget.bg = "#00000000"
    end
    widget:connect_signal("button::press", function()
        widget.pushed = mouse.coords().buttons[1]
        if mouse.coords().buttons[2] or mouse.coords().buttons[3] then
            appmenu_popup.visible = false
        end
    end)
    widget:connect_signal("button::release", function()
        if widget.pushed then
            awful.spawn(exec)
            appmenu_popup.visible = false
        end
        widget.pushed = false
    end)
    widget:connect_signal("mouse::enter", widget.set_color)
    widget:connect_signal("mouse::leave", widget.clear_color)

    return widget
end

-- デスクトップエントリのウィジェットを作成
entry_widgets = {}
for _, entry in ipairs(entries) do
    exec = entry.Exec
    string.gsub(exec, " %U", "")
    string.gsub(exec, " %F", "")
    table.insert(entry_widgets, appmenu_widget(entry.Icon, entry.Name, exec))
end

-- entry_widgets.spacing = dpi(4)
entry_widgets["layout"] = wibox.layout.fixed.vertical

appmenu_popup = awful.popup {
    widget = {
        entry_widgets,
        top = dpi(8),
        bottom = dpi(8),
        widget = wibox.container.margin
    },
    ontop = true,
    visible = false,
    y = dpi(32),
    border_width = 1,
    border_color = "#a0a0a0",
    bg = "#ffffff",
    fg = "#000000",
    shape = function(cr, width, height)
        gears.shape.partially_rounded_rect(cr, width, height, false, false, true, true, dpi(8))
    end
}

-- {{{ メニュー
-- メニューとランチャーの作成
myawesomemenu = {
   { "再起動", awesome.restart },
   { "終了", function() awesome.quit() end },
}

mymainmenu = freedesktop.menu.build({
    before = {
        { "Awesome", myawesomemenu, beautiful.awesome_icon }
    }
})

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- rofi = wibox.widget.imagebox("/home/minechan/.config/awesome/themes/default/rocket.svg")
-- rofi:buttons(awful.button({ }, 1, function()
--     awful.spawn("rofi -show drun")
--end))
rofi = wibox.widget {
    {
        {
            image = "/home/minechan/.config/awesome/themes/default/rocket.svg",
            widget = wibox.widget.imagebox
        },
        margins = dpi(4),
        widget = wibox.container.margin
    },
    id = "background_role",
    widget = wibox.container.background,
    shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(6))
    end
}

rofi.pushed = false
rofi.set_color = function()
    rofi.fg = "#ffffff"
    rofi.bg = "#00000080"
end
rofi.clear_color = function()
    rofi.fg = "#000000"
    rofi.bg = "#00000000"
end
rofi:connect_signal("button::press", function()
    rofi.pushed = mouse.coords().buttons[1]
    if rofi.pushed then
        rofi.set_color()
    end
end)
rofi:connect_signal("button::release", function()
    if rofi.pushed then
        -- awful.spawn("rofi -show drun")
        appmenu_popup.visible = not appmenu_popup.visible
    end
    rofi.pushed = false
    rofi.clear_color()
end)
rofi:connect_signal("mouse::enter", function()
    if not mouse.coords().buttons[1] then
        rofi.pushed = false
    end
    if rofi.pushed then
        rofi.set_color()
    end
end)
rofi:connect_signal("mouse::leave", rofi.clear_color)

-- メニューバーの設定
menubar.utils.terminal = "termite" -- 端末が必要なアプリ
-- }}}

-- {{{ Wibar
-- 時計のウィジェットを作成
mytextclock = wibox.widget {
    format = "%Y/%m/%d %H:%M",
    refresh = 1,
    font = "Noto Sans CJK JP 9",
    widget = wibox.widget.textclock
}
mytextclock:buttons(awful.button({ }, 1, function()
    calendar_popup.visible = not calendar_popup.visible
end))

-- カレンダー
calendar = wibox.widget {
    date = os.date('*t'),
    font = "Noto Sans CJK JP 8",
    start_sunday = true,
    widget = wibox.widget.calendar.month
}



calendar_popup = awful.popup {
    widget = {
        calendar,
        left = dpi(8), right = dpi(8), top = dpi(8), bottom = dpi(8), 
        widget = wibox.container.margin
    },
    ontop = true,
    visible = false,
    border_width = 1,
    border_color = "#a0a0a0",
    fg = "#000000",
    shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(8))
    end
}

-- セパレーター
separator = wibox.widget {
    {
        forced_width = dpi(8),
        thickness = 1,
        color = "#a0a0a0",
        widget = wibox.widget.separator
    },
    top = dpi(4), bottom = dpi(4),
    widget = wibox.container.margin
}

systray = wibox.widget {
    wibox.widget.systray(),
    top = dpi(2),
    bottom = dpi(2),
    widget = wibox.container.margin
}
-- systray:set_base_size(dpi(16))

-- タグリストのマウスのバインディング
local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                )

-- タスクリストのマウスのバインディング
local tasklist_buttons = gears.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  c:emit_signal(
                                                      "request::activate",
                                                      "tasklist",
                                                      {raise = true}
                                                  )
                                              end
                                          end),
                     awful.button({ }, 3, function()
                                              awful.menu.client_list({ theme = { width = 250 } })
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))

-- 壁紙
local function set_wallpaper(s)
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
        -- gears.wallpaper.set("#d7d2cf")
    end
end

-- スクリーンのジオメトリが変更されたときに壁紙を更新
screen.connect_signal("property::geometry", set_wallpaper)

-- スクリーンごとの処理
awful.screen.connect_for_each_screen(function(s)
    -- 壁紙
    set_wallpaper(s)

    -- タグ
    awful.tag({ "1", "2", "3", "4"}, s, awful.layout.suit.floating)

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()

    -- タグリストのウィジェットを作成
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        -- buttons = taglist_buttons,
        style = {
            shape = function(cr, width, height)
                gears.shape.rounded_rect(cr, width, height, dpi(6))
            end,
            bg_focus = "#00000020",
        },
        layout = {
            spacing = dpi(4),
            layout = wibox.layout.fixed.horizontal
        },

        widget_template = {
            {
                {
                    {
                        id = "text_role",
                        widget = wibox.widget.textbox
                    },
                    left = dpi(7),
                    right = dpi(7),
                    widget = wibox.container.margin
                }, 
                layout = wibox.layout.fixed.horizontal
            },
            id = "background_role",
            widget = wibox.container.background,
            create_callback = function(self, t, index, tags)
                self.pushed = false
                self.set_color = function()
                    self.fg = "#ffffff"
                    self.bg = "#00000080"
                end
                self.clear_color = function()
                    self.fg = "#000000"
                    self.bg = "#000000" .. (t.selected and "20" or "00")
                end
                self:connect_signal("button::press", function()
                    self.pushed = mouse.coords().buttons[1]
                    if self.pushed then
                        self.set_color()
                    end
                end)
                self:connect_signal("button::release", function()
                    if self.pushed then
                        t:view_only()
                    end
                    self.pushed = false
                    self.clear_color()
                end)
                self:connect_signal("mouse::enter", function()
                    if not mouse.coords().buttons[1] then
                        self.pushed = false
                    end
                    if self.pushed then
                        self.set_color()
                    end
                end)
                self:connect_signal("mouse::leave", self.clear_color)
            end
        }
    }

    -- タスクリストのウィジェットを作成
    -- s.mytasklist = awful.widget.tasklist {
    --     screen  = s,
    --     filter  = awful.widget.tasklist.filter.currenttags,
    --     buttons = tasklist_buttons
    -- }
    s.mytasklist = awful.widget.tasklist {
        screen = s,
        filter = awful.widget.tasklist.filter.currenttags, 
        -- buttons = tasklist_buttons,
        style = {
            shape = function(cr, width, height)
                gears.shape.rounded_rect(cr, width, height, dpi(6))
            end,
            bg_normal = "#00000000",
            bg_minimize = "#00000000",
            bg_focus = "#00000020",
            fg_normal = "#000000",
            fg_minimize = "#000000",
            font_focus = "Noto Sans CJK JP Bold 9",
            plain_task_name = true
        }, 
        layout = {
            spacing = dpi(4),
            layout = wibox.layout.flex.horizontal,
            max_widget_size = dpi(200)
        }, 
    
        widget_template = {
            {
                {
                    {
                        id = "desktopicon",
                        widget = wibox.widget.imagebox
                    },
                    {
                        id = "text_role",
                        -- forced_width = dpi(150),
                        valign = "bottom",
                        widget = wibox.widget.textbox
                    },
                    spacing = dpi(4),
                    layout = wibox.layout.fixed.horizontal
                },
                margins = dpi(4),
                widget = wibox.container.margin
            },
            id = "background_role",
            widget = wibox.container.background,
            create_callback = function(self, c, index, clients)
                self:get_children_by_id("desktopicon")[1].image = c.icon
                self.pushed = false
                self.set_color = function()
                    self.fg = "#ffffff"
                    self.bg = "#00000080"
                end
                self.clear_color = function()
                    self.fg = "#000000"
                    self.bg = "#000000" .. (c == client.focus and "20" or "00")
                end
                self:connect_signal("button::press", function()
                    self.pushed = mouse.coords().buttons[1]
                    if self.pushed then
                        self.set_color()
                    end
                end)
                self:connect_signal("button::release", function()
                    if self.pushed then
                        if c == client.focus then
                            c.minimized = true
                        else
                            c:emit_signal("request::activate", "tasklist", {raise = true})
                        end
                    end
                    self.pushed = false
                    self.clear_color()
                end)
                self:connect_signal("mouse::enter", function()
                    if not mouse.coords().buttons[1] then
                        self.pushed = false
                    end
                    if self.pushed then
                        self.set_color()
                    end
                end)
                self:connect_signal("mouse::leave", self.clear_color)
            end
        }
    }

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s, border_width = 1, border_color = "#a0a0a0", fg="#000000", height = dpi(32), ontop = true })

    -- Add widgets to the wibox
    s.mywibox:setup {
        {
            layout = wibox.layout.align.horizontal,
            spacing = dpi(8),
            { -- Left widgets
                layout = wibox.layout.fixed.horizontal,
                -- mylauncher,
                rofi,
                separator,
                s.mytaglist,
                separator
            },
            s.mytasklist, -- Middle widget
            { -- Right widgets
                layout = wibox.layout.fixed.horizontal,
                separator,
                systray,
                separator,
                mytextclock,
            }
        },
        margins = dpi(4),
        widget = wibox.container.margin
    }
end)
-- }}}

function get_corner(mouse_x, mouse_y, client_x, client_y, client_width, client_height, border_width)
    local area_x = 0
    local area_y = 0

    local area_name = {"top_left", "top", "top_right",
                       "left", "", "right",
                       "bottom_left", "bottom", "bottom_right"}

    -- Y座標
    if client_y + client_height + border_width <= mouse_y then
        -- 下のボーダーより下
        area_y = 4
    elseif client_y + client_height <= mouse_y then
        -- 下のボーダーの中
        area_y = 3
    elseif client_y <= mouse_y then
        -- クライアントの中
        area_y = 2
    elseif client_y - border_width <= mouse_y then
        -- 上のボーダーの中
        area_y = 1
    else
        -- 上のボーダーより上
        area_y = 0
    end

    -- X座標
    if client_x + client_width + border_width <= mouse_x then
        -- 右のボーダーより右
        area_x = 4
    elseif client_x + client_width <= mouse_x then
        -- 右のボーダーの中
        area_x = 3
    elseif client_x <= mouse_x then
        -- クライアントの中
        area_x = 2
    elseif client_x - border_width <= mouse_x then
        -- 左のボーダーの中
        area_x = 1
    else
        -- 左のボーダーより左
        area_x = 0
    end

    if 1 <= area_x and area_x <= 3 and 1 <= area_y and area_y <= 3 then
        return area_name[3 * (area_y - 1) + area_x]
    else
        return ""
    end
end

-- サイズ変更用の変数
resize_client = nil
pos1_x = nil
pos1_y = nil
pos2_x = nil
pos3_y = nil
mouse_prev_x = nil
mouse_prev_y = nil
resize_corner = nil
titlebar_height = dpi(28)

function init_resize_client()
    local pos = mouse.coords()
    for _, c in ipairs(client.get(mouse.screen, true)) do
        if c.minimized == false and c.hidden == false then
            local selected = false
            for _, t in ipairs(c:tags()) do
                selected = t.selected or selected
            end
            if selected then
                local corner = get_corner(pos.x, pos.y, c.x, c.y, c.width, c.height, 24)
                if corner ~= "" then
                    c:emit_signal("request::activate", "mouse_click", {raise = true})
                    -- サイズ変更の処理
                    resize_client = c
                    pos1_x = c.x + c.border_width
                    pos1_y = c.y + c.border_width
                    pos2_x = c.x + c.width
                    pos2_y = c.y + c.height
                    mouse_prev_x = pos.x
                    mouse_prev_y = pos.y
                    resize_corner = corner
                    mousegrabber.run(function(cursor) return resize_client_main(cursor) end, corner .. (string.find(corner, "_") and "_corner" or "_side"))
                    return true
                end
            end
        end
    end
    return false
end

-- サイズ変更の処理
function resize_client_main(cursor)
    -- マウスの差
    local delta_x = cursor.x - mouse_prev_x
    local delta_y = cursor.y - mouse_prev_y

    -- 仮のX軸のサイズ変更
    if string.find(resize_corner, "left") then
        pos1_x = pos1_x + delta_x
    elseif string.find(resize_corner, "right") then
        pos2_x = pos2_x + delta_x
    end
    -- 仮のY軸のサイズ変更
    if string.find(resize_corner, "top") then
        pos1_y = pos1_y + delta_y
    elseif string.find(resize_corner, "bottom") then
        pos2_y = pos2_y + delta_y
    end

    -- 仮のサイズ
    local temp_width = pos2_x - pos1_x + resize_client.border_width
    local temp_height = pos2_y - pos1_y + resize_client.border_width
    local min_width = resize_client.size_hints.min_width or 1
    local min_height = (resize_client.size_hints.min_height or 1) + titlebar_height
    local max_width = resize_client.size_hints.max_width and resize_client.size_hints.max_width or 2147483647
    local max_height = resize_client.size_hints.max_width and (resize_client.size_hints.max_width + titlebar_height) or 2147483647

    -- 幅と高さの変更
    resize_client.width = math.min(math.max(temp_width, min_width), max_width)
    resize_client.height = math.min(math.max(temp_height, min_height), max_height)

    -- X座標の変更
    if string.find(resize_corner, "left") then
        if temp_width > max_width then
            -- 仮の幅が最大幅より大きかったら
            resize_client.x = pos2_x - max_width
        elseif temp_width >= min_width then
            -- 範囲内なら
            resize_client.x = pos2_x - resize_client.width
        else
            -- 最小幅より小さかったら
            resize_client.x = pos2_x - min_width
        end
    end
    -- Y座標の変更
    if string.find(resize_corner, "top") then
        if temp_height > max_height then
            -- 仮の幅が最大幅より大きかったら
            resize_client.y = pos2_y - max_height
        elseif temp_height >= min_height then
            -- 範囲内なら
            resize_client.y = pos2_y - resize_client.height
        else
            -- 最小幅より小さかったら
            resize_client.y = pos2_y - min_height
        end
    end

    -- 終了
    mouse_prev_x = cursor.x
    mouse_prev_y = cursor.y
    return mouse.coords().buttons[1]
end

-- {{{ ルートのマウスのバインディング
root.buttons(gears.table.join(
    awful.button({ }, 1, function ()
        mymainmenu:hide()

        init_resize_client()
    end),
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"}),
    -- Menubar
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 4 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

-- クライアントのマウスのバインド
clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        if c ~= client.focus then
            if not init_resize_client() then
                c:emit_signal("request::activate", "mouse_click", {raise = true})
            end
        end
        -- c:emit_signal("request::activate", "mouse_click", {raise = true})
        -- resize_client()
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen
     }
    },

    -- Floating clients.
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
          "pinentry",
        },
        class = {
          "Arandr",
          "Blueman-manager",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Sxiv",
          "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
          "Wpa_gui",
          "veromix",
          "xtightvncviewer"},

        -- Note that the name property shown in xprop might be set slightly after creation of the client
        -- and the name shown there might not match defined rules here.
        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "ConfigManager",  -- Thunderbird's about:config.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = true }
    },

    -- {rule = {class = "Vivaldi-stable"},
    --  properties = {titlebars_enabled = false}}

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}
-- }}}

-- {{{ シグナル
-- 新しいクライアントが作成されたときのシグナルのハンドラ
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end
    -- if c.class == "Termite" then
        -- c.border_color = "#606060"
    -- end

    c.border_width = 1

    c.shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(12))
    end

    if c.floating then
        c.placement = awful.placement.centered
    end

    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- titlebars_enabledがセットされているならタイトルバーを作成
client.connect_signal("request::titlebars", function(c)
    if c.requests_no_titlebar then
        return
    end

    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end)
    )

    hints = c.size_hints
    -- class_lower = string.lower(c.class)

    awful.titlebar(c, {size = titlebar_height-- ,
        -- bg_normal = c.class == "Termite" and "#202020cc" or "#e0e0e0",
        -- bg_focus = c.class == "Termite" and "#202020cc" or "#e0e0e0",
        -- fg_focus = c.class == "Termite" and "#ffffff" or "#000000"
        -- bg_focus = {
        --     type = "linear",
        --     from = {0, 0},
        --     to = {0, dpi(24)},
        --     stops = {{0, "#e0e0e0"}, {1, "#c0c0c0"}}
        -- }
    }) : setup {
        { -- Left
            {
                awful.titlebar.widget.closebutton(c),
                awful.titlebar.widget.minimizebutton(c),
                awful.titlebar.widget.maximizedbutton(c),
                spacing = dpi(6),
                layout  = wibox.layout.fixed.horizontal,
            },
            top = dpi(7), bottom = dpi(7), left = dpi(10), right = dpi(10),
            -- top = dpi(17), bottom = dpi(17), left = dpi(15),
            widget = wibox.container.margin
        },
        { -- Middle
            {
                {
                    font = "Noto Sans CJK JP Bold 9",
                    align = "center",
                    widget = awful.titlebar.widget.titlewidget(c),
                },
                layout  = wibox.layout.flex.horizontal
            },
            right = dpi(10),
            widget = wibox.container.margin,
            buttons = buttons
        },
        nil,
        layout = wibox.layout.align.horizontal,
    }
end)
