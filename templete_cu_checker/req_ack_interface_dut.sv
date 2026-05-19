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

  // 1. Cand REQ se ridica, ACK trebuie sa urmeze in ciclul imediat urmator
  property p_ack_urmeaza_req;
    @(posedge clk) disable iff (!rst_n)
    $rose(obstacle_req) |=> obstacle_ack;
  endproperty
  a_ack_urmeaza_req: assert property(p_ack_urmeaza_req)
    else `uvm_error("REQ_ACK_INTF",
      "VIOLATION: obstacle_ack nu a urmat obstacle_req in 1 ciclu")

  // 2. ACK nu poate fi activ fara REQ activ (fara obstacol, usa nu se tine)
  property p_ack_implica_req;
    @(posedge clk) disable iff (!rst_n)
    obstacle_ack |-> obstacle_req;
  endproperty
  a_ack_implica_req: assert property(p_ack_implica_req)
    else `uvm_error("REQ_ACK_INTF",
      "VIOLATION: obstacle_ack activ fara obstacle_req activ")

  // 3. Cand REQ coboara, ACK trebuie sa coboare in ciclul urmator
  property p_ack_clear_dupa_req;
    @(posedge clk) disable iff (!rst_n)
    $fell(obstacle_req) |=> !obstacle_ack;
  endproperty
  a_ack_clear_dupa_req: assert property(p_ack_clear_dupa_req)
    else `uvm_error("REQ_ACK_INTF",
      "VIOLATION: obstacle_ack nu s-a dezactivat dupa coborarea obstacle_req")

  // 4. In reset, ACK trebuie sa fie dezactivat
  property p_ack_off_in_reset;
    @(posedge clk)
    !rst_n |-> !obstacle_ack;
  endproperty
  a_ack_off_in_reset: assert property(p_ack_off_in_reset)
    else `uvm_error("REQ_ACK_INTF",
      "VIOLATION: obstacle_ack activ in timpul resetului")

  // 5. Daca REQ e activ dar ACK nu a venit inca, ACK trebuie sa vina in max 2 cicluri
  property p_ack_raspuns_limitat;
    @(posedge clk) disable iff (!rst_n)
    (obstacle_req && !obstacle_ack) |-> ##[1:2] obstacle_ack;
  endproperty
  a_ack_raspuns_limitat: assert property(p_ack_raspuns_limitat)
    else `uvm_error("REQ_ACK_INTF",
      "VIOLATION: obstacle_ack nu a venit in 2 cicluri de la obstacle_req")

endinterface

`endif
