module dfins.fins;

import dfins.channel;


class FinsException : Exception {
   this(ubyte mainCode, ubyte subCode, string file = null, size_t line = 0) @trusted {
      _mainCode = mainCode;
      _subCode = subCode;
      import std.string : format;
      super("Fins error %s", mainErrToString(_mainCode));
   }

   private ubyte _mainCode;
   ubyte mainCode() { return _mainCode; }

   private ubyte _subCode;
   ubyte subCode() { return _subCode; }
}

enum MemoryArea : ubyte {
   CIO_BIT = 0x30,
   W_BIT = 0x31,
   H_BIT = 0x32,
   A_BIT = 0x33,
   D_BIT = 0x02,
   CIO_WORD = 0xB0,
   W_WORD = 0xB1,
   H_WORD = 0xB2,
   A_WORD = 0xB3,
   D_WORD = 0x82
}

struct Header {
   /**
    * Information Control Field, set to 0x80
    */
   ubyte icf = 0x80;
   //ubyte rsv;//reserved, set to 0x00
   //ubyte gct = 0x02;//gateway count, set to 0x02
   ubyte dna; //destination network, 0x01 if there are not network intermediaries
   ubyte da1; //destination node number, if set to default this is the subnet byte of the ip of the plc (ex. 192.168.0.1 -> 0x01)
   ubyte da2; //destination unit number, the unit number, see the hw conifg of plc, generally 0x00
   ubyte sna; //source network, generally 0x01
   ubyte sa1 = 0x02; //source node number, like the destination node number, you could set a fixed number into plc config
   ubyte sa2; //source unit number, like the destination unit number
   ubyte sid; //counter for the resend, generally 0x00
   ubyte mainCmdCode; // command code high byte
   ubyte subCmdCode; // command code low byte
}

/**
 * Convenience function for creating an `Header` with subnet data (`da1`)
 */
Header header(ubyte subnet) {
   Header h;
   h.da1 = subnet;
   return h;
}

/**
 *  Convert an `Header` to array of bytes.
 */
ubyte[] toBytes(Header data) {
   //ubyte[] b = new ubyte[](12 + data.text.length);
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
   b ~= data.mainCmdCode;
   b ~= data.subCmdCode;
   return b;
}

unittest {
   Header data;
   data.dna = 0;
   data.da1 = 0x16;
   data.da2 = 0;
   data.sna = 0;
   data.sa1 = 0x02;
   data.sa2 = 0;
   data.mainCmdCode = 0x01;
   data.subCmdCode = 0x01;

   ubyte[] exp = [0x80, 0x00, 0x02, 0x00, 0x16, 0x0, 0x00, 0x02, 0x0, 0x0, 0x01, 0x01];
   auto b = data.toBytes;
   assert(b.length == 12);

   import std.conv;
   for (int i = 0; i < 12; ++i) {
      assert(b[i] == exp[i], i.to!string());
   }
}

/**
 * Converts an array of bytes to `Header`
 */
Header toHeader(ubyte[] blob)
in {
   assert(blob.length > 11, "Blob too short (less than 12)");
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
   h.mainCmdCode = blob[10];
   h.subCmdCode = blob[11];
   return h;
}

unittest {
   ubyte[] blob = [
      0xc0,
      0x0, 0x02, 0x0,
      0x02, 0x0, 0x0,
      0x16, 0x0, 0x0,
   0x01, 0x02
   ];
   Header h = blob.toHeader;
   assert(h.icf == 0xC0);
   assert(h.dna == 0x0);
   assert(h.da1 == 0x2);
   assert(h.da2 == 0x0);
   assert(h.sna == 0x0);
   assert(h.sa1 == 0x16);
   assert(h.sa2 == 0x0);
   assert(h.sid == 0x0);
   assert(h.mainCmdCode == 0x01);
   assert(h.subCmdCode == 0x02);

}

struct ResponseData {
   Header header;
   ubyte mainRspCode;
   ubyte subRspCode;
   ubyte[] text;
}

ResponseData toResponse(ubyte[] data) {
   ResponseData resp;
   resp.header = data.toHeader;
   resp.mainRspCode = data[12];
   resp.subRspCode = data[13];
   for (int i = 0; i < data.length - 14; i++) {
      resp.text ~= data[14 + i];
   }
   return resp;
}

class FinsClient {
   private IChannel channel;
   private Header header;
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
    *  size = The size of the area to write. IMPORTANT: The size is expressed in WORD (2 byte)
    *  buffer = The byte array buffer which will be write in the PLC.
    *
    */
   void writeArea(MemoryArea area, ushort start, ushort size, ubyte[] buffer) {
      ubyte[] text = new ubyte[](6 + buffer.length);
      //memory area code
      text ~= cast(ubyte)area;

      //beginning address
      text ~= cast(ubyte)(start >> 8);
      text ~= cast(ubyte)start;
      text ~= 0x00;

      //number of items
      text ~= cast(ubyte)(size >> 8);
      text ~= cast(ubyte)size;

      for (int i = 0; i < buffer.length; i++) {
         text ~= buffer[i];
      }

      //sending the fins command and storing the response
      //sendFinsCommand(0x01, 0x02, text);
   }

   /**
    * Read an Omron PLC area: the area must be defined as CJ like area
    *
    * Params:
    *  area = The area type
    *  start = The start offset for the read process.
    *  size = The size of the area to read. IMPORTANT: The size is expressed in WORD (2 byte)
    *
    *
    * Returns:
    * The byte array buffer in which will be store the PLC readed area.
    *
    */
   ubyte[] readArea(MemoryArea area, ushort start, ushort size) {
      import std.stdio;

      ubyte[] cmdBlock;

      //memory area code
      cmdBlock ~= cast(ubyte)area;

      //beginning address
      cmdBlock ~= cast(ubyte)(start >> 8);
      cmdBlock ~= cast(ubyte)start;
      cmdBlock ~= 0x00;

      //number of items
      cmdBlock ~= cast(ubyte)(size >> 8);
      cmdBlock ~= cast(ubyte)size;

      return sendFinsCommand(0x01, 0x01, cmdBlock);
   }

   private ubyte[] sendFinsCommand(ubyte cmdH, ubyte cmdL, ubyte[] comText) {
      header.mainCmdCode = cmdH;
      header.subCmdCode = cmdL;

      ubyte[] sendFrame = header.toBytes() ~ comText;
      ubyte[] receiveFrame = channel.send(sendFrame);

      ResponseData response = receiveFrame.toResponse();
      if (response.mainRspCode != 0) {
         throw new FinsException(response.mainRspCode, response.subRspCode);
      }
      return response.text;
   }
}

string mainErrToString(ubyte mainErr) {
   switch (mainErr) {
      case 0x01: return "Local node error";
      case 0x02: return "Destination node error";
      case 0x03: return "Communications controller error";
      case 0x04: return "Not executable";
      case 0x05: return "Routing error";
      case 0x10: return "Command format error";
      case 0x11: return "Parameter error";
      case 0x20: return "Read not possible";
      case 0x21: return "Write not possible";
      case 0x22: return "Not executable in current mode";
      case 0x23: return "No Unit";
      case 0x24: return "Start/stop not possible";
      case 0x25: return "Unit error";
      case 0x26: return "Command error";
      case 0x30: return "Access right error";
      case 0x40: return "Abort";
      default: return "Unknown error";
   }
}
