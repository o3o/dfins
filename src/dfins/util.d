/**
 * Utility functions to convert PLC words
 *
 *	Copyright: © 2016-2026 Orfeo Da Vià.
 *	License: Boost Software License - Version 1.0 - August 17th, 2003
 *	Authors: Orfeo Da Vià
 */
module dfins.util;

import std.bitmanip : read;
import std.system : Endian; // for Endian
import std.range;

/**
 * Bytes per each word.
 *
 * A word is a $(D ushort), so each word has 2 bytes.
 */
enum BYTES_PER_WORD = 2;

/**
 * Converts an array of type T into an ubyte array.
 *
 * Omron stores data in LittleEndian format.
 *
 * Params:
 *   input = array of type T to convert
 *
 * Returns: An array of ubyte
 */
ubyte[] toBytes(T)(T[] input) {
   import std.array : appender;
   import std.bitmanip : append;

   auto buffer = appender!(const(ubyte)[])();
   foreach (dm; input) {
      buffer.append!(T, Endian.littleEndian)(dm);
   }
   return buffer.data.dup;
}
///
unittest {
   assert([0x8034].toBytes!ushort() == [0x34, 0x80]);
   ushort[] buf = [0x8034, 0x2010];
   assert(buf.toBytes!ushort() == [0x34, 0x80, 0x10, 0x20]);
   assert(buf.length == 2);

   assert([0x8034].toBytes!uint() == [0x34, 0x80, 0, 0]);
   assert([0x010464].toBytes!uint() == [0x64, 0x04, 1, 0]);
}

/**
 * Converts an array of bytes into wordd $(D ushort) array.
 *
 * Params:  bytes = array to convert
 *
 * Returns: An ushort array that rapresents words
 */
ushort[] toWords(ubyte[] bytes) {
   ushort[] dm;
   while (bytes.length >= BYTES_PER_WORD) {
      dm ~= bytes.read!(ushort, Endian.littleEndian);
   }
   if (bytes.length > 0) {
      dm ~= bytes[0];
   }
   return dm;
}

///
unittest {
   assert([0x10].toWords() == [0x10]);
   assert([0, 0xAB].toWords() == [0xAB00]);
   assert([0x20, 0x0].toWords() == [0x20]);
   assert([0x10, 0x20, 0x30, 0x40, 0x50].toWords() == [0x2010, 0x4030, 0x50]);
}

/**
 * Takes an array of word $(D ushort) and converts the first $(D T.sizeof / 2)
 * word to $(D T).
 * The array is $(B not) consumed.
 *
 * Params:
 *  T = The integral type to convert the first `T.sizeof / 2` words to.
 *  words = The array of word to convert
 */
T peek(T)(ushort[] words) {
   return peek!T(words, 0);
}
///
unittest {
   ushort[] words = [0x645A, 0x3ffb];
   assert(words.peek!float == 1.964F);
   assert(words.length == 2);

   ushort[] odd = [0x645A, 0x3ffb, 0xffaa];
   assert(odd.peek!float == 1.964F);
   assert(odd.length == 3);
}

/**
 * Takes an array of word ($(D ushort)) and converts the first $(D T.sizeof / 2)
 * word to $(D T) starting from index `index`.
 *
 * The array is $(B not) consumed.
 *
 * Params:
 *  T = The integral type to convert the first `T.sizeof / 2` word to.
 *  words = The array of word to convert
 *  index = The index to start reading from (instead of starting at the front).
 */
T peek(T)(ushort[] words, size_t index) {
   import std.bitmanip : peek;

   ubyte[] buffer = toBytes(words);
   return buffer.peek!(T, Endian.littleEndian)(index * BYTES_PER_WORD);
}
///
unittest {
   assert([0x645A, 0x3ffb].peek!float(0) == 1.964F);
   assert([0, 0, 0x645A, 0x3ffb].peek!float(2) == 1.964F);
   assert([0, 0, 0x645A, 0x3ffb].peek!float(0) == 0);
   assert([0x80, 0, 0].peek!ushort(0) == 128);
   assert([0xFFFF].peek!short(0) == -1);
   assert([0xFFFF].peek!ushort(0) == 65_535);
   assert([0xFFF7].peek!ushort(0) == 65_527);
   assert([0xFFF7].peek!short(0) == -9);
   assert([0xFFFB].peek!short(0) == -5);
   assert([0xFFFB].peek!ushort(0) == 65_531);
   assert([0x8000].peek!short(0) == -32_768);
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
 * Takes an input range of words ($(D ushort)) and converts the first $(D T.sizeof / 2)
 * words to $(D T).
 * The array is consumed.
 *
 * Params:
 *  T = The integral type to convert the first `T.sizeof / 2` word to.
 *  input = The input range of words to convert
 */
T pop(T, R)(ref R input) if ((isInputRange!R) && is(ElementType!R : const ushort)) {
   import std.traits : isIntegral, isSigned;

   static if (isIntegral!T) {
      return popInteger!(R, T.sizeof / 2, isSigned!T)(input);
   } else static if (is(T == float)) {
      return uint2float(popInteger!(R, 2, false)(input));
   } else static if (is(T == double)) {
      return ulong2double(popInteger!(R, 4, false)(input));
   } else {
      static assert(false, "Unsupported type " ~ T.stringof);
   }
}

/**
 * $(D pop!float) example
 */
unittest {
   ushort[] asPeek = [0x645A, 0x3ffb];
   assert(asPeek.pop!float == 1.964F);
   assert(asPeek.length == 0);

   // float.sizeOf is 4bytes => 2 word
   ushort[] input = [0x1eb8, 0xc19d];
   assert(input.length == 2);
   assert(pop!float(input) == -19.64F);
   assert(input.length == 0);

   input = [0x0, 0xBF00, 0x0, 0x3F00];
   assert(input.pop!float == -0.5F);
   assert(pop!float(input) == 0.5F);
}

/**
 * $(D pop!double) examples.
 *
 * A double has size 8 bytes => 4word
 */
unittest {
   ushort[] input = [0x0, 0x0, 0x0, 0x3FE0];
   assert(input.length == 4);

   assert(pop!double(input) == 0.5);
   assert(input.length == 0);

   input = [0x0, 0x0, 0x0, 0xBFE0];
   assert(pop!double(input) == -0.5);

   input = [0x00, 0x01, 0x02, 0x03];
   assert(input.length == 4);
   assert(pop!int(input) == 0x10000);
   assert(input.length == 2);
   assert(pop!int(input) == 0x30002);
   assert(input.length == 0);
}

/**
 * pop!ushort and short examples
 */
unittest {
   ushort[] input = [0xFFFF, 0xFFFF, 0xFFFB, 0xFFFB];
   assert(pop!ushort(input) == 0xFFFF);
   assert(pop!short(input) == -1);
   assert(pop!ushort(input) == 0xFFFB);
   assert(pop!short(input) == -5);
}

unittest {
   ushort[] input = [0x1eb8, 0xc19d, 0x0, 0xBF00, 0x0, 0x3F00, 0x0, 0x0, 0x0, 0x3FE0, 0x0, 0x0, 0x0, 0xBFE0, 0x00,
      0x01, 0x02, 0x03, 0xFFFF, 0xFFFF, 0xFFFB, 0xFFFB];

   assert(pop!float(input) == -19.64F);
   assert(pop!float(input) == -0.5F);
   assert(pop!float(input) == 0.5F);

   assert(pop!double(input) == 0.5);
   assert(pop!double(input) == -0.5);

   assert(pop!int(input) == 0x10000);
   assert(pop!int(input) == 0x30002);

   assert(pop!ushort(input) == 0xFFFF);
   assert(pop!short(input) == -1);
   assert(pop!ushort(input) == 0xFFFB);
   assert(pop!short(input) == -5);
}

unittest {
   ushort[] shortBuffer = [0x645A];
   assert(shortBuffer.length == 1);
   //shortBuffer.pop!float().shouldThrow!Exception;

   ushort[] bBuffer = [0x0001, 0x0002, 0x0003];
   assert(bBuffer.length == 3);

   assert(bBuffer.pop!ushort == 1);
   assert(bBuffer.length == 2);

   assert(bBuffer.pop!ushort == 2);
   assert(bBuffer.length == 1);

   assert(bBuffer.pop!ushort == 3);
   assert(bBuffer.length == 0);
}

/**
 * Takes an input range of words ($(D ushort)) and converts the first `numWords`
 * word's to $(D T).
 * The array is consumed.
 *
 * Params:
 *  R = The integral type of innput range
 *  numWords = Number of words to convert
 *  wantSigned = Get signed value
 *  input = The input range of word to convert
 */
private auto popInteger(R, int numWords, bool wantSigned)(ref R input)
      if ((isInputRange!R) && is(ElementType!R : const ushort)) {
   import std.traits : Signed;

   alias T = IntegerLargerThan!(numWords);
   T result = 0;

   foreach (i; 0 .. numWords) {
      result |= (cast(T)(popDM(input)) << (16 * i));
   }

   static if (wantSigned) {
      return cast(Signed!T)result;
   } else {
      return result;
   }
}

unittest {
   ushort[] input = [0x00, 0x01, 0x02, 0x03];
   assert(popInteger!(ushort[], 2, false)(input) == 0x10000);
   assert(popInteger!(ushort[], 2, false)(input) == 0x30002);
   assert(input.length == 0);

   input = [0x01, 0x02, 0x03, 0x04];
   assert(popInteger!(ushort[], 3, false)(input) == 0x300020001);

   input = [0x01, 0x02];
   //assert(popInteger!(ushort[], 3, false)(input).shouldThrow!Exception;

   input = [0x00, 0x8000];
   assert(popInteger!(ushort[], 2, false)(input) == 0x8000_0000);

   input = [0xFFFF, 0xFFFF];
   assert(popInteger!(ushort[], 2, true)(input) == -1);

   input = [0xFFFF, 0xFFFF, 0xFFFB, 0xFFFB];
   assert(popInteger!(ushort[], 1, false)(input) == 0xFFFF);
   assert(popInteger!(ushort[], 1, true)(input) == -1);
   assert(popInteger!(ushort[], 1, false)(input) == 0xFFFB);
   assert(popInteger!(ushort[], 1, true)(input) == -5);
}

private template IntegerLargerThan(int numWords) if (numWords > 0 && numWords <= 4) {
   static if (numWords == 1) {
      alias IntegerLargerThan = ushort;
   } else static if (numWords == 2) {
      alias IntegerLargerThan = uint;
   } else {
      alias IntegerLargerThan = ulong;
   }
}

private ushort popDM(R)(ref R input) if ((isInputRange!R) && is(ElementType!R : const ushort)) {
   if (input.empty) {
      throw new Exception("Expected a ushort, but found end of input");
   }

   const(ushort) d = input.front;
   input.popFront();
   return d;
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

private void writeInteger(R, int numWords)(ref R output, IntegerLargerThan!numWords n) if (isOutputRange!(R, ushort)) {
   import std.traits : Unsigned;

   alias T = IntegerLargerThan!numWords;
   auto u = cast(Unsigned!T)n;
   foreach (i; 0 .. numWords) {
      immutable(ushort) b = (u >> (i * 16)) & 0xFFFF;
      output.put(b);
   }
}

/**
 * Convert $(D uint) to $(D float)
 */
private float uint2float(uint x) pure nothrow {
   float_uint fi;
   fi.i = x;
   return fi.f;
}

unittest {
   // see http://gregstoll.dyndns.org/~gregstoll/floattohex/
   assert(uint2float(0x24369620) == 3.959212E-17F);
   assert(uint2float(0x3F000000) == 0.5F);
   assert(uint2float(0xBF000000) == -0.5F);
   assert(uint2float(0x0) == 0);
   assert(uint2float(0x419D1EB8) == 19.64F);
   assert(uint2float(0xC19D1EB8) == -19.64F);
   assert(uint2float(0x358637bd) == 0.000001F);
   assert(uint2float(0xb58637bd) == -0.000001F);
}

private uint float2uint(float x) pure nothrow {
   float_uint fi;
   fi.f = x;
   return fi.i;
}

unittest {
   // see http://gregstoll.dyndns.org/~gregstoll/floattohex/
   assert(float2uint(3.959212E-17F) == 0x24369620);
   assert(float2uint(.5F) == 0x3F000000);
   assert(float2uint(-.5F) == 0xBF000000);
   assert(float2uint(0x0) == 0);
   assert(float2uint(19.64F) == 0x419D1EB8);
   assert(float2uint(-19.64F) == 0xC19D1EB8);
   assert(float2uint(0.000001F) == 0x358637bd);
   assert(float2uint(-0.000001F) == 0xb58637bd);
}

// read/write 64-bits float
private union float_uint {
   float f;
   uint i;
}

double ulong2double(ulong x) pure nothrow {
   double_ulong fi;
   fi.i = x;
   return fi.f;
}

unittest {
   // see http://gregstoll.dyndns.org/~gregstoll/floattohex/
   assert(ulong2double(0x0) == 0);
   assert(ulong2double(0x3fe0000000000000) == 0.5);
   assert(ulong2double(0xbfe0000000000000) == -0.5);
}

private ulong double2ulong(double x) pure nothrow {
   double_ulong fi;
   fi.f = x;
   return fi.i;
}

unittest {
   // see http://gregstoll.dyndns.org/~gregstoll/floattohex/
   assert(double2ulong(0) == 0);
   assert(double2ulong(0.5) == 0x3fe0000000000000);
   assert(double2ulong(-0.5) == 0xbfe0000000000000);
}

private union double_ulong {
   double f;
   ulong i;
}
