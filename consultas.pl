% GERADO por etl.py. Consultas de análise executadas pelo Prolog.

% 1. Quais arcanas têm maior média de magia entre Personas sem DLC até o nível 40?
% Execute: pergunta(1, Resposta).
pergunta(1, Resposta) :-
    ranking_arcanas(40, nao, Resposta).

% 2. Quais são as 5 maiores pontuações mágicas sem DLC até o nível 30, com no máximo 1 fraqueza?
% Execute: pergunta(2, Resposta).
pergunta(2, Resposta) :-
    top_magicos(30, nao, 1, 5, Resposta).

% 3. Quais Personas sem DLC até o nível 40 têm força acima da média de sua própria arcana nesse recorte?
% Execute: pergunta(3, Resposta).
pergunta(3, Resposta) :-
    acima_media_arcana(40, nao, Resposta).

% 4. Como se comparam as médias dos atributos e das fraquezas de Personas com e sem DLC em cada faixa de nível?
% Execute: pergunta(4, Resposta).
pergunta(4, Resposta) :-
    comparacao_dlc(Resposta).

% 5. Quais são as 5 duplas sem DLC até o nível 20, de arcanas distintas e sem fraqueza em comum, com maior soma de força física e magia?
% Execute: pergunta(5, Resposta).
pergunta(5, Resposta) :-
    top_duplas(20, nao, 5, Resposta).

% Executa as cinco perguntas sem truncar as listas na impressão.
responder_todas :-
    forall(pergunta(Numero, Resposta),
           format('Pergunta ~d:~n~q~n~n', [Numero, Resposta])).
