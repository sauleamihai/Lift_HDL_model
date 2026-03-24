// Driver REQ/ACK - trimite butoane catre DUT prin req_ack_interface
// Acces direct la semnalele interfetei (compatibil Vivado xsim)

class button_driver;

  int no_transactions;

  virtual req_ack_interface req_ack_vif;
  mailbox gen2driv;

  function new(virtual req_ack_interface req_ack_vif, mailbox gen2driv);
    this.req_ack_vif = req_ack_vif;
    this.gen2driv    = gen2driv;
  endfunction

  task reset;
    $display("%0t [BUTTON DRIVER] Reset Started", $time);
    forever begin
      @(posedge req_ack_vif.clk);
      if (!req_ack_vif.reset) break;
    end
    req_ack_vif.buton_lift  <= 0;
    req_ack_vif.buton_scara <= 0;
    forever begin
      @(posedge req_ack_vif.clk);
      if (req_ack_vif.reset) break;
    end
    $display("%0t [BUTTON DRIVER] Reset Ended", $time);
  endtask

  task drive;
    button_transaction trans;
    gen2driv.get(trans);
    $display("%0t [BUTTON DRIVER] Transfer %0d", $time, no_transactions);
    repeat(trans.delay) @(posedge req_ack_vif.clk);
    req_ack_vif.buton_lift  <= trans.buton_lift;
    req_ack_vif.buton_scara <= trans.buton_scara;
    @(posedge req_ack_vif.clk); // puls de un ciclu
    req_ack_vif.buton_lift  <= 0;
    req_ack_vif.buton_scara <= 0;
    no_transactions++;
  endtask

  task main;
    forever begin
      fork
        begin wait(req_ack_vif.reset == 0); end
        begin forever drive(); end
      join_any
      disable fork;
    end
  endtask

endclass
