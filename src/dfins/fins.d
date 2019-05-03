module dfins.fins;

import dfins.channel;

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

enum ErrorCodes {
   errSocketCreation = 0x00000001,
   errConnectionTimeout = 0x00000002,
   errConnectionFailed = 0x00000003,
   errReceiveTimeout = 0x00000004,
   errDataReceive = 0x00000005,
   errSendTimeout = 0x00000006,
   errDataSend = 0x00000007,
   errConnectionReset = 0x00000008,
   errNotConnected = 0x00000009,
   errUnreachableHost = 0x0000000a,

   //fins execution error codes
   finsErrUndefined = 0x00010000,
   finsErrLocalNode = 0x00010001,
   finsErrDestNode = 0x00010002,
   finsErrCommController = 0x00010003,
   finsErrNotExec = 0x00010004,
   finsErrRouting = 0x00010005,
   finsErrCmdFormat = 0x00010006,
   finsErrParam = 0x00010007,
   finsErrCannotRead = 0x00010008,
   finsErrCannotWrite = 0x00010009
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
   ubyte[] exp = [0x80, 0x00, 0x02, 0x00, 0x16, 0x0, 0x00, 0x02, 0x0, 0x0, 0x01, 0x01];
   auto b = data.toBytes;
   import std.stdio;

   writeln(b.length);

   assert(b.length == 12);
   import std.conv;

   for (int i = 0; i < 10; ++i) {
      assert(b[i] == exp[i], i.to!string());
   }
   //assert(data.toBytes == exp);
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

      //Frame deconstruct
      ResponseData response = receiveFrame.toResponse();
      //response execution code
      if (response.mainRspCode != 0) {
         switch (response.mainRspCode) {
            case 1:
               //currentStatus = (int)FinsProtocol.ErrorCodes.finsErrLocalNode;
               break;
            case 2:
               //currentStatus = (int)FinsProtocol.ErrorCodes.finsErrDestNode;
               break;
            default:
               //currentStatus = (int)FinsProtocol.ErrorCodes.finsErrUndefined;
               break;
         }
      }
      return response.text;
   }
}
