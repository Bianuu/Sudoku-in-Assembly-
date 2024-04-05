.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
citat db "%d ",0
window_title DB "SUDOKU BY CIOBAN FABIAN-REMUS",0
area_width EQU 1350
area_height EQU 1000
area DD 0
;stiu ca asm nu avem matrice ca in C,ci e un vector,dar n-am stiut cum sa denumesc altfel
vectmat DD 81 dup(0) ;matricea care contine valorile din casute
vectmatverifc DD 81 dup(0) ;matricea cu 0/1 pentru a sti unde sunt valorile predefinite
verifvectcond DB 10 dup(0) ;vectorul pe care o sa realizam verificarile
element DD 0
initialla dd 0
initiallb dd 0
initiallc dd 0
semafor dd 0
counter DD 0 ; numara evenimentele de tip timer
oficialcountersec DD 0
counter_fail dd 0
arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20
marimepatrat DD 90
adresaactuala DD 0
a DD 0 ;coordonata
b DD 0 ;coordonata
contorpatrate DB 0 ;ca un fel de contor "de repetari"
contorpatrate1 DB 0 ;ca un fel de contor "de repetari"
contorpatrate2 DB 0 ;ca un fel de contor "de repetari"
;dimensiunea matricelor de numere
symbol_width EQU 10
symbol_height EQU 20

include digits.inc
include letters.inc

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
	mov dword ptr [edi], 0FFFFFFh
	
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

;un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

;calculam coordonatele_adresei "unde s-a dat click"
calc_adresa_matvect macro x,y 
	local et,continuare,final
	mov marimepatrat,100

	cmp dword ptr x,155
	jl final
	
	cmp dword ptr y,100
	jl final
	
	cmp dword ptr x,1050
	jg final
	
	cmp dword ptr y,989
	jg final
	
	mov eax,x
	sub eax,155
	mov edx,0
	div marimepatrat
	mov a,eax

	mov eax,y
	sub eax,100
	mov edx,0
	div marimepatrat
	mov b,eax

	mov marimepatrat,9
	mul marimepatrat
	add eax,a
	mov adresaactuala,eax

	mov marimepatrat,100
	mov eax,a
	mul marimepatrat
	add eax,200
	mov a,eax

	mov eax,b
	mul marimepatrat
	add eax,140
	mov b,eax

;dreptunghicica a,b,10,10,0ff0000h

final:
endm

;macro de desenare - cam tot ce tine de "desing"
dreptunghicica macro x,y,lung,latime,color
local bucla_line,bucla
mov eax,y ;eax=y
mov ebx,area_width
mul ebx ;eax=y*area_width
add eax,x ;eax=y*area_width+x
shl eax,2 ;eax=(y*area_width+x)*4
add eax,area
mov ecx,latime

  bucla : 
mov esi,ecx
mov ecx,lung

  bucla_line :
mov dword ptr[eax],color
add eax,4
loop bucla_line
mov ecx,esi
add eax,area_width*4
sub eax,lung*4
loop bucla
endm

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
	
;mai jos e codul care intializeaza fereastra cu pixeli albi si a design-uli
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
    push area
	call memset
	add esp, 12
	
	dreptunghicica 155,100,910,899,0fffffh
	
;coloana1
	dreptunghicica 170,110,80,80,0f0f8ffh
	dreptunghicica 170,210,80,80,0ff0000h
	dreptunghicica 170,310,80,80,0ff0000h
	dreptunghicica 170,410,80,80,0f0f8ffh
	dreptunghicica 170,510,80,80,0f0f8ffh
	dreptunghicica 170,610,80,80,000ff00h
	dreptunghicica 170,710,80,80,022h
	dreptunghicica 170,810,80,80,0f0f8ffh
	dreptunghicica 170,910,80,80,022h
	
;coloana2
	dreptunghicica 270,110,80,80,0f0f8ffh
	dreptunghicica 270,210,80,80,0ff0000h
	dreptunghicica 270,310,80,80,0ff0000h
	dreptunghicica 270,410,80,80,000ff00h
	dreptunghicica 270,510,80,80,0f0f8ffh
	dreptunghicica 270,610,80,80,000ff00h
	dreptunghicica 270,710,80,80,022h
	dreptunghicica 270,810,80,80,022h
	dreptunghicica 270,910,80,80,022h
	
;coloana3
	dreptunghicica 370,110,80,80,0f0f8ffh
	dreptunghicica 370,210,80,80,0f0f8ffh
	dreptunghicica 370,310,80,80,0ff0000h
	dreptunghicica 370,410,80,80,000ff00h
	dreptunghicica 370,510,80,80,000ff00h
	dreptunghicica 370,610,80,80,000ff00h
	dreptunghicica 370,710,80,80,022h
	dreptunghicica 370,810,80,80,022h
	dreptunghicica 370,910,80,80,022h
	
;coloana4
	dreptunghicica 470,110,80,80,0f0f8ffh
	dreptunghicica 470,210,80,80,0f3ff00h
	dreptunghicica 470,310,80,80,0f3ff00h
	dreptunghicica 470,410,80,80,0b33c00h
	dreptunghicica 470,510,80,80,0b33c00h
	dreptunghicica 470,610,80,80,0b33c00h
	dreptunghicica 470,710,80,80,015a6ffh
	dreptunghicica 470,810,80,80,0f0f8ffh
	dreptunghicica 470,910,80,80,0f0f8ffh
	
;coloana5
	dreptunghicica 570,110,80,80,0f3ff00h
	dreptunghicica 570,210,80,80,0f0f8ffh
	dreptunghicica 570,310,80,80,0f3ff00h
	dreptunghicica 570,410,80,80,0b33c00h
	dreptunghicica 570,510,80,80,0b33c00h
	dreptunghicica 570,610,80,80,0f0f8ffh
	dreptunghicica 570,710,80,80,015a6ffh
	dreptunghicica 570,810,80,80,015a6ffh
	dreptunghicica 570,910,80,80,015a6ffh
	
;coloana6
	dreptunghicica 670,110,80,80,0f3ff00h
	dreptunghicica 670,210,80,80,0f0f8ffh
	dreptunghicica 670,310,80,80,0f3ff00h
	dreptunghicica 670,410,80,80,0b33c00h
	dreptunghicica 670,510,80,80,0b33c00h
	dreptunghicica 670,610,80,80,0b33c00h
	dreptunghicica 670,710,80,80,0f0f8ffh
	dreptunghicica 670,810,80,80,015a6ffh
	dreptunghicica 670,910,80,80,015a6ffh
	
;coloana7
	dreptunghicica 770,110,80,80,0b3h
	dreptunghicica 770,210,80,80,0b3h
	dreptunghicica 770,310,80,80,0b3h
	dreptunghicica 770,410,80,80,0f0f8ffh
	dreptunghicica 770,510,80,80,0ff00aah
	dreptunghicica 770,610,80,80,0ff00aah
	dreptunghicica 770,710,80,80,0f0f8ffh
	dreptunghicica 770,810,80,80,09874h
	dreptunghicica 770,910,80,80,09874h
	
;coloana8
	dreptunghicica 870,110,80,80,0b3h
	dreptunghicica 870,210,80,80,0b3h
	dreptunghicica 870,310,80,80,0f0f8ffh
	dreptunghicica 870,410,80,80,0f0f8ffh
	dreptunghicica 870,510,80,80,0ff00aah
	dreptunghicica 870,610,80,80,0f0f8ffh
	dreptunghicica 870,710,80,80,09874h
	dreptunghicica 870,810,80,80,09874h
	dreptunghicica 870,910,80,80,09874h
	
;coloana9
	dreptunghicica 970,110,80,80,0b3h
	dreptunghicica 970,210,80,80,0b3h
	dreptunghicica 970,310,80,80,0b3h
	dreptunghicica 970,410,80,80,0ff00aah
	dreptunghicica 970,510,80,80,0ff00aah
	dreptunghicica 970,610,80,80,0ff00aah
	dreptunghicica 970,710,80,80,0f0f8ffh
	dreptunghicica 970,810,80,80,09874h
	dreptunghicica 970,910,80,80,09874h
	
;"taste"
	dreptunghicica 1175,80,88,81,0ff9300h
	dreptunghicica 1175,180,88,81,0ff9300h
	dreptunghicica 1175,280,88,81,0ff9300h
	dreptunghicica 1175,380,88,81,0ff9300h
	dreptunghicica 1175,480,88,81,0ff9300h
	dreptunghicica 1175,580,88,81,0ff9300h
	dreptunghicica 1175,680,88,81,0ff9300h
	dreptunghicica 1175,780,88,81,0ff9300h
	dreptunghicica 1175,880,88,81,0ff9300h
	
	jmp afisare_litere
	
evt_click:
    calc_adresa_matvect [ebp+arg2],[ebp+arg3]
;aici verificam daca "s-a dat click in buton"
	mov eax,[ebp+arg2]
	cmp eax,1175
    jl button_fail1	
	cmp eax,1263  
	jg button_fail1
	mov eax,[ebp+arg3]
	cmp eax,80
    jl button_fail1	
	cmp eax,161
	jg button_fail1
;aici verificam cu matricea de verificari daca este numar predefinit sau nu
		mov edi,adresaactuala
		lea esi,vectmatverifc
		cmp dword ptr [esi+edi*4],1
		je button_fail1
;daca nu este,il punem ca desing,dar si in matrice(atentie nu cea de verificari)
		make_text_macro '1',area,a,b
		mov dword ptr [vectmat+edi*4],1		
	jmp afisare_litere
button_fail1:
	make_text_macro ' ', area,100 , 900
	
	
	mov eax,[ebp+arg2]
	cmp eax,1175
    jl button_fail2	
	cmp eax,1263  
	jg button_fail2
	mov eax,[ebp+arg3]
	cmp eax,180
    jl button_fail2	
	cmp eax,261
	jg button_fail2
		
		mov edi,adresaactuala
		lea esi,vectmatverifc
		cmp dword ptr [esi+edi*4],1
		je button_fail1
		make_text_macro '2',area,a,b
		mov dword ptr [vectmat+edi*4],2
	jmp afisare_litere
button_fail2:
	make_text_macro ' ', area,100 , 900
	
	
	mov eax,[ebp+arg2]
	cmp eax,1175
    jl button_fail3	
	cmp eax,1263  
	jg button_fail3
	mov eax,[ebp+arg3]
	cmp eax,280
    jl button_fail3	
	cmp eax,361
	jg button_fail3
		
		mov edi,adresaactuala
		lea esi,vectmatverifc
		cmp dword ptr [esi+edi*4],1
		je button_fail1
		make_text_macro '3',area,a,b
		mov dword ptr [vectmat+edi*4],3
	jmp afisare_litere
button_fail3:
	make_text_macro ' ', area,100 , 900
	
	
	mov eax,[ebp+arg2]
	cmp eax,1175
    jl button_fail4	
	cmp eax,1263  
	jg button_fail4
	mov eax,[ebp+arg3]
	cmp eax,380
    jl button_fail4	
	cmp eax,461
	jg button_fail4
		
		mov edi,adresaactuala
		lea esi,vectmatverifc
		cmp dword ptr [esi+edi*4],1
		je button_fail1		
		make_text_macro '4',area,a,b
		mov dword ptr [vectmat+edi*4],4
	jmp afisare_litere
button_fail4:
	make_text_macro ' ', area,130 , 900
	
	
	mov eax,[ebp+arg2]
	cmp eax,1175
    jl button_fail5	
	cmp eax,1263  
	jg button_fail5
	mov eax,[ebp+arg3]
	cmp eax,480
    jl button_fail5	
	cmp eax,561
	jg button_fail5
		
		mov edi,adresaactuala
		lea esi,vectmatverifc
		cmp dword ptr [esi+edi*4],1
		je button_fail1
		make_text_macro '5',area,a,b
		mov dword ptr [vectmat+edi*4],5
	jmp afisare_litere
button_fail5:
	make_text_macro ' ', area,100 , 900
	
	
	mov eax,[ebp+arg2]
	cmp eax,1175
    jl button_fail6	
	cmp eax,1263  
	jg button_fail6
	mov eax,[ebp+arg3]
	cmp eax,580
    jl button_fail6	
	cmp eax,661
	jg button_fail6
		
		mov edi,adresaactuala
		lea esi,vectmatverifc
		cmp dword ptr [esi+edi*4],1
		je button_fail1
		make_text_macro '6',area,a,b
		mov dword ptr [vectmat+edi*4],6
	jmp afisare_litere
button_fail6:
	make_text_macro ' ', area,100 , 900
	
	
	mov eax,[ebp+arg2]
	cmp eax,1175
    jl button_fail7	
	cmp eax,1263  
	jg button_fail7
	mov eax,[ebp+arg3]
	cmp eax,680
    jl button_fail7	
	cmp eax,761
	jg button_fail7
	
		mov edi,adresaactuala
		lea esi,vectmatverifc
		cmp dword ptr [esi+edi*4],1
		je button_fail1	
		make_text_macro '7',area,a,b
		mov dword ptr [vectmat+edi*4],7
	jmp afisare_litere
button_fail7:
	make_text_macro ' ', area,100 , 900
	
	
	mov eax,[ebp+arg2]
	cmp eax,1175
    jl button_fail8	
	cmp eax,1263  
	jg button_fail8
	mov eax,[ebp+arg3]
	cmp eax,780
    jl button_fail8	
	cmp eax,861
	jg button_fail8
	
		mov edi,adresaactuala
		lea esi,vectmatverifc
		cmp dword ptr [esi+edi*4],1
		je button_fail1		
		make_text_macro '8',area,a,b
		mov dword ptr [vectmat+edi*4],8
	jmp afisare_litere
button_fail8:
	make_text_macro ' ', area,100 , 900

	
	mov eax,[ebp+arg2]
	cmp eax,1175
    jl button_fail9	
	cmp eax,1263  
	jg button_fail9
	mov eax,[ebp+arg3]
	cmp eax,880
    jl button_fail9	
	cmp eax,961
	jg button_fail9
	
		mov edi,adresaactuala
		lea esi,vectmatverifc
		cmp dword ptr [esi+edi*4],1
		je button_fail1	
		make_text_macro '9',area,a,b
		mov dword ptr [vectmat+edi*4],9
	jmp afisare_litere
button_fail9:
	make_text_macro ' ', area,100 , 900
	
	
	
;verificare conditii de Sudoku la click pe FINISH
	

		make_text_macro ' ', area,15 , 100
			make_text_macro ' ', area,25 , 100
				make_text_macro ' ', area,40, 100
					make_text_macro ' ', area,55 , 100
						make_text_macro ' ', area,65 , 100
							make_text_macro ' ', area,75 , 100
								make_text_macro ' ', area,85 , 100
									make_text_macro ' ', area,95 , 100
										make_text_macro ' ', area,105 , 100
										    make_text_macro ' ', area,115 , 100
					make_text_macro ' ', area,55 , 130
						make_text_macro ' ', area,65 , 130
							make_text_macro ' ', area,75 , 130
								make_text_macro ' ', area,85 , 130
									make_text_macro ' ', area,95 , 130
									
										

			make_text_macro ' ', area,15 , 100
			make_text_macro ' ', area,25 , 100
				make_text_macro ' ', area,40, 100
					make_text_macro ' ', area,55 , 100
						make_text_macro ' ', area,65 , 100
							make_text_macro ' ', area,75 , 100
								make_text_macro ' ', area,85 , 100
									make_text_macro ' ', area,95 , 100
										make_text_macro ' ', area,105 , 100
										   make_text_macro ' ', area,115 , 100
					make_text_macro ' ', area,55 , 130
						make_text_macro ' ', area,65 , 130
							make_text_macro ' ', area,75 , 130
								make_text_macro ' ', area,85 , 130
									make_text_macro ' ', area,95 , 130
									   make_text_macro ' ', area,105 , 130
										    make_text_macro ' ', area,115 , 130
											
									

		make_text_macro ' ', area,40 , 100
			make_text_macro ' ', area,50 , 100
				make_text_macro ' ', area,70, 100
					make_text_macro ' ', area,90 , 100
						make_text_macro ' ', area,100 , 100
							make_text_macro ' ', area,110 , 100
								make_text_macro ' ', area,120 , 100
									make_text_macro ' ', area,130 , 100
										make_text_macro ' ', area,140 , 100
	
				make_text_macro ' ', area,55 , 130
						make_text_macro ' ', area,65 , 130
							make_text_macro ' ', area,75 , 130
								make_text_macro ' ', area,85 , 130
									make_text_macro ' ', area,95 , 130
									   make_text_macro ' ', area,105 , 130
										  
	

			make_text_macro ' ', area,35 , 200
			make_text_macro ' ', area,45 , 200
			make_text_macro ' ', area,65 , 200
			make_text_macro ' ', area,75 , 200
			make_text_macro ' ', area,85 , 200
			make_text_macro ' ', area,95 , 200
			make_text_macro ' ', area,105 , 200
			make_text_macro ' ', area,115 , 200
			make_text_macro ' ', area,125 , 200
			make_text_macro ' ', area,135 , 200
		   
     
	
	
	mov eax,[ebp+arg2]
	cmp eax,30
    jl button_finish	
	cmp eax,130  
	jg button_finish
	mov eax,[ebp+arg3]
	cmp eax,350
    jl button_finish	
	cmp eax,450
	jg button_finish
	   
;verificare conditii pe linii toate elementele distincte de pe fiecare linie   

verif_linii :

;toti "algoritmi" de validare de mai jos merg pe acelasi principiu:
;gasesc o formula pentru conditia necesara,"i-au cifra" din matrice,si incrementez 
;intr-un nou vector pe pozitia aferenta,apoi compar ca tot vector sa fie 1 pentru a fi cifre distincte
;daca e,se reseteaza vector de frecventa si trece la urmatoarea repetare pana cand se epuizeaza numarul 
;de repetari,iar daca nu e atunci merge automat la fail
           mov ebx, 0
			mov edx,0
        start_check:
			mov byte ptr [verifvectcond],1
            mov ecx, 8
            linie:
			push ecx
             mov eax, ebx
             mov edx, 9
             mul edx
             add ecx, eax
; verificare pozitii de pe fiecare linie
			mov edx, dword ptr [vectmat + ecx*4]
            pop ecx
; incrementam in vectoru de frecventa de cate ori apare
            inc byte ptr [verifvectcond + edx]
            dec ecx
            cmp ecx,0
            jl iesireloop
            jmp linie
            iesireloop:
            mov ecx,9
            validare_linie:
; verificam ca in vectoru de frecventa pe toate pozitiile sa fie 1 pentru a fi cifre distincte
            cmp byte ptr [verifvectcond + ecx],1
            jne failverif
            loop validare_linie
            mov ecx, 1
            resetare:
            mov byte ptr [verifvectcond + ecx], 0
            inc ecx
            cmp ecx, 10
            jb resetare

            inc ebx
            cmp ebx, 9
         je verificare_coloane
           jmp start_check
		   
		   
;verificare conditii pe coloane toate elementele distincte de pe fiecare coloana   
verificare_coloane :
           mov ecx, 0
           mov edx,0
        start_check1:
        mov byte ptr [verifvectcond],1
            mov ebx, 8
            coloana:
             push ecx
             mov eax, ebx
             mov edx, 9
             mul edx
             add ecx, eax
            mov edx, dword ptr [vectmat + ecx*4]
			pop ecx
            inc byte ptr [verifvectcond + edx]
            dec ebx
            cmp ebx,0
            jl iesireloop1
            jmp coloana
            iesireloop1:
			push ecx
            mov ecx,9
            validare_coloana:
            cmp byte ptr [verifvectcond + ecx],1
            jne failverif1
            loop validare_coloana
            mov ecx, 1
            resetare1:
            mov byte ptr [verifvectcond + ecx], 0
            inc ecx
            cmp ecx, 10
            jb resetare1
            pop ecx

            inc ecx
            cmp ecx, 9
         je verificare_patrate
           jmp start_check1
		   
;verificare conditii pe patrate toate elementele distincte din fiecare patrat   	   
verificare_patrate:
		 
		mov eax, 0
        mov ebx, 1
        mov ecx, 2
        mov byte ptr [contorpatrate2], 3
	
	 totsudoku:
		mov byte ptr [contorpatrate1], 3
        mergpelinie: 
		mov byte ptr [contorpatrate], 3   
		
		mov [initialla],eax
		mov [initiallb],ebx
		mov [initiallc],ecx
;am dedus o formula de a putea verifica conditia de cifre distincte in patrate,dar fara explicatie pe desen nu stiu cum sa o zic
            patrat:
            mov edx, [vectmat + eax*4]
            inc byte ptr [verifvectcond + edx]
            mov edx, [vectmat + ebx*4]
            inc byte ptr[verifvectcond + edx]
            mov edx, [vectmat + ecx*4]
            inc byte ptr [verifvectcond + edx]
            add eax, 9
            add ebx, 9
            add ecx, 9
            dec byte ptr [contorpatrate]
            cmp byte ptr [contorpatrate], 0
            jne patrat
		
			mov ecx,9
			validare_patrat:
			cmp byte ptr [verifvectcond + ecx],1
			jne failverif2
			loop validare_patrat
			mov ecx, 1
            resetare2:
			mov byte ptr [verifvectcond + ecx], 0
			inc ecx
			cmp ecx, 10	
			jb resetare2
			
; patrate_urmatoare
		   
			mov eax,[initialla]
			mov ebx,[initiallb]
			mov ecx,[initiallc]
		   
            add eax, 3
            add ebx, 3
            add ecx, 3
			
		    dec byte ptr [contorpatrate1]
            cmp byte ptr [contorpatrate1], 0
            jne mergpelinie
			
			
			add eax, 18
            add ebx, 18
            add ecx, 18
			dec byte ptr [contorpatrate2]
            cmp byte ptr [contorpatrate2], 0
		
            jne totsudoku
				 jmp castig
				 
	failverif:
	mov semafor,1
		make_text_macro 'N', area,15 , 100
			make_text_macro 'U', area,25 , 100
				make_text_macro 'E', area,40, 100
					make_text_macro 'C', area,55 , 100
						make_text_macro 'O', area,65 , 100
							make_text_macro 'R', area,75 , 100
								make_text_macro 'E', area,85 , 100
									make_text_macro 'C', area,95 , 100
										make_text_macro 'T', area,105 , 100
										    make_text_macro 'A', area,115 , 100
					make_text_macro 'L', area,55 , 130
						make_text_macro 'I', area,65 , 130
							make_text_macro 'N', area,75 , 130
								make_text_macro 'I', area,85 , 130
									make_text_macro 'A', area,95 , 130
									
										jmp afisare_litere
										
 failverif1:
	pop ecx
 	mov semafor,1
			make_text_macro 'N', area,15 , 100
			make_text_macro 'U', area,25 , 100
				make_text_macro 'E', area,40, 100
					make_text_macro 'C', area,55 , 100
						make_text_macro 'O', area,65 , 100
							make_text_macro 'R', area,75 , 100
								make_text_macro 'E', area,85 , 100
									make_text_macro 'C', area,95 , 100
										make_text_macro 'T', area,105 , 100
										   make_text_macro 'A', area,115 , 100
					make_text_macro 'C', area,55 , 130
						make_text_macro 'O', area,65 , 130
							make_text_macro 'L', area,75 , 130
								make_text_macro 'O', area,85 , 130
									make_text_macro 'A', area,95 , 130
									   make_text_macro 'N', area,105 , 130
										    make_text_macro 'A', area,115 , 130
											
									jmp afisare_litere
									
  failverif2:
  	mov semafor,1
		make_text_macro 'N', area,40 , 100
			make_text_macro 'U', area,50 , 100
				make_text_macro 'E', area,70, 100
					make_text_macro 'C', area,90 , 100
						make_text_macro 'O', area,100 , 100
							make_text_macro 'R', area,110 , 100
								make_text_macro 'E', area,120 , 100
									make_text_macro 'C', area,130 , 100
										make_text_macro 'T', area,140 , 100
	
				make_text_macro 'P', area,55 , 130
						make_text_macro 'A', area,65 , 130
							make_text_macro 'T', area,75 , 130
								make_text_macro 'R', area,85 , 130
									make_text_macro 'A', area,95 , 130
									   make_text_macro 'T', area,105 , 130
										  
	
		jmp afisare_litere
		
	castig:	
			make_text_macro 'A', area,35 , 200
			make_text_macro 'I', area,45 , 200
			make_text_macro 'C', area,65 , 200
			make_text_macro 'A', area,75 , 200
			make_text_macro 'S', area,85 , 200
			make_text_macro 'T', area,95 , 200
			make_text_macro 'I', area,105 , 200
			make_text_macro 'G', area,115 , 200
			make_text_macro 'A', area,125 , 200
			make_text_macro 'T', area,135 , 200
		   
     
		jmp afisare_litere
	button_finish:
	make_text_macro ' ', area,100 , 100
	
	
evt_timer:
	inc counter
	cmp counter,5
	jne afisare_litere
	mov counter,0
	inc oficialcountersec
;am o "problema" de cand eram mic si jucam Sudoku,daca am gresit nu vroiam sa vad unde am gresit,
;ci sa refac de la 0 sa il iau pe un alt drum,drept urmare am facut ca la 5sec dupa ce afiseaza orice fail
;sa se inchida joc	
	cmp semafor,1
	jne afisare_litere
	inc counter_fail
	cmp counter_fail,5
	jne afisare_litere
	push 0
	call exit
	
afisare_litere:
;afisam valoarea counter-ului curent (sute, zeci,unitati si mii)
	mov ebx, 10
	mov eax, oficialcountersec
;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 110, 10
;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 100, 10
;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 90, 10
;cifra miilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 80, 10
	
;scriem un mesaj/titlu
	make_text_macro 'S', area,580 , 60
	make_text_macro 'U', area, 590, 60
	make_text_macro 'D', area, 599, 60
	make_text_macro 'O', area, 610, 60
	make_text_macro 'K', area, 620, 60
	make_text_macro 'U', area, 630, 60
	
;afisare cifre de pe taste
    make_text_macro '1' ,area, 1215,110
	 make_text_macro '2' ,area, 1215,210
	  make_text_macro '3' ,area, 1215,310
	   make_text_macro '4' ,area, 1215,410
	    make_text_macro '5' ,area, 1215,510
		 make_text_macro '6' ,area, 1215,610
		  make_text_macro '7' ,area, 1215,710
		   make_text_macro '8' ,area, 1215,810
		    make_text_macro '9' ,area, 1215,910
			
	make_text_macro 'T', area, 20, 10
	make_text_macro 'I', area, 30, 10
	make_text_macro 'M', area, 40, 10
	make_text_macro 'E', area, 50, 10
	make_text_macro 'R', area, 60, 10
	make_text_macro 'S', area, 120, 10
	
	
;afisarea valorilor predefinite
	make_text_macro '7' ,area, 200,140
	make_text_macro '1' ,area, 300,140
	make_text_macro '4' ,area, 400,140
	make_text_macro '6' ,area, 500,140
	make_text_macro '8' ,area, 400,240
	make_text_macro '1' ,area, 600,240
	make_text_macro '9' ,area, 700,240
	make_text_macro '5' ,area, 900,340
	make_text_macro '2' ,area, 200,440
	make_text_macro '5' ,area, 200,540
	make_text_macro '7' ,area, 300,540
	make_text_macro '6' ,area, 800,440
	make_text_macro '3' ,area, 900,440
	make_text_macro '4' ,area, 600,640
	make_text_macro '7' ,area, 900,640
	make_text_macro '6' ,area, 700,740
	make_text_macro '1' ,area, 800,740
	make_text_macro '4' ,area, 1000,740
	make_text_macro '9' ,area, 200,840
	make_text_macro '2' ,area, 500,840
	make_text_macro '3' ,area, 500,940
	
	
dreptunghicica 30,350,100,100,0bdbdbdh
	make_text_macro 'F', area, 50, 390
	make_text_macro 'I', area, 60, 390
	make_text_macro 'N', area, 70, 390
	make_text_macro 'I', area, 80, 390
	make_text_macro 'S', area, 90, 390
	make_text_macro 'H', area, 100, 390
	
final_draw:

	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:

;alocam vector incrementare valori predefinite
    mov eax, 9
	mov ebx, 9
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov vectmatverifc, eax
;alocam vector valori predefinite
    mov eax, 9
	mov ebx, 9
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov vectmat, eax	
	
	
	mov ecx,80
	init:
	mov dword ptr [vectmat+4*ecx],0
	dec ecx
	cmp ecx,0
	jnl init
	
;initializare vector valori predefinite
	lea esi,vectmat
	mov dword ptr [esi + 0*4],7
	mov dword ptr [esi + 1*4],1
	mov dword ptr [esi + 2*4],4
	mov dword ptr [esi + 3*4],6
	mov dword ptr [esi + 11*4],8
	mov dword ptr [esi + 13*4],1
	mov dword ptr [esi + 14*4],9
	mov dword ptr [esi + 25*4],5
	mov dword ptr [esi + 27*4],2
	mov dword ptr [esi + 33*4],6
	mov dword ptr [esi + 34*4],3
	mov dword ptr [esi + 36*4],5
	mov dword ptr [esi + 37*4],7
	mov dword ptr [esi + 49*4],4
	mov dword ptr [esi + 52*4],7
	mov dword ptr [esi + 59*4],6
	mov dword ptr [esi + 60*4],1
	mov dword ptr [esi + 62*4],4
	mov dword ptr [esi + 63*4],9
	mov dword ptr [esi + 66*4],2
	mov dword ptr [esi + 75*4],3
	
;incrementare vector valori predefinite	
	lea esi,vectmatverifc
	mov dword ptr [esi + 0*4],1
	mov dword ptr [esi + 1*4],1
	mov dword ptr [esi + 2*4],1
	mov dword ptr [esi + 3*4],1
	mov dword ptr [esi + 11*4],1
	mov dword ptr [esi + 13*4],1
	mov dword ptr [esi + 14*4],1
	mov dword ptr [esi + 25*4],1
	mov dword ptr [esi + 27*4],1
	mov dword ptr [esi + 33*4],1
	mov dword ptr [esi + 34*4],1
	mov dword ptr [esi + 36*4],1
	mov dword ptr [esi + 37*4],1
	mov dword ptr [esi + 49*4],1
	mov dword ptr [esi + 52*4],1
	mov dword ptr [esi + 59*4],1
	mov dword ptr [esi + 60*4],1
	mov dword ptr [esi + 62*4],1
	mov dword ptr [esi + 63*4],1
	mov dword ptr [esi + 66*4],1
	mov dword ptr [esi + 75*4],1
	
	
	
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
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	
;REZOLVAREA CORECTA	
;7 1 4  | 6 2 5  | 8 9 3
;3 5 8  | 7 1 9  | 2 4 6
;6 9 2  | 4 3 8  | 7 5 1
;---------------------------
;2 4 9  | 1 5 7  | 6 3 8
;5 7 3  | 8 6 2  | 4 1 9
;1 8 6  | 9 4 3  | 5 7 2
;---------------------------
;8 3 7  | 5 9 6  | 1 2 4
;9 6 1  | 2 7 4  | 3 8 5
;4 2 5  | 3 8 1  | 9 6 7
	

;terminarea programului
	push 0
	call exit
end start

