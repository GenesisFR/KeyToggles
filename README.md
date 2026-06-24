# GothicMacros
An AutoHotkey 2 script that brings quality-of-life features to the classic version of _Gothic 1_.

## Installation

You can run the script from anywhere, as long as `GothicMacros.ini` is in the same directory.

## Usage

It features the following macros, that are only active when the game's window is active, but also automatically disabled/stopped when alt-tabbing or bringing up the Steam overlay.

- **autobuy (toggle)**: holds `Shift + LButton + Action` to allow you to buy stacks of 100 items faster. It can also be used to sell items faster and use consumables. The clicking speed is customizable. Automatically disabled when manually pressing `Escape`, `LButton`, `RButton` or `Shift`.
- **autocook (toggle)**: your character can only cook meat one at a time, so you can start the macro and come back later. You need to make sure you're looking at a pan beforehand.
- **autojump (toggle)**: combine it with autorun to cover long distances faster without having to hold any key. Drawing your weapon while going up makes it even more effective. Automatically disabled when manually pressing `Jump`.
- **autorun (toggle)**: self-explanatory. Automatically disabled when manually pressing `Forward`.
- **fast attack (hold)**: holds the `Action` + `Backward` + `Forward` to let you attack the fastest way possible, therefore maximizing your DPS. You need to make sure your weapon is drawn out beforehand. The drawback is you can't parry while doing it, so use it sparingly.
- **walk (toggle)**: there's already a hard-coded in-game walk toggle (`Caps Lock`) so this one customizable.

All keys are configurable in the config file. Setting the optional keys to blank disables them.

Make sure your hotkeys are the same than the ones in-game (otherwise they won't work and unexpected behavior may occur).

If the game is run as admin, you must also run the script as admin for hotkeys to work.

## Default hotkeys

`F1`: toggle autorun  
`F2`: toggle autojump  
`l`: toggle autocook  
`k`: toggle autobuy  
`ScrollLock`: toggle Steam overlay  
`Shift`: toggle walk  
`Middle-click`: fast attack  
`f`: action  
`Space`: jump  
`s`: move backward  
`w`: move forward  
`Left ALT + F10`: close the script  
`Left ALT + F11`: reload the script  
`Left ALT + F12`: suspend the script (disables all hotkeys)

## Limitations

- Hotkeys using modifiers (ex: `Ctrl + K`) may not work.
- The autobuy macro doesn't work without `Gothic2_Control=1` in `SystemPack.ini`.

## Disclaimer

- I won't be held responsible for unexpected behavior such as loss of items. Use at your own risk!
