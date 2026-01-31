# KeyToggles
An AutoHotkey 2 script that can change the input mode of keys and mouse buttons.

5 modes are currently supported:
- toggle: converts keys that must be held down into toggle keys.
- hold: converts keys that must be toggled into hold keys.
- autofire: same as toggle except it will repeatedly perform the action of another key.
- autofire hold: same as autofire except you need to hold the autofire key.
- autorun: holds the forward key until pressed again (or pressing the forward/backward key)

## Installation

You can run the script from anywhere, as long as "KeyToggles.ini" is in the same directory.  

## Usage

The script will only be active when the specified process (and optionally window) is in focus. Please read "KeyToggles.ini" for more information about settings.  

Make sure that your keys or mouse buttons in "KeyToggles.ini" are the same than the ones in the game.

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
Left ALT + F12: pause the script (disables all hotkeys)  

For games run as admin, you must also run the script as admin for it to work.

## Limitations

I've only tested the script in Aliens: Colonial Marines, Half-Life 1, Half-Life 2 and some Unity games but it should work in most games.  
It will not work in games that prevent keys from being simulated (ex: games using anti-cheats).

## Credits

- [Keeyra_](https://www.reddit.com/user/Keeyra_)