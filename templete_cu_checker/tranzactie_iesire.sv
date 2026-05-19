`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __iesire_transaction
`define __iesire_transaction

// Tranzactia captureaza o imagine instantanee a tuturor iesirilor DUT-ului
// la un moment dat: LED-uri, semnale de stare si management etaje

class tranzactie_iesire extends uvm_sequence_item;

  `uvm_object_utils(tranzactie_iesire)

  // ── LED-uri (ACK tip A+C) ──────────────────────────────────────────
  bit [7:0] led_lift;          // bit i=1: cerere etaj i cabina activa
  bit [7:0] led_scara;         // bit i=1: cerere etaj i scara activa

  // ── Semnale de stare (various_signals) ────────────────────────────
  // bit[0] = door_open | bit[1] = emergency_stop | bits[7:2] = pending_count
  bit [7:0] various_signals;

  // ── Management etaje (floor_management) ──────────────────────────
  // bits[7:5] = etaj_curent | bits[4:2] = ultim_etaj_servit
  // bit[1] = eroare         | bit[0]    = door_open
  bit [7:0] floor_management;

  // ── Campuri decodate (pentru scoreboard si coverage) ──────────────
  bit        door_open;         // usa deschisa (din various_signals[0])
  bit        emergency_stop;    // urgenta activa (din various_signals[1])
  bit [5:0]  pending_count;     // cereri in asteptare (various_signals[7:2])
  bit [2:0]  etaj_curent;       // etaj curent (floor_management[7:5])
  bit [2:0]  ultim_etaj_servit; // ultimul etaj servit (floor_management[4:2])
  bit        eroare;            // bit eroare (floor_management[1])

  function new(string name = "tranzactie_iesire");
    super.new(name);
  endfunction

  // Decodeaza campurile din vectorii bruti
  function void decodeaza();
    door_open         = various_signals[0];
    emergency_stop    = various_signals[1];
    pending_count     = various_signals[7:2];
    etaj_curent       = floor_management[7:5];
    ultim_etaj_servit = floor_management[4:2];
    eroare            = floor_management[1];
  endfunction

  function void afiseaza_informatia_tranzactiei();
    decodeaza();
    $display("[IESIRE TRZ] etaj=%0d | door_open=%0b | emergency=%0b | pending=%0d | led_lift=0x%02h | led_scara=0x%02h | eroare=%0b",
             etaj_curent, door_open, emergency_stop, pending_count,
             led_lift, led_scara, eroare);
  endfunction

  function tranzactie_iesire copy();
    copy                    = new();
    copy.led_lift           = this.led_lift;
    copy.led_scara          = this.led_scara;
    copy.various_signals    = this.various_signals;
    copy.floor_management   = this.floor_management;
    copy.door_open          = this.door_open;
    copy.emergency_stop     = this.emergency_stop;
    copy.pending_count      = this.pending_count;
    copy.etaj_curent        = this.etaj_curent;
    copy.ultim_etaj_servit  = this.ultim_etaj_servit;
    copy.eroare             = this.eroare;
    return copy;
  endfunction

endclass
`endif
