import std.stdio;

import dfins.fins;
import dfins.channel;

void main(string[] args) {
   IChannel chan  = createUdpChannel("192.168.221.22", 2000);
   FinsClient f = new FinsClient(chan);
   f.sa1 = 22;
   f.sna = 0;
   f.da1 = 2;
   f.dna = 0;

   ubyte[] d0 = f.readArea(MemoryArea.D_WORD, 0, 1);
   writefln("len %s", d0.length);
   writefln("%( %s %)", d0);
}
