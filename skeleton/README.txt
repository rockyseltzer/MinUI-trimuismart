MinUI-trimuismart is a custom firmware for the TrimUI Smart, built on MinUI by Shaun Inman. It adds WiFi, Bluetooth audio (including AirPods), clock sync, arcade systems and more.

Source:
https://github.com/rockyseltzer/MinUI-trimuismart

Based on MinUI:
https://github.com/shauninman/minui

----------------------------------------
Installing

Use a reputable SD card, freshly formatted as FAT32 (MBR).

Unzip this file and copy everything in it to the root of the SD card: the "trimui" folder, "MinUI.zip" (do not unzip it), and the Bios, Roms, Saves, Emus and Tools folders. Put your games in the matching Roms folders and any bios files in the matching Bios folders.

Put the card in the TrimUI Smart and power on. The stock firmware runs the "trimui" folder once, which installs MinUI and then deletes itself. MinUI then unpacks "MinUI.zip" and starts.

----------------------------------------
Updating

Copy everything from the new zip to the root of the SD card, replacing what is there. Your games, saves and settings are kept. MinUI installs the new "MinUI.zip" on the next boot. (The "trimui" folder is only needed for a first install; it is harmless on an existing card.)

----------------------------------------
Shortcuts

  Volume: SELECT + L or R
  Brightness: START + L or R
  Sleep: MENU (twice)
  Wake: MENU

----------------------------------------
Quicksave & auto-resume

MinUI creates a quicksave when powering off in-game, and the next time you power on it resumes from where you left off. The TrimUI Smart has no POWER button: press MENU twice to put it to sleep before flipping the POWER switch.

----------------------------------------
Roms

The "Roms" folder has a folder for each system. You can rename these folders, but you must keep the uppercase tag in parentheses, which picks the emulator (eg. "Nintendo Entertainment System (FC)" could be renamed "NES (FC)").

When folders share the same display name (eg. "Game Boy Advance (GBA)" and "Game Boy Advance (MGBA)") they are combined into one menu item containing the roms from both. This lets you open specific roms with an alternate emulator.

Arcade (CPS1, CPS2, NEOGEO) uses the split FB Alpha 2012 cores: roms must match the FB Alpha 0.2.97.29 era sets, not modern FBNeo sets.

----------------------------------------
Bios

MinUI is strictly BYOB (bring your own bios). Put each bios in the folder that matches the tag of its Roms folder (eg. "/Bios/PS/" for "Sony PlayStation (PS)"). File names are case-sensitive:

      FC: disksys.rom
     FDS: disksys.rom
      GB: gb_bios.bin
     GBA: gba_bios.bin
     GBC: gbc_bios.bin
      MD: bios_CD_E.bin
          bios_CD_J.bin
          bios_CD_U.bin
    MGBA: gba_bios.bin
  NEOGEO: neogeo.zip
     PCE: syscard3.pce
     PKM: bios.min
      PS: psxonpsp660.bin
     SGB: sgb.bios

----------------------------------------
Disc-based games

To launch multi-file disc games directly, put the bin/cue (and/or iso/wav) files in a folder with the same name as the cue file. MinUI launches the cue file instead of opening the folder, eg.

  Harmful Park (English v1.0)/
    Harmful Park (English v1.0).bin
    Harmful Park (English v1.0).cue

For multi-disc games, put all the discs' files in one folder with an m3u file of the same name as the folder, listing each disc's cue file on its own line, eg.

  Policenauts (English v1.0)/
    Policenauts (English v1.0).m3u
    Policenauts (Japan) (Disc 1).bin
    Policenauts (Japan) (Disc 1).cue
    Policenauts (Japan) (Disc 2).bin
    Policenauts (Japan) (Disc 2).cue

where the m3u contains:

  Policenauts (Japan) (Disc 1).cue
  Policenauts (Japan) (Disc 2).cue

The in-game menu's Continue item then shows the current disc; press left or right to switch discs. chd and official pbp files also work (multi-disc pbp files over 2GB do not). All discs of a game share one memory card and set of save state slots.

----------------------------------------
Collections

A collection is a text file in the "Collections" folder at the root of the SD card, listing full paths to rom, cue or m3u files in order, eg. "/Collections/Metroid series.txt":

  /Roms/GBA/Metroid Zero Mission.gba
  /Roms/GB/Metroid II.gb
  /Roms/SNES (SFC)/Super Metroid.sfc
  /Roms/GBA/Metroid Fusion.gba

----------------------------------------
Display names

To override the name MinUI shows for a file, create a map.txt in the same folder: one line per file, `rom.ext`, a single tab, then `Display Name`. Start a display name with `.` to hide the file, eg.

  neogeo.zip	.Neo Geo Bios
  mslug.zip	Metal Slug
  sf2.zip	Street Fighter II

----------------------------------------
Tools

  Battery: battery level graph
  Bluetooth: pair, connect and play audio over Bluetooth
  Bootlogo: change the boot logo
  Clock: set the date and time
  Files: file manager
  Input: test the buttons
  Sync Clock: set the clock over WiFi
  Wifi: connect to a WiFi network

Bluetooth: pair a device with "Connect a device", then choose it again to connect. "Audio to Bluetooth" sends all sound to it and turns WiFi off while it is on (they share one antenna); turning it off reconnects WiFi. Expect about 200ms of audio delay. Deleting "/Tools/trimuismart/Bluetooth.pak" returns to the factory Bluetooth driver on the next boot.

----------------------------------------
Simple mode

MinUI has a simple mode that hides the Tools folder and replaces Options in the in-game menu with Reset. Create an empty file named "enable-simple-mode" (no extension) in "/.userdata/shared/".

----------------------------------------
Advanced

MinUI runs a user-authored shell script on boot if you place a file named "auto.sh" in "/.userdata/trimuismart/". Use Unix line endings (`\n`); Windows line endings (`\r\n`) will not work.

----------------------------------------
Thanks

To Shaun Inman, for MinUI.

To eggs, for his NEON scalers, years of top-notch example code, and patience in the face of endless questions.

To neonloop, for the original Trimui toolchain on which every MinUI toolchain is based, and for picoarch, the inspiration for minarch.

  https://git.crowdedwood.com

To Steward, for maintaining exhaustive documentation on a plethora of devices:

  https://steward-fu.github.io/website/

To the BlueZ and bluez-alsa projects, and to josegonzalez for minui-list and minui-presenter.
