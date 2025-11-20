<!--
  SPDX-FileCopyrightText: 2020-21 SmartRent
  SPDX-License-Identifier: CC-BY-4.0
-->

# RamoopsLogger

[![Hex version](https://img.shields.io/hexpm/v/ramoops_logger.svg "Hex version")](https://hex.pm/packages/ramoops_logger)
[![API docs](https://img.shields.io/hexpm/v/ramoops_logger.svg?label=hexdocs "API docs")](https://hexdocs.pm/ramoops_logger/RamoopsLogger.html)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/nerves-project/ramoops_logger/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/nerves-project/ramoops_logger/tree/main)
[![REUSE status](https://api.reuse.software/badge/github.com/nerves-project/ramoops_logger)](https://api.reuse.software/info/github.com/nerves-project/ramoops_logger)

This is an Elixir Logger backend for forwarding log messages to the [ramoops
logger](https://www.kernel.org/doc/html/v4.19/admin-guide/ramoops.html) on Linux
and Nerves systems. Messages sent to this log are written to a special area of
DRAM that can be recovered after reboots or very short power outages.

Here's a demo video:

[![RamoopsLogger Demo](http://img.youtube.com/vi/vpD511Bk5rU/0.jpg)](http://www.youtube.com/watch?v=vpD511Bk5rU)

## Configuration

RamoopsLogger uses the Linux `pstore` device driver, so it only works on
Linux-based platforms. Most official Nerves Projects systems start the `pstore`
driver automatically and you can skip the Linux configuration.

### Linux configuration

The most important part of using the RamoopsLogger is ensuring that the `pstore`
device driver is enabled and configured in your Linux kernel. The device driver
writes logs to a fixed location in DRAM that is platform-specific. If you are
lucky, someone will have determined a good place to store the logs. The official
Nerves Project systems all have a small amount of memory allocated for use by
the `pstore` driver. If you are not using Nerves, it's possible that one of the
device tree files (for ARM platforms) may be helpful.

If you're not using an official Nerves system, here's an example device tree
fragment that would need to be updated for your device, but may be helpful as a
start.

```c
reserved-memory {
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;

        ramoops@88d00000{
                compatible = "ramoops";
                reg = <0x88d00000 0x100000>;
                ecc-size = <16>;
                record-size     = <0x00020000>;
                console-size    = <0x00020000>;
                ftrace-size     = <0>;
                pmsg-size       = <0x00020000>;
        };
};
```

One way of testing whether the `pstore` driver is available is to check whether
the `/dev/pmsg0` file exists.

### Update your Elixir project

Once you're satisfied with the Linux configuration, add `ramoops_logger` to your project's
`mix.exs` dependencies list.

```elixir
def deps do
  [
    {:ramoops_logger, "~> 0.4.0"}
  ]
end
```

Next, attach the RamoopsLogger handler to the Erlang logger. You can do this in your
`config/runtime.exs`:

```elixir
# In config/runtime.exs
:logger.add_handler(:ramoops_logger, RamoopsLogger.Handler, %{})
```

Or you can attach it programmatically in your application start:

```elixir
# In your application.ex start function
def start(_type, _args) do
  RamoopsLogger.attach()
  
  # ... rest of your application setup
end
```

### Custom Configuration

If the defaults don't work for your system, you can specify custom paths:

```elixir
# In config/runtime.exs
:logger.add_handler(:ramoops_logger, RamoopsLogger.Handler, %{
  pmsg_path: "/dev/pmsg1",
  recovered_log_path: "/sys/fs/pstore/pmsg-ramoops-1"
})
```

Or programmatically:

```elixir
RamoopsLogger.attach(
  pmsg_path: "/dev/pmsg1",
  recovered_log_path: "/sys/fs/pstore/pmsg-ramoops-1"
)
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

## Nerves Automatic Log Check

If you want to have your system check if there is an oops log available, and you
are using Nerves, you can add this to your `rootfs_overlay/etc/iex.exs` file in
your firmware project:

```elixir
if RamoopsLogger.available_log?() do
  IO.puts("Oops! There's something in the oops log. Check with RamoopsLogger.dump()")
end
```
