//Author: Popescu Vlad-Mihai
//Forțăm liftul să schimbe direcția: de la parter mergem mai întâi în sus (etaj 4), apoi, cât încă urcă, apăsăm un buton sub poziția curentă (etaj 1). Dorim să vedem că, după terminarea cererii în sus, algoritmul decide să coboare.

`include "environment.sv"

module test(output_interface  output_intf,
             apb_interface     apb_intf,
             req_ack_interface req_ack_intf);

  environment env;
  initial begin
    env = new(output_intf, apb_intf, req_ack_intf);

    env.apb_gen.random_transaction    = 0;
    env.gen_button.random_generation  = 0;

    // ========= STIMULI =========
    // Se cheamă liftul la etajul 4 (scară)
    env.gen_button.write_buttons(4, 0, 2);

    // După 12 cicluri (când e „pe drum") se solicită etajul 1 din cabina liftului
    env.gen_button.write_buttons(1, /*is_lift_btn=*/1, /*delay=*/12);

    // ========= AȘTEPTĂRI =========
    // Trebuie să se oprească la 4, apoi la 1
    env.scb.expected_stop_order.push_back(4);
    env.scb.expected_stop_order.push_back(1);

    env.run();
  end
endmodule
