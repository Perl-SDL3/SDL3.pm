# NAME

SDL3 - Perl Wrapper for the Simple DirectMedia Layer 3.0

# SYNOPSIS

```perl
use SDL3 qw[:all];

my $window = SDL_CreateWindow( 'My Game', 640, 480, 0 );
# ...do stuff
```

# DESCRIPTION

This module provides a Perl wrapper for SDL3, a cross-platform development library designed to provide low level access
to audio, keyboard, mouse, joystick, and graphics hardware.

## Features

Each feature listed below is a tag you may use to import with.

### :assert

Helpful assertion macros! Well, not really...

### :asyncio

SDL offers a way to perform I/O asynchronously. This allows an app to read or write files without waiting for data to
actually transfer; the functions that request I/O never block while the request is fulfilled.

### :atomic

Atomic operations.

IMPORTANT: If you are not an expert in concurrent lockless programming, you should not be using any functions in this
file. You should be protecting your data structures with full mutexes instead.

### :audio

Audio functionality for the SDL library.

### :bits

Functions for fiddling with bits and bitmasks.

### :blendmode

Blend modes decide how two colors will mix together. There are both standard modes for basic needs and a means to
create custom modes, dictating what sort of math to do on what color components.

### :camera

Video capture for the SDL library.

### :clipboard

SDL provides access to the system clipboard, both for reading information from other processes and publishing
information of its own.

### :cpuinfo

CPU feature detection for SDL.

### :dialog

File dialog support.

### :error

Simple error message routines for SDL.

### :events

Event queue management.

### :filesystem

SDL offers an API for examining and manipulating the system's filesystem. This covers most things one would need to do
with directories, except for actual file I/O.

### :gamepad

SDL provides a low-level joystick API, which just treats joysticks as an arbitrary pile of buttons, axes, and hat
switches. If you're planning to write your own control configuration screen, this can give you a lot of flexibility,
but that's a lot of work, and most things that we consider "joysticks" now are actually console-style gamepads. So SDL
provides the gamepad API on top of the lower-level joystick functionality.

### :gpu

The GPU API offers a cross-platform way for apps to talk to modern graphics hardware. It offers both 3D graphics and
compute support, in the style of Metal, Vulkan, and Direct3D 12.

### :guid

A GUID is a 128-bit value that represents something that is uniquely identifiable by this value: "globally unique."

SDL provides functions to convert a GUID to/from a string.

### :haptic

The SDL haptic subsystem manages haptic (force feedback) devices.

### :hidapi

HID devices.

### :hints

Functions to set and get configuration hints, as well as listing each of them alphabetically.

### :init

All SDL programs need to initialize the library before starting to work with it.

### :iostream

SDL provides an abstract interface for reading and writing data streams. It offers implementations for files, memory,
etc, and the app can provide their own implementations, too.

SDL\_IOStream is not related to the standard C++ iostream class, other than both are abstract interfaces to read/write
data.

See [SDL3: CategoryIOStream](https://wiki.libsdl.org/SDL3/CategoryIOStream)

### :joystick

SDL joystick support.

### :keyboard

SDL keyboard management.

### :keycode

Defines constants which identify keyboard keys and modifiers.

### :loadso

System-dependent library loading routines.

### :locale

A struct to provide locale data.

### :log

Simple log messages with priorities and categories. A message's SDL\_LogPriority signifies how important the message is.
A message's SDL\_LogCategory signifies from what domain it belongs to. Every category has a minimum priority specified:
when a message belongs to that category, it will only be sent out if it has that minimum priority or higher.

### :main

Redefine main() if necessary so that it is called by SDL.

### :messagebox

SDL offers a simple message box API, which is useful for simple alerts, such as informing the user when something fatal
happens at startup without the need to build a UI for it (or informing the user \_before\_ your UI is ready).

### :metal

Functions to creating Metal layers and views on SDL windows.

This provides some platform-specific glue for Apple platforms. Most macOS and iOS apps can use SDL without these
functions, but this API they can be useful for specific OS-level integration tasks.

### :misc

SDL API functions that don't fit elsewhere.

### :mouse

Any GUI application has to deal with the mouse, and SDL provides functions to manage mouse input and the displayed
cursor.

See [SDL3: CategoryMouse](https://wiki.libsdl.org/SDL3/CategoryMouse)

### :mutex

SDL offers several thread synchronization primitives. This document can't cover the complicated topic of thread safety,
but reading up on what each of these primitives are, why they are useful, and how to correctly use them is vital to
writing correct and safe multithreaded programs.

### :opengl

This is a simple file to encapsulate the OpenGL API headers.

This is still on my TODO list.

### :pen

SDL pen event handling.

SDL provides an API for pressure-sensitive pen (stylus and/or eraser) handling, e.g., for input and drawing tablets or
suitably equipped mobile / tablet devices.

### :pixels

SDL offers facilities for pixel management.

### :platform

SDL provides a means to identify the app's platform, both at compile time and runtime.

### :power

SDL power management routines.

### :process

Process control support.

These functions provide a cross-platform way to spawn and manage OS-level processes.

### :properties

A property is a variable that can be created and retrieved by name at runtime.

### :rect

Some helper functions for managing rectangles and 2D points, in both integer and floating point versions.

See [SDL3: CategoryRect](https://wiki.libsdl.org/SDL3/CategoryRect)

### :render

SDL 2D rendering functions.

See [SDL3: CategoryRender](https://wiki.libsdl.org/SDL3/CategoryRender)

### :scancode

The SDL keyboard scancode representation.

An SDL scancode is the physical representation of a key on the keyboard, independent of language and keyboard mapping.

### :sensor

SDL sensor management.

These APIs grant access to gyros and accelerometers on various platforms.

### :storage

The storage API is a high-level API designed to abstract away the portability issues that come up when using something
lower-level.

### :surface

SDL surfaces are buffers of pixels in system RAM. These are useful for passing around and manipulating images that are
not stored in GPU memory.

See [SDL3: CategoryVideo](https://wiki.libsdl.org/SDL3/CategoryVideo)

### :stdinc

SDL provides its own implementation of some of the most important C runtime functions. Using these functions allows an
app to have access to common C functionality without depending on a specific C runtime (or a C runtime at all).

### :system

Platform-specific SDL API functions. These are functions that deal with needs of specific operating systems, that
didn't make sense to offer as platform-independent, generic APIs.

Most apps can make do without these functions, but they can be useful for integrating with other parts of a specific
system, adding platform-specific polish to an app, or solving problems that only affect one target.

### :thread

SDL offers cross-platform thread management functions. These are mostly concerned with starting threads, setting their
priority, and dealing with their termination.

### :time

SDL realtime clock and date/time routines.

### :timer

SDL provides time management functionality. It is useful for dealing with (usually) small durations of time.

### :touch

SDL offers touch input, on platforms that support it. It can manage multiple touch devices and track multiple fingers
on those devices.

### :tray

SDL offers a way to add items to the "system tray" (more correctly called the "notification area" on Windows). On
platforms that offer this concept, an SDL app can add a tray icon, submenus, checkboxes, and clickable entries, and
register a callback that is fired when the user clicks on these pieces.

### :version

Functionality to query the current SDL version, both as headers the app was compiled against, and a library the app is
linked to.

### :video

SDL's video subsystem is largely interested in abstracting window management from the underlying operating system. You
can create windows, manage them in various ways, set them fullscreen, and get events when interesting things happen
with them, such as the mouse or keyboard interacting with a window.

See [SDL3: CategoryVideo](https://wiki.libsdl.org/SDL3/CategoryVideo)

### :vulkan

Functions for creating Vulkan surfaces on SDL windows.

# NAME

SDL3 - Simple DirectMedia Layer 3.0

# SYNOPSIS

```perl
use SDL3;
...;
```

# DESCRIPTION

FFI Wrapper of SDL3

# See Also

TODO

# LICENSE

This software is Copyright (c) 2025 by Sanko Robinson <sanko@cpan.org>.

This is free software, licensed under:

```
The Artistic License 2.0 (GPL Compatible)
```

See the `LICENSE` file for full text.

# AUTHOR

Sanko Robinson <sanko@cpan.org>
