/**
 * Integration test with PLC connected.
 *
 * The PLC ip address is read from the "fins_ip" variable that you set (in fish):
 * ```
 * set -gx fins_ip "192.168.28.100"
 * ```
 *
 *	Copyright: © 2016-2026
 *	Authors: Orfeo Da Vià
 */
module it.fins;

import dfins.channel : IChannel, createUdpChannel;
import dfins.fins;
import std.process : environment;
import std.stdio;
import unit_threaded;

@HiddenTest("ip")
@("ip")
unittest {
   import std.stdio;

   string ip = environment.get("fins_ip", "192.168.28.100");
   writefln("ip %s", ip);
}

@HiddenTest()
@("readarea")
unittest {
   string ip = environment.get("fins_ip", "192.168.28.100");
   IChannel chan = createUdpChannel(ip, 2000);
   Header h = header(ip.getSubnet, 1);
   FinsClient f = new FinsClient(chan, h);

   ubyte[] d0 = f.readArea(MemoryArea.DM, 0, 1);
   writefln("DM000: %( 0x%x %)", d0);
}
