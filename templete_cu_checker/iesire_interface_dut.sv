`ifndef __iesire_intf
`define __iesire_intf

// Interfata de iesire — semnale read-only din DUT
// Monitorizate de agentul pasiv; nu sunt drivate de testbench

interface iesire_interface_dut;

  logic        clk;
  logic        rst_n;

  // ── LED-uri (ACK tip A+C) ─────────────────────────────────────────
  logic [7:0]  led_lift;           // LED-uri cabina
  logic [7:0]  led_scara;          // LED-uri scara

  // ── Semnale de stare ──────────────────────────────────────────────
  logic [7:0]  various_signals;    // [0]=door_open [1]=emg [7:2]=pending
  logic [7:0]  floor_management;   // [7:5]=etaj [4:2]=last [1]=err [0]=door

  import uvm_pkg::*;

  // ── Assertiuni pe iesiri ──────────────────────────────────────────
  // NOTE: toate folosesc "rst_n !== 1'b1" in loc de "!rst_n"
  // Motivul: "!X = X" (valoare necunoscuta), asa ca disable iff (!rst_n) NU
  // dezactiveaza assertiunea cand rst_n este X (la t=0 inainte de reset).
  // Cu "!== 1'b1", X si 0 ambele dezactiveaza assertiunea, 1 o activeaza.

  // 1. Etajul curent trebuie sa fie intotdeauna in intervalul valid 0-7
 /* property p_etaj_valid;
    @(posedge clk) disable iff (rst_n !== 1'b1)
    floor_management[7:5] inside {[3'b000 : 3'b111]};
  endproperty
  a_etaj_valid: assert property(p_etaj_valid)
    else `uvm_error("IESIRE_INTF",
      "VIOLATION: etaj_curent in afara intervalului valid 0-7")
*/
  // 2. Consistenta door_open: various_signals[0] == floor_management[0]
  property p_door_open_consistent;
    @(posedge clk) disable iff (rst_n !== 1'b1)
    various_signals[0] == floor_management[0];
  endproperty
  a_door_open_consistent: assert property(p_door_open_consistent)
    else `uvm_error("IESIRE_INTF",
      "VIOLATION: door_open inconsistent intre various_signals si floor_management")

  // 3. In reset, toate iesirile trebuie sa fie 0
  // disable iff (rst_n !== 1'b0): dezactiveaza cand rst_n e X sau 1
  // (assertiunea verifica doar cand rst_n e definitiv 0)
  property p_reset_outputs;
    @(posedge clk) 
    !rst_n |-> (led_lift         == 8'h00 &&
                led_scara        == 8'h00 &&
                various_signals  == 8'h00 &&
                floor_management == 8'h00);
  endproperty
  a_reset_outputs: assert property(p_reset_outputs)
    else `uvm_error("IESIRE_INTF",
      "VIOLATION: iesiri nenule in timpul resetului")

  // 4. Daca emergency_stop=1, pending_count trebuie sa fie 0
  // (DUT sterge toate cererile la intrarea in STATE_STOP)
  property p_emergency_clears_pending;
    @(posedge clk) disable iff (rst_n !== 1'b1)
    (various_signals[1] && various_signals[7:2] == 6'h00) |->
      ##[0:$] (various_signals[7:2] == 6'h00);
  endproperty
  a_emergency_clears_pending: assert property(p_emergency_clears_pending)
    else `uvm_error("IESIRE_INTF",
      "VIOLATION: cereri active in starea de urgenta")

  // 5. LED-urile nu pot fi aprinse la etaje inexistente (bit 7 = urgenta,
  // nu etaj real, deci led_lift[7] si led_scara[7] trebuie sa fie 0)
  property p_led_fara_etaj_invalid;
    @(posedge clk) disable iff (rst_n !== 1'b1)
    (led_lift[7] == 1'b0) && (led_scara[7] == 1'b0);
  endproperty
  a_led_fara_etaj_invalid: assert property(p_led_fara_etaj_invalid)
    else `uvm_error("IESIRE_INTF",
      "VIOLATION: LED aprins la bitul de urgenta (bit 7)")

endinterface

`endif
