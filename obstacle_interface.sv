// Interfata REQ/ACK pentru senzorul de obstacol al usii liftului
// REQ: senzorul detecteaza un obstacol in calea usii → trimite semnal catre DUT
// ACK: DUT confirma ca a receptionat semnalul si tine usa deschisa

`ifndef OBSTACLE_INTERFACE_SV
`define OBSTACLE_INTERFACE_SV

interface obstacle_interface(input logic clk, input logic reset);

  logic req;  // senzor → DUT: obstacol detectat in calea usii
  logic ack;  // DUT → senzor: usa este tinuta deschisa

  // =====================================================================
  // Assertiuni REQ/ACK senzor obstacol
  // =====================================================================

  // 1. Cand REQ se ridica, ACK trebuie sa urmeze in ciclul imediat urmator
  property p_req_ack_response;
    @(posedge clk) disable iff (!reset)
    $rose(req) |=> ack;
  endproperty
  a_req_ack_response: assert property(p_req_ack_response)
    else $error("OBSTACLE VIOLATION: ACK nu a urmat REQ in 1 ciclu");
  c_req_ack_response: cover property(p_req_ack_response);

  // 2. ACK nu poate fi activ fara ca REQ sa fie activ (fara obstacol, usa nu se tine)
  property p_ack_needs_req;
    @(posedge clk) disable iff (!reset)
    ack |-> req;
  endproperty
  a_ack_needs_req: assert property(p_ack_needs_req)
    else $error("OBSTACLE VIOLATION: ACK activ fara REQ activ");

  // 3. Cand REQ coboara, ACK trebuie sa coboare in ciclul urmator
  property p_ack_clears_after_req;
    @(posedge clk) disable iff (!reset)
    $fell(req) |=> !ack;
  endproperty
  a_ack_clears_after_req: assert property(p_ack_clears_after_req)
    else $error("OBSTACLE VIOLATION: ACK nu s-a dezactivat dupa coborarea REQ");
  c_ack_clears_after_req: cover property(p_ack_clears_after_req);

  // 4. In timpul resetului, ACK trebuie sa fie dezactivat
  property p_ack_off_in_reset;
    @(posedge clk)
    !reset |-> !ack;
  endproperty
  a_ack_off_in_reset: assert property(p_ack_off_in_reset)
    else $error("OBSTACLE VIOLATION: ACK activ in timpul resetului");

  // 5. Daca REQ este activ dar ACK inca nu, ACK trebuie sa vina in maxim 2 cicluri
  property p_ack_bounded_response;
    @(posedge clk) disable iff (!reset)
    (req && !ack) |-> ##[1:2] ack;
  endproperty
  a_ack_bounded_response: assert property(p_ack_bounded_response)
    else $error("OBSTACLE VIOLATION: ACK nu a venit in 2 cicluri de la REQ");
  c_ack_bounded_response: cover property(p_ack_bounded_response);

endinterface

`endif // OBSTACLE_INTERFACE_SV
