// tranzactiile din acest text se genereaza complet aleatoriu (singura constrangere
// fiind in fisierul transaction.sv, aceasta asigurand functionalitatea corecta a DUT-ului)
`include "environment.sv"
module test(output_interface output_intf, apb_interface apb_intf, req_ack_interface req_ack_intf);

  //declaring environment instance
  environment env;

  initial begin
    //creating environment
    env = new(output_intf, apb_intf, req_ack_intf);

    //setting the repeat count of generator as 4, means to generate 4 packets
    env.apb_gen.repeat_count = 4;
    env.apb_gen.random_transaction = 1;

    env.gen_button.repeat_count = 4;
    env.gen_button.random_generation = 1;

    //calling run of env, it interns calls generator and driver main tasks.
    env.run();
  end
endmodule
