//	DE10_VGA.v
//	Author: Parker Dillmann
//	Website: http://www.longhornengineer.com
// Github: https://github.com/LonghornEngineer
// Modified by Pascal Francis-Mezger to support 640x480 resolution
// - Modified parameters and PLL clock timing
// Modified to use altera_up_altpll
`include "./PLL_PIXEL_CLK.v"
module DE10_VGA
(
	 clk_50, pixel_color, VGA_BUS_R, VGA_BUS_G, VGA_BUS_B, VGA_HS, VGA_VS, X_pix, Y_pix, H_visible, V_visible, pixel_clk, pixel_cnt
);

input		wire				clk_50;

input		wire	[11:0]	pixel_color;

output	reg	[3:0]		VGA_BUS_R;
output	reg	[3:0]		VGA_BUS_G;
output	reg	[3:0]		VGA_BUS_B;

output	reg	[0:0]		VGA_HS;
output	reg	[0:0]		VGA_VS;

output	wire	[10:0]	X_pix;
output	wire	[10:0]	Y_pix;
		
output	reg	[0:0]		H_visible;
output	reg	[0:0]		V_visible;
			
output	wire [0:0]		pixel_clk;

output	reg	[9:0]		pixel_cnt;

			reg	[10:0]	HS_counter;
			reg	[10:0]	VS_counter;

			wire	[0:0]		vertical_clk;


//640x480@60Hz
//http://tinyvga.com/vga-timing/640x480@60Hz
parameter [10:0] HSNC_STRT 		= 11'd16;
parameter [10:0] HSNC_END  		= HSNC_STRT + 11'd96;
parameter [10:0] HBCK_PRCH_END = HSNC_END + 11'd48;
parameter [10:0] HVSBL_END		= HBCK_PRCH_END + 11'd640;

parameter [10:0] VSNC_STRT		= 11'd10;
parameter [10:0] VSNC_END		= VSNC_STRT + 11'd2;
parameter [10:0] VBCK_PRCH_END	= VSNC_END + 11'd33;
parameter [10:0] VVSBL_END		= VBCK_PRCH_END + 11'd480;

//Use counters to assign X_pix and Y_pix locations. 
assign X_pix 	= (HS_counter - HBCK_PRCH_END) > 11'd0 ? (HS_counter - HBCK_PRCH_END) : 11'd0;
assign Y_pix	= (VS_counter - VBCK_PRCH_END) > 11'd0 ? (VS_counter - VBCK_PRCH_END) : 11'd0;


initial
	begin
		VGA_BUS_R 	<= 4'b0000;
		VGA_BUS_G 	<= 4'b0000;
		VGA_BUS_B 	<= 4'b0000;
		VGA_VS		<= 1'b1;
		VGA_HS		<= 1'b1;
		
		HS_counter	<=	11'b0;
		VS_counter	<= 11'b0;
		
		H_visible	<= 1'b0;
		V_visible	<= 1'b0;
				
		pixel_cnt	<= 1;
		
	end
	
//Display Stuff!
always_ff @(posedge pixel_clk)
	begin
		if((H_visible == 1'b1) && (V_visible == 1'b1))
			begin
				VGA_BUS_B 	<= pixel_color[11:8];
				VGA_BUS_G 	<= pixel_color[7:4];
				VGA_BUS_R 	<= pixel_color[3:0];
			
				pixel_cnt	<= pixel_cnt + 1'b1;
			end
		else
			begin
				pixel_cnt	<= 0;
				VGA_BUS_R 	<= 4'b0000;
				VGA_BUS_G 	<= 4'b0000;
				VGA_BUS_B 	<= 4'b0000;	
			end
	end
	
//Timing for VGA_HS and VGA_VS
always_ff @(posedge pixel_clk)
	begin
		case(HS_counter)
			//Wait for front porch
			HSNC_STRT:						//Start sync.
			begin	
				VGA_HS <= 1'b0;
				H_visible <= H_visible;
				HS_counter <= HS_counter + 1'b1; 
			end
			HSNC_END:							//Sync over.
			begin
				VGA_HS <= 1'b1;
				H_visible <= H_visible;
				HS_counter <= HS_counter + 1'b1; 
			end			
			HBCK_PRCH_END:				//Back porch over. Visable area begin.
			begin
				VGA_HS <= VGA_HS;
				H_visible <= 1'b1;
				HS_counter <= HS_counter + 1'b1; 
			end	
			HVSBL_END:					//Visable area over. Reset counter.
			begin
				VGA_HS <= VGA_HS;
				H_visible <= 1'b0;
				HS_counter <= 1;
				if (VS_counter == VVSBL_END)	//Control VS_counter here to make sure Vertical Sync stays in sync. 
					begin
						VS_counter <= 1;
					end
				else
					begin
						VS_counter <= VS_counter + 1'b1;
					end
			end
			default:
			begin
				VGA_HS <= VGA_HS;
				H_visible <= H_visible;
				HS_counter <= HS_counter + 1'b1; 
			end
		endcase
	end
	
always_ff @(posedge pixel_clk)
	begin
		case(VS_counter)
			//Wait for front porch
			VSNC_STRT:					//Start sync.
			begin	
				VGA_VS <= 1'b0;
				V_visible	<= V_visible;
			end
			VSNC_END:					//Sync over.
			begin
				VGA_VS <= 1'b1;
				V_visible	<= V_visible;
			end			
			VBCK_PRCH_END:				//Back porch over. Visable area begin.
			begin
				VGA_VS <= VGA_VS;
				V_visible	<= 1'b1;
			end	
			VVSBL_END:					//Visable area over. Reset counter.
			begin
				VGA_VS <= VGA_VS;
				V_visible	<= 1'b0;
			end
			default
			begin
				VGA_VS <= VGA_VS;
				V_visible	<= V_visible;
			end
		endcase
	end
	
	// Altera_UP_Clocks.pdf: " ...additional clocks can
	// be generated using specific circuits in FPGAs called 
	// phase-lock loops (PLLs). PLLs have many parameters, so to
	// make them easier to use, a suite of three IP cores is provided.
	// These IP cores are described in more detail below."
	// "The video in ADC requires a 27 MHz clock, however this is provided
	//   by a second on-board oscillator."
	// Tools > IP Catalog
	// IP Catalog > Search "video clocks"
	// Select "Library" > "Unviersity Program" > Clock >
	//     > Video Clocks for DE-series Boards"
	// Combine the generated *.v files into a single function
   altera_up_altpll #(
		.OUTCLK0_MULT  (1),
		.OUTCLK0_DIV   (2), // 25 MHz
		.OUTCLK1_MULT  (1),
		.OUTCLK1_DIV   (2), // 25 MHz
		.OUTCLK2_MULT  (2), // 33 Mhz
		.OUTCLK2_DIV   (3),
		.PHASE_SHIFT   (0),
		.DEVICE_FAMILY ("MAX 10")
	) video_pll (
		.refclk  (clk_50),             		//  refclk.clk
		.reset   (1'b0),         				//   reset.reset
		.locked  (1'b1), 							//  locked.export
		.outclk0 (),                        // outclk0.clk
		.outclk1 (pixel_clk),             	// outclk1.clk
		.outclk2 ()                         // outclk2.clk
	);		
endmodule
		
