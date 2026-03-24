// Monitor REQ/ACK - observa butonele si LED-urile din req_ack_interface
// Acces direct la semnalele interfetei (compatibil Vivado xsim)

class button_monitor;

  virtual req_ack_interface req_ack_interf;
  mailbox  button_mon2scb;

  event stop_mon;

  function new(
      virtual req_ack_interface req_ack_interf,
      mailbox  button_mon2scb
  );
    this.req_ack_interf = req_ack_interf;
    this.button_mon2scb = button_mon2scb;
  endfunction

  task main;
    button_transaction trans;

    forever begin
      if (stop_mon.triggered) break;

      @(posedge req_ack_interf.clk);

      trans = new();
      trans.buton_scara = req_ack_interf.buton_scara;
      trans.buton_lift  = req_ack_interf.buton_lift;

      button_mon2scb.put(trans);
    end
  endtask
endclass
