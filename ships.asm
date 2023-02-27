.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf:proc 

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Exemplu proiect desenare",0
area_width EQU 640
area_height EQU 480
area DD 0

counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20
p dd  0
d dd 0
p1 dd 0
d1 dd 0

piese_totale dd 15
puncte_albastre dd 0
puncte_rosii dd 0
copie_piese_totatle dd 15

margine_stg equ 110
margine_sus equ 50

inceput_vaporas1 equ 110
sfarsit_vaporas1  equ  50

inceput_vaporas2 equ 310
sfarsit_vaporas2 equ 230


inceput_vaporas3 equ 150
sfarsit_vaporas3  equ 302




inceput dd 0
sfarsit dd 0

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

format db "%d ", 0
.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0505050h
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp



; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

line_horizontal macro x, y, l, h, color ; de unde sa inceapa, lungimea liniei (pixeli)
    local bucla_linie
	;crearea unui pixwl
	mov eax, y; formula pt y, eax=y
	mov ebx, area_width
	mul ebx ; y*area_width
	add eax, x; eax=y*area_width+x
	shl eax, 2 ; inmultimul cu 4(pozitia in vectorul de pixel)
	add eax, area
	mov ecx , h 
	
	;bucla pt linie 
	bucla_linii:
	mov esi, ecx
	mov ecx, l ; nr de pixeli , ecx primeste lungimea unei linii
 
 bucla_linie:
mov dword ptr[eax], color ; se coloreaza adresa de la eax
;deplasare 
add eax, 4 ; pentru a sari la aria urmatorului pixel
loop bucla_linie

mov ecx, esi 
add eax , area_width*144 ; spatiul catre urmatoarea linie  
sub eax , l*4
loop bucla_linii

endm

 ; linie vericala pentru crearea matricei 
linie_verticala macro x, y, l,color 
local bucla_l
    
	mov eax, y; formula pt y, eax=y
	mov ebx, area_width
	mul ebx ; y*area_width
	add eax, x; eax=y*area_width+x
	shl eax, 2 ; inmultimul cu 4(pozitia in vectorul de pixel)
	add eax, area 
    mov ecx, l ; nr de pixeli
;	bucla pt linie

	bucla_l:
	mov dword ptr[eax], color
;	deplasare
	
	add eax, 4*area_width
	loop bucla_l
	
	endm
	
colorare macro x, y, len, lat ,color 
local bucla_l
local bucla_liniiv
    mov eax, y; formula pt y, eax=y
	mov ebx, area_width
	mul ebx ; y*area_width
	add eax, x; eax=y*area_width+x
	shl eax, 2 ; inmultimul cu 4(pozitia in vectorul de pixel)
	add eax, area 

	 
	mov ecx, len ; nr de pixeli pt lungime 
	;bucla pt linie
	bucla_liniiv:
	mov esi, ecx
	mov ecx, lat   ; nr de pixeli pt latime 
	
	bucla_l:
	mov dword ptr[eax], color  ; colorez pixelul de la asdresa eax 
	;deplasare pentru a trece la pixelul de langa 
	add eax, 4 
	loop bucla_l
	
	
	mov ecx, esi  ; mut  lungimea in ecx 
	add eax, area_width*4 ; trec la pixelul de jos 
	sub eax, lat*4 
	loop bucla_liniiv
endm



; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 78
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	
evt_click:
; pentru try_again 
mov edx, [ebp+arg2]
mov ecx, [ebp+arg3]
mov p1, edx
mov d1 , ecx
 cmp edx, 550
   jl button_failed
   cmp edx, 610
   jg button_failed
   cmp ecx, 200
   jl button_failed
   cmp ecx, 265
   jg button_failed
   resetare:
   make_text_macro ' ', area, 270, 240
	make_text_macro ' ', area, 280, 240
	make_text_macro ' ', area, 290, 240
	make_text_macro ' ', area, 300, 240
	make_text_macro ' ', area, 320, 240
	make_text_macro ' ', area, 330, 240
	make_text_macro ' ', area, 340, 240
	make_text_macro ' ', area, 350, 240
	colorare 550 , 200, 60, 65, 0505050h
	make_text_macro ' ' , area, 555,210
	make_text_macro ' ' , area, 565,210
	make_text_macro ' ' , area, 575,210
	make_text_macro ' ' , area, 560,229
	make_text_macro ' ' , area, 570,229
	make_text_macro ' ' , area, 580,229
	make_text_macro ' ' , area, 590, 229
	make_text_macro ' ' , area, 600,229
	 make_text_macro ' ', area, 290, 450
	make_text_macro ' ', area, 300, 450
	make_text_macro ' ', area, 310, 450
	make_text_macro ' ', area, 320, 450
	make_text_macro ' ', area, 330, 450
	make_text_macro ' ', area, 340, 450
	
	
	button_failed:
	jmp verif

	; verificam daca click-ul se afla in cadranul matricii
	verif:
	mov edx, [ebp+arg2]
 
   mov ecx, [ebp+arg3]
	

	mov ebx, 110
	cmp edx, ebx 
	jl button_fail
	cmp edx, 510
	jg button_fail
	mov ebx, 50
	cmp ecx , ebx
	jl button_fail
	cmp ecx, 410
	jg button_fail
	
	
	
	mov eax, [ebp+arg2] ; locul unde dam click pentru Ox 
	mov ebx, [ebp+arg2]
	
    mov ecx , [ebp+arg3]  ; locul unde dam click pentru Oy
	mov edx, [ebp+arg3]
	mov esi, 110
	mov edi, 50
	
	
   ; vrem sa ajungem la latura din stanga cea mai apropiata de locul unde dam click , deci facem adunari cu 40 , resp 36
	pentru_Ox:
    cmp ebx, esi
	jl distanta
	add esi, 40
	jmp pentru_Ox;
	distanta:
	sub esi, 40
	pentru_Oy:
	cmp edx, edi
	jl dist
	add edi, 36
   jmp pentru_Oy;
	dist:
	sub edi, 36
	 mov eax, [ebp+arg2] ; x-ul
	 
	 
 

mov eax, [ebp+arg3]; formula pt y, eax=y
	mov ebx, area_width
	mul ebx ; y*area_width
	add eax, [ebp+arg2]; eax=y*area_width+x
	shl eax, 2 ; inmultimul cu 4(pozitia in vectorul de pixel)
	add eax, area
	
	
	
	; vapor 1
	cmp esi, inceput_vaporas1
	je color1
	cmp  esi, inceput_vaporas1+40
	 je color2
	 cmp esi, inceput_vaporas1+80
     je color3
	 jmp vapor2;
	
	color1:
	cmp edi,sfarsit_vaporas1
	je colorare1
	cmp edi, sfarsit_vaporas1+36
	je colorare1
	jmp vapor2;
	colorare1:
	cmp dword ptr[eax], 0800000h
	je afisare_litere
	colorare esi, edi, 36, 40,0800000h
	inc puncte_rosii
	dec piese_totale
	jmp afisare_litere;
	
	 color2:
	 cmp edi, sfarsit_vaporas1+36
	 je colorare2
	jmp vapor2;
	 colorare2:
		cmp dword ptr[eax], 0800000h
	je afisare_litere
	colorare esi, edi, 36, 40, 0800000h
	inc puncte_rosii
	dec piese_totale
	jmp afisare_litere;
	

	color3:
	cmp edi, sfarsit_vaporas1
	je colorare3
	cmp edi, sfarsit_vaporas1+36
	je colorare3
	jmp vapor2
	colorare3:
		cmp dword ptr[eax], 0800000h
	je afisare_litere
	colorare esi, edi, 36, 40,  0800000h
	inc puncte_rosii
	dec piese_totale
	jmp afisare_litere;

	; vapor2
	vapor2:
	cmp esi, inceput_vaporas2
	je colori1
	cmp  esi, inceput_vaporas2+40
	 je colori2
	 cmp esi, inceput_vaporas2+80
     je colori3
	 jmp vapor3;
	
	colori1:
	cmp edi,sfarsit_vaporas2
	je colorarei1
	cmp edi, sfarsit_vaporas2+36
	je colorarei1
	jmp vapor3;
	colorarei1:
		cmp dword ptr[eax], 0800000h
	je afisare_litere
	colorare esi, edi, 36, 40,0800000h
	inc puncte_rosii
	dec piese_totale
	jmp afisare_litere;
	
	 colori2:
	 cmp edi, sfarsit_vaporas2+36
	 je colorarei2
	jmp vapor3;
	 colorarei2:
		cmp dword ptr[eax], 0800000h
	je afisare_litere
	colorare esi, edi, 36, 40, 0800000h
	inc puncte_rosii
	dec piese_totale
	jmp afisare_litere;
	

	colori3:
	cmp edi, sfarsit_vaporas2
	je colorarei3
	cmp edi, sfarsit_vaporas2+36
	je colorarei3
	jmp vapor3
	colorarei3:
		cmp dword ptr[eax], 0800000h
	je afisare_litere
	colorare esi, edi, 36, 40,  0800000h
	inc puncte_rosii
	dec piese_totale
	jmp afisare_litere;
	
	; vapor3
   vapor3:
     cmp esi, inceput_vaporas3
	je col1
	cmp  esi, inceput_vaporas3+40
	 je col2
	 cmp esi, inceput_vaporas3+80
     je col3
	 jmp colorare_rest
	
	col1:
	cmp edi,sfarsit_vaporas3
	je coloraree1
	cmp edi, sfarsit_vaporas3+36
	je coloraree1
	jmp colorare_rest
	coloraree1:
		cmp dword ptr[eax], 0800000h
	je afisare_litere 
	colorare esi, edi, 36, 40,0800000h
	inc puncte_rosii
	dec piese_totale
	jmp afisare_litere;
	
	
	 col2:
	 cmp edi, sfarsit_vaporas3+36
	 je coloraree2
	 jmp colorare_rest
	 coloraree2:
	 	cmp dword ptr[eax], 0800000h
	je afisare_litere
	 colorare esi, edi, 36, 40, 0800000h
	 inc puncte_rosii
	 dec piese_totale
jmp afisare_litere;
	
	col3:
	cmp edi, sfarsit_vaporas3
	je coloraree3
	cmp edi, sfarsit_vaporas3+36
	je coloraree3
	jmp colorare_rest
	coloraree3:
		cmp dword ptr[eax], 0800000h
	je afisare_litere
	colorare esi, edi, 36, 40, 0800000h
	inc puncte_rosii
	dec piese_totale
	jmp afisare_litere;
colorare_rest:
	cmp dword ptr[eax],099ccffh
	je afisare_litere
colorare esi, edi, 36, 40, 099ccffh
   inc puncte_albastre
   

  
	
	jmp afisare_litere
	
 

	button_fail:
     jmp afisare_litere 


	
evt_timer:
	inc counter
	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 10
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10
	

	
	
	;scriem un mesaj
	
	
	make_text_macro 'V', area, 260, 25
	make_text_macro 'A', area, 270, 25
	make_text_macro 'P', area, 280, 25
	make_text_macro 'O', area, 290, 25
	make_text_macro 'R', area, 300, 25
	make_text_macro 'A', area, 310, 25
	make_text_macro 'S', area, 320, 25
	 make_text_macro 'E', area, 330, 25
	 
	
	 
	; make_text_macro 'A', area, 140, 120
	
	
	
	line_horizontal  110, 50, 400,11, 099ccffh
	linie_verticala 110, 50, 360, 099ccffh
	 linie_verticala 150, 50, 360, 099ccffh
	 linie_verticala 190, 50, 360, 099ccffh
	 linie_verticala 230, 50, 360, 099ccffh
	 linie_verticala 270, 50, 360, 099ccffh
	 linie_verticala 310, 50, 360, 099ccffh
	 linie_verticala 350, 50, 360, 099ccffh
	 linie_verticala 390, 50, 360, 099ccffh
	 linie_verticala 430, 50, 360, 099ccffh
	 linie_verticala 470, 50, 360, 099ccffh
	 linie_verticala 510, 50, 360, 099ccffh
	 

	
mov ecx , 10
mov eax , puncte_rosii
mov edx , 0
div ecx
add eax, '0'

make_text_macro eax , area, 560, 86
add edx, '0'
make_text_macro edx, area , 570, 86

mov ecx , 10
mov eax , puncte_albastre
mov edx , 0
div ecx
add eax, '0'

make_text_macro eax , area,  560 , 358
add edx, '0'
make_text_macro edx, area , 570, 358


 mov ecx , 10
mov eax , piese_totale
mov edx , 0
div ecx
add eax, '0'

make_text_macro eax , area, 50, 205
add edx, '0'

make_text_macro edx, area , 60, 205


mov eax , 12
mov edx, copie_piese_totatle
cmp edx, puncte_rosii
je afisare_winner
cmp edx, puncte_albastre  ; jocul se termina cand sunt 15 piese ratate si mai putin de 12 piese din vaporas descoperite 
je comparare_ratate
jmp final_draw
comparare_ratate:
cmp eax, puncte_rosii
jge afisare_gameOver
jmp final_draw
   
afisare_winner:	 
mov puncte_albastre,0
	mov puncte_rosii,0
	mov piese_totale,15
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 78
	push area
	call memset
	add esp, 12
    make_text_macro 'W', area, 290, 450
	make_text_macro 'I', area, 300, 450
	make_text_macro 'N', area, 310, 450
	make_text_macro 'N', area, 320, 450
	make_text_macro 'E', area, 330, 450
	make_text_macro 'R', area, 340, 450
	mov puncte_albastre,0
	mov piese_totale, 15
	mov puncte_rosii,0
	colorare 550 , 200, 60, 65, 099ccffh
	make_text_macro 'T' , area, 555,210
	make_text_macro 'R' , area, 565,210
	make_text_macro 'Y' , area, 575,210
	make_text_macro 'A' , area, 560,229
	make_text_macro 'G' , area, 570,229
	make_text_macro 'A' , area, 580,229
	make_text_macro 'I' , area, 590, 229
	make_text_macro 'N' , area, 600,229
    jmp final_draw
	
afisare_gameOver:

 
	mov puncte_albastre,0
	mov puncte_rosii,0
	mov piese_totale,15
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 78
	push area
	call memset
	add esp, 12
	make_text_macro 'G', area, 270, 240
	make_text_macro 'A', area, 280, 240
	make_text_macro 'M', area, 290, 240
	make_text_macro 'E', area, 300, 240
	make_text_macro 'O', area, 320, 240
	make_text_macro 'V', area, 330, 240
	make_text_macro 'E', area, 340, 240
	make_text_macro 'R', area, 350, 240
colorare 550 , 200, 60, 65, 099ccffh
	make_text_macro 'T' , area, 555,210
	make_text_macro 'R' , area, 565,210
	make_text_macro 'Y' , area, 575,210
	make_text_macro 'A' , area, 560,229
	make_text_macro 'G' , area, 570,229
	make_text_macro 'A' , area, 580,229
	make_text_macro 'I' , area, 590, 229
	make_text_macro 'N' , area, 600,229
	mov puncte_albastre,0
	mov puncte_rosii,0
	mov piese_totale, 15

	jmp final_draw
	
  
	

	

final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20


	
	

	;terminarea programului
	push 0
	call exit
end start
