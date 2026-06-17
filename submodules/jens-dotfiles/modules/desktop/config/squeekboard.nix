{ lib, pkgs, config, ... }:
with lib;
pkgs.writeText "squeekboard-terminal.yaml" ''
---
outlines:
    default: { width: 35.33, height: 46 }
    action:  { width: 50,    height: 46 }
    altline: { width: 52.67, height: 46 }
    wide: { width: 59, height: 46 }
    spaceline: { width: 140, height: 46 }
    special: { width: 44, height: 46 }
    small: { width: 59, height: 30 }

views:
    base:
        - "Ctrl Super Alt small/ tab_small Esc_small"
        - "q w e r t z u i o p"
        - "a s d f g h j k l -"
        - "Shift_L y x c v b n m BackSpace"
        - "show_numbers show_symbols space period Return"
    upper:
        - "Ctrl Super Alt small? tab_small Esc_small"
        - "Q W E R T Z U I O P"
        - "A S D F G H J K L _"
        - "Shift_L Y X C V B N M BackSpace"
        - "show_numbers preferences space colon Return"
    numbers:
        - "Esc_small show_actions_small Ctrl tab_small Alt smallBS"
        - "~ @ # = 1 2 3 * ' \""
        - "` ! % $ 4 5 6 + ( )"
        - "\\ | colon & 7 8 9 0 period"
        - "show_letters show_symbols space comma Return"
    symbols:
        - "Ctrl Alt ← ↓ ↑ →"
        - "~ ` | · √ π τ { } ¶"
        - "© ® £ € ¥ ^ ° [ ] @"
        - "show_numbers_from_symbols \\ % ÷ × = < > BackSpace"
        - "show_letters preferences space semicolon Return"
    actions:
        - "menu_small Ctrl tab_small Alt Insert smallBS"
        - "Esc F1  F2  F3 Break  Up  Del"
        - "Pause F4  F5  F6  Left Down Right"
        - "F7 F8 F9 F10 PgUp Home Return"
        - "show_letters preferences F11 F12 PgDn End Shift_Fun"
    shiftable_actions:
        - "menu_small Ctrl tab_small Alt Insert smallBS"
        - "Esc F1  F2  F3 Break  Up  Del"
        - "Pause F4  F5  F6  Left Down Right"
        - "F7 F8 F9 F10 PgUp Home Return"
        - "show_letters preferences F11 F12 PgDn End Shift_Fun"

buttons:
    Shift_L:
        action:
            locking:
                lock_view: "upper"
                unlock_view: "base"
        outline: "altline"
        icon: "key-shift"
    Shift_Fun:
        action:
            locking:
                lock_view: "shiftable_actions"
                unlock_view: "actions"
        outline: "altline"
        icon: "key-shift"
    smallBS:
        outline: "small"
        icon: "edit-clear-symbolic"
        action: erase
    BackSpace:
        outline: "altline"
        icon: "edit-clear-symbolic"
        action: erase
    preferences:
        action: "show_prefs"
        outline: "special"
        icon: "keyboard-mode-symbolic"
    show_numbers:
        action:
            set_view: "numbers"
        outline: "wide"
        label: "123"
    show_numbers_from_symbols:
        action:
            set_view: "numbers"
        outline: "altline"
        label: "123"
    show_letters:
        action:
            set_view: "base"
        outline: "wide"
        label: "ABC"
    show_symbols:
        action:
            set_view: "symbols"
        outline: "altline"
        label: "τ=\\"
    show_actions_small:
        action:
            set_view: "actions"
        outline: "small"
        label: "Fx"
    show_actions:
        action:
            set_view: "actions"
        outline: "altline"
        label: ">_"
    period:
        outline: "altline"
        text: "."
    greater_than:
        outline: "altline"
        text: ">"
    comma:
        outline: "altline"
        text: ","
    space:
        outline: "spaceline"
        text: " "
    Return:
        outline: "wide"
        icon: "key-enter"
        keysym: "Return"
    colon:
        text: ":"
    semicolon:
        outline: "altline"
        text: ";"
    F1:
        outline: "action"
        keysym: "F1"
    F2:
        outline: "action"
        keysym: "F2"
    F3:
        outline: "action"
        keysym: "F3"
    F4:
        outline: "action"
        keysym: "F4"
    F5:
        outline: "action"
        keysym: "F5"
    F6:
        outline: "action"
        keysym: "F6"
    F7:
        outline: "action"
        keysym: "F7"
    F8:
        outline: "action"
        keysym: "F8"
    F9:
        outline: "action"
        keysym: "F9"
    F10:
        outline: "action"
        keysym: "F10"
    F11:
        outline: "action"
        keysym: "F11"
    F12:
        outline: "action"
        keysym: "F12"
    Esc:
        outline: "action"
        keysym: "Escape"
    Esc_small:
        outline: "small"
        label: "Esc"
        keysym: "Escape"
    tab_small:
        outline: "small"
        label: "Tab"
        keysym: "Tab"
    Tab:
        outline: "action"
        keysym: "Tab"
    Del:
        outline: "action"
        keysym: "Delete"
    Insert:
        outline: "small"
        keysym: "Insert"
    menu_small:
        outline: "small"
        label: "Menu"
        keysym: "Menu"
    Pause:
        outline: "action"
        label: "Pau"
        keysym: "Pause"
    Break:
        outline: "action"
        label: "Brk"
        keysym: "Break"
    Home:
        outline: "action"
        label: "Hm"
        keysym: "Home"
    End:
        outline: "action"
        keysym: "End"
    PgUp:
        outline: "action"
        label: "Pg↑"
        keysym: "Page_Up"
    PgDn:
        outline: "action"
        label: "Pg↓"
        keysym: "Page_Down"
    small-:
        outline: "small"
        text: "-"
    small_:
        outline: "small"
        text: "_"
    small.:
        outline: "small"
        text: "."
    small/:
        outline: "small"
        text: "/"
    small?:
        outline: "small"
        text: "?"
    "↑":
        outline: "small"
        keysym: "Up"
    "↓":
        outline: "small"
        keysym: "Down"
    "←":
        outline: "small"
        keysym: "Left"
    "→":
        outline: "small"
        keysym: "Right"
    Up:
        label: "↑"
        outline: "action"
        keysym: "Up"
    Left:
        label: "←"
        outline: "action"
        keysym: "Left"
    Down:
        label: "↓"
        outline: "action"
        keysym: "Down"
    Right:
        label: "→"
        outline: "action"
        keysym: "Right"
    Ctrl:
        modifier: "Control"
        outline: "small"
        label: "Ctrl"
    Super:
        modifier: "Mod4"
        outline: "small"
        label: "Super"
    Alt:
        modifier: "Alt"
        outline: "small"
        label: "Alt"
''
