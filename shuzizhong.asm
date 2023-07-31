P4     DATA   0C0H  ; 端口寄存器的地址
P5     DATA   0C8H
P3M1	DATA	0xB1	; 设置端口模式寄存器的地址
P3M0	DATA	0xB2
P4M1	DATA	0xB3	
P4M0	DATA	0xB4	
P5M1	DATA	0xC9	
P5M0	DATA	0xCA
;*************	IO口定义	**************
HC595_SER      BIT  P4.0	           ;   串行数据输入引脚
HC595_RCLK    BIT  P5.4            ;   锁存时钟
HC595_SRCLK  BIT  P4.3            ;   移位时钟
STACK_P	EQU    0D0H           ;   堆栈开始地址
DIS_BLACK	EQU    10H              ;   消隐的索引值
;*************       本地变量声明	       ***********
LED8	DATA    30H             ;   显示缓冲 30H ~ 37H
disp_index	DATA    38H             ;   显示位索引
INT1_cnt	DATA    39H             ;   测试用的计数变量
hour DATA 40H
minute DATA 41H
second DATA 42H

    ORG	0000H		; reset
	LJMP	Main
	ORG	0003H		; INT0 中断向量
	LJMP	INT0_ISR 
	ORG	0013H		; INT1 中断向量
	LJMP	INT1_ISR 
	ORG  001BH            ;T1中断向量
           	AJMP  T1_ISR
	ORG	0100H		; 主程序起始地址
Main:  CLR      A
	      MOV   P3M1, A 	;设置为准双向口
 	      MOV   P3M0, A
	      MOV   P4M1, A 	 
 	      MOV   P4M0, A
	      MOV   P5M1, A 	
 	      MOV   P5M0, A
	      MOV   SP, #STACK_P
	      MOV   disp_index, #0
		MOV hour,#12
		MOV minute,#30
		MOV second,#0
   		MOV	R0, #LED8
		MOV	R2, #8
		MOV  R5,  #14H       ;定时次数，每次50ms
          		MOV  TMOD,  #00H ;T1方式0定时
           		MOV  TH1,  #3CH    ;50ms定时初值
           		MOV  TL1,  #0B0H
		SETB  ET1                  ;T1中断允许
               		SETB  EA                   ;中断总允许
               		SETB  PT1                  ;T1高优先级
               		SETB  TR1                  ;启动定时
               		
 SETB	EX1		  ;   INT1允许
				  SETB	EX0	  ;   INT0允许
	              SETB	IT1		  ;   INT1 下降沿中断
				  SETB	IT0		  ;   INT0 下降沿中断
	              SETB	EA		  ;   允许总中断	
                    SETB   PX1                           ;    高优先级
					SETB   PX0                          ;    高优先级


ClearLoop: MOV	@R0, #DIS_BLACK  ;  上电消隐
	              INC	 R0
	              DJNZ	R2,  ClearLoop	
				  
Main_loop: 			LCALL   delay_ms1	
	                LCALL   DispScan
	                LJMP    Main_loop           ;   循环等待中断
					
DispScan: MOV	A, hour
	              MOV	B, #10
	              DIV  	AB
	              MOV	LED8+0, A    ;十位
	              MOV	LED8+1, B    ;个位
	              MOV        R7, #8          ; 2个数码管

		MOV A,minute
		MOV	B, #10
	              DIV  	AB
	              MOV	LED8+2, A    ;十位
	              MOV	LED8+3, B    ;个位
	              MOV        R7, #8          ; 2个数码管
		
		MOV A,second
		MOV	B, #10
	              DIV  	AB
	              MOV	LED8+4, A    ;十位
	              MOV	LED8+5, B    ;个位
				  MOV   LED8+6, #17
				  MOV   LED8+7, #17
	              MOV        R7, #8          ; 2个数码管
NEXT:	
			
			MOV	DPTR, #T_COM   ; 位码表头   
	        MOV	A, disp_index      ;  数码管号
	        MOVC	A, @A+DPTR
	        CPL 	A                        ; 595级联时用的/Q7
	        LCALL	Send_595	; 输出位码
	        MOV	DPTR, #T_Disp ; 7段码表头
	        MOV	A, disp_index
	        ADD	A, #LED8
	        MOV	R0, A
	        MOV	A, @R0               ; 待显示的数
MOVC	A, @A+DPTR
LCALL	Send_595	; 输出段码
CLR	 HC595_RCLK	; 产生锁存时钟
SETB	HC595_RCLK

INC	 disp_index      ; 下一数码管
DJNZ    R7, NEXT
MOV	disp_index, #0 ; 8位结束回0
RET
; HC595串行移位输出一个字符

Send_595:   MOV   R2, #8
Send_Loop: RLC      A
	                  MOV  HC595_SER, C
	                  CLR    HC595_SRCLK 
                      SETB  HC595_SRCLK  ; 产生移位脉冲
	                  DJNZ  R2, Send_Loop
	                  RET

delay_ms10: MOV      R7,#50    ;延时50mS子程序
DL1:   MOV      R6,#2
DL2:   MOV      R5,#248

       DJNZ     R5,$

       DJNZ     R6,DL2

       DJNZ     R7,DL1

       RET
	   
delay_ms1: MOV      R7,#100    ;延时0.1mS子程序

       DJNZ     R7,$

       RET

T_Disp: DB 3FH,06H,5BH,4FH,66H,6DH, 7DH,07H
              DB  7FH,6FH,77H,7CH,39H,5EH,79H,71H,00H,40H;
; 0-F的7段码及消隐 
T_COM: DB 01H,02H,08H,10H,40H,80H,04H,20H  ;  位码
	           
T1_ISR: DJNZ  R5,  EXIT          ; 1s未到，退出中断
              MOV  R5,  #14H
    
	
	MOV A,second
	CJNE A,#59,SECOND_ADD
	MOV second,#0
	
	MOV A,minute
	CJNE A,#59,MINUTE_ADD
	MOV minute,#0
	
	MOV A,hour
	CJNE A,#23,HOUR_ADD
	MOV hour,#0
	     
	EXIT: RETI
	SECOND_ADD:		INC second  
	RETI
	MINUTE_ADD:		INC minute
	RETI
	HOUR_ADD:		INC hour
	RETI
 
INT0_ISR:  
			
			INC hour
			MOV A,hour
			CJNE A,#24,EXIT2
			MOV hour,#0
			
			EXIT2:
			RETI

INT1_ISR:  
		
			INC minute 
			MOV A,minute
			CJNE A,#60,EXIT1
			MOV minute,#0
			
			EXIT1:RETI
			
			
	              

 
 END
