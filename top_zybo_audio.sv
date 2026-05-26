`timescale 1ns / 1ps

module efectos_audio (

    input logic clk,
    input logic rst,

    input logic sw0,
    input logic sw1,
    input logic sw2,

    input logic muestra_valida,

    input logic signed [15:0] audio_izq_in,
    input logic signed [15:0] audio_der_in,

    output logic signed [15:0] audio_izq_out,
    output logic signed [15:0] audio_der_out
);


    logic signed [31:0] eco_izq;
    logic signed [31:0] eco_der;

    logic signed [15:0] audio_retrasado_izq;
    logic signed [15:0] audio_retrasado_der;

    logic [13:0] direccion_eco;

    (* ram_style = "block" *)
    logic signed [15:0] memoria_eco_izq [0:16383];

    (* ram_style = "block" *)
    logic signed [15:0] memoria_eco_der [0:16383];


    always_ff @(posedge clk) begin

        if (rst) begin

            audio_izq_out <= 16'sd0;
            audio_der_out <= 16'sd0;

            audio_retrasado_izq <= 16'sd0;
            audio_retrasado_der <= 16'sd0;

            direccion_eco <= 14'd0;

        end else begin

            if (muestra_valida) begin

                audio_retrasado_izq <=
                    memoria_eco_izq[direccion_eco];

                audio_retrasado_der <=
                    memoria_eco_der[direccion_eco];

                if (

                    (audio_izq_in > 16'sd300)  ||
                    (audio_izq_in < -16'sd300) ||

                    (audio_retrasado_izq > 16'sd150)  ||
                    (audio_retrasado_izq < -16'sd150)

                ) begin

                    memoria_eco_izq[direccion_eco] <=
                        (audio_izq_in >>> 1)
                      + (audio_retrasado_izq >>> 3);

                end else begin

                    memoria_eco_izq[direccion_eco] <=
                        16'sd0;

                end


                if (

                    (audio_der_in > 16'sd300)  ||
                    (audio_der_in < -16'sd300) ||

                    (audio_retrasado_der > 16'sd150)  ||
                    (audio_retrasado_der < -16'sd150)

                ) begin

                    memoria_eco_der[direccion_eco] <=
                        (audio_der_in >>> 1)
                      + (audio_retrasado_der >>> 3);

                end else begin

                    memoria_eco_der[direccion_eco] <=
                        16'sd0;

                end


                if (sw0) begin

                    audio_izq_out <= audio_izq_in;
                    audio_der_out <= audio_der_in;

                end


                else if (sw1) begin

                    audio_izq_out <= {

                        audio_izq_in[15:12],
                        12'b0

                    };

                    audio_der_out <= {

                        audio_der_in[15:12],
                        12'b0

                    };

                end

                else if (sw2) begin

                    eco_izq =

                        {{16{audio_izq_in[15]}},
                        audio_izq_in}

                      +

                        ({{16{
                            audio_retrasado_izq[15]
                        }},
                        audio_retrasado_izq} >>> 2);

                    eco_der =

                        {{16{audio_der_in[15]}},
                        audio_der_in}

                      +

                        ({{16{
                            audio_retrasado_der[15]
                        }},
                        audio_retrasado_der} >>> 2);


                    if (eco_izq > 32767)

                        audio_izq_out <= 32767;

                    else if (eco_izq < -32768)

                        audio_izq_out <= -32768;

                    else

                        audio_izq_out <= eco_izq[15:0];


                    if (eco_der > 32767)

                        audio_der_out <= 32767;

                    else if (eco_der < -32768)

                        audio_der_out <= -32768;

                    else

                        audio_der_out <= eco_der[15:0];

                end


                else begin

                    audio_izq_out <= 16'sd0;
                    audio_der_out <= 16'sd0;

                end

                direccion_eco <= direccion_eco + 1'b1;

            end
        end
    end

endmodule


module interfaz_i2s (

    input  logic clk,
    input  logic rst,

    output logic ac_mclk,
    output logic ac_bclk,

    output logic ac_pblrc,
    output logic ac_pbdat,

    output logic ac_reclrc,
    input  logic ac_recdat,

    output logic muestra_valida,

    output logic signed [15:0] audio_izq_in,
    output logic signed [15:0] audio_der_in,

    input  logic signed [15:0] audio_izq_out,
    input  logic signed [15:0] audio_der_out
);


    logic [2:0] contador_mclk;
    logic [4:0] contador_bclk;

    logic subida_bclk;
    logic bajada_bclk;

    logic [5:0] contador_bits;


    logic signed [15:0] shift_rx_izq;
    logic signed [15:0] shift_rx_der;

    logic signed [15:0] registro_tx_izq;
    logic signed [15:0] registro_tx_der;


    always_ff @(posedge clk) begin

        if (rst) begin

            contador_mclk <= 3'd0;
            ac_mclk <= 1'b0;

        end else begin

            if (contador_mclk == 3'd4) begin

                contador_mclk <= 3'd0;
                ac_mclk <= ~ac_mclk;

            end else begin

                contador_mclk <= contador_mclk + 1'b1;

            end
        end
    end

    always_ff @(posedge clk) begin

        if (rst) begin

            contador_bclk <= 5'd0;

            ac_bclk <= 1'b0;

            subida_bclk <= 1'b0;
            bajada_bclk <= 1'b0;

        end else begin

            subida_bclk <= 1'b0;
            bajada_bclk <= 1'b0;

            if (contador_bclk == 5'd19) begin

                contador_bclk <= 5'd0;

                ac_bclk <= ~ac_bclk;

                if (ac_bclk == 1'b0)
                    subida_bclk <= 1'b1;
                else
                    bajada_bclk <= 1'b1;

            end else begin

                contador_bclk <= contador_bclk + 1'b1;

            end
        end
    end

    always_comb begin

        if (contador_bits < 6'd32) begin

            ac_pblrc  = 1'b0;
            ac_reclrc = 1'b0;

        end else begin

            ac_pblrc  = 1'b1;
            ac_reclrc = 1'b1;

        end
    end


    always_ff @(posedge clk) begin

        if (rst) begin

            contador_bits <= 6'd0;

            shift_rx_izq <= 16'sd0;
            shift_rx_der <= 16'sd0;

            audio_izq_in <= 16'sd0;
            audio_der_in <= 16'sd0;

            registro_tx_izq <= 16'sd0;
            registro_tx_der <= 16'sd0;

            muestra_valida <= 1'b0;

        end else begin

            muestra_valida <= 1'b0;

            if (subida_bclk) begin


                if (

                    contador_bits >= 6'd1 &&
                    contador_bits <= 6'd16

                ) begin

                    shift_rx_izq <= {

                        shift_rx_izq[14:0],
                        ac_recdat

                    };

                end


                if (

                    contador_bits >= 6'd33 &&
                    contador_bits <= 6'd48

                ) begin

                    shift_rx_der <= {

                        shift_rx_der[14:0],
                        ac_recdat

                    };

                end


                if (contador_bits == 6'd63) begin

                    contador_bits <= 6'd0;

                    audio_izq_in <= shift_rx_izq;
                    audio_der_in <= shift_rx_der;

                    registro_tx_izq <= audio_izq_out;
                    registro_tx_der <= audio_der_out;

                    muestra_valida <= 1'b1;

                end else begin

                    contador_bits <=
                        contador_bits + 1'b1;

                end
            end
        end
    end


    always_ff @(posedge clk) begin

        if (rst) begin

            ac_pbdat <= 1'b0;

        end else begin

            if (bajada_bclk) begin


                if (contador_bits == 6'd0) begin

                    ac_pbdat <= 1'b0;

                end


                else if (

                    contador_bits >= 6'd1 &&
                    contador_bits <= 6'd16

                ) begin

                    ac_pbdat <=
                        registro_tx_izq[
                            16 - contador_bits
                        ];

                end


                else if (contador_bits == 6'd32) begin

                    ac_pbdat <= 1'b0;

                end


                else if (

                    contador_bits >= 6'd33 &&
                    contador_bits <= 6'd48

                ) begin

                    ac_pbdat <=
                        registro_tx_der[
                            48 - contador_bits
                        ];

                end

                else begin

                    ac_pbdat <= 1'b0;

                end
            end
        end
    end

endmodule


module controlador_codec (

    input  logic clk,
    input  logic rst,

    output logic scl,
    inout  logic sda
);


    localparam logic [6:0]
        DIRECCION_CODEC = 7'h1A;

    localparam int
        DIVISOR_SERIAL = 625;

    localparam int
        TOTAL_REGISTROS = 11;

    logic [$clog2(DIVISOR_SERIAL)-1:0]
        contador_divisor;

    logic tick_serial;

    logic habilitar_sda;

    assign sda =
        habilitar_sda ? 1'b0 : 1'bz;

    logic [3:0]
        indice_registro;

    logic [1:0]
        indice_paquete;

    logic [2:0]
        bit_serial;

    logic [15:0]
        palabra_config;

    logic [7:0]
        dato_serial;

    typedef enum logic [3:0] {

        S0_ESPERA,
        S1_INICIO,
        S2_BIT_BAJO,
        S3_BIT_ALTO,
        S4_ACK_BAJO,
        S5_ACK_ALTO,
        S6_STOP_BAJO,
        S7_STOP_ALTO,
        S8_SIGUIENTE,
        S9_FINAL

    } estado_t;

    estado_t estado;

    always_comb begin

        case (indice_registro)

            // RESET
            4'd0:
                palabra_config =
                    {7'd15, 9'h000};

            // POWER
            4'd1:
                palabra_config =
                    {7'd6, 9'h000};

            // LEFT LINE IN
            4'd2:
                palabra_config =
                    {7'd0, 9'h01F};

            // RIGHT LINE IN
            4'd3:
                palabra_config =
                    {7'd1, 9'h01F};

            // LEFT HEADPHONE
            4'd4:
                palabra_config =
                    {7'd2, 9'h07F};

            // RIGHT HEADPHONE
            4'd5:
                palabra_config =
                    {7'd3, 9'h07F};

            // ANALOG PATH
            4'd6:
                palabra_config =
                    {7'd4, 9'h012};

            // DIGITAL PATH
            4'd7:
                palabra_config =
                    {7'd5, 9'h000};

            // I2S + 16 BIT
            4'd8:
                palabra_config =
                    {7'd7, 9'h002};

            // SAMPLE RATE
            4'd9:
                palabra_config =
                    {7'd8, 9'h000};

            // ACTIVE
            4'd10:
                palabra_config =
                    {7'd9, 9'h001};

            default:
                palabra_config =
                    16'h0000;

        endcase
    end


    always_comb begin

        case (indice_paquete)

            2'd0:

                dato_serial = {

                    DIRECCION_CODEC,
                    1'b0

                };

            2'd1:

                dato_serial =
                    palabra_config[15:8];

            2'd2:

                dato_serial =
                    palabra_config[7:0];

            default:

                dato_serial = 8'h00;

        endcase
    end


    always_ff @(posedge clk) begin

        if (rst) begin

            contador_divisor <= '0;

            tick_serial <= 1'b0;

        end else begin

            if (
                contador_divisor ==
                DIVISOR_SERIAL - 1
            ) begin

                contador_divisor <= '0;

                tick_serial <= 1'b1;

            end else begin

                contador_divisor <=
                    contador_divisor + 1'b1;

                tick_serial <= 1'b0;

            end
        end
    end


    always_ff @(posedge clk) begin

        if (rst) begin

            estado <= S0_ESPERA;

            scl <= 1'b1;

            habilitar_sda <= 1'b0;

            indice_registro <= 4'd0;
            indice_paquete <= 2'd0;

            bit_serial <= 3'd7;

        end else begin

            if (tick_serial) begin

                case (estado)

                    S0_ESPERA: begin

                        scl <= 1'b1;

                        habilitar_sda <= 1'b0;

                        indice_registro <= 4'd0;

                        indice_paquete <= 2'd0;

                        bit_serial <= 3'd7;

                        estado <= S1_INICIO;

                    end


                    S1_INICIO: begin

                        scl <= 1'b1;

                        habilitar_sda <= 1'b1;

                        indice_paquete <= 2'd0;

                        bit_serial <= 3'd7;

                        estado <= S2_BIT_BAJO;

                    end


                    S2_BIT_BAJO: begin

                        scl <= 1'b0;

                        if (
                            dato_serial[bit_serial]
                            == 1'b0
                        )

                            habilitar_sda <= 1'b1;

                        else

                            habilitar_sda <= 1'b0;

                        estado <= S3_BIT_ALTO;

                    end


                    S3_BIT_ALTO: begin

                        scl <= 1'b1;

                        if (bit_serial == 3'd0) begin

                            estado <= S4_ACK_BAJO;

                        end else begin

                            bit_serial <=
                                bit_serial - 1'b1;

                            estado <= S2_BIT_BAJO;

                        end
                    end

                    S4_ACK_BAJO: begin

                        scl <= 1'b0;

                        habilitar_sda <= 1'b0;

                        estado <= S5_ACK_ALTO;

                    end

                    S5_ACK_ALTO: begin

                        scl <= 1'b1;

                        if (
                            indice_paquete == 2'd2
                        ) begin

                            estado <= S6_STOP_BAJO;

                        end else begin

                            indice_paquete <=
                                indice_paquete + 1'b1;

                            bit_serial <= 3'd7;

                            estado <= S2_BIT_BAJO;

                        end
                    end

                    S6_STOP_BAJO: begin

                        scl <= 1'b0;

                        habilitar_sda <= 1'b1;

                        estado <= S7_STOP_ALTO;

                    end

                    S7_STOP_ALTO: begin

                        scl <= 1'b1;

                        habilitar_sda <= 1'b0;

                        estado <= S8_SIGUIENTE;

                    end


                    S8_SIGUIENTE: begin

                        if (
                            indice_registro ==
                            TOTAL_REGISTROS - 1
                        ) begin

                            estado <= S9_FINAL;

                        end else begin

                            indice_registro <=
                                indice_registro + 1'b1;

                            indice_paquete <= 2'd0;

                            bit_serial <= 3'd7;

                            estado <= S1_INICIO;

                        end
                    end

                    S9_FINAL: begin

                        scl <= 1'b1;

                        habilitar_sda <= 1'b0;

                        estado <= S9_FINAL;

                    end

                    default: begin

                        estado <= S0_ESPERA;

                    end

                endcase
            end
        end
    end

endmodule

module top_audio (

    input  logic clk,
    input  logic rst,

    input  logic sw0,
    input  logic sw1,
    input  logic sw2,

    output logic led0,
    output logic led1,
    output logic led2,

    // CODEC AUDIO
    output logic ac_mclk,
    output logic ac_bclk,

    output logic ac_pblrc,
    output logic ac_pbdat,

    output logic ac_reclrc,
    input  logic ac_recdat,

    output logic ac_scl,
    inout  logic ac_sda,

    output logic ac_muten
);

    assign led0 = sw0;
    assign led1 = sw1;
    assign led2 = sw2;

    assign ac_muten = 1'b1;

    logic muestra_valida;

    logic signed [15:0] audio_izq_in;
    logic signed [15:0] audio_der_in;

    logic signed [15:0] audio_izq_out;
    logic signed [15:0] audio_der_out;

    controlador_codec codec_config (

        .clk(clk),
        .rst(rst),

        .scl(ac_scl),
        .sda(ac_sda)
    );

    interfaz_i2s interfaz_audio (

        .clk(clk),
        .rst(rst),

        .ac_mclk(ac_mclk),
        .ac_bclk(ac_bclk),

        .ac_pblrc(ac_pblrc),
        .ac_pbdat(ac_pbdat),

        .ac_reclrc(ac_reclrc),
        .ac_recdat(ac_recdat),

        .muestra_valida(muestra_valida),

        .audio_izq_in(audio_izq_in),
        .audio_der_in(audio_der_in),

        .audio_izq_out(audio_izq_out),
        .audio_der_out(audio_der_out)
    );


    efectos_audio efectos (

        .clk(clk),
        .rst(rst),

        .sw0(sw0),
        .sw1(sw1),
        .sw2(sw2),

        .muestra_valida(muestra_valida),

        .audio_izq_in(audio_izq_in),
        .audio_der_in(audio_der_in),

        .audio_izq_out(audio_izq_out),
        .audio_der_out(audio_der_out)
    );

endmodule