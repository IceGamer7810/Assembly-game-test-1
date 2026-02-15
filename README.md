# Assembly-game-test-1

Natív Windows 10 Assembly projekt (FASM), 3D FPS alapjátékkal.

## Fájlok
- `game.asm` - a játék teljes forrása (Assembly)
- `build.bat` - fordítási script
- `tools/FASM.EXE` - assembler
- `AssemblyGame.exe` - lefordított futtatható fájl

## Build
```bat
build.bat
```

## Vezérlés
- `W A S D`: mozgás
- `Egér`: FPS nézet forgatás
- `Space`: ugrás
- `Shift`: futás
- `Ctrl`: guggolás
- `Esc`: kurzor vissza

## Megjegyzés
- A build közvetlenül a gyökérbe írja az `AssemblyGame.exe`-t.
- A játék assembly forrásból fordul (`game.asm`).
