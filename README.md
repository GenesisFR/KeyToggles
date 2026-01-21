# KeyToggles
An AutoHotkey 2 script that can change the input mode of keys and mouse buttons.

4 modes are currently supported:
- toggle: you don't have to hold the key to perform its action.
- hold: you have to hold the key to perform its action.
- autofire: same as toggle except it will repeatedly perform the action of another key.
- autofire hold: same as autofire except you need to hold the autofire key.

## Installation

You can run the script from anywhere, as long as "KeyToggles.ini" is in the same directory than the script.  

## Usage

The script will only be active when the specified window is in focus. Please read "KeyToggles.ini" for more information about setting it up.  

Make sure that your keys or mouse buttons in "KeyToggles.ini" are the same than the ones in the game.

Default keys:

Right-click: toggle aim  
Left CTRL: toggle crouch  
Left SHIFT: toggle sprint  
F1: toggle aim autofire  
F2: toggle crouch autofire  
F3: toggle sprint autofire  
Left ALT + F12: pause the script (disable all hotkeys)  

For games run as admin, you must also run the script as admin for it to work.

## Limitations

I've only tested the script in Aliens: Colonial Marines, Half-Life 1, Half-Life 2 and some Unity games.  
It will not work in games that prevent keys from being simulated (ex: games using anti-cheats).

## Credits

- [Keeyra_](https://www.reddit.com/user/Keeyra_)