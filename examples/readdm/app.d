import std.stdio;

import dfins.fins;
import dfins.channel;

void main(string[] args) {
   IChannel chan  = createUdpChannel("192.168.221.22", 2000);

   Header h = header(22);
   FinsClient f = new FinsClient(chan, h);

   ubyte[] d0 = f.readArea(MemoryArea.D_WORD, 0, 1);
   writefln("DM000 len %s", d0.length);
   writefln("%( %s %)", d0);

   ubyte[] d1 = f.readArea(MemoryArea.D_WORD, 1, 1);
   writefln("DM001 len %s", d1.length);
   writefln("%( %s %)", d1);
}
