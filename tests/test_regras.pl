:- encoding(utf8).
:- ensure_loaded('../main.pl').
:- use_module(library(plunit)).

:- begin_tests(persona5).

test(integridade_do_snapshot) :-
    findall(N, persona(N, _, _, _, _, _, _, _, _, _), Nomes),
    length(Nomes, 232), sort(Nomes, Unicos), length(Unicos, 232),
    findall(A, arcana(A), Arcanas), length(Arcanas, 24),
    findall(N, persona(N, _, _, sim, _, _, _, _, _, _), DLCs), length(DLCs, 25).

test(conversao_de_arsene) :-
    persona(arsene, fool, 1, nao, 2, 2, 2, 3, 1, [bless, ice]).

test(pergunta1_agrega_e_ordena) :-
    pergunta(1, [arcana(tower, 1, MT, NT), arcana(judgement, 1, MJ, NJ)|Resto]),
    assertion(MT =:= 27), assertion(NT =:= 37),
    assertion(MJ =:= 24), assertion(NJ =:= 34),
    length(Resto, 21).

test(pergunta2_resultado_completo) :-
    pergunta(2, Resultado),
    assertion(Resultado == [magico(orlov, 30, 90, 1),
                            magico(koh_i_noor, 25, 75, 1),
                            magico(neko_shogun, 30, 61, 1),
                            magico(stone_of_scone, 20, 60, 1),
                            magico(principality, 29, 59, 1)]).

test(pergunta3_media_do_grupo_correto) :-
    pergunta(3, [destaque(hope_diamond, death, 40, Media, Dif)|Resto]),
    assertion(abs(Media - 120 / 7) < 0.000001),
    assertion(abs(Dif - (40 - 120 / 7)) < 0.000001),
    length(Resto, 47).

test(pergunta3_todos_superam_a_media) :-
    pergunta(3, R),
    forall(member(destaque(_, _, F, Media, Dif), R),
           (F > Media, Dif > 0)).

test(pergunta4_grupos_particionam_a_base) :-
    pergunta(4, R),
    findall(Q, member(grupo(_, _, Q, _, _), R), Quantidades),
    assertion(Quantidades == [74, 9, 68, 8, 65, 8]),
    sum_list(Quantidades, 232),
    memberchk(grupo(inicial, nao, 74, MediaTotal, MediaFr), R),
    assertion(abs(MediaTotal - 4304 / 74) < 0.000001),
    assertion(abs(MediaFr - 98 / 74) < 0.000001).

test(pergunta5_resultado_e_desempate) :-
    pergunta(5, R),
    assertion(R == [dupla(shiki_ouji, leanan_sidhe, 19, 33),
                    dupla(black_ooze, leanan_sidhe, 19, 32),
                    dupla(flauros, leanan_sidhe, 19, 32),
                    dupla(yaksini, leanan_sidhe, 20, 31),
                    dupla(shiki_ouji, orobas, 18, 30)]).

test(pergunta5_nao_repete_fraqueza) :-
    pergunta(5, R),
    forall(member(dupla(F, M, _, _), R),
           (persona(F, AF, _, nao, FF, MF, _, _, _, FrF),
            persona(M, AM, _, nao, FM, MM, _, _, _, FrM),
            AF \= AM, FF > MF, MM > FM,
            FrF = [_|_], FrM = [_|_],
            sem_fraqueza_comum(FrF, FrM))).

test(uma_resposta_por_pergunta) :-
    forall(between(1, 5, N), (findall(R, pergunta(N, R), Respostas), Respostas = [_])).

test(recorte_vazio) :-
    ranking_arcanas(0, nao, []),
    top_magicos(0, nao, 1, 5, []),
    acima_media_arcana(0, nao, []),
    top_duplas(0, nao, 5, []).

test(top_zero) :-
    top_magicos(30, nao, 1, 0, []), top_duplas(20, nao, 0, []).

test(top_negativo, [fail]) :- top_magicos(30, nao, 1, -1, _).

test(media_vazia_nao_divide_por_zero, [fail]) :- media([], _).

test(fraqueza_compartilhada_reprovada, [fail]) :-
    sem_fraqueza_comum([ice, fire], [bless, ice]).

test(fraquezas_distintas) :- sem_fraqueza_comum([ice, fire], [wind]).

test(desempate_estavel) :-
    ordenar([chave(-10, 3, b)-b, chave(-10, 2, z)-z,
             chave(-11, 9, c)-c, chave(-10, 3, a)-a], [c, z, a, b]).

:- end_tests(persona5).
