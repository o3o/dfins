# dfins

This is an implementation of the OMRON FINS protocol using [D](https://dlang.org/)



## Usage
The `examples` sub directory contains examples explaining how use this library.

Import the module:
```d
import dfins;
```

Create an udp channel:
```d
enum TIMEOUT_MS = 2000;
IChannel chan = createUdpChannel("192.168.221.22", TIMEOUT_MS);
```

Create a FinsClient object and pass it:
- channel
- header

```
Header h = header(22);
FinsClient f = new FinsClient(chan, h);
```

Finally read and write:

```
/* Reads 10 registers starting from register 00000 in the DM Memory Area */
ubyte[] d0 = f.readArea(MemoryArea.DM, 0, 10);

/* Writes the values 42, 19, 64 into DM registers 0, 1, 2 */
ushort[] v = [42, 19, 64];
f.writeArea(MemoryArea.DM, 0, v.toBytes!ushort);
```

