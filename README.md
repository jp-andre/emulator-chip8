# CHIP-8 emulator in Zig

This program is a simple example of a CHIP-8 emulator.
This was written to learn Zig and have a little bit of
fun.

![image](https://github.com/user-attachments/assets/23adeeda-1a18-4f36-a86b-daede1a91a22)

## Run it

With zig 0.13.0 preinstalled:
```bash
zig build run -- assets/gradsim.hex
```

Optional arguments: `--debug`, `--hires` and `--nosleep`.

Key bindings: 1,2,3,4,q,w,e,r,a,s,d,f,z,x,c,v.

Extra keys:
- H: toggle debug
- G: toggle nosleep (fast mode)

## Resources

- Zig: https://ziglang.org/
- CHIP specs: http://devernay.free.fr/hacks/chip8/C8TECH10.HTM
- CHIP8 examples: https://johnearnest.github.io/Octo/
- SDL: https://thenumb.at/cpp-course/index.html

## TODO

- [ ] Support for audio output
- [ ] Fix execution sync and rendering speed (blinking)
- [ ] Support for quirks and other chips
- [ ] Test suite

## Assets

These were generated in https://johnearnest.github.io/Octo/.
I'm assuming the license for the programs is also MIT since they
can be found in https://github.com/JohnEarnest/Octo.

## This project will NOT be maintained
