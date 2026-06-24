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

Would you like to expand this repository with specific API command structures for controlling SpaceWire cards (such as C/C++ or LabVIEW examples), or do you need a step-by-step pin layout translation for building an RJ45-to-Micro-D lab cable?

