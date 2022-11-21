/**
 * Utility functions to convert PLC words.
 *
 *	Copyright: © 2016-2026 Orfeo Da Vià.
 *	License: Boost Software License - Version 1.0 - August 17th, 2003
 *	Authors: Orfeo Da Vià
 */
module dfins.util;

import std.range;
import std.system : Endian;

/**
 * Converts ushort value into BDC format.
 *
 * Params:
 *  dec = ushort in decimal format
 *
 * Returns: BCD value
 */
ushort toBCD(ushort dec) {
   enum ushort MAX_VALUE = 9999;
   enum ushort MIN_VALUE = 0;
   if ((dec > MAX_VALUE) || (dec < MIN_VALUE)) {
      throw new Exception("Decimal out of range (should be 0..9999)");
   } else {
      ushort bcd;
      enum ushort NUM_BASE = 10;
      ushort i;
      for (; dec > 0; dec /= NUM_BASE) {
         ushort rem = cast(ushort)(dec % NUM_BASE);
         bcd += cast(ushort)(rem << 4 * i++);
      }
      return bcd;
   }
}

///
unittest {
   assert(0.toBCD() == 0);
   assert(10.toBCD() == 0x10);
   assert(34.toBCD() == 52);
   assert(127.toBCD() == 0x127);
   assert(110.toBCD() == 0x110);
   assert(9999.toBCD() == 0x9999);
   assert(9999.toBCD() == 39_321);
}

/**
 * Converts BCD value into decimal format.
 *
 * Params:
 *  bcd = ushort in BCD format.
 *
 * Returns: decimal value.
 */
ushort fromBCD(ushort bcd) {
   enum int NO_OF_DIGITS = 8;
   enum ushort MAX_VALUE = 0x9999;
   enum ushort MIN_VALUE = 0;
   if ((bcd > MAX_VALUE) || (bcd < MIN_VALUE)) {
      throw new Exception("BCD out of range (should be 0..39321)");
   } else {
      ushort dec;
      ushort weight = 1;
      foreach (j; 0 .. NO_OF_DIGITS) {
         dec += cast(ushort)((bcd & 0x0F) * weight);
         bcd = cast(ushort)(bcd >> 4);
         weight *= 10;
      }
      return dec;
   }
}
///
unittest {
   assert(0.fromBCD() == 0);
   assert((0x22).fromBCD() == 22);
   assert((34).fromBCD() == 22);
   // 17bcd
   assert((0b0001_0111).fromBCD() == 17);
   assert(295.fromBCD() == 127);
   assert(39_321.fromBCD() == 9_999);
   assert((0x9999).fromBCD() == 9_999);
}

/**
 * Takes an input range of ubyte and converts the first $(D T.sizeof)
 * bytes to $(D T).
 * The array is consumed.
 *
 * Params:
 *  T = The type to convert the first `T.sizeof` bytes.
 *  input = The input range of ubyte to convert.
 */
T readFins(T, R)(ref R input) if ((isInputRange!R) && is(ElementType!R : const ubyte)) {
   import std.algorithm.mutation : swapAt;
   import std.bitmanip : read, bigEndianToNative;

   static if (is(T == int) || is(T == uint) || is(T == float)) {
      ubyte[T.sizeof] bytes;
      foreach (ref e; bytes) {
         e = input.front;
         input.popFront();
      }
      bytes.swapAt(0, 2);
      bytes.swapAt(1, 3);
      return bigEndianToNative!T(bytes);
   } else static if (is(T == double)) {
      static assert(false, "Unsupported type " ~ T.stringof);
   } else {
      return input.read!(T);
   }
}

/**
 * Takes an input range of ubyte and converts the first $(D L) bytes to string.
 *
 * L must be even.
 * The array is consumed.
 *
 * Params:
 *  L = The number of bytes to convert. L $(B must be) even and will be converted only ascii char
 *  input = The input range of ubyte to convert
 */
string readString(size_t L, R)(ref R input) if ((isInputRange!R) && is(ElementType!R : const ubyte) && !(L & 1)) {
   import std.algorithm.iteration : filter;
   import std.array : array;

   ubyte[] stream = readSwap!(L)(input).filter!(a => a > 0x1F && a < 0x7F).array;
   return cast(string)stream;
}

///
unittest {
   ubyte[] abc00 = [0x42, 0x41, 0x44, 0x43, 0x46, 0x45, 0x48, 0x47, 0x0, 0x49];
   string s0 = abc00.readString!10;
   assert(s0.length == 9);
   assert(s0 == "ABCDEFGHI");

   ubyte[] abc01 = [0x42, 0x41, 0x44, 0x43, 0x46, 0x45, 0x48, 0x47, 0x0, 0x49];
   string s1 = abc01.readString!40;
   assert(s1.length == 9);
   assert(s1 == "ABCDEFGHI");

   ubyte[] abc02 = [0x42, 0x41, 0x44, 0x43, 0x46, 0x45, 0x48, 0x47, 0x0, 0x49];
   string s2 = abc02.readString!4;
   assert(s2.length == 4);
   assert(s2 == "ABCD");
   assert(abc02.readString!2 == "EF");
   assert(abc02.readString!4 == "GHI");

   ubyte[] abc03 = [0x42, 0x41, 0x00, 0x00, 0x00, 0x00, 0x48, 0x47, 0x0, 0x49];
   string s3 = abc03.readString!4;
   assert(s3 == "AB");

   ubyte[] abc04 = [0x62, 0x61, 0x01, 0x01, 0x02, 0xFF, 0x68, 0x67, 0x0, 0x49];
   assert(abc04.length == 10);
   // read 4 byte, but only two are valid ascii char.
   assert(abc04.readString!4 == "ab");
   assert(abc04.length == 6);

   ubyte[] abc05 = [0x42, 0x41, 0x00,  0x44, 0x43, 0x45];
   //import std.stdio;
   //writeln(abc05.readString!6 );
   assert(abc05.readString!6 == "ABDEC");
}

/**
 * Takes an input range of ubyte and converts the first $(D L) bytes or until null terminator is found, to string.
 *
 * L must be even.
 * The array is consumed.
 *
 * Params:
 *  L = The number of bytes to convert. L $(B must be) even and will be converted only ascii char
 *  input = The input range of ubyte to convert
 */
string readStringz(size_t L, R)(ref R input) if ((isInputRange!R) && is(ElementType!R : const ubyte) && !(L & 1)) {
   import std.algorithm.searching  : until;
   ubyte[] stream = readSwap!(L)(input).until(0x0).array;
   return cast(string)stream;
}

/**
 * Takes an input range of ubyte and swap the first $(D L) bytes.
 *
 * L must be even.
 * The array is consumed.
 *
 * Params:
 *  L = The number of bytes to convert. L $(B must be) even and will be converted only ascii char
 *  input = The input range of ubyte to convert
 */
ubyte[] readSwap(size_t L, R)(ref R input) if ((isInputRange!R) && is(ElementType!R : const ubyte) && !(L & 1)) {
   ubyte[] bytes = new ubyte[](L);

   foreach (ref e; bytes) {
      if (input.empty) {
         break;
      }
      e = input.front;
      input.popFront();
   }
   bytes.swapBy!2;
   return bytes;
}
///
unittest {
   ubyte[] blob0 = [0x42, 0x41, 0x00,  0x44, 0x43, 0x45];
   assert(blob0.readSwap!6 == [0x41, 0x42, 0x44,  0x00, 0x45, 0x43]);
   assert(blob0.length == 0);
   ubyte[] blob1 = [0x42, 0x41, 0x00,  0x44, 0x43, 0x45];
   assert(blob1.readSwap!2 == [0x41, 0x42]);
   assert(blob1.length == 4);
}

/**
 * Converts the given value from the native endianness to Fins format and
 * returns it as a `ubyte[n]` where `n` is the size of the given type.
 *
 * Params:
 *  T = Value type.
 *  val = Value to be converted.
 */
ubyte[] nativeToFins(T)(T val) pure nothrow {
   import std.algorithm.mutation : swapAt;
   import std.bitmanip : nativeToBigEndian;

   static if (is(T == int) || is(T == uint) || is(T == float)) {
      ubyte[] bytes = nativeToBigEndian!T(val).dup;
      bytes.swapAt(0, 2);
      bytes.swapAt(1, 3);
      return bytes;
   } else static if (is(T == string)) {
      ubyte[] blob = cast(ubyte[])val;
      if (blob.length & 1) {
         blob ~= 0x0;
      }
      blob.swapBy!2;
      return blob;
   } else static if (is(T == double)) {
      static assert(false, "Unsupported type " ~ T.stringof);
   } else {
      return nativeToBigEndian!T(val).dup;
   }
}

/**
 * Swap byte order of items in an array.
 *
 * Params:
 *  L = Lenght.
 *  data = Buffer to swap.
 */
void swapBy(int L = 2)(ref ubyte[] data) @trusted pure nothrow if (L == 2 || L == 4) {
   import std.algorithm.mutation : swapAt;
   import std.range : chunks;

   if (data.length) {
      auto cs = chunks(data, L);
      static if (L == 2) {
         foreach (c; cs) {
            if (c.length >= L) {
               c.swapAt(0, 1);
            }
         }
      } else static if (L == 4) {
         foreach (c; cs) {
            if (c.length >= L) {
               c.swapAt(0, 2);
               c.swapAt(1, 3);
            }
         }
      }
   }
}

///
unittest {
   import std.algorithm.comparison : equal;

   ubyte[] a = [0xF5, 0xC3, 0x40, 0x48, 0xff];
   swapBy!4(a);
   assert(a.equal([0x40, 0x48, 0xF5, 0xc3, 0xFF]));

   ubyte[] b = [0xF5, 0xC3, 0x40, 0x48, 0xff];
   b.swapBy!2;
   assert(b.equal([0xc3, 0xF5, 0x48, 0x40, 0xFF]));

   ubyte[] e;
   swapBy(e);
   assert(e.length == 0);
}
