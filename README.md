# KeyToggles
An AutoHotkey 2 script that can change the input mode of keys and mouse buttons.

5 input modes are currently supported:
- toggle: converts keys that must be held down into toggle keys.
- hold: converts keys that must be toggled into hold keys.
- autofire toggle: same as toggle except it will repeatedly perform the action of another key.
- autofire hold: same as autofire except you need to hold the autofire key.
- autorun: toggle key that holds the forward key until pressed again (or pressing the forward/backward key)

## Installation

You can run the script from anywhere, as long as "KeyToggles.ini" is in the same directory.  

## Usage

The hotkeys will only be active when the specified process (and optionally window) is in focus.

You can edit the script settings using the built-in configurator (accessible from the tray menu). Please read "KeyToggles.ini" for more information about settings.

Make sure your hotkeys are the same than the ones in-game and that the input modes are different (otherwise unexpected behavior will occur).

For games run as admin, you must also run the script as admin for hotkeys to work.

Default hotkeys:

Right-click: aim  
Left CTRL: crouch  
Left SHIFT: sprint  
F1: toggle autorun  
F2: aim autofire  
F3: crouch autofire  
F4: sprint autofire  
w: move forward  
s: move backward  
Left ALT + F10: close the script (debug mode)  
Left ALT + F11: reload the script (debug mode)  
Left ALT + F12: suspend the script (disables all hotkeys)

<img width="522" height="843" alt="built-in configurator" src="https://github.com/user-attachments/assets/225856e4-36ec-413b-8cd3-94b216f428a1" />

## Limitations

- Hotkeys using modifiers (ex: Ctrl + K) aren't supported at the moment.
- Notifications only work if the game is not running in exclusive fullscreen mode.
- The hotkey controls in the built-in configurator don't support some keys. Use the extra keys drop-down lists for that (mouse buttons won't show up though).
- It will not work in games that prevent keys from being simulated (ex: games using anti-cheats).

## Credits

- [Keeyra_](https://www.reddit.com/user/Keeyra_)

## Disclaimer
- I've only tested the script in Aliens: Colonial Marines, Half-Life 1, Half-Life 2 and some Unity games but it should work in most cases. If it doesn't, feel free to post an issue about it.
- I won't be held responsible for unexpected behavior such as game bans or loss of data. Use at your own risk!
