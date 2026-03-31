//Author: Popescu Vlad-Mihai
// Test 1: Fortam liftul sa schimbe directia: de la parter mergem mai intai in sus (etaj 4),
//         apoi, cat inca urca, apasam un buton sub pozitia curenta (etaj 1).
//         Dorim sa vedem ca, dupa terminarea cererii in sus, algoritmul decide sa coboare.
// Test 2: La deschiderea usii la etajul 4, simulam un obstacol (om in usa) timp de 6 cicluri.
//         Verificam ca FSM ramane in STATE_DOOR_OPEN si obstacle_ack este activ,
//         iar dupa eliminarea obstacolului usa se inchide normal.

`include "environment.sv"

module test(output_interface   output_intf,
             apb_interface      apb_intf,
             req_ack_interface  req_ack_intf,
             obstacle_interface obstacle_intf);

  environment env;
  initial begin
    env = new(output_intf, apb_intf, req_ack_intf, obstacle_intf);

    env.apb_gen.random_transaction    = 0;
    env.gen_button.random_generation  = 0;

    // ========= STIMULI BUTOANE =========
    // Se cheama liftul la etajul 4 (scara)
    env.gen_button.write_buttons(4, 0, 2);

    // Dupa 12 cicluri (cand e pe drum) se solicita etajul 1 din cabina liftului
    env.gen_button.write_buttons(1, /*is_lift_btn=*/1, /*delay=*/12);

    env.apb_gen.write_reg(1, 8'h40);
    env.apb_gen.read_reg(1);

    // ========= STIMULI OBSTACOL =========
    // Fork independent: asteapta prima deschidere a usii (door_open = various_signals[0])
    // si simuleaza un obstacol detectat de senzor timp de 6 cicluri de ceas
    fork
      begin
        // Asteapta rising edge pe door_open (FSM intra in STATE_DOOR_OPEN)
        @(posedge output_intf.various_signals[0]);
        $display("[OBSTACLE TEST] Usa deschisa la etajul %0d - obstacol detectat!",
                 output_intf.floor_management[7:5]);

        // Activeaza senzorul de obstacol
        obstacle_intf.req = 1'b1;

        // Tine obstacolul activ 6 cicluri (mai mult decat DOOR_OPEN_CYCLES=3)
        // In aceasta perioada FSM trebuie sa ramana in STATE_DOOR_OPEN
        repeat(6) @(posedge obstacle_intf.clk);

        // Elimina obstacolul - timerul reia numarararea normala
        obstacle_intf.req = 1'b0;
        $display("[OBSTACLE TEST] Obstacol eliminat - usa se inchide normal");
      end
    join_none

    // ========= ASTEPTARI =========
    // Trebuie sa se opreasca la 4, apoi la 1
    env.scb.expected_stop_order.push_back(4);
    env.scb.expected_stop_order.push_back(1);

    env.run();
  end
endmodule
