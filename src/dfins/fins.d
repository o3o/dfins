module dfins.fins;

import dfins.channel;

enum MemoryArea : ubyte {
   CIO_BIT  = 0x30,
   W_BIT    = 0x31,
   H_BIT    = 0x32,
   A_BIT    = 0x33,
   D_BIT    = 0x02,
   CIO_WORD = 0xB0,
   W_WORD   = 0xB1,
   H_WORD   = 0xB2,
   A_WORD   = 0xB3,
   D_WORD   = 0x82
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

struct CommandData {
   /**
    * Information Control Field, set to 0x80
    */
   ubyte ICF;
   ubyte RSV;//RESERVED, SET TO 0x00
   ubyte GCT;//GATEWAY COUNT, SET TO 0x02
   ubyte DNA;//DESTINATION NETWORK, 0x01 IF THERE ARE NOT NETWORK INTERMEDIARIES
   ubyte DA1;//DESTINATION NODE NUMBER, IF SET TO DEFAULT THIS IS THE SUBNET BYTE OF THE IP OF THE PLC (EX. 192.168.0.1 -> 0x01)
   ubyte DA2;//DESTINATION UNIT NUMBER, THE UNIT NUMBER, SEE THE HW CONIFG OF PLC, GENERALLY 0x00
   ubyte SNA;//SOURCE NETWORK, GENERALLY 0x01
   ubyte SA1;//SOURCE NODE NUMBER, LIKE THE DESTINATION NODE NUMBER, YOU COULD SET A FIXED NUMBER INTO PLC CONFIG
   ubyte SA2;//SOURCE UNIT NUMBER, LIKE THE DESTINATION UNIT NUMBER
   ubyte SID;//COUNTER FOR THE RESEND, GENERALLY 0x00
   ubyte MR;
   ubyte SR;
   ubyte[] text;
}

ubyte[] toBytes(CommandData data) {
   ubyte[] b = new ubyte[](12 + data.text.length);
   b ~= data.ICF;
   b ~= data.RSV;
   b ~= data.GCT;
   b ~= data.DNA;
   b ~= data.DA1;
   b ~= data.DA2;
   b ~= data.SNA;
   b ~= data.SA1;
   b ~= data.SA2;
   b ~= data.SID;
   b ~= data.MR;
   b ~= data.SR;
   foreach (elem; data.text) {
      b ~= elem;
   }
   return b;
}

struct ResponseData {
   public ubyte ICF;
   public ubyte RSV;
   public ubyte GCT;
   public ubyte DNA;
   public ubyte DA1;
   public ubyte DA2;
   public ubyte SNA;
   public ubyte SA1;
   public ubyte SA2;
   public ubyte SID;
   public ubyte MR;
   public ubyte SR;
   public ubyte rspCodeH;
   public ubyte rspCodeL;
   public ubyte[] text;
}

ResponseData toResponse(ubyte[] data) {
   ResponseData resp;
   resp.text = new ubyte[](data.length - 14);
   resp.ICF = data[0];
   resp.RSV = data[1];
   resp.GCT = data[2];
   resp.DNA = data[3];
   resp.DA1 = data[4];
   resp.DA2 = data[5];
   resp.SNA = data[6];
   resp.SA1 = data[7];
   resp.SA2 = data[8];
   resp.SID = data[9];
   resp.MR = data[10];
   resp.SR = data[11];
   resp.rspCodeH = data[12];
   resp.rspCodeL = data[13];
   for (int i = 0; i < data.length - 14; i++) {
      resp.text ~= data[14 + i];
   }
   return resp;
}

class FinsClient {
   /+
   /**
    * Instantiates a new FinsClient
    *
    * Params:
    *  DNA = Destination Network, look at the PLC configuration
    *  DA1 = Destination Node Number, if set to default this is the last IP byte (subnet) of the plc. Example: 192.168.0.1 -> 0x01. You can set a fixed number into PLC configuration
    *  DA2 = Destination Unit Number, the unit number, see the hw conifg of plc, generally 0x00.
    *  SNA = Source Network, if in the same network of PLC, it is like DNA.
    *  SA1 = Source Node Number, like the destination node number. You can set a fixed number into PLC configuration
    *  SA2 = Source Unit Number, like the destination unit number.
    *
    */
   this(byte DNA = 0x01, byte DA1 = 0x01, byte DA2 = 0x00, byte SNA = 0x01, byte SA1 = 0x01, byte SA2 = 0x01) {
      //destination properties
      DestinationNetworkAddress = DNA;   //DNA
      DestinationNodeNumber = DA1;       //DA1
      DestinationUnitNumber = DA2;       //DA2

      //source properties
      SourceNetworkAddress = SNA;        //SNA
      SourceNodeNumber = SA1;            //SA1
      SourceUnitNumber = SA2;            //SA2
   }
   +/

   private IChannel channel;
   this(IChannel channel) {
      assert(channel !is null);
      this.channel = channel;
   }

   private ubyte _dna = 0x01;
   /**
    * Destination Network, look at the PLC configuration
    */
   ubyte dna() { return _dna; }
   void dna(ubyte value) { _dna = value; }


   private ubyte _da1 = 0x01;
   /**
    * Destination Node Number, if set to default this is the last IP byte (subnet) of the plc.
    *
    * Examples:
    * --------------------
    * 192.168.0.1 -> 0x01.
    * --------------------
    *
    * You can set a fixed number into PLC configuration
    */
   ubyte da1() { return _da1; }
   void da1(ubyte value) { _da1 = value; }

   private ubyte _da2 = 0x00;
   /**
    * Destination Unit Number, the unit number, see the hw conifg of plc, generally 0x00.
    */
   ubyte da2() { return _da2; }
   void da2(ubyte value) { _da2 = value; }

   private ubyte _sna = 0x01;

   /**
    * Source Network, if in the same network of PLC, it is like DNA.
    */
   ubyte sna() { return _sna; }
   void sna(ubyte value) { _sna = value; }

   private ubyte _sa1 = 0x01;
   /**
    * Source Node Number, like the destination node number. You can set a fixed number into PLC configuration
    */
   ubyte sa1() { return _sa1; }
   void sa1(ubyte value) { _sa1 = value; }

   private ubyte _sa2 = 0x01;
   /**
    * Source Unit Number, like the destination unit number.
    */
   ubyte sa2() { return _sa2; }
   void sa2(ubyte value) { _sa2 = value; }


   /**
    * Write an Omron PLC area: the area must be defined as CJ like area
    *
    * Params:
    *  area = The area type
    *  start = The start offset for the write process.
    *  size = The size of the area to write. IMPORTANT: The size is expressed in WORD (2 byte)
    *  buffer = The byte array buffer which will be write in the PLC.
    *
    *
    * Returns: The status integer
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
      sendFinsCommand(0x01, 0x02, text);
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
      ubyte[] text = new ubyte[](6);
      writefln("area %s", area);

      //memory area code
      text ~= cast(ubyte)area;

      //beginning address
      text ~= cast(ubyte)(start >> 8);
      text ~= cast(ubyte)start;
      text ~= 0x00;

      //number of items
      text ~= cast(ubyte)(size >> 8);
      text ~= cast(ubyte)size;

      writefln("%( %s %)", text);
      return sendFinsCommand(0x01, 0x01, text);
   }

   private ubyte[] sendFinsCommand(ubyte MR, ubyte SR, ubyte[] comText) {
      CommandData commandFrame;
      commandFrame.ICF = 0x80;
      commandFrame.RSV = 0x00;
      commandFrame.GCT = 0x02;
      commandFrame.DNA = _dna;
      commandFrame.DA1 = _da1;
      commandFrame.DA2 = _da2;
      commandFrame.SNA = _sna;
      commandFrame.SA1 = _sa1;
      commandFrame.SA2 = _sa2;
      commandFrame.SID = 0x00;
      commandFrame.MR = MR;
      commandFrame.SR = SR;
      commandFrame.text = comText;

      // Frame send via UDP
      ubyte[] sendFrame = commandFrame.toBytes();
      ubyte[] receiveFrame = channel.send(sendFrame);

      //Frame deconstruct
      ResponseData response = receiveFrame.toResponse();
      //response execution code
      if (response.rspCodeH != 0) {
         switch (response.rspCodeH) {
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
