{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.queezle.sway;
  temperature-bin = pkgs.writeScript "temperature.zsh" ''
    #!/usr/bin/env zsh

    echo -n $'🔥\uFE0E '

    result=$(sensors -j | jq --join-output '."coretemp-isa-0000"."Package id 0".temp1_input // ."k10temp-pci-00c3".Tctl.temp1_input // ."cpu0_thermal-virtual-0".temp1.temp1_input | tonumber | floor')
    if [[ -n $result ]]
    then
      print "$result°C"
      exit 0
    fi

    exit 42
  '';
in
pkgs.writeText "sway-config" ''
# sway config file

set $mod Mod4

set $base00 #1d1f21
set $base01 #282a2e
set $base02 #373b41
set $base03 #969896
set $base04 #b4b7b4
set $base05 #c5c8c6
set $base06 #e0e0e0
set $base07 #ffffff
set $base08 #cc6666
set $base09 #de935f
set $base0A #f0c674
set $base0B #b5bd68
set $base0C #8abeb7
set $base0D #81a2be
set $base0E #b294bb
set $base0F #a3685a

set $active #51c9ff

set $wallpaper ${config.queezle.sway.wallpaper}
set $lockscreen ${config.queezle.sway.lockscreen}

set $terminal terminal
set $terminal2 terminal2

set $workspace_q 0:q
set $workspace_messaging 11:msg
set $workspace_telegram 12:t
set $workspace_music 13:music

input * {
  xkb_layout de
  xkb_variant nodeadkeys
  xkb_numlock enable
  xkb_options caps:escape_shifted_capslock
}

input 7805:12850:ROCCAT_ROCCAT_Ryos_MK_Pro {
  xkb_variant ""
  xkb_layout us
}

input 2:7:SynPS/2_Synaptics_TouchPad {
  tap enabled
  natural_scroll enabled
}

input 1739:5841:SYNA7501:00_06CB:16D1 {
  map_to_output eDP-1
}

output * {
  scale 1
}

output eDP-1 {
  pos 0 0
}

output * bg $wallpaper fill

# Background processes

exec PROMPT_NO_INITIAL_NEWLINE=1 foot --server

exec mako
#exec CM_SELECTIONS=clipboard clipmenud
#exec nm-applet --indicator

exec gammastep

exec squeekboard

# Fix XWayland DPI
exec xrdb -load ~/.Xresources

#workspace_auto_back_and_forth yes

hide_edge_borders both
smart_gaps off
#gaps inner 10

# The window under the cursor will always be focused, even after switching between workspaces.
focus_follows_mouse always

focus_wrapping yes

for_window [class=qutebrowser] border pixel

for_window [class="Vncviewer"] fullscreen enable

# sway
bindsym $mod+n bar mode toggle

# notification controls
bindsym Ctrl+Shift+Space exec makoctl dismiss

# screen controls
bindsym $mod+F10 output eDP-1 enable
bindsym $mod+Shift+F10 output eDP-1 disable

# clipmenu
bindsym $mod+plus exec CM_LAUNCHER=rofi CM_HISTLENGTH=15 clipmenu -p clipboard

# pass
#bindsym $mod+numbersign exec passmenu && sleep 0.1 && clipdel -d ".*" && sleep 1 && clipdel -d ".*"

# lock
bindsym Print exec swaylock-with-idle -i $lockscreen
bindsym Shift+Print exec swaylock -c 00000000
#bindsym Shift+Print exec ~/run/lock/winlock
#bindsym Ctrl+Print exec ~/run/lock/blurlock

# screenshot
bindsym Ctrl+Print exec grim -g "$(slurp -o)"
bindsym Ctrl+Shift+Print exec grim -g "$(slurp)"

# suspend
bindsym $mod+Print exec systemctl suspend
${if cfg.autoLockBeforeSuspend then ''exec swayidle -w before-sleep "swaylock -f -i $lockscreen"'' else ""}

# subraum
#bindsym $mod+Delete exec ~/run/subraum/hackbuzzer
#bindsym $mod+Shift+Delete exec ~/run/edi/sob hackbuzzer

#bindsym $mod+Delete exec mosquitto_pub -h blinky.subraum.c3pb.de -t illuminati/anim -m sparkle && sleep 3s && mosquitto_pub -h blinky.subraum.c3pb.de -t illuminati/anim -m bubblegum
#bindsym $mod+Shift+Delete exec mosquitto_pub -h blinky.subraum.c3pb.de -t device/matryx/fullHour -m 1 && mosquitto_pub -h blinky.subraum.c3pb.de -t illuminati/anim -m rgb && sleep 3s && mosquitto_pub -h blinky.subraum.c3pb.de -t illuminati/anim -m bubblegum

# macro keys (bound to F14-F18, which is received as XF86Launch5-XF86Launch9)
bindsym XF86Launch5 exec mosquitto_pub -h 10.0.2.1 -t component/G815/key/G1 -m G1
bindsym XF86Launch6 exec mosquitto_pub -h 10.0.2.1 -t component/G815/key/G2 -m G2
bindsym XF86Launch7 exec mosquitto_pub -h 10.0.2.1 -t component/G815/key/G3 -m G3
bindsym XF86Launch8 exec mosquitto_pub -h 10.0.2.1 -t component/G815/key/G4 -m G4
bindsym XF86Launch9 exec mosquitto_pub -h 10.0.2.1 -t component/G815/key/G5 -m G5

# audio volume
set $audioRaiseVolume "pamixer --unmute --increase 1"
set $audioLowerVolume "pamixer --unmute --decrease 1"
set $audioRaiseVolume5 "pamixer --unmute --increase 5"
set $audioLowerVolume5 "pamixer --unmute --decrease 5"
set $audioToggleMute "pamixer --toggle-mute"
bindsym --locked XF86AudioRaiseVolume exec $audioRaiseVolume
bindsym --locked XF86AudioLowerVolume exec $audioLowerVolume
bindsym --locked Shift+XF86AudioRaiseVolume exec $audioRaiseVolume5
bindsym --locked Shift+XF86AudioLowerVolume exec $audioLowerVolume5
bindsym --locked XF86AudioMute exec $audioToggleMute

# music player control
bindsym --locked $mod+F1 exec "playerctl --player=%any,chromium play-pause"
bindsym --locked $mod+F2 exec "playerctl --player=%any,chromium previous"
bindsym --locked $mod+F3 exec "playerctl --player=%any,chromium next"
bindsym --locked XF86AudioPlay exec "playerctl --player=%any,chromium play-pause"
bindsym --locked XF86AudioStop exec "playerctl --player=%any,chromium stop"
bindsym --locked XF86AudioPrev exec "playerctl --player=%any,chromium previous"
bindsym --locked XF86AudioNext exec "playerctl --player=%any,chromium next"

# brightness
set $brightnessUp "xbacklight -fps 60 -inc 5"
set $brightnessUpSmall "xbacklight -fps 60 -inc 1"
set $brightnessDown "xbacklight -fps 60 -dec 5"
set $brightnessDownSmall "xbacklight -fps 60 -dec 1"
set $brightnessFull "xbacklight -fps 60 -set 100"
set $brightnessBright "xbacklight -fps 60 -set 50"
set $brightnessNormal "xbacklight -fps 60 -set 20"
set $brightnessDark "xbacklight -fps 60 -set 5"
set $brightnessVeryDark "xbacklight -fps 60 -set 2"
bindsym --locked XF86MonBrightnessDown exec $brightnessDown
bindsym --locked Shift+XF86MonBrightnessDown exec $brightnessDownSmall
bindsym --locked $mod+F11 exec $brightnessDark
bindsym --locked $mod+Shift+F11 exec $brightnessVeryDark
bindsym --locked XF86MonBrightnessUp exec $brightnessUp
bindsym --locked Shift+XF86MonBrightnessUp exec $brightnessUpSmall
bindsym --locked $mod+F12 exec $brightnessNormal
bindsym --locked $mod+Shift+F12 exec $brightnessBright
bindsym --locked $mod+Ctrl+F12 exec $brightnessFull

# Toggle mumble mute
# TODO: merge with mumble config (requires sway config merging)
bindsym --locked Pause exec ~/.local/bin/mumble-toggle-mute

# The middle button over a titlebar kills the window
bindsym button2 kill

# Font for window titles. Will also be used by the bar unless a different font
# is used in the bar {} block below.
#font pango:monospace 8
font PragmataPro Liga 10

# This font is widely installed, provides lots of unicode glyphs, right-to-left
# text rendering and scalability on retina/hidpi displays (thanks to pango).
#font pango:DejaVu Sans Mono 8

# Before i3 v4.8, we used to recommend this one as the default:
# font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1
# The font above is very space-efficient, that is, it looks good, sharp and
# clear in small sizes. However, its unicode glyph coverage is limited, the old
# X core fonts rendering does not support right-to-left and this being a bitmap
# font, it doesn’t scale on retina/hidpi displays.

# Use Mouse+$mod to drag floating windows to their wanted position
floating_modifier $mod

# q
bindsym $mod+asciicircum workspace $workspace_q
bindsym $mod+Shift+asciicircum move container to workspace $workspace_q

# start a terminal
bindsym $mod+Return exec $terminal
bindsym $mod+Shift+Return exec cool-retro-term --fullscreen --profile "Monochrome Green"
bindsym $mod+Alt+Return exec $terminal2

# start program launcher
bindsym $mod+Tab exec launcher
#bindsym $mod+Tab exec rofi -show drun
#bindsym $mod+Mod1+Tab exec rofi -show run

# start an edi shell
#bindsym $mod+o exec cool-retro-term --fullscreen --profile "Default Amber" -e run/edi/edish/edish
bindsym $mod+o exec cool-retro-term --fullscreen --profile "Default Amber" -e ssh edi

# start a python terminal
bindsym $mod+p exec $terminal python

# start an haskel ghci terminal (TODO)
bindsym $mod+Shift+p exec $terminal stack ghci --verbosity warning

# start a browser
bindsym $mod+b exec "chromium --enable-features=WebRTCPipeWireCapturer --force-dark-mode"
# Ozone might work only when $DISPLAY is not set
#bindsym $mod+b exec "chromium --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer --ozone-platform=wayland --force-dark-mode"
#bindsym $mod+Shift+b exec qutebrowser

# start htop
bindsym $mod+Escape exec $terminal htop

# Messaging workspace / open matrix client
bindsym $mod+i workspace $workspace_messaging
bindsym $mod+Shift+i move container to workspace $workspace_messaging
bindsym $mod+Ctrl+i workspace $workspace_messaging; exec chromium --app=https://element.queezle.net/

# start telegram
bindsym $mod+t workspace $workspace_telegram
bindsym $mod+Ctrl+t workspace $workspace_telegram; exec telegram-desktop

# music player workspace
bindsym $mod+m workspace $workspace_music
bindsym $mod+Shift+m move container to workspace $workspace_music
# start spotify instead of mopidy web interface while mopidy is broken
#bindsym $mod+Ctrl+m workspace $workspace_music; exec chromium --app=http://stargate:6680/iris/#/
bindsym $mod+Ctrl+m workspace $workspace_music; exec spotify
bindsym $mod+Alt+m exec $terminal pulsemixer
#bindsym $mod+Ctrl+m workspace $workspace_music; exec ~/run/spotify-singleton

# scratchpad
bindsym $mod+y scratchpad show
bindsym $mod+Shift+y move scratchpad

# kill focused window
bindsym $mod+q kill
bindsym $mod+Shift+q kill

# change focus
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

# alternatively, you can use the cursor keys:
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# move focused window
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

# alternatively, you can use the cursor keys:
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

bindsym $mod+Alt+Shift+h move workspace to output left
bindsym $mod+Alt+Shift+j move workspace to output down
bindsym $mod+Alt+Shift+k move workspace to output up
bindsym $mod+Alt+Shift+l move workspace to output right
bindsym $mod+Alt+Shift+Left move workspace to output left
bindsym $mod+Alt+Shift+Down move workspace to output down
bindsym $mod+Alt+Shift+Up move workspace to output up
bindsym $mod+Alt+Shift+Right move workspace to output right

# split in horizontal orientation
bindsym $mod+c split h

# split in vertical orientation
bindsym $mod+v split v

# enter fullscreen mode for the focused container
bindsym $mod+f fullscreen toggle

# change container layout (stacked, tabbed, toggle split)
bindsym $mod+s layout stacking
#bindsym $mod+w layout tabbed
bindsym $mod+x layout toggle split

# toggle tiling / floating
bindsym $mod+Shift+space floating toggle

# change focus between tiling / floating windows
bindsym $mod+space focus mode_toggle

# focus the parent container
bindsym $mod+a focus parent

# focus the child container
bindsym $mod+d focus child

# switch to workspace
bindsym $mod+Ctrl+h workspace prev_on_output
bindsym $mod+Ctrl+k workspace prev_on_output
bindsym $mod+Ctrl+j workspace next_on_output
bindsym $mod+Ctrl+l workspace next_on_output
bindsym $mod+1 workspace 1
bindsym $mod+2 workspace 2
bindsym $mod+3 workspace 3
bindsym $mod+4 workspace 4
bindsym $mod+5 workspace 5
bindsym $mod+6 workspace 6
bindsym $mod+7 workspace 7
bindsym $mod+8 workspace 8
bindsym $mod+9 workspace 9
bindsym $mod+0 workspace 10

# move focused container to workspace
bindsym $mod+Ctrl+Shift+h move container to workspace prev_on_output
bindsym $mod+Ctrl+Shift+l move container to workspace next_on_output
bindsym $mod+Shift+1 move container to workspace 1
bindsym $mod+Shift+2 move container to workspace 2
bindsym $mod+Shift+3 move container to workspace 3
bindsym $mod+Shift+4 move container to workspace 4
bindsym $mod+Shift+5 move container to workspace 5
bindsym $mod+Shift+6 move container to workspace 6
bindsym $mod+Shift+7 move container to workspace 7
bindsym $mod+Shift+8 move container to workspace 8
bindsym $mod+Shift+9 move container to workspace 9
bindsym $mod+Shift+0 move container to workspace 10

# reload the configuration file
bindsym $mod+Shift+c reload
# restart i3 inplace (preserves your layout/session, can be used to upgrade i3)
bindsym $mod+Shift+r restart
# exit sway (logs you out of your Wayland session)
# bindsym $mod+Shift+e exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'
bindsym $mod+Shift+e exec "swaymsg exit"

# resize window (you can also use the mouse for that)
mode "resize" {
        # These bindings trigger as soon as you enter the resize mode

        # Pressing left will shrink the window’s width.
        # Pressing right will grow the window’s width.
        # Pressing up will shrink the window’s height.
        # Pressing down will grow the window’s height.
        bindsym h resize shrink width 10 px or 10 ppt
        bindsym j resize shrink height 10 px or 10 ppt
        bindsym k resize grow height 10 px or 10 ppt
        bindsym l resize grow width 10 px or 10 ppt

        # same bindings, but for the arrow keys
        bindsym Left resize shrink width 10 px or 10 ppt
        bindsym Down resize shrink height 10 px or 10 ppt
        bindsym Up resize grow height 10 px or 10 ppt
        bindsym Right resize grow width 10 px or 10 ppt

        # back to normal: Enter or Escape
        bindsym Return mode "default"
        bindsym Escape mode "default"
}

bindsym $mod+r mode "resize"


# marks POC
#set $goto_mark "goto mark"
set $set_mark "set mark"

mode $goto_mark {
	bindsym a [con_mark=a] focus; mode "default"
	bindsym b [con_mark=b] focus; mode "default"
	bindsym c [con_mark=c] focus; mode "default"

        # back to normal: Enter or Escape
        bindsym Return mode "default"
        bindsym Escape mode "default"
}

mode $set_mark {
	bindsym a mark a; mode "default"
	bindsym b mark b; mode "default"
	bindsym c mark c; mode "default"

        # back to normal: Enter or Escape
        bindsym Return mode "default"
        bindsym Escape mode "default"
}

bindsym $mod+apostrophe mode $goto_mark
bindsym $mod+grave mode $goto_mark
bindsym $mod+acute mode $goto_mark

# Keybinding is in conflict with pulsemixer keybinding
#bindsym $mod+Alt+m mode $set_mark

# experimental multi-level menu

set $super_mode "super"

mode $super_mode {
	bindsym m mode $set_mark
	bindsym apostrophe mode $goto_mark
	bindsym grave mode $goto_mark
	bindsym acute mode $goto_mark

        #bindsym Return exec $terminal; mode "default"
        bindsym Return mode "default"
        bindsym Escape mode "default"

	# Exit by pressing super again. This allows the usage of $mod+key keybindings while exiting the mode
	bindsym Super_L mode "default"
}

#bindsym --release Super_L mode $super_mode


# Basic color configuration using the Base16 variables for windows and borders.
# Property Name         Border  BG      Text    Indicator Child Border
client.focused          $base01 $base01 $active $active $base01
client.focused_inactive $base00 $base00 $base05 $base03 $base01
client.unfocused        $base00 $base00 $base03 $base01 $base00
client.urgent           $base00 $base0A $base00 $base09 $base09
client.placeholder      $base00 $base00 $base05 $base00 $base00
client.background       $base00

bar {
  status_command qbar server swaybar date squeekboard --auto-hide battery cpu script --poll ~/.config/qbar/blocks/memory script --poll ${temperature-bin} disk / ${if config.networking.networkmanager.enable then "networkmanager" else ""}

  id bar-0
  position top
  strip_workspace_numbers yes
  colors {
    background $base00
    separator  $base01
    statusline $base04

    # State             Border  BG      Text
    focused_workspace   $active $base01 $base05
    active_workspace    $base05 $base03 $base00
    inactive_workspace  $base01 $base01 $base05
    urgent_workspace    $base09 $base0A $base00
    binding_mode        $base00 $base0D $base00
  }
  bindsym button4 nop
  bindsym button5 nop
}

include local

include /etc/sway/config.d/*
''
