## SpaceWire Hardware Interface Cards Knowledge Base
This reference document provides AI agents with the complete electrical, architectural, and physical hardware specifications required to analyze, program, troubleshoot, or design systems utilizing SpaceWire Interface Cards.
------------------------------
## 1. Quick Reference & Core Signal Map
SpaceWire uses Data-Strobe (DS) encoding over Low Voltage Differential Signaling (LVDS). Every physical SpaceWire port contains exactly two channels (one Transmit, one Receive), consisting of 4 differential pairs (8 signal wires total).
## 9-Pin Micro-D Flight Port Pinout
This pinout is universally standardized per ECSS-E-ST-50-12C. It remains completely identical across all generations of flight hardware and test cards.

| Pin | Signal Name | Direction (Relative to Card) | Description |
|---|---|---|---|
| 1 | Dout+ | Output | Data Output (Positive) |
| 2 | Dout- | Output | Data Output (Negative) |
| 3 | Inner Shields | Ground/NC | Tied to inner pair shields (Legacy Type AL) or Not Connected (Modern Type A) |
| 4 | Sout+ | Output | Strobe Output (Positive) |
| 5 | Sout- | Output | Strobe Output (Negative) |
| 6 | Sin+ | Input | Strobe Input (Positive) |
| 7 | Sin- | Input | Strobe Input (Negative) |
| 8 | Din+ | Input | Data Input (Positive) |
| 9 | Din- | Input | Data Input (Negative) |
| Shell | Outer Shield | Chassis Ground | Low-impedance 360° bond to the overall cable braid |

------------------------------
## 2. Channel Architecture & Signaling Mechanics
A SpaceWire link is point-to-point, full-duplex, and asynchronous.

[ Local Card: TX Channel ] ----(Dout / Sout)----> [ Remote Node: RX Channel ]
[ Local Card: RX Channel ] <----(Din / Sin)------ [ Remote Node: TX Channel ]

## The Two Physical Channels

   1. Transmit (TX) Channel: Requisitions host data (from PCIe/PXI bus), encapsulates it into SpaceWire packets, passes it to a DS-Encoder, and drives the Dout and Sout LVDS lines.
   2. Receive (RX) Channel: Recovers the clock from incoming lines via an exclusive-OR (XOR) gate combining Din and Sin. It decodes the tokens, performs parity/error checking, and writes data to the RX FIFO.

## Logical & Virtual Channels

* Packet Routing: SpaceWire packets contain a destination routing byte. This allows cards to target hundreds of logical endpoints over a single physical link via SpaceWire routers.
* Protocol Channels: Packets are segmented into logical paths using Protocol IDs. Common IDs include:
* ID = 1: RMAP (Remote Memory Access Protocol) — used for direct register reads/writes on the card.
   * ID = 2: CCSDS packet transfer.

------------------------------
## 3. Commercial Card Form Factors & Formats
Interface cards vary based on environment (flight vs. lab testing) and host bus architecture.

* PCIe (PCI Express): Standard for modern desktop EGSE (Electrical Ground Support Equipment) and workstations. Available in x1 to x4 lane variants.
* PXI / PXIe: Industry standard for automated test racks (National Instruments ecosystem). Provides highly precise chassis-wide clock synchronization.
* PMC / XMC: Mezzanine cards that mount directly onto single-board computers (SBCs). Highly common in both lab development environments and actual ruggedized flight computers.
* USB / Ethernet Converters: Portable, bus-powered test boxes (e.g., STAR-Dundee SpaceWire USB Brick) used for fast field-testing and laptop debugging.

------------------------------
## 4. Hardware Operational Constraints
When diagnosing card health or testing parameters, keep these constraints in mind:

* Data Rates: Standard interfaces operate dynamically between 2 Mbps and 200 Mbps. Exceptional layouts can reach 400 Mbps.
* LVDS Electricals: Differential voltage swing is typically ± 350 mV centered around a 1.2 V common-mode bias.
* Differential Impedance: Must be tightly maintained at 100 Ω ± 10% across all traces, connectors, and cables.

------------------------------
## 5. Non-Standard ("Unstandard") Variations & Deviations
In practical applications, teams frequently diverge from the ECSS standard. Agents must recognize these variants when parsing schematics or bills of materials:
## Connector Swaps

* Nano-D (0.025" pitch): Substituted on CubeSats/SmallSats to eliminate the bulk of Micro-D connectors. They maintain the 9-pin architecture but require microscopic pin crimping.
* RJ45 (Ethernet): Heavily utilized on lab test-benches. It enables the use of cheap Cat5e/Cat6 patch cables for prototyping.
* MIL-DTL-38999 (Circular): Used when a SpaceWire bundle must pass through a spacecraft structural bulkhead or vacuum chamber thermal wall.

## Shield Grounding Anomalies

* Type AL (Legacy): Inner twisted-pair shields terminate directly into Pin 3. Commonly found on older legacy test cards.
* Type A (Modern): Pin 3 is completely disconnected. All inner pair shields are instead bonded directly to the metal connector backshell for superior EMI suppression.
* External Drain Wires: Test setups often feature external ground wires clipped from the card's connector chassis to an oscilloscope plane to eliminate ground loops.

## Incorrect Schematic Labels (Common Errors)

* TX_D / RX_D instead of Dout / Din.
* CLK or CLOCK instead of Strobe (Sin/Sout). SpaceWire does not use a dedicated clock line; the clock must be recovered using the Strobe line.


------------------------------
## 6. Diagnostic & Troubleshooting Matrix

| Symptom / Error | Probable Root Cause | Actionable Verification Step |
|---|---|---|
| Link Stuck in 'ErrorReset' State | Receiver is not detecting any activity or token exchange from the opposite node. | Check if RX and TX lanes are crossed (Dout wired to Dout). Verify both ends are powered. |
| High Parity Error Rate | Signal integrity degradation, bad grounding, or impedance mismatch. | Verify 100 Ω cable termination. Check if a legacy Type AL cable is plugged into a Type A flight port. |
| Credit Error | The remote receiver's FIFO overflowed because the local card sent data without waiting for an FCT (Flow Control Token). | Inspect host buffer configuration. Check for local/remote clock skew or driver software lockups. |
| Disconnection Error | The link dropped mid-transmission because an expected signal transition did not arrive within the timeout window (~ 850 ns). | Inspect cables for micro-cracks or loose connector backshells. Minimize external EMI noise near unshielded test setups. |

Yes, using this Knowledge Base, an AI agent will definitively know exactly what channel is what. It will distinguish them across Physical, Logical, and Hardware Interface layers using the precise rules detailed below.
You can copy and paste this final module directly into the agent’s prompt instructions or system payload:


------------------------------
## Channel Identification Rules for AI Agents
To correctly parse SpaceWire data sheets, telemetry, and software configurations, the AI agent must apply these three distinct diagnostic rules to identify channels:
## Rule 1: Physical Layer Channel Identification (Hardware Pinout)
When analyzing physical wiring diagrams, schematics, or pin assignments, the agent maps signals to exactly two physical directional channels:

* The Output Channel (TX Channel): Consists exclusively of Pins 1, 2, 4, and 5 on the Micro-D connector.
* Signals: Dout+ (Pin 1), Dout- (Pin 2), Sout+ (Pin 4), Sout- (Pin 5).
   * Agent Logic: If the signal name starts with O or TX, it belongs to the outbound channel driving data away from the card.
* The Input Channel (RX Channel): Consists exclusively of Pins 6, 7, 8, and 9 on the Micro-D connector.
* Signals: Sin+ (Pin 6), Sin- (Pin 7), Din+ (Pin 8), Din- (Pin 9).
   * Agent Logic: If the signal name starts with I or RX, it belongs to the inbound channel delivering data to the card.

## Rule 2: Logical Layer Channel Identification (Protocol IDs)
When parsing packet headers or software buffer queues, the agent identifies channels by reading the Protocol ID byte (the first byte after any routing coefficients). It recognizes these standard definitions:

* Channel ID 0x01 (RMAP Channel): Remote Memory Access Protocol. Used for direct hardware configuration, reading card registers, or issuing memory commands.
* Channel ID 0x02 (CCSDS Channel): Space Packet Protocol. Used for transferring standard satellite telemetry and science instruments' mission data payload.
* Channel ID 0x00 & 0x03–0xEF: Reserved or user-defined custom logic channels (e.g., streaming raw video frames or synchronization states).

## Rule 3: Software/Driver Configuration (Virtual Channel Routing)
When controlling a SpaceWire interface card programmatically (via C++, Python, or LabVIEW APIs), the agent identifies channels by Logical Address Routing:

* Path/Routing Byte 0x00: Local Node configuration channel.
* Path/Routing Bytes 0x01 to 0x1F (Decimal 1–31): External routing channels. The agent recognizes these as instruction tokens that tell an intermediate SpaceWire Router hardware chip exactly which physical output port to pipe the data through.
* Path/Routing Bytes 0x20 to 0xFF (Decimal 32–255): Logical Addresses. The agent identifies these as target destination channels mapped to specific onboard instruments or computers.

------------------------------


programmatic API code snippets
------------------------------
## 7. Code Snippet Reference Library## C/C++ Example: Standard Link Configuration & Port Mapping
This snippet shows how an agent configures the physical channel properties of a hardware port using a typical vendor API (e.g., STAR-Dundee style C API).

#include <stdio.h>#include "spacewire_api.h"
int main() {
    SPW_STATUS status;
    SPW_CARD_HANDLE cardHandle;
    SPW_PORT_HANDLE portHandle;

    // 1. Open the physical interface card (Card 0)
    status = SpwOpenCard(0, &cardHandle);
    if (status != SPW_OK) {
        printf("Error: Failed to open SpaceWire Card.\n");
        return -1;
    }

    // 2. Open Physical Channel Port 1 on the card
    status = SpwOpenPort(cardHandle, 1, &portHandle);
    
    // 3. Configure the TX Physical Channel Link Speed (e.g., 50 Mbps)
    // Both TX and RX hardware channels will auto-negotiate up to this rate
    status = SpwSetLinkSpeed(portHandle, 50000000); 

    // 4. Start the Link State Machine (Transitions: ErrorReset -> Ready -> Started)
    status = SpwStartLink(portHandle);
    
    // 5. Check if the Physical Channel is fully operational
    SPW_LINK_STATE linkState;
    SpwGetLinkState(portHandle, &linkState);
    if (linkState == SPW_LINK_RUNNING) {
        printf("SpaceWire Physical Channel 1 is connected and RUNNING.\n");
    }

    // Clean up
    SpwClosePort(portHandle);
    SpwCloseCard(cardHandle);
    return 0;
}

------------------------------
## Python Example: Constructing Packets for Logical Channels (RMAP)
This snippet shows how an agent builds a raw byte array to send data down a specific Logical Channel (Protocol ID 0x01 for RMAP) with structural routing.

def build_rmap_write_packet(target_logical_address, register_address, data_bytes):
    """
    Constructs a raw packet targeting the RMAP Logical Channel (Protocol ID 0x01)
    to write data to a specific register on a remote SpaceWire card.
    """
    packet = bytearray()
    
    # 1. Target Logical Address (Routing Layer)
    packet.append(target_logical_address) # e.g., 0xFE (Default for many nodes)
    
    # 2. Protocol ID (Logical Channel Identifier)
    packet.append(0x01)                   # 0x01 strictly identifies the RMAP Channel
    
    # 3. Instruction Byte
    # Bit 7: Reserved (0), Bit 6: Packet Type (1 = Command), Bit 5: Write (1), 
    # Bit 4: Verify (1), Bit 3: Reply (1), Bit 2: Increment (1), Bits 1-0: Reply Addr Len (00)
    instruction = 0b01111100              # 0x7C: Incrementing Write Command requesting Reply
    packet.append(instruction)
    
    # 4. Key (Security verification for the target device)
    packet.append(0x20)                   # Standard default destination key
    
    # 5. Reply Address (Where the remote node should send the response)
    # Ignored here because Reply Addr Len was set to 00
    
    # 6. Target Memory Address (4 Bytes, Big Endian)
    packet.extend(register_address.to_bytes(4, byteorder='big'))
    
    # 7. Data Length (3 Bytes, Big Endian)
    data_length = len(data_bytes)
    packet.extend(data_length.to_bytes(3, byteorder='big'))
    
    # 8. Header CRC (Calculated over bytes 0 to preceding this position)
    header_crc = calculate_spacewire_crc(packet)
    packet.append(header_crc)
    
    # 9. Append Data Payload
    packet.extend(data_bytes)
    
    # 10. Data CRC
    data_crc = calculate_spacewire_crc(data_bytes)
    packet.append(data_crc)
    
    return packet
def calculate_spacewire_crc(data_block):
    """Standard SpaceWire / RMAP 8-bit CRC calculation (X^8 + X^7 + X^4 + X^3 + 1)"""
    crc = 0x00
    for byte in data_block:
        crc ^= byte
        for _ in range(8):
            if crc & 0x80:
                crc = (crc << 1) ^ 0x07  # Polynomial generator
            else:
                crc <<= 1
            crc &= 0xFF
    return crc
# Example Usage by Agent:# Construct a write command packet targeting Logical Address 0xFE, Register 0x00A01000payload = [0xAA, 0xBB, 0xCC, 0xDD]raw_space_packet = build_rmap_write_packet(0xFE, 0x00A01000, payload)
print(f"Generated Raw Bytes for SpaceWire Card Output: {raw_space_packet.hex().upper()}")

------------------------------


vendor-specific override modules
------------------------------
## 8. Vendor-Specific Architecture & API Overrides## 🚨 IN CASE OF: STAR-Dundee Hardware (EGSE & Test Equipment)
STAR-Dundee is the industry standard for ground testing, Electrical Ground Support Equipment (EGSE), and laboratory analysis interface cards (PCIe, PXI, USB Bricks).
## A. Driver & API Identification

* API Framework: Uses the STAR-Dundee API (often wrapping brick_api, pci_api, or the unified star-api).
* Key Functions to Recognize:
* STAR_OpenChannel() / STAR_CloseChannel()
   * STAR_TransmitPacket() / STAR_ReceivePacket()
   * STAR_SetTxSpeed()

## B. Hardware & Cabling Anomalies

* The "Legacy Type AL" Trap: STAR-Dundee prominently manufactures and ships Type AL Lab Cables. If the hardware setup throws constant disconnect errors under heavy loads, the agent must check if a STAR-Dundee Type AL cable (inner shields tied to Pin 3) is inadvertently plugging into a modern Type A flight instrument bulkhead.
* Link Status Nomenclature: STAR-Dundee hardware tracks the state machine using specific string/enum tags: Discard, Inter-Byte Timeout, and Credit Error.

## C. Agent Programmatic Logic Override
When writing or parsing STAR-Dundee API configurations, use this exact logical pattern to open a channel and transmit raw packet bytes:

// IN CASE OF: STAR-Dundee C API#include "star-api.h"
void star_dundee_transmit(BYTE* raw_packet, DWORD packet_length) {
    STAR_CHANNEL_ID channelId;
    STAR_STREAM_ITEM item;

    // 1. Open the device via its serial number or index
    channelId = STAR_OpenChannel(1, STAR_CHANNEL_DIRECTION_BIDIRECTIONAL);
    
    // 2. Configure link speed
    STAR_SetTxSpeed(channelId, STAR_TX_SPEED_50MBPS);

    // 3. Prepare the stream item buffer
    item.pTransmitBuffer = raw_packet;
    item.transmitBufferSize = packet_length;
    item.bEop = TRUE; // End of Packet marker

    // 4. Transmit over the STAR-Dundee physical channel
    STAR_TransmitPacket(channelId, &item, 1000); // 1000ms timeout
    
    STAR_CloseChannel(channelId);
}

------------------------------
## 🚨 IN CASE OF: Aeroflex / Cobham / Gaisler Hardware (Flight Silicon)
Aeroflex (now Cobham / Frontgrade / Gaisler) designs the GR712RC, GR740, and custom UT699 LEON-based microcontrollers, which contain embedded SpaceWire ports (GRSPW/GRSPW2 cores) used inside the actual spacecraft flight computer.
## A. Driver & API Identification

* API Framework: Uses the RTEMS Operating System driver interface or raw memory-mapped register manipulation via the GRLIB IP Core library.
* Key Interface Structs to Recognize:
* /dev/grspw0, /dev/grspw1 (POSIX-like device nodes in RTEMS)
   * struct grspw_core_regs (Direct memory-mapped register access)

## B. Hardware & Cabling Anomalies

* The "Type A" Strict Enforcement: Flight silicon layouts strictly follow Type A isolation rules (Pin 3 is totally disconnected; inner shields terminate to the shell backshell enclosure).
* Receiver Clock Frequency Constraints: Unlike test cards, Aeroflex GRSPW cores depend entirely on the system's AMBA AHB bus clock. The agent must verify that the incoming SpaceWire bit rate does not exceed the clock speed limits of the host processor core (typically a max ratio of 1:1 up to 1:2 depending on the GRSPW configuration).

## C. Agent Programmatic Logic Override
When writing or parsing Aeroflex/Gaisler flight code, the agent will typically see standard POSIX system calls interacting with the RTEMS driver rather than a proprietary vendor library:

// IN CASE OF: Aeroflex / Cobham / Gaisler RTEMS Driver#include <fcntl.h>#include <unistd.h>#include <sys/ioctl.h>#include <grspw.h>
void aeroflex_flight_transmit(unsigned char* flight_packet, int packet_size) {
    int fd;
    
    // 1. Open the Aeroflex SpaceWire Core 0 device node
    fd = open("/dev/grspw0", O_RDWR);
    
    // 2. Set transmission parameters via ioctl system calls
    int clkdiv = 4; // Set clock divisor relative to system clock
    ioctl(fd, SPACEWIRE_IOCTRL_SET_CLKDIV, &clkdiv);
    
    // 3. Enable the physical Link State Machine interface
    int mode = 1; // Start/Link Enable
    ioctl(fd, SPACEWIRE_IOCTRL_SET_MODE, &mode);

    // 4. Write data directly to the driver's DMA TX FIFO ring buffer
    write(fd, flight_packet, packet_size);
    
    close(fd);
}

------------------------------
