/**
 * Fins client.
 *
 * There are two command systems that can be used for communications with CV-series PLCs.
 * The first system is the C-series command system, which can be
 * used within any one local network. The other system is the CV-series command
 * system, which uses FINS commands.
 * The structure of C-series commands, also called C-mode commands, differs
 * depending on the type of network in which they are used, and thus do not allow
 * communications to remote networks. FINS commands, also called CV-mode
 * commands, do allow internetwork communications between network PLCs or
 * computer nodes. This library implements the FINS command system.
 *
 *	Copyright: © 2016-2026 Orfeo Da Vià.
 *	License: Boost Software License - Version 1.0 - August 17th, 2003
 *	Authors: Orfeo Da Vià
 */
module dfins.fins;

import dfins.channel;

/**
 * Fins protocol exception.
 */
class FinsException : Exception {
   /**
    * Constructor which takes two error codes.
    *
    * Params:
    *  mainCode = Main error code
    *  subCode = Sub error code
    *  file = Fine name
    *  line = Line number
    */
   this(ubyte mainCode, ubyte subCode, string file = null, size_t line = 0) @trusted {
      _mainCode = mainCode;
      _subCode = subCode;
      import std.string : format;

      super("Fins error %s".format(mainErrToString(_mainCode)));
   }

   private ubyte _mainCode;
   /**
    * Main error code
    */
   ubyte mainCode() {
      return _mainCode;
   }

   private ubyte _subCode;
   /**
    * Sub error code
    */
   ubyte subCode() {
      return _subCode;
   }
}

/**
 * Memory area code.
 *
 * See page 15 of $(I FINS Commands reference manual)
 */
enum MemoryArea : ubyte {
   CIO_BIT = 0x30,
   W_BIT = 0x31,
   H_BIT = 0x32,
   A_BIT = 0x33,
   D_BIT = 0x02,
   /**
    * CIO Channel IO area, word
    */
   IO = 0xB0,
   /**
    * WR Work area, word
    */
   WR = 0xB1,
   /*
    * HR Holding area, word
    */
   HR = 0xB2,
   /**
    * AR Auxiliary Relay area, word
    */
   AR = 0xB3,
   /**
    * DM Data Memory area, word
    */
   DM = 0x82,
   /**
    * CNT, Counter area, word
    */
   CT = 0x89
}

///
enum FINS_HEADER_LEN = 12;

///
struct Header {
   /**
    * Information Control Field, set to 0x80
    */
   ubyte icf = 0x80;
   //ubyte rsv;//reserved, set to 0x00
   //ubyte gct = 0x02;//gateway count, set to 0x02
   /**
    * Destination network address, 0x0 local , 0x01 if there are not network intermediaries
    */
   ubyte dna;
   /**
    * Destination node number.
    *
    * If set to default this is the subnet byte of the ip of the plc
    * Examples:
    * --------------------
    * ex. 192.168.0.1 -> 0x01
    * --------------------
    */
   ubyte da1;
   /**
    * Destination unit number
    *
    * The unit number, see the hardware config of plc, generally 0x00
    */
   ubyte da2;
   /**
    * Source network
    *
    * generally 0x01
    */
   ubyte sna;
   /**
    * Source node number.
    *
    * Like the destination node number, you could set a fixed number into plc config
    */
   ubyte sa1 = 0x02;
   /**
    * Source unit number.
    *
    * Like the destination unit number.
    */
   ubyte sa2;
   /**
    * Counter for the resend.
    *
    * Generally 0x00
    */
   ubyte sid;
   /**
    * Main request code (high byte).
    */
   ubyte mainRqsCode;
   /**
    * Sub request code.
    */
   ubyte subRqsCode;
}

/**
 * Convenience function for creating an `Header` with destination node number (`da1`) and source node number (`sa1`).
 *
 * `da1` is the subnet byte of the ip of the plc
 *
 * Params:
 *  dstNodeNumber = Destination node number
 *  srcNodeNumber = Source node number
 */
Header header(ubyte dstNodeNumber, ubyte srcNodeNumber = 0x02) {
   Header h;
   h.da1 = dstNodeNumber;
   h.sa1 = srcNodeNumber;
   return h;
}

/**
 * Get subnet (`da1`) from ip address.
 *
 * Examples:
 * --------------------
 * enum IP = "192.168.1.42";
 * IChannel chan = createUdpChannel(IP, 2000);
 * Header h = header(IP.getSubnet); // subnet == da1 == 42
 * FinsClient f = new FinsClient(chan, h);
 * --------------------
 */
ubyte getSubnet(string ip) @safe {
   import std.regex : regex, matchFirst;
   import std.conv : to;
   import std.exception : enforce;

   auto ipReg = regex(
         r"^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$");
   auto m = matchFirst(ip, ipReg);
   enforce(!m.empty && m.length > 4, "Invalid ip");
   return m[4].to!ubyte;
}

///
unittest {
   import std.exception : assertThrown;

   assert("192.168.221.64".getSubnet == 64);
   assert("192.168.221.1".getSubnet == 1);
   assert("192.168.22.2".getSubnet == 2);

   assertThrown("192.168.221".getSubnet);
   assertThrown("400.168.221.1".getSubnet);
   assertThrown("".getSubnet);
   assertThrown("asas".getSubnet);
}

/**
 * Convert an [Header] to array of bytes.
 */
ubyte[] toBytes(Header data) {
   enum RSV = 0x0;
   enum GCT = 0x02;
   ubyte[] b;
   b ~= data.icf;
   b ~= RSV;
   b ~= GCT;
   b ~= data.dna;
   b ~= data.da1;
   b ~= data.da2;
   b ~= data.sna;
   b ~= data.sa1;
   b ~= data.sa2;
   b ~= data.sid;
   b ~= data.mainRqsCode;
   b ~= data.subRqsCode;
   return b;
}

/**
 * Converts an array of bytes to `Header`
 */
Header toHeader(ubyte[] blob)
in {
   assert(blob.length >= FINS_HEADER_LEN, "Blob too short (less than 12)");
}
do {
   Header h;
   h.icf = blob[0];
   h.dna = blob[3];
   h.da1 = blob[4];
   h.da2 = blob[5];
   h.sna = blob[6];
   h.sa1 = blob[7];
   h.sa2 = blob[8];
   h.sid = blob[9];
   h.mainRqsCode = blob[10];
   h.subRqsCode = blob[11];
   return h;
}

///
struct ResponseData {
   /**
    * Response header
    */
   Header header;
   /**
    * Main response code
    */
   ubyte mainRspCode;
   /**
    * Sub response code
    */
   ubyte subRspCode;
   /**
    * Payload
    */
   ubyte[] text;
}

/**
 * Converts an array of bytes to `ResponseData` structure
 */
ResponseData toResponse(ubyte[] data)
in {
   assert(data.length > FINS_HEADER_LEN + 1, "Invalid data length");
}
do {
   ResponseData resp;
   resp.header = data.toHeader;
   resp.mainRspCode = data[12];
   resp.subRspCode = data[13];
   resp.text = data[14 .. $];
   return resp;
}

/**
 * Returs an array with start address and size.
 */
private ubyte[] getAddrBlock(ushort start, ushort size) {
   ubyte[] cmdBlock;

   //beginning address
   cmdBlock ~= cast(ubyte)(start >> 8);
   cmdBlock ~= cast(ubyte)start;
   cmdBlock ~= 0x00;
   cmdBlock ~= cast(ubyte)(size >> 8);
   cmdBlock ~= cast(ubyte)size;
   return cmdBlock;
}

/**
 * Client for Fins protocol
 */
class FinsClient {
   private IChannel channel;
   private Header header;
   /**
    * Constructor which takes a channel and header.
    */
   this(IChannel channel, Header header) {
      assert(channel !is null);
      this.channel = channel;
      this.header = header;
   }

   /**
    * Write an Omron PLC area: the area must be defined as CJ like area
    *
    * Params:
    *  area = The area type
    *  start = The start offset for the write process.
    *  buffer = The byte array buffer which will be write in the PLC.
    */
   void writeArea(MemoryArea area, ushort start, ubyte[] buffer)
   in {
      assert((buffer.length & 1) == 0, "Odd buffer length");
   }
   do {
      import std.conv : to;
      enum BYTES_PER_WORD = 2;

      ubyte[] text;
      //memory area code
      text ~= cast(ubyte)area;
      //IMPORTANT: The size is expressed in WORD (2 byte)
      immutable(ushort) size = (buffer.length / BYTES_PER_WORD).to!ushort;
      text ~= getAddrBlock(start, size);
      text ~= buffer;
      sendFinsCommand(0x01, 0x02, text);
   }

   /**
    * Read an Omron PLC area.
    *
    * Params:
    *  area = The area type
    *  start = The start offset for the read process.
    *  size = The size of the area to read. IMPORTANT: The size is expressed in WORD (2 byte)
    *
    * Returns:
    * The byte array buffer in which will be store the PLC readed area.
    */
   ubyte[] readArea(MemoryArea area, ushort start, ushort size) {
      ubyte[] cmdBlock;

      //memory area code
      cmdBlock ~= cast(ubyte)area;
      cmdBlock ~= getAddrBlock(start, size);
      return sendFinsCommand(0x01, 0x01, cmdBlock);
   }

   private ubyte[] sendFinsCommand(ubyte mainCode, ubyte subCode, ubyte[] comText) {
      header.mainRqsCode = mainCode;
      header.subRqsCode = subCode;

      ubyte[] sendFrame = header.toBytes() ~ comText;
      ubyte[] receiveFrame = channel.send(sendFrame);

      ResponseData response = receiveFrame.toResponse();
      if (response.mainRspCode != 0) {
         throw new FinsException(response.mainRspCode, response.subRspCode);
      }
      return response.text;
   }
}

/**
 * Converts main error code into string
 */
string mainErrToString(ubyte mainErr) {
   switch (mainErr) {
      case 0x01:
         return "Local node error";
      case 0x02:
         return "Destination node error";
      case 0x03:
         return "Communications controller error";
      case 0x04:
         return "Not executable";
      case 0x05:
         return "Routing error";
      case 0x10:
         return "Command format error";
      case 0x11:
         return "Parameter error";
      case 0x20:
         return "Read not possible";
      case 0x21:
         return "Write not possible";
      case 0x22:
         return "Not executable in current mode";
      case 0x23:
         return "No Unit";
      case 0x24:
         return "Start/stop not possible";
      case 0x25:
         return "Unit error";
      case 0x26:
         return "Command error";
      case 0x30:
         return "Access right error";
      case 0x40:
         return "Abort";
      default:
         return "Unknown error";
   }
}

/**
 * Convenience functions that create an `FinsClient` object.
 *
 * Examples:
 * --------------------
 * FinsClient f = createFinsClient("192.168.1.1", 2000, 9600);
 * --------------------
 *
 * Params:
 *  ip = IP address
 *  timeout = Send and receive timeout in ms
 *  port = Port number (default 9600)
 *  srcNodeNumber = Source node number
 */
FinsClient createFinsClient(string ip, long timeout, ushort port = 9600, ubyte srcNodeNumber = 0x02)
in {
   assert(ip.length);
   assert(timeout >= 0);
}
do {
   import dfins.channel : IChannel, createUdpChannel;

   IChannel chan = createUdpChannel(ip, timeout, port);
   Header h = header(ip.getSubnet, srcNodeNumber);
   return new FinsClient(chan, h);
}
