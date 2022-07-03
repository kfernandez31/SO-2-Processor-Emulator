## Testy rocznikowe
https://gitlab.com/mimuw-rocznik-2001/so-2022/testy-zad2

## Testy oficjalne
https://github.com/kfernandez31/SO-2-Processor-Emulator/blob/main/test.c

## Opis wyników i testów

### Jeden rdzeń

Rozwiązanie jest kompilowane z parametrem `-DCORES=1`. Ocena jest z przedziału od `0 do 4. Jest 16 testów o numerach od 0 do 15. Za każdy test zakończony poprawnym wynikiem otrzymuje się 1/4 punktu. Od tego wyniku odejmowane są następujące kary:
  * (code_size > 768) * (code_size - 768) / 1024,
    ale nie więcej niż 0,8 punktu,
  * (data_size - bss_size) / 512 + (data_size > 8) * (data_size - 8) / 128,
    ale nie więcej niż 0,8 punktu,
gdzie:
  * code_size to łączny rozmiar sekcji text i rodata,
  * data_size to łączny rozmiar sekcji data i bss,
  * bss_size to rozmiar sekcji bss.

### Wiele rdzeni

Rozwiązanie jest kompilowane z parametrem `-DCORES=4`. Ocena jest z przedziału
od 0 do 1. Są 3 testów o numerach od 40 do 42. Za każdy test zakończony
poprawnym wynikiem otrzymuje się 1/3 punktu. Od tego wyniku odejmowane są
następujące kary:

  * (data_size - bss_size) / 2048 + (data_size > 32) * (data_size - 32) / 512,
    ale nie więcej niż 0,4 punktu,

gdzie:

  * data_size to łączny rozmiar sekcji data i bss,
  * bss_size to rozmiar sekcji bss.

## Ocena końcowa

Ocena końcowa jest sumą ocen z testów z jednym rdzeniem i wieloma rdzeniami
pomniejszoną o następujące kary:

  * 1 pkt za błędną nazwę pliku,
  * 1 pkt za błędy wykryte przez valgrind,
  * 0,2 pkt. za niepotrzebne użycie instrukcji div lub idiv,
  * 0,2 pkt. za niepotrzebne użycie instrukcji mul lub imul,
  * 0,1 pkt. za ustawienie w rejestrze rax bitów, które powinny być wyzerowane,
  * 0,5 pkt. za zmodyfikowanie wartości w którymś z rejestrów rbx, rbp, r12,
    r13, r14, r15,
  * 1 pkt za zmodyfikowanie kodu programu,
  * 0,1 do 1 punktu za jakość kodu.

Ocena końcowa jest zaokrąglana w dół do 0,1 punktu, ale nie jest ujemna.

W komentarzu do oceny podany jest skrótowy opis wyników. W polu testy wymienione
są numery testów, które nie przeszły. W nawiasie podany jest kod błędu:

  * 1   – błędnie obliczony wynik,
  * 123 – valgrind wykrył błąd,
  * 124 – przekroczenie czasu (2 s dla testów z jednym rdzeniem, 4 s dla testów
    z wieloma rdzeniami),
  * 132 – nielegalna instrukcja,
  * 139 – naruszenie ochrony pamięci.

Następnie wypisany jest ułamek testów, które zakończyły się poprawnym wynikiem.
Wypisanie nazwy rejestru oznacza, że nie zachowano reguł użycia tego rejestru.
Napis non-const oznacza, że zmodyfikowano kod programu.
Na koniec wypisane są rozmiary poszczególnych sekcji.
