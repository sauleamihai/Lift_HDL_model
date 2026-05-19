`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __scoreboard
`define __scoreboard

// Declarare porturi de analiza multiple (cate unul per agent)
`uvm_analysis_imp_decl(_apb)
`uvm_analysis_imp_decl(_req_ack)
`uvm_analysis_imp_decl(_iesire)

class scoreboard extends uvm_scoreboard;

  `uvm_component_utils(scoreboard)

  // ── Porturi de intrare (unul per agent) ─────────────────────────────
  uvm_analysis_imp_apb     #(tranzactie_apb,     scoreboard) port_pentru_datele_de_la_apb;
  uvm_analysis_imp_req_ack #(tranzactie_req_ack, scoreboard) port_pentru_datele_de_la_req_ack;
  uvm_analysis_imp_iesire  #(tranzactie_iesire,  scoreboard) port_pentru_datele_de_la_iesire;

  // ── Ultima tranzactie primita de la fiecare agent ────────────────────
  tranzactie_apb     ultima_tranzactie_apb;
  tranzactie_req_ack ultima_tranzactie_req_ack;
  tranzactie_iesire  ultima_tranzactie_iesire;

  // ── Cozi pentru verificari incrucisate ──────────────────────────────
  tranzactie_apb     coada_apb[$];
  tranzactie_req_ack coada_req_ack[$];
  tranzactie_iesire  coada_iesire[$];

  // ── Contoare pentru raport final ────────────────────────────────────
  int erori_detectate;
  int verificari_trecute;

  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
    port_pentru_datele_de_la_apb     = new("port_apb",     this);
    port_pentru_datele_de_la_req_ack = new("port_req_ack", this);
    port_pentru_datele_de_la_iesire  = new("port_iesire",  this);
    erori_detectate   = 0;
    verificari_trecute = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ultima_tranzactie_apb     = tranzactie_apb::type_id::create("ultima_apb");
    ultima_tranzactie_req_ack = tranzactie_req_ack::type_id::create("ultima_req_ack");
    ultima_tranzactie_iesire  = tranzactie_iesire::type_id::create("ultima_iesire");
  endfunction

  // ── Handler tranzactii APB ───────────────────────────────────────────
  function void write_apb(input tranzactie_apb tr);
    `uvm_info("SCOREBOARD", "Tranzactie APB primita:", UVM_HIGH)
    tr.afiseaza_informatia_tranzactiei();
    ultima_tranzactie_apb = tr.copy();
    coada_apb.push_back(ultima_tranzactie_apb);

    // Verificare: scriere la adresa invalida nu trebuie sa afecteze starea
    if (tr.rw == 1'b1 && tr.addr > 8'h01)
      `uvm_error("SCOREBOARD",
        $sformatf("Scriere la adresa read-only 0x%02h detectata!", tr.addr))

    verifica_consistenta_apb_iesire(tr);
  endfunction

  // ── Handler tranzactii REQ/ACK obstacol ─────────────────────────────
  function void write_req_ack(input tranzactie_req_ack tr);
    `uvm_info("SCOREBOARD", "Tranzactie REQ/ACK primita:", UVM_HIGH)
    tr.afiseaza_informatia_tranzactiei();
    ultima_tranzactie_req_ack = tr.copy();
    coada_req_ack.push_back(ultima_tranzactie_req_ack);

    // Verificare 1: ACK trebuie sa fie primit
    if (!tr.ack_primit) begin
      `uvm_error("SCOREBOARD",
        "REQ/ACK: obstacle_ack nu a fost primit dupa obstacle_req!")
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end

    // Verificare 2: latenta ACK trebuie sa fie maxim 1 ciclu
    if (tr.cicli_pana_la_ack > 1) begin
      `uvm_error("SCOREBOARD",
        $sformatf("REQ/ACK: latenta ACK = %0d cicluri (maxim permis: 1)",
                  tr.cicli_pana_la_ack))
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end

    // Verificare 3: ACK clear trebuie sa vina in 1 ciclu dupa REQ=0
    if (tr.cicli_pana_la_ack_clear > 1) begin
      `uvm_error("SCOREBOARD",
        $sformatf("REQ/ACK: ACK clear dupa %0d cicluri (maxim permis: 1)",
                  tr.cicli_pana_la_ack_clear))
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end
  endfunction

  // ── Handler tranzactii iesiri DUT ───────────────────────────────────
  function void write_iesire(input tranzactie_iesire tr);
    `uvm_info("SCOREBOARD", "Tranzactie IESIRE primita:", UVM_HIGH)
    tr.afiseaza_informatia_tranzactiei();
    ultima_tranzactie_iesire = tr.copy();
    coada_iesire.push_back(ultima_tranzactie_iesire);

    // Verificare 1: etaj curent in interval valid
    if (tr.etaj_curent > 3'd7) begin
      `uvm_error("SCOREBOARD",
        $sformatf("IESIRE: etaj_curent=%0d in afara intervalului [0:7]!",
                  tr.etaj_curent))
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end

    // Verificare 2: door_open consistent intre cele doua registre
    if (tr.various_signals[0] !== tr.floor_management[0]) begin
      `uvm_error("SCOREBOARD",
        "IESIRE: door_open inconsistent intre various_signals si floor_management!")
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end

    // Verificare 3: LED bit 7 mereu stins (bit 7 = urgenta, nu etaj fizic)
    if (tr.led_lift[7] || tr.led_scara[7]) begin
      `uvm_error("SCOREBOARD",
        "IESIRE: LED aprins la bit 7 (bit de urgenta, nu etaj fizic)!")
      erori_detectate++;
    end else begin
      verificari_trecute++;
    end
  endfunction

  // ── Verificare incrucisata APB <-> Iesiri ───────────────────────────
  // Dupa o scriere APB la buton_lift/buton_scara,
  // LED-urile corespunzatoare trebuie sa se aprinda
  function void verifica_consistenta_apb_iesire(tranzactie_apb tr_apb);
    if (tr_apb.rw == 1'b1 && coada_iesire.size() > 0) begin
      tranzactie_iesire tr_out = coada_iesire[$]; // ultima iesire
      case (tr_apb.addr)
        8'h00: begin // buton_scara scris
          if ((tr_out.led_scara & tr_apb.data) != tr_apb.data)
            `uvm_warning("SCOREBOARD",
              $sformatf("LED scara 0x%02h nu reflecta cererea APB 0x%02h (poate inca in tranzit)",
                        tr_out.led_scara, tr_apb.data))
        end
        8'h01: begin // buton_lift scris
          if (tr_apb.data != 8'h80) begin // ignoram urgenta
            if ((tr_out.led_lift & tr_apb.data) != tr_apb.data)
              `uvm_warning("SCOREBOARD",
                $sformatf("LED lift 0x%02h nu reflecta cererea APB 0x%02h (poate inca in tranzit)",
                          tr_out.led_lift, tr_apb.data))
          end
        end
        default: ;
      endcase
    end
  endfunction

  // ── Raport final ────────────────────────────────────────────────────
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    $display("╔══════════════════════════════════════╗");
    $display("║        RAPORT FINAL SCOREBOARD       ║");
    $display("╠══════════════════════════════════════╣");
    $display("║  Tranzactii APB      : %4d          ║", coada_apb.size());
    $display("║  Tranzactii REQ/ACK  : %4d          ║", coada_req_ack.size());
    $display("║  Tranzactii Iesire   : %4d          ║", coada_iesire.size());
    $display("╠══════════════════════════════════════╣");
    $display("║  Verificari trecute  : %4d          ║", verificari_trecute);
    $display("║  Erori detectate     : %4d          ║", erori_detectate);
    $display("╠══════════════════════════════════════╣");
    if (erori_detectate == 0)
      $display("║  STATUS: ** TOATE TESTELE TRECUTE ** ║");
    else
      $display("║  STATUS: !! %4d ERORI DETECTATE !!  ║", erori_detectate);
    $display("╚══════════════════════════════════════╝");
  endfunction

endclass
`endif
