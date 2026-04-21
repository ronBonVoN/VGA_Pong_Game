// either this 
`include "./DE10_VGA.sv" 
// XOR "Project Navigator" > "File" > Add files > DE10_VGA.v
// not both

module VGA_top(
	 //////////// CLOCK //////////
    input                       ADC_CLK_10,
    input                       MAX10_CLK1_50,
    input                       MAX10_CLK2_50,

    //////////// SDRAM //////////
    output          [12:0]      DRAM_ADDR,
    output           [1:0]      DRAM_BA,
    output                      DRAM_CAS_N,
    output                      DRAM_CKE,
    output                      DRAM_CLK,
    output                      DRAM_CS_N,
    inout           [15:0]      DRAM_DQ,
    output                      DRAM_LDQM,
    output                      DRAM_RAS_N,
    output                      DRAM_UDQM,
    output                      DRAM_WE_N,

    //////////// SEG7 //////////
    output           [7:0]      HEX0,
    output           [7:0]      HEX1,
    output           [7:0]      HEX2,
    output           [7:0]      HEX3,
    output           [7:0]      HEX4,
    output           [7:0]      HEX5,

    //////////// KEY //////////
    input            [1:0]      KEY,

    //////////// LED //////////
    output           [9:0]      LEDR,

    //////////// SW //////////
    input            [9:0]      SW,

    //////////// VGA //////////
    output           [3:0]      VGA_B, //Output Blue
    output           [3:0]      VGA_G, //Output Green
    output           [3:0]      VGA_R, //Output Red
    output                      VGA_HS,//Horizontal Sync
    output                      VGA_VS,//Vertical Sync

    //////////// Accelerometer //////////
    output                      GSENSOR_CS_N,
    input            [2:1]      GSENSOR_INT,
    output                      GSENSOR_SCLK,
    inout                       GSENSOR_SDI,
    inout                       GSENSOR_SDO,

    ///////// GPIO /////////
    inout           [35: 0]   GPIO,

    //////////// Arduino //////////
    inout           [15:0]      ARDUINO_IO,
    inout                       ARDUINO_RESET_N
 );

wire			[9:0]		X_pix;			// Location in X of the driver
wire			[9:0]		Y_pix;			// Location in Y of the driver

wire			[0:0]		H_visible;		//H_blank?
wire			[0:0]		V_visible;		//V_blank?

wire		   [0:0]		pixel_clk;		//Pixel clock. Every clock a pixel is being drawn. 
wire			[9:0]		pixel_cnt;		//How many pixels have been output.

reg			[11:0]		pixel_color;	//12 Bits representing color of pixel, 4 bits for R, G, and B
										//4 bits for Red are in most significant position, Blue in least

wire [9:0] paddle_width = 10'd100;  
wire [9:0] paddle_height = 10'd10;  
wire [9:0] paddle_step_x = 10'd1; 
wire [9:0] paddle_step_y = 10'd1; 
wire paddle_active; 

reg [9:0] paddle_x_location = 10'd0;  
reg [9:0] paddle_y_location = 10'd0;  
reg paddle_move_right; 
reg paddle_move_left; 
reg paddle_move_up; 
reg paddle_move_down; 

wire [9:0] ball_width = 10'd10; 
wire [9:0] ball_height = 10'd10; 
wire [9:0] ball_step_x = 10'd1; 
wire [9:0] ball_step_y = 10'd1; 
wire ball_active; 
wire ball_wall_collision; 

reg [9:0] ball_x_location = 10'd0; 
reg [9:0] ball_y_location = 10'd0; 
reg ball_move_right; 
reg ball_move_left; 
reg ball_move_up; 
reg ball_move_down; 

reg [31:0] clock_counter = 32'd0; 

make_box player_paddle (
	.x_pix(X_pix), 
	.y_pix(Y_pix), 
	.box_width(paddle_width), 
	.box_height(paddle_height), 
	.box_x_location(paddle_x_location), 
	.box_y_location(paddle_y_location), 
	.pixel_clk(pixel_clk),
	.box_active(paddle_active)
);  

move_box move_player_paddle (
	.box_width(paddle_width), 
	.box_height(paddle_height), 
	.step_x(paddle_step_x),
	.step_y(paddle_step_y),
	.move_right(paddle_move_right),
	.move_left(paddle_move_left),
	.move_up(paddle_move_up),
	.move_down(paddle_move_down),
	.wall_collision(),
	.pixel_clk(pixel_clk),
	.box_x_location(paddle_x_location), 
	.box_y_location(paddle_y_location), 
); 

make_box ball (
	.x_pix(X_pix), 
	.y_pix(Y_pix), 
	.box_width(ball_width), 
	.box_height(ball_height), 
	.box_x_location(ball_x_location), 
	.box_y_location(ball_y_location), 
	.pixel_clk(pixel_clk),
	.box_active(ball_active)
);  

move_box move_ball (
	.box_width(ball_width), 
	.box_height(ball_height), 
	.step_x(ball_step_x),
	.step_y(ball_step_y),
	.move_right(ball_move_right),
	.move_left(ball_move_left),
	.move_up(ball_move_up),
	.move_down(ball_move_down),
	.wall_collision(ball_wall_collision),
	.pixel_clk(pixel_clk),
	.box_x_location(ball_x_location), 
	.box_y_location(ball_y_location), 
); 


always @(posedge pixel_clk) begin 
		if (paddle_active) pixel_color <= 12'b0000_0000_1111; 
		else if (ball_active) pixel_color <= 12'b1111_1111_1111; 
		else pixel_color <= 12'b0000_0000_0000; 
		
		clock_counter <= clock_counter + 1'd1;
		
		paddle_move_right <= 1'd0;
		paddle_move_left <= 1'd0; 
		paddle_move_up <= 1'd0; 
		paddle_move_down <= 1'd0; 
		
		ball_move_right <= 1'd0;
		ball_move_left <= 1'd0; 
		ball_move_up <= 1'd0; 
		ball_move_down <= 1'd0; 
		
		if (clock_counter > 32'b0000_1111_1111_1111_1111) begin
			clock_counter <= 32'd0; 
			
			paddle_move_right <= SW[1] && SW[0]; 
			paddle_move_left <= SW[1] && !SW[0]; 
			paddle_move_up <= SW[3] && SW[2]; 
			paddle_move_down <= SW[3] && !SW[2]; 
			
			ball_move_right 
		
		end		
	end
	
//Pass pins and current pixel values to display driver
DE10_VGA VGA_Driver
(
	.clk_50(MAX10_CLK1_50),   // input to the driver
	.pixel_color(pixel_color), // input to the driver
	.VGA_BUS_R(VGA_R),         // output
	.VGA_BUS_G(VGA_G),         // output
	.VGA_BUS_B(VGA_B),         // output
	.VGA_HS(VGA_HS),           // output
	.VGA_VS(VGA_VS),           // output
	.X_pix(X_pix),             // output what pixel we are drawing right now
	.Y_pix(Y_pix),             // output what pixel we are drawing right now
	.H_visible(H_visible),     // H_blank?
	.V_visible(V_visible),
	.pixel_clk(pixel_clk),     // Pixel clock. Every clock a pixel is being drawn.
	.pixel_cnt(pixel_cnt)
);
endmodule

module make_box(
	input [9:0] x_pix, 
	input [9:0] y_pix, 
	input [9:0] box_width,
	input [9:0] box_height,
	input logic [9:0] box_x_location,
	input logic [9:0] box_y_location,
	input pixel_clk,
	output reg box_active
); 	
	always @(posedge pixel_clk) begin	
		box_active <= (x_pix > box_x_location) && 
		              (x_pix < box_x_location + box_width) &&
		              (y_pix > box_y_location) && 
	      			  (y_pix < box_y_location + box_height); 
		end
endmodule

module move_box(
	input [9:0] box_width,
	input [9:0] box_height,
	input [9:0] step_x, 
	input [9:0] step_y, 
	input logic move_left, 
	input logic move_right, 
	input logic move_up, 
	input logic move_down, 
	input pixel_clk,
	output wall_collision, 
	output reg [9:0] box_x_location,
	output reg [9:0] box_y_location
); 
	parameter SCREEN_WIDTH = 10'd640;
	parameter SCREEN_HEIGHT = 10'd480;
	
	always @(posedge pixel_clk) begin			
		if (move_right)
			box_x_location <= (box_x_location + step_x > SCREEN_WIDTH - box_width) ? SCREEN_WIDTH - box_width : box_x_location + step_x; 
		
		else if (move_left)
			box_x_location <= (box_x_location < step_x) ? 10'd0 : box_x_location - step_x; 
		
		if (move_up) 
			box_y_location <= (box_y_location < step_y) ? 10'd0 : box_y_location - step_y; 
		
		else if (move_down)
			box_y_location <= (box_y_location + step_y > SCREEN_HEIGHT - box_height) ? SCREEN_HEIGHT - box_height : box_y_location + step_y;
	
		wall_collision = (box_x_location + step_x > SCREEN_WIDTH - box_width) | (box_x_location < step_x) | (box_y_location < step_y) | (box_y_location + step_y > SCREEN_HEIGHT - box_height);
	end
endmodule
