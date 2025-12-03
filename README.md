<!--
  SPDX-FileCopyrightText: 2020-21 SmartRent
  SPDX-License-Identifier: CC-BY-4.0
-->

# RamoopsLogger

[![Hex version](https://img.shields.io/hexpm/v/ramoops_logger.svg "Hex version")](https://hex.pm/packages/ramoops_logger)
[![API docs](https://img.shields.io/hexpm/v/ramoops_logger.svg?label=hexdocs "API docs")](https://hexdocs.pm/ramoops_logger/RamoopsLogger.html)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/nerves-project/ramoops_logger/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/nerves-project/ramoops_logger/tree/main)
[![REUSE status](https://api.reuse.software/badge/github.com/nerves-project/ramoops_logger)](https://api.reuse.software/info/github.com/nerves-project/ramoops_logger)

This library uses the Linux
[pstore](https://www.kernel.org/doc/html/v6.12/admin-guide/pstore-blk.html) to
capture diagnostic information for unexpected reboots. The `pstore` is a special
block of DRAM managed by the kernel that can survive reboots. This works
independent of filesystems where logs are normally kept and since it's
in-memory, there's no loss on unexpected reboots due to caching.

This library does require a properly configured kernel to work. In particular,
it uses the user application accessible `pmsg` circular buffer.

Here are some features:

* Automatically record log messages of `:error` severity and higher
* Retrieve logs from the previous reboot

For historical reasons, some `pstore` functionality was called `ramoops` and
that affects the naming of this library.

## Configuration

RamoopsLogger uses the Linux `pstore` device driver, so it only works on
Linux-based platforms. Most official Nerves Projects systems start the `pstore`
driver automatically and you can skip the Linux configuration.

### Linux configuration

The most important part of using the RamoopsLogger is ensuring that the `pstore`
device driver is enabled and configured in your Linux kernel. Most of the
official Nerves Project systems do this already.

The required kernel options are:

```text
CONFIG_PSTORE=y
CONFIG_PSTORE_PMSG=y
CONFIG_PSTORE_RAM=y
```

Then you'll need to allocate part of DRAM to use for `pstore` and configure
memory sizes. Please refer to Linux `pstore` documentation.

If you're using a system that uses device trees or device tree overlays, the
following snippet may help you find the parts that need configuration. Please,
please don't copy verbatim and expect it to work.

```c
reserved-memory {
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;

        ramoops@88d00000{
                compatible = "ramoops";
                reg = <0x88d00000 0x100000>;
                ecc-size = <16>; /* Optional */
                record-size     = <0x00020000>; /* Optional */
                console-size    = <0x00020000>; /* Optional */
                ftrace-size     = <0>; /* Optional */
                pmsg-size       = <0x00020000>; /* Important for RamoopsLogger */
        };
};
```

Look for `/dev/pmsg0` to verify that Linux loaded the `pstore` driver and it's
properly configured.

### Update your Elixir project

Once you're satisfied with the Linux, add `ramoops_logger` to your project's
`mix.exs` dependencies list.

```elixir
def deps do
  [
    {:ramoops_logger, "~> 0.3.0"}
  ]
end
```

No application configuration is necessary as the defaults should all be fine. If
you do need to change something, here are the available options for your
`config.exs` or `target.exs`:


```elixir
import Config

config :ramoops_logger,
  pmsg_path: "/dev/pmsg0",              # If you have more than one pmsg buffer
  pstore_mount_point: "/sys/fs/pstore", # Mount pstore in a custom location
  pmsg_log: "pmsg-ramoops-0",           # Analogous to pmsg_path for more than one pmsg buffer
  auto_mount?: true                     # Mount pstore automatically
```

## IEx Session Usage

To read the last ramoops log to the console run:

```elixir
iex> RamoopsLogger.dump()
```

To read the last ramoops log and it to a variable run:

```elixir
iex> {:ok, contents} = RamoopsLogger.read()
```
