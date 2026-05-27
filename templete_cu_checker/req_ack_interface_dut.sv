`ifndef __req_ack_intf
`define __req_ack_intf

// Interfata REQ/ACK explicita pentru senzorul de obstacol al usii:
//   obstacle_req (REQ) — senzorul trimite 1 cand detecteaza un obstacol
//   obstacle_ack (ACK) — DUT confirma ca tine usa deschisa

interface req_ack_interface_dut;

  logic clk;
  logic rst_n;
  logic obstacle_req;   // REQ: sensor -> DUT
  logic obstacle_ack;   // ACK: DUT -> sensor

  import uvm_pkg::*;

  // ── Assertiuni protocol REQ/ACK ───────────────────────────────────

  // 1. Cand REQ se ridica (front ascendent), ACK trebuie sa fie activ
  //    in acelasi ciclu (obstacle_ack este combinatorial in DUT)
  property p_ack_la_rose_req;
    @(posedge clk) disable iff (rst_n !== 1'b1)
    $rose(obstacle_req) |-> obstacle_ack;
  endproperty
  a_ack_la_rose_req: assert property(p_ack_la_rose_req)
    else `uvm_error("REQ_ACK_INTF",
      "VIOLATION: obstacle_ack nu s-a activat la frontul ascendent al obstacle_req")

  // 2. ACK nu poate fi activ fara REQ activ (fara obstacol, usa nu se tine)
  property p_ack_implica_req;
    @(posedge clk) disable iff (rst_n !== 1'b1)
    obstacle_ack |-> obstacle_req;
  endproperty
  a_ack_implica_req: assert property(p_ack_implica_req)
    else `uvm_error("REQ_ACK_INTF",
      "VIOLATION: obstacle_ack activ fara obstacle_req activ")

  // 3. Cand REQ coboara, ACK trebuie sa coboare in ciclul urmator
  property p_ack_clear_dupa_req;
    @(posedge clk) disable iff (rst_n !== 1'b1)
    $fell(obstacle_req) |=> !obstacle_ack;
  endproperty
  a_ack_clear_dupa_req: assert property(p_ack_clear_dupa_req)
    else `uvm_error("REQ_ACK_INTF",
      "VIOLATION: obstacle_ack nu s-a dezactivat dupa coborarea obstacle_req")

  // 4. In reset, ACK trebuie sa nu fie ACTIV (1'b1).
  //    Folosim "!== 1'b1" in loc de "!ack" pentru X-safe:
  //    daca obstacle_req nu este inca driven (X), obstacle_ack = X & ~X = X,
  //    iar "!X = X" ar fi raportat fals ca eroare. Cu "!== 1'b1", X trece.
  property p_ack_off_in_reset;
    @(posedge clk)
    (rst_n === 1'b0) |-> (obstacle_ack !== 1'b1);
  endproperty
  a_ack_off_in_reset: assert property(p_ack_off_in_reset)
    else `uvm_error("REQ_ACK_INTF",
      "VIOLATION: obstacle_ack activ in timpul resetului")

  // 5. ACK trebuie sa fie un PULS de exact 1 ciclu (combinatorial in DUT,
  //    activ doar la frontul ascendent al REQ)
  property p_ack_puls_un_ciclu;
    @(posedge clk) disable iff (rst_n !== 1'b1)
    obstacle_ack |=> !obstacle_ack;
  endproperty
  a_ack_puls_un_ciclu: assert property(p_ack_puls_un_ciclu)
    else `uvm_error("REQ_ACK_INTF",
      "VIOLATION: obstacle_ack a ramas activ mai mult de 1 ciclu (asteptat puls)")

endinterface

`endif
