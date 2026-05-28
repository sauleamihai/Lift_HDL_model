`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __scoreboard
`define __scoreboard

// ═══════════════════════════════════════════════════════════════════════════
//  COMPONENTA: scoreboard
//  ROL       : Modelul de referinta al mediului UVM. Primeste tranzactii de
//              la TOATE cele trei monitoare (APB, REQ/ACK, Iesire) si decide
//              daca DUT-ul se comporta conform specificatiilor.
//
//  FILOSOFIA VERIFICARII PE 3 NIVELURI:
//    1. Asertiuni SVA (in interfete)      → verifica protocoalele la nivel
//                                            de CICLU (ce semnal cand)
//    2. Coverage (covergroups in agenti)  → masoara EXHAUSTIVITATEA
//                                            (cat din functionalitate a fost
//                                            stimulat)
//    3. Scoreboard (acest fisier)         → verifica CORECTITUDINEA end-to-end
//                                            (intrari → iesiri se potrivesc?)
//
//  CELE 5 NIVELURI DE VERIFICARE IMPLEMENTATE AICI:
//    A. Sanity checks       → etaj valid 0-7, bit 7 LED stins, door consistent
//    B. Shadow registers    → model de referinta pentru R/W (echo check)
//    C. Timing REQ/ACK      → latente ACK conform protocolului (≤1 ciclu)
//    D. Tracker URGENTA     → FSM intern care urmareste ciclul de viata al
//                              starii de urgenta (start → coborare → eliberare)
//    E. Cross-checks APB↔IO → scriere buton APB ⇒ LED corespunzator aprins
//
//  PLUS: Statistici functionale (etaje vizitate, max pending, etc.) afisate
//        in report_phase pentru o privire de ansamblu asupra testului.
//
//  FLUX DE DATE:
//
//    ┌─────────────┐     ┌─────────────┐     ┌──────────────┐
//    │ Monitor APB │     │ Monitor R/A │     │ Monitor Iesire│
//    └──────┬──────┘     └──────┬──────┘     └──────┬────────┘
//           │ tranzactie_apb     │ tranzactie_       │ tranzactie_iesire
//           │                    │ req_ack           │
//           ▼                    ▼                   ▼
//    ┌──────────────────────────────────────────────────────────┐
//    │  port_apb       port_req_ack       port_iesire           │
//    │     │                │                  │                 │
//    │     ▼                ▼                  ▼                 │
//    │  write_apb()    write_req_ack()    write_iesire()        │
//    │     │                │                  │                 │
//    │     ├────► coada_apb (history)          │                 │
//    │     ├────► shadow_buton_*_reg (mirror)  │                 │
//    │     └────► verifica_consistenta_apb_iesire(tr) ◄──────────┤
//    │                                         │                 │
//    │                                         └─► coada_iesire  │
//    │                                            (history)      │
//    │                                                           │
//    │   La sfarsit: report_phase() → Tabel cu statistici PASS/FAIL│
//    └──────────────────────────────────────────────────────────┘
// ═══════════════════════════════════════════════════════════════════════════

// ── Macro-uri pentru porturi de analiza multiple ─────────────────────────
// uvm_analysis_imp_decl(<sufix>) creeaza un tip distinct de analysis_imp
// cu numele uvm_analysis_imp_<sufix>. E necesar pentru ca UVM nu permite
// mai multe porturi de acelasi tip in aceeasi clasa.
//
// Cand un monitor face port.write(tr), UVM apeleaza automat metoda
// "write_<sufix>" din scoreboard (callback automat).
//   _apb     → port_apb.write(tr)     → scoreboard.write_apb(tr)
//   _req_ack → port_req_ack.write(tr) → scoreboard.write_req_ack(tr)
//   _iesire  → port_iesire.write(tr)  → scoreboard.write_iesire(tr)
`uvm_analysis_imp_decl(_apb)
`uvm_analysis_imp_decl(_req_ack)
`uvm_analysis_imp_decl(_iesire)

class scoreboard extends uvm_scoreboard;

  `uvm_component_utils(scoreboard)

  // ═══════════════════════════════════════════════════════════════════
  //  SECTIUNEA 1: PORTURI DE INTRARE (cate unul per agent)
  // ═══════════════════════════════════════════════════════════════════
  // Fiecare port primeste un TIP SPECIFIC de tranzactie de la monitorul
  // corespunzator. Tipurile generice: uvm_analysis_imp_<sufix>#(T, parent)
  uvm_analysis_imp_apb     #(tranzactie_apb,     scoreboard) port_pentru_datele_de_la_apb;
  uvm_analysis_imp_req_ack #(tranzactie_req_ack, scoreboard) port_pentru_datele_de_la_req_ack;
  uvm_analysis_imp_iesire  #(tranzactie_iesire,  scoreboard) port_pentru_datele_de_la_iesire;

  // ═══════════════════════════════════════════════════════════════════
  //  SECTIUNEA 2: SNAPSHOTS — ultima tranzactie primita per interfata
  // ═══════════════════════════════════════════════════════════════════
  // Pastram o copie a celei mai recente tranzactii pentru acces rapid
  // in cross-checks (de exemplu: la o scriere APB, vrem ultima iesire).
  tranzactie_apb     ultima_tranzactie_apb;
  tranzactie_req_ack ultima_tranzactie_req_ack;
  tranzactie_iesire  ultima_tranzactie_iesire;

  // ═══════════════════════════════════════════════════════════════════
  //  SECTIUNEA 3: ISTORICUL — cozi pentru analize temporale
  // ═══════════════════════════════════════════════════════════════════
  // SystemVerilog queue: tip[$] — array dinamic cu push_back/pop_front.
  // Util pentru:
  //   - Verificari incrucisate (cauta o tranzactie din alt agent)
  //   - Statistici finale (cate tranzactii au fost)
  //   - Debug post-mortem (ce s-a intamplat inainte de eroare)
  tranzactie_apb     coada_apb[$];
  tranzactie_req_ack coada_req_ack[$];
  tranzactie_iesire  coada_iesire[$];

  // ═══════════════════════════════════════════════════════════════════
  //  SECTIUNEA 4: CONTOARE pentru raport
  // ═══════════════════════════════════════════════════════════════════
  int erori_detectate;    // criteriu PASS/FAIL — 0 = trecut
  int verificari_trecute; // indicator de incredere — cu cat mai mare, mai bine

  // ═══════════════════════════════════════════════════════════════════
  //  SECTIUNEA 5: SHADOW REGISTERS — Model de referinta pentru R/W
  // ═══════════════════════════════════════════════════════════════════
  // CONCEPT: pentru fiecare registru R/W din DUT (0x00 si 0x01), tinem
  // o COPIE LOCALA care reflecta ultima scriere observata pe APB.
  //
  // VERIFICARE: la fiecare CITIRE, comparam PRDATA cu shadow-ul. Daca
  // nu se potrivesc, am gasit o regresie:
  //   - DUT coruptie registru
  //   - Bug timing PRDATA (gen "1 ciclu intarziere")
  //   - Decoder de adresa stricat
  //
  // FLAG-uri de initializare: la inceputul testului registrele DUT-ului
  // sunt 0x00 (reset), dar nu am observat inca o scriere. Daca am compara
  // PRDATA cu shadow=0 fara sa stim ca s-a scris vreodata, am putea da
  // erori false. De aceea verificam abia DUPA prima scriere observata.
  bit [7:0] shadow_buton_scara_reg;
  bit [7:0] shadow_buton_lift_reg;
  bit       shadow_scara_initializat;  // 1 = am observat cel putin o scriere
  bit       shadow_lift_initializat;

  // ═══════════════════════════════════════════════════════════════════
  //  SECTIUNEA 6: TRACKER URGENTA — Mini-FSM pentru test_urgenta
  // ═══════════════════════════════════════════════════════════════════
  // Aceasta sectiune implementeaza un automat cu 3 stari care urmareste
  // ciclul de viata complet al unei urgente:
  //
  //   ┌──────────────────────┐
  //   │  in_urgenta = 0      │
  //   │  (NORMAL — astept)   │
  //   └────────────┬─────────┘
  //                │ Detectez: various_signals[1] tocmai a urcat (front)
  //                ▼
  //   ┌─────────────────────────────────┐
  //   │  STATE 1: START                 │
  //   │  - salvez etajul de start       │
  //   │  - resetez timer cicli          │
  //   │  - marchez deja-la-0? (rar dar  │
  //   │    posibil daca urgenta apare   │
  //   │    chiar la parter)             │
  //   │  - in_urgenta = 1               │
  //   │  - incrementez contor urgente   │
  //   └────────────┬────────────────────┘
  //                │ Urgenta continua (emerg = 1)
  //                ▼
  //   ┌─────────────────────────────────┐
  //   │  STATE 2: TRACKING              │
  //   │  - cicli_in_urgenta++           │
  //   │  - daca etaj_curent==0:         │
  //   │      a_atins_etaj_0 = 1         │
  //   │  - daca cicli > limita (200):   │
  //   │      ERROR "blocat" + reset     │
  //   └────────────┬────────────────────┘
  //                │ Urgenta s-a eliberat (emerg = 0)
  //                ▼
  //   ┌─────────────────────────────────┐
  //   │  STATE 3: VALIDATION            │
  //   │  Verific cele 2 contracte ale   │
  //   │  unei urgente corecte:          │
  //   │    a) liftul A ATINS etaj 0     │
  //   │    b) pending_count = 0 la final│
  //   │  Daca DA → verificari_trecute++ │
  //   │  Daca NU → erori_detectate++    │
  //   │  Reset: in_urgenta = 0          │
  //   └─────────────────────────────────┘
  //
  // De ce e mai puternic decat asertiunile SVA?
  // SVA prinde daca pending != 0 in fereastra de 100 cicluri, dar NU
  // spune "de ce". Scoreboard-ul ofera CONTEXT:
  //   "URGENTA #1 activata la etajul 6, eliberata dupa 35 tranzactii"
  bit       in_urgenta;                  // suntem in starea de urgenta?
  int       cicli_in_urgenta;            // tranzactii scurse de la activare
  int       max_cicli_in_urgenta = 200;  // limita superioara (timeout)
  bit       a_atins_etaj_0_in_urgenta;   // liftul a atins etaj 0 in timpul urgentei?
  bit [2:0] etaj_la_inceput_urgenta;     // unde era liftul cand a inceput
  int       numar_urgente_detectate;     // contor pentru raport

  // ═══════════════════════════════════════════════════════════════════
  //  SECTIUNEA 7: STATISTICI GLOBALE pentru raport functional
  // ═══════════════════════════════════════════════════════════════════
  // Aceste metrici complementeaza coverage-ul oferind o perspectiva
  // CALITATIVA asupra comportamentului liftului:
  //   - Cate etaje a vizitat? (coverage functional)
  //   - Care e nivelul de stress maxim atins? (max pending)
  //   - Cate cereri a servit? (deschideri usa)
  //   - Cate urgente au fost declansate? (validare test_urgenta)
  bit [2:0] ultim_etaj_vizitat;          // pentru detectarea schimbarilor
  bit       primul_tranzactie_iesire;    // flag pentru initializare lazy
  int       max_pending_observat;        // peak pentru stress level
  bit [7:0] etaje_vizitate_mask;         // bit N = 1 daca etajul N a fost vizitat
  int       numar_deschideri_usa;        // contor pentru cereri servite
  int       numar_tranzactii_apb_read;   // profil trafic
  int       numar_tranzactii_apb_write;

  // ═══════════════════════════════════════════════════════════════════
  //  CONSTRUCTOR — apelat la `create()`, inainte de orice faza UVM
  // ═══════════════════════════════════════════════════════════════════
  // Aici facem 2 lucruri:
  //  1. Cream porturile de analiza (new() cu numele si parintele)
  //  2. Initializam variabilele de stare interne la valori sigure
  //
  // Atentie: NU se creeaza componente UVM aici — alea se cresc in build_phase.
  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
    port_pentru_datele_de_la_apb     = new("port_apb",     this);
    port_pentru_datele_de_la_req_ack = new("port_req_ack", this);
    port_pentru_datele_de_la_iesire  = new("port_iesire",  this);
    erori_detectate   = 0;
    verificari_trecute = 0;
    shadow_buton_scara_reg   = 8'h00;
    shadow_buton_lift_reg    = 8'h00;
    shadow_scara_initializat = 1'b0;
    shadow_lift_initializat  = 1'b0;
    in_urgenta                = 1'b0;
    cicli_in_urgenta          = 0;
    a_atins_etaj_0_in_urgenta = 1'b0;
    etaj_la_inceput_urgenta   = 3'd0;
    numar_urgente_detectate   = 0;
    ultim_etaj_vizitat        = 3'd0;
    primul_tranzactie_iesire  = 1'b1;
    max_pending_observat      = 0;
    etaje_vizitate_mask       = 8'h00;
    numar_deschideri_usa      = 0;
    numar_tranzactii_apb_read = 0;
    numar_tranzactii_apb_write = 0;
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  build_phase — Creem aici obiectele "dinamice" (transaction handles)
  // ═══════════════════════════════════════════════════════════════════
  // Folosim type_id::create() pentru a beneficia de UVM factory:
  // testul poate sa "override" tipul si sa schimbe ce tranzactie e folosita
  // fara sa modificam scoreboard-ul.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ultima_tranzactie_apb     = tranzactie_apb::type_id::create("ultima_apb");
    ultima_tranzactie_req_ack = tranzactie_req_ack::type_id::create("ultima_req_ack");
    ultima_tranzactie_iesire  = tranzactie_iesire::type_id::create("ultima_iesire");
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  HANDLER 1: write_apb — Primim tranzactie de la monitorul APB
  // ═══════════════════════════════════════════════════════════════════
  // Apelat AUTOMAT cand monitorul APB face port.write(tr).
  // Tranzactia contine: addr (8b), data (8b), rw (1b).
  //
  // Pasi efectuati:
  //   1. Salvam in istoric (coada + snapshot)
  //   2. Verificare: nu se scrie la adrese RO
  //   3. Numarare pentru statistici (read vs write)
  //   4. La SCRIERE: actualizam shadow-ul (model de referinta)
  //   5. La CITIRE: verificam PRDATA (echo check + addr invalida)
  //   6. Cross-check cu ultima iesire (LED-ul reflecta cererea?)
  function void write_apb(input tranzactie_apb tr);
    `uvm_info("SCOREBOARD", "Tranzactie APB primita:", UVM_HIGH)
    tr.afiseaza_informatia_tranzactiei();
    ultima_tranzactie_apb = tr.copy();   // copy() = clone pentru safe storage
    coada_apb.push_back(ultima_tranzactie_apb);

    // ─── Verificare 1: scriere la adresa RO ───────────────────────
    // DE CE: 0x00 si 0x01 sunt R/W (registrele de butoane), restul
    // (0x02-0x05) sunt RO (status registers). Daca testbench-ul scrie
    // la o adresa RO, DUT-ul o ignora (no-op), dar e o violare a
    // contractului — testul are un bug logic.
    if (tr.rw == 1'b1 && tr.addr > 8'h01)
      `uvm_error("SCOREBOARD",
        $sformatf("Scriere la adresa read-only 0x%02h detectata!", tr.addr))

    // ─── Statistici trafic APB ────────────────────────────────────
    if (tr.rw == 1'b1) numar_tranzactii_apb_write++;
    else               numar_tranzactii_apb_read++;

    // ─── SCRIERE: actualizam shadow registers ─────────────────────
    // DE CE: pentru test_citire_registre, vrem sa validam ca o
    // citire ulterioara la aceeasi adresa returneaza valoarea scrisa.
    // Shadow = "umbra" registrului real din DUT, pastrata local.
    if (tr.rw == 1'b1) begin
      case (tr.addr)
        8'h00: begin
          shadow_buton_scara_reg   = tr.data;
          shadow_scara_initializat = 1'b1;  // de acum putem verifica citirile
          `uvm_info("SCOREBOARD",
            $sformatf("Shadow: buton_scara_reg <= 0x%02h", tr.data), UVM_HIGH)
        end
        8'h01: begin
          shadow_buton_lift_reg    = tr.data;
          shadow_lift_initializat  = 1'b1;
          `uvm_info("SCOREBOARD",
            $sformatf("Shadow: buton_lift_reg <= 0x%02h", tr.data), UVM_HIGH)
        end
        default: ;  // scrieri la RO sunt deja semnalate mai sus
      endcase
    end

    // ─── CITIRE: delegate la verifica_citire_apb pentru claritate ─
    if (tr.rw == 1'b0) begin
      verifica_citire_apb(tr);
    end

    // ─── Cross-check cu ultima iesire ─────────────────────────────
    // Daca tocmai am scris la un buton, verificam ca LED-ul s-a aprins.
    verifica_consistenta_apb_iesire(tr);
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  HELPER: verifica_citire_apb — Validare PRDATA pentru toate adresele
  // ═══════════════════════════════════════════════════════════════════
  // Logica decizionala:
  //
  //            ┌─ tr.data este X (necunoscut) ──► ERROR (PRDATA invalid)
  //            │
  //  CITIRE ───┼─ addr 0x00 / 0x01 ──► compara cu shadow
  //            │                       (DAR doar daca s-a scris vreodata,
  //            │                        altfel sare verificarea)
  //            │
  //            ├─ addr 0x02-0x05 ───► doar verifica ne-X (valoarea depinde
  //            │                       de starea curenta a DUT-ului, nu
  //            │                       avem un model exact)
  //            │
  //            └─ addr 0x06+ ────────► trebuie sa returneze 0xFF (default
  //                                    din lift_apb.v)
  function void verifica_citire_apb(tranzactie_apb tr);
    // ─── Verificare 0: PRDATA nu e X ────────────────────────────
    // DE CE: $isunknown() returneaza 1 daca orice bit e X sau Z.
    // PRDATA-ul DUT-ului trebuie sa fie determinist la citire valida.
    // Aceasta verificare e redundanta cu asertiunea SVA a_prdata_known,
    // dar o pastram pentru a opri verificari ulterioare (return).
    if ($isunknown(tr.data)) begin
      `uvm_error("SCOREBOARD",
        $sformatf("CITIRE: PRDATA contine X la addr=0x%02h", tr.addr))
      erori_detectate++;
      return;  // opreste verificarea — restul nu mai are sens cu X
    end

    case (tr.addr)
      // ─── Adresele R/W: echo check cu shadow ─────────────────────
      8'h00: begin
        if (shadow_scara_initializat && (tr.data !== shadow_buton_scara_reg)) begin
          // Mismatch! Asta a prins bug-ul "PRDATA registrat cu 1 ciclu intarziere"
          `uvm_error("SCOREBOARD",
            $sformatf("CITIRE 0x00: asteptat=0x%02h, citit=0x%02h",
                      shadow_buton_scara_reg, tr.data))
          erori_detectate++;
        end else if (shadow_scara_initializat) begin
          // Match perfect — verificare trecuta
          `uvm_info("SCOREBOARD",
            $sformatf("CITIRE 0x00 OK: data=0x%02h matches shadow", tr.data), UVM_HIGH)
          verificari_trecute++;
        end
        // (else: nu s-a scris inca aici, deci nu putem verifica)
      end
      8'h01: begin
        if (shadow_lift_initializat && (tr.data !== shadow_buton_lift_reg)) begin
          `uvm_error("SCOREBOARD",
            $sformatf("CITIRE 0x01: asteptat=0x%02h, citit=0x%02h",
                      shadow_buton_lift_reg, tr.data))
          erori_detectate++;
        end else if (shadow_lift_initializat) begin
          `uvm_info("SCOREBOARD",
            $sformatf("CITIRE 0x01 OK: data=0x%02h matches shadow", tr.data), UVM_HIGH)
          verificari_trecute++;
        end
      end

      // ─── Adresele RO: doar verificam ca ne-X (deja facut sus) ────
      // Valoarea concreta a various_signals/floor_management/led_*
      // depinde de starea curenta a FSM-ului. Pentru a o verifica exact,
      // ar trebui sa modelam tot FSM-ul aici, ceea ce ar duplica DUT-ul.
      // De aceea limitam la verificare de validitate (ne-X), iar
      // verificarea functionala se face prin asertiuni si covergroups.
      8'h02, 8'h03, 8'h04, 8'h05: begin
        verificari_trecute++;
      end

      // ─── Adrese invalide (0x06+): trebuie sa returneze 0xFF ──────
      // DUT-ul are `default: PRDATA = 8'hFF` in case-ul de citire.
      // Aici validam acest comportament documentat.
      default: begin
        if (tr.data !== 8'hFF) begin
          `uvm_error("SCOREBOARD",
            $sformatf("CITIRE addr invalida 0x%02h: asteptat=0xFF, citit=0x%02h",
                      tr.addr, tr.data))
          erori_detectate++;
        end else begin
          `uvm_info("SCOREBOARD",
            $sformatf("CITIRE addr invalida 0x%02h OK: returneaza 0xFF", tr.addr), UVM_HIGH)
          verificari_trecute++;
        end
      end
    endcase
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  HANDLER 2: write_req_ack — Validare timing senzor obstacol
  // ═══════════════════════════════════════════════════════════════════
  // Monitorul de REQ/ACK masoara latentele si le impacheteaza in tranzactie:
  //   - ack_primit:              boolean (a venit ACK?)
  //   - cicli_pana_la_ack:       int (de la rose(REQ) la rose(ACK))
  //   - cicli_pana_la_ack_clear: int (de la fall(REQ) la fall(ACK))
  //
  // Pentru DUT-ul nostru cu obstacle_ack = obstacle_req & ~prev_obstacle_req:
  //   - latenta_ACK = 0 (combinatorial, acelasi ciclu)
  //   - latenta_clear = 1 (prev_obstacle_req se updateaza pe urmatorul edge)
  //
  // Aceste verificari sunt REDUNDANTE cu asertiunile SVA (a_ack_la_rose_req,
  // a_ack_puls_un_ciclu), dar valoarea adaugata e ca avem METRICILE in raport.
  function void write_req_ack(input tranzactie_req_ack tr);
    `uvm_info("SCOREBOARD", "Tranzactie REQ/ACK primita:", UVM_HIGH)
    tr.afiseaza_informatia_tranzactiei();
    ultima_tranzactie_req_ack = tr.copy();
    coada_req_ack.push_back(ultima_tranzactie_req_ack);

    // ─── Verificare 1: DUT a raspuns cu ACK ───────────────────────
    // DE CE: protocolul REQ/ACK garanteaza un raspuns. Daca DUT-ul nu
    // raspunde deloc, senzorul de obstacol e "mort" — caz critic.
    if (!tr.ack_primit) begin
      `uvm_error("SCOREBOARD",
        "REQ/ACK: obstacle_ack nu a fost primit dupa obstacle_req!")
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end

    // ─── Verificare 2: latenta de activare ────────────────────────
    // DE CE: DUT-ul e combinatorial, ACK trebuie sa apara IMEDIAT.
    // Daca cineva re-arhitectureaza DUT-ul si introduce un registru
    // pentru ack, aici prindem regresia.
    if (tr.cicli_pana_la_ack > 1) begin
      `uvm_error("SCOREBOARD",
        $sformatf("REQ/ACK: latenta ACK = %0d cicluri (maxim permis: 1)",
                  tr.cicli_pana_la_ack))
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end

    // ─── Verificare 3: latenta de dezactivare ─────────────────────
    // DE CE: ACK trebuie sa fie un puls scurt. Daca ramane pe 1 dupa
    // ce REQ a coborat, e un bug (de exemplu, prev_obstacle_req nu
    // se updateaza corect).
    if (tr.cicli_pana_la_ack_clear > 1) begin
      `uvm_error("SCOREBOARD",
        $sformatf("REQ/ACK: ACK clear dupa %0d cicluri (maxim permis: 1)",
                  tr.cicli_pana_la_ack_clear))
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  HANDLER 3: write_iesire — Cea mai complexa functie din scoreboard
  // ═══════════════════════════════════════════════════════════════════
  // Aceasta functie face 5 lucruri majore:
  //   1. Verificari de sanitate (etaj valid, door consistent, LED bit 7)
  //   2. Tracker URGENTA (mini-FSM cu 3 stari — vezi diagrama de sus)
  //   3. Statistici (etaje vizitate, deschideri usa, max pending)
  //
  // Monitorul de iesire este PASIV si sampleaza CONTINUU starea DUT-ului,
  // deci aceasta functie e apelata frecvent (la fiecare schimbare).
  function void write_iesire(input tranzactie_iesire tr);
    `uvm_info("SCOREBOARD", "Tranzactie IESIRE primita:", UVM_HIGH)
    tr.afiseaza_informatia_tranzactiei();
    ultima_tranzactie_iesire = tr.copy();
    coada_iesire.push_back(ultima_tranzactie_iesire);

    // ─── Verificare 1: etaj curent in interval valid ──────────────
    // DE CE: current_floor_reg e 3 biti, deci matematic e 0-7. Daca cineva
    // mareste la 4 biti din greseala si lasa codul de mapare la 3 biti,
    // valori > 7 ar fi prinse aici.
    if (tr.etaj_curent > 3'd7) begin
      `uvm_error("SCOREBOARD",
        $sformatf("IESIRE: etaj_curent=%0d in afara intervalului [0:7]!",
                  tr.etaj_curent))
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end

    // ─── Verificare 2: door_open consistent intre cele 2 registre ──
    // DE CE: various_signals[0] si floor_management[0] derivă din ACELASI
    // semnal intern (door_open). Daca FSM-ul are bug si le actualizeaza
    // inconsistent (de exemplu, un mux gresit), prindem regresia.
    // Folosim !== pentru a fi X-safe (la comparatie standard, X==X ar fi X).
    if (tr.various_signals[0] !== tr.floor_management[0]) begin
      `uvm_error("SCOREBOARD",
        "IESIRE: door_open inconsistent intre various_signals si floor_management!")
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end

    // ─── Verificare 3: LED bit 7 mereu stins ──────────────────────
    // DE CE: bitul 7 al LED-urilor este REZERVAT (urgenta), nu un etaj
    // fizic. DUT-ul foloseste mascarea (& 8'h7F) la asignare. Daca
    // cineva sterge mascarea, bit 7 s-ar aprinde la scrieri 0x80 si
    // verificarea aici prinde bug-ul. Aceasta verificare a prins un
    // bug REAL la noi (LED se aprindea la urgenta).
    if (tr.led_lift[7] || tr.led_scara[7]) begin
      `uvm_error("SCOREBOARD",
        "IESIRE: LED aprins la bit 7 (bit de urgenta, nu etaj fizic)!")
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end

    // ═══════════════════════════════════════════════════════════════
    //  TRACKER URGENTA — Mini-FSM cu 3 stari
    // ═══════════════════════════════════════════════════════════════
    // Implementare: cele 3 stari sunt selectate prin if/else if cu
    // conditii pe (emergency_now AND in_urgenta_track) — un pattern
    // standard pentru FSM-uri implicite in functii non-blocking.

    // ─── STATE 1: START (rising edge detection) ────────────────────
    // Conditie: emergency=1 ACUM dar nu eram in tracker → tocmai s-a activat
    if (tr.various_signals[1] && !in_urgenta) begin
      in_urgenta                = 1'b1;
      cicli_in_urgenta          = 0;
      etaj_la_inceput_urgenta   = tr.etaj_curent;
      // Caz rar: urgenta porneste chiar la etaj 0 (lift deja la parter)
      a_atins_etaj_0_in_urgenta = (tr.etaj_curent == 3'd0);
      numar_urgente_detectate++;
      `uvm_info("SCOREBOARD",
        $sformatf("URGENTA #%0d activata la etajul %0d",
                  numar_urgente_detectate, tr.etaj_curent), UVM_LOW)
    end

    // ─── STATE 2: TRACKING (urgenta in derulare) ───────────────────
    // Conditie: emergency=1 si eram deja in tracker → continuam
    else if (tr.various_signals[1] && in_urgenta) begin
      cicli_in_urgenta++;
      // Marcam ca liftul a vizitat etaj 0 in timpul coborarii
      if (tr.etaj_curent == 3'd0) a_atins_etaj_0_in_urgenta = 1'b1;

      // Safety net: daca urgenta dureaza prea mult, FSM-ul e blocat
      // (deadlock in STATE_STOP, contoare gresite, etc.)
      if (cicli_in_urgenta > max_cicli_in_urgenta) begin
        `uvm_error("SCOREBOARD",
          $sformatf("URGENTA blocata: %0d tranzactii cu emergency=1 (limita %0d)",
                    cicli_in_urgenta, max_cicli_in_urgenta))
        erori_detectate++;
        in_urgenta = 1'b0;  // reset tracking ca sa nu spammuim erori
      end
    end

    // ─── STATE 3: VALIDATION (falling edge — urgenta s-a terminat) ──
    // Conditie: emergency=0 ACUM dar eram in tracker → tocmai s-a eliberat
    // Aici facem VERIFICAREA CRITICA a contractului unei urgente corecte:
    //   a) liftul a coborat la etaj 0?
    //   b) toate cererile au fost sterse (pending = 0)?
    else if (!tr.various_signals[1] && in_urgenta) begin
      `uvm_info("SCOREBOARD",
        $sformatf("URGENTA eliberata dupa %0d tranzactii (start etaj %0d -> end etaj %0d)",
                  cicli_in_urgenta, etaj_la_inceput_urgenta, tr.etaj_curent), UVM_LOW)

      // Verificare 4a: liftul TREBUIE sa fi atins etaj 0 in coborare
      if (!a_atins_etaj_0_in_urgenta) begin
        `uvm_error("SCOREBOARD",
          "URGENTA: liftul NU a atins etaj 0 in timpul starii de urgenta!")
        erori_detectate++;
      end else begin
        verificari_trecute++;
      end

      // Verificare 4b: TOATE cererile au fost sterse (request_reg = 0)
      // various_signals[7:2] = pending_count
      if (tr.various_signals[7:2] != 6'h00) begin
        `uvm_error("SCOREBOARD",
          $sformatf("URGENTA: pending_count=%0d (asteptat 0) la eliberare!",
                    tr.various_signals[7:2]))
        erori_detectate++;
      end else begin
        verificari_trecute++;
      end

      in_urgenta = 1'b0;  // reset tracker pentru urmatoarea urgenta
    end

    // ═══════════════════════════════════════════════════════════════
    //  STATISTICI GLOBALE (rulate la fiecare tranzactie iesire)
    // ═══════════════════════════════════════════════════════════════

    // Initializare lazy a contextului
    if (primul_tranzactie_iesire) begin
      ultim_etaj_vizitat       = tr.etaj_curent;
      primul_tranzactie_iesire = 1'b0;
    end

    // ─── Track etaje vizitate (coverage functional manual) ──────
    // Cand door_open=1, liftul a "servit" un etaj. Inregistram bitul
    // corespunzator in masca. La final, popcount-ul mastii = numar etaje unice.
    if (tr.various_signals[0]) begin  // bit 0 = door_open
      etaje_vizitate_mask[tr.etaj_curent] = 1'b1;
      // Numaram doar tranzitii (etaj nou) — altfel am numara fiecare
      // sample din timpul cat usa e deschisa
      if (tr.etaj_curent != ultim_etaj_vizitat) begin
        numar_deschideri_usa++;
      end
    end
    ultim_etaj_vizitat = tr.etaj_curent;

    // ─── Track stress level: pending maxim observat ────────────
    // Util pentru a sti cat de "incarcat" a fost liftul in test
    if (tr.various_signals[7:2] > max_pending_observat)
      max_pending_observat = tr.various_signals[7:2];
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  CROSS-CHECK: verifica_consistenta_apb_iesire
  // ═══════════════════════════════════════════════════════════════════
  // CONCEPT: validare END-TO-END a fluxului control.
  // Cand testbench-ul scrie la un buton (APB write), DUT-ul ar trebui sa
  // aprinda LED-ul corespunzator (vizibil pe interfata iesire).
  //
  // De ce WARNING si nu ERROR?
  //   Latenta: intre scrierea APB si actualizarea LED-ului, trec 1-2 cicluri
  //   (un pas prin FSM). Daca scoreboard-ul compara IMEDIAT, valoarea poate
  //   sa nu fi ajuns inca la iesire. Un WARNING semnaleaza posibila problema,
  //   dar nu o eroare definitiva. Daca testul are multe astfel de warnings
  //   constant, ar trebui investigat. Daca apare doar in primele cicluri,
  //   e normal.
  //
  // Caz special: scrierea 0x80 la 0x01 = urgenta, NU cerere de etaj 7.
  // Ignoram acest caz (LED-ul nu trebuie sa se aprinda — bit 7 e rezervat).
  function void verifica_consistenta_apb_iesire(tranzactie_apb tr_apb);
    if (tr_apb.rw == 1'b1 && coada_iesire.size() > 0) begin
      tranzactie_iesire tr_out = coada_iesire[$]; // [$] = ultima din coada
      case (tr_apb.addr)
        8'h00: begin // s-a scris pe buton_scara
          // Verificare: TOATE bitii setati in tr_apb.data sunt aprinsi in led_scara
          // (led_scara & data) == data  ⇔  data este submultime a led_scara
          if ((tr_out.led_scara & tr_apb.data) != tr_apb.data)
            `uvm_warning("SCOREBOARD",
              $sformatf("LED scara 0x%02h nu reflecta cererea APB 0x%02h (poate inca in tranzit)",
                        tr_out.led_scara, tr_apb.data))
        end
        8'h01: begin // s-a scris pe buton_lift
          // Caz special: 0x80 = urgenta, nu cerere — sarim verificarea
          if (tr_apb.data != 8'h80) begin
            if ((tr_out.led_lift & tr_apb.data) != tr_apb.data)
              `uvm_warning("SCOREBOARD",
                $sformatf("LED lift 0x%02h nu reflecta cererea APB 0x%02h (poate inca in tranzit)",
                          tr_out.led_lift, tr_apb.data))
          end
        end
        default: ;  // alte adrese sunt RO (no-op pentru cross-check)
      endcase
    end
    // (else: nu avem inca o tranzactie iesire de comparat sau citire APB)
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  RAPORT FINAL — apelat AUTOMAT la sfarsitul simularii (report_phase)
  // ═══════════════════════════════════════════════════════════════════
  // Format tabloul de bord cu 3 sectiuni:
  //   1. Volum trafic per interfata
  //   2. Statistici functionale (coverage manual)
  //   3. Verdict PASS/FAIL bazat pe contoare
  //
  // Acest raport e VALORUL ADAUGAT al scoreboard-ului fata de simpla
  // detectie de erori: ofera context calitativ asupra testului rulat.
  virtual function void report_phase(uvm_phase phase);
    int numar_etaje_unice;
    super.report_phase(phase);

    // ─── Calculam numarul de etaje UNICE vizitate (popcount) ─────
    // Trecem prin fiecare bit din masca si contam cati sunt 1.
    // SystemVerilog ar avea $countones() pentru asta, dar pastram
    // un for-loop simplu pentru compatibilitate.
    numar_etaje_unice = 0;
    for (int b = 0; b < 8; b++)
      if (etaje_vizitate_mask[b]) numar_etaje_unice++;

    // ─── Afisare formatata cu caractere Unicode pentru tabel ─────
    $display("╔════════════════════════════════════════════╗");
    $display("║          RAPORT FINAL SCOREBOARD           ║");
    $display("╠════════════════════════════════════════════╣");

    // SECTIUNEA 1: Volum trafic
    $display("║  Tranzactii APB total  : %4d              ║", coada_apb.size());
    $display("║    └─ scrieri          : %4d              ║", numar_tranzactii_apb_write);
    $display("║    └─ citiri           : %4d              ║", numar_tranzactii_apb_read);
    $display("║  Tranzactii REQ/ACK    : %4d              ║", coada_req_ack.size());
    $display("║  Tranzactii Iesire     : %4d              ║", coada_iesire.size());
    $display("╠════════════════════════════════════════════╣");

    // SECTIUNEA 2: Statistici comportament (coverage functional manual)
    $display("║  STATISTICI COMPORTAMENT LIFT              ║");
    $display("║  Etaje unice vizitate  : %4d / 8          ║", numar_etaje_unice);
    $display("║  Mask etaje vizitate   : 0x%02h              ║", etaje_vizitate_mask);
    $display("║  Deschideri usa        : %4d              ║", numar_deschideri_usa);
    $display("║  Max pending observat  : %4d              ║", max_pending_observat);
    $display("║  Urgente detectate     : %4d              ║", numar_urgente_detectate);
    $display("╠════════════════════════════════════════════╣");

    // SECTIUNEA 3: Verdict final
    $display("║  Verificari trecute    : %4d              ║", verificari_trecute);
    $display("║  Erori detectate       : %4d              ║", erori_detectate);
    $display("╠════════════════════════════════════════════╣");
    if (erori_detectate == 0)
      $display("║  STATUS: ** TOATE TESTELE TRECUTE **       ║");
    else
      $display("║  STATUS: !! %4d ERORI DETECTATE !!        ║", erori_detectate);
    $display("╚════════════════════════════════════════════╝");
  endfunction

endclass
`endif
