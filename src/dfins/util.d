/**
 * Utility functions to convert PLC words
 *
 *	Copyright: © 2016-2026 Orfeo Da Vià.
 *	License: Boost Software License - Version 1.0 - August 17th, 2003
 *	Authors: Orfeo Da Vià
 */
module dfins.util;

import std.range;
import std.system : Endian;

/**
 * Bytes per each word.
 *
 * A word is a $(D ushort), so each word has 2 bytes.
 */
enum BYTES_PER_WORD = 2;

/**
 * Converts an array of type T into an ubyte array using BigEndian.
 *
 * Params:
 *   input = array of type T to convert
 *
 * Returns:
 *   An array of ubyte
 */
deprecated("Will be removed, use nativeToBigEndian") ubyte[] toBytes(T)(T[] input) {
   import std.array : appender;
   import std.bitmanip : append;

   auto buffer = appender!(const(ubyte)[])();
   foreach (dm; input) {
      buffer.append!(T, Endian.bigEndian)(dm);
   }
   return buffer.data.dup;
}
///
unittest {
   import std.bitmanip : nativeToBigEndian;

   assert([0x8034].toBytes!ushort() == [0x80, 0x34]);
   ushort[] buf = [0x8034, 0x2010];
   assert(buf.toBytes!ushort() == [0x80, 0x34, 0x20, 0x10]);
   assert(buf.length == 2);

   //import std.stdio;
   //writefln("%( 0x%x %)", [0x8034].toBytes!uint());
   assert([0x8034].toBytes!uint() == [0, 0, 0x80, 0x34]);
   assert([0x010464].toBytes!uint() == [0x0, 0x01, 0x04, 0x64]);
   assert(nativeToBigEndian!uint(0x8034) == [0, 0, 0x80, 0x34]);
   assert(nativeToBigEndian!uint(0x010464) == [0x0, 0x01, 0x04, 0x64]);
}

/**
 * Converts ushort value into BDC format
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
 * Converts BCD value into decimal format
 *
 * Params:
 *  bcd = ushort in BCD format
 *
 * Returns: decimal value
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
 * Takes an input range of ubyte ($(D ushort)) and converts the first $(D T.sizeof)
 * words to $(D T).
 * The array is consumed.
 *
 * Params:
 *  T = The type to convert the first `T.sizeof` o.
 *  input = The input range of ubyte to convert
 */
T readFins(T, R)(ref R input) if ((isInputRange!R) && is(ElementType!R : const ubyte)) {
   import std.bitmanip : read, bigEndianToNative;
   import std.algorithm.mutation : swapAt;

   static if (is(T == int) || is(T == uint) || is(T == float))  {
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

unittest {
   import std.bitmanip : read;
   import std.math : approxEqual;

   // dfmt off
   ubyte[] buf = [
      0x0, 0x10,
      0xF5, 0xC3, 0x40, 0x48, // 3.14
      0x1E, 0xB8, 0x41, 0x9D // 19.64
   ];
   // dfmt on
   assert(buf.readFins!ushort == 0x10);
   assert(approxEqual(buf.readFins!float, 3.14));
   assert(approxEqual(buf.readFins!float, 19.64));
}


/**
 * Writes numeric type $(I T) into a output range of $(D ushort).
 *
 * Params:
 *  n = The numeric type to write into output range
 *  output = The output range of word to convert
 *
 * Examples:
 * --------------------
 * ushort[] arr;
 * auto app = appender(arr);
 * write!float(app, 1.0f);
 *
 * auto app = appender!(const(ushort)[]);
 * app.write!ushort(5);
 * app.data.shouldEqual([5]);
 * --------------------
 */
void write(T, R)(ref R output, T n) if (isOutputRange!(R, ushort)) {
   import std.traits : isIntegral;

   static if (isIntegral!T) {
      writeInteger!(R, T.sizeof / 2)(output, n);
   } else static if (is(T == float)) {
      writeInteger!(R, 2)(output, float2uint(n));
   } else static if (is(T == double)) {
      writeInteger!(R, 4)(output, double2ulong(n));
   } else {
      static assert(false, "Unsupported type " ~ T.stringof);
   }
}

/+
/**
 * Write float and double
 */
unittest {
   ushort[] arr;
   auto app = appender(arr);
   write!float(app, 1.0f);

   app.write!double(2.0);

   ushort[] expected = [0, 0x3f80, 0, 0, 0, 0x4000];
   assert(app.data == expected);
}

/**
 * Write ushort and int
 */
unittest {
   import std.array : appender;

   auto app = appender!(const(ushort)[]);
   app.write!ushort(5);
   assert(app.data == [5]);

   app.write!float(1.964F);
   assert(app.data == [5, 0x645A, 0x3ffb]);

   app.write!uint(0x1720_8034);
   assert(app.data == [5, 0x645A, 0x3ffb, 0x8034, 0x1720]);
}
+/

private void writeInteger(R, int numWords)(ref R output, IntegerLargerThan!numWords n) if (isOutputRange!(R, ushort)) {
   import std.traits : Unsigned;

   alias T = IntegerLargerThan!numWords;
   auto u = cast(Unsigned!T)n;
   foreach (i; 0 .. numWords) {
      immutable(ushort) b = (u >> (i * 16)) & 0xFFFF;
      output.put(b);
   }
}

@("PC2PLC")
unittest {
   import std.bitmanip : nativeToBigEndian;

   assert(nativeToBigEndian!uint(0x8034) == [0, 0, 0x80, 0x34]);
   assert(nativeToBigEndian!uint(0x010464) == [0x0, 0x01, 0x04, 0x64]);

   //0x4048F5C3
   assert(nativeToBigEndian!float(3.14) == [0x40, 0x48, 0xF5, 0xC3]);
   //0x419D1EB8
   assert(nativeToBigEndian!float(19.64) == [0x41, 0x9D, 0x1E, 0xB8]);
}

@("PLC2PC")
unittest {
   import std.bitmanip : read;
   import std.math : approxEqual;

   // dfmt off
   ubyte[] buf = [
      0x0, 0x10,
      0x40, 0x48, 0xF5, 0xC3, // 3.14
      0x41, 0x9D, 0x1E, 0xB8, // 19.64
      0xF5, 0xC3, 0x40, 0x48,
   ];
   // dfmt on
   //assert(buf.peek!ushort == 0x10);
   assert(buf.read!ushort == 0x10);
   assert(approxEqual(buf.read!float, 3.14));
   assert(approxEqual(buf.read!float, 19.64));
   //assert(approxEqual(buf.read!float, 3.14));
}

/**
 * Swap byte order of items in an array in place.
 *
 * Params:
 *  L = Lenght
 *  array = Buffer with values to fix byte order of.
 */
ubyte[] swapByteOrder(int L = 4)(ubyte[] data) @trusted pure nothrow if (L == 2 || L == 4 || L == 0) {
   import std.algorithm.mutation : swapAt;
   ubyte[] array = data.dup;

   size_t ptr;
   static if (L == 2) {
      while (ptr < array.length - 1) {
         array.swapAt(ptr, ptr + 1);
         ptr += 2;
      }
   } else static if (L == 4) {
      while (ptr < array.length - 3) {
         array.swapAt(ptr + 0, ptr + 2);
         array.swapAt(ptr + 1, ptr + 3);
         ptr += 4;
      }
   }
   return array;
}

unittest {
   import std.algorithm.comparison : equal;

   ubyte[] a = [0xF5, 0xC3, 0x40, 0x48, 0xFF];

   assert(a.swapByteOrder.equal([0x40, 0x48, 0xF5, 0xc3, 0xFF]));
   assert(a.swapByteOrder!(2).equal([0xc3, 0xF5, 0x48, 0x40, 0xFF]));
}
