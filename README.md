# Lift HDL Model — Verification Project

Proiect de verificare functionala pentru un sistem de lift cu interfata APB si REQ/ACK, implementat in SystemVerilog si simulat in Vivado 2024.2.

---

## Structura proiectului

```
testbench.sv              ← Top-level testbench (singurul fisier adaugat in Vivado)
│
├── apb_interface.sv      ← Interfata APB (cu assertiuni protocol)
├── req_ack_interface.sv  ← Interfata REQ/ACK butoane + LED-uri (cu assertiuni)
├── output_interface.sv   ← Interfata iesiri lift
│
├── design.sv             ← Top DUT
│   └── lift_apb.v        ← Wrapper APB in jurul liftului
│       └── lift.v        ← Logica principala lift (FSM)
│
└── test_change_direction.sv   ← Testul activ (schimbare directie)
    └── environment.sv         ← Environment complet
        ├── apb_driver.sv / apb_transaction.sv / generator_apb.sv
        ├── button_driver.sv / button_transaction.sv / button_generator.sv
        ├── monitor_apb.sv / monitor_out.sv / button_monitor.sv
        ├── apb_coverage.sv / coverage_out.sv
        ├── transaction_out.sv
        └── scoreboard.sv
```

---

## Cum rulezi simularea in Vivado

### Pas 1 — Cloneaza repository-ul
```bash
git clone https://github.com/sauleamihai/Lift_HDL_model.git
```

### Pas 2 — Creeaza un proiect nou in Vivado
1. Deschide **Vivado 2024.2**
2. **Create Project** → Next
3. Nume proiect (ex: `Lift_Sim`), alege locatia → Next
4. **RTL Project** → bifa **"Do not specify sources at this time"** → Next
5. Alege orice parte (ex: `xc7a35tcpg236-1`) → Next → **Finish**

### Pas 3 — Adauga sursa de simulare
1. In panoul **Sources** → click **"+"**
2. **Add or create simulation sources** → Next
3. **Add Files** → naviga la folderul clonat → selecteaza **DOAR** `testbench.sv`
4. **NU** bifa "Copy sources into project"
5. **Finish**

### Pas 4 — Seteaza top module
- In **Sources → Simulation Sources**: `testbench` ar trebui sa fie deja top
- Daca nu: click dreapta pe `testbench` → **Set as Top**

### Pas 5 — Ruleaza simularea
- **Flow Navigator → Run Simulation → Run Behavioral Simulation**

---

## Configuratie waveform (recomandat)

Fisierul `waves/lift_waves.wcfg` contine toate semnalele importante pre-configurate.

### Metoda 1 — Incarcare automata (cea mai simpla)
1. Dupa ce simularea porneste, in **TCL Console** (jos in Vivado) scrie:
```tcl
open_wave_config {C:/calea/ta/Lift_HDL_model/waves/lift_waves.wcfg}
```
Inlocuieste `C:/calea/ta/` cu calea unde ai clonat repo-ul.

### Metoda 2 — Adaugare in proiect (se incarca automat la fiecare simulare)
1. **Sources** → click **"+"** → **Add or create simulation sources**
2. **Add Files** → naviga la `waves/` → selecteaza `lift_waves.wcfg`
3. Click **Finish** — Vivado il va incarca automat de acum inainte

### Metoda 3 — Din meniul Vivado
1. In fereastra waveform → **File → Open Waveform Configuration**
2. Naviga la `waves/lift_waves.wcfg`

---

## Semnale incluse in waveform

Fisierul `.wcfg` contine deja toate semnalele relevante:

```
testbench/DUT/u_lift_apb/u_lift/
    ├── current_floor_reg[2:0]   ← etajul curent (0-7)
    ├── state[1:0]               ← 0=IDLE, 1=MOVE, 2=DOOR_OPEN, 3=STOP
    ├── destination[2:0]         ← etajul destinatie
    ├── direction                ← 1=UP, 0=DOWN
    ├── request_reg[7:0]         ← cereri active (bitmask)
    └── pending_count[3:0]       ← numarul de cereri in asteptare

testbench/
    ├── req_ack_intf/buton_lift[7:0]    ← REQ din cabina
    ├── req_ack_intf/buton_scara[7:0]   ← REQ de pe scara
    ├── req_ack_intf/led_lift[7:0]      ← ACK cabina (LED)
    ├── req_ack_intf/led_scara[7:0]     ← ACK scara (LED)
    ├── output_intf/floor_management[7:0]
    └── output_intf/various_signals[7:0]
```

**Decodare `floor_management[7:0]`:**
| Biti | Semnificatie |
|------|-------------|
| `[7:5]` | Etajul curent |
| `[4:2]` | Ultimul etaj servit |
| `[1]` | Error flag |
| `[0]` | Usa deschisa |

---

## Testele disponibile

| Fisier | Descriere |
|--------|-----------|
| `test_change_direction.sv` | **Activ** — Lift chemat la etaj 4, apoi cerere etaj 1 din cabina. Verifica schimbarea directiei. |
| `random_test.sv` | Tranzactii APB si butoane generate aleatoriu |

### Cum schimbi testul activ
In `testbench.sv`, linia:
```systemverilog
`include "test_change_direction.sv"
```
Inlocuieste cu:
```systemverilog
`include "random_test.sv"
```

---

## Interfete si protocoale

### APB (Advanced Peripheral Bus)
- Adresa `0x00` — scrie `buton_scara` (bitmask etaje)
- Adresa `0x01` — scrie `buton_lift` (bitmask etaje)
- Adresa `0x02` — citeste `various_signals`
- Adresa `0x03` — citeste `floor_management`
- Adresa `0x04` — citeste `led_lift`
- Adresa `0x05` — citeste `led_scara`

### REQ/ACK
- **REQ**: `buton_lift[i]` sau `buton_scara[i]` = 1 → cerere etaj `i`
- **ACK tip A**: `led_lift[i]` / `led_scara[i]` se aprinde imediat (confirmare inregistrare)
- **ACK tip C**: LED-ul se stinge cand liftul ajunge la etajul `i` si usa se deschide

---

## Assertiuni implementate

### APB (`apb_interface.sv`)
- PENABLE urmeaza PSEL cu 1 ciclu
- PENABLE activ doar cand PSEL activ
- PWRITE/PADDR stabile pe durata transferului
- PENABLE se dezactiveaza dupa PREADY

### REQ/ACK (`req_ack_interface.sv`)
- LED aprins in 1 ciclu dupa apasarea butonului
- Niciun etaj cerut simultan din cabina si de pe scara
- LED-uri stinse in timpul resetului
- Maxim un etaj cerut odata (one-hot)
