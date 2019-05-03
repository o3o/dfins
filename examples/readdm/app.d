import std.stdio;

import dfins.fins;
import dfins.channel;
import dfins.util;

void main(string[] args) {
   IChannel chan = createUdpChannel("192.168.221.22", 2000);

   Header h = header(22);
   FinsClient f = new FinsClient(chan, h);

   ubyte[] d0 = f.readArea(MemoryArea.D_WORD, 0, 1);
   writefln("DM000: %( 0x%x %)", d0.toWords);

   ubyte[] d1 = f.readArea(MemoryArea.D_WORD, 1, 1);
   writefln("DM001: %( 0x%x %)", d1.toWords);

   ushort[] v = [0x64];
   f.writeArea(MemoryArea.D_WORD, 0, v.toBytes!ushort);
   writefln("DM000: %( 0x%x %)", f.readArea(MemoryArea.D_WORD, 0, 1).toWords);

   //v[0] = 0;
   //f.writeArea(MemoryArea.D_WORD, 0, v.toBytes!ushort);
}
