% Teste separado: reproduz o carregamento de texto Unicode em memória.
:- use_module(library(plunit)).
:- use_module(library(readutil)).
:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, '../knowledge_base.pl', File),
   read_file_to_string(File, Text, [encoding(utf8)]),
   setup_call_cleanup(open_string(Text, Stream),
                      load_files(swish_text:program, [stream(Stream), silent(true)]),
                      close(Stream)).

:- begin_tests(swish_texto).

test(cinco_perguntas_em_stream_unicode) :-
    forall(between(1, 5, N),
           (swish_text:pergunta(N, Resposta), Resposta = [_|_])),
    swish_text:pergunta(2, [magico(orlov, 30, 90, 1)|_]).

:- end_tests(swish_texto).
