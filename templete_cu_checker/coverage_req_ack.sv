`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __req_ack_coverage
`define __req_ack_coverage

// ═══════════════════════════════════════════════════════════════════════════
//  COMPONENTA: coverage_req_ack
//  ROL       : Colector de acoperire functionala pentru interfata REQ/ACK
//              a senzorului de obstacol. Masoara cat de bine au fost
//              stimulate scenariile temporale ale protocolului.
//
//  CONTEXT — Protocolul REQ/ACK:
//    - obstacle_req (input)  : senzorul detecteaza un obstacol in usa
//    - obstacle_ack (output) : DUT-ul confirma (puls combinatorial de 1 ciclu)
//
//    Cand REQ urca (front 0→1), DUT-ul raspunde combinatorial cu ACK in
//    ACELASI ciclu. Cand REQ persista, door_counter ramane 0 (usa deschisa).
//    Cand REQ coboara, ACK se dezactiveaza in ciclul urmator.
//
//  CE MASURAM CU COVERAGE-UL?
//    Nu doar "a aparut un obstacol" (banal), ci scenariile TEMPORALE:
//
//    1. DURATA OBSTACOLULUI (cat timp REQ a fost activ):
//       - Scurt (1-3 cicluri) → trecere rapida prin usa
//       - Mediu (4-6 cicluri) → o persoana se opreste in usa
//       - Lung  (7-15 cicluri) → blocaj prelungit
//       Acoperire 100% = am testat liftul cu toate tipurile de blocaje.
//
//    2. LATENTA DE ACTIVARE (de cand REQ urca pana cand ACK urca):
//       - Imediat (0)         → caz optim, combinatorial
//       - 1 ciclu             → caz acceptabil
//       - 2+ cicluri          → caz suspect / regresie
//       Acoperire 100% = am observat raspunsul DUT-ului in mai multe regimuri.
//
//    3. LATENTA DE DEZACTIVARE (de cand REQ coboara pana cand ACK coboara):
//       - 1-2 cicluri         → comportament normal
//       - 3+ cicluri          → bug (ACK ramane pe 1 prea mult)
//
//    4. REUSITA HANDSHAKE-ULUI:
//       - ACK primit          → DUT a raspuns corect
//       - ACK lipsa           → DUT a "ratat" obstacolul (caz critic)
//
//  DE CE E IMPORTANT?
//    Asertiunile SVA verifica timpii MAXIMI (ack ≤ 1 ciclu), dar coverage-ul
//    asigura ca am EXERCITAT DUT-ul in toate aceste regimuri temporale.
//    De exemplu, daca toate testele genereaza doar obstacole de 5 cicluri,
//    nu vom sti niciodata cum reactioneaza la obstacole de 1 sau 15 cicluri.
// ═══════════════════════════════════════════════════════════════════════════
class coverage_req_ack;

  // ═══════════════════════════════════════════════════════════════════
  //  VARIABILE DE SAMPLE — metrici temporale capturate de monitor
  // ═══════════════════════════════════════════════════════════════════
  // Monitorul calculeaza aceste valori urmarind ceasurile dintre evenimente,
  // apoi le impacheteaza in tranzactie_req_ack. Le copiem local pentru sample.
  int cv_durata_obstacol;          // cate cicluri REQ a fost activ
  int cv_cicli_pana_la_ack;        // latenta activare: rose(REQ) → rose(ACK)
  int cv_cicli_pana_la_ack_clear;  // latenta dezactivare: fall(REQ) → fall(ACK)
  bit cv_ack_primit;               // 1 = ACK a venit, 0 = ACK lipsa

  // ═══════════════════════════════════════════════════════════════════
  //  COVERGROUP: stari_req_ack_cg
  // ═══════════════════════════════════════════════════════════════════
  // option.per_instance = 1: fiecare instanta are coverage propriu
  // (la noi e o singura instanta in mediu, dar e bun pattern de robustete).
  covergroup stari_req_ack_cg;
    option.per_instance = 1;

    // ─── COVERPOINT 1: cp_durata ───────────────────────────────────
    // SCOP: validam ca am stimulat liftul cu obstacole de DURATE VARIATE.
    //
    // De ce 3 categorii?
    //   - SCURT (1-3 cicluri): persoana traverseaza usa rapid → ACK puls
    //     scurt → comportament aproape combinatorial
    //   - MEDIU (4-6 cicluri): persoana se opreste in usa → liftul tine
    //     usa deschisa cativa cicli suplimentari
    //   - LUNG (7-15 cicluri): blocaj prelungit → testeaza limita superioara
    //     a comportamentului de hold pe door_counter
    //
    // Bins-urile NU se suprapun (1-3, 4-6, 7-15) — orice valoare cade
    // in EXACT un bin. Daca o valoare nu cade in niciun bin (de exemplu,
    // 0 sau 100), nu se conteaza (auto-bins-uri sunt dezactivate cand
    // definim bins-uri explicite).
    cp_durata: coverpoint cv_durata_obstacol {
      bins scurt  = {[1:3]};
      bins mediu  = {[4:6]};
      bins lung   = {[7:15]};
    }

    // ─── COVERPOINT 2: cp_latenta_ack ──────────────────────────────
    // SCOP: caracterizam comportamentul temporal al raspunsului DUT-ului.
    //
    // BINS:
    //   - IMEDIAT (0)     → ACK in acelasi ciclu cu REQ (combinatorial)
    //                        Aceasta e regimul NORMAL pentru DUT-ul nostru.
    //   - UN_CICLU (1)    → ACK in ciclul urmator (acceptabil daca s-ar
    //                        re-implementa cu registru)
    //   - DOI_CICLI (2)   → la limita asertiunii a_ack_la_rose_req
    //   - INTARZIAT (3+)  → bug clar, va declansa erori in scoreboard
    //
    // De ce avem bin-ul "intarziat" daca asertiunea il interzice?
    // Pentru ca daca DUT-ul ar avea bug si ar genera 3+ cicluri latenta,
    // vrem sa vedem si in coverage acea situatie. Asertiunea va da eroare,
    // dar coverage-ul ne arata "am stimulat scenariul respectiv" — util
    // pentru debug ulterior.
    cp_latenta_ack: coverpoint cv_cicli_pana_la_ack {
      bins imediat   = {0};
      bins un_ciclu  = {1};
      bins doi_cicli = {2};
      bins intarziat = {[3:$]};   // $ = upper bound (infinit practic)
    }

    // ─── COVERPOINT 3: cp_latenta_ack_clear ────────────────────────
    // SCOP: cat de repede se dezactiveaza ACK dupa ce REQ coboara.
    //
    // Pentru DUT-ul nostru (obstacle_ack = obstacle_req & ~prev_obstacle_req):
    //   - Cand REQ coboara: in ciclul urmator, prev_obstacle_req=1, deci
    //     obstacle_ack = 0 & ~1 = 0. Asadar latenta = 1 ciclu standard.
    //   - 2+ cicluri ar fi anomalie (probabil sample-ul a captat o stare
    //     metastabila).
    //
    // NU avem bin "imediat" aici pentru ca dezactivarea instant nu e posibila
    // (avem nevoie de cel putin un edge de clock pentru prev_obstacle_req).
    cp_latenta_ack_clear: coverpoint cv_cicli_pana_la_ack_clear {
      bins un_ciclu  = {1};
      bins doi_cicli = {2};
      bins intarziat = {[3:$]};
    }

    // ─── COVERPOINT 4: cp_ack_primit ───────────────────────────────
    // SCOP: sanity check — DUT-ul a raspuns la TOATE obstacolele?
    //
    // BINS:
    //   - ACK_OK (1)    → DUT a raspuns
    //   - ACK_LIPSA (0) → DUT NU a raspuns (bug critic)
    //
    // Idealmente, ack_lipsa NU TREBUIE atins. Daca bin-ul devine 100%
    // (adica avem cazuri unde DUT nu raspunde), avem probleme grave.
    // Daca bin-ul ramane 0%, e bine.
    //
    // De ce sample-uim oricum un bin "indezirabil"?
    // Pentru CONSTIENTIZARE: vrem sa stim daca testele scot DUT-ul in
    // afara protocolului si daca asa, daca DUT-ul reactioneaza gracios.
    cp_ack_primit: coverpoint cv_ack_primit {
      bins ack_ok    = {1'b1};
      bins ack_lipsa = {1'b0};
    }

    // ═══════════════════════════════════════════════════════════════
    //  CROSS-COVERAGE: cx_durata_latenta
    // ═══════════════════════════════════════════════════════════════
    // SCOP: am testat ca latenta de raspuns ramane CONSISTENTA indiferent
    // de durata obstacolului. Adica:
    //   - Obstacol scurt → ACK rapid?
    //   - Obstacol lung  → ACK la fel de rapid?
    //
    // Combinatii (durata × latenta_ack):
    //   scurt × imediat    → caz nominal pentru obstacol rapid
    //   scurt × un_ciclu   → caz acceptabil
    //   scurt × doi_cicli  → la limita
    //   mediu × imediat    → caz nominal pentru obstacol mediu
    //   mediu × un_ciclu   → acceptabil
    //   ...
    //
    // IGNORE_BINS — de ce excludem (durata, intarziat)?
    //
    // Motivul: asertiunile SVA garanteaza ca latenta_ack NU poate fi
    // > 2 cicluri (a_ack_la_rose_req cere raspuns combinatorial).
    // Asadar combinatiile (scurt × intarziat), (mediu × intarziat) si
    // (lung × intarziat) sunt LOGIC IMPOSIBILE intr-un DUT corect.
    // Daca ar exista, asertiunile ar fi prins eroarea.
    //
    // Le excludem cu ignore_bins pentru ca daca am cere acoperire 100%
    // si aceste bins NICIODATA nu se umplu (corect), atunci am avea
    // mereu < 100% — fals semnal de coverage incomplet.
    //
    // SINTAXA: binsof(cp_X.bin_Y) && binsof(cp_X.bin_Z) selecteaza
    // intersectia (combinatia specifica a celor 2 bins).
    cx_durata_latenta: cross cp_durata, cp_latenta_ack {
      ignore_bins ack_intarziat_scurt = binsof(cp_durata.scurt) &&
                                        binsof(cp_latenta_ack.intarziat);
      ignore_bins ack_intarziat_mediu = binsof(cp_durata.mediu) &&
                                        binsof(cp_latenta_ack.intarziat);
      ignore_bins ack_intarziat_lung  = binsof(cp_durata.lung)  &&
                                        binsof(cp_latenta_ack.intarziat);
    }

  endgroup

  // ═══════════════════════════════════════════════════════════════════
  //  CONSTRUCTOR
  // ═══════════════════════════════════════════════════════════════════
  // Instantierea covergroup-ului trebuie facuta EXPLICIT. Daca uitam, la
  // primul sample() vom avea null pointer dereference.
  function new();
    stari_req_ack_cg = new();
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  update() — copiaza datele tranzactiei in variabilele de sample
  // ═══════════════════════════════════════════════════════════════════
  // Apelata de monitorul REQ/ACK la fiecare obstacol observat (un ciclu
  // complet de REQ↑ → ACK↑ → REQ↓ → ACK↓). Dupa update(), monitorul
  // apeleaza stari_req_ack_cg.sample() pentru a inregistra valorile.
  function void update(tranzactie_req_ack tr);
    cv_durata_obstacol         = tr.durata_obstacol;
    cv_cicli_pana_la_ack       = tr.cicli_pana_la_ack;
    cv_cicli_pana_la_ack_clear = tr.cicli_pana_la_ack_clear;
    cv_ack_primit              = tr.ack_primit;
  endfunction

  // ═══════════════════════════════════════════════════════════════════
  //  print_coverage() — raport detaliat la sfarsitul simularii
  // ═══════════════════════════════════════════════════════════════════
  // INTERPRETARE TIPICA A RAPORTULUI:
  //
  //   100% pe cp_durata          → am variat durata obstacolelor (bun!)
  //   < 100% pe cp_durata        → testele genereaza doar un tip de durata
  //                                 → trebuie sa adaugam secvente cu
  //                                   obstacole scurte SI lungi
  //
  //   100% pe cp_latenta_ack     → DUT-ul a fost vazut raspunzand in toate
  //                                 modurile temporale interesante
  //   0% pe bin "intarziat"      → BUN — DUT-ul nu intarzie niciodata
  //
  //   100% pe cp_ack_primit.ack_ok    → DUT a raspuns intotdeauna
  //   0% pe cp_ack_primit.ack_lipsa   → BUN — niciodata nu a ratat un REQ
  //
  //   100% pe cx_durata_latenta  → am exercitat toate combinatiile valide
  function void print_coverage();
    $display("=== RAPORT COVERAGE REQ/ACK OBSTACOL ===");
    $display("  Acoperire totala     : %.2f%%", stari_req_ack_cg.get_coverage());
    $display("  cp_durata            : %.2f%%", stari_req_ack_cg.cp_durata.get_coverage());
    $display("  cp_latenta_ack       : %.2f%%", stari_req_ack_cg.cp_latenta_ack.get_coverage());
    $display("  cp_latenta_ack_clear : %.2f%%", stari_req_ack_cg.cp_latenta_ack_clear.get_coverage());
    $display("  cp_ack_primit        : %.2f%%", stari_req_ack_cg.cp_ack_primit.get_coverage());
    $display("  cx_durata_latenta    : %.2f%%", stari_req_ack_cg.cx_durata_latenta.get_coverage());
    $display("=========================================");
  endfunction

endclass

`endif
