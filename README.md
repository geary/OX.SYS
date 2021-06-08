This is a little `AUX` driver I wrote back in the 1980s for Windows 1.0 debugging.

Back then, the Windows `OutputDebugString()` function wrote to the `AUX` device that DOS managed. By default, this was a terminal connected to a serial port.

I didn't have one of those, but I did have the IBM Monochrome Display sitting idle while Windows ran on the CGA/EGA/VGA display.

So this driver redirected `AUX` output to the monochrome display and scrolled the output.

Why is it called `OX.SYS` instead of something more obvious like `AUX.SYS`?

Turned out that `AUX` was a reserved name that _always_ pointed to the serial port, regardless of the file extension, even if you were trying to access a filename like `AUX.ASM`.

As can be seen in the `title` directive, at first I tried calling it `AuxDrv`. But that didn't roll off the tongue like `AUX`. So I changed the name to `OX`. Homophones to the rescue!

Context and discussion:

[What's the deal with those reserved filenames like NUL and CON?](https://devblogs.microsoft.com/oldnewthing/20031022-00/?p=42073)

[“It is 2018 and this error message is a mistake from 1974”](https://news.ycombinator.com/item?id=27426775)
