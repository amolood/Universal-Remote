# IR Protocol Research (verified)

This is a synthesis task — all the data is provided inline. No tools needed. Producing the report directly.

# IR Protocol Implementation Spec — Synthesis Report

All verdicts below are `confirmed` unless flagged in **Corrections**. Confidence reflects the researcher's rating after adversarial verification.

---

## 1. Ready to implement now

High-confidence, verifier-confirmed protocols with public codes or computable full-state. **Grouped by encoder** so shared work is obvious.

### NEC (32-bit, 38 kHz) — biggest shared encoder
Leader 9000us mark + 4500us space; 560us bit mark; '0'=560us space, '1'=1690us space; 32 bits LSB-first = addr + ~addr + cmd + ~cmd; repeat = 9000+2250us ditto.

| Brand + kind | Notes |
|---|---|
| Toshiba TV | IRDB device 64; plain NEC |
| Hitachi TV | IRDB device 80 (also 96/12) |
| Hisense TV | Fixed address; extended-NEC (addr not inverted), e.g. Power 0x00FDB04F |
| TCL TV (modern) | Fixed addr 0x57E3; full per-button hex public |
| Haier TV | Addr 0x04; **partial codes** — see §2 |
| Daewoo TV | NEC1 dev 4 / NECx1 dev 6,6; IRDB |
| Generic fan/heater | NEC encoder ready; per-button codes per-device from IRDB/capture |

### Samsung32 (38 kHz) — covers Samsung TV + AV + DVD
Symmetric leader 4480us mark + 4480us space; 560us bit mark; '1'=1680us space, '0'=560us space; 32 bits LSB-first = customer + customer(repeated) + cmd + ~cmd. **Key distinction from NEC: address byte is duplicated, not inverted.**

| Brand + kind | Notes |
|---|---|
| Samsung TV | Customer 0x07; Power 0xE0E040BF |
| Samsung soundbar/hi-fi | HW-* series; same encoder, codes in IRDB/hifi-remote |
| Samsung DVD (older) | AV address 0xE0E0; Power/Eject/Source documented |
| Samsung Blu-ray/soundbar (modern) | **SAMSUNG36** variant (AK59-00167A, AH59-02692E) — distinct 36-bit framing; needs a second small encoder if targeting modern BD |

### LG (NEC-derived, 28-bit + variants, 38 kHz) — TV + AV + AC
Classic LG: leader 8500us mark + 4250us space; 550us bit mark; '1'=1600us, '0'=550us; 28 bits MSB-first with 4-bit nibble-sum checksum. LG2 variant: 3200us mark + 9900us space (newer split units).

| Brand + kind | Notes |
|---|---|
| LG TV | **Practical default = NEC32 with address 0x04 / 0x20DF** for most/older sets (e.g. Power 0x20DF10EF); 28-bit LG mostly for AC/some TVs |
| LG soundbar/hi-fi | LG NEC-family (28/32-bit); codes in IRDB/LIRC |
| LG DVD/Blu-ray | **Plain NEC32, address 0x20DF** — not the LG-AC protocol |
| LG AC | Full 28-bit state word: 0x88 signature, temp/mode/fan/power fields, nibble checksum; IRLgAc encoder ready |

### SIRC / Sony (pulse-WIDTH, 40 kHz — NOT 38 kHz)
Start 2400us mark + 600us space; '1'=1200us mark, '0'=600us mark, each + 600us space; LSB-first; 12/15/20-bit. **Must send each frame ≥3×.**

| Brand + kind | Notes |
|---|---|
| Sony TV | 12-bit, device address 1 |
| Sony soundbar/hi-fi/receiver | SIRC; audio device addresses differ from TV |
| Sony DVD/Blu-ray | 20-bit variant (device ~0x1A + extended bits) |

### Kaseikyo / Panasonic 48-bit (pulse-distance, ~37 kHz / 36.7 kHz)
Leader 3456us mark + 1728us space; 432us bit mark; '1'=1296us, '0'=432us; 48 bits LSB-first = vendor 0x2002/0x4004 + device + subdevice + command + checksum(D^S^F).

| Brand + kind | Notes |
|---|---|
| Panasonic TV | Per-button codes in IRDB/LIRC |
| Panasonic soundbar/hi-fi | Same encoder, Panasonic vendor code |
| Panasonic DVD/Blu-ray | device/genre + function fields |

### RC5 / RC6 (Manchester, 36 kHz) — Philips
RC5: 1778us bit time (889us halves), 14 bits, no leader. RC6 mode 0: leader 2666us mark + 889us space, 444us base, double-width toggle, 20 bits, inverted bit-sense vs RC5.

| Brand + kind | Notes |
|---|---|
| Philips TV (legacy) | RC5, addr 0x00, Power 0x0C |
| Philips TV (modern) | RC6 mode 0 |
| Philips soundbar/hi-fi | RC5 or RC6 — **verify per model** |

### Sharp (15-bit, 38 kHz) — TV/AV only
No leader; 260us bit mark; '1'=1820us, '0'=780us; 15 bits LSB-first = addr(5)+cmd(8)+expansion(1)+check(1); frame sent twice (2nd inverted). IRDB device 1.

### Full-state AC encoders (each a distinct class; compute state + checksum, no per-button table)

| Brand + kind | Protocol | Carrier | One-line frame |
|---|---|---|---|
| Midea AC | Midea 48-bit | 38 kHz | 6-byte state + inverted copy; NEC-like timing; checksum byte0 |
| Daikin AC | Daikin family (280/216/312/128/64/152/160/176/200-bit) | 38 kHz (**312-bit = 36.7 kHz**) | Full-state, additive &0xFF checksum; pick variant per model |
| Panasonic AC | PanasonicAc (Kaseikyo) | 36.7 kHz | 27-byte, 2 sections; checksum init 0xF4; model variants NKE/DKE/JKE/LKE/CKP/RKR |
| Toshiba AC | TOSHIBA_AC | 38 kHz | 9-byte/72-bit; 0xF2 signature; XOR checksum; sent twice |
| Hitachi AC | HITACHI_AC + AC1/AC3/AC264/AC296/AC344/AC424 | 38 kHz | 28-byte base; AC424 has ~30ms leader; pick variant per model |
| LG AC | LG 28-bit (see LG group) | 38 kHz | 0x88 signature, nibble checksum |
| Samsung AC | SamsungAC | 38 kHz | 14-byte (2 sections), 21-byte extended for power/timer; negated-sum checksum |
| Haier AC | HAIER_AC / YRW02 / AC160 / AC176 | 38 kHz | 9/14/20/22-byte; additive checksum (dual for 160/176) |
| Hisense AC | Kelon 48-bit + Kelon168 | 38 kHz | 48-bit (power = **toggle**) or 21-byte/168-bit; 168 = BETA |
| TCL AC | TCL112AC (+ TCL96AC) | 38 kHz | 14-byte, absolute power, 0.5C temp; TCL96 = 2-bit-symbol space encoding |
| Electrolux / Frigidaire AC | Electra (ELECTRA_AC) | 38 kHz | 13-byte/104-bit; send marked Alpha but well-specified |
| Whirlpool AC | WHIRLPOOL_AC | 38 kHz | 21-byte/168-bit, 3 sections, 2 XOR checksums, power = toggle; set model DG11J1-91 vs -3A |
| Sharp AC | SHARP_AC | 38 kHz | 13-byte/104-bit; nibble checksum |
| Beko AC | COOLIX 24-bit | 38 kHz | 3 bytes + complement; discrete command words |

### Fan (distinct, ready)
| Brand + kind | Protocol | Carrier | Notes |
|---|---|---|---|
| Lasko fan | Symphony | 38 kHz | No header; 12-bit; swapped 400/1250us marks; replay 4 captured codes or sendSymphony() |

---

## 2. Partial — structure known, codes/spec incomplete

| Brand + kind | Protocol | What's missing |
|---|---|---|
| Haier TV | NEC addr 0x04 | Only CH±/VOL±/Power/Mute captured from one user remote; no digits/HDMI/menu/arrows. Basic encoder works; full remote needs capture. |
| Xiaomi TV | Xiaomi-IR (RC-MM quaternary, 36 kHz) | Protocol + key codes public (D=0x86, Power D=0x3C), but **no ready-made library encoder** — must hand-build raw frame with custom XOR checksum. |
| Lasko heater (CC23161) | Custom 64-bit pulse-distance | No bit→function spec; replay per-button RAW captures only. NEC does not decode. |
| Honeywell portable AC | Custom LSB-first pulse-distance | Fields (mode/temp/timer) reverse-engineerable from Eleccelerator tables, but no normalized per-field spec — assemble bit table or capture. |
| Honeywell IR fan | Custom space-encoded (~636us mark) | Only raw ON/SPEED + OFF captures; full bit table lives in an unretrieved JP1 file. RAW replay only. |
| GE window/portable AC | GE 48-bit pulse-distance (LIRC) | Discrete per-button only (0x555AF308 prefix); cannot synthesize arbitrary state. Some GE units are actually LG (GE6711AR2853M → use LG). |
| Arçelik AC | COOLIX (likely) / VESTEL_AC | Brand→protocol mapping **unconfirmed**; no Arcelik-labelled codes. Capture and probe COOLIX first. |
| Kenmore AC | Midea/Coolix (OEM-dependent) | No Kenmore-specific spec; OEM (usually Midea, sometimes LG) varies by model. Capture + match. |

---

## 3. Not feasible from public data

| Brand + kind | Status |
|---|---|
| Pelonis fan / fan-heater (non-AC) | No public capture or protocol ID at all. Cheap encoder chip likely (Symphony-style or NEC) but unconfirmed. **Stay generic-NEC fallback or Wi-Fi; requires physical capture.** (Note: Pelonis *AC* IS ready — it's Midea, see §1.) |

---

## 4. Corrections / clarifications from verifiers

- **Midea AC is its own distinct protocol** (a 48-bit NEC-*like* full-state frame with payload+inverse), and **Midea24 / Beko / Kenmore / Coolix are the Coolix-family** — not "generic NEC." Don't treat Midea-family as button-code NEC.
- **LG TV: the practical default is NEC32 with address 0x04 / 0x20DF**, not the dedicated 28-bit LG protocol. The 28-bit "LG" framing is primarily for LG **AC** and some TVs. LG DVD/BD also = plain NEC32 (0x20DF), NOT the LG-AC protocol.
- **Hisense AC = Kelon** (Hisense's Kelon-OEM brand), not a "Hisense" protocol; power is a **toggle** (open-loop can't guarantee on/off state).
- **Carrier traps corrected/confirmed:** Sony = **40 kHz** (not 38); Panasonic TV/AV/DVD/AC + Daikin312 = **~37 kHz / 36.7 kHz** (not 38); Philips RC5/RC6 + Xiaomi = **36 kHz** (not 38). Everything else listed = 38 kHz.
- **"GE" in IRremoteESP8266 is misleading** — GE6711AR2853M is an **LG AC remote** handled by the LG protocol, not a native GE protocol. True GE window/portable ACs use a separate 48-bit discrete protocol.
- **Whirlpool & Hisense-Kelon power = toggle bit**; Whirlpool also needs the correct model (DG11J1-91 applies −2C offset) and the Cmd/button field set.
- **TCL spans protocols across generations:** modern = NEC (addr 0x57E3); older RCA-OEM = RCA-38 (IRDB's only TCL TV entry). TCL AC = TCL112AC (modern) or TCL96AC (GYKQ-58 remotes).
- Minor non-blocking timing nits flagged by verifiers (Midea min-gap ~5600us not 4240us; Haier AC160 some intra-byte offsets; Panasonic kPanasonicFreq=36700 vs literal 37000) — do not affect protocol identity.

---

## 5. Recommended encoder set (minimal coverage)

Implement these **distinct encoders** to maximize brand coverage. Ordered by ROI.

| # | Encoder | Carrier | Brands / devices served |
|---|---|---|---|
| 1 | **NEC32** (+ extended-NEC) | 38 kHz | Toshiba TV, Hitachi TV, Hisense TV, TCL TV (modern), Haier TV, Daewoo TV, **LG TV/DVD/BD (0x20DF)**, generic fan/heater. The single highest-leverage encoder. |
| 2 | **Samsung32** (+ small Samsung36 add-on) | 38 kHz | Samsung TV, Samsung AV/soundbar, Samsung DVD; Samsung36 for modern Blu-ray/soundbar. |
| 3 | **SIRC / Sony** | 40 kHz | Sony TV, soundbar, receiver, DVD/Blu-ray. (Remember 3× send.) |
| 4 | **Kaseikyo/Panasonic 48-bit** | 37 kHz | Panasonic TV, AV, DVD/Blu-ray. |
| 5 | **RC5 + RC6** | 36 kHz | Philips TV (legacy + modern), Philips soundbar/hi-fi. |
| 6 | **Sharp 15-bit** | 38 kHz | Sharp TV/AV. |
| 7 | **Midea 48-bit (+ Coolix 24-bit)** | 38 kHz | **Midea AC + all rebrands**: Pelonis AC, Kenmore AC (most), Beko (Coolix), Electrolux/Frigidaire Midea-clones, and many OEM split ACs. |
| 8 | **Daikin family** | 38 kHz (312-bit=36.7) | Daikin AC (all length variants behind one class family). |
| 9 | **Per-brand AC state encoders** (port from IRremoteESP8266) | 38 kHz | PanasonicAc, Toshiba AC, Hitachi AC (multi-variant), LG AC, SamsungAC, Haier AC, Kelon (Hisense), TCL112AC, Electra (Electrolux/Frigidaire), Whirlpool, Sharp AC. Each is independent; implement on demand per target market. |
| 10 | **LG 28-bit** | 38 kHz | LG AC + the subset of LG TVs/hubs needing true LG framing (most LG TVs covered by #1). |
| 11 | **Symphony** | 38 kHz | Lasko fans (+ SamHop/Blyss/Westinghouse/SilverCrest family). |

**Coverage summary:** encoders #1–#6 cover essentially all confirmed **TV / AV / DVD-BD** targets. #7 (Midea+Coolix) is the single highest-ROI **AC** encoder (Midea + many rebrands). #8–#10 add the remaining major AC brands. Everything in §2/§3 (Xiaomi, Lasko heater, Honeywell, GE, Arçelik, Kenmore-non-Midea, Pelonis fan) should ship as **RAW-capture replay + generic-NEC fallback**, not synthesized encoders.

---

# Per-target dossier (frame details + verdicts)

```json
[
 {
  "target": "tv-samsung-lg",
  "protocols": [
   {
    "brand": "Samsung",
    "kind": "TV",
    "protocolName": "Samsung32 (SAMSUNG)",
    "carrierHz": 38000,
    "frameSummary": "Leader: 4480us mark + 4480us space (8x560us tick each). Bit mark 560us; logical 1 = 560us mark + 1680us space (3x tick); logical 0 = 560us mark + 560us space. 32 bits total, transmitted LSB-first, with a 560us trailing stop bit. Frame layout = customer_byte + customer_byte (repeated) + command_byte + ~command_byte (inverted). Effectively 16 bits of distinct data (8-bit device/customer address + 8-bit command, each protected by being repeated or inverted). Repeats use a full re-send of the frame (NEC-style repeat handling). This is a genuinely distinct protocol from generic NEC: NEC uses a 9000/4500us leader and 8+8+8+8 addr/~addr/cmd/~cmd layout, whereas Samsung uses a symmetric 4480/4480us leader and customer+customer+cmd+~cmd layout.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Samsung.cpp + ir_Samsung.h (sendSAMSUNG, kSamsungBits=32, kSamsungHdrMark/Space=4480us, kSamsungBitMark=560us, kSamsungOneSpace=1680us, kSamsungZeroSpace=560us, 38kHz). Per-button hex codes available in IRDB (github.com/probonopd/irdb, Samsung TV CSVs) and LIRC remote DB.",
    "notes": "Samsung TVs predominantly use Samsung32. Device/customer code for Samsung TVs is commonly 0x07 (so customer byte 0xE0E0 patterns appear in captured 32-bit values, e.g. power toggle = 0xE0E040BF). Real per-button codes are abundant in IRDB and LIRC. Some newer Samsung sets also accept the same Samsung32 framing. The Samsung *AC* protocol is entirely different (stateful, 56/112/168-bit, IRSamsungAc class) and not relevant to TV. Implementability is 'ready' to write a real encoder: timings + bit layout + button codes are all public."
   },
   {
    "brand": "LG",
    "kind": "TV",
    "protocolName": "LG (NEC-derived 28-bit) / LG2 variant",
    "carrierHz": 38000,
    "frameSummary": "LG (classic, UPD6121-style): Leader 8500us mark + 4250us space. Bit mark 550us; logical 1 = 550us mark + 1600us space; logical 0 = 550us mark + 550us space. LG2 variant: leader 3200us mark + 9900us space, bit mark 480us, same 1/0 spaces. Both are 28 bits total (kLgBits=28). Frame layout = 8 (or 12) bits address + 16 bits command + 4-bit checksum, MSB-first, with a 550us trailing stop bit. Checksum = sum of the four command nibbles, masked to 4 bits. Repeats use the NEC repeat frame (9000us mark + 2250us space + stop). This is a real, distinct LG protocol (28-bit with embedded 4-bit checksum), NOT plain 32-bit NEC -- though it is NEC-family and shares NEC-style modulation and the NEC repeat mechanism.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_LG.cpp + ir_LG.h (sendLG/sendLG2, kLgBits=28, kLgHdrMark=8500, kLgHdrSpace=4250, kLgBitMark=550, kLgOneSpace=1600, kLgZeroSpace=550; kLg2HdrMark=3200, kLg2HdrSpace=9900, kLg2BitMark=480). Per-button codes: IRDB LG TV CSVs, LIRC LG remotes, and the public gist 'LG TV 2008-2013 NEC IR Codes' (gist a59379c9772717a6e2fbb822a383114b).",
    "notes": "Caveat: many LG TVs (especially 2008-2013 era and a large share of current sets) are documented to respond to a STANDARD 32-bit NEC frame with device code 0x04 (e.g. power = 0x20DF10EF), as captured in the widely-used LG NEC code gist and IRDB. The dedicated 28-bit 'LG'/'LG2' protocols in IRremoteESP8266 are primarily used by LG air conditioners and some TVs; for many TV models the practical, well-attested path is NEC32 with address 0x04 / 0xLG patterns. Both the 28-bit LG spec and the NEC32 button codes are public, so an encoder is 'ready' -- but pick the framing per model (NEC32 0x04 is the safest default for older/most LG TVs; LG2 timing for some IR-hub-blasted units). LG2's inverted-looking leader (short mark, long space) trips up naive decoders, worth noting."
   }
  ],
  "verdicts": [
   {
    "brand": "Samsung",
    "protocolName": "Samsung32 (SAMSUNG)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Every load-bearing parameter in the claim matches the primary source (IRremoteESP8266 src/ir_Samsung.cpp + ir_Samsung.h) verified via direct fetch of github.com/crankyoldgit/IRremoteESP8266. Confirmed values: kSamsungTick=560us; kSamsungHdrMarkTicks=8 and kSamsungHdrSpaceTicks=8 => 4480us mark + 4480us space symmetric leader (distinct from NEC's asymmetric 9000/4500us); kSamsungBitMarkTicks=1 => 560us bit mark; kSamsungOneSpaceTicks=3 => 1680us space for logical 1; kSamsungZeroSpaceTicks=1 => 560us space for logical 0; kSamsungBits=32; carrier=38kHz; transmission LSB-first with a 560us trailing stop bit; frame layout = customer_byte + customer_byte (repeated) + command + ~command (inverted). A second independent source (techiesms / community IR-decoding writeups and Arduino forum analyses) corroborates the same framing: 4.5ms/4.5ms start, 560us+1690us for 1, 560us+560us for 0, 32 bits address+address+data+~data sent LSB-to-MSB, ~37.9-38kHz carrier. The claim correctly distinguishes Samsung32 from generic NEC (different leader timing and address/address/cmd/~cmd vs addr/~addr/cmd/~cmd layout), avoids the carrier-confusion trap (38kHz is correct, not Sony 40kHz or Panasonic 37kHz), and NEC-style full-frame repeat handling is accurate. Per-button hex codes are indeed available in IRDB and LIRC. No discrepancies found; the ~37.9kHz precise figure rounds to the stated 38kHz used by the library's sendSAMSUNG default."
   },
   {
    "brand": "LG",
    "protocolName": "LG (NEC-derived 28-bit) / LG2 variant",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Every claimed value was independently confirmed against the cited IRremoteESP8266 source (crankyoldgit/IRremoteESP8266, src/ir_LG.cpp and src/IRremoteESP8266.h). Confirmed: kLgBits=28; kLgHdrMark=8500, kLgHdrSpace=4250, kLgBitMark=550, kLgOneSpace=1600, kLgZeroSpace=550; LG2 variant kLg2HdrMark=3200, kLg2HdrSpace=9900, kLg2BitMark=480 (with the same 1/0 spaces). Carrier is 38 kHz (the literal \"38\" is passed to sendGeneric in sendLG/sendLG2) \u2014 correct, not Sony's 40 kHz or Panasonic's 37 kHz. Checksum is the sum of the four command nibbles masked to 4 bits (irutils::sumNibbles(command, 4)), matching the claim. Frame layout (8/12-bit address + 16-bit command + 4-bit checksum = 28 bits, MSB-first, 550us trailing stop bit) and the NEC-style repeat frame are accurate. The characterization as a distinct NEC-derived LG protocol with an embedded 4-bit checksum \u2014 NEC-family modulation but NOT plain 32-bit NEC \u2014 is correct; LG is a separately-defined protocol in the library. The named gist (a59379c9772717a6e2fbb822a383114b, \"LG TV 2008-2013 NEC IR Codes\") does contain per-button LG TV codes. No adversarial pitfall applies: not Samsung32 confusion, correct carrier, and not a false \"distinct protocol\" claim. All claims hold."
   }
  ]
 },
 {
  "target": "tv-sony-panasonic",
  "protocols": [
   {
    "brand": "Sony",
    "kind": "TV",
    "protocolName": "SIRC (Sony Infrared Remote Control / SIRCS)",
    "carrierHz": 40000,
    "frameSummary": "Pulse-WIDTH coded. Carrier 40kHz (~1/3 duty). Leader/start burst = 2400us mark followed by 600us space. Each bit: bit-mark of 1200us = logical '1', 600us = logical '0', each followed by a 600us space. LSB-first. Three variants: 12-bit (7-bit command + 5-bit address/device), 15-bit (7-bit command + 8-bit address), 20-bit (7-bit command + 5-bit address + 8-bit extended). Standard TVs use the 12-bit variant: device address 1 (TV). Full frame width is padded so total frame = 45ms; frames are auto-repeated every 45ms while a key is held. No checksum/parity in the frame.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Sony.cpp (sendSony/decodeSony, 12/15/20-bit, kSonyHdrMark 2400, kSonyOneMark 1200, kSonyZeroMark 600, 40kHz); SB-Projects SIRC page (sbprojects.net/knowledge/ir/sirc.php); LIRC remote DB (Sony devices); IRDB github.com/probonopd/irdb (Sony TV per-button codes). Cross-checked righto.com Sony IR analysis.",
    "notes": "Distinct, dedicated Sony protocol \u2014 NOT generic NEC. The key implementation gotcha is Sony sends each command at least 3 times (3 frames) per keypress; many devices ignore a single frame. Address byte for TV is typically 1. Per-button command codes (e.g. power toggle, vol up/down, channel) are fully enumerated in LIRC and IRDB. 12-bit is the common TV variant; some newer Bravia sets use 15-bit or 20-bit for extended functions."
   },
   {
    "brand": "Panasonic",
    "kind": "TV",
    "protocolName": "Kaseikyo / Panasonic (48-bit)",
    "carrierHz": 37000,
    "frameSummary": "Pulse-DISTANCE coded. Carrier 37kHz. Unit = 432us. Leader = 3456us mark (8 units) + 1728us space (4 units). Bit-mark = 432us for every bit; bit value set by the space: 1296us space = '1', 432us space = '0'. LSB-first, 48 bits total. Frame = 16-bit manufacturer/vendor code (0x2002, i.e. bytes 0x40 0x04, for Panasonic) + 8-bit device/genre code + 8-bit subdevice code + 8-bit function/command code + 8-bit checksum. Checksum = device XOR subdevice XOR function. Message terminated by a ~5000us end gap; min repeat gap ~74.7ms.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Panasonic.cpp & ir_Panasonic.h (sendPanasonic64/encodePanasonic, kPanasonicHdrMark 3456, kPanasonicHdrSpace 1728, kPanasonicBitMark 432, kPanasonicOneSpace 1296, kPanasonicZeroSpace 432, 37kHz, kPanasonicManufacturer 0x4004); Arduino-IRremote ir_Kaseikyo.hpp (KASEIKYO_UNIT 432, vendor-ID + parity + address + command + parity); LIRC Panasonic remotes; IRDB Panasonic TV codes.",
    "notes": "This is the Kaseikyo protocol (co-developed by Panasonic/Matsushita, JVC, Denon, Sharp, Mitsubishi); the vendor/manufacturer ID field selects the brand, with 0x2002/0x4004 = Panasonic. It is a real distinct protocol, NOT NEC. The 8-bit XOR checksum must be computed for any synthesized frame. Per-button command codes for Panasonic TVs are enumerated in LIRC and IRDB. Note: the Panasonic AC protocol shares the same low-level timing but is a multi-section, much-longer (e.g. 27-byte) stateful frame and is entirely separate from the TV remote protocol \u2014 do not conflate them."
   }
  ],
  "verdicts": [
   {
    "brand": "Sony",
    "protocolName": "SIRC (Sony Infrared Remote Control / SIRCS)",
    "verdict": "confirmed",
    "correctedCarrierHz": 40000,
    "correctedProtocol": "",
    "reasoning": "Every claimed parameter is independently confirmed by reputable sources (SB-Projects SIRC page, righto.com Sony analysis, edcheung.com SIRCS spec, and IRremoteESP8266 ir_Sony.cpp). Carrier: 40kHz with ~1/3 (or 1/4) duty cycle - correct, and distinct from the 38kHz norm and Panasonic's ~37kHz, so no carrier confusion. Encoding: pulse-WIDTH coded - confirmed. Leader/start burst: 2.4ms (2400us) mark + 0.6ms (600us) space - confirmed, and used by the receiver for gain adjustment. Bit timing: logical '1' = 1.2ms (1200us) mark, logical '0' = 0.6ms (600us) mark, each followed by a 0.6ms (600us) space - confirmed exactly (matches kSonyHdrMark 2400 / kSonyOneMark 1200 / kSonyZeroMark 600). Bit order: LSB-first - confirmed. Variants: 12-bit (7-bit command + 5-bit address/device), 15-bit (7-bit command + 8-bit address), 20-bit (7-bit command + 5-bit address + 8-bit extended) - all three confirmed with correct field layouts. Standard TV uses the 12-bit variant with device address 1 - consistent with sources. Repeat: frame padded so total = 45ms, auto-repeated every 45ms (measured start-to-start) while a key is held - confirmed verbatim. No checksum/parity - confirmed; SIRC has no error-detection field. This is a genuinely distinct protocol (not generic NEC), the carrier is correct, and there is no NEC/Samsung32 confusion. No corrections needed."
   },
   {
    "brand": "Panasonic",
    "protocolName": "Kaseikyo / Panasonic (48-bit)",
    "verdict": "confirmed",
    "correctedCarrierHz": 37000,
    "reasoning": "Independently confirmed via three reputable, mutually independent sources: (1) IRremoteESP8266 ir_Panasonic doxygen/source \u2014 kPanasonicHdrMark=3456, kPanasonicHdrSpace=1728, kPanasonicBitMark=432, kPanasonicOneSpace=1296, kPanasonicZeroSpace=432, kPanasonicEndGap=5000, kPanasonicMinGap=74736 (~74.7ms), all exactly as claimed; (2) Arduino-IRremote ir_Kaseikyo.hpp \u2014 KASEIKYO_UNIT=432us (16 cycles of 37kHz), header 8 units mark + 4 units space, one-space=3 units, zero-space=1 unit, 48-bit pulse-distance, vendor-ID + parity/checksum framing; (3) DecodeIR (hifi-remote JP1 authoritative reference) IRP: {37k,432}<1,-1|1,-3>(8,-4,2:8,32:8,D:8,S:8,F:8,(D^S^F):8,1,-173)+ \u2014 which independently confirms 37kHz carrier, 432us unit, 8/4-unit leader, pulse-distance bit coding (mark always 1 unit; 1='1' set by 3-unit space, '0' by 1-unit space), LSB-first 48 bits, and checksum = D XOR S XOR F. This carrier (~37kHz) is correctly distinct from Sony (~40kHz) and the NEC/Samsung family (~38kHz); the protocol is a genuinely distinct multi-field 48-bit Kaseikyo frame, not generic NEC. The 16-bit Panasonic vendor code (0x2002 / manufacturer constant 0x4004) is correct. Minor note: IRremoteESP8266 defines kPanasonicFreq=36700Hz rather than a literal 37000, but this rounds to ~37kHz and the claim itself stated 'Carrier ~37kHz', so this is not a substantive discrepancy. All load-bearing claims (framing, timings, checksum, carrier band, repeat gap) are verified."
   }
  ]
 },
 {
  "target": "tv-sharp-toshiba",
  "protocols": [
   {
    "brand": "Sharp",
    "kind": "TV",
    "protocolName": "Sharp",
    "carrierHz": 38000,
    "frameSummary": "Distinct Sharp protocol (NOT generic NEC), pulse-distance modulation. No long AGC leader like NEC; frame begins directly with bits. Bit mark ~260us (38kHz burst, ~12 cycles); '0' space ~781us (total bit ~1ms), '1' space ~1821us (total bit ~2ms); end-of-frame gap ~43.6ms. 15 bits total transmitted LSB-first: Address(5) + Command(8) + Expansion(1) + Check(1). Frame sent twice: the second frame is the same Address but with Command/Expansion/Check bits inverted, ~40ms after the first, for error verification. IRremoteESP8266 ir_Sharp.cpp constants: kSharpAddressBits=5, kSharpCommandBits=8, kSharpBitMark=260us, kSharpOneSpace=1821us, kSharpZeroSpace=781us.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Sharp.cpp (sendSharp/encodeSharp + kSharp* constants); SB-Projects IR Sharp protocol page (sbprojects.net/knowledge/ir/sharp.php); IRDB codes/Sharp/TV/1,-1.csv (protocol column = 'Sharp', device 1, e.g. POWER=22, VOL+=20, VOL-=21, MUTE=23, CH+=17, CH-=18)",
    "notes": "Sharp TVs use a real, distinct, named protocol with its own framing and a built-in inverted-repeat check frame - it is NOT generic NEC. This is the same base 'Sharp' protocol IRremoteESP8266 exposes via sendSharp(address, command) and encodeSharp(); it is separate from the Sharp A/C protocol (kSharpAc) which is a 13-byte stateful frame. IRDB provides per-button function codes (5-bit address + 8-bit command form) ready to encode."
   },
   {
    "brand": "Toshiba",
    "kind": "TV",
    "protocolName": "NEC",
    "carrierHz": 38000,
    "frameSummary": "Standard NEC (IRDB protocol variant 'NEC1'). 9000us mark + 4500us space AGC leader; 560us bit mark; '0' = 560us mark + 560us space; '1' = 560us mark + 1690us space; 560us trailing mark; ~40ms frame period. 32 data bits LSB-first: Address(8) + ~Address(8) + Command(8) + ~Command(8) (inverted bytes for error check). Held-button repeat = 9000us + 2250us 'ditto' frame. IRDB device 64, subdevice -1 (so high address byte is the inverse of 64). Sample commands: POWER toggle=18, VOL+=26, VOL-=30, CH+=27, CH-=31, MUTE=16.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRDB codes/Toshiba/TV/64,-1.csv (protocol='NEC1'/'NEC', device 64); LIRC generic NEC.conf (lirc.sourceforge.net/remotes/generic/NEC.conf); IRremoteESP8266 src/ir_NEC.* and SupportedProtocols.md (notes Toshiba 42TL838 LCD TV decodes as NEC)",
    "notes": "Toshiba TVs do NOT have a brand-specific TV protocol - they use plain NEC (8-bit address with inverted complement + 8-bit command with inverted complement). Fully implementable with a generic NEC encoder plus IRDB per-button function codes. IMPORTANT: the TOSHIBA_AC protocol in IRremoteESP8266 is a separate stateful A/C frame and is unrelated to Toshiba TVs."
   },
   {
    "brand": "Hitachi",
    "kind": "TV",
    "protocolName": "NEC",
    "carrierHz": 38000,
    "frameSummary": "Standard NEC (IRDB variants 'NEC1'/'NEC2'). 9000us mark + 4500us space leader; 560us bit mark; '0'=560+560us, '1'=560+1690us; 560us trailing mark; ~110ms total/repeat period with 9000+2250us ditto repeats. 32 data bits LSB-first: Address(8) + ~Address(8) + Command(8) + ~Command(8). IRDB device 80, subdevice -1. Sample commands: POWER=23, MUTE=11, VOL UP=18, CH UP=25, MENU=83, EXIT=100. (Some older Hitachi sets historically also appear as RC5-style in other DBs, but the dominant public Hitachi TV data is NEC.)",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRDB codes/Hitachi/TV/80,-1.csv (protocol='NEC1'/'NEC'/'NEC2', device 80; also 96,-1 / 80,143 / 80,173 / 12,251 files); LIRC generic NEC.conf; RemoteCentral Hitachi model list (remotecentral.com/cgi-bin/codes/hitachi/)",
    "notes": "Hitachi TVs use generic NEC, not a distinct brand protocol. Multiple device IDs exist across model lines (80, 96, 12), each with full per-button NEC function codes in IRDB - ready to encode with a generic NEC encoder. IMPORTANT: the HITACHI_AC / HITACHI_AC1 / HITACHI_AC2 / HITACHI_AC424 protocols in IRremoteESP8266 are stateful air-conditioner frames and are NOT related to Hitachi TVs; do not conflate them."
   }
  ],
  "verdicts": [
   {
    "brand": "Sharp",
    "protocolName": "Sharp",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Independently confirmed from both cited reputable sources. (1) SB-Projects Sharp page (sbprojects.net/knowledge/ir/sharp.php) confirms: 38kHz carrier; ~320us mark as a 38kHz burst (~12 cycles); logical '0' = 1ms total, logical '1' = 2ms total; 5 address bits + 8 command bits + expansion + check (15 total); LSB-first; NO AGC leader/header burst (unlike NEC); one command = two messages, the second sent ~40ms after the first with all non-address bits INVERTED for verification. This is a distinct pulse-distance protocol, not generic NEC (NEC has a 9ms+4.5ms AGC leader, which Sharp lacks) and not Samsung32. (2) IRremoteESP8266 src/ir_Sharp.cpp confirms the exact constants: kSharpTick=26us, kSharpBitMarkTicks=10 -> kSharpBitMark=260us; kSharpOneSpaceTicks=70 -> kSharpOneSpace=1820us; kSharpZeroSpaceTicks=30 -> kSharpZeroSpace=780us; kSharpGapTicks=1677 -> kSharpGap=43602us (~43.6ms); kSharpAddressBits=5; kSharpCommandBits=8; sendSharpRaw uses 38kHz. The claim's 1821us/781us are trivial rounding artifacts of the tick math (70x26=1820, 30x26=780); 12us discrepancy is negligible and the claim's own bit-total framing (1ms/2ms bit, 43.6ms gap) is correct. Carrier is correctly 38000Hz (not Panasonic 37kHz or Sony 40kHz). Bit mark of ~260us at 38kHz equals ~9.9 cycles, consistent with the claimed ~12 cycles / 320us burst description. All material claims verified; verdict confirmed."
   },
   {
    "brand": "Toshiba",
    "protocolName": "NEC",
    "verdict": "confirmed",
    "reasoning": "Every claimed parameter independently checks out against reputable sources. SB-Projects (sbprojects.net/knowledge/ir/nec.php) confirms NEC framing: 38kHz carrier, 9ms AGC mark + 4.5ms space leader, 560us bit mark, '0'=560us mark+560us space (1.125ms total), '1'=560us mark+1690us space (2.25ms total), 560us trailing mark, 32 data bits LSB-first as Address(8)+~Address(8)+Command(8)+~Command(8) with inverted bytes for error checking. The held-button repeat is confirmed as a 9ms mark + 2.25ms space 'ditto' frame (plus 560us burst), matching the claim. The Toshiba TV association is confirmed independently: IRremoteESP8266 src/ir_NEC.h explicitly lists 'Brand: Toshiba, Model: 42TL838 LCD TV' as decoding via the NEC protocol, and its SupportedProtocols.md / search corroborate this. No protocol confusion: carrier is correctly 38kHz (not Sony ~40kHz or Panasonic ~37kHz), and the framing is standard NEC, not Samsung32 (which uses a different bit/byte structure). The IRDB device=64, subdevice=-1 detail (high address byte = inverse of 64) is consistent with the standard 8-bit-address-with-complement NEC1 variant, where subdevice -1 signals the inverted-address form rather than the extended-NEC 16-bit address form. Sample command values are internally consistent with an 8-bit command space. Verdict: confirmed."
   },
   {
    "brand": "Hitachi",
    "protocolName": "NEC",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently confirmed from the primary source and multiple corroborating references. I fetched the actual IRDB file codes/Hitachi/TV/80,-1.csv (github.com/probonopd/irdb) and verified protocol=NEC1/NEC2/NEC, device=80, subdevice=-1, and the exact sample commands: POWER=23, MUTE=11, VOL UP=18, CH UP=25, MENU=83, EXIT=100 \u2014 all matching the claim verbatim. The NEC framing is standard and confirmed by SB-Projects, Vishay datasheet, and irq5.io: 38kHz carrier; 9000us mark + 4500us space leader; 560us (562.5us) bit mark; '0'=560+560us, '1'=560+1690us; 32-bit payload Address(8)+~Address(8)+Command(8)+~Command(8) sent LSB-first; ~110ms frame with 9000+2250us ditto repeats. Adversarial checks all clear: (1) Not Samsung32 \u2014 NEC's 9000us leader mark distinguishes it from Samsung's 4500us leader, and NEC uses an inverted address rather than Samsung's repeated address; (2) Carrier is correctly 38000Hz, not Sony 40kHz or Panasonic 37kHz; (3) This is a TV, so no Midea/Coolix AC-protocol confusion applies; (4) The claim itself appropriately acknowledges older RC5-style Hitachi sets in other DBs while correctly identifying NEC as the dominant public Hitachi TV data. All claimed parameters are independently corroborated."
   }
  ]
 },
 {
  "target": "tv-hisense-tcl",
  "protocols": [
   {
    "brand": "Hisense",
    "kind": "TV",
    "protocolName": "NEC",
    "carrierHz": 38000,
    "frameSummary": "Standard NEC: 38 kHz carrier; 9000 us leader mark + 4500 us space; 562.5 us bit-mark; logical 0 = 562.5 us space, logical 1 = 1687.5 us space; 32 bits total sent LSB-first = [8-bit address][8-bit inverted address][8-bit command][8-bit inverted command]; ends with a final 562.5 us stop bit. Repeats use a 9000 us mark + 2250 us space ditto frame. Hisense uses a single fixed address byte (the high 16 bits of the 32-bit word are constant across all buttons) and varies only the command byte. Example full 32-bit (MSB-first hex as commonly captured): Power-toggle 0x00FDB04F, Input 0x00FD48B7, VolUp 0x00FD22DD, VolDown 0x00FDC23D, Mute 0x00FD708F, Digit1 0x00FD807F. Discrete power-on/off exist on some Prosumer/commercial models (e.g. Power On 0x00FD0BF4 / Power Off 0x00FD8B74) via Hisense's published discrete IR list; consumer models are often power-toggle only and lack discrete HDMI-input codes.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "ant-thomas Gist (HiSense B7500 NEC Arduino/LIRC codes) https://gist.github.com/ant-thomas/122b12c9570058c0f2ca43da96e59a76 ; hawkins.id.au 'Discrete IR codes for a Hisense TV' (32-bit NEC, brute-forced commands); Hisense USA official 'Discrete IR Commands' PDF (Pronto CCF) and 'RS-232/IR Protocol' PDF for Prosumer TVs; IRremoteESP8266 NEC decoder (decode_NEC.cpp).",
    "notes": "Real per-button codes are publicly available and a complete NEC spec exists, so an encoder can be written today with sendNEC(0xADDR<<24 | ...) style. Caveat: address byte and exact command map differ per Hisense remote/model family; the B7500 set and the Hisense commercial discrete list are two distinct concrete code tables. Many consumer sets have only Power-toggle (no discrete On/Off) and no discrete HDMI codes. Verify the address byte for the specific target model. This is a genuine, standards-conformant NEC implementation, not a vague 'generic NEC' claim."
   },
   {
    "brand": "TCL",
    "kind": "TV",
    "protocolName": "NEC (modern sets); RCA-38 on some older/RCA-built models",
    "carrierHz": 38000,
    "frameSummary": "Modern TCL (incl. many Roku/Android TCL sets) use standard NEC: 38 kHz; 9000 us leader mark + 4500 us space; 562.5 us bit-mark; 0 = 562.5 us space, 1 = 1687.5 us space; 32 bits LSB-first = [addr][~addr][cmd][~cmd]. TCL uses a fixed 16-bit address word 0x57E3 (i.e. address byte 0xE3 / 0xA7 little-endian split as captured); only the command byte varies. Per-button 32-bit words (full hex as captured): Power 0x57E318E7, Mute 0x57E304FB, VolUp 0x57E3F00F, VolDown 0x57E308F7, HDMI1 0x57E3847B, HDMI2 0x57E344BB, HDMI3 0x57E3C43B, plus discrete On/Off/HDMI on R615/R617 series. NOTE: IRDB's one TCL/TV table is the RCA-38 protocol (device 15) \u2014 RCA-38 is NEC-like but 56 us bit-cell / 4000 us leader family \u2014 used by some older RCA-OEM TCL sets; so TCL spans more than one protocol across generations.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "DDRBoxman Gist 'TCL TV IR Codes' (NEC, addr 0x57E3, full per-button hex) https://gist.github.com/DDRBoxman/c68b68e41a47338496ba8cbd1bb5d20e ; AVS Forum 'Discrete IR Codes for TCL 65R615/65R617'; Crestron groups.io 'New TCL TV devices - Discrete IR Codes'; IRDB codes/TCL/TV/15,-1.csv (protocol RCA-38, device 15) https://github.com/probonopd/irdb/blob/master/codes/TCL/TV/15%2C-1.csv ; IRremoteESP8266 NEC + RCA decoders.",
    "notes": "Ready to implement for the dominant case: standard 32-bit NEC with fixed address 0x57E3 and the documented command map (incl. discrete On/Off and HDMI inputs on R6xx series). Be aware of the protocol split: IRDB's only TCL TV entry is RCA-38 (an RCA-derived NEC-like protocol), reflecting older RCA-OEM TCL models. For a real product, ship the NEC 0x57E3 set as primary and optionally RCA-38 as a fallback. Not a guess \u2014 both code sets are concrete and public."
   },
   {
    "brand": "Haier",
    "kind": "TV",
    "protocolName": "NEC",
    "carrierHz": 38000,
    "frameSummary": "Standard NEC: 38 kHz; 9000 us leader mark + 4500 us space; 562.5 us bit-mark; 0 = 562.5 us space, 1 = 1687.5 us space; 32 bits LSB-first = [addr 0x04][~addr 0xFB][cmd][~cmd]. Address byte is 0x04 across the remote; only the command byte changes. Captured per-button command bytes (as documented in LIRC-format/Flipper captures): CH+ = 0x00, CH- = 0x01, VOL+ = 0x02, VOL- = 0x03, Power = 0x04 (toggle on the captured remote), Mute = 0x09. Full 32-bit word example for VOL+ \u2248 addr 0x04, cmd 0x02 -> 0x04FB02FD (MSB-first). Carrier/bit timings are the NEC defaults; the captures themselves list address+command, not raw timings.",
    "publicDataAvailable": true,
    "confidence": "medium",
    "implementability": "partial",
    "source": "Flipper Zero firmware issue #2029 'IR signals from Haier TV' (NEC, address 0x04, parsed per-button captures) https://github.com/flipperdevices/flipperzero-firmware/issues/2029 ; probonopd/lirc-remotes database (NEC-format Haier configs); LIRC generic NEC.conf template. No Haier/TV entry exists in IRDB (codes/Haier absent from the repo tree).",
    "notes": "Protocol is confidently NEC with address byte 0x04, and several real command bytes are publicly captured (CH+/-, VOL+/-, Power, Mute). However the public per-button set is INCOMPLETE: no documented discrete digits/HDMI-input/source/menu/arrow codes, and the captures come from a single user-contributed remote rather than a full vendor spec or a vetted LIRC remotes-table entry. Enough to build a working basic encoder (power/volume/channel/mute) right now, but not a full remote \u2014 hence 'partial'. A complete table would require capturing the target Haier remote directly. This is a real distinct NEC code set (addr 0x04), not merely 'generic NEC'."
   }
  ],
  "verdicts": [
   {
    "brand": "Hisense",
    "protocolName": "NEC",
    "correctedCarrierHz": 38000,
    "verdict": "confirmed",
    "reasoning": "Independent web sources confirm every load-bearing element of the claim. Justin Hawkins' blog (hawkins.id.au, 'Discrete IR codes for a Hisense TV') explicitly states Hisense TVs use the NEC protocol with a single 32-bit number per command, that the NEC address space is effectively 8-bit, and that 'every code I've learned has the same initial 16 bits' \u2014 confirming the fixed-address/varying-command structure. The exact example codes match: Power-toggle 0x00FDB04F, VolUp 0x00FD22DD, plus discrete Power On 0x00FD0BF4 and Power Off 0x00FD8B74. Hisense USA's official 'Discrete IR Commands' PDF and 'RS-232/IR Protocol for Prosumer TV' PDF corroborate the discrete-code list (discrete on/off available on prosumer/commercial units; consumer remotes are often power-toggle-only, as the H9G AVForums thread notes). Carrier frequency: standard NEC is ~38kHz (the NEC spec sheet cites 38.222kHz nominal); 38000Hz is the correct, conventional value used by IRremoteESP8266's NEC decoder. NEC framing in the claim (9000us leader mark + 4500us space, 562.5us bit mark, 0=562.5us space, 1=1687.5us space, 32 bits LSB-first as addr/~addr/cmd/~cmd, 562.5us stop, repeat = 9000us mark + 2250us space) matches the canonical NEC protocol definition. No confusion with Samsung32 (which uses an 8-bit leader and different framing) or with Panasonic (~37kHz) / Sony (~40kHz). The note that Hisense's address byte does NOT satisfy the classic NEC addr/~addr inversion (it's a single fixed byte, making it 'extended NEC'-like) is consistent with how decoders capture it as a raw 32-bit word. No discrepancies found; claim is confirmed."
   },
   {
    "brand": "TCL",
    "protocolName": "NEC (modern sets); RCA-38 on some older/RCA-built models",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "verdict": "confirmed",
    "reasoning": "Independently confirmed across all claim elements. (1) Protocol/carrier: Modern TCL uses standard NEC at 38 kHz with classic timings (9000us leader mark, 4500us space, 562.5us bit-mark, 0=562.5us space, 1=1687.5us space), corroborated by multiple NEC protocol references (sbprojects, Vishay) and the DDRBoxman gist which sends via irsend.sendNEC(payload,32). (2) Address + per-button hex: The DDRBoxman gist 'TCL TV IR Codes' was fetched and matches the claim exactly: fixed 16-bit address 0x57E3 with Power 0x57E318E7, Mute 0x57E304FB, VolUp 0x57E3F00F, VolDown 0x57E308F7, HDMI1 0x57E3847B, HDMI2 0x57E344BB, HDMI3 0x57E3C43B. (3) NEC vs Samsung32 adversarial check PASSED: every code's low two bytes are a perfect command/~command complement (e.g. 0x18/0xE7, 0x04/0xFB, 0xF0/0x0F, 0x08/0xF7, 0x84/0x7B, 0x44/0xBB, 0xC4/0x3B), which is the NEC framing signature; Samsung32 instead repeats the address byte, so Samsung32 is ruled out. The 0x57E3 is a fixed 16-bit extended-NEC address (no addr/~addr inversion), exactly as the frame describes. (4) RCA-38 generational span: confirmed by fetching IRDB codes/TCL/TV/15,-1.csv directly, which exists and is protocol RCA-38, device 15 (41 functions, NEC-like RCA family). Carrier is correctly 38000 Hz (not Sony ~40k or Panasonic ~37k). All claims hold; no correction needed."
   },
   {
    "brand": "Haier",
    "protocolName": "NEC",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "The core protocol claim is independently confirmed by reputable sources. Flipper Zero firmware issue #2029 (\"IR signals from Haier TV for universal remote control\") explicitly documents the Haier TV as NEC protocol, address 04 00 00 00, with command bytes matching the claim exactly: CH+ = 0x00, CH- = 0x01, VOL+ = 0x02, VOL- = 0x03, Mute = 0x09. The 38kHz carrier and standard NEC framing (9ms AGC leader mark + 4.5ms space; 562.5us bit-mark; logical 0 = 562.5us space, logical 1 = 1687.5us/1.6875ms space; 32-bit LSB-first frame of [addr][~addr][cmd][~cmd] with both address and command sent then inverted for verification) are confirmed by multiple independent NEC references (sbprojects.net NEC protocol page, infishark, hackaday). The VOL+ example 0x04FB02FD is consistent: addr 0x04, ~addr 0xFB, cmd 0x02, ~cmd 0xFD (MSB-first representation). No confusion with Samsung32 (different framing/leader) and the carrier is correctly 38kHz, not Panasonic ~37kHz or Sony ~40kHz. The only discrepancy is the Power = 0x04 button: the original issue #2029 listed only five buttons (CH+/-, VOL+/-, Mute) and did not include Power, but the claim flags this as a value from the captured remote (plausibly from an extended Flipper .ir capture) and it does not affect the protocol/address/carrier identification. This is a parsed per-button NEC capture, not a distinct proprietary protocol, and it is not an AC protocol mismatch (this is a TV, not Midea/Coolix AC). Verdict: confirmed."
   }
  ]
 },
 {
  "target": "tv-philips-xiaomi",
  "protocols": [
   {
    "brand": "Philips",
    "kind": "TV",
    "protocolName": "RC5",
    "carrierHz": 36000,
    "frameSummary": "Manchester (bi-phase) encoded, 36kHz. No discrete leader pulse; every bit = 1.778ms (889us mark + 889us space halves). Logical 1 = space-then-mark, logical 0 = mark-then-space. 14-bit frame: 2 start bits (S1=1 always, S2/field bit used as command MSB extension in RC5X), 1 toggle bit (flips each new keypress), 5-bit system/address, 6-bit command. Total 14 bits. RC5X variant uses S2 as a 7th command bit giving extended commands.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_RC5_RC6.cpp (sendRC5/kRC5Bits=13, kRC5XBits=14, kRC5T1=889us, carrier 36kHz); SB-Projects RC-5 spec (sbprojects.net/knowledge/ir/rc5.php)",
    "notes": "Used by older/legacy Philips TVs. Real per-button system+command code pairs are widely published (e.g. TV system addr 0x00, Power=0x0C, Vol+=0x10, Ch+=0x20). Fully encodable now. IRremoteESP8266 exposes sendRC5() taking a data word + nbits."
   },
   {
    "brand": "Philips",
    "kind": "TV",
    "protocolName": "RC6 (mode 0)",
    "carrierHz": 36000,
    "frameSummary": "Manchester encoded, 36kHz, base time t=444us (16 carrier cycles). Leader: 6t mark (2666us) + 2t space (889us). Then start bit (always 1), 3 mode/field bits (000 for mode 0), 1 toggle bit which is DOUBLE width (2t each half, 889us), 8-bit address (MSB first), 8-bit command (MSB first). 20 significant bits (1 start + 3 mode + 1 toggle + 8 addr + 8 cmd), ~22 bit-times total. Followed by >=2.666ms idle. Bit sense is INVERTED vs RC5: logical 1 = mark-then-space.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_RC5_RC6.cpp (sendRC6/kRC6Mode0Bits=20, kRC6T1=444us, kRC6HdrMark=2666us, kRC6HdrSpace=889us, double-wide toggle); SB-Projects RC-6 spec (sbprojects.net/knowledge/ir/rc6.php); pcbheaven.com RC6 writeup",
    "notes": "Used by modern Philips TVs (e.g. 22PFT4000 etc., addr 0x00, Power=0x0C). RC6 mode 6/RC6-MCE (36-bit, toggle at 16th LSB) also exists for some STBs but TVs use mode 0. sendRC6() implemented and ready. Distinct real protocol, NOT generic NEC."
   },
   {
    "brand": "Xiaomi",
    "kind": "TV",
    "protocolName": "Xiaomi-IR (RC-MM variant, quaternary)",
    "carrierHz": 36000,
    "frameSummary": "36kHz carrier, quaternary (2-bits-per-symbol) pulse-distance like RC-MM but with Xiaomi-specific space lengths. IRP: {36k,290,msb}<2,-2|2,-3|2,-4|2,-5>(1000u,-2,D:8,F:8,C:4,2,^30m). i.e. leader ~1000us mark + ~580us space, then symbols each ~580us mark with one of four space lengths (2/3/4/5 x ~290us) encoding 00/01/10/11. Payload = 8-bit device D, 8-bit function F, 4-bit checksum C, where C = (D:4:4 ^ D:4 ^ F:4:4 ^ F:4). 20 data bits. Frame repeats at 30ms intervals.",
    "publicDataAvailable": true,
    "confidence": "medium",
    "implementability": "partial",
    "source": "JP1/hifi-remote.com Xiaomi TV 4S thread (t=102671) giving the exact IRP and device codes; ysard/mi_remote_database (reverse-engineered Mi Remote app IRDB)",
    "notes": "Real per-button codes are public: device D=0x86 (134) for most keys (Vol+=0x0E, Mute=0xA1, OK=0x0D, Up=0x05), POWER uses device 0x3C with function 0xC1. This is NOT plain NEC and NOT identical to IRremoteESP8266's generic RCMM decoder (different space lengths + custom XOR checksum), so the library cannot send it out-of-the-box. Implementable via a raw/IRP-driven encoder using the documented timings and checksum formula. Marked partial because a ready-made named encoder does not exist; you must hand-build the raw frame. Note many third-party 'Xiaomi universal' remote code lists actually emit NEC for various TVs, but the genuine Mi TV remote protocol is this RC-MM variant."
   },
   {
    "brand": "Daewoo",
    "kind": "TV",
    "protocolName": "NEC (NEC1 / NECx1)",
    "carrierHz": 38000,
    "frameSummary": "Standard NEC: 38kHz, leader 9000us mark + 4500us space, then 32 bits pulse-distance coded (560us mark; 560us space = 0, 1690us space = 1), trailing 560us mark. NEC1 = 8-bit address + 8-bit ~address + 8-bit command + 8-bit ~command (device/subdevice -1 means address byte's complement is used). NECx1 variant uses a true 16-bit address (device + subdevice, e.g. 6/6) with command + complement. Repeat frames = 9000us+2250us leader + single mark.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "probonopd/irdb codes/Daewoo/TV/4,-1.csv (NEC1 dev 4: Power func 8), codes/Daewoo/TV/6,6.csv (NECx1 dev 6 subdev 6: Power func 15); IRremoteESP8266 src/ir_NEC.cpp (sendNEC, kNecBits=32)",
    "notes": "Real per-button codes published in IRDB with explicit protocol/device/subdevice/function. Most Daewoo TVs are NEC1/NECx1 and directly sendable with IRremoteESP8266 sendNEC() after composing the 32-bit word. CAVEAT: a third Daewoo TV code set in IRDB (20,-1.csv) uses the 'Proton' protocol (also a NEC-family pulse-distance protocol, 38kHz, distinct timing/bit-order) \u2014 IRremoteESP8266 has no named Proton encoder, so that specific code set would need a raw encoder. Primary/most-common Daewoo path is ready via NEC."
   }
  ],
  "verdicts": [
   {
    "brand": "Philips",
    "protocolName": "RC5",
    "correctedCarrierHz": 36000,
    "correctedProtocol": "",
    "verdict": "confirmed",
    "reasoning": "Every element of the claim is independently confirmed by the authoritative SB-Projects RC-5 page and corroborated by Wikipedia/IRremote sources. (1) Carrier: 36kHz - confirmed (not 38kHz, which would be the common-mistake trap). (2) Manchester/bi-phase encoding with no discrete leader pulse - confirmed; every bit is a high/low or low/high transition. (3) Bit time 1.778ms = 64 cycles of 36kHz, half-bit 889us - confirmed exactly, matching IRremoteESP8266 kRC5T1=889us. (4) Polarity: logical 1 = space-then-mark (idle-then-burst, burst in second half), logical 0 = mark-then-space (burst in first half) - confirmed verbatim. (5) 14-bit frame: 2 start bits (S1 always 1), 1 toggle bit (flips on each new keypress/release), 5-bit address, 6-bit command - confirmed. (6) RC5X variant repurposes S2 (inverted) as a 7th command bit, keeping the first 64 commands compatible - confirmed. (7) Philips TV is the canonical/originating RC5 device. The IRremoteESP8266 'kRC5Bits=13' is a data-bit count that drops the always-1 S1 start bit, fully consistent with the 14-bit physical frame described. No carrier error, no protocol confusion (not NEC/Samsung/Sony/Panasonic), no generic-NEC substitution. Claim stands as written."
   },
   {
    "brand": "Philips",
    "protocolName": "RC6 (mode 0)",
    "verdict": "confirmed",
    "correctedCarrierHz": 36000,
    "reasoning": "Both independent reputable sources fully corroborate the claim. SB-Projects RC-6 spec: carrier 36kHz; base unit t=444us (16 carrier cycles); leader = 6t mark (~2.666ms) + 2t space (~0.889ms); structure = 1 start bit (always 1) + 3 mode bits (000 for mode 0) + 1 double-width toggle/trailer bit (2t) + 8-bit address + 8-bit command = 20 significant bits; Manchester encoding where logical 1 = mark-then-space, and the page explicitly states this is 'the opposite of the RC-5 protocol' (bit sense inverted vs RC5). IRremoteESP8266 src/ir_RC5_RC6.cpp matches: sendRC6 uses 36kHz with 1/3 (33%) duty cycle, kRc6Tick=444us, kRc6HdrMark=2664us (6t), kRc6HdrSpace=888us (2t), and the 4th transmitted bit (the toggle bit) is double-width (bitTime = 2*kRc6Tick when i==4), with '1' encoded mark-then-space and '0' space-then-mark, noted as reversed compared to RC5. Carrier is correctly 36kHz (not the 38kHz default for NEC/Samsung, ~37kHz Panasonic, or ~40kHz Sony). No NEC/Samsung confusion or carrier error present. Claim confirmed."
   },
   {
    "brand": "Xiaomi",
    "protocolName": "Xiaomi-IR (RC-MM variant, quaternary)",
    "verdict": "confirmed",
    "correctedCarrierHz": 36000,
    "reasoning": "Independently confirmed against the cited primary source (hifi-remote.com JP1 thread t=102671, \"Xiaomi TV 4S IR Codes\") and corroborated by ysard/mi_remote_database. The exact IRP returned by the forum/DecodeIR matches the claim verbatim: {36k,290,msb}<2,-2|2,-3|2,-4|2,-5>(1000u,-2,D:8,F:8,C:4,2,^30m)* {C=(D:4:4^D:4^F:4:4^F:4)} [D:0..255,F:0..255]. Every load-bearing detail checks out: (1) carrier = 36 kHz (not the 38 kHz of NEC/Samsung, nor Panasonic ~37 kHz or Sony ~40 kHz) \u2014 so this is NOT a misidentified generic NEC; (2) it is explicitly described as a RC-MM variant; (3) quaternary 2-bits-per-symbol encoding via four space lengths (2,-2 | 2,-3 | 2,-4 | 2,-5), i.e. ~580us marks with space lengths of 2/3/4/5 x 290us, matching pulse-distance RC-MM style; (4) timing base 290us and leader 1000u mark + -2 (~580us) space; (5) 20 data bits = D:8 + F:8 + C:4; (6) checksum C = (D:4:4 ^ D:4 ^ F:4:4 ^ F:4) = high-nibble XOR low-nibble of D and F; (7) ~30ms (^30m) repeat interval. Device-code examples (e.g. 0x86 for TV 4S) are consistent. No discrepancy found; this is a genuinely distinct Xiaomi-specific RC-MM-derived protocol, not generic NEC, and the carrier is correctly stated as 36 kHz."
   },
   {
    "brand": "Daewoo",
    "protocolName": "NEC (NEC1 / NECx1)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Every element of the claim was independently corroborated by reputable sources.\n\n1) Carrier frequency: Multiple independent sources (sbprojects.net, sigrok, hifi-remote.com IRP) confirm NEC and its NECx variants use a 38.0 kHz carrier. This is NOT one of the carrier-confusion traps: Panasonic (~37kHz) and Sony (~40kHz) differ, but NEC is correctly 38kHz.\n\n2) Frame structure: Confirmed by sbprojects.net and others - 9ms (9000us) leader mark + 4.5ms (4500us) space, 32 bits pulse-distance coded with 560/562.5us mark; 0 = 560us space (1.125ms total), 1 = 1690us space (2.25ms total), trailing 560us mark. Repeat frames = 9ms + 2.25ms (2250us) leader + single mark. Exactly matches the claim.\n\n3) NEC1 vs NECx1 distinction: hifi-remote.com / DecodeIR confirm NEC1 uses 8-bit address + complement (device with subdevice = -1 meaning the complement byte is used), while NECx1 uses a true 16-bit address (device + subdevice, S nearly always = D, e.g. 6/6) with command + complement. IRP for NECx1: {38.0k,564}<1,-1|1,-3>(8,-8,D:8,S:8,F:8,~F:8,...). Matches the claim's framing description precisely.\n\n4) Source verification: I confirmed the irdb GitHub directory codes/Daewoo/TV/ actually contains both 4,-1.csv and 6,6.csv (plus 20,-1.csv). The CSV format (functionname, protocol, device, subdevice, function) matches, e.g. NEC1 device 4 and NECx1 device 6 subdevice 6.\n\n5) IRremoteESP8266 src/ir_NEC.cpp confirmed: sendNEC transmits a 32-bit message (kNECBits = 32) at 38 kHz using sendGeneric with standard NEC header/bit timings.\n\nNo trap conditions triggered: this is genuine NEC (not Samsung32, which shares 38kHz but uses different framing), the carrier is correct at 38kHz (not Panasonic 37k or Sony 40k), it is a real NEC variant (not a misattributed distinct protocol), and it is a TV (not an AC where Midea/Coolix confusion would apply). Verdict: confirmed."
   }
  ]
 },
 {
  "target": "ac-midea",
  "protocols": [
   {
    "brand": "Midea",
    "kind": "AC",
    "protocolName": "Midea (48-bit, NEC-like)",
    "carrierHz": 38000,
    "frameSummary": "48-bit (6-byte) frame, MSB-first. Leader: header mark 4480us + header space 4480us. Bit mark 560us; '0' = 560us mark + 560us space; '1' = 560us mark + 1680us space. Min repeat gap ~4240us. The whole 48-bit message is sent, then an entirely INVERTED copy of the payload is sent (strict decode requires the second message be the bitwise inverse of the first). State layout (union MideaProtocol, 6 bytes): Byte0=Checksum (computed over bits 8-47, reversed-byte sum). Byte1=SensorTemp(7b)+disableSensor(1b) for Follow-Me. Byte2=Reserved(1b)+OffTimer(6b, half-hour units, 0b111111=off)+BeepDisable(1b). Byte3=Temp(5b, 17-30C / 62-86F)+useFahrenheit(1b)+reserved(1b). Byte4=Mode(3b: Cool=0,Dry=1,Auto=2,Heat=3,Fan=4)+Fan(2b: Auto=0,Low=1,Med=2,High=3)+reserved(1b)+Sleep(1b)+Power(1b). Byte5=Type(3b: Command=0b001,Special=0b010,FollowMe=0b100)+Header(5b, typically 0b10100). Toggle-only 'Special' frames carry swing/turbo/econo/light/self-clean/8C-heat. Constants: kMideaBits=48, kMideaMinRepeat=kNoRepeat.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Midea.cpp and src/ir_Midea.h (github.com/crankyoldgit/IRremoteESP8266); kMideaBits=48 in src/IRremoteESP8266.h. Corroborated by sheinz/esp-midea-ir, mpetroff.net (2015), AnalysIR IRForum t=489. Full state encoder/decoder + checksum are implemented in the library.",
    "notes": "This is a REAL distinct full-state HVAC protocol, NOT generic NEC button codes (though bit-level timings resemble NEC). The remote transmits the complete AC state (power/temp/mode/fan) in each frame plus its inverse for integrity; there are no per-button 'codes' to look up \u2014 you compute the 48-bit state and checksum. Temperature setpoint uses a Gray-code-like 5-bit table (per blogs); Follow-Me/sensor temp in Byte1 uses a different binary encoding. IRremoteESP8266's IRMideaAC class is directly portable. Use this for the vast majority of Midea (and many OEM-rebadged) split ACs."
   },
   {
    "brand": "Midea",
    "kind": "AC (24-bit variant / non-AC Midea devices)",
    "protocolName": "Midea24",
    "carrierHz": 38000,
    "frameSummary": "Same NEC-like bit timings as Midea (38kHz, ~4480us leader, 560us bit mark, 560us '0' space, 1680us '1' space). 48 transmitted bits = 24 bits of real data with each data byte immediately followed by its bitwise-inverted byte (alternate-byte inversion), giving 24 effective data bits. Requires at least one repeat (kMidea24MinRepeat=kSingleRepeat). kMidea24Bits=24.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Midea.cpp (Midea24 send/decode) and kMidea24Bits=24 / kMidea24MinRepeat in src/IRremoteESP8266.h.",
    "notes": "Distinct from the 48-bit full-state AC protocol. This 24-bit alternate-byte-inverted form is used by some Midea remotes and Midea-family rebadged devices for discrete commands rather than encoding full HVAC state. Carry both protocols if targeting the whole Midea ecosystem; the 48-bit IRMideaAC is the one needed for AC power/temp/mode/fan control."
   }
  ],
  "verdicts": [
   {
    "brand": "Midea",
    "protocolName": "Midea (48-bit, NEC-like)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Verified against the authoritative IRremoteESP8266 source (src/ir_Midea.cpp and src/ir_Midea.h, crankyoldgit) plus corroborating sheinz/esp-midea-ir.\n\nCONFIRMED items:\n- Carrier 38000 Hz: sendMidea() calls enableIROut(38). Correct. (Note adversarial checks: Panasonic ~37kHz, Sony ~40kHz \u2014 neither applies here; 38kHz is right.)\n- 48-bit / 6-byte frame, MSB-first: kMideaBits = 48 (defined in IRremoteESP8266.h). Confirmed.\n- NEC-like framing (NOT Samsung32, NOT generic NEC, NOT Coolix-as-the-named-protocol): The library's own docs describe Midea as 'basically a 48-bit version of the NEC protocol.' This is a distinct, library-recognized protocol with its own encoder/decoder and checksum, so claiming a distinct 'Midea' protocol is legitimate \u2014 it is not merely generic NEC. (The common 'Midea = Coolix-family' caution refers to a different, separate Midea24/Coolix variant; the 48-bit MideaProtocol with the full state union described here is the correct match for this state layout.)\n- Timing constants exact: kMideaTick=80us. kMideaHdrMark = 56*80 = 4480us; kMideaHdrSpace = 56*80 = 4480us. kMideaBitMark = 7*80 = 560us. '0' space = kMideaZeroSpace = 7*80 = 560us; '1' space = kMideaOneSpace = 21*80 = 1680us. All match the claim precisely.\n- Inverted-copy semantics: the full 48-bit message is sent, then an entirely inverted copy of the payload; strict decode requires the second be the bitwise inverse. Confirmed in source.\n- kMideaMinRepeat = kNoRepeat (Midea does not auto-repeat; the message itself is payload+inverse). Confirmed.\n- State layout (union MideaProtocol, 6 bytes) verified field-by-field from ir_Midea.h source: Byte0=Sum/Checksum; Byte1=SensorTemp(7b)+disableSensor(1b); Byte2=reserved(1b)+OffTimer(6b)+BeepDisable(1b); Byte3=Temp(5b)+useFahrenheit(1b)+reserved(1b); Byte4=Mode(3b)+Fan(2b)+reserved(1b)+Sleep(1b)+Power(1b); Byte5=Type(3b)+Header(5b, typically 0b10100). All match the claim exactly. Mode/Fan/Type enum encodings consistent with library.\n\nONE MINOR DISCREPANCY (does not change verdict): the claim's 'Min repeat gap ~4240us' is slightly off \u2014 the actual kMideaMinGap = (56+7+7)*80 = 5600us. This is a secondary inter-block gap footnote, not a core framing parameter, and does not affect protocol identity, carrier, or bit timing. Given every headline parameter (carrier, bit count, leader, bit timing, inverted-copy structure, full state union, checksum) matches the authoritative source, the verdict is CONFIRMED."
   },
   {
    "brand": "Midea",
    "protocolName": "Midea24",
    "correctedCarrierHz": 38000,
    "verdict": "confirmed",
    "reasoning": "Verified directly against the primary source (crankyoldgit/IRremoteESP8266). In src/IRremoteESP8266.h: kMidea24Bits = 24 and kMidea24MinRepeat = kSingleRepeat (=1), matching the claim exactly. In src/ir_Midea.cpp, the documented header states Midea24 \"is basically a 48-bit version of the NEC protocol with alternate bytes inverted, thus only 24 bits of real data, and with at least a single repeat.\" Encoding builds inverted byte pairs (next ^ 0xFF) and decoding verifies current == (next ^ 0xFF) \u2014 confirming 48 transmitted bits = 24 effective data bits via alternate-byte inversion. sendMidea24() delegates to sendNEC(), so it uses NEC timing/carrier: 38 kHz (NEC default), kNecBitMark = 560us, kNecZeroSpace = 560us ('0'), kNecOneSpace = 1680us ('1'). The carrier is correct at 38 kHz (not Panasonic ~37 kHz nor Sony ~40 kHz). This is genuinely a distinct protocol (Midea24), not plain NEC, because of the mandatory alternate-byte inversion and required repeat. Minor imprecision in the claim: the \"~4480us leader\" actually corresponds to the NEC header SPACE (kNecHdrSpace = 4480us = 8 ticks); the full NEC leader is an 8960us mark followed by the 4480us space. Also, Midea24 strictly uses NEC timings (via sendNEC), not the base Midea/Coolix AC timings \u2014 but every timing value the claim explicitly lists (560/560/1680, 38 kHz) matches NEC and is correct. These are framing nuances, not factual errors in the load-bearing constants, so the claim is confirmed."
   }
  ]
 },
 {
  "target": "ac-daikin",
  "protocols": [
   {
    "brand": "Daikin",
    "kind": "AC",
    "protocolName": "Daikin (Daikin/Daikin280 \u2014 the original/canonical Daikin protocol)",
    "carrierHz": 38000,
    "frameSummary": "Full-state AC protocol (not address/command like NEC). Carrier 38 kHz, pulse-distance, LSB-first bytes. Original Daikin = 35-byte / 280-bit state, sent as 3 frames (8 + 8 + 19 bytes) separated by ~29 ms gaps. Per-frame leader/header mark 3650us / space 1623us; bit mark ~428us, one-space ~1280us, zero-space ~428us. Frame 3 carries the control state: fixed header 0x11 0xDA 0x27 0x00; byte5 = mode/power/timer nibbles (Auto=0, Dry=2, Cool=3, Heat=4, Fan=6); byte6 = temperature = degC*2 in hex (20C -> 0x28); byte8 = fan(upper nibble: 0x3-0x7 = speed1-5, 0xA=Auto, 0xB=Silent) + swing(lower nibble: 0x0=off, 0xF=on); bytes 0x0A-0x0C = timer minutes*60 little-endian; byte0x0D powerful bit; byte0x10 econo (0x80 off/0x84 on); last byte = checksum = (sum of all prior bytes) & 0xFF.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Daikin.h + src/ir_Daikin.cpp (kDaikinStateLength=35, kDaikinHdrMark=3650, kDaikinHdrSpace=1623, kDaikinBitMark=428, kDaikinOneSpace=1280, kDaikinZeroSpace=428, kDaikinGap=29000); blafois/Daikin-IR-Reverse (full byte-level frame-3 layout + checksum)",
    "notes": "This is a genuinely distinct Daikin protocol, NOT generic NEC. The whole AC state (power/temp/mode/fan/swing/timer/powerful/econo) is serialized into the 35-byte frame; you cannot use a per-button code table \u2014 you build and transmit the full state plus an additive 8-bit checksum. Carrier not explicitly written in the original-variant constants but the family/library uses 38 kHz (38000)."
   },
   {
    "brand": "Daikin",
    "kind": "AC",
    "protocolName": "Daikin216 (216-bit variant)",
    "carrierHz": 38000,
    "frameSummary": "27-byte / 216-bit full-state variant. Carrier 38 kHz. Header mark 3440us / space 1750us; bit mark 420us, one-space 1300us, zero-space 450us; inter-frame gap ~29650us. Same general full-state philosophy as the original Daikin: fixed header bytes, then power/mode/temp/fan/swing fields and a trailing additive (&0xFF) checksum; differs in length and exact byte offsets from the 280-bit version.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Daikin.h (kDaikin216StateLength=27, kDaikin216HdrMark=3440, kDaikin216HdrSpace=1750, kDaikin216BitMark=420, kDaikin216OneSpace=1300, kDaikin216ZeroSpace=450) + ir_Daikin.cpp IRDaikin216 class",
    "notes": "One of several length variants Daikin ships across model families. IRremoteESP8266 has a complete encoder/decoder class with state-field accessors (setTemp/setMode/setFan/setSwing/setPower), so it is directly implementable."
   },
   {
    "brand": "Daikin",
    "kind": "AC",
    "protocolName": "Daikin2 / Daikin312 (312-bit, 39-byte variant)",
    "carrierHz": 36700,
    "frameSummary": "39-byte / 312-bit full-state variant, two sections. Carrier 36.7 kHz (note: lower than the 38 kHz of most Daikin variants). Long leader mark ~10024us / space ~25180us, then header mark ~3500us / space ~1728us; bit mark ~460us, one-space ~1270us, zero-space ~420us; ~35.5 ms gap between sections. Encodes full AC state across the 39 bytes (power/mode/temp/fan/swing plus extended features) with additive checksum(s) per section.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Daikin.h (kDaikin2StateLength=39 / kDaikin312StateLength=39, kDaikin2LeaderMark=10024, kDaikin2LeaderSpace=25180, kDaikin2HdrMark=3500, kDaikin2HdrSpace=1728, kDaikin2BitMark=460, kDaikin2OneSpace=1270, kDaikin2ZeroSpace=420, kDaikin2Freq=36700) + IRDaikin2 class in ir_Daikin.cpp",
    "notes": "Distinct timing AND distinct 36.7 kHz carrier \u2014 important to get right or the AC won't respond. Fully implemented in IRremoteESP8266 (IRDaikin2). Daikin312 is a near-identical 39-byte sibling with slightly different timings (hdr 3518/1688, bit 453/1275/414)."
   },
   {
    "brand": "Daikin",
    "kind": "AC",
    "protocolName": "Daikin128 / Daikin64 (128-bit & 64-bit variants)",
    "carrierHz": 38000,
    "frameSummary": "Compact Daikin variants. Daikin128 = 16-byte / 128-bit state; Daikin64 = single 64-bit value. Carrier 38 kHz. Leader mark ~9800us / space ~9800us, header mark 4600us / space 2500us; bit mark 350us, one-space 954us, zero-space 382us; gap ~20300us. State carries power/mode/temp/fan/swing plus model-specific clock/timer fields; checksum included.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Daikin.h (kDaikin128StateLength=16, kDaikin128LeaderMark=9800, kDaikin128HdrMark=4600, kDaikin128HdrSpace=2500, kDaikin128BitMark=350, kDaikin128OneSpace=954, kDaikin128ZeroSpace=382, kDaikin128Gap=20300; kDaikin64 64-bit) + IRDaikin128/IRDaikin64 classes",
    "notes": "Used on certain BRC/portable Daikin units. Note Daikin64 packs the whole state into one 64-bit integer rather than a byte array, but is still a full-state (not NEC) protocol with checksum."
   },
   {
    "brand": "Daikin",
    "kind": "AC",
    "protocolName": "Daikin152 / Daikin160 / Daikin176 / Daikin200 (additional length variants)",
    "carrierHz": 38000,
    "frameSummary": "Family of shorter full-state variants, all 38 kHz, all pulse-distance LSB-first with additive (&0xFF) checksum. Daikin152: 19 bytes/152 bits, hdr 3492/1718us, bit 433/1529/433us, gap 25182us. Daikin160: 20 bytes/160 bits, hdr 5000/2145us, bit 342/1786/700us, gap 29650us. Daikin176: 22 bytes/176 bits, hdr 5070/2140us, bit 370/1780/710us, gap 29410us. Daikin200: 25 bytes/200 bits, hdr 4920/2230us, bit 290/1850/780us, gap 29400us. Each encodes power/mode/temp/fan/swing into its byte layout.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Daikin.h (kDaikin152/160/176/200 StateLength + Hdr/Bit timing constants) + corresponding IRDaikin152/160/176/200 classes in ir_Daikin.cpp",
    "notes": "These cover regional/model-specific Daikin remotes. All are distinct, documented protocols with complete encoder classes in IRremoteESP8266 \u2014 directly implementable. They differ mainly in length, timings, and byte-field positions; the encoding philosophy (build full state, append checksum) is identical to the canonical Daikin protocol."
   }
  ],
  "verdicts": [
   {
    "brand": "Daikin",
    "protocolName": "Daikin (Daikin/Daikin280 \u2014 the original/canonical Daikin protocol)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently confirmed via two reputable sources cited in the claim. IRremoteESP8266 (crankyoldgit) src/ir_Daikin.h doxygen source and ir_Daikin.cpp verify every timing constant exactly: kDaikinHdrMark=3650, kDaikinHdrSpace=1623, kDaikinBitMark=428, kDaikinOneSpace=1280, kDaikinZeroSpace=428, kDaikinGap=29000, with sendDaikin transmitting at 38 kHz via sendGeneric(...,38). The original DAIKIN protocol is a full-state, pulse-distance, LSB-first AC protocol of 35 bytes / 280 bits (35x8=280). blafois/Daikin-IR-Reverse independently confirms the 3-data-frame structure (8 + 8 + 19 bytes) separated by ~29 ms gaps, and the frame-3 byte-level layout: fixed header 0x11 0xDA 0x27 0x00; mode codes Auto=0/Dry=2/Cool=3/Heat=4/Fan=6; temperature = degC*2 (20C -> 0x28); byte8 fan upper-nibble + swing lower-nibble; timer bytes; powerful bit; econo byte; and last byte = (sum of all prior bytes) & 0xFF checksum. Carrier is correctly 38 kHz (not the 37 kHz Panasonic / 40 kHz Sony outliers), and this is a genuinely distinct full-state AC protocol, not generic NEC/Samsung32 nor the Coolix/Midea family. All claimed details match the cited sources with no discrepancies."
   },
   {
    "brand": "Daikin",
    "protocolName": "Daikin216 (216-bit variant)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Independently verified against the cited reputable source (crankyoldgit/IRremoteESP8266, ir_Daikin.h doxygen source). Every claimed timing constant matches exactly: kDaikin216Freq=38000 (38 kHz carrier confirmed), kDaikin216HdrMark=3440us, kDaikin216HdrSpace=1750us, kDaikin216BitMark=420us, kDaikin216OneSpace=1300us, kDaikin216ZeroSpace=450us, kDaikin216Gap=29650us (matches the ~29650us inter-frame gap claimed). kDaikin216StateLength=27 bytes was confirmed via the test/source references; 27 bytes x 8 = 216 bits, consistent with the '216-bit variant' name. The protocol is a distinct, registered full-state Daikin AC variant (IRDaikin216 class), transmitted in 2 sections (8-byte section 1 + 19-byte section 2), with the Daikin family's characteristic fixed header bytes plus power/mode/temp/fan/swing fields and trailing additive (&0xFF) checksum, differing in length/offsets from the 280-bit Daikin variant. No common-mistake pitfalls apply: it is not generic NEC/Samsung32, carrier is correctly 38 kHz (not Panasonic 37 kHz or Sony 40 kHz), and it is a real AC-specific protocol rather than a misattribution. Claim is fully supported."
   },
   {
    "brand": "Daikin",
    "protocolName": "Daikin2 / Daikin312 (312-bit, 39-byte variant)",
    "verdict": "confirmed",
    "correctedCarrierHz": 36700,
    "reasoning": "Independently verified every claimed value against the upstream IRremoteESP8266 source (crankyoldgit/IRremoteESP8266). In ir_Daikin.h: kDaikin2LeaderMark=10024, kDaikin2LeaderSpace=25180, kDaikin2HdrMark=3500, kDaikin2HdrSpace=1728, kDaikin2BitMark=460, kDaikin2OneSpace=1270, kDaikin2ZeroSpace=420, kDaikin2Freq=36700 \u2014 all exact matches. In IRremoteESP8266.h: kDaikin2StateLength=39 and kDaikin2Bits=312 (line ~1223), and kDaikin312StateLength=39 / kDaikin312Bits=312 (line ~1246) \u2014 confirming the 39-byte / 312-bit full-state framing. The protocol uses a long leader mark/space followed by a header, two sections with an inter-section gap (~kDaikin2LeaderMark+kDaikin2LeaderSpace region / ~35 ms), and additive per-section checksums, consistent with the IRDaikin2 class in ir_Daikin.cpp. The unusual 36.7 kHz carrier (vs the 38 kHz used by most Daikin variants) is correctly noted and matches kDaikin2Freq. No NEC/Samsung32 confusion, no carrier error, and it is genuinely a distinct AC protocol rather than generic NEC. Claim is fully confirmed."
   },
   {
    "brand": "Daikin",
    "protocolName": "Daikin128 / Daikin64 (128-bit & 64-bit variants)",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "verdict": "confirmed",
    "reasoning": "Independently verified against the authoritative source (crankyoldgit/IRremoteESP8266, src/ir_Daikin.h and its Doxygen mirror). Every claimed constant matches exactly: kDaikin128StateLength=16 (16-byte/128-bit state, 2 sections of 8 bytes), kDaikin128LeaderMark=9800, kDaikin128LeaderSpace=9800, kDaikin128HdrMark=4600, kDaikin128HdrSpace=2500, kDaikin128BitMark=350, kDaikin128OneSpace=954, kDaikin128ZeroSpace=382, kDaikin128Gap=20300, carrier kDaikin128Freq=38000Hz. The Daikin64 variant is a single 64-bit (8-byte) value reusing the same timing family (LdrMark 9800, HdrMark 4600, HdrSpace 2500, BitMark 350, OneSpace 954, ZeroSpace 382, Gap 20300) at kDaikin64Freq=38000Hz. These are genuinely distinct Daikin compact protocols (PR #832), not generic NEC, not Samsung32, and not Coolix/Midea-family; the 38kHz carrier is correct and not confused with Panasonic 37kHz or Sony 40kHz. State carries power/mode/temp/fan/swing plus clock/timer fields with a checksum, consistent with the IRDaikin128/IRDaikin64 classes. No corrections needed."
   },
   {
    "brand": "Daikin",
    "protocolName": "Daikin152 / Daikin160 / Daikin176 / Daikin200 (additional length variants)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Verified against the authoritative source (IRremoteESP8266 src/ir_Daikin.h, ir_Daikin.cpp, IRremoteESP8266.h) via doxygen source and GitHub. Carrier: all four define Freq=38000 Hz (kDaikin152Freq/160/176/200Freq = 38000), confirming 38 kHz, the standard for Daikin (not Panasonic ~37k or Sony ~40k). Timing constants match exactly: Daikin152 HdrMark 3492 / HdrSpace 1718, BitMark 433, OneSpace 1529, ZeroSpace 433, Gap 25182. Daikin160 5000/2145, 342/1786/700, Gap 29650. Daikin176 5070/2140, 370/1780/710, Gap 29410. Daikin200 4920/2230, 290/1850/780, Gap 29400. State lengths confirmed: 152=19 bytes (152 bits), 160=20 bytes (160 bits), 176=22 bytes (176 bits), 200=25 bytes (200 bits). Bit order confirmed LSB-first: send functions call sendGeneric with MSBfirst=false. Checksum confirmed additive: checksum() uses sumBytes() (additive sum) stored into a byte field (effectively &0xFF). These are genuine distinct manufacturer AC protocols, not generic NEC and not confused with any Coolix/Midea/Samsung family. No discrepancies found; every claimed value is corroborated."
   }
  ]
 },
 {
  "target": "ac-panasonic",
  "protocols": [
   {
    "brand": "Panasonic",
    "kind": "Air Conditioner / Heat Pump",
    "protocolName": "Kaseikyo/Panasonic AC (PanasonicAc)",
    "carrierHz": 36700,
    "frameSummary": "Pulse-distance, LSB-first, based on the Kaseikyo (Japanese/NECA) standard. Header mark 3456 us + space 1728 us. Bit mark 432 us; '0' = mark + 432 us space, '1' = mark + 1296 us space. Full A/C state is 27-28 bytes (kPanasonicAcStateLength = 27, padded/handled as 28 = 216-224 bits). The message is sent in TWO sections separated by a ~10,000 us (10 ms) gap: an 8-byte header/section-1 block (fixed Kaseikyo-style vendor preamble incl. Panasonic vendor/manufacturer ID) followed by the variable state section, with an end gap ~5000 us. A trailing checksum byte (init 0xF4, mod-256 sum) validates the frame. State field layout: byte 13 = power(bit0) + mode(Auto 0x0, Dry 0x2, Cool 0x3, Heat 0x4, Fan 0x6) + timer flags; byte 14 = temperature (5-bit field, offset 1, 16-30 C; fan-only forces 27 C); byte 16 = fan speed (Low1/Med2/High3/Max4/Auto7) + vertical swing (4-bit Highest..Lowest/Auto); byte 17 = horizontal swing; bytes 18-20 = on/off timers (11-bit minutes, max 1439); byte 21 = Quiet/Powerful (CKP & RKR have these two bits swapped); bytes 24-25 = clock. Six model variants: NKE, DKE, JKE, LKE, CKP, RKR, differing in horizontal-swing and ion/nanoe bits.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "notes": "Distinct, fully reverse-engineered stateful A/C protocol (NOT generic NEC). IRremoteESP8266 provides a complete IRPanasonicAc encoder/decoder class with setPower/setTemp/setMode/setFan/setSwing helpers and checksum logic, so a real encoder can be written immediately. Note Panasonic also has a separate 48-bit short Kaseikyo/Panasonic protocol used for TVs/audio (37 kHz, vendor ID 0x2002) \u2014 that is a different, address/command remote, not the A/C state protocol. Carrier was corrected to 36.7 kHz (some older refs say 35-37 kHz). Picking the correct model variant matters because the CKP/RKR Quiet/Powerful bit swap and horizontal-swing support differ.",
    "source": "IRremoteESP8266 src/ir_Panasonic.cpp and src/ir_Panasonic.h (github.com/crankyoldgit/IRremoteESP8266); timing/freq corroborated by IRremoteESP8266 issue #62 and Arduino-IRremote PR #442 (kPanasonicFreq = 36700 Hz); model CS-E9CKP support discussion in IRremoteESP8266 issue #1364."
   }
  ],
  "verdicts": [
   {
    "brand": "Panasonic",
    "protocolName": "Kaseikyo/Panasonic AC (PanasonicAc)",
    "verdict": "confirmed",
    "correctedCarrierHz": 36700,
    "correctedProtocol": "",
    "reasoning": "Independently verified against the cited primary sources. (1) Carrier: kPanasonicFreq = 36700 Hz is confirmed verbatim in IRremoteESP8266 src/ir_Panasonic.h, and Arduino-IRremote PR #442 (\"Fix incorrect frequency used for Panasonic\") corrects the value to ~37kHz, noting the true value is 36.7kHz. This correctly avoids the common error of assuming 38kHz; Panasonic genuinely uses ~37kHz, distinct from Sony ~40kHz. (2) Protocol family: Panasonic AC is built on the Kaseikyo (Japanese/NECA) standard, confirmed by hifi-remote.com Kaseikyo wiki, with IRP {37k,432}<1,-1,1,-3>(8,-4,...). Unit time 432us yields header mark 8x432=3456us and space 4x432=1728us, '0'=1 unit space (432us) and '1'=3 unit space (1296us) - all matching the claim exactly. Pulse-distance, LSB-first framing is consistent with Kaseikyo. (3) State length: kPanasonicAcStateLength=27 bytes confirmed in source; AC sends a longer stream than the basic 48-bit appliance message, consistent with the two-section (8-byte vendor preamble + variable state) structure. (4) Checksum: kPanasonicAcChecksumInit=0xF4 confirmed verbatim in ir_Panasonic.h. (5) Model variants NKE/DKE/JKE/LKE/CKP/RKR confirmed in the header's supported-models list and corroborated by issue #1364/#1307 (CS-E9CKP / A75C2295). The CKP/RKR Quiet/Powerful bit-swap and field layout are consistent with the documented implementation. No mismatch found (not NEC, not Samsung32, not Coolix/Midea). This is a genuine distinct Panasonic AC protocol, not generic NEC."
   }
  ]
 },
 {
  "target": "ac-toshiba",
  "protocols": [
   {
    "brand": "Toshiba",
    "kind": "AC (air conditioner / heat pump)",
    "protocolName": "Toshiba (TOSHIBA_AC) \u2014 a distinct, dedicated state-based AC protocol (NOT generic NEC; it is Samsung-style PWM but with its own framing and checksum)",
    "carrierHz": 38000,
    "frameSummary": "Carrier 38 kHz. Header mark 4400 us, header space 4300 us. Bit mark 580 us; ONE space 1600 us, ZERO space 490 us (pulse-distance, MSB-first per byte). Inter-frame minimum gap ~4600 us; usual gap ~7400 us. The whole frame is sent twice (kToshibaACMinRepeat = single repeat). State length is variable: short = swing-only, standard = 9 bytes / 72 bits (kToshibaACStateLength=9, kToshibaACBits=72), long = with Turbo/Econo. Byte map (standard 9-byte/72-bit form): byte0 = 0xF2 (fixed signature); byte1 = inverted byte0 (0x0D); byte2 = high nibble model (RemoteA=0x0, RemoteB=0x1) + low nibble payload length code; byte3 = inverted length byte; byte4 = message-type flags (LongMsg/ShortMsg + reserved); byte5 = Swing(3 bits: Step=0/On=1/Off=2/Toggle=4) low nibble + Temp(4 bits, raw = celsius - 17, range 17..30 C) high nibble; byte6 = Mode(3 bits: Auto=0,Cool=1,Dry=2,Heat=3,Fan=4,Off=7) + Fan(3 bits: Auto=0,Min=1,Med=3,Max=5); byte7 = Filter bit + reserved; byte8 = checksum (XOR of all preceding bytes via calcChecksum/xorBytes; in the longer 80-bit variant this position carries Eco/Turbo and the checksum moves to the final byte). RemoteB differs from RemoteA only in the leading 4 bits of byte2.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266: src/ir_Toshiba.cpp and src/ir_Toshiba.h (github.com/crankyoldgit/IRremoteESP8266, master). Timing/checksum confirmed in ir_Toshiba.cpp; field/byte layout in ir_Toshiba.h (ToshibaProtocol union + kToshibaAc* constants). Cross-checked with mrossi blog 'Toshiba Air Conditioner IR signal Reverse Engineering' (2016), k3a/toshiba-ac and ikke-t/toshiba-ac-ir-remote. NOTE: issalig/toshiba_air_cond documents the WIRED 2400-baud UART 'AB' bus, a different transport, not the IR remote \u2014 do not confuse the two.",
    "notes": "Fully reverse-engineered, state-based protocol with a complete public encoder/decoder in IRremoteESP8266 \u2014 you can compute any power/temp/mode/fan/swing state and its checksum directly, so no per-button code table is needed. Verified models include RAS-B13N3KV2, Akita EVO II, RAS-B13N3KVP-E, RAS 18SKP-ES, WH-TA04NE, WC-L03SE. Two remote variants exist (A and B); A's signature begins 0xF2 0x0D ... Temperature encodes as (celsius - 17). Implement by building the 9-byte state, XOR-checksumming, then transmitting MSB-first with the timings above, repeated twice. Some Toshiba units also accept short (swing-only) frames."
   }
  ],
  "verdicts": [
   {
    "brand": "Toshiba",
    "protocolName": "Toshiba (TOSHIBA_AC)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Independently confirmed against the cited authoritative source, IRremoteESP8266 (crankyoldgit, master), via the raw source files. ir_Toshiba.cpp defines exactly: kToshibaAcHdrMark=4400, kToshibaAcHdrSpace=4300, kToshibaAcBitMark=580, kToshibaAcOneSpace=1600, kToshibaAcZeroSpace=490, kToshibaAcMinGap=4600, kToshibaAcUsualGap=7400, with a 38kHz carrier in the send call. The checksum is an XOR of all preceding bytes ('Always do the Xor checksum LAST!'), matching the claim. IRremoteESP8266.h defines kToshibaACStateLength=9, kToshibaACBits=72, with short (7 bytes/56 bits) and long (10 bytes/80 bits) variants, and kToshibaACMinRepeat=kSingleRepeat=1 (frame sent twice). ir_Toshiba.h confirms the field layout: byte0=0xF2 signature, byte1 inverted, byte2 model nibble + length nibble, byte3 inverted length, byte4 message-type flags, Swing values (Step=0/On=1/Off=2/Toggle=4), Temp range 17-30C, Modes (Auto=0,Cool=1,Dry=2,Heat=3,Fan=4,Off=7), Fan (Auto=0,Min=1,Med=3,Max=5), Filter bit, and the long 80-bit variant carrying Turbo/Econo with the checksum at the final byte. This is a distinct dedicated state-based AC protocol, NOT generic NEC. Carrier (38kHz) is correct, not Panasonic's ~37kHz or Sony's ~40kHz. Cross-referenced with mrossi's 2016 reverse-engineering blog (which documents the 0xF20D signature and XOR checksum) and k3a/toshiba-ac. The issalig/toshiba_air_cond repo is correctly noted as the separate WIRED 'AB' UART bus, not the IR remote. Every numeric and structural claim matches the source verbatim."
   }
  ]
 },
 {
  "target": "ac-hitachi",
  "protocols": [
   {
    "brand": "Hitachi",
    "kind": "AC (split / wall-mounted air conditioner)",
    "protocolName": "Hitachi AC (HITACHI_AC, 224-bit / 28-byte base variant)",
    "carrierHz": 38000,
    "frameSummary": "Header mark 3300us / header space 1700us; bit mark 400us; one-space 1250us, zero-space 500us (pulse-distance). 28 bytes = 224 bits, MSB-first per byte. Full A/C state (no address/command split). Field positions (per Hitachi struct in ir_Hitachi.h): Mode at byte 10 (8 bits, stored bit-reversed), Temp at byte 11 (8 bits, reversed + left-shifted, range ~16-32C), Fan at byte 13 (8 bits, reversed), Power as a single bit in byte 17, plus SwingV/SwingH boolean bits. Checksum/integrity carried in the state bytes.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Hitachi.cpp and src/ir_Hitachi.h (crankyoldgit), constants kHitachiAcHdrMark=3300, kHitachiAcHdrSpace=1700, kHitachiAcBitMark=400, kHitachiAcOneSpace=1250, kHitachiAcZeroSpace=500; sendHitachiAC(); class IRHitachiAc. Model RAS-35THA6.",
    "notes": "This is the canonical base Hitachi A/C protocol. HITACHI_AC2 (53-byte/424-bit) and HITACHI_AC264 (33-byte/264-bit) reuse the very same timing constants and delegate to sendHitachiAC(); they differ only in length and bit order (AC264 is LSB-first with inverted-byte validation). Marked STABLE/working in SupportedProtocols.md."
   },
   {
    "brand": "Hitachi",
    "kind": "AC (older split, Series VI circa 2007 / LT0541-HTA remote)",
    "protocolName": "Hitachi AC1 (HITACHI_AC1, 13-byte / 104-bit)",
    "carrierHz": 38000,
    "frameSummary": "Header mark 3400us / header space 3400us (symmetric leader, distinct from base variant); bit mark 400us; one-space 1250us, zero-space 500us. 13 bytes = 104 bits, MSB-first. Encoding: Power single bit (byte 11); Fan in low nibble + Mode in high nibble of byte 5; Temp 5-bit field in byte 6 (stored with reversed nibbles and a delta offset); plus Sleep and timer fields.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Hitachi.cpp / .h, constants kHitachiAc1HdrMark=3400, kHitachiAc1HdrSpace=3400; class IRHitachiAc1; GitHub issue #1056 (13-byte HITACHI_AC1). Remotes: LT0541-HTA, R-LT0541-HTA/Y.",
    "notes": "Distinct framing (symmetric 3400/3400 header and 104-bit length) makes this a separate variant from the 224-bit base. Fully reverse-engineered with a working encoder/decoder."
   },
   {
    "brand": "Hitachi",
    "kind": "AC (variable-length remote, e.g. PC-LH3B / RAS models using AC3 framing)",
    "protocolName": "Hitachi AC3 (HITACHI_AC3, variable 15-27 byte / 120-216 bit)",
    "carrierHz": 38000,
    "frameSummary": "Header mark 3400us / header space 1660us; bit mark 460us; one-space 1250us, zero-space 410us (note the distinct 460us mark and 410us zero-space vs the base variant). Variable length 15-27 bytes, LSB-first per byte. State integrity enforced via inverted byte pairs immediately after the header. Power/temp/mode/fan are packed into the variable-length state payload.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Hitachi.cpp / .h, constants kHitachiAc3HdrMark=3400, kHitachiAc3HdrSpace=1660, kHitachiAc3BitMark=460, kHitachiAc3OneSpace=1250, kHitachiAc3ZeroSpace=410; class IRHitachiAc3.",
    "notes": "Separate timing set (460/410us) and LSB ordering distinguish AC3. Variable message length is handled by capturing full raw state; encoder is provided."
   },
   {
    "brand": "Hitachi",
    "kind": "AC (modern split, RAR-8P2 remote / RAS-AJ25H)",
    "protocolName": "Hitachi AC424 (HITACHI_AC424, 53-byte / 424-bit) with long leader",
    "carrierHz": 38000,
    "frameSummary": "Distinct double-stage start: very long LEADER mark 29784us + space 49290us, then header mark 3416us / header space 1604us; bit mark 463us; one-space 1208us, zero-space 372us. 53 bytes = 424 bits, LSB-first per byte. Fields (Hitachi424 struct): Temp at byte 13 (6-bit field, 16-32C), Mode (low nibble) + Fan (high nibble) at byte 25, Power single bit at byte 27, with button/command-tracking bytes. Integrity via inverted byte pairs.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Hitachi.cpp / .h, constants kHitachiAc424LdrMark=29784, kHitachiAc424LdrSpace=49290, kHitachiAc424HdrMark=3416, kHitachiAc424HdrSpace=1604, kHitachiAc424BitMark=463, kHitachiAc424OneSpace=1208, kHitachiAc424ZeroSpace=372; class IRHitachiAc424; GitHub issue #973 (424-bit). Remote RAR-8P2.",
    "notes": "Note the unusual ~30ms leader mark and ~49ms space before the normal header - critical to reproduce or the AC will ignore the frame. STABLE/working. HITACHI_AC344 (43-byte/344-bit) extends AC424 with SwingV bit + 6-position SwingH and a button-based command system, sharing the base bit/space timings."
   },
   {
    "brand": "Hitachi",
    "kind": "AC (split, AC296 framing - 37-byte models)",
    "protocolName": "Hitachi AC296 (HITACHI_AC296, 37-byte / 296-bit)",
    "carrierHz": 38000,
    "frameSummary": "Header mark 3300us / header space 1700us; bit mark 400us; one-space 1250us, zero-space 500us (base timing set). 37 bytes = 296 bits, LSB-first per byte. Encoding: Power bit; Mode (5 values); Temp encoded directly with a special value for Auto; Fan 5 levels; integrity via inverted byte pairs across the state.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Hitachi.cpp / .h; class IRHitachiAc296; constants kHitachiAcHdrMark=3300, kHitachiAcHdrSpace=1700, kHitachiAcBitMark=400, kHitachiAcOneSpace=1250, kHitachiAcZeroSpace=500.",
    "notes": "Reuses base timing constants but with 296-bit length and LSB ordering plus its own field map; full encoder provided. Independently confirmed by community reverse-engineering (perhof.wordpress.com Hitachi RAR write-up describing 400us mark, 400us=0 / 1300us=1 spacing)."
   }
  ],
  "verdicts": [
   {
    "brand": "Hitachi",
    "protocolName": "Hitachi AC (HITACHI_AC, 224-bit / 28-byte base variant)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Every claimed detail is independently confirmed against the authoritative source (crankyoldgit/IRremoteESP8266).\n\nTiming constants (from ir_Hitachi.cpp): kHitachiAcHdrMark=3300, kHitachiAcHdrSpace=1700, kHitachiAcBitMark=400, kHitachiAcOneSpace=1250, kHitachiAcZeroSpace=500 \u2014 all match exactly. This is a pulse-distance encoding (constant 400us mark, with 1250us space = 1, 500us space = 0), as claimed.\n\nCarrier: ir_Hitachi.h defines kHitachiAcFreq=38000 Hz, and sendHitachiAC() transmits at 38 kHz \u2014 matches the claimed 38000Hz. This is consistent with the note that most non-Sony/non-Panasonic protocols run at 38kHz; no carrier confusion here.\n\nFrame size: The base HITACHI_AC variant uses kHitachiAcStateLength=28 bytes = 224 bits (kHitachiAcBits=224), a full A/C state with no address/command split \u2014 matches. The library also defines distinct larger Hitachi variants (HITACHI_AC1=13B, HITACHI_AC2=53B, HITACHI_AC3, HITACHI_AC264=33B, HITACHI_AC296=37B, HITACHI_AC344=43B, plus the 424-bit big-Hitachi), so the researcher correctly identified the 28-byte base variant specifically rather than conflating it.\n\nField positions (confirmed from the HitachiProtocol struct in ir_Hitachi.h): Mode at byte 10, Temp at byte 11 (~16-32C range), Fan at byte 13, Power as a single bit in byte 17, SwingV bit in byte 14, SwingH bit in byte 15 \u2014 all consistent with the claim. Mode/Temp/Fan stored bit-reversed and an integrity/checksum carried in the state bytes is the documented Hitachi behavior.\n\nThis is genuinely a distinct dedicated protocol (class IRHitachiAc, sendHitachiAC), not generic NEC or a Coolix/Midea-family or Samsung32 misattribution. No correction needed."
   },
   {
    "brand": "Hitachi",
    "protocolName": "Hitachi AC1 (HITACHI_AC1, 13-byte / 104-bit)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "All claimed details independently verified against the authoritative IRremoteESP8266 source (crankyoldgit/IRremoteESP8266, src/ir_Hitachi.cpp and src/ir_Hitachi.h), the canonical definition for this protocol. Confirmed: kHitachiAc1HdrMark=3400us and kHitachiAc1HdrSpace=3400us (symmetric leader, distinct from the base HITACHI_AC variant); kHitachiAcBitMark=400us, kHitachiAcOneSpace=1250us, kHitachiAcZeroSpace=500us; kHitachiAc1StateLength=13 bytes -> kHitachiAc1Bits=104. Carrier confirmed as kHitachiAcFreq=38 kHz (38000 Hz) passed to sendGeneric in sendHitachiAC1 -- correctly 38kHz, not Panasonic ~37kHz nor Sony ~40kHz. Remote models LT0541-HTA and R-LT0541-HTA (Series VI, circa 2007) are documented in the source comments and the kHitachiAc1Remote enum. Temperature is stored with reversed bits and a delta offset (kHitachiAc1TempDelta), matching the claim. This is a genuine standalone protocol (its own send/decode/class IRHitachiAc1), not generic NEC or a Coolix/Midea-family AC. No contradictions found; no correction needed."
   },
   {
    "brand": "Hitachi",
    "protocolName": "Hitachi AC3 (HITACHI_AC3, variable 15-27 byte / 120-216 bit)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "All claimed constants are independently confirmed against the IRremoteESP8266 source (crankyoldgit/IRremoteESP8266, src/ir_Hitachi.cpp and .h). Exact matches: kHitachiAc3HdrMark=3400, kHitachiAc3HdrSpace=1660, kHitachiAc3BitMark=460, kHitachiAc3OneSpace=1250, kHitachiAc3ZeroSpace=410. The carrier is kHitachiAcFreq=38000 Hz, used by sendHitachiAc3() via sendGeneric, confirming 38kHz. Length range is confirmed: kHitachiAc3MinStateLength=15 and kHitachiAc3StateLength=27, giving the variable 15-27 byte (120-216 bit) state, with five typical sizes (cancel timer=15, change temp=17, change mode=21, normal=23, set timer=27). HITACHI_AC3 is a genuine distinct AC protocol with its own class IRHitachiAc3; it is NOT a generic NEC or Coolix/Midea-family protocol. The distinct 460us mark and 410us zero-space (differing from the base Hitachi AC variant) are accurate. No carrier or protocol-family confusion detected. Sources: GitHub crankyoldgit/IRremoteESP8266 (ir_Hitachi.cpp, ir_Hitachi.h, IRremoteESP8266.h) and the project SupportedProtocols/doxygen docs."
   },
   {
    "brand": "Hitachi",
    "protocolName": "Hitachi AC424 (HITACHI_AC424, 53-byte / 424-bit) with long leader",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "verdict": "confirmed",
    "reasoning": "Every element of the claim was independently verified against the authoritative IRremoteESP8266 source (crankyoldgit/IRremoteESP8266, src/ir_Hitachi.cpp/.h and the doxygen header dump).\n\nTiming constants (from ir_Hitachi.cpp) match exactly: kHitachiAc424LdrMark=29784, kHitachiAc424LdrSpace=49290, kHitachiAc424HdrMark=3416, kHitachiAc424HdrSpace=1604, kHitachiAc424BitMark=463, kHitachiAc424OneSpace=1208, kHitachiAc424ZeroSpace=372 us. The distinctive double-stage start (very long ~29.8ms leader mark + ~49.3ms leader space, then a separate header mark/space) is correct and is what distinguishes AC424 from HitachiAC2.\n\nCarrier: kHitachiAcFreq = 38000 Hz (38 kHz), confirmed. This is consistent with the general statement that most non-Sony/non-Panasonic IR is 38 kHz; not 37 kHz (Panasonic) or 40 kHz (Sony).\n\nStructure: 53 bytes = 424 bits, LSB-first per byte, space-encoded \u2014 confirmed (issue #973 'Return of the Big Hitachi AC (424 bit)', class IRHitachiAc424, kHitachiAc424StateLength=53). Integrity via inverted byte pairs is consistent with the library's checksum scheme.\n\nField offsets confirmed against the Hitachi424Protocol union in ir_Hitachi.h (doxygen): Temp at byte 13 (6-bit field), Mode = low nibble of byte 25, Fan = high nibble of byte 25, Power single bit at byte 27. These match the claim precisely.\n\nDevice mapping confirmed: GitHub issue #973 targets the Hitachi Shirokumakun RAS-AJ25H A/C with the RAR-8P2 remote, listed as STABLE/working under HITACHI_AC424.\n\nNo common-mistake pitfalls apply: this is a genuine distinct AC protocol (not generic NEC, not Samsung32, not Coolix/Midea family), carrier is correctly 38 kHz, and all named constants and field layouts are exact matches. Verdict: confirmed."
   },
   {
    "brand": "Hitachi",
    "protocolName": "Hitachi AC296 (HITACHI_AC296, 37-byte / 296-bit)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently verified against the cited source, IRremoteESP8266 src/ir_Hitachi.cpp (raw GitHub master). Every claimed parameter matches: kHitachiAcHdrMark=3300, kHitachiAcHdrSpace=1700, kHitachiAcBitMark=400, kHitachiAcOneSpace=1250, kHitachiAcZeroSpace=500 (microseconds). Carrier is 38 kHz (kHitachiAcFreq=38), consistent with the claimed 38000 Hz, so the carrier is correct (not a Panasonic ~37k or Sony ~40k mismatch). Framing is 37 bytes = 296 bits with MSBfirst=false (LSB-first), as claimed. Integrity uses inverted byte pairs (IRHitachiAc296::setInvertedStates calls invertBytePairs over _.raw+3 across the state), matching the 'inverted byte pairs across the state' claim. The protocol HITACHI_AC296 is a genuinely distinct, library-supported A/C protocol (STABLE, works on real device RAS-70YHA3 / remote RAR-3U3), not a generic NEC, Samsung32, or Coolix/Midea misattribution. SupportedProtocols.md and the library's send/IRsend references corroborate the 296-bit/37-byte description. All elements of the researcher's claim are confirmed."
   }
  ]
 },
 {
  "target": "ac-lg",
  "protocols": [
   {
    "brand": "LG",
    "kind": "AC",
    "protocolName": "LG (NEC-derived, 28-bit) / LG2 variant",
    "carrierHz": 38000,
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_LG.cpp and src/ir_LG.h (github.com/crankyoldgit/IRremoteESP8266) \u2014 decodeLG/sendLG, IRLgAc class; SupportedProtocols.md lists LG and LG2 (Beta/working).",
    "frameSummary": "Carrier 38kHz. LG (28-bit) timings: header mark 8500us, header space 4250us, bit mark 550us, one-space 1600us, zero-space 550us, min gap ~39750us (NEC/UPD6121-style leader). LG2 variant: header mark 3200us, header space 9900us, bit mark 480us, same 1600/550us spaces (used by newer split units e.g. AKB74955603/AKB73757604). Bits sent MSB-first. The 28-bit AC frame is a self-contained state word laid out (LSB->MSB) as: Sum[3:0] (4-bit checksum), Fan[7:4] (4 bits), Temp[11:8] (4 bits), Mode[14:12] (3 bits), padding[17:15], Power[19:18] (2 bits), Signature/Sign[27:20] (8 bits, kLgAcSignature=0x88). Mode: Cool=0, Dry=1, Fan=2, Auto=3, Heat=4. Fan: Lowest=0, Low=1, Medium=2, Max=4, Auto=5, LowAlt=9, High=10. Temp: value stored = (degC - kLgAcTempAdjust(15)); range 16-30C (so nibble 1..15). Power: On=0b00, Off=0b11 (0xFF special off command also exists). Checksum (Sum nibble) = sum of the other nibbles of the 28-bit word, low 4 bits. Library also decodes longer LG 32/48/56/112-bit framings for some remotes, but the core controllable AC state is the 28-bit word.",
    "notes": "Distinct documented protocol, NOT generic NEC \u2014 it is NEC-leader-derived but carries a full 28-bit AC state word with LG-specific 0x88 signature, nibble checksum, and temp/mode/fan/power bit fields, plus a structurally different LG2 leader (3200/9900us) for newer inverter/split remotes. IRLgAc in IRremoteESP8266 fully encodes/decodes state, so a real encoder can be written now. Multiple remote models supported (AKB74955603, AKB73757604, GE6711AR2853M, 6711A20083V). LIRC db and IRDB also carry per-button LG codes for some remotes as backup. Confidence high; only caveat is per-model variation in exact off-command/byte-length that the library handles by remote model."
   }
  ],
  "verdicts": [
   {
    "brand": "LG",
    "protocolName": "LG (NEC-derived, 28-bit) / LG2 variant",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently verified against IRremoteESP8266 src/ir_LG.cpp and src/ir_LG.h (crankyoldgit), the named source. Every load-bearing detail matches:\n\nCARRIER: Both sendLG and sendLG2 use 38kHz. This is correct for LG (not confused with Panasonic ~37kHz or Sony ~40kHz). NEC-family LG is genuinely 38kHz.\n\nLG timings: header mark 8500us, header space 4250us, bit mark 550us, one-space 1600us, zero-space 550us, min gap 39750us \u2014 all confirmed. This is the classic NEC/UPD6121-style leader (LG TVs historically used UPD6121 ~9ms or TC9012 ~4.5ms chips), so the \"NEC-derived\" characterization is accurate.\n\nLG2 timings: header mark 3200us, header space 9900us, bit mark 480us, same 1600/550us data spaces, min gap 39750us \u2014 confirmed. This is a genuinely distinct framing used by newer split units (AKB74955603, AKB73757604 model designations confirmed in the library's supported-models list and ReleaseNotes), so claiming a distinct LG2 protocol is justified, not a false-distinct-vs-generic-NEC error.\n\nAC STATE WORD: 28-bit frame (kLgBits=28), MSB-first. LGProtocol bitfield layout confirmed: Sum[3:0] 4-bit checksum, Fan 4 bits, Temp 4 bits, Mode 3 bits, padding 3 bits, Power 2 bits, Sign 8 bits (sums to 28 bits in a uint32 union). kLgAcSignature=0x88 and kLgAcTempAdjust=15 (temp range 16-30C) confirmed. Mode Cool=0/Dry=1/Fan=2/Auto=3/Heat=4, Fan Lowest=0/Low=1/Medium=2/Max=4/Auto=5/High=10, Power On=0b00/Off=0b11 all confirmed. Checksum = low 4 bits of the sum of the other nibbles \u2014 confirmed. Library also decodes longer LG 32/48/56/112-bit framings \u2014 confirmed (SupportedProtocols lists LG and LG2 as Beta/working).\n\nNo common mistakes present: not Samsung32-confused, correct 38kHz carrier, distinct LG2 is real not a mislabel of generic NEC, and this is genuinely an LG AC protocol (not a Midea/Coolix-family mismatch)."
   }
  ]
 },
 {
  "target": "ac-samsung",
  "protocols": [
   {
    "brand": "Samsung",
    "kind": "AC",
    "protocolName": "SamsungAC (IRremoteESP8266)",
    "carrierHz": 38000,
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Samsung.cpp and src/ir_Samsung.h (github.com/crankyoldgit/IRremoteESP8266); reverse-engineering in issues #505 and #1538",
    "frameSummary": "State-based protocol (not button codes). Carrier 38 kHz. Header mark 690 us / header space 17844 us, then data sent in 7-byte sections. Per-section: section mark 3086 us / section space 8864 us, then 56 data bits with bit mark 586 us, one-space 1432 us, zero-space 436 us (LSB-first bytes). Section gap ~2886 us between sections. Standard ('normal') message = kSamsungAcStateLength = 14 bytes (2 sections); extended message = kSamsungAcExtendedStateLength = 21 bytes (3 sections), required to change power on/off, timers, or sleep. State field map (full-state encoding, byte indices per SamsungProtocol union): Temp in byte 11 (4 bits, value = degC-16, range 16-30 C, auto 25); Mode in byte 12 high nibble (Auto 0, Cool 1, Dry 2, Fan 3, Heat 4); Fan in byte 12 low bits (Auto 0, Low 2, Med 4, High 5, Auto2 6, Turbo 7); Power split across byte 6 (Power1, 2 bits) and byte 13 (Power2, 2 bits); Swing in byte 9 (3 bits); Quiet/Sleep in byte 5; Display/CleanToggle/FanSpecial in byte 10. Checksum: per section, sum of set bits over data nibbles of bytes 1-6 (checksum nibbles excluded), then XOR with 0xFF (negated), stored in nibbles of bytes 2-3 of the section. Power-off uses a special pre-recorded extended message (cannot be purely computed). Models: AR09FSSDAWKNFA, AR09HSFSBWKN, AR12KSFPEWQNET, AR12HSSDBWKNEU.",
    "notes": "This is a distinct full-state AC protocol, NOT generic NEC and NOT the Samsung32 TV protocol. IRremoteESP8266 provides a complete IRSamsungAc class (setTemp/setMode/setFan/setSwing/setPower/setQuiet/setSleep + checksum + send). The 'normal' 14-byte message is fully computable; only true power on/off transitions need the 21-byte extended message with a documented power section template (0x1D20F00000000) and pre-captured off frame. Enough public spec + reference C++ implementation to write a real encoder now."
   },
   {
    "brand": "Samsung",
    "kind": "AC (alternate / non-state remotes)",
    "protocolName": "Samsung36 / Samsung32 (NEC-like) for simple remotes",
    "carrierHz": 38000,
    "publicDataAvailable": true,
    "confidence": "medium",
    "implementability": "partial",
    "source": "IRremoteESP8266 src/ir_Samsung.cpp (sendSamsung36 / sendSamsung). LIRC remotes/samsung and IRDB Samsung trees for some legacy units",
    "frameSummary": "Some older/simpler Samsung climate or fan-style remotes use the Samsung pulse-distance protocol rather than the full SamsungAC state machine. Samsung32 (TV-style): carrier 38 kHz, tick = 560 us, header mark 4480 us / header space 4480 us, bit mark 560 us, one-space 1680 us, zero-space 560 us, 32 bits (16-bit address LSB-first + command + ~command), final 560 us mark. Samsung36 is a 36-bit variant with an extra structural gap. These carry discrete button codes, not a decomposed temp/mode/fan state.",
    "notes": "Listed for completeness and honesty: the authoritative modern Samsung AC protocol is SamsungAC above. Only specific legacy remotes use Samsung32/36 NEC-like discrete codes, and per-button code tables for AC functions are sparse/incomplete in public DBs (LIRC/IRDB coverage is mostly TVs). Marked partial because the timing spec is solid but real per-button AC code sets are not reliably published for these units."
   }
  ],
  "verdicts": [
   {
    "brand": "Samsung",
    "protocolName": "SamsungAC (IRremoteESP8266)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "All claimed facts were independently confirmed against the cited primary source: IRremoteESP8266 src/ir_Samsung.cpp and src/IRremoteESP8266.h on github.com/crankyoldgit/IRremoteESP8266.\n\nTimings (exact match from ir_Samsung.cpp): header mark 690 us / header space 17844 us; section (extra) mark 3086 us / section space 8864 us; section gap 2886 us; bit mark 586 us; one-space 1432 us; zero-space 436 us; LSB-first. Carrier 38 kHz (enableIROut at 38). \n\nMessage structure: kSamsungAcStateLength = 14 (verified in IRremoteESP8266.h: \"const uint16_t kSamsungAcStateLength = 14;\"), kSamsungAcExtendedStateLength = 21 (\"= 21;\"), kSamsungAcSectionLength = 7. Normal = 2 sections, extended = 3 sections; extended required for power/timer/sleep changes \u2014 matches sendExtended/sendOff logic.\n\nSamsungProtocol union field map matches exactly: Temp byte 11 (degC-16), Mode byte 12 high nibble, Fan byte 12 low bits, Power1 byte 6 / Power2 byte 13 (0b11 on / 0b00 off), Swing byte 9, Quiet/Sleep5 byte 5, Display byte 10. Checksum: sum of set bits over data nibbles (negated, XOR 0xFF), stored in section nibbles \u2014 confirmed. Power-off transmits a special pre-recorded extended message (sendOff) \u2014 confirmed.\n\nThis is correctly distinguished from the Samsung32 button protocol and from generic NEC (both 38 kHz but different framing); SamsungAC is a genuine distinct state-based AC protocol. No correction needed."
   },
   {
    "brand": "Samsung",
    "protocolName": "Samsung36 / Samsung32 (NEC-like) for simple remotes",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Independently verified against the primary cited source (IRremoteESP8266 src/ir_Samsung.cpp). Every timing constant in the claim matches the source exactly: kSamsungTick = 560 us; kSamsungHdrMark/HdrSpace = 8 ticks = 4480 us each (symmetric leader); kSamsungBitMark = 560 us; kSamsungOneSpace = 3 ticks = 1680 us; kSamsungZeroSpace = 560 us; carrier = 38 kHz for both sendSamsung() and sendSamsung36(). Bit counts confirmed: Samsung32 = 32 bits, Samsung36 = 36 bits (16-bit + 20-bit blocks with an extra structural gap), exactly as framed. Carrier of 38 kHz is correct (not Panasonic ~37 kHz nor Sony ~40 kHz). Critically, the claim correctly avoids the NEC-vs-Samsung32 confusion the task flagged: NEC uses a 9 ms mark / 4.5 ms space asymmetric AGC leader (sbprojects.net), whereas Samsung32 uses a symmetric 4.5 ms / 4.5 ms (4480/4480 us) leader \u2014 both at 38 kHz with 560 us pulse-distance bit coding but distinct framing. The framing that these are discrete pulse-distance button codes (not a decomposed SamsungAC temp/mode/fan state machine) is accurate and consistent with the library, which keeps sendSamsung/sendSamsung36 separate from the SamsungAc protocol class. No discrepancies found; all load-bearing details corroborated by reputable primary sources."
   }
  ]
 },
 {
  "target": "ac-haier",
  "protocols": [
   {
    "brand": "Haier",
    "kind": "AC",
    "protocolName": "HAIER_AC (HSU07-HEA03)",
    "carrierHz": 38000,
    "frameSummary": "Distinct Haier protocol, NOT generic NEC. Leader: header mark ~3000us followed by a second long mark/space pair (pulses 1-3 ~2850-3100us, pulse 4 ~4300-4350us) before data; effectively kHeaderMark=3000us, kHeaderSpace=4300us. Bit mark ~520us. Bit=0 -> short space ~650us (600-850us); bit=1 -> long space ~1650us (1700-1950us). Min gap 150000us. State = 9 bytes / 72 bits (full raw frame ~149 pulses). Layout: temp in byte1 bits4-7 (16-30C), command/power in byte1 bits0-3 (e.g. 0000=Off,0001=On,0010=Mode,0011=Fan,0110=TempUp,0111=TempDown,1000=Sleep,1100=Health,1001=TimerSet,1010=TimerCancel), fan in byte5 bits0-1 (Auto/Low/Med/High), mode in byte6 bits0-2 (Auto/Cool/Dry/Heat/Fan). Checksum = byte8 = sum of bytes0-7 mod 0x100.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Haier.h and src/ir_Haier.cpp (HAIER_AC, HSU07-HEA03; reverse-engineered by kuzin2006). github.com/crankyoldgit/IRremoteESP8266",
    "notes": "Full encoder/decoder with state builder exists. One of the earliest Haier variants; whole-state frame, command-oriented (each button press sends a full 9-byte state with a command nibble). Confirmed in issue #404 and SupportedProtocols.md."
   },
   {
    "brand": "Haier",
    "kind": "AC",
    "protocolName": "HAIER_AC_YRW02 (YR-W02 / HSU-09HMC203)",
    "carrierHz": 38000,
    "frameSummary": "Same Haier timing family as HAIER_AC (header mark 3000us, header space 4300us, bit mark ~520us, zero space ~650us, one space ~1650us, gap 150000us). State = kHaierACYRW02StateLength = 14 bytes / 112 bits. Encodes full A/C state: power bit, mode (Auto/Cool/Dry/Heat/Fan, 3-bit field), fan (High/Med/Low/Auto), temperature (16-30C), plus swing/turbo/health/sleep buttons. Single-byte checksum (sumBytes over state minus checksum byte). Button field indicates which control changed.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Haier.h / ir_Haier.cpp (IRHaierACYRW02 class; reverse-engineered by non7top). github.com/crankyoldgit/IRremoteESP8266",
    "notes": "Distinct from HSU07 by larger 14-byte state and richer feature set. Discussed in issues #1480 and #404. Full builder/parser available."
   },
   {
    "brand": "Haier",
    "kind": "AC",
    "protocolName": "HAIER_AC176 (V9014557 M47 8D; also some Mabe units)",
    "carrierHz": 38000,
    "frameSummary": "Same Haier modulation family (header mark 3000us, header space 4300us, bit mark ~520us, zero space ~650us, one space ~1650us, 38kHz). State = kHaierAC176StateLength = 22 bytes / 176 bits, structured as a 14-byte YRW02-style block followed by an 8-byte extension. Layout: temp byte1 bits0-3 (16-30C), power byte4 bit6, fan byte5 bits0-2 plus Fan2 in byte16 bits0-1, mode byte7 bits0-2. Two checksums: primary at byte13 (covers first ~14-byte block) and secondary at byte21 (covers the extension).",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Haier.h / ir_Haier.cpp (IRHaierAC176 class). github.com/crankyoldgit/IRremoteESP8266; issue #1804.",
    "notes": "Newer/longer Haier frame. Dual-checksum design over two concatenated blocks. Full encoder available; behaves as superset of YRW02."
   },
   {
    "brand": "Haier",
    "kind": "AC",
    "protocolName": "HAIER_AC160",
    "carrierHz": 38000,
    "frameSummary": "Same Haier timing family (3000us header mark, 4300us header space, ~520us bit mark, ~650us zero space, ~1650us one space, 38kHz). State = kHaierAC160StateLength = 20 bytes / 160 bits. Layout: temp byte1 bits0-3 (16-30C), power byte4 bit7, fan byte5 bits0-2 plus Fan2 byte16 bits0-2, mode byte7 bits0-2. Two checksums: primary at byte13, secondary at byte19.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Haier.h / ir_Haier.cpp (IRHaierAC160 class). github.com/crankyoldgit/IRremoteESP8266",
    "notes": "160-bit sibling of AC176; same dual-checksum/dual-block structure with slightly different bit offsets (power bit7 vs bit6, secondary checksum at byte19 vs 21). Full encoder available."
   }
  ],
  "verdicts": [
   {
    "brand": "Haier",
    "protocolName": "HAIER_AC (HSU07-HEA03)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "All claimed parameters were independently confirmed against the authoritative IRremoteESP8266 source (src/ir_Haier.h / .cpp, crankyoldgit, reverse-engineered by kuzin2006).\n\nCarrier: 38kHz confirmed \u2014 sendHaierAC calls enableIROut(38). This matches the claim of 38000Hz. (Sanity check on the listed gotchas: this is NOT Panasonic ~37kHz nor Sony ~40kHz.)\n\nTiming constants match exactly: kHaierAcHdr=3000us, kHaierAcHdrGap=4300us, kHaierAcBitMark=520us, kHaierAcOneSpace=1650us, kHaierAcZeroSpace=650us, kHaierAcMinGap=150000us. Decode tolerances also match: pulses 1-3 in 2850..3100, pulse 4 in 4300..4350, marks ~500, zero space 600..850, one space 1700..1950.\n\nDistinct-protocol claim is correct, NOT generic NEC: the two-stage leader (header mark ~3000us followed by a long header gap ~4300us) is fundamentally different from NEC's single ~9000us mark + ~4500us space leader and from Samsung32's framing. Haier is a stateful 72-bit/9-byte AC protocol, not a 32-bit NEC-style frame, and is not a Coolix/Midea-family protocol. So the common mistakes (NEC vs Samsung32 confusion, Midea=Coolix) do not apply here.\n\nState: 9 bytes / 72 bits confirmed (kHaierACStateLength=9). Prefix byte 0b10100101 confirmed.\n\nLayout/semantics confirmed: temp range 16-30C (kHaierAcMinTemp=16, kHaierAcMaxTemp=30); modes Auto(0)/Cool(1)/Dry(2)/Heat(3)/Fan(4); fan Auto(0)/Low(1)/Med(2)/High(3). Command codes confirmed exactly: Off=0b0000, On=0b0001, Mode=0b0010, Fan=0b0011, TempUp=0b0110, TempDown=0b0111, Sleep=0b1000, Health=0b1100, TimerSet=0b1001, TimerCancel=0b1010.\n\nChecksum confirmed: final byte = sum of preceding bytes mod 0x100.\n\nMinor, non-material note: the \"~149 pulses\" raw-frame figure is slightly loose (72 data bits = ~144 mark/space transitions plus header/leader/trailer), but this does not affect protocol identification. Everything load-bearing in the claim is independently corroborated by the reputable upstream source, so the verdict is confirmed."
   },
   {
    "brand": "Haier",
    "protocolName": "HAIER_AC_YRW02 (YR-W02 / HSU-09HMC203)",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "verdict": "confirmed",
    "reasoning": "Every claimed detail independently verified against the canonical IRremoteESP8266 source (crankyoldgit). (1) Carrier: 38 kHz (38000 Hz) confirmed in ir_Haier.cpp \u2014 this is a proprietary multi-byte AC state protocol, not NEC/Samsung32, so no NEC/Samsung carrier-confusion applies. (2) Timing family: header mark 3000us, header space 4300us, bit mark 520us, zero space 650us, one space 1650us all match the Haier AC timing constants; the 150000us gap matches kHaierAcMinGap (source even comments it is a 'completely made up value' placeholder, consistent with the claim's '~' phrasing). (3) State length: IRremoteESP8266.h defines const uint16_t kHaierACYRW02StateLength = 14, i.e. 14 bytes / 112 bits, exactly as claimed (distinct from kHaierACStateLength = 9 for the base HAIER_AC). (4) Semantics confirmed: temperature 16-30C (default 25), 5 modes Auto/Cool/Dry/Heat/Fan, fan High/Med/Low/Auto, plus swing/turbo/health/sleep buttons, with a Button field (byte 12, 5-bit) indicating which control changed. (5) Checksum: single trailing byte equal to the sum of all prior state bytes (sumBytes minus checksum byte), matching validChecksum(). (6) Provenance: IRHaierACYRW02 class in src/ir_Haier.h/.cpp, reverse-engineered (attributed to non7top), in the crankyoldgit/IRremoteESP8266 repo \u2014 all as stated. No discrepancies found; this is not a generic-NEC or Coolix/Midea-family mismatch."
   },
   {
    "brand": "Haier",
    "protocolName": "HAIER_AC176 (V9014557 M47 8D; also some Mabe units)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently verified against the authoritative IRremoteESP8266 source (src/ir_Haier.h and src/ir_Haier.cpp, IRHaierAC176 class). Carrier confirmed at 38000 Hz via enableIROut(38000) in sendHaierAC. Timing constants match exactly: kHaierAcHdr=3000us header mark, kHaierAcHdrGap=4300us header space, kHaierAcBitMark=520us, kHaierAcZeroSpace=650us, kHaierAcOneSpace=1650us. The HaierAc176Protocol union spans 22 bytes (kHaierAC176StateLength = 176 bits), with temp in byte1 (16-30C), power in byte4, mode in byte7 (3 bits), fan in byte5. Two checksums confirmed: primary Sum at byte13 and secondary Sum2 at byte21, validated by validChecksum(). Source issue #1804 is the correct reference for HAIER_AC176 support. This is a distinct genuine Haier AC protocol, not a misidentification of NEC, Samsung32, or Coolix/Midea. All stated facts confirmed; no corrections needed."
   },
   {
    "brand": "Haier",
    "protocolName": "HAIER_AC160",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently confirmed via the official IRremoteESP8266 source/doxygen (crankyoldgit.github.io and github.com/crankyoldgit/IRremoteESP8266, ir_Haier.h/.cpp). HAIER_AC160 is a real, distinct, STABLE protocol implemented by the IRHaierAC160 class. Carrier 38kHz: CONFIRMED. State = kHaierAC160StateLength = 20 bytes / 160 bits: CONFIRMED. Haier timing family CONFIRMED exactly: header mark ~3000us, header gap/space 4300us (kHaierAcHdrGap), bit mark 520us (kHaierAcBitMark), zero space 650us (kHaierAcZeroSpace), one space 1650us (kHaierAcOneSpace). Dual checksums CONFIRMED: primary Sum at byte 13, secondary Sum2 at byte 19. Fan layout CONFIRMED: Fan in byte5 (bits 0-2) plus Fan2 in byte16. Source attribution CONFIRMED. This is NOT a generic-NEC/Samsung32 misclassification and NOT a Coolix/Midea-family confusion; it is a genuine bespoke 160-bit Haier AC protocol with proper struct and dual-checksum framing. Minor note: the doxygen HaierAc160Protocol union shows some exact intra-byte bit offsets differing from the claim (Temp at byte1 bits4-7 vs claimed bits0-3; Power at byte4 bit1 vs claimed bit7; Mode at byte7 bits3-5 vs claimed bits0-2). These are small field-offset inaccuracies, not protocol-identity errors, and the correct byte assignments (temp byte1, power byte4, mode byte7) are right. The central claim \u2014 protocol name, brand, carrier, bit/byte count, timing family, and dual checksum positions \u2014 is verified, so the verdict is confirmed."
   }
  ]
 },
 {
  "target": "ac-hisense-tcl",
  "protocols": [
   {
    "brand": "Hisense",
    "kind": "AC (air conditioner / heat pump)",
    "protocolName": "Kelon (KELON, 48-bit) \u2014 IRremoteESP8266 decoded::KELON",
    "carrierHz": 38000,
    "publicDataAvailable": true,
    "source": "IRremoteESP8266 src/ir_Kelon.cpp + src/ir_Kelon.h (PR #1494, merged v2.7.19). SupportedProtocols.md lists 'Kelon ON/OFF 9000-12000' and DG11R2-01/RCH-R0Y3 remotes; these are Hisense's Kelon-OEM brand.",
    "frameSummary": "48-bit (6-byte) stateful frame, LSB-first. Leader: HdrMark 9000us / HdrSpace 4600us; BitMark 560us; OneSpace 1680us; ZeroSpace 600us; inter-message gap ~4000us (2x default). Carrier 38kHz. Power is a TOGGLE bit (PowerToggle) rather than absolute on/off. Temperature stored as offset from 16C (range 16-31C). Mode: Smart/Cool/Heat/Dry/Fan. Fan: Auto=0 plus three manual speeds with inverted scale. Encoded via a bitfield union, not flat byte offsets.",
    "implementability": "ready",
    "confidence": "high",
    "notes": "This is a genuine, distinct AC protocol (NOT generic NEC), reverse-engineered with full send/decode + unit tests. Caveat: power is a toggle, so an open-loop IR sender cannot guarantee absolute on/off state without external state tracking. Distinct from the 168-bit Kelon variant below."
   },
   {
    "brand": "Hisense",
    "kind": "AC (air conditioner / heat pump)",
    "protocolName": "Kelon168 (KELON168, 168-bit)",
    "carrierHz": 38000,
    "publicDataAvailable": true,
    "source": "IRremoteESP8266 src/ir_Kelon.cpp / ir_Kelon.h (Kelon168Protocol union), issues #1745 and #1903, SupportedProtocols.md. Confirmed brands/models: Hisense AST-09UW4RVETG00A A/C, Hisense KFR-33GWEF20A1, remotes DG11R2-01 / RCH-R0Y3.",
    "frameSummary": "168-bit / 21-byte stateful frame. Fixed 2-byte preamble 0x83,0x06. Bitfields encode Fan speed, Power, Sleep, Swing, Mode (Heat=0,Smart=1,Cool=2,Dry=3,Fan=4), Temperature (16-32C), Clock hours/minutes, Light-off, and Timer. Two checksum bytes (kKelon168ChecksumByte1=13 and ChecksumByte2 = StateLength-1). Carrier 38kHz. Send/decode are marked BETA ('probably works').",
    "implementability": "ready",
    "confidence": "high",
    "notes": "Real distinct protocol used by several modern Hisense split units. Status is BETA in upstream, and some fields (timer/clock) are only partially mapped, but core power/temp/mode/fan/swing are implemented and testable. Many Hisense units fall into either this 168-bit or the 48-bit Kelon family depending on remote model \u2014 device-specific identification recommended."
   },
   {
    "brand": "TCL",
    "kind": "AC (air conditioner / heat pump)",
    "protocolName": "TCL112AC",
    "carrierHz": 38000,
    "publicDataAvailable": true,
    "source": "IRremoteESP8266 src/ir_Tcl.h + src/ir_Tcl.cpp + test/ir_Tcl_test.cpp (issue #619). SupportedProtocols.md: TCL TAC-09CHSD/XA31I (TAC09CHSD model), and Teknopoint/Leberg/Daewoo/Electrolux via TCL112.",
    "frameSummary": "112-bit (14-byte) stateful frame, kTcl112AcStateLength=14. Confirmed literal #defines from ir_Tcl.h: HdrMark 3000us, HdrSpace 1650us, BitMark 500us, OneSpace 1050us, ZeroSpace 325us, Gap=default message gap. Carrier 38kHz. Fixed leading bytes act as a brand/address signature. Power: single bit (byte 5). Temperature: 4 bits, 16-31C with 0.5C resolution (half-degree flag). Mode (4 bits): Heat=1, Dry=2, Cool=3, Fan=7, Auto=8. Fan (3 bits): Auto=0, Min/Night=1, Low=2, Med=3, High=5. Byte 13 = 8-bit checksum. Swing/turbo/quiet/timers in additional bytes.",
    "implementability": "ready",
    "confidence": "high",
    "notes": "Fully reverse-engineered with absolute (non-toggle) power and a clean byte map plus unit-test vectors. Model variants TAC09CHSD (model 1) and GZ055BE1 (model 2 = Teknopoint) selected via setModel(); they share the 112-bit frame. This is the primary, production-ready TCL AC path."
   },
   {
    "brand": "TCL",
    "kind": "AC (air conditioner / heat pump) \u2014 alternate/legacy frame",
    "protocolName": "TCL96AC",
    "carrierHz": 38000,
    "publicDataAvailable": true,
    "source": "IRremoteESP8266 src/ir_Tcl.h/.cpp (TCL96AC), SupportedProtocols.md: TCL GYKQ-58(XM) remote.",
    "frameSummary": "96-bit / 12-byte stateful frame used by some TCL remotes (e.g. GYKQ-58XM). Uses a different multi-symbol (2-bit) space encoding rather than simple one/zero spaces. Carrier 38kHz. Header and exact field map are less thoroughly documented than TCL112; the .h header in repo focuses on TCL112 constants. Encoding maps 2-bit symbols to four distinct space durations.",
    "implementability": "partial",
    "confidence": "medium",
    "notes": "A real, distinct second TCL protocol (not NEC), present in upstream, but its per-field encoding is documented less completely than TCL112AC and uses an unusual 4-level (2-bit-per-symbol) space encoding. Implementable but verify against captured frames before relying on temp/mode/fan mapping. Prefer TCL112AC unless the target remote is a GYKQ-58 family unit."
   }
  ],
  "verdicts": [
   {
    "brand": "Hisense",
    "protocolName": "Kelon (KELON, 48-bit) \u2014 IRremoteESP8266 decoded::KELON",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Independently verified against the primary source (IRremoteESP8266 src/ir_Kelon.cpp, master). Every claimed parameter matches: carrier kKelonFreq = 38000 Hz; 48-bit message; timings kKelonHdrMark=9000us, kKelonHdrSpace=4600us, kKelonBitMark=560us, kKelonOneSpace=1680us, kKelonZeroSpace=600us; kKelonGap = 2 * kDefaultMessageGap (the ~4000us / 2x default gap). Power is a toggle (setTogglePower / \"Request toggling power - will be reset to false after sending\"), not absolute on/off. Temperature stored as offset: _.Temperature = temp - kKelonMinTemp (min 16C). Modes Smart/Cool/Heat/Dry/Fan present. Fan uses Auto=0 with an inverted manual scale (\"Kelon fan speeds are backwards! ... maps 0,1:3 to 0,3:1\"). The frame is a bitfield union, not flat byte offsets, consistent with the ir_Kelon.h struct. Attribution to Hisense/Kelon-OEM is supported: SupportedProtocols.md lists 'Kelon ON/OFF 9000-12000' and the DG11R2-01 / RCH-R0Y3 remotes; PR #1494 (depau) added detailed Kelon AC support. No common-mistake confusion applies here (this is a distinct stateful AC protocol at the correct 38kHz, not NEC/Samsung32/Coolix). The only minor nuance: the parent stateful frame is 48-bit but the library also has an experimental KELON168 (168-bit) variant for some Hisense models \u2014 this does not contradict the 48-bit claim made."
   },
   {
    "brand": "Hisense",
    "protocolName": "Kelon168 (KELON168, 168-bit)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Every claimed detail was independently confirmed against the IRremoteESP8266 source (src/ir_Kelon.cpp and ir_Kelon.h on crankyoldgit/IRremoteESP8266 master) and supporting GitHub issues #1745 and #1903. Confirmed: (1) Carrier is 38000 Hz via kKelonFreq = 38000 in ir_Kelon.cpp \u2014 correct for this family, not Sony ~40kHz or Panasonic ~37kHz. (2) 168-bit / 21-byte stateful frame (kKelon168StateLength = 21). (3) Fixed 2-byte preamble _.raw[0]=0x83, _.raw[1]=0x06. (4) Checksum byte indices kKelon168ChecksumByte1 = 13 and kKelon168ChecksumByte2 = StateLength-1 (=20). (5) Mode mapping Heat=0, Smart=1, Cool=2, Dry=3, Fan=4. (6) Temperature range 16-32C. (7) Both send and decode marked BETA / 'probably works'. (8) Brand/model attribution: Hisense AST-09UW4RVETG00A, KFR-33GWEF20A1, remotes DG11R2-01 / RCH-R0Y3, issues #1745/#1903 all match. This is a genuine distinct stateful AC protocol \u2014 not generic NEC, not Samsung32, and not a Coolix/Midea-family code \u2014 so none of the common confusion cases apply. No correction needed."
   },
   {
    "brand": "TCL",
    "protocolName": "TCL112AC",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently verified against the authoritative IRremoteESP8266 source (crankyoldgit/IRremoteESP8266 src/ir_Tcl.h, src/ir_Tcl.cpp, and the Doxygen reference). Every claimed detail matches exactly. Timing #defines from ir_Tcl.h confirmed: kTcl112AcHdrMark=3000us, kTcl112AcHdrSpace=1650us, kTcl112AcBitMark=500us, kTcl112AcOneSpace=1050us, kTcl112AcZeroSpace=325us, kTcl112AcGap=kDefaultMessageGap. Frame is a 112-bit / 14-byte stateful frame with kTcl112AcStateLength=14 (reset state 0x23,0xCB,0x26,... fixed leading bytes act as brand signature). Carrier confirmed 38000Hz: sendTcl112Ac calls sendGeneric(..., 38000, false, repeat, 50). Modes confirmed Heat=1, Dry=2, Cool=3, Fan=7, Auto=8. Fan speeds confirmed Auto=0, Min/Night=1, Low=2, Med=3, High=0b101=5. Temperature 16-31C with 0.5C resolution via a HalfDegree flag bit. Checksum is the last byte (byte 13), calcChecksum over the state. Origin issue #619 / PR #627 confirmed. SupportedProtocols brands (TCL TAC-09CHSD/XA31I, plus Teknopoint/Leberg/Daewoo/Electrolux via TCL112) confirmed. This is a genuine distinct stateful AC protocol, not a generic NEC or Samsung32 misattribution, and the 38kHz carrier is correct (not Panasonic ~37kHz or Sony ~40kHz). No corrections needed."
   },
   {
    "brand": "TCL",
    "protocolName": "TCL96AC",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Verified directly against the IRremoteESP8266 source (crankyoldgit/IRremoteESP8266). In src/ir_Tcl.cpp the send routine calls enableIROut(38), confirming a 38 kHz carrier (38000 Hz). The frame is 96 bits = 12 bytes (kTcl96AcBits / nbytes processing). Encoding is confirmed as a multi-symbol 2-bit space scheme rather than simple one/zero spaces: data is processed 2 bits at a time, and each 2-bit symbol maps to one of four distinct space durations via kTcl96AcBitSpaces = {360, 838, 2182, 1444} microseconds, with a fixed bit mark (kTcl96AcBitMark = 600) and header (kTcl96AcHdrMark = 1056, kTcl96AcHdrSpace = 550). The remote association is correct: source/SupportedProtocols.md and issue #1810 reference the TCL GYKQ-58(XM) remote (TAC-09CHSD/XA31I A/C). The claim that the .h header focuses on TCL112 constants while TCL96AC details live elsewhere is also accurate \u2014 the header only carries kTcl112Ac* constants plus a comment naming the GYKQ-58(XM)/TCL96AC model. No NEC/Samsung32 confusion, no carrier error, and it is genuinely a distinct AC protocol (not generic NEC). All claimed attributes (brand, protocol name, 38 kHz carrier, 96-bit/12-byte stateful frame, 4-way 2-bit space encoding, GYKQ-58XM source) match reputable sources."
   }
  ]
 },
 {
  "target": "ac-electrolux-whirlpool",
  "protocols": [
   {
    "brand": "Electrolux",
    "kind": "air conditioner (split/portable)",
    "protocolName": "Electra (ELECTRA_AC)",
    "carrierHz": 38000,
    "frameSummary": "Full-state protocol, 13 bytes = 104 bits (kElectraAcStateLength=13, kElectraAcBits=104). Leader: HdrMark 9166us / HdrSpace 4470us. Bit mark 646us; one-space 1647us; zero-space 547us (pulse-distance / space-encoded). State is a fixed 13-byte array, NOT discrete per-button codes: Temp = 5-bit field in byte 1 (16-32C, encoded as temp delta from a base, value stored with an offset of 8), Mode = 3-bit field in byte 6 (Auto/Cool/Dry/Heat/Fan), Fan = 3-bit field in byte 4 (Auto/Low/Med/High), Power = single bit in byte 9, checksum in byte 12. Confirmed against real Electrolux YKR-H/531E remote.",
    "publicDataAvailable": true,
    "confidence": "high",
    "source": "IRremoteESP8266 src/ir_Electra.h + src/ir_Electra.cpp (constants kElectraAcHdrMark=9166, kElectraAcHdrSpace=4470, kElectraAcBitMark=646, kElectraAcOneSpace=1647, kElectraAcZeroSpace=547); kElectraAcStateLength=13 in IRremoteESP8266.h. Supported devices list names Electrolux YKR-H/531E.",
    "implementability": "ready",
    "notes": "Decode is marked STABLE/known-working; send is marked 'Alpha / needs testing' and the 38kHz modulation is the author's guess (Electra emitters are insensitive to exact carrier, so 38kHz is safe). Caveat: not ALL Electrolux ACs are Electra. Electrolux/Kelvinator EACM and ESE-series units are clones of Midea (use COOLIX/MIDEA) or TCL (TCL96AC was added specifically for an Electrolux EACM CL/N3 remote). Identify by remote model: YKR-H/531E => Electra; otherwise probe for Midea/TCL."
   },
   {
    "brand": "Frigidaire",
    "kind": "air conditioner (portable)",
    "protocolName": "Electra (ELECTRA_AC)",
    "carrierHz": 38000,
    "frameSummary": "Same Electra full-state protocol as Electrolux: 13 bytes / 104 bits. Leader HdrMark 9166us / HdrSpace 4470us; bit mark 646us; one-space 1647us; zero-space 547us. Temp 5-bit (byte1), Mode 3-bit (byte6), Fan 3-bit (byte4), Power 1-bit (byte9), checksum byte12. Confirmed against real Frigidaire FGPC102AB1 unit.",
    "publicDataAvailable": true,
    "confidence": "high",
    "source": "IRremoteESP8266 src/ir_Electra.h supported-devices list explicitly names Frigidaire FGPC102AB1; same constants as Electra above.",
    "implementability": "ready",
    "notes": "Frigidaire is a Whirlpool-corp brand for some lines but the IR-controlled portable ACs in IRremoteESP8266's DB are Electra clones. As with Electrolux, this applies to the AUX/Electra OEM family; window units with a non-LCD stick remote may instead be generic NEC discrete codes (see IRDB) and should be verified per model."
   },
   {
    "brand": "Whirlpool",
    "kind": "air conditioner (split)",
    "protocolName": "Whirlpool (WHIRLPOOL_AC)",
    "carrierHz": 38000,
    "frameSummary": "Dedicated full-state protocol. 21 bytes = 168 bits (kWhirlpoolAcStateLength=21, kWhirlpoolAcBits=168), transmitted as 3 sections (6 + 8 + 7 bytes) separated by a gap. Leader: HdrMark 8950us / HdrSpace 4484us; bit mark 597us; one-space 1649us; zero-space 533us; inter-section gap kWhirlpoolAcGap=7920us. Two XOR checksums: first at byte 6 (covers section 1), second at byte 13. Power is a TOGGLE bit (_.Power), and the last pressed button is carried in a Cmd field (e.g. temp/mode/fan/power change codes) so the receiver knows what changed. Temp/Mode/Fan are bit-fields in the state array. Two model variants: DG11J1-91 (J191=true, applies -2C temperature offset) and DG11J1-3A (J191=false, no offset).",
    "publicDataAvailable": true,
    "confidence": "high",
    "source": "IRremoteESP8266 src/ir_Whirlpool.cpp + src/ir_Whirlpool.h (kWhirlpoolAcHdrMark=8950, kWhirlpoolAcHdrSpace=4484, kWhirlpoolAcBitMark=597, kWhirlpoolAcOneSpace=1649, kWhirlpoolAcZeroSpace=533, kWhirlpoolAcGap=7920); GitHub issue #509 (decode work) and discussion #2018 (DG11J1-91 remote).",
    "implementability": "ready",
    "notes": "Mature, send+receive supported. Must set the correct model (DG11J1-91 vs DG11J1-3A) for temperature to land correctly, and must set the Cmd/button field so the AC acts on the intended change since Power is a toggle. This is a genuinely distinct protocol, not generic NEC."
   },
   {
    "brand": "GE",
    "kind": "air conditioner (window/portable)",
    "protocolName": "GE 48-bit pulse-distance (LIRC raw); NOT a generic IRremoteESP8266 AC protocol",
    "carrierHz": 38000,
    "frameSummary": "Discrete per-button protocol (each button = one fixed 48-bit code, NOT a packed power/temp/mode/fan state frame). Leader 3388us mark / 1678us space; bit mark ~430us; one-space 1257us; zero-space 412us; trailing 428us; inter-frame gap ~40991us. 48 data bits, space-encoded. Real captured codes share a 0x555AF308 prefix, e.g. Power 0x555AF308598F, Cool 0x555AF3081D8F, Temp+ 0x555AF308D987, Fan hi/mid/low 0x555AF308DD83 / 0x555AF3083D8D / 0x555AF308BD85. Carrier not stated by the author; 38kHz assumed (typical).",
    "publicDataAvailable": true,
    "confidence": "medium",
    "source": "LIRC config from 'Absurdly Certain' blog (absurdlycertain.blogspot.com, 2013) reverse-engineering a GE AC remote (48-bit codes). NOTE: the IRremoteESP8266 SupportedProtocols.md 'GE' entry is misleading -- GE6711AR2853M is actually an LG A/C remote handled by the LG protocol, not a native GE protocol.",
    "implementability": "partial",
    "notes": "No clean generic GE AC spec and no entry in IRremoteESP8266. Two cases: (1) Some units badged GE ship an LG-style remote (GE6711AR2853M) -> use the LG protocol. (2) True GE window/portable remotes use the 48-bit discrete protocol above. Because it is per-button discrete codes (not a decodable state machine), you can replay captured buttons but cannot synthesize an arbitrary temp/mode/fan combination without capturing each button from the specific remote. Mark partial: structure + timings + some real codes are known, but coverage is per-remote and not standardized. IRDB/LIRC GE entries are incomplete; capture from the actual remote is recommended."
   }
  ],
  "verdicts": [
   {
    "brand": "Electrolux",
    "protocolName": "Electra (ELECTRA_AC)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Every claimed element checks out against the IRremoteESP8266 master source. ir_Electra.cpp calls sendGeneric(kElectraAcHdrMark, kElectraAcHdrSpace, kElectraAcBitMark, kElectraAcOneSpace, kElectraAcBitMark, kElectraAcZeroSpace, ..., 38000, false, ...), confirming 38 kHz carrier and pulse-distance/space encoding (NOT Manchester). Timing constants match exactly: HdrMark 9166us, HdrSpace 4470us, BitMark 646us, OneSpace 1647us, ZeroSpace 547us. IRremoteESP8266.h defines kElectraAcStateLength = 13 and kElectraAcBits = kElectraAcStateLength * 8 = 104, confirming the 13-byte / 104-bit full-state frame. The ElectraProtocol union in ir_Electra.h confirms the field layout: Temp = 5-bit field in byte 1 (16-32C), Mode = 3-bit field in byte 6 (Auto/Cool/Dry/Heat/Fan), Fan = 3-bit field in byte 4 (Auto/Low/Med/High), Power bit in byte 9, checksum (Sum) in byte 12. Electrolux YKR-H/531E is listed as a supported device (added per issue #1980), and the protocol is full-state (fixed byte array) rather than discrete per-button NEC codes. I specifically checked the adversarial concern that this might be generic NEC or that it might be Manchester-coded: it is neither. One forum result mentioned 'Manchester coding,' but that referenced an unrelated third-party Electra implementation; the canonical IRremoteESP8266 send path uses sendGeneric (pulse-distance). Carrier is 38 kHz, not Sony's 40 kHz or Panasonic's 37 kHz. No correction needed."
   },
   {
    "brand": "Frigidaire",
    "protocolName": "Electra (ELECTRA_AC)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently verified against the IRremoteESP8266 source. ir_Electra.h's supported-devices comment explicitly lists \"Frigidaire: FGPC102AB1 A/C\" alongside Electrolux YKR-H/531E and Electra Classic INV \u2014 all sharing the same Electra full-state protocol. ir_Electra.cpp confirms the exact timing constants claimed: header mark 9166us, header space 4470us, bit mark 646us, one-space 1647us, zero-space 547us, carrier 38kHz. The ElectraProtocol union has Byte0-Byte12 = 13 bytes / 104 bits with the checksum in byte 12, exactly as claimed. ELECTRA_AC is a genuine distinct full-state AC protocol (protocol #48), not generic NEC, and shares no framing with the NEC/Samsung/Coolix families flagged as common mistakes. Carrier 38kHz is correct (not Panasonic ~37kHz or Sony ~40kHz). Only the fine-grained per-field bit offsets (Temp/Mode/Fan/Power byte positions) were not byte-verified, but all load-bearing claims (protocol identity, brand/model in supported list, frame size, checksum byte, leader/bit timings, carrier) are confirmed by reputable primary source."
   },
   {
    "brand": "Whirlpool",
    "protocolName": "Whirlpool (WHIRLPOOL_AC)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Independently verified against the IRremoteESP8266 source on GitHub (src/ir_Whirlpool.cpp and src/ir_Whirlpool.h). Carrier confirmed: sendWhirlpoolAC modulates at 38000 Hz (38 kHz). Timing constants confirmed exactly: kWhirlpoolAcHdrMark=8950, kWhirlpoolAcHdrSpace=4484, kWhirlpoolAcBitMark=597, kWhirlpoolAcOneSpace=1649, kWhirlpoolAcZeroSpace=533, kWhirlpoolAcGap=7920. Frame confirmed: 21-byte / 168-bit dedicated full-state protocol (kWhirlpoolAcStateLength=21, kWhirlpoolAcBits=168) transmitted in 3 sections of 6+8+7 bytes separated by the inter-section gap. Two XOR checksums confirmed (one at the first checksum byte covering section 1, a second checksum byte covering the following section). Power-toggle behavior confirmed (_.Power via setPowerToggle), and a Cmd field carries the last pressed button (temp/mode/fan/power command codes). Temp/Mode/Fan are bit-fields in the state array. Two model variants confirmed: DG11J1-91 (J191=true) applies a -2C temperature offset and DG11J1-3A (J191=false) applies 0 offset. This is a genuinely distinct dedicated AC protocol, not a generic NEC/Samsung32 misclassification, and the carrier is the standard 38 kHz (not Panasonic ~37 kHz or Sony ~40 kHz). No discrepancies found; all claims match the authoritative source."
   },
   {
    "brand": "GE",
    "protocolName": "GE 48-bit pulse-distance (LIRC raw); NOT a generic IRremoteESP8266 AC protocol",
    "correctedCarrierHz": 38000,
    "verdict": "confirmed",
    "reasoning": "Every detail of the claim was independently verified against primary sources. (1) The Absurdly Certain blog (absurdlycertain.blogspot.com, 2013, \"LIRC RasPi remote control configuration for GE Air Conditioner\") was located and its LIRC config matches the claim exactly: bits 48, flags SPACE_ENC, header 3388 1678 (leader 3388us mark / 1678us space), one 430 1257 (bit mark ~430us, one-space 1257us), zero 430 412 (zero-space 412us), ptrail 428 (trailing 428us), gap 40991 (inter-frame ~40991us). (2) The captured hex codes match exactly: Power 0x555AF308598F, Cool 0x555AF3081D8F, Temp+ 0x555AF308D987, Fan hi/mid/low 0x555AF308DD83 / 0x555AF3083D8D / 0x555AF308BD85 -- all sharing the 0x555AF308 prefix. This is consistent with a discrete per-button protocol (each button is one fixed 48-bit code), not a packed state frame. (3) The note that the IRremoteESP8266 'GE' entry is misleading is also confirmed: SupportedProtocols.md lists GE6711AR2853M under the LG protocol (Brand: General Electric, but handled by the LG protocol -- 'LG - GE6711AR2853M'), with NO native standalone 'GE' AC protocol. So this blog's GE window/portable AC remote is a genuinely distinct 48-bit space-encoded protocol, not the LG-based GE6711AR2853M, and not a generic IRremoteESP8266 AC protocol. Carrier: not stated by the blog author; 38kHz is the typical default for such consumer IR and is a reasonable assumption (this is the one unverified detail, but it does not contradict any evidence and is the standard frequency). No NEC/Samsung32 confusion applies (48-bit length and the timing/leader differ from both NEC and Samsung32). Verdict: confirmed."
   }
  ]
 },
 {
  "target": "ac-sharp-beko",
  "protocols": [
   {
    "brand": "Sharp",
    "kind": "AC (air conditioner / heat pump)",
    "protocolName": "SHARP_AC (Sharp A/C)",
    "carrierHz": 38000,
    "frameSummary": "Leader/header mark ~3800us, header space ~1900us. Bit mark ~470us; '1' space ~1400us, '0' space ~500us. State is a full 13-byte (104-bit) message (kSharpAcStateLength=13), LSB-first per byte, terminated by a final bit mark + message gap. State layout: byte4 = temp (4 bits, 15-30C) + model bit; byte5 = PowerSpecial (4-bit power/special state, values 0-8); byte6 = mode (2 bits: cool/heat/dry/auto) + fan (3 bits, auto/min/med/high/max) + clean bit; byte7 = timer hours+type; byte8 = swing (3 bits); byte11 = ion bit; byte12 = 4-bit checksum (nibble sum). Supports A705/A903/A907 remote variants selected via the model bit.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Sharp.h + src/ir_Sharp.cpp (sendSharpAc/decodeSharpAc, IRSharpAc class) and SupportedProtocols.md (models AH-A12REVP-1, AH-AxSAY, AH-PR13-GL, AH-XP10NRY, AY-ZP40KR, CRMC-820JBEZ / CRMC-A907 JBEZ remotes). github.com/crankyoldgit/IRremoteESP8266",
    "notes": "Distinct, fully reverse-engineered AC protocol (NOT generic NEC). Library marks it stable/working with per-field setters (power, temp, mode, fan, swing, turbo, econo, ion, clean, timer). One known quirk: A903 reports temp 2C lower than the remote display (issue #1819). A complete encoder can be written today from the library."
   },
   {
    "brand": "Sharp",
    "kind": "TV / AV remote (non-AC)",
    "protocolName": "SHARP (Sharp TV protocol)",
    "carrierHz": 38000,
    "frameSummary": "No long leader pulse. 15-bit frame (kSharpBits=15) = 5 address bits + 8 command bits + 1 expansion bit + 1 check bit, LSB-first. Bit mark ~260us; '1' space ~1820us, '0' space ~780us; inter-frame gap ~43800us. Per Sharp spec the frame is sent twice: first with expansion=1/check=0, then a second time with the command/expansion/check bits inverted (address kept) for error detection.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Sharp.cpp (sendSharp/sendSharpRaw, kSharpBits) + LIRC db sharp remotes; e.g. device LC-52D62U TV. github.com/crankyoldgit/IRremoteESP8266",
    "notes": "This is the classic Sharp 15-bit protocol used by Sharp TVs/AV gear, distinct from NEC and from the Sharp AC protocol above. Real per-button codes exist in LIRC remote DB for many Sharp TVs. Included for completeness; only relevant if non-AC Sharp devices are in scope."
   },
   {
    "brand": "Beko",
    "kind": "AC (split-type air conditioner)",
    "protocolName": "COOLIX (Coolix 24-bit)",
    "carrierHz": 38000,
    "frameSummary": "Header mark ~4400us, header space ~4400us (8 ticks x ~560us). Bit mark ~560us (1 tick); '1' space ~1680us (3 ticks), '0' space ~560us. 24 data bits sent with each byte followed by its bitwise-inverted complement (so the carried payload is effectively 3 bytes, transmitted as 6 with inversions), then a footer mark + ~5040us gap, and the whole 24-bit message is typically repeated. State layout: temp (4 bits, 17-30C, e.g. 17C=0b0000), mode (Cool 0b000/Dry 0b001/Auto 0b010/Heat 0b011/Fan 0b100), fan (Auto 0b101/Min 0b100/Med 0b010/Max 0b001/ZoneFollow/Fixed), with fixed marker nibble 0xB; power handled via dedicated on/off command words rather than a single power bit.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Coolix.h + src/ir_Coolix.cpp (IRCoolixAC, sendCoolix/decodeCoolix) and SupportedProtocols.md explicitly listing Brand: Beko, models BINR 070/071 split-type A/C and remote RG57K7(B)/BGEF. github.com/crankyoldgit/IRremoteESP8266",
    "notes": "Beko is explicitly documented as Coolix (same family as Midea). Stable/confirmed-working 24-bit variant; a 48-bit COOLIX48 variant also exists (alpha). A full encoder is implementable now. Coolix sends discrete command words for special functions (power, swing, turbo, light, etc.) rather than re-sending full state each time."
   },
   {
    "brand": "Ar\u00e7elik / Arcelik",
    "kind": "AC (split-type air conditioner)",
    "protocolName": "COOLIX (most likely) / VESTEL_AC (some Turkish-market units)",
    "carrierHz": 38000,
    "frameSummary": "No Arcelik-branded entry exists in IRremoteESP8266. Inference: Arcelik is the Turkish parent company that owns Beko (and Grundig/Blomberg), and Beko ACs are documented as COOLIX, so Arcelik-branded splits most likely also use the COOLIX 24-bit frame (header ~4400/4400us, bit mark 560us, '1'=1680us, '0'=560us, byte+complement, repeated). Alternative: some Turkish-market remotes match the VESTEL_AC protocol (header mark ~3110us, space ~9066us, bit mark ~520us, '1' space ~1535us, '0' space ~480us, 128-bit two-field cmdState/timeState; temp 16-30C 4 bits, mode 3 bits, fan 4 bits).",
    "publicDataAvailable": false,
    "confidence": "low",
    "implementability": "partial",
    "source": "Inference from IRremoteESP8266 SupportedProtocols.md (Beko->COOLIX) given Arcelik=Beko parent; plus ir_Vestel.h/.cpp for the VESTEL_AC alternative. No Arcelik-specific reverse-engineered code set found in IRremoteESP8266, LIRC, or IRDB.",
    "notes": "HONEST GAP: there is no public, Arcelik-labelled per-button/full-state spec. Practical path is to raw-capture the specific Arcelik remote with IRrecvDumpV2 and check whether it decodes as COOLIX (most probable) or VESTEL_AC. Do NOT assume; verify against the physical remote. Marked partial because the candidate protocols are well-documented but the brand mapping is unconfirmed."
   },
   {
    "brand": "Kenmore",
    "kind": "AC (window / portable / mini-split)",
    "protocolName": "MIDEA / COOLIX (likely, OEM-dependent) \u2014 NOT a distinct Kenmore protocol",
    "carrierHz": 38000,
    "frameSummary": "Kenmore is a Sears house brand with no IR protocol of its own; units are OEM-rebranded. The most-cited OEM is Midea Group (Kenmore is listed among Midea-family brands), implying the Midea/Coolix family: 38kHz, header ~4400/4400us, bit mark ~560us, '1' space ~1680us, '0' space ~560us, byte-plus-complement, message repeated. Midea full-state variant uses a 48-bit frame (address 0xBA45 + 0xD22D-style payload carrying temp/mode/fan) vs the 24-bit Coolix-style command words. Specific bit layout depends on which OEM/model the particular Kenmore unit is.",
    "publicDataAvailable": false,
    "confidence": "low",
    "implementability": "partial",
    "source": "No Kenmore entry in IRremoteESP8266, LIRC, or IRDB (code search for 'Kenmore' returns 0 hits). Brand->OEM mapping from mac-zhou/midea-ac-py (lists Kenmore as a Midea Group brand) and hobby-hour universal-remote setup-code tables (which give only 3-4 digit universal codes, not raw IR).",
    "notes": "HONEST GAP: no Kenmore-specific reverse-engineered IR spec exists publicly; only universal-remote setup codes (opaque, not raw timings). Kenmore ACs are OEM units (commonly Midea, sometimes LG or others depending on year/model), so the correct protocol must be determined per unit by raw-capturing the remote and matching against MIDEA/COOLIX (or LG) decoders. Cannot write a guaranteed encoder blind. Marked partial: the probable underlying protocols are fully documented, but the Kenmore->protocol binding is unverified."
   }
  ],
  "verdicts": [
   {
    "brand": "Sharp",
    "protocolName": "SHARP_AC (Sharp A/C)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently verified against IRremoteESP8266 src/ir_Sharp.h (Doxygen source) and src/ir_Sharp.cpp. The Doxygen header source lists kSharpAcHdrMark=3800us, kSharpAcHdrSpace=1900us, kSharpAcBitMark=470us, kSharpAcOneSpace=1400us, kSharpAcZeroSpace=500us, and kSharpAcStateLength=13 bytes (104 bits) \u2014 all matching the claim. sendSharpAc passes 38000 Hz (38 kHz) to sendGeneric, matching the claimed carrier. The SharpProtocol union field layout matches: byte4 = temp (4 bits, 15-30C) + model bit; byte5 = PowerSpecial (4-bit power/special); byte6 = mode (2 bits) + fan (3 bits) + clean bit; byte7 = timer hours/type/enabled; byte8 = swing (3 bits); byte11 = ion bit (plus model2); byte12 = 4-bit checksum (nibble sum). This is a dedicated 13-byte stateful protocol, NOT generic NEC or Coolix/Midea-family. The LSB-first-per-byte ordering and final bit mark + gap termination are consistent with the library's sendGeneric usage and the test vectors. No corrections needed; carrier is correctly 38 kHz (not Panasonic ~37 kHz or Sony ~40 kHz). Verdict: confirmed."
   },
   {
    "brand": "Sharp",
    "protocolName": "SHARP (Sharp TV protocol)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Two independent reputable sources confirm every claimed parameter. (1) IRremoteESP8266 src/ir_Sharp.cpp (crankyoldgit) defines kSharpBits=15 with structure Address(5)+Command(8)+Expansion(1)+Check(1), carrier 38kHz, kSharpBitMark=260us, kSharpOneSpace=1820us, kSharpZeroSpace=780us, kSharpGap~43602us, no long leader pulse, and the documented requirement that data be sent twice 'once normally, then with all but the address bits inverted.' (2) SB-Projects (sbprojects.net/knowledge/ir/sharp.php) independently confirms 38kHz, 5 address bits + 8 command bits + expansion + check = 15 bits total, LSB-first, logical 1 = 2ms / logical 0 = 1ms (matching the 1820/780us spaces), and a second message ~40ms later with all bits except the address inverted for error detection. This is a genuine distinct protocol (not generic NEC: NEC has a long 9ms leader pulse, 32 bits MSB-grouped with address+command byte-inversion, whereas Sharp has no leader, 15 bits, LSB-first, and inverts on a whole second transmission). Carrier is correctly 38kHz (not Panasonic's ~37kHz nor Sony's ~40kHz). No correction needed."
   },
   {
    "brand": "Beko",
    "protocolName": "COOLIX (Coolix 24-bit)",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "verdict": "confirmed",
    "reasoning": "Independently verified against the cited primary source (crankyoldgit/IRremoteESP8266). (1) SupportedProtocols.md explicitly lists \"Beko | BINR 070/071 split-type A/C / RG57K7(B)/BGEF Remote\" under the COOLIX protocol, matching the claimed models exactly. (2) src/ir_Coolix.cpp confirms 38kHz carrier, 24 data bits transmitted as three bytes each followed by its bitwise-inverted complement (48 bits on the wire, \"this protocol is basically a 48-bit version of NEC with alternate bytes inverted, so only 24 bits of real data\"), with at least one repeat. (3) The framing timings match within tick-rounding: the library uses a ~276us tick giving header mark 4692us, header space 4416us, bit mark 552us, '1' space 1656us, '0' space 552us, min gap 5244us. The claimed values (4400/4400/560/1680/560/5040) are the standard rounded/approximate figures for these same constants and are correct in structure. No protocol confusion present: this is a genuine AC-family protocol (Coolix, shared with Midea/Tokio/Airwell), not generic NEC mislabeling, and not a Samsung/Sony/Panasonic carrier mismatch (Coolix is correctly 38kHz). The only deviations from the claim are minor approximate-vs-exact tick timings, which do not change the protocol identity, so this is confirmed rather than corrected."
   },
   {
    "brand": "Ar\u00e7elik / Arcelik",
    "protocolName": "COOLIX (most likely) / VESTEL_AC (some Turkish-market units)",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "verdict": "confirmed",
    "reasoning": "Independently verified against IRremoteESP8266 source. (1) Carrier: COOLIX uses enableIROut(38) = 38 kHz, confirming the 38000 Hz claim. No carrier confusion (this is not Panasonic ~37 kHz or Sony ~40 kHz). (2) COOLIX timings from ir_Coolix.cpp: kCoolixHdrMark=4692us, kCoolixHdrSpace=4416us, kCoolixBitMark=552us, kCoolixOneSpace=1656us, kCoolixZeroSpace=552us, 24-bit. The researcher's stated values (header ~4400/4400, bit mark 560, '1'=1680, '0'=560, 24-bit byte+complement, repeated) are correct to within rounding \u2014 substantively accurate. (3) The framing premise is verified: SupportedProtocols.md contains NO 'Arcelik'/'Ar\u00e7elik' entry under any protocol. (4) Beko IS explicitly listed under COOLIX (BINR 070/071 split-type A/C, RG57K7(B)/BGEF Remote), and Midea also COOLIX \u2014 supporting the parent-company inference since Ar\u00e7elik owns Beko. (5) VESTEL_AC lists only Vestel (BIOX CXP-9); header mark ~3110us, space ~9066us, bit mark ~520us, '1' space ~1535us, '0' space ~480us, 128-bit \u2014 a legitimate distinct Turkish-market protocol, correctly described as the alternative. CAVEAT preventing full certainty: this remains an inference; no Arcelik-specific reverse-engineered code or raw IR capture was found in IRremoteESP8266, LIRC, or IRDB. The irplus 'Ar\u00e7elik Oxygen Plasma' remote entry exists but exposes no protocol/timing spec. The brand-to-protocol mapping (Arcelik->COOLIX via Beko) is plausible and brand-consistent, and the COOLIX/VESTEL_AC technical details are accurate, so the claim's substance and its hedged confidence ('most likely', with a stated alternative) are confirmed rather than corrected. No common AC-protocol mistakes were committed (correctly treats this as an AC stateful protocol, not generic NEC; COOLIX is the Midea/Coolix family, consistent with guidance that Midea=Coolix-family)."
   },
   {
    "brand": "Kenmore",
    "protocolName": "MIDEA / COOLIX (likely, OEM-dependent) \u2014 NOT a distinct Kenmore protocol",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Every verifiable element of the claim checks out against reputable sources.\n\n1) No distinct Kenmore protocol: Confirmed. The IRremoteESP8266 SupportedProtocols.md does not contain any \"Kenmore\" entry. Kenmore is a Sears house brand with no IR protocol of its own.\n\n2) OEM = Midea: Strongly confirmed. Sears.com itself sells parts labeled \"OEM Midea Air Conditioner\" that \"originally shipped with\" Kenmore-branded AC units (e.g., model MPPD12CRN1BI0 / MPPDA08CRN1BCG5). Kenmore.com also lists Midea OEM compressor parts. This corroborates the mac-zhou/midea-ac brand-family mapping cited by the researcher. Therefore Kenmore AC units inherit whatever protocol their Midea OEM uses.\n\n3) Protocol family and carrier (the key trap): Confirmed correct. Midea AC IR is the Coolix/Midea family at 38kHz \u2014 NOT NEC, NOT Samsung32. This avoids the carrier-frequency traps (it is not Sony ~40kHz nor Panasonic ~37kHz) and the AC-protocol-mismatch trap (Midea is correctly Coolix-family, not NEC). IRremoteESP8266 groups Midea with Coolix and lists sibling OEM brands (Keystone, Danby, Comfee, Pioneer, Beko, MrCool, Lennox), consistent with the rebrand-family framing.\n\n4) Timing parameters: Confirmed within rounding. IRremoteESP8266 Coolix constants: bit mark ~552us, '1' space ~1656us, '0' space ~552us, header ~4480us. The claim's 560/1680/560 and header ~4400 are the canonical rounded NEC/Coolix-family values and match. Byte-plus-complement framing and message repetition are documented (e.g., 0xBA45 address + 0xD22D... payload with complement bytes; 48-bit full-state Midea variant vs 24-bit Coolix command words).\n\nThe claim is appropriately hedged (\"likely, OEM-dependent\") and that hedge is itself accurate, since the exact bit layout depends on the specific Midea model behind a given Kenmore unit. Nothing in the claim is contradicted; carrier (38000Hz) and protocol family are correct."
   }
  ]
 },
 {
  "target": "audio-soundbar",
  "protocols": [
   {
    "brand": "Samsung",
    "kind": "soundbar/hi-fi (audio devices)",
    "protocolName": "Samsung32",
    "carrierHz": 38000,
    "frameSummary": "Pulse-distance protocol. Leader: 4480us mark + 4480us space. Bit mark 560us; logical 1 = 560us mark + 1680us space, logical 0 = 560us mark + 560us space. 32 bits total, LSB-first, structured as customer_byte + customer_byte(repeated) + command_byte + inverted(command_byte). Stop bit (560us mark) closes the frame. Min gap ~108ms. Distinct from NEC (which sends address+~address, not a doubled customer code).",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Samsung.cpp (kSamsungHdrMark/Space=4480us, kSamsungBitMark=560us, kSamsungOneSpace=1680us, kSamsungZeroSpace=560us, sendGeneric @38kHz, 32 bits). Cross-check: sbprojects/handsontec note 37.9kHz carrier.",
    "notes": "Samsung soundbars (HW-* series) use the Samsung32 remote protocol for IR commands (power, volume, source, sound mode). This is a real distinct protocol, not generic NEC, though it shares pulse-distance encoding. Per-button codemaps are widely available (IRDB, hifi-remote, LIRC samsung remotes). Note: Samsung HVAC/AC uses a separate Samsung AC stateful protocol (kSamsungAcStateLength), unrelated to audio. Carrier commonly cited 37.9-38kHz."
   },
   {
    "brand": "LG",
    "kind": "soundbar/hi-fi (audio devices)",
    "protocolName": "NEC-family / LG (28-bit and 32-bit variants)",
    "carrierHz": 38000,
    "frameSummary": "Pulse-distance, NEC-derived. LG 28-bit: leader 8500us mark + 4250us space; bit mark 550us, one-space 1600us, zero-space 550us; 28 bits = 8/12-bit address + 16-bit command + 4-bit checksum. LG32 variant: leader 4500us mark + 4450us space, 32 bits. Repeat space 2250us, min gap ~39.75ms. Originates from NEC uPD6121 or TC9012 remote chips (uPD6121=9ms header, TC9012=4.5ms header).",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_LG.cpp (kLgHdrMark=8500, kLgHdrSpace=4250, kLgBitMark=550, kLgOneSpace=1600, kLgZeroSpace=550; kLg32HdrMark=4500/Space=4450; 28/32-bit, @38kHz). LIRC lg remote db; IRDB LG/.",
    "notes": "LG audio devices (soundbars, mini hi-fi systems) use LG's NEC-family protocol. It is recognized as a distinct 'LG' protocol in IRremoteESP8266 because of the 28-bit framing + nibble-sum checksum, but it is fundamentally NEC pulse-distance with LG-specific headers/bit-count. Real per-button codes available in IRDB and LIRC. The 'LG' protocol in the library is the same one used by TVs/audio; LG AC is a separate stateful protocol."
   },
   {
    "brand": "Sony",
    "kind": "soundbar/hi-fi/radio (audio devices)",
    "protocolName": "SIRC (Sony 12/15/20-bit)",
    "carrierHz": 40000,
    "frameSummary": "Pulse-WIDTH coded (not pulse-distance). Start/header burst 2400us + 600us space. Logical 1 = 1200us burst, logical 0 = 600us burst, each separated by 600us space. Three variants: 12-bit (7-bit command + 5-bit device address), 15-bit (7-bit cmd + 8-bit addr), 20-bit (7-bit cmd + 5-bit addr + 8-bit extended). LSB-first. Frame repeats every 45ms while key held. 40kHz carrier (notably not 38kHz).",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Sony.cpp (sendSony, 12/15/20-bit, 40kHz, hdr 2400us, one 1200us, zero 600us); sbprojects.net/knowledge/ir/sirc; righto.com Sony LIRC analysis; hifi-remote.com/sony per-device codes.",
    "notes": "Sony audio gear (HT-* soundbars, STR receivers, hi-fi, clock radios) uses SIRC. Different device categories use different device addresses (e.g. audio/amplifier addresses distinct from TV). Genuinely distinct protocol (PWM, 40kHz). Extensive real per-button code tables at hifi-remote.com/sony and in LIRC. Fully implementable today."
   },
   {
    "brand": "Panasonic",
    "kind": "soundbar/hi-fi/radio (audio devices)",
    "protocolName": "Kaseikyo (Panasonic 48-bit)",
    "carrierHz": 37000,
    "frameSummary": "Pulse-distance. Leader 3456us mark + 1728us space. Bit mark 432us; one = 432us mark + 1296us space, zero = 432us mark + 432us space. 48 bits LSB-first: 16-bit manufacturer/vendor code (Panasonic = 0x2002 / 'customer' code), 8-bit device code, 8-bit subdevice code, 8-bit function/command, 8-bit checksum = XOR(device, subdevice, function). Min gap ~74.7ms; min command length ~163ms.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Panasonic.cpp (kPanasonicHdrMark=3456, HdrSpace=1728, BitMark=432, OneSpace=1296, ZeroSpace=432, 48-bit Kaseikyo, ~37kHz). hifi-remote.com/wiki Kaseikyo; LIRC panasonic db; IRDB Panasonic/.",
    "notes": "Panasonic soundbars / SC-* hi-fi micro systems use the Kaseikyo 48-bit protocol (Panasonic vendor code). Kaseikyo is a protocol FAMILY (Panasonic, Mitsubishi-K, Fujitsu, SharpDVD, Teac-K) distinguished by the 16-bit vendor code; Panasonic is one member. Real per-button codes in IRDB/LIRC. Carrier 37kHz (some refs 36.7/38kHz). Distinct protocol, fully implementable."
   },
   {
    "brand": "Philips",
    "kind": "soundbar/hi-fi/radio (audio devices)",
    "protocolName": "RC5 / RC6 (also RC-MM on some newer gear)",
    "carrierHz": 36000,
    "frameSummary": "Manchester (bi-phase) coded, NOT pulse-distance. RC5: 36kHz carrier, fixed bit time 1778us (half mark/half space); '0' = burst in first half, '1' = burst in second half; frame = 2 start bits + 1 toggle bit + 5-bit address + 6-bit command (14 bits; RC5X uses field bit for 7-bit command). RC6: 36kHz, base unit 1t=444us (16 carrier cycles), leader 2666us mark + 889us space, start bit, mode (3 bits), toggle (double-width in Mode 0), then address+command; Manchester but inverted polarity vs RC5. Toggle bit flips each keypress.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_RC5_RC6.cpp; sbprojects.net/knowledge/ir/rc5 and /rc6; LIRC philips remotes db; IRDB Philips/. hifi-remote RC5 hex code tables.",
    "notes": "Philips audio (soundbars, Fidelio, micro hi-fi, clock radios) historically uses RC5; newer/AV gear uses RC6 (and occasionally RC-MM for some products). Both are real distinct Manchester-coded protocols at 36kHz. Toggle bit must be implemented for repeat-vs-new-press semantics. Real per-button codes available in LIRC and hifi-remote RC5 tables. The main caveat: a given Philips soundbar model may use RC5 OR RC6 (or System/subsystem-addressed RC5) \u2014 identify per model. Both fully implementable; mark 'ready' but verify RC5-vs-RC6 per specific device."
   }
  ],
  "verdicts": [
   {
    "brand": "Samsung",
    "protocolName": "Samsung32",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "All parameters independently verified against the primary source (IRremoteESP8266 src/ir_Samsung.cpp by crankyoldgit) and corroborating secondary sources. Confirmed: kSamsungHdrMark/Space = 4480us each (8 ticks x 560us), kSamsungBitMark = 560us, kSamsungOneSpace = 1680us (3 ticks), kSamsungZeroSpace = 560us; sendGeneric at 38kHz; 32 bits, LSB-first. Frame structure confirmed as customer_byte + customer_byte(repeated) + command_byte + inverted(command_byte) \u2014 a doubled customer code plus command and its complement. The key distinction from NEC is correctly stated: Samsung uses a 4480us+4480us (4.5/4.5ms-class) leader and DOUBLES the customer code, whereas NEC uses a 9000us+4500us leader and sends address + inverse(address). Carrier 38kHz is correct; the sbprojects/handsontec '37.9kHz' note is the real-world measured equivalent of the nominal 38kHz, not a discrepancy. No NEC/Samsung confusion, no carrier error, no AC-protocol mismatch (this is the TV/audio Samsung32 protocol, not the SamsungAC variant). Verdict: confirmed."
   },
   {
    "brand": "LG",
    "protocolName": "NEC-family / LG (28-bit and 32-bit variants)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently confirmed against the primary cited source (IRremoteESP8266 src/ir_LG.cpp on GitHub) and a second reputable IR reference (SB-Projects NEC page). Every timing constant matches exactly: kLgHdrMark=8500us, kLgHdrSpace=4250us, kLgBitMark=550us, kLgOneSpace=1600us, kLgZeroSpace=550us; LG32 kLg32HdrMark=4500us, kLg32HdrSpace=4450us; kLgRptSpace=2250us, kLgMinGap=39750us (~39.75ms). Carrier is 38kHz, confirmed by the sendGeneric calls in ir_LG.cpp and by SB-Projects for the NEC family it derives from -- correctly in the 38kHz family, not confused with Panasonic ~37kHz or Sony ~40kHz. The 28-bit (8/12-bit address + 16-bit command + 4-bit checksum) and 32-bit variants are confirmed, as is the NEC-derived pulse-distance encoding. Notably the source itself flags that LG32 is near-identical to Samsung32, differing in header mark and repeat signaling -- the claim correctly treats them as distinct LG variants rather than conflating NEC/LG with Samsung32, avoiding the listed common mistake. No discrepancies found."
   },
   {
    "brand": "Sony",
    "protocolName": "SIRC (Sony 12/15/20-bit)",
    "verdict": "confirmed",
    "correctedCarrierHz": 40000,
    "correctedProtocol": "",
    "reasoning": "Every element of the claim is independently corroborated by multiple reputable sources.\n\nCARRIER: sbprojects.net confirms SIRC uses a 40kHz carrier (duty cycle 1/4 to 1/3), distinct from the 38kHz norm. This matches the claim's emphasis on 40kHz (not 38kHz) and IRremoteESP8266's Sony implementation. Correct, and avoids the common carrier-mismatch error.\n\nENCODING/TIMING: sbprojects.net states SIRC uses PULSE-WIDTH encoding (not pulse-distance). Header/start burst = 2.4ms (2400us) followed by a 0.6ms (600us) space. Logical 1 = 1200us burst, logical 0 = 600us burst, all bursts separated by a 600us space. This matches the claim exactly.\n\nVARIANTS: Three versions exist - 12-bit (7-bit command + 5-bit device address), 15-bit (7-bit command + 8-bit address), and 20-bit (7-bit command + 5-bit address + 8-bit extended). Confirmed verbatim by sbprojects.net.\n\nBIT ORDER: LSB transmitted first - confirmed.\n\nREPEAT: Frame repeats every 45ms (start-to-start) while the key is held - confirmed by sbprojects.net.\n\nSOURCE VALIDATION: IRremoteESP8266 src/ir_Sony.cpp (sendSony) uses 40kHz with the standard kSonyHdrMark/OneMark/ZeroMark constants (2400/1200/600us), and the library notes Sony expects the frame sent 3 times (repeat=2). righto.com's Sony LIRC analysis corroborates the framing.\n\nNo errors detected. This is genuinely SIRC, not a generic NEC/Samsung32 mislabel, and the 40kHz carrier is correctly stated rather than the common 38kHz default. All facts verified independently."
   },
   {
    "brand": "Panasonic",
    "protocolName": "Kaseikyo (Panasonic 48-bit)",
    "verdict": "confirmed",
    "correctedCarrierHz": 37000,
    "correctedProtocol": "",
    "reasoning": "Every claimed parameter is independently corroborated by reputable, primary sources.\n\n1) Timing \u2014 IRremoteESP8266 src/ir_Panasonic.cpp (crankyoldgit, the cited source) defines exactly: kPanasonicHdrMark=3456, kPanasonicHdrSpace=1728, kPanasonicBitMark=432, kPanasonicOneSpace=1296, kPanasonicZeroSpace=432 us. This is pulse-distance encoding (one = 432 mark + 1296 space; zero = 432 mark + 432 space), matching the claim verbatim. Min gap = 74736us (~74.7ms) and min command length = 163296us (~163ms) also match.\n\n2) Carrier \u2014 Confirmed ~37kHz, NOT 38kHz or 40kHz. The hifi-remote/DecodeIR IRP notation for Panasonic Kaseikyo is {37k,432}<1,-1|1,-3>(8,-4,2:8,32:8,D:8,S:8,F:8,(D^S^F):8,1,-173)+, where 432us = 16 cycles of 37kHz and 3456us = 8 units = the leader. Arduino-IRremote PR #442 by crankyoldgit explicitly corrected the value FROM 35kHz TO 37kHz, citing GlobalCache, hifi-remote, and RemoteCentral (true carrier ~36.7kHz; IRremoteESP8266 stores kPanasonicFreq=36700, i.e. the integer-rounded 37kHz the claim states). One sub-model WebFetch initially misreported 40kHz, but that was a read error contradicted by the IRP notation, the PR, and the source constant.\n\n3) Frame \u2014 48 bits LSB-first, Kaseikyo family (Panasonic, Mitsubishi-K, Fujitsu, SharpDVD, Teac-K). Panasonic vendor/customer code = OEM bytes 0x02 then 0x20 = 0x2002 little-endian, matching the claimed 16-bit manufacturer code. Structure manufacturer(16) / device(8) / subdevice(8) / function(8) / checksum(8) is correct.\n\n4) Checksum \u2014 Confirmed as XOR(device, subdevice, function), i.e. (D^S^F):8 in the IRP and device^subdevice^function in the source. Matches exactly.\n\nNo NEC/Samsung32 confusion, no wrong-carrier error, no generic-NEC substitution, and no AC-protocol mismatch. The researcher's claim is accurate in protocol name, framing, carrier, and checksum.\n\nSources: github.com/crankyoldgit/IRremoteESP8266/blob/master/src/ir_Panasonic.cpp and ir_Panasonic.h (kPanasonicFreq=36700); hifi-remote.com/wiki Kaseikyo (IRP {37k,432}, D^S^F checksum, OEM codes 2/32); Arduino-IRremote PR #442 \"Fix incorrect frequency used for Panasonic\" (35k->37k)."
   },
   {
    "brand": "Philips",
    "protocolName": "RC5 / RC6 (also RC-MM on some newer gear)",
    "verdict": "confirmed",
    "correctedCarrierHz": 36000,
    "reasoning": "Independently verified from reputable sources (sbprojects.net RC5/RC6 pages, pcbheaven, hifigear, AVS Forum). Carrier of 36kHz confirmed for both RC5 and RC6 (distinct from the common 38kHz NEC/Samsung family, ~40kHz Sony, ~37kHz Panasonic). RC5 details confirmed: Manchester/bi-phase coding (not pulse-distance), fixed 1778us bit time with 889us half-bursts, '0'=burst in first half / '1'=burst in second half, 14-bit frame = 2 start bits + 1 toggle + 5-bit address + 6-bit command, with RC5X extending to a 7-bit command via the second start/field bit. RC6 details confirmed: 1t=444us (16 carrier cycles), leader = 6t (2666us) mark + 2t (889us) space, Manchester with polarity inverted relative to RC5, plus a toggle/trailer bit (double-width in Mode 0) that flips on keypress. Brand fit confirmed: Philips audio gear (e.g. CSS2123 soundbar documented using RC6) uses these Philips-origin protocols. RC-MM is a genuine Philips variant on newer equipment. No carrier or framing errors found; the claim is accurate."
   }
  ]
 },
 {
  "target": "dvd-bluray",
  "protocols": [
   {
    "brand": "Samsung",
    "kind": "DVD/Blu-ray player",
    "protocolName": "Samsung32 (older DVD) and SAMSUNG36 (Blu-ray)",
    "carrierHz": 38000,
    "frameSummary": "Two distinct protocols. SAMSUNG32 (NEC-like, used by most Samsung DVD/older players and many BD players): header mark 4480us + space 4480us; bit mark 560us; '1' space 1680us; '0' space 560us; 32 bits = customer_byte + customer_byte(repeat, NOT inverted) + command_byte + ~command_byte(inverted). LSB-first, trailing stop bit, min gap ~7280us. Repeats sent as full frames. Real per-button codes are well documented (address byte 0xE0E0 for Samsung AV; e.g. Power 0xE0E040BF, Eject 0xE0E0E01F, Source 0xE0E0807F). SAMSUNG36 is the modern Samsung Blu-ray/Soundbar protocol: header mark 4515us + space 4438us; bit mark 512us; '1' space 1468us; '0' space 490us; 36 total bits split into a 16-bit block (header precedes this) + a 4-bit gap/spacer + a 20-bit block. IRremoteESP8266 lists AK59-00167A (Samsung Blu-ray remote) and AH59-02692E (Soundbar) explicitly under SAMSUNG36.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Samsung.cpp and src/ir_Samsung.h (sendSAMSUNG, sendSamsung36); SupportedProtocols.md lists AK59-00167A Blu-ray remote as SAMSUNG36; LIRC samsung remote files; community gists for per-button hex.",
    "notes": "Older Samsung DVD players use SAMSUNG32. Modern Blu-ray players (and their soundbar combos) commonly use SAMSUNG36. Both fully documented with timings and real codes. Note SAMSUNG32 differs from pure NEC in that the address byte is duplicated (not inverted) and timings use 560us base like NEC but 4480/4480 header instead of NEC's 9000/4500."
   },
   {
    "brand": "LG",
    "kind": "DVD/Blu-ray player",
    "protocolName": "NEC / NEC32 (no distinct LG DVD protocol)",
    "carrierHz": 38000,
    "frameSummary": "LG DVD and Blu-ray players use the standard NEC protocol, not a vendor-unique IR protocol. NEC frame: header mark 9000us + space 4500us; bit mark 560us; '1' space 1690us; '0' space 560us; 32 bits = address(8) + ~address(8) + command(8) + ~command(8), LSB-first, single 560us trailing stop bit; a repeat is a 9000us mark + 2250us space + stop bit every ~110ms. LG AV device codes commonly carry address 0x20DF (e.g. Power 0x20DF10EF, and documented hex like 0x20DFA35C). Some newer LG remotes deviate from strict inversion and decode as NEC32 (full 32 bits, second/fourth bytes not the bitwise inverse of first/third). The LG *air-conditioner* protocol is a separate distinct protocol, but that is NOT what DVD/BD players use.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "LIRC LG remote DB; community gists (gist.github.com/francis2110/8f69843dd57ae07dce80 LG IR codes); Linux kernel rc-protos.md (NEC/NEC32 definitions); IRremoteESP8266 ir_NEC for generic NEC encoding.",
    "notes": "Honest distinction: this is generic NEC with the LG 0x20DF address space, NOT a reverse-engineered LG-specific protocol. Implementable today because NEC is fully specified and LG per-button hex codes are published. Do not conflate with the separate, distinct LG-AC protocol in IRremoteESP8266."
   },
   {
    "brand": "Sony",
    "kind": "DVD/Blu-ray player",
    "protocolName": "SIRC (Sony, 12/15/20-bit) \u2014 DVD/BD typically 20-bit",
    "carrierHz": 40000,
    "frameSummary": "Sony SIRC, carrier 40kHz (not 38kHz). Start/header burst 2400us mark + 600us space. Pulse-width encoding: '1' = 1200us mark, '0' = 600us mark; every bit separated/followed by 600us space. LSB-first. Command (7 bits) transmitted first, then address (device) bits. Three variants: 12-bit = 7 cmd + 5 addr; 15-bit = 7 cmd + 8 addr; 20-bit = 7 cmd + 5 addr + 8 extended bits. Frame repeated every 45ms (start-to-start) while key held; Sony devices typically require the frame sent 3x. DVD/Blu-ray players commonly use the 20-bit variant (DVD device address ~0x1A / 26 with extended bits). Real per-button codes available in LIRC and via Ken Shirriff's documentation.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "SB-Projects SIRC spec (sbprojects.net/knowledge/ir/sirc.php); Ken Shirriff righto.com 2010 Sony IR codes/LIRC article; IRremoteESP8266 ir_Sony (sendSony 12/15/20-bit); LIRC sony DVD remote files.",
    "notes": "Critical implementation detail: carrier is 40kHz, and unlike NEC/Samsung this is pulse-WIDTH encoded with no inverted-redundancy. Must send the frame 3 times. Choose 20-bit for DVD/BD. Fully implementable now."
   },
   {
    "brand": "Panasonic",
    "kind": "DVD/Blu-ray player",
    "protocolName": "Kaseikyo / Panasonic 48-bit",
    "carrierHz": 37000,
    "frameSummary": "Panasonic 48-bit is a modified Kaseikyo protocol, carrier 37kHz (~36.7kHz). Header mark ~3456us + space ~1728us (8T/4T at 432us base). Bit mark ~432us; '1' space ~1296us; '0' space ~432us; trailing stop bit. Pulse-distance encoding, LSB-first, 48 total bits = 16-bit manufacturer/vendor code (0x4004 for Panasonic, sent as 0x2002 reversed in some references) + 4-bit device(genre) + ... structured as: VendorID(16) + Parity/XOR(8 for vendor) + Device/Genre(4) + Subdevice + Function/command(8) + Checksum(8) where the final byte = XOR of the preceding data bytes. IRremoteESP8266 exposes sendPanasonic64()/encodePanasonic() taking (manufacturer 0x4004, device, subdevice, function). Real DVD/BD button codes derivable via the documented device+function fields.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Panasonic.cpp (sendPanasonic64, manufacturer 0x4004, checksum/XOR logic); Arduino-IRremote Kaseikyo docs; SupportedProtocols.md (PANASONIC/KASEIKYO 48-bit); LIRC panasonic DVD remote files.",
    "notes": "Distinct, fully reverse-engineered protocol (not NEC). Key facts: 37kHz carrier, Panasonic manufacturer code 0x4004, final byte is an XOR checksum of the message bytes which an encoder must compute. Encoder is straightforward to write with the IRremoteESP8266 reference. Per-button function codes for DVD/BD available in LIRC."
   }
  ],
  "verdicts": [
   {
    "brand": "Samsung",
    "protocolName": "Samsung32 (older DVD) and SAMSUNG36 (Blu-ray)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Independently confirmed against IRremoteESP8266 (src/ir_Samsung.cpp, ir_Samsung.h, SupportedProtocols.md) and multiple corroborating sources. (1) Carrier: Samsung uses ~38 kHz (precisely ~37.9 kHz); both SAMSUNG and SAMSUNG36 transmit at 38 kHz \u2014 matches the claimed 38000Hz. (2) SAMSUNG32 timing verified exactly: kSamsungTick=560us, HdrMark=4480us (8 ticks), HdrSpace=4480us (8 ticks), BitMark=560us, OneSpace=1680us (3 ticks), ZeroSpace=560us \u2014 all match. (3) SAMSUNG32 frame structure verified: address byte + address byte REPEATED (not inverted) + command + inverted command, LSB-first. This is the genuine differentiator from NEC (NEC inverts the address byte; Samsung repeats it un-inverted). The cited hex 0xE0E040BF decodes as E0/E0/40/BF where BF=~40 and E0 is repeated un-inverted, exactly fitting Samsung (not NEC) structure \u2014 so the claim correctly avoids the NEC-confusion trap. (4) SAMSUNG36 verified: header-marked 16-bit block + spacer (kSamsung36HdrSpace ~4438us) + 20-bit block = 36 bits, with HdrMark ~4515/HdrSpace ~4438/BitMark 512/OneSpace 1468/ZeroSpace 490us. (5) Model attributions AK59-00167A (Blu-ray remote) and AH59-02692E (Soundbar) are explicitly listed under SAMSUNG36 in SupportedProtocols.md. Minor non-disqualifying nuance: claimed SAMSUNG32 min gap ~7280us differs from IRremoteESP8266 kSamsungMinGap=6160us (11 ticks); min-gap values vary by source (LIRC vs IRremoteESP8266) and do not affect protocol identification. All load-bearing claims (carrier, both protocol names, timings, frame layout, model mapping) are independently corroborated, so the verdict is confirmed."
   },
   {
    "brand": "LG",
    "protocolName": "NEC / NEC32 (no distinct LG DVD protocol)",
    "verdict": "confirmed",
    "reasoning": "Independently confirmed across multiple reputable sources. (1) NEC timing/framing verified by SB-Projects IR reference: 38kHz carrier, 560us bursts, 9ms AGC header mark + 4.5ms space, logical '1' = 1.69ms space (2.25ms total), '0' = 560us space (1.125ms total), 32 data bits = address(8) + ~address(8) + command(8) + ~command(8), LSB-first, trailing stop bit \u2014 exactly as claimed; the ~110ms-spaced repeat frame (9ms mark + 2.25ms space + stop) is also standard NEC. (2) LG device address 0x20DF and Power = 0x20DF10EF confirmed by the cited francis2110 gist, the Tasmota Codes-for-IR-Remotes DB (lists 0x20DF10EF as LG NEC 32-bit power), and LIRC LG community discussion (pre_data 0x20DF + button code). (3) The claim that LG DVD/Blu-ray players use generic NEC rather than a vendor-unique protocol is supported: the gist and LIRC data show LG AV devices (including a BD/AVR unit noted in gist comments) share the same 0x20DF NEC code family as LG TVs; there is no separate documented LG DVD/BD IR protocol. (4) The researcher correctly distinguishes the LG *air-conditioner* protocol as a separate, distinct protocol \u2014 IRremoteESP8266's ir_LG.cpp implements LG AC as its own protocol (derived from JVC), NOT NEC, and the claim explicitly excludes it. (5) The NEC32 nuance is accurate: some newer LG remotes deviate from strict byte inversion and decode as full-32-bit NEC32/NEC-extended rather than standard checksummed NEC. No carrier-frequency error (38kHz is correct for LG/NEC; not Sony 40kHz or Panasonic 37kHz), and no Samsung32 confusion. Every load-bearing element of the claim checks out.",
    "correctedCarrierHz": 38000,
    "correctedProtocol": ""
   },
   {
    "brand": "Sony",
    "protocolName": "SIRC (Sony, 12/15/20-bit) \u2014 DVD/BD typically 20-bit",
    "correctedProtocol": "",
    "verdict": "confirmed",
    "reasoning": "Every technical claim was independently confirmed against three reputable, primary sources.\n\n1) Carrier 40kHz (not 38kHz): CONFIRMED. SB-Projects states \"Carrier frequency of 40kHz.\" IRremoteESP8266 ir_Sony.cpp defines `const uint16_t kSonyStdFreq = 40000`. (Note: an alternate sendSony38() at 38kHz exists for some Sony soundbars, but the standard SIRC carrier is 40kHz, matching the claim and contradicting the \"most everything is 38kHz\" pitfall.)\n\n2) Header/start burst 2400us mark + 600us space: CONFIRMED. SB-Projects: start burst \"always 2.4ms wide, followed by a standard space of 0.6ms.\" ir_Sony.cpp uses kSonyTick=200us with header mark = 12 ticks (2400us) and 3-tick (600us) spaces.\n\n3) Pulse-width encoding '1'=1200us mark, '0'=600us mark, each bit followed by 600us space: CONFIRMED. SB-Projects: logical '1' = 1.2ms burst, logical '0' = 0.6ms, all separated by 0.6ms space. ir_Sony.cpp: one=6 ticks (1200us), zero=3 ticks (600us), space=3 ticks (600us).\n\n4) LSB-first, command (7 bits) first then address: CONFIRMED. SB-Projects: \"the LSB is transmitted first... the 7-bit Command is transmitted, followed by the 5-bit Device address.\"\n\n5) Three variants 12/15/20-bit: CONFIRMED. SB-Projects: 12-bit = 7 cmd + 5 addr; 15-bit = 7 cmd + 8 addr; 20-bit = 7 cmd + 5 addr + 8 extended bits \u2014 exact match to the claim. IRremoteESP8266: \"SIRC can be 12, 15, or 20 bits long.\"\n\n6) 45ms start-to-start repeat: CONFIRMED. SB-Projects: \"Commands are repeated every 45ms (measured from start to start) for as long as the key is held down.\"\n\n7) Sony devices require frame sent ~3x: CONFIRMED. IRremoteESP8266 ir_Sony.cpp comment: sendSony() \"should typically be called with repeat=2 as Sony devices expect the message to be sent at least 3 times.\" Independent forum/Ken Shirriff references agree.\n\n8) DVD/BD commonly use 20-bit variant with extended bits: CONFIRMED. Ken Shirriff (righto.com) and electronics forums document Sony DVD remotes using the extra 8 extended bits (21-bit-style frames) as an extended device code; the 20-bit variant is the standard DVD/BD form.\n\nNo corrections needed. None of the listed pitfalls apply: this is a genuine distinct protocol (not generic NEC), carrier is correctly 40kHz (not the 38kHz default), framing is pulse-width PWM (not NEC/Samsung32 distance encoding), and it is not an AC protocol. Verdict: confirmed.",
    "correctedCarrierHz": 40000
   },
   {
    "brand": "Panasonic",
    "protocolName": "Kaseikyo / Panasonic 48-bit",
    "verdict": "confirmed",
    "correctedCarrierHz": 36700,
    "reasoning": "Independently verified against reputable sources. The Panasonic 48-bit protocol is correctly identified as a member of the Kaseikyo family. IRP notation from hifi-remote/JP1 (Kaseikyo wiki) and Arduino-IRremote ir_Kaseikyo.hpp give {37k,432}<1,-1|1,-3>(8,-4,...): base unit 432us, header mark 3456us (8T) + space 1728us (4T), bit mark 432us, '1' space 1296us (3T), '0' space 432us (1T), trailing stop bit. This matches the claim's framing exactly. Pulse-distance encoding, LSB-first, 48 bits = 16-bit vendor ID + parity/genre + device + command + 8-bit XOR checksum is confirmed; the Panasonic vendor variant uses vendor code 0x4004 and the final checksum = XOR of preceding data bytes (device^subdevice^function), matching IRremoteESP8266 ir_Panasonic.cpp sendPanasonic64() (manufacturer 0x4004, checksum = device ^ subdevice ^ function). DVD/Blu-ray remotes use this same Kaseikyo 48-bit framing (LIRC panasonic remote configs), differentiated by device/genre + function fields rather than a separate protocol. This is correctly NOT confused with NEC or Samsung32, and the carrier (~37kHz) is distinctly Panasonic, not Sony's ~40kHz or the common 38kHz. The ONE imprecision: the canonical carrier in the cited IRremoteESP8266 source is kPanasonicFreq = 36700 Hz (36.7 kHz), not exactly 37000 Hz. The claim already hedged this ('37kHz (~36.7kHz)'), and the IRP nominal notation uses {37k}; both are within demodulator tolerance. I set correctedCarrierHz=36700 as the most precise value, but the protocol identification, brand, framing, and structure are all correct, so the verdict is confirmed."
   }
  ]
 },
 {
  "target": "fan-heater",
  "protocols": [
   {
    "brand": "Lasko",
    "kind": "fan (tower/pedestal with IR remote, e.g. models controlled by SamHop SM5021/SM5032 chipset)",
    "protocolName": "Symphony",
    "carrierHz": 38000,
    "frameSummary": "No leader/header pulse at all. 12 data bits sent MSB-first as pulse-distance with SWAPPED mark/space: a '0' bit = ~400us mark + ~1250us space; a '1' bit = ~1250us mark + ~400us space (i.e. ZeroMark=OneSpace=400us, ZeroSpace=OneMark=1250us). Footer gap ~6600us. Whole 12-bit frame is repeated (typ. 2-3 times) with a ~35ms gap. The 12 bits are a single opaque command value per button (power/speed/rotate/timer) - it is NOT an address+command split and NOT a stateful AC frame; each button is one fixed 12-bit code. Verified against derekjhunt's captured Lasko raw arrays (FAN_POWER/FAN_SPEED/FAN_ROTATE/FAN_TIMER): 23 timing entries (12 bits, last bit's trailing space omitted), all values clustering at 400/1250us, kHz=38, sent via irsend.sendRaw - these match the Symphony constants exactly.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Symphony.cpp (kSymphonyZeroMark=400, kSymphonyZeroSpace=1250, kSymphonyOneMark=1250, kSymphonyOneSpace=400, kSymphonyFooterGap=6600, no header) and IRremoteESP8266.h (kSymphonyBits=12, kSymphonyDefaultRepeat=3); concrete Lasko per-button raw codes in github.com/derekjhunt/esp8266_lasko_ir sketch.ino (FAN_POWER={1300,350,1300,400,400,1250,1250,400,...}, FAN_SPEED, FAN_ROTATE, FAN_TIMER; int kHz=38; irsend.sendRaw).",
    "notes": "Lasko is NOT in IRremoteESP8266's official Symphony brand list (which names Symphony/SamHop/Blyss/Westinghouse/SilverCrest/Satellite), but the captured Lasko fan raw timings are unmistakably Symphony (38kHz, no header, 400/1250 swapped marks, 12 bits). To implement: either replay the four captured raw arrays directly, or call sendSymphony() after decoding each array to its 12-bit value. IMPORTANT: this covers Lasko FANS only - Lasko HEATERS are a different protocol (see separate entry)."
   },
   {
    "brand": "Lasko",
    "kind": "space heater (e.g. CC23161 ceramic heater with IR remote)",
    "protocolName": "Custom 64-bit pulse-distance (proprietary, non-standard; not NEC)",
    "carrierHz": 38000,
    "frameSummary": "Leader ~10130us mark + ~4675us space (an NEC-like AGC burst but with non-NEC bit timing). 64 data bits using pulse-distance: bit mark ~700us; '0' = ~700us space, '1' = ~2100us space. Unusual non-standard tail/footer of roughly +2000us mark, -700us space appended after the 64 bits. Decoded as RCSwitch 'Raw protocol 4' style by some users. Each button = one fixed 64-bit command (stateless command device, NOT a full power/temp/mode/fan AC state frame).",
    "publicDataAvailable": true,
    "confidence": "medium",
    "implementability": "partial",
    "source": "Home Assistant / ESPHome community thread 'Help deciphering IR remote codes for Lasko CC23161 space heater' (community.home-assistant.io/t/.../953821) - working power-on raw capture begins '10130,-4675,769,-2075,768,-654,768,-656,...' with the '2000,-700' tail; users explicitly confirmed NEC decode returns nothing because the frame is 64-bit, not NEC's 32-bit.",
    "notes": "Distinct from Lasko fans. NEC explicitly does NOT work. There is no clean published bit-field spec mapping bits->functions; the only reliable path is replaying per-button RAW captures (captured in ESPHome with buffer_size:4096, idle:50000us). Marked 'partial' because real spec/per-button-table is not generalized publicly - you must capture the specific model's buttons, though the timing structure is documented enough to build a raw encoder."
   },
   {
    "brand": "Pelonis",
    "kind": "portable / window air conditioner (e.g. RG51-series remote)",
    "protocolName": "Midea (a.k.a. Coolix-family Midea variant)",
    "carrierHz": 38000,
    "frameSummary": "Midea protocol: ~4480us leader mark + ~4480us leader space. 48-bit data (MIDEA / COOLIX48) sent as pulse-distance: bit mark ~560us; '0' space ~560us, '1' space ~1680us. The 48-bit state is sent, then a footer gap, then the SAME data sent again INVERTED (one's-complement) as an integrity check (this is the signature of the Midea/Coolix split). Full stateful AC frame: dedicated fields for power, mode (auto/cool/dry/heat/fan), temperature (encoded in a lookup/Gray-like table, typ. 17-30C), and fan speed (auto/low/med/high), plus a fixed header/device byte. IRremoteESP8266 provides full encode/decode of every field.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_Midea.cpp + IRMideaAC class (SupportedProtocols.md lists MIDEA/MIDEA24 and COOLIX/COOLIX48; documents RG57-series Midea remotes). Brand attribution: Pelonis is a Midea Group sub-brand (Justia trademark reg. 5286586, Midea Group filing 2014; Midea Group Wikipedia), and Pelonis AC remotes use the Midea RG51/RG57 remote families.",
    "notes": "High confidence by brand ownership + remote-model family (RG51/RG57 = Midea OEM remotes). Implement using IRremoteESP8266's IRMideaAC (setPower/setMode/setTemp/setFan/getRaw). Verify on the specific unit since a few Midea OEM ACs use the COOLIX (24-bit) variant instead of MIDEA (48-bit) - both are in the library. This covers Pelonis AIR CONDITIONERS, which are the IR-remote Pelonis products with a documented protocol."
   },
   {
    "brand": "Pelonis",
    "kind": "fan / fan-heater / tower heater (e.g. PFZ36R0APK, PSHC30RD4BC, PSHF10M1ABB)",
    "protocolName": "Unknown / undocumented (no public protocol identification; likely simple per-button code, possibly NEC or Midea-fan, but unconfirmed)",
    "carrierHz": 38000,
    "frameSummary": "No public bit-level capture or protocol identification could be found for Pelonis FAN/HEATER (non-AC) IR remotes. Only owner's manuals exist, which describe remote functions (power, fan speed, heat level, oscillation, 12hr timer, ECO) but contain zero IR timing/code data. Cannot state leader timing, bit count, or field mapping with any confidence.",
    "publicDataAvailable": false,
    "confidence": "low",
    "implementability": "not-feasible",
    "source": "Pelonis owner's manuals only (e.g. pelonis.com PFZ36R0APK, PSHC30RD4BC, PSHF10M1ABB user manuals) - no IR protocol data. Not present in IRremoteESP8266 SupportedProtocols.md, LIRC remote DB, or IRDB under Pelonis fan/heater.",
    "notes": "Even though Pelonis is Midea-owned (so an AC uses Midea), that does NOT carry over to the cheap fan/heater lines, which typically use a low-cost encoder chip (SamHop/Symphony-style) or generic NEC - but no captured data exists to confirm. Marked not-feasible without a physical capture of the specific model's remote."
   },
   {
    "brand": "Honeywell",
    "kind": "portable air conditioner (e.g. MN/HL-series with IR remote)",
    "protocolName": "Custom pulse-distance AC protocol (proprietary, LSB-first; not NEC, not a named library protocol)",
    "carrierHz": 38000,
    "frameSummary": "Pulse-distance, LSB-first. Every bit is preceded by a fixed-length low (mark) period regardless of value; the bit value is encoded purely by the length of the following HIGH/space period (short space = 0, long space = 1) - i.e. classic space-distance encoding. The frame is a full stateful AC payload: documented code examples vary by temperature level (highest/mid/lowest), by mode (AC / dehumidify / fan-only), and by timer setting, so bit fields for mode, temperature and timer are isolatable from the captured code table. Exact leader timing and total bit count are shown on the source page's timing diagrams but are non-standard (not NEC's 9000/4500).",
    "publicDataAvailable": true,
    "confidence": "medium",
    "implementability": "partial",
    "source": "Eleccelerator Wiki 'Honeywell Portable Air Conditioner Infrared Codes' (eleccelerator.com/wiki/index.php/Honeywell_Portable_Air_Conditioner_Infrared_Codes) - documents LSB-first bit encoding, timing diagrams, and per-setting code examples for AC/dehumidify/fan-only modes and temperature levels.",
    "notes": "Real captured codes and bit-encoding scheme are public, and the mode/temp/timer fields can be reverse-engineered from the documented examples, but there is NO complete normalized field spec the way IRremoteESP8266 provides for Midea/Gree. Marked 'partial': structure is known, a raw encoder can be built from the documented examples, but a full clean per-field encoder requires assembling the bit table from the Eleccelerator examples (or capturing the target model). Not a named protocol in IRremoteESP8266/LIRC."
   },
   {
    "brand": "Honeywell",
    "kind": "fan (e.g. handheld/mag-mount remote tower & oscillating fans)",
    "protocolName": "Custom space-encoded protocol (~636us mark, pulse-distance; not NEC)",
    "carrierHz": 38000,
    "frameSummary": "Pulse-distance / space-encoded with a constant short mark of ~636us. Bit value set by the following space: '0' = ~636us mark + ~642us space; '1' = ~636us mark + ~1914us space (long-space = 1). Captured ON/SPEED example: '+636 -1914 +636 -1914 +1908 -642 +1908 -642 +636 -1914 ...' (note some entries show ~1908us marks too, suggesting a few combined/merged symbols in the raw capture). Each button (ON/SPEED, OFF, etc.) is a single fixed command word, NOT a stateful AC frame. Total bit count not cleanly published.",
    "publicDataAvailable": true,
    "confidence": "low",
    "implementability": "partial",
    "source": "JP1 Remotes / hifi-remote.com forum thread 'Honeywell fan' (hifi-remote.com/forums viewtopic t=2900) - raw captures 'ON/SPEED: +636 -1914 +636 -1914 +1908 -642 ...' and OFF command; a user (Jon Armstrong) reportedly decoded it into a JP1 Protocol Builder upgrade, but the named protocol/device-subdevice is not published in the visible thread.",
    "notes": "Honeywell makes both ceiling-fan RF remotes (model 40012, NOT IR - radio) and IR tabletop/tower fans. This entry is the IR tabletop/tower fan. It is clearly NOT NEC (no 9000/4500 leader, mark is ~636us not NEC's 560us, and spacing pattern differs). Implementable only by RAW replay of captured per-button codes; the full protocol/bit-table is in a JP1 file that was not retrievable. Marked low confidence / partial."
   },
   {
    "brand": "Generic (NEC)",
    "kind": "fan / heater using the standard NEC IR protocol",
    "protocolName": "NEC",
    "carrierHz": 38000,
    "frameSummary": "Leader: 9000us mark + 4500us space. Then 32 bits, LSB-first, pulse-distance: bit mark ~560us; '0' space ~560us, '1' space ~1690us. The 32 bits = 8-bit address + 8-bit inverted address + 8-bit command + 8-bit inverted command (the inversions are the integrity check). Final ~560us mark closes the frame. Repeats (button held) are a special short frame: 9000us mark + 2250us space + 560us mark, sent every ~110ms. Extended NEC variant uses a full 16-bit address (drops the address-inversion check) + 8-bit command + inverted command. For a fan/heater this means each button is one fixed (address,command) pair - stateless, NOT an AC state frame.",
    "publicDataAvailable": true,
    "confidence": "high",
    "implementability": "ready",
    "source": "IRremoteESP8266 src/ir_NEC.cpp (sendNEC/encodeNEC: kNecHdrMark=9000, kNecHdrSpace=4500, kNecBitMark=560, kNecOneSpace=1690, kNecZeroSpace=560, kNecBits=32); SB-Projects NEC protocol spec (sbprojects.net/knowledge/ir/nec.php); per-device address/command codes crowd-sourced in IRDB (github.com/probonopd/irdb, CSV rows 'function,protocol=NEC1,device,subdevice,function').",
    "notes": "Fully ready: encode via sendNEC(address,command) or build the 32-bit value yourself. The ONLY missing piece for any specific generic device is the actual per-button address/command bytes, which must come from IRDB or a capture - but the protocol/encoder itself is completely specified. Use this path for any fan/heater confirmed to be plain NEC; do not assume a device is NEC without verifying (Lasko fans=Symphony, Lasko heaters=custom 64-bit, Honeywell=custom space-encoded - none of these are NEC)."
   }
  ],
  "verdicts": [
   {
    "brand": "Lasko",
    "protocolName": "Symphony",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Every load-bearing detail of the claim was independently verified against the cited reputable sources.\n\n1) IRremoteESP8266 src/ir_Symphony.cpp (crankyoldgit master) confirms: kSymphonyZeroMark=400us, kSymphonyZeroSpace=1250us, kSymphonyOneMark=1250us (=ZeroSpace), kSymphonyOneSpace=400us (=ZeroMark), kSymphonyFooterGap=6600us (=4*(400+1250)). The decode explicitly uses \"No Header\" in matchGenericConstBitTime, confirming there is NO leader/header pulse. This is the swapped mark/space pulse-distance scheme described (a '0' = short mark + long space; a '1' = long mark + short space).\n\n2) IRremoteESP8266.h confirms kSymphonyBits=12 and kSymphonyDefaultRepeat=3, matching the \"12 data bits, repeated ~3 times\" claim. (Header carries no per-protocol carrier constant; the library default 38kHz applies and is corroborated by the Lasko sketch.)\n\n3) derekjhunt/esp8266_lasko_ir sketch.ino confirms the concrete Lasko per-button raw arrays FAN_POWER/FAN_SPEED/FAN_ROTATE/FAN_TIMER each have 23 timing entries (= 12 bits with the final trailing space omitted), values cluster bimodally at ~400us and ~1250us, int kHz=38, and they are transmitted via irsend.sendRaw. These raw timings match the Symphony constants exactly.\n\nThe 12 bits are a single opaque fixed code per button (the sketch stores one raw array per button), consistent with the claim that this is NOT an address+command split and NOT a stateful AC frame. No NEC/Samsung32 confusion applies (this is a distinct headerless 12-bit const-bit-time protocol, not 32-bit NEC framing), and the 38kHz carrier is correct (not Panasonic's ~37kHz or Sony's ~40kHz). All checks pass; the claim is confirmed verbatim."
   },
   {
    "brand": "Lasko",
    "protocolName": "Custom 64-bit pulse-distance (proprietary, non-standard; not NEC)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independently verified against the exact cited source: Home Assistant / ESPHome community thread \"Help deciphering IR remote codes for Lasko CC23161 space heater\" (community.home-assistant.io/t/.../953821). Every specific claim matches the captured data in that thread: (1) Leader/AGC burst of ~10130us mark + ~4675us space (forum shows \"10130, 4675\" / \"10133, 4675\") - an NEC-like AGC burst; (2) bit mark ~700us (captures show 769/768); (3) '0' = ~700us space, '1' = ~2100us space (expert decoder Karosm: \"700, -700 is zero and 700, -2100 is one\"); (4) the unusual non-standard tail/footer \"2000, -700\" (Karosm: \"uncommon tail at the end 2000, -700\"); (5) 64 data bits; (6) 38kHz carrier; (7) NEC decode explicitly returns nothing (\"dump: nec\" produced no results) precisely because the frame is 64-bit rather than NEC's 32-bit; (8) stateless per-button fixed commands rather than a parametric power/temp/mode/fan AC state frame (forum: sends discrete values requiring individual raw codes per setting). Adversarial cross-checks all pass: carrier is correctly 38kHz (not Sony ~40kHz or Panasonic ~37kHz); it is genuinely NOT generic NEC (NEC decode fails, 64-bit length and non-NEC bit/footer timing); and it is not an AC Coolix/Midea-family state frame. This is a stateless command device with a genuinely non-standard proprietary pulse-distance encoding. A second independent repo (phillipgreenii/irremote-signals-lasko-heater-6350) corroborates the family's need to raise the IR library gap threshold to 50000us due to \"long pauses,\" consistent with the ~2100us '1' spaces and idle tail. Claim confirmed."
   },
   {
    "brand": "Pelonis",
    "protocolName": "Midea (a.k.a. Coolix-family Midea variant)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Independently confirmed on every point.\n\n1) Carrier/framing: IRremoteESP8266's ir_Midea.cpp (via the official Doxygen reference) lists the exact timing constants claimed: header mark 4480us, header space 4480us, bit mark 560us, '0' space 560us, '1' space 1680us (each expressed as tick-based values: 56/56/7/7/21 ticks x 80us). The 38kHz carrier is corroborated by multiple Midea reverse-engineering sources (e.g. Matthew Petroff's decoding writeup and sheinz/esp-midea-ir), which describe a 38kHz carrier with ~1.1ms time base, start pulse, six data bytes, a middle/footer pulse, then the inverse of the six data bytes. This matches the claimed 48-bit pulse-distance MIDEA/COOLIX48 frame sent then re-sent inverted (one's-complement) as an integrity check.\n\n2) Stateful AC model: Confirmed that Midea encodes full system state (power, mode, temperature, fan) per transmission rather than discrete key commands \u2014 consistent with the IRMideaAC stateful encode/decode description. The inverted-copy redundancy is the documented Midea/Coolix signature, distinct from plain NEC.\n\n3) Brand attribution: Confirmed Pelonis AC remotes are in the Midea RG51 remote family. Anderic lists Pelonis OEM remotes RG51G(1)/EFU1 and RG51G(1)/CEFU1 (window/portable AC), and the RG51A/B series are standard Midea remotes. Pelonis is a Midea Group sub-brand. This is not an NEC/Samsung32 confusion case and the carrier is correctly 38kHz (not Panasonic 37kHz or Sony 40kHz).\n\nNo corrections needed; the protocol is correctly identified as the Midea (Coolix-family) variant at 38kHz, not generic NEC."
   },
   {
    "brand": "Honeywell",
    "protocolName": "Custom pulse-distance AC protocol (proprietary, LSB-first; not NEC, not a named library protocol)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "Independent web searches located the cited source (Eleccelerator Wiki, \"Honeywell Portable Air Conditioner Infrared Codes\", documenting the Honeywell MM14CCSBB/MM14CCS portable AC) and corroborated every load-bearing element of the claim:\n\n1. Bit ordering: The page explicitly states the code \"appears to be LSB first.\" -> matches claim.\n\n2. Encoding scheme: It states \"All bits are preceded by a low period of the same length regardless of whether the bit is 0 or 1, with the bit indicated by the length of the high period following - short means 0 and long means 1.\" This is exactly classic space-distance / pulse-distance encoding as described in the claim (fixed mark, value encoded purely by the trailing space length). -> matches claim.\n\n3. Stateful AC payload with isolatable fields: The page provides per-setting code tables varying by temperature (highest/mid/lowest), mode (AC / dehumidify / fan-only), and timer. -> matches claim.\n\n4. Carrier: 38 kHz, the standard IR AC carrier, consistent with the demodulating-receiver capture described and with the 'most else 38kHz' rule. No evidence of Panasonic ~37kHz or Sony ~40kHz. -> matches claimed 38000 Hz.\n\n5. Proprietary, not a named library protocol: The framing (non-standard leader, full multi-byte AC state payload, LSB-first space-distance) is consistent with a proprietary AC protocol, not generic NEC (which is a short command/address frame) and not Samsung32. Common-mistake checks (NEC-vs-Samsung32 confusion, wrong carrier, mislabeling generic NEC, Midea/Coolix) do not apply here - this is a documented per-vendor AC payload, not a stateless remote.\n\nThe only detail not independently re-derived from raw numbers is the exact leader timing and total bit count, which the source presents in an image (Media:Honeywellacircode.png) timing diagram rather than searchable text; the claim itself acknowledges these are non-standard (not NEC 9000/4500), which is consistent with a proprietary AC protocol and does not contradict any verified fact. Verdict: confirmed."
   },
   {
    "brand": "Honeywell",
    "protocolName": "Custom space-encoded protocol (~636us mark, pulse-distance; not NEC)",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "correctedProtocol": "",
    "reasoning": "I located and fetched the exact cited source, the JP1/hifi-remote.com forum thread 'Honeywell fan' (viewtopic t=2900), plus a related decode thread (p=148533). The raw ON/SPEED capture in the thread matches the claim line-for-line: '+636 -1914 +636 -1914 +1908 -642 +1908 -642 +636 -1914 ...' ending in '+636 -22316' (the ~22316us lead-out gap). This confirms a pulse-distance / space-encoded frame with a constant short mark (~636us) where the FOLLOWING space sets the bit: '0' = ~636us mark + ~642us space, '1' = ~636us mark + ~1914us space (long-space = 1). The occasional ~1908us marks in the raw capture are merged/combined adjacent symbols in the learned signal, exactly as the researcher noted. This framing is NOT NEC: NEC uses a 9000us/4500us lead-in burst pair and a fixed 562us pulse with PWM-by-space yielding a structured 32-bit addr/cmd word with logical inverses; this Honeywell capture shows neither the NEC AGC header nor NEC bit structure, and the JP1 thread treats it as a non-standard fan protocol requiring a custom Protocol Builder / KeyMaster upgrade (Jon Armstrong / mdavej), not the built-in NEC protocol. Each button is a single fixed command word, not a stateful AC frame \u2014 consistent with the claim and ruling out AC-protocol confusion (Coolix/Midea/etc.). Carrier: 38000Hz is the standard, expected value for this learned-fan style and is consistent across the JP1 community discussion; there is no evidence of Sony-style 40kHz or Panasonic ~37kHz here, so 38kHz stands. Minor enrichment (not a correction to the core technical claim): the related decode thread names the working JP1 protocol 'Amaxon Fan' (an Amazon/Intertek-sourced fan controller family), and notes the auto-decoder initially mis-detected it (same EFC, differing Device/Sub-Device) \u2014 corroborating that it is a distinct custom protocol rather than generic NEC. The core claim (custom space-encoded pulse-distance, ~636us mark, short-space=0/long-space=1, not NEC, 38kHz, fixed single-word commands) is independently confirmed from the primary source."
   },
   {
    "brand": "Generic (NEC)",
    "protocolName": "NEC",
    "verdict": "confirmed",
    "correctedCarrierHz": 38000,
    "reasoning": "Every detail of the claim is independently corroborated by two reputable sources.\n\n1) Carrier 38kHz: SB-Projects NEC page states \"Carrier frequency of 38kHz\" verbatim; IRremoteESP8266 ir_NEC.cpp calls sendGeneric() with 38kHz. Confirmed. This correctly distinguishes NEC from Sony (~40kHz) and Panasonic (~37kHz).\n\n2) Frame timing: SB-Projects confirms 9ms AGC mark + 4.5ms space leader, 560us bit mark, 560us '0' space, 1.69ms '1' space, 2.25ms logical-'1' total / 1.125ms logical-'0' total. IRremoteESP8266 defines the same as tick multiples: kNecTick=560, kNecHdrMark=16 ticks (8960, canonical 9000), kNecHdrSpace=8 ticks (4480, canonical 4500), kNecBitMark=560, kNecOneSpace=1680 (canonical 1690), kNecZeroSpace=560, kNecBits=32. The small 8960/9000 and 1680/1690 differences are merely tick-rounded vs spec-rounded representations of the same protocol \u2014 not a different protocol. Confirmed.\n\n3) 32-bit structure LSB-first: SB-Projects confirms \"the LSB is transmitted first\" and \"Address and Command are transmitted twice. The second time all bits are inverted,\" i.e. 8-bit addr + inverted addr + 8-bit cmd + inverted cmd, the inversions serving as the integrity check. Confirmed.\n\n4) Repeat frame: SB-Projects confirms repeat code = 9ms AGC pulse + 2.25ms space + 560us burst, sent every 110ms. IRremoteESP8266 corroborates with kNecRptSpace=2240us (4 ticks ~ 2.25ms) and kNecMinCommandLength=108080us (~110ms). Confirmed.\n\n5) Extended NEC: SB-Projects confirms the address range \"was extended from 8 bits to 16 bits\" by sacrificing the address-redundancy (inversion) check while keeping command redundancy. Confirmed.\n\n6) Stateless fan/heater semantics: Correct. Generic NEC remotes emit one fixed (address,command) pair per button \u2014 unlike stateful AC protocols that encode full machine state in long frames. The claim's contrast that Midea AC uses Coolix-family (not NEC) is also accurate per IRremoteESP8266.\n\nNo mistakes from the watch-list apply: not confused with Samsung32 (Samsung uses different 4500/4500 header framing despite 38kHz), carrier is correctly 38kHz, and the device is correctly typed as generic NEC rather than a distinct or AC-state protocol. The claim is accurate as stated."
   }
  ]
 }
]
```
