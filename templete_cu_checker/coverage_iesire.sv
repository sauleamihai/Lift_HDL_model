`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __iesire_coverage
`define __iesire_coverage

// ═══════════════════════════════════════════════════════════════════════════
//  COMPONENTA: coverage_iesire
//  ROL       : Colector de acoperire functionala pentru interfata de IESIRE
//              a DUT-ului. Masoara cat din spatiul de stari posibile a fost
//              EFECTIV stimulat de testele rulate.
//
//  FILOSOFIA COVERAGE:
//    Asertiunile SVA + Scoreboard verifica CORECTITUDINEA (ce face DUT-ul
//    este OK), dar nu garanteaza ca am exercitat TOATE scenariile posibile.
//    Coverage-ul raspunde la intrebarea: "Am testat suficient?"
//
//  TIPURI DE COVERAGE:
//    - Coverage de cod (line/branch)   → automat, generat de simulator
//    - Coverage functional (acest fisier) → manual, definit prin covergroups
//
//  CE ESTE UN COVERGROUP?
//    Un container care contine:
//      - coverpoints: variabile observate, impartite in BINS (categorii)
//      - cross-uri:   produs cartezian intre 2+ coverpoints
//    La fiecare `sample()`, simulatorul incrementeaza bin-ul corespunzator
//    valorii curente. La final: % bins cu hit-uri = procent acoperire.
//
//  ARHITECTURA:
//    Clasa este o clasa SystemVerilog SIMPLA (nu uvm_component) pentru a
//    putea fi instantiata ca obiect membru in monitor (covergroup-urile nu
//    pot fi declarate direct in uvm_component din motive de timing).
//
//  CE OBSERVAM PE INTERFATA IESIRE:
//    - etaj_curent     → etajul fizic al liftului (3 biti, 0-7)
//    - door_open       → starea usii (1 bit)
//    - emergency_stop  → flag urgenta (1 bit)
//    - pending_count   → cate cereri sunt in asteptare (0-8)
//    - led_lift        → LED-uri cabina (un bit per etaj)
//    - led_scara       → LED-uri palier (un bit per etaj)
//
//  CROSS-COVERAGE INTERESANTE:
//    - etaj × door_open  → liftul a deschis usa la TOATE etajele?
//    - etaj × pending    → exista cereri la fiecare etaj la momente diferite?
// ═══════════════════════════════════════════════════════════════════════════
class coverage_iesire;

  // ═══════════════════════════════════════════════════════════════════
  //  VARIABILE DE SAMPLE — copii locale ale semnalelor monitorizate
  // ═══════════════════════════════════════════════════════════════════
  // Convenia "cv_" (coverage variable). Sunt actualizate de update()
  // si sample-uite implicit de covergroup la fiecare apel sample().
  //
  // De ce variabile separate si nu direct campurile tranzactiei?
  //   - Independenta fata de schimbarile in clasa tranzactiei
  //   - Posibilitate de pre-procesare (de exemplu, derive de semnale)
  //   - Simplifica debugging-ul (vedem clar ce ajunge in covergroup)
  bit [2:0] cv_etaj_curent;        // current_floor_reg [2:0] din DUT
  bit       cv_door_open;          // various_signals[0]
  bit       cv_emergency_stop;     // various_signals[1]
  bit [5:0] cv_pending_count;      // various_signals[7:2], max valoare = 8
  bit [7:0] cv_led_lift;           // led_lift complet (8 biti)
  bit [7:0] cv_led_scara;          // led_scara complet (8 biti)

  // ═══════════════════════════════════════════════════════════════════
  //  COVERGROUP: stari_iesire_cg
  // ═══════════════════════════════════════════════════════════════════
  // Acest covergroup descrie SCENARIILE FUNCTIONALE pe care vrem sa le
  // observam. Fiecare coverpoint este o "dimensiune" de masurare.
  //
  // option.per_instance = 1 → daca am multiple instante ale clasei,
  //   fiecare are propriul ei coverage (nu se cumuleaza). La noi e o
  //   singura instanta in mediu, dar e bun pattern pentru flexibilitate.
  covergroup stari_iesire_cg;
    option.per_instance = 1;

    // ─── COVERPOINT 1: cp_etaj_curent ─────────────────────────────
    // SCOP: validam ca liftul a TRECUT efectiv prin TOATE cele 8 etaje.
    // Fara aceasta acoperire, am putea avea teste care exercita doar
    // o parte din etaje, lasand zone netestate ale FSM-ului.
    //
    // BINS: cate unul per etaj — 8 bins distincte.
    // Acoperire 100% = liftul a fost in fiecare etaj cel putin o data.
    cp_etaj_curent: coverpoint cv_etaj_curent {
      bins etaj_0 = {3'd0};   // parter (si destinatia urgentei)
      bins etaj_1 = {3'd1};
      bins etaj_2 = {3'd2};
      bins etaj_3 = {3'd3};
      bins etaj_4 = {3'd4};
      bins etaj_5 = {3'd5};
      bins etaj_6 = {3'd6};
      bins etaj_7 = {3'd7};   // etaj maxim
    }

    // ─── COVERPOINT 2: cp_door_open ───────────────────────────────
    // SCOP: confirmam ca am observat usa atat DESCHISA cat si INCHISA.
    // Acoperire 100% = ambele stari atinse (banal, dar bun ca sanity).
    cp_door_open: coverpoint cv_door_open {
      bins inchisa  = {1'b0};
      bins deschisa = {1'b1};
    }

    // ─── COVERPOINT 3: cp_emergency ────────────────────────────────
    // SCOP: confirmam ca am exercitat STAREA DE URGENTA.
    // Acoperire 100% = am stimulat atat operatia normala cat si urgenta.
    // Daca acest coverpoint ramane sub 100%, inseamna ca testele nu
    // testeaza scenariile critice de siguranta.
    cp_emergency: coverpoint cv_emergency_stop {
      bins normal  = {1'b0};
      bins urgenta = {1'b1};
    }

    // ─── COVERPOINT 4: cp_pending ──────────────────────────────────
    // SCOP: masuram NIVELUL DE STRESS pe care liftul a fost expus.
    //
    // BINS impartite logic (nu uniform):
    //   - nicio cerere  → idle, baseline
    //   - 1 cerere      → comportament normal (1 buton apasat)
    //   - 2-3 cereri    → trafic moderat (lift ocupat)
    //   - 4-8 cereri    → stress (aproape saturat)
    //
    // Acoperire 100% = am exercitat liftul la TOATE nivelurile de incarcare.
    cp_pending: coverpoint cv_pending_count {
      bins nicio     = {6'd0};
      bins una       = {6'd1};
      bins doua_trei = {[6'd2 : 6'd3]};
      bins multe     = {[6'd4 : 6'd8]};
    }

    // ─── COVERPOINT 5: cp_led_lift ─────────────────────────────────
    // SCOP: validam ca LED-urile cabinei s-au aprins pentru fiecare etaj.
    //
    // WILDCARD BINS: notatia 8'b????_???1 inseamna "orice valoare unde
    //   bitul 0 este 1" (ceilalti biti pot fi 0 sau 1). Asta capteaza
    //   TOATE situatiile in care LED-ul etajului 0 e aprins, chiar daca
    //   simultan sunt si alte LED-uri aprinse.
    //
    // De ce nu bins simple {8'h01}?
    //   Daca cerem un singur etaj, da, e 0x01. Dar daca cerem etajele 0 si 3,
    //   led_lift = 0x09. Cu wildcard, ambele cazuri sunt prinse de bin-ul
    //   led_etaj_0. Coverage-ul masoara "LED-ul X a fost aprins vreodata",
    //   nu "LED-ul X a fost SINGUR aprins".
    //
    // BIT 7 LIPSESTE INTENTIONAT: este rezervat pentru urgenta, nu reprezinta
    //   un etaj fizic. Asertiunea a_led_fara_etaj_invalid garanteaza ca
    //   acest bit ramane 0, deci nu il sample-uim.
    cp_led_lift: coverpoint cv_led_lift {
      wildcard bins led_etaj_0 = {8'b????_???1};
      wildcard bins led_etaj_1 = {8'b????_??1?};
      wildcard bins led_etaj_2 = {8'b????_?1??};
      wildcard bins led_etaj_3 = {8'b????_1???};
      wildcard bins led_etaj_4 = {8'b???1_????};
      wildcard bins led_etaj_5 = {8'b??1?_????};
      wildcard bins led_etaj_6 = {8'b?1??_????};
      bins toate_stinse = {8'h00};  // baseline: nicio cerere activa
    }

    // ─── COVERPOINT 6: cp_led_scara ────────────────────────────────
    // SCOP IDENTIC cu cp_led_lift, dar pentru LED-urile de pe palier
    // (apeluri din afara cabinei). Acoperirea completa demonstreaza ca
    // ambele surse de cereri (cabina + palier) au fost stimulate la toate
    // etajele 0-6.
    cp_led_scara: coverpoint cv_led_scara {
      wildcard bins led_etaj_0 = {8'b????_???1};
      wildcard bins led_etaj_1 = {8'b????_??1?};
      wildcard bins led_etaj_2 = {8'b????_?1??};
      wildcard bins led_etaj_3 = {8'b????_1???};
      wildcard bins led_etaj_4 = {8'b???1_????};
      wildcard bins led_etaj_5 = {8'b??1?_????};
      wildcard bins led_etaj_6 = {8'b?1??_????};
      bins toate_stinse = {8'h00};
    }

    // ═══════════════════════════════════════════════════════════════
    //  CROSS-COVERAGE — interactiuni intre coverpoints
    // ═══════════════════════════════════════════════════════════════
    // Cross-ul creeaza un PRODUS CARTEZIAN: pentru fiecare combinatie
    // (etaj × door_state), avem un bin. Daca etaj are 8 bins si door
    // are 2, cross-ul are 16 bins.
    //
    // IGNORE_BINS: excludem combinatiile pe care nu vrem sa le numaram
    // (in general, cele care nu aduc informatie utila despre comportament).

    // ─── CROSS 1: cx_etaj_door ────────────────────────────────────
    // SCOP: validam ca liftul a deschis usa LA FIECARE ETAJ.
    // Aceasta este verificarea functionala cheie: liftul "serveste" 8 etaje,
    // deci 8 bins de tip (etaj_N, deschisa). Acoperire 100% = toate etajele
    // au fost vizitate cu usa deschisa.
    //
    // ignore_bins etaj_fara_usa: ignoram combinatiile (etaj_N, inchisa)
    // pentru ca usa inchisa la un etaj e starea NORMALA in timpul deplasarii
    // si nu valideaza ca etajul a fost SERVIT.
    cx_etaj_door: cross cp_etaj_curent, cp_door_open {
      ignore_bins etaj_fara_usa = binsof(cp_door_open.inchisa);
    }

    // ─── CROSS 2: cx_etaj_pending ─────────────────────────────────
    // SCOP: verificam ca am exercitat scenarii unde liftul are cereri
    // active LA FIECARE ETAJ (nu doar la unul-doua).
    //
    // De exemplu, am verificat ca am avut momente cand:
    //   - Liftul era la etaj 3 si avea 1 cerere
    //   - Liftul era la etaj 5 si avea 3 cereri
    //   etc.
    //
    // ignore_bins nicio_cerere: ignoram cazul (etaj_N, 0 cereri) pentru ca
    // nu reprezinta o situatie de "lift sub presiune" — toate etajele in
    // idle e doar baseline-ul.
    cx_etaj_pending: cross cp_etaj_curent, cp_pending {
      ignore_bins nicio_cerere = binsof(cp_pending.nicio);
    }

  endgroup

  // ═══════════════════════════════════════════════════════════════════
  //  CONSTRUCTOR
  // ═══════════════════════════════════════════════════════════════════
  // ATENTIE: covergroup-urile TREBUIE instantiate explicit cu `new()`!
  // Spre deosebire de variabilele obisnuite, ele nu se auto-creeaza la
  // declaratie. Daca uitam, simularea da error la primul sample().
  function new();
    stari_iesire_cg = new();
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  update() — apelat de monitor la fiecare tranzactie noua
  // ═══════════════════════════════════════════════════════════════════
  // Workflow:
  //   1. Monitor primeste o tranzactie de la DUT
  //   2. Monitor cheama coverage.update(tr) → actualizam cv_*
  //   3. Monitor cheama stari_iesire_cg.sample() → coverage incrementat
  //
  // Putem combina pasul 2 si 3 intr-o singura functie:
  //   - update() actualizeaza variabilele si APELEAZA sample() implicit
  //     (cand stari_iesire_cg detecteaza schimbarea automata)
  //   - Sau monitor face sample() manual dupa update()
  //
  // La noi, monitorul face sample() explicit dupa update() pentru
  // claritate.
  function void update(tranzactie_iesire tr);
    cv_etaj_curent    = tr.etaj_curent;
    cv_door_open      = tr.door_open;
    cv_emergency_stop = tr.emergency_stop;
    cv_pending_count  = tr.pending_count;
    cv_led_lift       = tr.led_lift;
    cv_led_scara      = tr.led_scara;
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  print_coverage() — afisare raport detaliat
  // ═══════════════════════════════════════════════════════════════════
  // Apelata din monitor.report_phase() pentru a vedea detaliat care
  // coverpoints au atins 100% si care necesita teste suplimentare.
  //
  // get_coverage() returneaza % pentru:
  //   - intregul covergroup (medie ponderata)
  //   - fiecare coverpoint individual
  //   - fiecare cross
  //
  // INTERPRETARE TIPICA:
  //   - 100% pe cp_etaj_curent → liftul a vizitat toate etajele
  //   - <100% pe cp_emergency → testele nu activeaza urgenta suficient
  //   - <100% pe cx_etaj_door → unele etaje nu au fost servite efectiv
  function void print_coverage();
    $display("=== RAPORT COVERAGE IESIRI DUT ===");
    $display("  Acoperire totala   : %.2f%%", stari_iesire_cg.get_coverage());
    $display("  cp_etaj_curent     : %.2f%%", stari_iesire_cg.cp_etaj_curent.get_coverage());
    $display("  cp_door_open       : %.2f%%", stari_iesire_cg.cp_door_open.get_coverage());
    $display("  cp_emergency       : %.2f%%", stari_iesire_cg.cp_emergency.get_coverage());
    $display("  cp_pending         : %.2f%%", stari_iesire_cg.cp_pending.get_coverage());
    $display("  cp_led_lift        : %.2f%%", stari_iesire_cg.cp_led_lift.get_coverage());
    $display("  cp_led_scara       : %.2f%%", stari_iesire_cg.cp_led_scara.get_coverage());
    $display("  cx_etaj_door       : %.2f%%", stari_iesire_cg.cx_etaj_door.get_coverage());
    $display("  cx_etaj_pending    : %.2f%%", stari_iesire_cg.cx_etaj_pending.get_coverage());
    $display("==================================");
  endfunction

endclass

`endif
