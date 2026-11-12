% Regras escritas manualmente; os dados são gerados pelo ETL.
% As consultas públicas recebem limites inteiros e DLC = sim, nao ou todos.
:- use_module(library(lists)).

% --- Predicados auxiliares ---

dlc_permitido(todos, _).
dlc_permitido(nao, nao).
dlc_permitido(sim, sim).

selecionada(MaxNivel, DLC, Nome, Arcana, Nivel, F, M, R, A, S, Fraquezas) :-
    integer(MaxNivel), MaxNivel >= 0,
    memberchk(DLC, [todos, nao, sim]),
    persona(Nome, Arcana, Nivel, Tipo, F, M, R, A, S, Fraquezas),
    Nivel =< MaxNivel,
    dlc_permitido(DLC, Tipo).

arcana(Arcana) :-
    findall(A, persona(_, A, _, _, _, _, _, _, _, _), Arcanas),
    sort(Arcanas, Unicas),
    member(Arcana, Unicas).

media(Valores, Media) :-
    Valores = [_|_],
    sum_list(Valores, Soma),
    length(Valores, Quantidade),
    Media is Soma / Quantidade.

primeiros(0, _, []) :- !.
primeiros(_, [], []) :- !.
primeiros(N, [X|Xs], [X|Ys]) :-
    N > 0,
    Proximo is N - 1,
    primeiros(Proximo, Xs, Ys).

valores_pares([], []).
valores_pares([_-Valor|Pares], [Valor|Valores]) :-
    valores_pares(Pares, Valores).

ordenar(Pares, Valores) :-
    keysort(Pares, Ordenados),
    valores_pares(Ordenados, Valores).

% --- 1. Agrupamento por arcana e ranking da média de magia ---
% resultado: arcana(Arcana, Quantidade, MediaMagia, MediaNivel).

resumo_arcana(MaxNivel, DLC, Arcana, Quantidade, MediaMagia, MediaNivel) :-
    arcana(Arcana),
    findall(M, selecionada(MaxNivel, DLC, _, Arcana, _, _, M, _, _, _, _), Magias),
    media(Magias, MediaMagia),
    length(Magias, Quantidade),
    findall(N, selecionada(MaxNivel, DLC, _, Arcana, N, _, _, _, _, _, _), Niveis),
    media(Niveis, MediaNivel).

ranking_arcanas(MaxNivel, DLC, Ranking) :-
    findall(chave(Negativa, Arcana)-arcana(Arcana, Q, MM, MN),
            (resumo_arcana(MaxNivel, DLC, Arcana, Q, MM, MN), Negativa is -MM),
            Pares),
    ordenar(Pares, Ranking).

% --- 2. Ranking mágico com restrições e pontuação explícita ---
% Pontuação criada para a análise: 2 * magia + agilidade (não é uma regra do jogo).
% resultado: magico(Nome, Nivel, Pontuacao, QuantidadeFraquezas).

top_magicos(MaxNivel, DLC, MaxFraquezas, K, Ranking) :-
    integer(MaxFraquezas), MaxFraquezas >= 0,
    integer(K), K >= 0,
    findall(chave(Negativa, Nivel, Nome)-magico(Nome, Nivel, Pontos, Q),
            (selecionada(MaxNivel, DLC, Nome, _, Nivel, _, M, _, A, _, Fr),
             length(Fr, Q), Q =< MaxFraquezas,
             Pontos is 2 * M + A, Negativa is -Pontos),
            Pares),
    ordenar(Pares, Todos),
    primeiros(K, Todos, Ranking).

% --- 3. Comparação com a média do próprio grupo ---
% Cada média considera a MESMA faixa de nível e opção de DLC da pergunta.
% resultado: destaque(Nome, Arcana, Forca, MediaForca, Diferenca).

media_forca_arcana(MaxNivel, DLC, Arcana, Media) :-
    findall(F, selecionada(MaxNivel, DLC, _, Arcana, _, F, _, _, _, _, _), Forcas),
    media(Forcas, Media).

acima_media_arcana(MaxNivel, DLC, Ranking) :-
    findall(chave(Negativa, Nome)-destaque(Nome, Arcana, F, Media, Diferenca),
            (selecionada(MaxNivel, DLC, Nome, Arcana, _, F, _, _, _, _, _),
             media_forca_arcana(MaxNivel, DLC, Arcana, Media),
             F > Media, Diferenca is F - Media, Negativa is -Diferenca),
            Pares),
    ordenar(Pares, Ranking).

% --- 4. Comparação de DLC por faixa, com duas agregações ---
% resultado: grupo(Faixa, DLC, Quantidade, MediaSomaAtributos, MediaFraquezas).

faixa(inicial, 1, 30).
faixa(intermediaria, 31, 60).
faixa(avancada, 61, 99).

medidas_grupo(Faixa, DLC, Total, QFraquezas) :-
    faixa(Faixa, Min, Max),
    persona(_, _, Nivel, DLC, F, M, R, A, S, Fr),
    Nivel >= Min, Nivel =< Max,
    Total is F + M + R + A + S,
    length(Fr, QFraquezas).

resumo_grupo(Faixa, DLC, Q, MediaTotal, MediaFraquezas) :-
    faixa(Faixa, _, _),
    member(DLC, [nao, sim]),
    findall(T, medidas_grupo(Faixa, DLC, T, _), Totais),
    media(Totais, MediaTotal),
    length(Totais, Q),
    findall(F, medidas_grupo(Faixa, DLC, _, F), Fraquezas),
    media(Fraquezas, MediaFraquezas).

comparacao_dlc(Grupos) :-
    findall(grupo(Faixa, DLC, Q, MT, MF),
            resumo_grupo(Faixa, DLC, Q, MT, MF), Grupos).

% --- 5. Composição de regras para duplas complementares ---
% Ambos precisam ter ao menos uma fraqueza, para evitar o caso trivial [].
% "Sem fraqueza em comum" não significa resistir ao ataque que afeta o parceiro.

sem_fraqueza_comum(FraquezasA, FraquezasB) :-
    \+ (member(Elemento, FraquezasA), memberchk(Elemento, FraquezasB)).

dupla_candidata(MaxNivel, DLC, Fisico, Magico, MaiorNivel, Pontos) :-
    selecionada(MaxNivel, DLC, Fisico, ArcanaF, NF, FF, MF, _, _, _, FrF),
    FF > MF, FrF = [_|_],
    selecionada(MaxNivel, DLC, Magico, ArcanaM, NM, FM, MM, _, _, _, FrM),
    MM > FM, FrM = [_|_],
    ArcanaF \= ArcanaM,
    sem_fraqueza_comum(FrF, FrM),
    MaiorNivel is max(NF, NM),
    Pontos is FF + MM.

% resultado: dupla(PersonaFisica, PersonaMagica, MaiorNivel, Pontuacao).
top_duplas(MaxNivel, DLC, K, Ranking) :-
    integer(K), K >= 0,
    findall(chave(Negativa, Nivel, F, M)-dupla(F, M, Nivel, Pontos),
            (dupla_candidata(MaxNivel, DLC, F, M, Nivel, Pontos), Negativa is -Pontos),
            Pares),
    ordenar(Pares, Todas),
    primeiros(K, Todas, Ranking).
