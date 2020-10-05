import std.stdio;

import std.getopt;
import dfins.fins;
import dfins.channel;
import dfins.util;

void main(string[] args) {
   import std.bitmanip: read;
   import std.string : strip;
   import std.stdio, std.regex;
   import std.conv : to;
   string ip = "192.168.22.2";
   ubyte sa1 = 1;

   auto opt = getopt(args,
         "ip", "IP", &ip,
         "s", "source node number address", &sa1
         );
   if (opt.helpWanted) {
      defaultGetoptPrinter("Fins client", opt.options);
   } else {
      FinsClient f = createFinsClient(ip, 2000, 9600, sa1);
      writefln("Fins client ip %s sa1 %s", ip, sa1);

      string s = readln().strip;
      while ( s != "q") {
         auto mr = matchFirst(s, r"r\s*([0-9]+)$");
         auto md = matchFirst(s, r"rd\s*([0-9]+)$");
         auto mf = matchFirst(s, r"rf\s*([0-9]+)$");
         auto mw = matchFirst(s, r"w\s*([0-9]+)\s+([0-9]+)$");
         if (mr) {
            ushort addr = mr[1].to!ushort;
            ubyte[] d0 = f.readArea(MemoryArea.DM, addr, 1);
            writefln("%( 0x%x %)", d0);
            writefln(">D%s %d", addr, d0.readFins!ushort);
         } else if (md) {
            ushort addr = md[1].to!ushort;
            ubyte[] d0 = f.readArea(MemoryArea.DM, addr, 1);
            writefln("%( 0x%x %)", d0);
            writefln(">BCD%s %d", addr, d0.readFins!ushort.toBCD);
         } else if (mf) {
            ushort addr = mf[1].to!ushort;
            ubyte[] d0 = f.readArea(MemoryArea.DM, addr, 2);
            writefln(">D%s %d", addr, d0.readFins!float);
         } else if (mw) {
            import std.bitmanip : nativeToBigEndian;
            ushort addr = mw[1].to!ushort;
            short val = mw[2].to!short;
            f.writeArea(MemoryArea.DM, addr, nativeToBigEndian!short(val));
            writefln(">W%s %s", addr, val);
         } else {
            writefln("%s???", s);
         }

         s = readln().strip;
      }
   }
}

void help() {
   writeln("USE:");
   writeln("\tr0: read D000");
   writeln("\tr1: read D001");
   writeln("\tr100: read D100");
   writeln("\tr1100: read D1100");
   writeln("\tw0: write 0x0a0b into D00");
}
