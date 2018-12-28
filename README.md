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

Alternatively, you can always download PRG file from GitHub releases location: 
