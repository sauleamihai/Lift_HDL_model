// Interfata REQ/ACK pentru lift cu assertiuni (compatibil Vivado xsim)
// REQ: butoanele apasate (inputs catre DUT)
// ACK: LED-urile de confirmare (outputs din DUT)

interface req_ack_interface(input logic clk, input logic reset);

  // REQ - cereri de etaj
  logic [7:0] buton_lift;    // buton din cabina liftului
  logic [7:0] buton_scara;   // buton de pe scara

  // ACK - confirmari (LED aprins = cerere inregistrata, stins = etaj servit)
  logic [7:0] led_lift;
  logic [7:0] led_scara;

  // =====================================================================
  // Assertiuni REQ/ACK
  // =====================================================================

  // 1. Orice buton_lift apasat → led_lift trebuie sa se aprinda in ciclul urmator
  property p_lift_req_ack;
    @(posedge clk) disable iff (!reset)
    (|buton_lift) |-> ##1 (|led_lift);
  endproperty
  a_lift_req_ack: assert property(p_lift_req_ack)
    else $error("REQ/ACK VIOLATION: led_lift nu s-a aprins in 1 ciclu dupa buton_lift");
  c_lift_req_ack: cover property(p_lift_req_ack);

  // 2. Orice buton_scara apasat → led_scara trebuie sa se aprinda in ciclul urmator
  property p_scara_req_ack;
    @(posedge clk) disable iff (!reset)
    (|buton_scara) |-> ##1 (|led_scara);
  endproperty
  a_scara_req_ack: assert property(p_scara_req_ack)
    else $error("REQ/ACK VIOLATION: led_scara nu s-a aprins in 1 ciclu dupa buton_scara");
  c_scara_req_ack: cover property(p_scara_req_ack);

  // 3. Acelasi etaj nu poate fi cerut simultan din cabina SI de pe scara
  property p_no_double_request;
    @(posedge clk) disable iff (!reset)
    (buton_lift & buton_scara) == 8'b0;
  endproperty
  a_no_double_request: assert property(p_no_double_request)
    else $error("REQ/ACK VIOLATION: acelasi etaj cerut simultan din cabina si de pe scara");

  // 4. In timpul resetului, toate LED-urile trebuie sa fie stinse
  property p_leds_off_in_reset;
    @(posedge clk)
    !reset |-> (led_lift == 8'b0 && led_scara == 8'b0);
  endproperty
  a_leds_off_in_reset: assert property(p_leds_off_in_reset)
    else $error("REQ/ACK VIOLATION: LED-uri active in timpul resetului");

  // 5. Un singur etaj poate fi cerut odata (buton one-hot sau zero)
  property p_single_request;
    @(posedge clk) disable iff (!reset)
    $onehot0(buton_lift) && $onehot0(buton_scara);
  endproperty
  a_single_request: assert property(p_single_request)
    else $error("REQ/ACK VIOLATION: mai mult de un etaj cerut simultan");

endinterface
