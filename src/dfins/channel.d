module dfins.channel;

import std.experimental.logger;
import core.time : dur;
import std.socket;

/**
 * Timeout exception
 */
class ChannelTimeoutException : Exception {
   this(string msg, string ip, const(ubyte[]) messageSent, string file = null, size_t line = 0) @trusted {
      _ip = ip;
      _messageSent = messageSent;

      import std.string : format;

      super("%s -- PLC ip %s".format(msg, ip));
   }

   private string _ip;
   string ip() {
      return _ip;
   }

   private const(ubyte[]) _messageSent;
   const(ubyte[]) messageSent() {
      return _messageSent;
   }
}

unittest {
   ChannelTimeoutException ex = new ChannelTimeoutException("message", "192.168.221.1", [10, 11]);
   assert(ex.ip == "192.168.221.1");
   assert(ex.messageSent == [10, 11]);
   assert(ex.msg == "message -- PLC ip 192.168.221.1");
}


interface IChannel {
   ubyte[] send(const(ubyte[]) msg);
}

/**
 * Implementazione di $(LINK IChannel) con protocollo ethernet (UDP)
 */
class UdpChannel : IChannel {
   private Socket socket;
   private Address address;
   this(Socket socket, Address address) {
      assert(socket !is null);
      this.socket = socket;

      assert(address !is null);
      this.address = address;
   }

   /**
    * Invia il messaggio e ritorna una risposta
    */
   ubyte[] send(const(ubyte[]) msg) {
      int attempt;
      while (true) {
         try {
            return sendSingle(msg);
         } catch (Exception e) {
            ++attempt;
            tracef("attempt %d failed", attempt);
            if (attempt > 2) {
               // tre tentativi
               throw e;
            }
         }
      }
   }

   private ubyte[] sendSingle(const(ubyte[]) msg) {
      socket.sendTo(msg, address);

      ubyte[1024] reply;
      version (Win32) {
         uint len = socket.receiveFrom(reply, address);
      } else {
         long len = socket.receiveFrom(reply, address);
      }

      if (len > 0) {
         return reply[0 .. len].dup;
      } else {
         throw new ChannelTimeoutException("Channel send error", address.toAddrString, msg);
      }
   }
}

/**
/*
 * Convenience functions that create an `IChannel` object
 *
 * Params:
 *  ip = IP address
 *  timeout = Send and recieve timeout in ms
 *  port = Port number (defaul 9600)
 */
IChannel createUdpChannel(string ip, long timeout, ushort port = 9600)
in {
   assert(ip.length);
   assert(timeout >= 0);
}
do {
   auto sock = new UdpSocket();
   sock.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(timeout));

   Address addr = parseAddress(ip, port);
   return new UdpChannel(sock, addr);
}
