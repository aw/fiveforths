# FiveForths: 32-bit RISC-V Forth for microcontrollers

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/aw/fiveforths/main.yml) [![GitHub release](https://img.shields.io/github/release/aw/fiveforths.svg)](https://github.com/aw/fiveforths) [![justforfunnoreally.dev badge](https://img.shields.io/badge/justforfunnoreally-dev-9ff)](https://justforfunnoreally.dev)

[FiveForths](https://github.com/aw/fiveforths) is a tiny [Forth](https://www.forth.com/starting-forth/) written in hand-coded RISC-V assembly, initially designed to run on the 32-bit [Longan Nano](https://longan.sipeed.com/en/) (GD32VF103) microcontroller.

![fiveforths-terminal](https://user-images.githubusercontent.com/153401/213904509-089dd490-62e2-4c9d-9f9c-a6e5fab34e17.png)

_FiveForths_ currently uses the _indirect threading_ model and only has 19 built-in primitive words. It is 100% fully functional and can be extended by adding new primitives (in Assembly) or by defining new words (in Forth). This implementation is loosely inspired by [sectorforth](https://github.com/cesarblum/sectorforth), [jonesforth](https://github.com/nornagon/jonesforth), and [derzforth](https://github.com/theandrew168/derzforth).

Development progress has been logged regularly in the [devlogs](https://aw.github.io/fiveforths/).

---

1. [Quick start](#quick-start)
2. [Documentation](#documentation)
3. [Todo](#todo)
4. [Contributing](#contributing)
5. [Changelog](#changelog)
6. [License](#license)

# Quick start

The quickest way to get started is to download and flash one of the firmware binaries listed below:.

* [fiveforths-longan-nano-lite.bin](https://github.com/aw/fiveforths/releases/download/v0.5/fiveforths-longan-nano-lite.bin) (64K Flash, 20K RAM)
* [fiveforths-longan-nano.bin](https://github.com/aw/fiveforths/releases/download/v0.5/fiveforths-longan-nano.bin) (128K Flash, 32K RAM)

See the [TUTORIALS](docs/TUTORIALS.md) for detailed download and flashing information.

# Documentation

* [TUTORIALS](docs/TUTORIALS.md): a quick guide to **get started**
* [EXPLAIN](docs/EXPLAIN.md): learn the story behind _FiveForths_
* [HOWTO](docs/HOWTO.md): build, usage, and code examples in Forth and RISC-V Assembly
* [REFERENCE](docs/REFERENCE.md): learn the technical details, what's under the hood

# TODO

- [ ] Code cleanup and optimizations

# Contributing

Please create a pull-request or [open an issue](https://github.com/aw/picolisp-kv/issues/new) on GitHub.

# Changelog

## 0.5 (TBD)

  * Fix issue #19 - Error building without zicsr extension
  * Fix issue #20 - Specify `stm32loader` instead of `dfu-util` in docs

## 0.4 (2023-01-23)

  * Fix issue #16 - Add the ability to read hex numbers
  * Update documentation
  * Add example for toggling an LED

## 0.3 (2023-01-19)

  * Fix issue #7 - Implement bounds checks for stacks
  * Fix issue #8 - Implement bounds checks for user dictionary
  * Fix issue #13 - `TOIN` should not be an address
  * Fix issue #14 - `STORE` primitive is incorrect
  * Add better error messages
  * Add detailed documentation in [docs](docs/)
  * Add `djb2.c` to generate a word's hash locally
  * Add RAM zerofill of unused dictionary space on reset

## 0.2 (2023-01-10)

  * Fix issue #9 - Handling of carriage return
  * Fix issue #11 - Ignore non-printable characters
  * Re-organize code to support different boards and MCUs
  * Add boot message when the device is reset
  * Add GitHub action to automatically build and publish the firmware binaries

## 0.1 2023-01-09 - First release

# License

[MIT License](LICENSE)

Copyright (c) 2021~ [Alexander Williams](https://a1w.ca)
