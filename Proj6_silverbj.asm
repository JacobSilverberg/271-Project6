TITLE Designing low-level I/O procedures    (Proj6_silverbj.asm)

; Author: Jacob Silverberg - 934-372-804
; Last Modified:
; OSU email address: silverbj@oregonstate.edu
; Course number/section:   CS271 Section 400
; Project Number:  6               Due Date: 8/13/2021
; Description: This is a MASM project utilzing macros and procedures in order to 
; receive 10 numbers from a user, read in string form, which are converted to integers
; to determine the sum and average.  Those are converted to strings and printed.

INCLUDE Irvine32.inc

; (insert macro definitions here)

; ---------------------------------------------------------------------------------
; Name: mGetString
; Function: Generates a random string of lowercase letters.
; Preconditions: do not use eax, ecx, esi as arguments
; Receives:
; print_string = array address of string to be printed
; user_input = array address where the input string will be stored
; returns: user_input string
; ---------------------------------------------------------------------------------
mGetString		MACRO	print_string, user_input
	PUSH	EDX
	MOV		EDX, OFFSET print_string
	CALL	WriteString
	MOV		ECX, SIZEOF user_input
	MOV		EDX, OFFSET user_input
	CALL	ReadString
	PUSH	EAX
	POP		byte_count
	POP		EDX
ENDM


; ---------------------------------------------------------------------------------
; Name: mDisplayString
; Function: Prints a string
; Preconditions: string argument is a string
; Receives: 
; string = string address
; returns: None
; ---------------------------------------------------------------------------------
mDisplayString	MACRO	string
	PUSH	EDX	
	MOV		EDX, OFFSET string
	CALL	WriteString
	POP		EDX
ENDM

; (insert constant definitions here)

ASCII_LOW		=	48
ASCII_HI		=	57
ASCII_NEG		=	45
ASCII_PLUS		=	43
MAX_32			=	2147483646		; Largest signed decimal 32 bit storage
MIN_32			=	-2147483647		; Smalled signed decimal 32 bit storage
ARRAYSIZE		=	10
PLACE_INCREMENT	=	10				; Used for exponential calcs

.data

; (insert variable definitions here)
	intro_1			BYTE	"PROGRAMMING ASSIGNMENT 6: Designing low-level I/O procedures",10,13,0
	intro_2			BYTE	"Written by: Jacob Silverberg",10,13,0 
	instruct_1		BYTE	"Please provide 10 signed decimal integers.",10,13,0
	instruct_2		BYTE	"Each number needs to be small enough to fit inside a 32 bit register.",10,13,0
	instruct_3		BYTE	"After you have finished inputting the raw numbers I will display a list of the integers, their sum, and their average value.",10,13,0
	num_prompt		BYTE	"Please enter an signed number: ",0
	error_str		BYTE	"ERROR: You did not enter a signed number or your number was too big.",10,13,0
	sum_str			BYTE	"The sum of these numbers is: ",0
	avg_str			BYTE	"The rounded average of these numbers is: ",0
	values_str		BYTE	"You entered the following numbers:",0
	space_str		BYTE	" ",0
	user_input		BYTE	21 DUP(?)
	byte_count		DWORD	?
	num_array		DWORD	ARRAYSIZE DUP(?)
	num_converted	SDWORD	?
	sum				DWORD	?
	avg				DWORD	?
	sub_str			BYTE	"-",0

.code
main PROC

; (insert executable instructions here)

	; Display program introduction and strings
	mDisplayString		intro_1
	mDisplayString		intro_2
	call	CrLf
	mDisplayString		instruct_1
	mDisplayString		instruct_2
	mDisplayString		instruct_3
	push	num_converted
	push	OFFSET num_array
	push	OFFSET user_input
	mov		ECX, ARRAYSIZE

_getUserInput:									; Loop to get 10 user inputs into ReadVal
	call	ReadVal								
	mov		ESI, OFFSET num_array
	mov		EAX, ECX
	mov		EBX, ARRAYSIZE
	sub		EBX, EAX
	mov		EAX, TYPE num_array					
	push	EDX									; Maintain EDX
	mul		EBX
	pop		EDX
	add		ESI, EAX							; Increment ESI based on loop number
	mov		[ESI], EDX
	loop	_getUserInput

_writeVal:
	push	LENGTHOF num_array
	push	OFFSET num_array
	push	LENGTHOF num_array
	call	WriteVal

_numSum:
	push	LENGTHOF num_array
	push	OFFSET num_array
	call	NumSum

_numAvg:
	push	LENGTHOF num_array
	push	OFFSET num_array
	call	NumAverage

	Invoke ExitProcess,0	; exit to operating system
main ENDP
; (insert additional procedures here)

; ------------------------------------------
; Name: ReadVal
; Description: Utilizes mGetString to take user input string.  Evaluates string for validity and
; converts to a string for storage in sum_array.  Displays error if string fails validity.
; Preconditions: Relevant ASCII constants and ARRAYSIZE are set as constants.
; Postconditions: EAX, EBX, EDX changed.  someArray Changed. EBP and ECX preserved
; Receives: OFFSET user_input, OFFSET num_array, num_converted
; Returns: EDX contains integer
; ------------------------------------------

ReadVal PROC

	push	EBP
	mov		EBP, ESP
	push	ECX

_funcStart:
	CLD										; Clear direction flag (will increment forward)
	MOV		ESI, [EBP+8]					; Move OFFSET user_input to ESI
	MOV		EDI, [EBP+12]					; Move current OFFSET num_array to EDI
	MOV		EBX, [EBP+16]					; Move num_converted to EBX
	
_getStringStart:
	mGetString num_prompt, user_input
	PUSH	byte_count
	pop		ECX								; Set EDX to number of chars entered (internal loop count)

_userInputSignCheck:
	LODSB									; Load [ESI] to AL, increments ESI
	CMP		AL, ASCII_NEG					; Check for negative sign
	JE		_validatedDigit
	CMP		AL, ASCII_PLUS					; Check for positive sign
	JE		_validatedDigit

_userInputLoopStart:
	CMP		AL, ASCII_LOW					; Check if below ASCII number range
	JL		_errorDisplay					
	CMP		AL, ASCII_HI					; Check if above ASCII number range
	JG		_errorDisplay
	JMP		_validatedDigit					; If passed all validations

_validatedDigit:
	LODSB
	LOOP		_userInputLoopStart

_validatedNumber:
	; Reset ESI, ECX, EDI, EBX, EDX for usage in number conversion
	MOV		ESI, [EBP+8]					; Move OFFSET user_input to ESI
	MOV		EDI, [EBP+12]					; Move current OFFSET num_array to EDI
	MOV		EBX, [EBP+16]					; Move num_converted to EBX
	PUSH	byte_count
	POP		ECX
	MOV		EDX, 0							; Clear EDX for number storage
	
_numberConversion:
	MOV		EAX, 0							; Clear EAX
	PUSH	ECX								; push external loop
	DEC		ECX								; set for usage in exponential calc
	LODSB
	CMP		AL, ASCII_NEG
	JE		_signLoop
	CMP		AL, ASCII_PLUS
	JE		_signLoop
	SUB		AL, ASCII_LOW					; Subtract 48 from ASCII digit
	PUSH	EAX								; Place value on stack
	MOV		EBX, PLACE_INCREMENT			; Set EBX, EAX for exponential place calculation
	MOV		EAX, 1
	CMP		ECX, 0
	JE		_onesPlace						; Skips exponential calc if process in Ones place.
	JMP		_exponentCalc

_signLoop:
	POP		EAX								; Clear PUSH ECX
	JMP		_numberConversion

	
_exponentCalc:
	PUSH	EDX
	MUL		EBX								; Caclulate 10 ^ Place
	POP		EDX
	LOOP	_exponentCalc
	JMP		_calculated
	
_onesPlace:
	JMP		_calculated
	
_calculated:
	POP		EBX
	PUSH	EDX								; Preserve EDX (Number total)
	MUL		EBX
	POP		EDX
	ADD		EDX, EAX						; Move current total to EDX
	POP		ECX								; Pop external loop
	LOOP	_numberConversion
	JMP		_negativeSign

_negativeSign:
	MOV		ESI, [EBP+8]					; Move OFFSET user_input to ESI
	LODSB
	CMP		AL, ASCII_NEG
	JE		_negativeNum
	JMP		_funcEnd

_negativeNum:
	NEG		EDX
	JMP		_funcEnd

_funcEnd:
	pop		ECX								; Reset ECX counter
	pop		EBP
	
	ret

_errorDisplay:
	mDisplayString error_str				; Display error string
	JMP		_funcStart

ReadVal ENDP


; ------------------------------------------
; Name: WriteVal
; Description: Procedure for displaying the values given by the user.
; Preconditions: MAX_32, ASCII constants defined.  values_str and sum variables exist
; Postconditions: EAX, EBX, ECX, EDX changed.  sum_array Changed.
; Receives: LENGTHOF sum_array, OFFSET sum_array
; Returns: None
; ------------------------------------------

WriteVal PROC

	push	EBP
	mov		EBP, ESP

	mov		ECX, [EBP+8]				; Set loop counter to length of array
	mov		ESI, [EBP+12]				; Set array location

	mDisplayString	values_str
	call	CrLf

_fullLoopStart:
	mov		EAX, [ESI]
	push	ECX
	cmp		EAX, MAX_32
	jae		_negative
	jmp		_asciiConvert

_negative:
	mDisplayString	sub_str
	neg		EAX
	jmp		_asciiConvert

_asciiConvert:							; EAX holds the int
	mov		EBX, 0						; Set EBX to 0 and ECX to 10 for ASCII conversion steps
	mov		ECX, 10
_asciiLoop:
	cmp		EAX, 10	
	jl		_finalLoop
	CDQ
	idiv	ECX
	push	EDX							; Push remainder to stack
	inc		EBX							; Count digits
	cmp		EAX, 10						; Loop controller based on digits remaining
	jge		_asciiLoop
	jl		_finalLoop

_finalLoop:
	cmp		EAX, 10
	jl		_singleDigit
	idiv	ECX
	push	EDX
	inc		EBX
	mov		ECX, EBX					; Set count of digits as loop length

_singleDigit:
	push	EAX
	inc		EBX
	mov		ECX, EBX
	jmp		_asciiPop

_asciiPop:
	pop		EAX
	add		EAX, ASCII_LOW
	push	EAX
	pop		sum
	mDisplayString	sum					; Display strings
	loop	_asciiPop
	jmp		_nextValue

_nextValue:
	pop		ECX
	add		ESI, TYPE num_array
	mDisplayString	space_str
	loop	_fullLoopStart

	call	CrLf

_funcEnd:
	pop		EBP
	
	ret
WriteVal ENDP


; ------------------------------------------
; Name: NumSum
; Description: Procedure which loops through sum_array and sums the 10 values.  Writes the final
; sum using mDisplayString
; Preconditions: mDisplayString macro exists, MAX_32 constant exists, sub_str variable exists
; Postconditions: EAX, EBX, ECX, EDX changed.
; Receives: OFFSET sum_array, LENGTHOF sum_array
; Returns: None
; ------------------------------------------

NumSum PROC
	push	EBP
	mov		EBP, ESP

	mov		ESI, [EBP+8]				; Set array location
	mov		ECX, [EBP+12]				; Set loop counter to length of array
	mDisplayString	sum_str				; Display String

_sumStart:
	mov		EAX, [ESI]
	dec		ECX
	jmp		_sumLoop

_sumLoop:
	add		ESI, TYPE num_array
	mov		EBX, [ESI]
	cmp		EBX, MAX_32
	jae		_negativeSub
	jmp		_positiveAdd

_positiveAdd:
	add		EAX, EBX
	loop	_sumLoop
	jmp		_asciiConvert

_negativeSub:
	neg		EBX
	sub		EAX, EBX
	loop	_sumLoop
	jmp		_asciiConvert



_asciiConvert:							; EAX holds the int
	cmp		EAX, MAX_32
	jae		_negativeConvert
	jmp		_convertContinue

_negativeConvert:
	mDisplayString	sub_str
	neg		EAX

_convertContinue:
	mov		EBX, 0						; Set EBX to 0 and ECX to 10 for ASCII conversion steps
	mov		ECX, 10
_asciiLoop:
	CDQ
	idiv	ECX
	push	EDX							; Push remainder to stack
	inc		EBX							; Count digits
	cmp		EAX, 10						; Loop controller based on digits remaining
	jge		_asciiLoop
	jl		_finalLoop

_finalLoop:
	CDQ
	idiv	ECX
	push	EDX
	inc		EBX
	mov		ECX, EBX					; Set count of digits as loop length

_asciiPopFirst:
	pop		EAX
	jmp		_popContinue

_asciiPopLoop:
	pop		EAX
_popContinue:
	cmp		EAX, MAX_32
	jae		_negativeInLoop
	jmp		_continueInLoop

_negativeInLoop:
	neg		EAX
	jmp		_continueInLoop

_continueInLoop:
	add		EAX, ASCII_LOW
	jmp		_displayContinue

_displayContinue:
	push	EAX
	pop		sum
	mDisplayString	sum					; Display strings
	loop	_asciiPopLoop

	call	CrLf


_funcEnd:
	pop		EBP

	ret
NumSum ENDP


; ------------------------------------------
; Name: NumAverage
; Description: Procedure which loops through sum_array and sums the 10 values.  Writes the final
; sum using mDisplayString but ignores final digit to give the average (rounded down).
; Preconditions: mDisplayString macro exists, MAX_32 constant exists, sub_str variable exists
; Postconditions: EAX, EBX, ECX, EDX changed.
; Receives: OFFSET sum_array, LENGTHOF sum_array
; Returns: None
; ------------------------------------------

NumAverage PROC
	push	EBP
	mov		EBP, ESP

	mov		ESI, [EBP+8]				; Set array location
	mov		ECX, [EBP+12]				; Set loop counter to length of array
	mDisplayString	avg_str				; Display String

_sumStart:
	mov		EAX, [ESI]
	dec		ECX
	jmp		_sumLoop

_sumLoop:
	add		ESI, TYPE num_array
	mov		EBX, [ESI]
	cmp		EBX, MAX_32							; Checks value against MAX_32 
	jae		_negativeSub						; Subtracts if negative
	jmp		_positiveAdd						; Adds if positive

_positiveAdd:
	; Adds to EAX
	add		EAX, EBX
	loop	_sumLoop
	jmp		_asciiConvert

_negativeSub:
	; Subtracts from EAX
	neg		EBX
	sub		EAX, EBX
	loop	_sumLoop
	jmp		_divByTen

_divByTen:
	MOV		EBX, 10
	CDQ
	idiv	EAX

_asciiConvert:							; EAX holds the int
	cmp		EAX, MAX_32
	jae		_asciiAvgNeg
	jmp		_asciiAvgContinue

_asciiAvgNeg:
	mDisplayString	sub_str
	neg		eax

_asciiAvgContinue:
	mov		EBX, 0						; Set EBX to 0 and ECX to 10 for ASCII conversion steps
	mov		ECX, 10
_asciiLoop:
	CDQ
	idiv	ECX
	push	EDX							; Push remainder to stack
	inc		EBX							; Count digits
	cmp		EAX, 10						; Loop controller based on digits remaining
	jge		_asciiLoop
	jl		_finalLoop

_finalLoop:
	CDQ
	idiv	ECX
	push	EDX
	inc		EBX
	mov		ECX, EBX					; Set count of digits as loop length

_asciiPopFirst:
	dec		ECX
	pop		EAX
	jmp		_popContinue

_asciiPopLoop:
	pop		EAX
_popContinue:
	cmp		EAX, MAX_32					; Check for negative value against MAX_32
	jae		_negativeInLoop
	jmp		_continueInLoop

_negativeInLoop:
	neg		EAX							; Negates EAX if negative
	jmp		_continueInLoop

_continueInLoop:
	add		EAX, ASCII_LOW
	jmp		_displayContinue

_displayContinue:
	push	EAX
	pop		sum
	mDisplayString	sum					; Display strings
	loop	_asciiPopLoop

	call	CrLf

_funcEnd:
	pop		EBP

	ret
NumAverage ENDP

END main
