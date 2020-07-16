# Whitefield Plug-n-play support for Contiki(-ng)

Plug-n-play (PnP) refers to using the stackline (such as RIOT/Contiki/..)
without any platform modifications in stackline for [Whitefield][3]. That is,
[Contiki][1]/[Contiki-NG][2] need not change a single line of code to use
Whitefield. For e.g., the user can simply compile the contiki example using the
native target and use the binary in Whitefield.

This document explains system engineering aspects of how Whitefield integrates
with Contiki in PnP mode.

Whitefield uses three techniques to achieve its purpose:
1. LD\_PRELOAD to override TUN open()/ioctl()/send()/receive()/system() and main().
2. dlopen/dlsym on position independent compiled contiki code
3. Overriding compilation variables

Another aim of this integration was to depend on as less changes to Contiki ABI as
possible and if there is any dependency Whitefield will cross-check at runtime
whether the dependent ABI is not different in the binaries passed by the user.

### LD\_PRELOADing

By LD\_PRELOADing, Whitefield could override the Contiki's main() function and
can pass Whitefield's NODEID. This NODEID eventually is passed to Contiki which
creates linklayer address based on this.

Contiki's native platform uses TUN interface to send/receive packets.
Whitefield overrides this interface to intercept the packets and pass it on to
Whitefield's Airline where it gets processed in NS3.

Following contiki's glibc calls are intercepted by Whitefield using LD\_PRELOAD:
1. TUN `open()`: Whitefield checks the open call's filename and if it is tun
   interface, it returns its internal commline Unix Domain Socket (UDS) FD.
   The `send()`/`receive()` now is redirected to Whitefield's UDS.
2. TUN `ioctl()`: TUN interface ioctl cannot be called no longer, hence these
   needs to be overrided.
3. `system()`: Contiki internally calls `system()` to start/stop tun interface.
   Whitefield overrides `system()` to not do this.

### Position Independent Code

Contiki-ng binaries are compiled with position independent code (-fPIE) options
and thus it possible to dlopen/dlsym the functions in the binary. This provides
an ability to call internal contiki functions from LD\_PRELOADed code.

An example of how this is used: Contiki-NG's native platform adds a default
route in the `platform_main()`. Whitefield removes this explicit default route
by loading and calling internal contiki functions.

### Overriding send/receive

There are two modes in which this overriding can be done:

1. Default Mode: By default Contiki's Native platform uses TUN interface which
   does not use modules such as sicslowpan (6lowpan) and CSMA. The
   `nullradio_driver` even though compiled and linked never appears in the
   execution flow with TUN interface. Whitefield preloads contiki and overrides
   `open()`/`ioctl()` calls and hooks it with Whitefield calls.  Interestingly
   Whitefield replaces tun fd with Whitefield's commline fd which internally is
   based on unix domain socket.

2. 6lo Mode: Folks will need 6lowpan for experimentation and thus Whitefield
   somehow needs to interface with these modules in native mode. One can
   compile Contiki-NG's example in following manner.
   ```makefile
    CFLAGS="-Dconst= \
        -DNETSTACK_CONF_NETWORK=sicslowpan_driver \
        MAKE_MAC=MAKE_MAC_CSMA \
        make -C examples/rpl-udp/ clean all
   ```
   This enables sicslowpan and CSMA modules in contiki-ng. However, TUN driver
   is no more used for send/receive. Instead nullradio\_driver is used. The
   radio driver is by default registered in flash by contiki by using const.
   The compile option `-Dconst=` makes sure that the driver is loaded in RAM
   such that Whitefield can override this driver from LD\_PRELOADed contiki's
   main().

## Terms

* UDS: Unix domain socket
* FD: File Descriptor
* Contiki and Contiki-NG are used synonymously
* ABI: Application Binary Interface

[1]: https://github.com/contiki-os/contiki
[2]: https://github.com/contiki-ng/contiki-ng
[3]: https://github.com/whitefield-framework/whitefield
