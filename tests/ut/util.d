module ut.util;

import dfins.util;
import std.experimental.logger;
import std.typecons : Flag, Yes, No;
import unit_threaded;


@("readFins")
unittest {
   import std.bitmanip : read;
   import std.math : approxEqual;

   // dfmt off
   ubyte[] buf = [
      0x0, 0x10,
      0xF5, 0xC3, 0x40, 0x48, // 3.14
      0x1E, 0xB8, 0x41, 0x9D, // 19.64
      0xF5, 0xC3, 0x40, 0x48, // 1_078_523_331
      0xF5, 0xC3, 0x40, 0x48, // 1_078_523_331
      0x0A, 0x3D, 0xBF, 0xB7,
      0x0C, 0x0D, 0x0A, 0xB // 0x0a0b0c0d
   ];
   // dfmt on

   buf.readFins!ushort.should == 0x10;
   buf.readFins!float.shouldApproxEqual(3.14);
   buf.readFins!float.shouldApproxEqual(19.64);

   buf.readFins!uint.should == 1_078_523_331;
   buf.readFins!int.should  == 1_078_523_331;
   buf.readFins!int.should == -1_078_523_331;
   buf.readFins!uint.should == 0x0a0b0c0d;
}
@("readStringZ")
unittest {
   ubyte[] abc00 = [0x42, 0x41, 0x0, 0x43, 0x46, 0x45, 0x48, 0x47, 0x0, 0x49];
   string s0 = abc00.readStringz!10;
   abc00.length.should == 0;
   s0.length.should == 3;
   s0.should == "ABC";

   ubyte[] abc01 = [0x42, 0x41, 0x0, 0x43];
   string s1 = abc01.readStringz!10;
   s1.length.should == 3;
   s1.should == "ABC";

   ubyte[] abc02 = [0x42, 0x41, 0x0, 0x0];
   string s2 = abc02.readStringz!10;
   s2.length.should == 2;
   s2.should == "AB";
}

@("PLC2PC")
unittest {
   import std.bitmanip : read;

   // dfmt off
   ubyte[] buf = [
      0x0, 0x10,
      0x40, 0x48, 0xF5, 0xC3, // 3.14
      0x41, 0x9D, 0x1E, 0xB8, // 19.64
      0xF5, 0xC3, 0x40, 0x48,
   ];
   // dfmt on
   buf.read!ushort.should == 0x10;
   buf.read!float.shouldApproxEqual( 3.14);
   buf.read!float.shouldApproxEqual(19.64);
}

@("PC2PLC")
unittest {
   import std.bitmanip : nativeToBigEndian;

   nativeToBigEndian!uint(0x8034).should == [0, 0, 0x80, 0x34];
   nativeToBigEndian!uint(0x010464).should == [0x0, 0x01, 0x04, 0x64];

   //0x4048F5C3
   nativeToBigEndian!float(3.14).should == [0x40, 0x48, 0xF5, 0xC3];
   nativeToBigEndian!float(3.14).should == [0x40, 0x48, 0xF5, 0xC3];
   //0x419D1EB8
   nativeToBigEndian!float(19.64).should == [0x41, 0x9D, 0x1E, 0xB8];
}
@("nativeToFins")
unittest {
   import std.bitmanip : nativeToBigEndian;
   import std.algorithm.comparison : equal;
   import core.bitop;
   import std.conv: to;

   ubyte[] abcFins = [0x42, 0x41, 0x44, 0x43, 0x46, 0x45, 0x48, 0x47, 0x0, 0x49];
   nativeToFins!string("ABCDEFGHI").should == abcFins;


   nativeToFins!float(3.14).should == [0xf5, 0xc3, 0x40, 0x48];
   //0x0a0b0c0d = 168_496_141
   nativeToFins!uint(0x0a0b0c0d).should == [0x0c, 0x0d, 0x0a, 0xb];
   nativeToFins!ushort(0x0a0b).should == [0x0a, 0x0b];
   (cast(ubyte[])nativeToBigEndian!ushort(0x0a0b)).should == [0xa, 0xb];

   size_t e;
   bts(&e, cast(size_t)0);
   ubyte[] ea = nativeToFins!ushort(e.to!ushort);
   ea.length.should == 2;
   ea[0].should == 0;
   ea[1].should == 1;
}
