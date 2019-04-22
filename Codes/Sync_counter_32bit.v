

module Sync_counter_32bit (out, clock, clear_bar, count_en);

output [31:0] out;
input  clock, count_en, clear_bar;


Sync_counter_4bit C0 (.out(out[3:0]), .and_out(aout0), .clock(clock), .clear_bar(clear_bar), .count_en(count_en));
and_2_GT6100 C0A (ce1, aout0, out[3]);
Sync_counter_4bit C1 (.out(out[7:4]), .and_out(aout1), .clock(clock), .clear_bar(clear_bar), .count_en(ce1));
and_2_GT6100 C1A (ce2, aout1, out[7]);
Sync_counter_4bit C2 (.out(out[11:8]), .and_out(aout2), .clock(clock), .clear_bar(clear_bar), .count_en(ce2));
and_2_GT6100 C2A (ce3, aout2, out[11]);
Sync_counter_4bit C3 (.out(out[15:12]), .and_out(aout3), .clock(clock), .clear_bar(clear_bar), .count_en(ce3));
and_2_GT6100 C3A (ce4, aout3, out[15]);
Sync_counter_4bit C4 (.out(out[19:16]), .and_out(aout4), .clock(clock), .clear_bar(clear_bar), .count_en(ce4));
and_2_GT6100 C4A (ce5, aout4, out[19]);
Sync_counter_4bit C5 (.out(out[23:20]), .and_out(aout5), .clock(clock), .clear_bar(clear_bar), .count_en(ce5));
and_2_GT6100 C5A (ce6, aout5, out[23]);
Sync_counter_4bit C6 (.out(out[27:24]), .and_out(aout6), .clock(clock), .clear_bar(clear_bar), .count_en(ce6));
and_2_GT6100 C6A (ce7, aout6, out[27]);
Sync_counter_4bit C7 (.out(out[31:28]), .and_out(not_used), .clock(clock), .clear_bar(clear_bar), .count_en(ce7));

endmodule


////////////////////////////////////////////////////////////////////
module Sync_counter_4bit (out, and_out, clock, clear_bar, count_en);

output [3:0] out;
output and_out;
input  clock, count_en, clear_bar;

Toggle_FF_GT6100 T0(.out(out[0]), .en(count_en), .clear_bar(clear_bar), .clock(clock));
Toggle_FF_GT6100 T1(.out(out[1]), .en(a0), .clear_bar(clear_bar), .clock(clock));
Toggle_FF_GT6100 T2(.out(out[2]), .en(a1), .clear_bar(clear_bar), .clock(clock));
Toggle_FF_GT6100 T3(.out(out[3]), .en(and_out), .clear_bar(clear_bar), .clock(clock));

and_2_GT6100 A0 (a0, count_en, out[0]),
	   A1 (a1, a0, out[1]),
	   A2 (and_out, a1, out[2]);

endmodule
