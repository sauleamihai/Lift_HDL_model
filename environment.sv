`include "transaction_out.sv"
`include "apb_transaction.sv"
`include "button_transaction.sv"
`include "button_monitor.sv"
`include "coverage_out.sv"
`include "monitor_out.sv"

`include "apb_coverage.sv"
`include "monitor_apb.sv"
`include "generator_apb.sv"
`include "button_generator.sv"
`include "apb_driver.sv"
`include "button_driver.sv"
`include "scoreboard.sv"

class environment;

  generator_apb    apb_gen;
  button_generator gen_button;
  apb_driver       apb_driv;
  button_driver    button_driv;
  monitor_out      mon_out;
  monitor_apb      mon_apb;
  button_monitor   mon_button;
  scoreboard       scb;

  mailbox apb_gen2driv, button_gen2driv;
  mailbox apb_mon2scb,  button_mon2scb;
  mailbox out_mon2scb;

  virtual output_interface   out_interf;
  virtual apb_interface      apb_interf;
  virtual req_ack_interface  req_ack_interf;

  function new(
      virtual output_interface  out_interf,
      virtual apb_interface     apb_interf,
      virtual req_ack_interface req_ack_interf
  );
    this.out_interf     = out_interf;
    this.apb_interf     = apb_interf;
    this.req_ack_interf = req_ack_interf;

    apb_gen2driv    = new();
    apb_mon2scb     = new();
    button_gen2driv = new();
    button_mon2scb  = new();
    out_mon2scb     = new();

    scb         = new(apb_mon2scb, button_mon2scb, out_mon2scb);
    apb_gen     = new(apb_gen2driv);
    gen_button  = new(button_gen2driv);
    apb_driv    = new(apb_interf,      apb_gen2driv);
    button_driv = new(req_ack_interf,  button_gen2driv);
    mon_apb     = new(apb_interf,      apb_mon2scb);
    mon_button  = new(req_ack_interf,  button_mon2scb);
    mon_out     = new(out_interf,      out_mon2scb);
  endfunction

  task pre_test();
    fork
      apb_driv.reset();
      button_driv.reset();
    join
  endtask

  task test();
    fork
      apb_gen.main();
      apb_driv.main();
      gen_button.main();
      button_driv.main();
      mon_apb.main();
      mon_button.main();
      mon_out.main();
      scb.main();
    join_any
  endtask

  task post_test();
    // asteapta sfarsitul generatoarelor
    wait(apb_gen.ended.triggered);
    wait(gen_button.ended.triggered);
    // opreste monitoarele
    -> mon_apb.stop_mon;
    -> mon_button.stop_mon;
  endtask

  function void report();
    $display("--- COVERAGE APB ---");
    mon_apb.cov_apb.print_coverage();
    $display("--- COVERAGE OUT ---");
    mon_out.coverage_collector.print_coverage();
  endfunction

  task run;
    fork
      begin
        pre_test();
        test();
        post_test();
        #5000;
        report();
        $finish;
      end
      begin
        #100_000;
        $display("*** WATCH-DOG: simulare incheiata fortat ***");
        $finish;
      end
    join_any
  endtask

endclass
