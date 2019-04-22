
module GT_IFU(inst_addr, GCLK, CLEAR_BAR, CTR_EN);
  
/***********************************************************************************
Global Declarations
***********************************************************************************/  
input GCLK;//CLEAR_BAR, CTR_EN
output CTR_EN, CLEAR_BAR;       
output [31:0] inst_addr;

reg CLEAR_BAR;
reg CTR_EN;  //Making CTR_EN a changeable register
reg clk;
integer count;  //Substitute for ctr_out

/***********************************************************************************
Declarations for Functional Unit
***********************************************************************************/
reg [3:0] opcode;
reg [31:0] dst_reg;
reg [31:0] src_reg1;
reg [31:0] src_reg2;


reg [31:0] inst_addr;
reg [31:0] addr_stream_mem[63:0];    
wire [31:0] ctr_out;  /* sequence number from the counter */
integer i;



/***********************************************************************************
Declarations for Register File
***********************************************************************************/
integer tv;   //Register tag value, 0 = data, 1 = tag
reg [31:0] register[15:0]; //Contents of the register

/***********************************************************************************
Declarations for Reservation Station
***********************************************************************************/
reg [31:0] rsa[0:3];  //Operand A of RS
reg [31:0] rsb[0:3];  //Operand B of RS 
reg rs_busy[0:3];     //Busy condition of all reservation stations
reg [3:0] rsopcode[0:3];  //Opcode that is present in a particular reservation station
reg flag;  //flag used for avoiding use of if-else
reg [2:0] rsa_tag[0:3];  //Tag of Operand A
reg [2:0] rsb_tag[0:3];  //Tag of Operand B




/***********************************************************************************
Declarations for Execution unit
***********************************************************************************/
reg [3:0] rsopready;  //opcode in RS which is ready to execute but unable to do so since functional unit is busy
reg [3:0] rsopdispatch;  //opcode in RS to be executed next in functional unit
reg [31:0] dst_sum_reg;  //Destination register tag for sum func unit
reg [31:0] dst_mult_reg; //Destination register tag for mult func unit 
reg [31:0] dst_div_reg;  //Destination register tag for div func unit 
integer rs_id_func;      //Displays which functional unit uses which RS's operands
reg flag1;   //used to avoid if-else
reg [31:0] a; //Operand A in functional unit
reg [31:0] b;  //Operand B in functional unit
reg [31:0] sum; 
reg [31:0] diff;
reg [31:0] mult;
reg [31:0] div;
reg sum_busy;  //addition/subtraction functional unit busy status
reg mult_busy; //multiplication functional unit busy status 
reg div_busy;  //division functional unit busy status
reg sum_ready; //addition/subtraction functional unit addition complete status (not considering latency for WB)
reg mult_ready;//multiplication functional unit multiplication complete status (not considering latency for WB)
reg div_ready;//division functional unit division complete status (not considering latency for WB)

   
Sync_counter_32bit Ctr_imem (.out(ctr_out), .clock(GCLK), .clear_bar(CLEAR_BAR), .count_en(CTR_EN));

initial 
begin   

/***********************************************************************************
Initial Values for Functional Unit
***********************************************************************************/ 
  // description of 32 bit instruction // 32'b oper_dest_src1_src2_next_16_bits_ignored 
  addr_stream_mem[0] = 32'h0000_0000;  // 32'b 0000_0000_0000_0000_0000_0000_0000_0000 = add r0, r0, r0 
  addr_stream_mem[1] = 32'h1123_0000;  // 32'b 0001_0001_0010_0011_0000_0000_0000_0000 = sub r1, r2, r3
  addr_stream_mem[2] = 32'h2423_0000;  // 32'b 0010_0100_0010_0011_0000_0000_0000_0000 = mul r4, r2, r3
  addr_stream_mem[3] = 32'h3523_0000;  // 32'b 0011_0101_0010_0011_0000_0000_0000_0000 = div r5, r2, r3
  addr_stream_mem[4] = 32'h0544_0000;  // 32'b 0000_0101_0100_0100_0000_0000_0000_0000 = add r5, r4, r4
  addr_stream_mem[5] = 32'h1655_0000;  // 32'b 0001_0110_0101_0101_0000_0000_0000_0000 = sub r6, r5, r5
  addr_stream_mem[6] = 32'h2500_0000;  // 32'b 0010_0101_0000_0000_0000_0000_0000_0000 = mul r5, r0, r0
  addr_stream_mem[7] = 32'h2511_0000;  // 32'b 0010_0101_0001_0001_0000_0000_0000_0000 = mul r5, r1, r1
  addr_stream_mem[8] = 32'hf000_0000;  // 32'b 1111_0000_0000_0000_0000_0000_0000_0000 = hlt 

  inst_addr = addr_stream_mem[0];  
  count = 0;
  CLEAR_BAR = 0;
  CTR_EN = 1;
  // CLK
  clk = 1;
  
/***********************************************************************************
Initial Values for Reservation Station
***********************************************************************************/ 
  for (i=0; i<16; i=i+1)
  begin
    register[i] <= 32'b0000_0000_0000_0101;
    tv[i] <= 0;
  end
  //For RS
  for (i=0; i<4; i=i+1)
  begin
    rs_busy[i] = 0;
    rsopcode[i] = 4'hxxxx;
    rsa_tag[i] = 3'bxxx;
    rsb_tag[i] = 3'bxxx;
  end
/***********************************************************************************
Initial Values for Execution Unit
***********************************************************************************/
  rsopdispatch = 4'bxxxx;
  sum_busy = 0;
  mult_busy = 0;
  div_busy = 0;
end





/***********************************************************************************
Creation of a custom Clock independent of GCLK. This clock operates only on the change of "count" (defined below)
***********************************************************************************/
always begin
  #50 clk = ~clk; 
end     

always @(posedge GCLK) begin
CLEAR_BAR = #100 1;
end 
/***********************************************************************************
Creation of a custom Counter based on ctr_out. Each change of ctr_out increments count by 1
***********************************************************************************/
always @(ctr_out)
begin
   count = count +1;
end

   
/***********************************************************************************
Instruction Fetching and storing them in temporary variables
***********************************************************************************/  
always @(count)
begin
   inst_addr = addr_stream_mem[ctr_out];
   opcode = inst_addr[31:28];
   dst_reg = inst_addr[27:24];
   src_reg1 = inst_addr[23:20];
   src_reg2 = inst_addr[19:16];
   flag = 0;
   if (opcode == 4'b1111)begin
    CTR_EN = 0;
  end
 end
 
/***********************************************************************************
Writing Fetched Instructions into Reservation Station
***********************************************************************************/  
 
 always @(negedge clk) 
begin
      if (opcode == 4'b1111) begin
      //Do not fill the reservation station if opcode = 1111
    end
    /***************For RS0******************/
  else begin
    if ((rs_busy[0]==0) && (flag==0))
     begin
        //For source operand A
       if (tv[src_reg1] ==0)begin
           rsa[0] <= register[src_reg1];  //If tag value = 0, register contains data value. So write that to the operand A in RS[0]
           rsa_tag[0] <= 3'b101;          // Set TAG of that operand = 5. TAG = 5 means that the data is available and ready to be sent to the functional unit 
         end
       else begin
           rsa_tag[0] <= register[src_reg1]; //If tag value = 1, register contains the actal TAG
         end
       
       //For source operand B
       if (tv[src_reg2] ==0)begin
           rsb[0] <= register[src_reg2];
           rsb_tag[0] <= 3'b101;
         end
       else begin
           rsb_tag[0] <= register[src_reg2];
         end
       
       //For Destination operand
       tv[dst_reg] <= 1; //Setting Tag value of destination register to 1
       register[dst_reg] <= 2'b00; // Setting the TAG of destination register to Reservation station ID (0 in this case)
       rsopcode[0] <= opcode; //temporary registers to stopre opcode value accessible in the execution unit
       rs_busy[0] <= 1'b1; //Setting the reservation station to busy
       flag = 1;   
       if (count ==0) begin  //Do not set rs_busy[0] = 0 when the processor has just booted up and this condition is true
       rs_busy[0] <=1'b0;
     end   
     end
     
     /***************For RS1******************/
     else if ((rs_busy[1]==0) && (flag==0))
     begin
        //For source operand A
       if (tv[src_reg1] ==0) begin
           rsa[1] <= register[src_reg1];
           rsa_tag[1] <= 3'b101;
         end
       else begin
           rsa_tag[1] <= register[src_reg1];
         end
       
       //For source operand B
       if (tv[src_reg2] ==0) begin
           rsb[1] <= register[src_reg2];
           rsb_tag[1] <= 3'b101;
         end
       else begin
           rsb_tag[1] <= register[src_reg2];
         end
       
       //For Destination operand
       tv[dst_reg] <= 1;
       register[dst_reg] <= 2'b01;
       rsopcode[1] <= opcode;
       rs_busy[1] <= 1'b1;
       flag = 1;    
     end
     
     /***************For RS2******************/
     else if ((rs_busy[2]==0) && (flag==0))
     begin
       //For source operand A
       if (tv[src_reg1] ==0) begin
           rsa[2] <= register[src_reg1];
           rsa_tag[2] <= 3'b101;
         end
       else begin
           rsa_tag[2] <= register[src_reg1];
         end
       
       //For source operand B
       if (tv[src_reg2] ==0) begin
           rsb[2] <= register[src_reg2];
           rsb_tag[2] <= 3'b101;
         end
       else begin
           rsb_tag[2] <= register[src_reg2];
         end
       
       //For Destination operand
       tv[dst_reg] <= 1;
       register[dst_reg] <= 2'b10;
       rsopcode[2] <= opcode;
       rs_busy[2] <= 1'b1;
       flag = 1;     
     end
     /***************For RS3******************/
     else if ((rs_busy[3]==0) && (flag==0))
     begin
       //For source operand A
       if (tv[src_reg1] ==0) begin
           rsa[3] <= register[src_reg1];
           rsa_tag[3] <= 3'b101;
         end
       else begin
           rsa_tag[3] <= register[src_reg1];
         end
       
       //For source operand B
       if (tv[src_reg2] ==0) begin
           rsb[3] <= register[src_reg2];
           rsb_tag[3] <= 3'b101;
         end
       else begin
           rsb_tag[3] <= register[src_reg2];
         end
       
       //For Destination operand
       tv[dst_reg] <= 1;
       register[dst_reg] <= 2'b11;
       rsopcode[3] <= opcode;
       rs_busy[3] <= 1'b1;
       flag = 1;
     end
   flag = 0;
    end  
// end 
end




/***********************************************************************************
Execution Unit
***********************************************************************************/ 

always @(posedge GCLK)
begin
flag1 =0;
/***************FOR RS 0 *************/

if ((rs_busy[0] == 1) && (flag1 == 0)) begin
     if ((rsa_tag[0] == 5) && (rsb_tag[0] == 5)) begin
        rsopready = rsopcode[0]; //temporary registers used for debugging
        if ((rsopcode[0] == 0) && (sum_busy==0)) begin
           rsopdispatch = rsopready; 
           flag1=1;
           a = rsa[0]; //operand A of RS assigned to operand A of Functional unit
           b = rsb[0]; //operand B of RS assigned to operand B of Functional unit 
           rsopcode[0] <= #50 4'bxxxx; // Setting these values to don't care after their utility has been satisfied
           rsopready <= 4'bxxxx;
           rsa_tag[0] <= 3'bxxx;
           rsb_tag[0] <= 3'bxxx; 
           rs_id_func <= 2'b00;
           sum_busy <= 1;
           sum_ready <= 0; 
           sum =  #100 (a+b);
           sum_ready <= #100 1;
           rs_busy[0] <= #150 0;
           dst_sum_reg <= 2'b00;
        end
      else if ((rsopcode[0] == 1) && (sum_busy==0)) begin
           rsopdispatch = rsopready;
           flag1=1;
           a = rsa[0];
           b = rsb[0];
           rsopcode[0] <= #50 4'bxxxx;
           rsopready <= 4'bxxxx;
           rsa_tag[0] <= 3'bxxx;
           rsb_tag[0] <= 3'bxxx; 
           rs_id_func <= 2'b01;
           sum_busy <= 1;
           sum_ready <= 0;  
           rs_busy[0] <= #150 0;
           sum =  #100 (a-b);
           //sum <=  #150 32'bxxxx_xxxx_xxxx_xxxx; 
           dst_sum_reg <= 2'b00;
           sum_ready <= #100 1;
        end
          
       else if ((rsopcode[0] == 2) && (mult_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[0];
            b = rsb[0];
            rsopcode[0] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[0] <= 3'bxxx;
            rsb_tag[0] <= 3'bxxx; 
            rs_id_func <= 2'b10;
            mult_busy <= 1;
            mult_ready <= 0; 
            rs_busy[0] <= #250 0; 
            mult =  #200 (a*b);
            //mult <=  #250 32'bxxxx_xxxx_xxxx_xxxx; 
            dst_mult_reg <= 2'b00;
            mult_ready <= #200 1;
         end
        
     else if ((rsopcode[0] == 3) && (div_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[0];
            b = rsb[0];
            rsopcode[0] <=  #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[0] <= 3'bxxx;
            rsb_tag[0] <= 3'bxxx; 
            rs_id_func <= 2'b11;
            div_busy <= 1;
            div_ready <= 0;
            rs_busy[0] <= #350 0; 
            div =  #300 (a/b);
            //div <=  #350 32'bxxxx_xxxx_xxxx_xxxx; 
            dst_div_reg <= 2'b00;
            div_ready <= #300 1;
         end
    end
end
/***************FOR RS 1 *************/

if ((rs_busy[1] == 1) && (flag1 == 0)) begin
     if ((rsa_tag[1] == 5) && (rsb_tag[1] == 5)) begin
        rsopready = rsopcode[1];
        if ((rsopcode[1] == 0) && (sum_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[1];
            b = rsb[1];
            rsopcode[1] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[1] <= 3'bxxx;
            rsb_tag[1] <= 3'bxxx; 
            rs_id_func <= 2'b00;
            sum_busy <= 1;
            sum_ready <= 0; 
            sum <=  #100 (a+b);
           // sum <=  #150 4'bxxxx_xxxx_xxxx_xxxx; 
            dst_sum_reg <= 2'b01;
            sum_ready <= #100 1;
            rs_busy[1] <= #150 0;
        end
          if ((rsopcode[1] == 1) && (sum_busy==0)) begin
              
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[1];
            b = rsb[1];
            rsopcode[1] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[1] <= 3'bxxx;
            rsb_tag[1] <= 3'bxxx; 
            rs_id_func <= 2'b01;
            sum_busy <= 1;
            sum_ready <= 0;  
            rs_busy[1] <= #150 0;
            sum <=  #100 (a-b);
           // sum <=  #150 32'bxxxx_xxxx_xxxx_xxxx;
            dst_sum_reg <= 2'b01;
            sum_ready <= #100 1;
       end
          
         else if ((rsopcode[1] == 2) && (mult_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[1];
            b = rsb[1];
            rsopcode[1] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[1] <= 3'bxxx;
            rsb_tag[1] <= 3'bxxx; 
            rs_id_func <= 2'b10;
            mult_busy <= 1;
            mult_ready <= 0; 
            rs_busy[1] <= #250 0; 
            mult <=  #200 (a*b);
          //  mult <=  #250 32'bxxxx_xxxx_xxxx_xxxx;
            dst_mult_reg <= 2'b01;
            mult_ready <= #200 1;
        end
        
     else if ((rsopcode[1] == 3) && (div_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[1];
            b = rsb[1];
            rsopcode[1] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[1] <= 3'bxxx;
            rsb_tag[1] <= 3'bxxx; 
            rs_id_func <= 2'b11;
            div_busy <= 1;
            div_ready <= 0;
            rs_busy[1] <= #350 0; 
            div <=  #300 (a/b);
          //  div <=  #350 4'bxxxx_xxxx_xxxx_xxxx;
            dst_div_reg <= 2'b01;
            div_ready <= #300 1;
         end
     end
end


/***************FOR RS 2 *************/

 if ((rs_busy[2] == 1) && (flag1 == 0)) begin
     if ((rsa_tag[2] == 5) && (rsb_tag[2] == 5)) begin
        rsopready = rsopcode[2];
        if ((rsopcode[2] == 0) && (sum_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[2];
            b = rsb[2];
            rsopcode[2] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[2] <= 3'bxxx;
            rsb_tag[2] <= 3'bxxx; 
            rs_id_func <= 2'b00;
            sum_busy <= 1;
            sum_ready <= 0; 
            sum <=  #100 (a+b);
           // sum <=  #150 32'bxxxx_xxxx_xxxx_xxxx;
            dst_sum_reg <= 2'b10;
            sum_ready <= #100 1;
            rs_busy[2] <= #150 0;
         end
       else if ((rsopcode[2] == 1) && (sum_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[2];
            b = rsb[2];
            rsopcode[2] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[2] <= 3'bxxx;
            rsb_tag[2] <= 3'bxxx; 
            rs_id_func <= 2'b01;
            sum_busy <= 1;
            sum_ready <= 0;  
            rs_busy[2] <= #150 0;
            sum <=  #100 (a-b);
          //  sum <=  #150 32'bxxxx_xxxx_xxxx_xxxx;
            dst_sum_reg <= 2'b10;
            sum_ready <= #100 1;
          end
          
      else  if ((rsopcode[2] == 2) && (mult_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[2];
            b = rsb[2];
            rsopcode[2] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[2] <= 3'bxxx;
            rsb_tag[2] <= 3'bxxx; 
            rs_id_func <= 2'b10;
            mult_busy <= 1;
            mult_ready <= 0; 
            rs_busy[2] <= #250 0; 
            mult <=  #200 (a*b);
          //  mult <=  #250 32'bxxxx_xxxx_xxxx_xxxx;
            dst_mult_reg <= 2'b10;
            mult_ready <= #200 1;
          end
        
     else if ((rsopcode[2] == 3) && (div_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[2];
            b = rsb[2];
            rsopcode[2] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[2] <= 3'bxxx;
            rsb_tag[2] <= 3'bxxx;
            rs_id_func <= 2'b11; 
            div_busy <= 1;
            div_ready <= 0;
            rs_busy[2] <= #350 0; 
            div <=  #300 (a/b);
           // div <=  #350 32'bxxxx_xxxx_xxxx_xxxx;
            dst_div_reg <= 2'b10;
            div_ready <= #300 1;
          end
      end
end


/***************FOR RS 3 *************/

if ((rs_busy[3] == 1) && (flag1 == 0)) begin
     if ((rsa_tag[3] == 5) && (rsb_tag[3] == 5)) begin
        rsopready = rsopcode[3];
        if ((rsopcode[3] == 0) && (sum_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[3];
            b = rsb[3];
            rsopcode[3] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[3] <= 3'bxxx;
            rsb_tag[3] <= 3'bxxx; 
            rs_id_func <= 2'b00;
            sum_busy <= 1;
            sum_ready <= 0; 
            sum <=  #100 (a+b);
          //  sum <=  #150 32'bxxxx_xxxx_xxxx_xxxx;
            dst_sum_reg <= 2'b11;
            sum_ready <= #100 1;
            rs_busy[3] <= #150 0;
        end
          if ((rsopcode[3] == 1) && (sum_busy==0)) begin
            rsopdispatch = rsopready;
            a = rsa[3];
            b = rsb[3];
            rsopcode[3] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[3] <= 3'bxxx;
            rsb_tag[3] <= 3'bxxx; 
            rs_id_func <= 2'b01;
            sum_busy <= 1;
            sum_ready <= 0;  
            rs_busy[3] <= #150 0;
            sum <=  #100 (a-b);
          //  sum <=  #150 32'bxxxx_xxxx_xxxx_xxxx;
            dst_sum_reg <= 2'b11;
            sum_ready <= #100 1;
          end
          
          if ((rsopcode[3] == 2) && (mult_busy==0)) begin
            rsopdispatch = rsopready;
            flag1=1;
            a = rsa[3];
            b = rsb[3];
            rsopcode[3] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[3] <= 3'bxxx;
            rsb_tag[3] <= 3'bxxx; 
            rs_id_func <= 2'b10;
            mult_busy <= 1;
            mult_ready <= 0; 
            rs_busy[3] <= #250 0; 
            mult <=  #200 (a*b);
           // mult <=  #250 32'bxxxx_xxxx_xxxx_xxxx_xxxx;
            dst_mult_reg <= 2'b11;
            mult_ready <= #200 1;
        end
        
        if ((rsopcode[3] == 3) && (div_busy==0)) begin
            rsopdispatch = rsopready;
            a = rsa[3];
            b = rsb[3];
            rsopcode[3] <= #50 4'bxxxx;
            rsopready <= 4'bxxxx;
            rsa_tag[3] <= 3'bxxx;
            rsb_tag[3] <= 3'bxxx;
            rs_id_func <= 2'b11; 
            div_busy <= 1;
            div_ready <= 0;
            rs_busy[3] <= #350 0; 
            div <=  #300 (a/b);
          //  div <=  #350 32'bxxxx_xxxx_xxxx_xxxx;
            dst_div_reg <= 2'b11;
            div_ready <= #300 1;
          end
     end

   end

flag1=0;




end

/***********************************************************************************
Negative edge Halt condition, RS Busy and write back procedure
***********************************************************************************/ 

always @(negedge GCLK)
begin
  
  /*************Checking if all reservation stations are busy*******************/
  if ((rs_busy[0] == 1) && (rs_busy[1] == 1) && (rs_busy[2] == 1) && (rs_busy[3] == 1)) begin
    CTR_EN = 0; //If all RS busy, pause the counter
  end
else begin
  CTR_EN = 1;  //else keep the counter ON
  if ((opcode == 4'b1111)) begin
    CTR_EN = 0; //If Opcode = 1111 stop fetching by turning of the fetch counter CTR_EN
  end
  if (!((rs_busy[0] == 1) && (rs_busy[1] == 1) && (rs_busy[2] == 1) && (rs_busy[3] == 1))) begin
    CTR_EN = #40 1; //If atleast 1 RS is free, keep CTR_EN = 1 
    end
end
end
/***********************************************************************************
Negative edge write back procedure
***********************************************************************************/ 

always @(negedge GCLK)
begin
  if (sum_ready == 1)
    begin
      sum_busy <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        if ((register [i] == dst_sum_reg) && (tv[i] == 1)) begin
          register [i] = sum;
          tv [i] <= 0; 
       end
      end
      for (i = 0; i < 4; i = i + 1) begin
        if (rsa_tag [i] == dst_sum_reg) begin
          rsa [i] = sum;
          rsa_tag [i] <= 3'b101;
       end
        if (rsb_tag [i] == dst_sum_reg) begin
          rsb [i] = sum;
          rsb_tag [i] <= 3'b101;
       end
     end
     sum_ready <=0;
     sum <= 32'bxxxx_xxxx_xxxx_xxxx;  //setting the functional unit accumulator to don't care once write back is complete
  end
    
    
    if (mult_ready == 1) begin
      mult_busy <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        if ((register [i] == dst_mult_reg) && (tv[i] == 1)) begin
          register [i] <= mult;
          tv [i] <= 0; 
        end
      end
      for (i = 0; i < 4; i = i + 1) begin
        if (rsa_tag [i] == dst_mult_reg) begin
          rsa [i] <= mult;
          rsa_tag [i] <= 3'b101;
       end
        if (rsb_tag [i] == dst_mult_reg) begin
          rsb [i] <= mult;
          rsb_tag [i] <=3'b101;
       end
      end
      mult_ready <=0;
      mult <= 32'bxxxx_xxxx_xxxx_xxxx;
    end
    
  
     if (div_ready == 1) begin
      div_busy <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        if ((register [i] == dst_div_reg) && (tv[i] == 1)) begin
          register [i] <= div;
          tv [i] <= 0; 
       end
      end
       for (i = 0; i < 4; i = i + 1) begin
        if (rsa_tag [i] == dst_div_reg) begin
          rsa [i] <= div;
          rsa_tag [i] <= 3'b101;
       end
        if (rsb_tag [i] == dst_div_reg) begin
          rsb [i] <= div;
          rsb_tag [i] <=3'b101;
       end
      end
      
    end
    div_ready <=0;
    div <= 32'bxxxx_xxxx_xxxx_xxxx;
end    

  

endmodule



  
 
  
  
 
  














