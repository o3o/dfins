import std.stdio;

import dfins.fins;
import dfins.channel;
import dfins.util;

void main(string[] args) {
   import std.bitmanip: read, nativeToBigEndian;
   IChannel chan = createUdpChannel("192.168.22.2", 2000);
   Header h = header(2, 1);
   FinsClient f = new FinsClient(chan, h);

   //FinsClient f = createFinsClient("192.168.22.2", 2000);
   if (args.length > 1) {
      if (args[1] == "r0") {
         ubyte[] d0 = f.readArea(MemoryArea.DM, 0, 1);
         writefln("DM000: %( 0x%x %)", d0);
      }  else if (args[1] == "r1") {
         ubyte[] d1 = f.readArea(MemoryArea.DM, 1, 1);
         ubyte[] d2 = f.readArea(MemoryArea.DM, 1, 1);
         writefln("DM001: %( 0x%x %)", d1);
         writefln("DM001 fins: 0x%x ", d1.readFins!ushort);
         writefln("DM001     : 0x%x ", d2.read!ushort);
      }  else if (args[1] == "r1100") {
         ubyte[] d1 = f.readArea(MemoryArea.DM, 1100, 1);
         ubyte[] d2 = f.readArea(MemoryArea.DM, 1100, 1);
         writefln("DM1100: %( 0x%x %)", d1);
         writefln("DM1100 fins: 0x%x ", d1.readFins!ushort);
         writefln("DM1100     : 0x%x ", d2.read!ushort);
      }  else if (args[1] == "w0") {
         ushort v = 0x0a0b;
         f.writeArea(MemoryArea.DM, 0, nativeToBigEndian!ushort(v));
         ubyte[] dr0 = f.readArea(MemoryArea.DM, 0, 1);
         ubyte[] dr1 = f.readArea(MemoryArea.DM, 0, 1);
         writefln("DM000. byte0:0x%x byte1:0x%x", dr0[0], dr0[1]);
         writefln("DM000 fins: 0x%x ", dr0.readFins!ushort);
         writefln("DM000     : 0x%x ", dr1.read!ushort);
      }  else if (args[1] == "r100") {
         ubyte[] d100 = f.readArea(MemoryArea.DM, 100, 1);
         ubyte[] d101 = f.readArea(MemoryArea.DM, 100, 1);
         writefln("DM100. byte0:0x%x byte1:0x%x", d100[0], d100[1]);
         writefln("DM100: %( 0x%x %)", d100);
         writefln("DM100 fins: 0x%x ", d100.readFins!ushort);
         writefln("DM100     : 0x%x ", d101.read!ushort);
      }  else if (args[1] == "f") {
         import dfins.util: swapByteOrder;
         ubyte[] f2 = f.readArea(MemoryArea.DM, 30_002, 2); // 4 bytes --> 2DM
         ubyte[] flotta = f2.swapByteOrder!4; // 4 bytes --> 2DM
         writefln("DM30_002: %( 0x%x %)", flotta);
         writefln("DM30_002 fins: %s", f2.readFins!float);
         writefln("DM30_002     : %s", flotta.read!float);
      }  else if (args[1] == "wf") {
         import std.conv : to;
         float ff = args[2].to!float;
         ubyte[] v = nativeToBigEndian!float(ff).swapByteOrder;
         f.writeArea(MemoryArea.DM, 32_002, v);
         writefln("DM32_002: %( 0x%x %)", v);
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
   writeln("\tr1100: read D1100");
   writeln("\tw0: write 0x0a0b into D00");
   writeln("\tf: read 32_000 as float");
   writeln("\twf x: write x into 32_000 as float");
}
