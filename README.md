# dfins
This is an implementation of the OMRON FINS protocol using [D](https://dlang.org/).

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


## Documentation
dfins uses ddoc. One way of building and serving the documentation locally (you will need libevent for serving) is:

```
dub build -b ddox && dub run -b ddox
```

Or use your favorite DDOC compiler.


## Omron PLC data example

| Data type    | Value       | FINS rep.             | Std rep.                 |
| ---          | ---         | ---                   | ---                      |
| float        | 3.14        | 0xF5C34048            | 0x4048F5C3               |
| string       | 'abcdefghi' | 0x4241444346454847049 | 0x4041424344454547484900 |
| uint (32bit) | 0x0a0b0c0d  | 0x0c0d0a0b            | 0x0a0b0c0d               |

|           | float      | string                   | uint       |
| ---       | ---        | ---                      | ---        |
| Value     | 3.14       | 'abcdefghi'              | 0x0a0b0c0d |
| FINS rep. | 0xF5C34048 | 0x4241444346454847049    | 0x0c0d0a0b |
| Std rep.  | 0x4048F5C3 | 0x4041424344454547484900 | 0x0a0b0c0d |

