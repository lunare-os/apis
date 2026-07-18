# Useful APIs for CC Tweaked

This repository contains various useful APIs that developers can use to create a variety of software for CC Tweaked.

## Multimonitor API
This API allows you to combine multiple monitors into a single large virtual monitor with an identical set of methods.
The first time you use it, a configurator will launch to help you set up your monitors interactively. Once the configuration is complete, a `mm.json` file will be created for future use.
To reset the configuration, simply delete the `mm.json` file.
### Methods that have not been implemented:

- scroll:
  This would be too difficult to implement, as it would require maintaining a buffer of the current content of all monitors and performing resource-intensive redraw operations.
- setPaletteColo[u]r: TODO in near future
- getPaletteColo[u]r: TODO in near future

### How to install
Simply run this command in the CC:T computer shell:
```sh
wget https://raw.githubusercontent.com/lunare-os/apis/refs/heads/main/multimonitor.lua mm.lua
```
### Usage

```lua
local m = require("mm")
local w,h = m.getSize()
m.write("Hello, world!")
m.setCursorPos(10,2)
m.write("That's a ".. string.rep("very ", math.floor(w/3)).. "long line btw :P")
```
