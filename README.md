# Pinball Action (Tehkan 1985) for MiSTer FPGA
A MiSTer FPGA implementation of Pinball Action, the 1985 arcade game developed by Tehkan (later Tecmo).
This core recreates the original arcade hardware using FPGA logic and is intended for preservation, research, and enjoyment on MiSTer FPGA hardware.

<p align="center">
  <img src="https://github.com/net-beui/Arcade-PinballAction/blob/main/pbaction-small.png" />
</p>

## Features
- Z80 main CPU
- Z80 sound CPU
- Three AY-3-8910 compatible sound generators
- Hardware tilemap and sprite rendering
- Background scrolling
- Cocktail/flip-screen support
- MiSTer FPGA framework integration
- MRA-based ROM loading
- HDMI and analog video support
- Per-layer alignment controls for hardware tuning

## Hardware Summary
| Component | Details |
|----------|----------|
| Main CPU | Z80 @ 4 MHz |
| Sound CPU | Z80 @ 3 MHz |
| Sound | 3 × AY-3-8910 compatible PSGs |
| Video | 256×224 active display |
| Foreground | 8×8 tiles, 3 bpp |
| Background | 8×8 tiles, 4 bpp |
| Sprites | 16×16 and 32×32 sprites, 3 bpp |
| Palette | 256 colors from palette RAM |

## ROM Requirements
This project requires the original arcade ROMs, which are not included.
Users must provide their own legally obtained ROM images.
The core expects the standard MAME pbaction.zip ROM set through the supplied MRA file.

## Building
Requirements
- Quartus Prime 17.x
- MiSTer FPGA framework
- DE10-Nano

Build Steps
1. ```git clone --recurse-submodules https://github.com/net-beui/PinballAction_MiSTer```
2. Open ```PinballAction.qpf```
3. Compile using Quartus Prime and load the resulting .rbf onto MiSTer

## Project Status

This core is currently playable and feature-complete enough for regular use on MiSTer FPGA.

Implemented and working:

- Main Z80 CPU subsystem
- Sound Z80 subsystem
- Three AY-3-8910 compatible PSG channels (JT49)
- Foreground and background tilemap rendering
- Sprite rendering (16×16 and 32×32 sprites)
- Background scrolling
- Palette RAM and color generation
- Screen flip support
- MRA ROM loading
- HDMI and analog video support
- Per-layer alignment controls for tuning and verification

### Known Issues

#### Bottom edge rendering discrepancy

One remaining video issue affects the extreme bottom of the playfield (which appears on the left side of the screen when using the game's native vertical orientation).

A small band approximately three scanlines tall does not perfectly match MAME:

- Gameplay is fully functional
- The issue is only visible at the extreme edge of the playfield
- The affected rows appear to use incorrect source pixels
- Foreground, background, and sprite rendering are otherwise aligned and functional
- The exact root cause is still unknown

The current implementation represents the best gameplay-oriented compromise found so far, but the final edge-case rendering behavior remains unresolved.

If you would like to help investigate this issue, contributions, ideas, test results, or code reviews would be greatly appreciated.

### Accuracy

The goal of this project is hardware-faithful recreation rather than enhancement. Areas still under active review include:

- Video timing verification against original hardware
- Remaining edge-case rendering differences from MAME
- Sound subsystem accuracy improvements
- Documentation and hardware research

Bug reports, hardware captures, PCB references, and pull requests are welcome.

## Acknowledgements
*Jotego*

This project makes use of Jotego's excellent JT49 AY-3-8910 compatible sound implementation.
JT49 is part of the Jotego FPGA arcade preservation ecosystem and is used here as the programmable sound generator implementation for Pinball Action.
Thank you to José Tejada Gómez (Jotego) and all contributors involved in preserving arcade hardware through FPGA development.

*MiSTer Project*

Thanks to Sorgelig and the MiSTer FPGA community for creating and maintaining the MiSTer platform.

*MAME*

MAME serves as an invaluable reference for hardware behavior, device mappings, graphics layouts, and verification.

## About AI-Assisted Development
Artificial intelligence tools were used during development of this project.
AI assistance was used for tasks such as:

- Verilog/SystemVerilog review
- Documentation improvements
- Code cleanup and refactoring suggestions
- Hardware research assistance
- Debugging discussions and analysis

All generated suggestions were reviewed, tested, modified where necessary, and integrated by the project maintainer. The final implementation decisions, testing, debugging, validation, and responsibility for the code remain with the author.
This project should be viewed as a human-developed FPGA core that made use of AI as a development aid, similar to the use of static analysis tools, code assistants, or other engineering productivity tools.

## License
This project is licensed under the GNU General Public License v3.0 (GPL-3.0).
You are free to:

- Use the source code
- Study the source code
- Modify the source code
- Redistribute the source code

Under the terms of GPL-3.0, any redistributed modified versions must also make their corresponding source code available under GPL-3.0.
See the included LICENSE file for the full license text.

## Disclaimer
Pinball Action is a copyrighted work of its respective rights holders.
This repository contains only FPGA implementation source code and supporting project files. No game ROMs or copyrighted game assets are included.

