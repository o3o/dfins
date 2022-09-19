module ut.fins;

import dfins.fins;
import std.experimental.logger;
import unit_threaded;

@("header")
unittest {
   immutable(Header) hdr = header(0x11);
   hdr.icf.should == 0x80;
   hdr.dna.should == 0x0;
   hdr.da1.should == 0x11;
   hdr.sa1.should == 0x02;

   immutable(Header) hdr2 = header(0x10, 0x42);
   hdr2.da1.should == 0x10;
   hdr2.sa1.should == 0x42;
}

@("toBytes")
unittest {
   import std.conv : to;

   Header data;
   data.dna = 0;
   data.da1 = 0x16;
   data.da2 = 0;
   data.sna = 0;
   data.sa1 = 0x02;
   data.sa2 = 0;
   data.mainRqsCode = 0x01;
   data.subRqsCode = 0x01;

   auto b = data.toBytes;
   b.length.should == FINS_HEADER_LEN;

   ubyte[] exp = [0x80, 0x00, 0x02, 0x00, 0x16, 0x0, 0x00, 0x02, 0x0, 0x0, 0x01, 0x01];
   for (int i = 0; i < FINS_HEADER_LEN; ++i) {
      b[i].should == exp[i];
   }
}
@("toHeader")
unittest {
   ubyte[] blob = [0xc0, 0x0, 0x02, 0x0, 0x02, 0x0, 0x0, 0x16, 0x0, 0x0, 0x01, 0x02];

   immutable(Header) h = blob.toHeader;
   h.icf.should == 0xC0;
   h.dna.should == 0x0;
   h.da1.should == 0x2;
   h.da2.should == 0x0;
   h.sna.should == 0x0;
   h.sa1.should == 0x16;
   h.sa2.should == 0x0;
   h.sid.should == 0x0;
   h.mainRqsCode.should == 0x01;
   h.subRqsCode.should == 0x02;
}

@("toResponse")
unittest {
   // dfmt off
   ubyte[] blob = [
      0xc0, 0x0, 0x02, 0x0, 0x02, 0x0, 0x0, 0x16, 0x0, 0x0, 0x01, 0x02,
      0x42, 0x43,  // rsp code
      0x64, 0x65, 0x66, 0x67, 0x68, 0x69 // data
   ];
   // dfmt on
   ResponseData r = blob.toResponse;
   r.header.icf.should == 0xC0;
   r.header.dna.should == 0x0;
   r.header.da1.should == 0x2;
   r.header.da2.should == 0x0;
   r.header.sna.should == 0x0;
   r.header.sa1.should == 0x16;
   r.header.sa2.should == 0x0;
   r.header.sid.should == 0x0;
   r.header.mainRqsCode.should == 0x01;
   r.header.subRqsCode.should == 0x02;

   r.mainRspCode.should == 0x42;
   r.subRspCode.should == 0x43;
   r.text.should == [0x64, 0x65, 0x66, 0x67, 0x68, 0x69];

   ubyte[] nodata = [0xc0, 0x0, 0x02, 0x0, 0x02, 0x0, 0x0, 0x16, 0x0, 0x0, 0x01, 0x02, 0x42, 0x43];
   nodata.toResponse.text.length.should == 0;
}


