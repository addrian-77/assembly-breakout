# assembly-breakout

This project aims to port the classic Breakout game into 8086 Assembly.

## How to run
> It is recommended to run this game through a DosBox emulator

1. Clone this repository
2. Compile the code into a `.com` file (I used emu8086)
3. Run the `.com` file on a DOS compatible machine, or use a DosBox emulator.

## Features
- Projectile collision checking with screen bounds and paddle
- The direction of the projectile will be changed based on where it hits the paddle
- For projectiles, drawing is ignored if an update has not occured
- For paddle, a full initial draw is done, then only the outer margins are redrawn to save performance

## Missing features
- Bricks collision checker
- Powerups, pickups