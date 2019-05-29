import std.stdio;

import dfins.fins;
import dfins.channel;
import dfins.util;

void main(string[] args) {
   //IChannel chan = createUdpChannel("192.168.221.22", 2000);
   //Header h = header(22);
   //FinsClient f = new FinsClient(chan, h);

   FinsClient f = createFinsClient("192.168.221.22", 2000);
   if (args.length > 1) {
      if (args[1] == "r0") {
         ubyte[] d0 = f.readArea(MemoryArea.DM, 0, 1);
         writefln("DM000: %( 0x%x %)", d0.toWords);
      }  else if (args[1] == "r1") {
         ubyte[] d1 = f.readArea(MemoryArea.DM, 1, 1);
         writefln("DM001: %( 0x%x %)", d1.toWords);
      }  else if (args[1] == "w0") {
         ushort[] v = [0x0a0b];
         f.writeArea(MemoryArea.DM, 0, v.toBytes!ushort);
         ubyte[] dr0 = f.readArea(MemoryArea.DM, 0, 1);
         writefln("DM000. byte0:0x%x byte1:0x%x", dr0[0], dr0[1]);
         writefln("DM000: %( 0x%x %)", dr0.toWords);
      }  else if (args[1] == "r100") {
         ubyte[] d100 = f.readArea(MemoryArea.DM, 100, 1);
         writefln("DM100. byte0:0x%x byte1:0x%x", d100[0], d100[1]);
         writefln("DM100: %( 0x%x %)", d100.toWords);
      } else {
         help;
      }
   } else {
      help;
   }
}

void help() {
   writeln("USE:");
   writeln("\tr0: read D000");
   writeln("\tr1: read D001");
   writeln("\tr100: read D100");
   writeln("\tw0: write 0x0a0b into D00");
}
