# bluevessel

[![Build Status](https://travis-ci.org/maciejmalecki/bluevessel.svg?branch=master)](https://travis-ci.org/maciejmalecki/bluevessel)

BlueVessel is my first official C64 intro (calling it a demo would be a bit too much) that I completed in ca 2hrs using c64lib. I plan to 
give it as an addition to C64C that I have prepared for my collegue. Why it is about vessel and why it's blue - he'll know ;-)

This intro is released in form of PRG file that can be either launched using C64 emulator (i.e. Vice) or by running on real hardware 
(preferred).

## how to compile

This intro is written with KickAssembler and can be compiled with KA version 5.0. It requires, however, a few libraries to be checked out into `<lib-dir>`:
* https://github.com/c64lib/common
* https://github.com/c64lib/chipset
* https://github.com/c64lib/text
* https://github.com/c64lib/copper64

The intro can be compiled in following way:
```
java -jar <path-to-ka>/KickAss.jar -libdir <lib-dir> bluevessel.asm
```
Put path to the place where you keep your Kick Assembler installation as `<path-to-ka>` and directory where you have cloned library repositiories as `<lib-dir>`.

Alternatively, you can always download PRG file from GitHub releases location: https://github.com/maciejmalecki/bluevessel/releases/latest

## how is it made

This intro demonstates few simple but well cycled raster based effects. Writing stable raster interrupt routines is not a big deal but it is rather annoying to code and cycle it separately for each project I'm going to develop, therefore I have written copper64 library that, in the future, will do the job for most common effects you'll need for games, intros or even simple demos.

Sadly, it does not work with NTSC models, but I have idea to hack in support of NTSC into c64lib. This will rather be a separate build target for KickAssembler (so separate binaries will be produced), but still, it will be sufficient to keep NTSC community happy. I don't personally own any NTSC machine but hopefully I don't need any as there is Vice...
