# Persona 5 — Knowledge Engine

Projeto de Lógica e Matemática Discreta: uma base de conhecimento sobre **Persona 5 Royal**, com ETL em Python e inferência em Prolog.

A base contém **232 Personas, 24 arcanas e 10 campos selecionados**. Cinco perguntas exploram agrupamento, médias, ordenação, comparação entre registros e composição de regras. Os dados e os arquivos gerados estão incluídos: não é necessário depender da API para reproduzir a entrega.

## Executar sem instalar nada

1. Abra [knowledge_base.pl](knowledge_base.pl) neste repositório e clique em **Raw** para copiar o arquivo inteiro.
2. Acesse o [SWISH — Prolog online](https://swish.swi-prolog.org/).
3. Crie um programa Prolog e cole o conteúdo na área **Program**.
4. Na área **Query**, execute uma pergunta por vez, por exemplo:

```prolog
pergunta(2, Resposta).
```

Troque `2` por um número entre `1` e `5`. Para imprimir todas as respostas completas:

```prolog
responder_todas.
```

O ponto final faz parte da consulta. Não coloque `?-` no código do programa. Caso a interface abrevie uma lista com `...`, use `responder_todas.` para ver a saída inteira.

Se estiver usando uma cópia antiga e aparecer `No permission to encoding stream`, remova a linha `:- encoding(utf8).` do início de `knowledge_base.pl` e execute novamente. A versão atual do ETL já gera esse arquivo sem a diretiva: o SWISH recebe texto Unicode em memória.

**O VS Code é opcional:** ele serve para editar os arquivos, mas não é necessário para executar o projeto no SWISH.

## Fonte e recorte dos dados

- Fonte: [Persona 5 API, de Matheus Pagaime](https://github.com/MatheusPagaime17/persona5-api).
- Único endpoint utilizado: [`GET /personas/`](https://mpppersona5-api.onrender.com/personas/).
- Tabela-fonte: a lista JSON retornada por esse endpoint; cada objeto representa uma Persona.
- Snapshot incluído: [data/personas.json](data/personas.json).
- Registro da coleta, URL e SHA-256: [data/origem.json](data/origem.json).
- Foram mantidas todas as **232 linhas** da resposta, incluindo **25 registros identificados pela fonte como DLC**. As consultas permitem separar esses registros.

Não há junção com outras tabelas, consultas a endpoints individuais nem enriquecimento com outra base. O JSON bruto preserva os 15 campos recebidos para auditoria; **somente os 10 abaixo são transformados em fatos e utilizados nas análises**. A lista de fraquezas permanece em um único campo do registro.

### Dicionário dos dez campos

| Campo na fonte | Argumento em Prolog | Tipo | Significado |
|---|---|---|---|
| `name` | `Nome` | Qualitativo | Nome da Persona, normalizado como átomo |
| `arcana` | `Arcana` | Qualitativo | Grupo da Persona |
| `level` | `Nivel` | Quantitativo inteiro | Nível inicial informado pela fonte |
| `dlc` | `DLC` | Qualitativo binário | `0` vira `nao`; `1` vira `sim` |
| `strength` | `Forca` | Quantitativo inteiro | Força base |
| `magic` | `Magia` | Quantitativo inteiro | Magia base |
| `endurance` | `Resistencia` | Quantitativo inteiro | Atributo de resistência física geral; não é afinidade elemental |
| `agility` | `Agilidade` | Quantitativo inteiro | Agilidade base |
| `luck` | `Sorte` | Quantitativo inteiro | Sorte base |
| `weak` | `Fraquezas` | Qualitativo, lista | Elementos aos quais o registro é fraco; `[]` significa nenhum listado |

`trait`, `resists`, `nullifies`, `reflects` e `absorbs` não foram selecionados.

### Representação em lógica

```prolog
persona(Nome, Arcana, Nivel, DLC, Forca, Magia, Resistencia, Agilidade, Sorte, Fraquezas).
```

Exemplo real da base:

```prolog
persona(arsene, fool, 1, nao, 2, 2, 2, 3, 1, [bless, ice]).
```

Esse fato afirma uma relação entre os dez valores. Os nomes em minúsculo são átomos; termos iniciados por maiúscula são variáveis. `persona/10` indica o nome do predicado e seus dez argumentos.

## Como a base foi construída

1. **Extração:** obtenção da lista JSON da API e armazenamento integral da resposta, com hash e metadados de origem.
2. **Seleção:** escolha dos dez campos do dicionário, misturando variáveis qualitativas e quantitativas.
3. **Validação:** conferência dos campos obrigatórios, tipos, limites dos números, valores de DLC e elementos das fraquezas. Fonte vazia, nomes duplicados ou registros inválidos interrompem a geração; nenhum número ausente é substituído por zero.
4. **Transformação:** nomes passam para minúsculas, acentos são removidos e separadores viram `_`. Exemplo: `Koh-i-Noor` vira `koh_i_noor`. O programa rejeita colisões de nomes após a normalização. Fraquezas são ordenadas e deduplicadas, e os registros são ordenados por nome.
5. **Carga:** o Python escreve os fatos em `base_persona.pl`, as cinco perguntas executáveis em `consultas.pl` e a versão completa em `knowledge_base.pl`.
6. **Inferência:** `regras.pl` responde às perguntas usando exclusivamente Prolog. O Python não calcula os rankings nem as respostas analíticas.

O ETL usa apenas a biblioteca padrão do Python. Não são necessários `pandas`, `requests` nem uma chave de API.

## As cinco perguntas

As respostas completas obtidas no snapshot estão em [docs/resultados.txt](docs/resultados.txt). Os resultados abaixo são exemplos extraídos da execução; médias na apresentação podem estar arredondadas.

### 1. Quais arcanas têm maior média de magia até o nível 40, sem DLC?

```prolog
pergunta(1, Resposta).
% Equivalente a:
ranking_arcanas(40, nao, Resposta).
```

O Prolog agrupa os registros por arcana, calcula a quantidade, a média de magia e a média de nível, e ordena por média de magia decrescente. Em caso de empate, usa o nome da arcana em ordem crescente. Arcanas sem registros no recorte não aparecem.

Formato: `arcana(Arcana, Quantidade, MediaMagia, MediaNivel)`.

| Primeiras arcanas | Quantidade | Média de magia | Média de nível |
|---|---:|---:|---:|
| `tower` | 1 | 27,00 | 37,00 |
| `judgement` | 1 | 24,00 | 34,00 |
| `fortune` | 4 | 23,75 | 30,25 |

**Por que é sofisticada:** agrupamento, duas médias e ordenação. As quantidades pequenas e os diferentes níveis médios precisam ser considerados na interpretação; o ranking não prova que uma arcana seja melhor no jogo.

### 2. Quais registros têm as cinco maiores pontuações mágicas até o nível 30, sem DLC e com até uma fraqueza?

```prolog
pergunta(2, Resposta).
% Equivalente a:
top_magicos(30, nao, 1, 5, Resposta).
```

Definição adotada para esta análise:

```text
Pontuação = 2 × Magia + Agilidade
```

A magia recebe peso dois por ser o atributo priorizado nessa pergunta. Essa é uma **métrica criada para o projeto**, e não uma fórmula oficial de dano. O desempate favorece menor nível e, depois, nome em ordem crescente.

Formato: `magico(Nome, Nivel, Pontuacao, QuantidadeFraquezas)`.

```prolog
[magico(orlov, 30, 90, 1),
 magico(koh_i_noor, 25, 75, 1),
 magico(neko_shogun, 30, 61, 1),
 magico(stone_of_scone, 20, 60, 1),
 magico(principality, 29, 59, 1)]
```

**Por que é sofisticada:** composição de condições, contagem de fraquezas, pontuação, desempate e seleção dos cinco primeiros.

### 3. Quais Personas têm força acima da média da própria arcana até o nível 40, sem DLC?

```prolog
pergunta(3, Resposta).
% Equivalente a:
acima_media_arcana(40, nao, Resposta).
```

Cada Persona é comparada com a média de força de **sua própria arcana, dentro do mesmo recorte de nível e DLC**. O resultado é ordenado pela diferença para essa média, da maior para a menor, com desempate pelo nome.

Formato: `destaque(Nome, Arcana, Forca, MediaForca, Diferenca)`.

Há 48 resultados. O primeiro é `hope_diamond`, da arcana `death`: força 40, média do grupo aproximadamente 17,14 e diferença aproximadamente 22,86.

**Por que é sofisticada:** média por grupo, comparação com um valor calculado, cálculo da diferença e ordenação.

### 4. Como DLC e não DLC se comparam em cada faixa de nível?

```prolog
pergunta(4, Resposta).
% Equivalente a:
comparacao_dlc(Resposta).
```

As faixas definidas no projeto são `inicial` (1–30), `intermediaria` (31–60) e `avancada` (61–99). Para cada combinação de faixa e DLC, calculam-se a quantidade, a média da soma dos cinco atributos e a média da quantidade de fraquezas. Grupos vazios são omitidos.

Formato: `grupo(Faixa, DLC, Quantidade, MediaSomaAtributos, MediaFraquezas)`.

| Faixa | DLC | Quantidade | Média da soma dos atributos | Média de fraquezas |
|---|---|---:|---:|---:|
| Inicial | Não | 74 | 58,16 | 1,32 |
| Inicial | Sim | 9 | 71,33 | 1,44 |
| Intermediária | Não | 68 | 147,69 | 1,01 |
| Intermediária | Sim | 8 | 153,63 | 1,00 |
| Avançada | Não | 65 | 239,06 | 0,71 |
| Avançada | Sim | 8 | 236,50 | 0,75 |

**Por que é sofisticada:** agrupamento por duas características, soma de atributos, contagem e duas médias. A comparação é descritiva: as faixas ainda contêm níveis diferentes, portanto não isola um efeito de DLC.

### 5. Quais duplas combinam perfil físico e mágico sem compartilhar fraquezas até o nível 20, sem DLC?

```prolog
pergunta(5, Resposta).
% Equivalente a:
top_duplas(20, nao, 5, Resposta).
```

A Persona de perfil físico precisa ter força maior que magia; a de perfil mágico precisa ter magia maior que força. As duas devem ser de arcanas diferentes, ter pelo menos uma fraqueza cada e não compartilhar nenhum elemento fraco.

```text
Pontuação da dupla = Força da Persona física + Magia da Persona mágica
```

O ranking ordena pela pontuação decrescente. Desempates usam o menor valor de `MaiorNivel` e os nomes em ordem crescente. Os papéis distintos evitam contar a mesma dupla nas duas ordens.

Formato: `dupla(PersonaFisica, PersonaMagica, MaiorNivel, Pontuacao)`.

```prolog
[dupla(shiki_ouji, leanan_sidhe, 19, 33),
 dupla(black_ooze, leanan_sidhe, 19, 32),
 dupla(flauros, leanan_sidhe, 19, 32),
 dupla(yaksini, leanan_sidhe, 20, 31),
 dupla(shiki_ouji, orobas, 18, 30)]
```

**Por que é sofisticada:** relaciona dois registros, compõe predicados, usa negação de uma fraqueza compartilhada, calcula pontuação e ordena. Não compartilhar fraquezas não significa resistir ao ataque que afeta o parceiro; essa pergunta não usa resistências, anulações ou absorções.

## Executar no computador

Requisitos: **Python 3.10 ou superior** e [SWI-Prolog](https://www.swi-prolog.org/download/stable). O editor é de sua escolha.

```bash
git clone https://github.com/JoaoEspioni/MatDisKnowledgeEngine.git
cd MatDisKnowledgeEngine
python etl.py
swipl -q -s main.pl
```

Em sistemas nos quais o comando é `python3`, substitua `python` por `python3`. No terminal do Prolog:

```prolog
pergunta(1, Resposta).
pergunta(2, Resposta).
pergunta(3, Resposta).
pergunta(4, Resposta).
pergunta(5, Resposta).
halt.
```

Para executar tudo em um único comando:

```bash
swipl -q -s main.pl -g responder_todas -t halt
```

Também é possível mudar os parâmetros, por exemplo:

```prolog
top_magicos(50, todos, 2, 10, Resposta).
top_duplas(30, nao, 3, Resposta).
```

`todos` inclui ambos os valores de DLC; `nao` e `sim` restringem a um grupo. Passe limites inteiros não negativos. As consultas retornam `[]` quando o recorte não possui resultados e as funções de top K retornam no máximo K itens.

### Reproduzir ou atualizar a coleta

```bash
# Usa o snapshot incluído; não acessa a internet.
python etl.py

# Confere a origem e se os arquivos gerados estão atualizados, sem escrever.
python etl.py --verificar

# Opcional: baixa a tabela atual da API e atualiza o snapshot e os arquivos Prolog.
python etl.py --atualizar
```

A API pode demorar para responder. Se a atualização falhar ou retornar dados inválidos, o programa informa o erro antes de substituir o snapshot. As respostas de referência e os testes de regressão correspondem ao snapshot entregue; após atualizar os dados, revise possíveis mudanças de resultados antes de atualizar essas referências.

## Verificação

```bash
python -m unittest discover -s tests -v
python etl.py --verificar
swipl -q -s tests/test_regras.pl -g run_tests -t halt
```

Os 12 testes Python verificam a conversão, dados inválidos, colisões, integridade do snapshot e reprodução dos arquivos. Os 17 testes Prolog verificam resultados das cinco perguntas, médias, desempates, integridade da base, ausência de resultados e limites de top K.

O fluxo em [.github/workflows/testes.yml](.github/workflows/testes.yml) executa esses comandos no GitHub Actions e também carrega a versão independente destinada ao SWISH.

O teste adicional abaixo verifica o carregamento do programa por um stream de texto em memória, incluindo a execução das cinco perguntas:

```bash
swipl -q -s tests/test_swish.pl -g run_tests -t halt
```

## Organização

| Arquivo | Função |
|---|---|
| `etl.py` | Extrai, valida, transforma e gera os arquivos Prolog |
| `data/personas.json` | Snapshot bruto da única tabela-fonte |
| `data/origem.json` | Proveniência, contagem e hash do snapshot |
| `data/LICENSE-fonte.txt` | Licença publicada pelo repositório da API |
| `base_persona.pl` | 232 fatos `persona/10`, gerados pelo ETL |
| `regras.pl` | Predicados auxiliares e regras de análise |
| `consultas.pl` | Cinco perguntas executáveis, geradas pelo ETL |
| `main.pl` | Carregador dos arquivos separados para execução local |
| `knowledge_base.pl` | Base, regras e perguntas em um único arquivo para o SWISH |
| `docs/resultados.txt` | Saída integral das cinco consultas no snapshot entregue |
| `tests/` | Testes do ETL e das regras |

Edite `regras.pl` para alterar a inferência e execute o ETL novamente para atualizar a versão independente. Não carregue `main.pl` e `knowledge_base.pl` juntos: são duas formas de carregar o mesmo programa.

## Limites e créditos

As análises usam os valores base fornecidos pela API. Não simulam evolução de nível, fusões, habilidades, equipamentos ou condições de obtenção e de uso em combate. Portanto, os rankings descrevem os registros selecionados e não garantem a melhor escolha para uma partida real. Níveis e tamanhos de grupos diferentes também influenciam as médias.

A fonte é comunitária e pode conter erros ou mudar; o snapshot e seu hash permitem reproduzir exatamente os dados utilizados. Nenhum atributo foi inventado ou completado com outra fonte. O marcador de DLC é interpretado conforme a API.

Crédito dos dados: **Matheus Pagaime**, autor da [Persona 5 API](https://github.com/MatheusPagaime17/persona5-api). A API informa utilizar recursos da comunidade e o [persona-compendium](https://github.com/luyluish/persona-compendium) como referência. O código da API é publicado sob a licença MIT, cuja cópia foi preservada em `data/LICENSE-fonte.txt`. Persona e os elementos relacionados ao jogo pertencem aos seus respectivos titulares; este projeto é acadêmico e não tem vínculo com a Atlus.

## Correspondência com os requisitos

| Requisito do enunciado | Implementação |
|---|---|
| Uma tabela-fonte pública | Lista JSON de `/personas/` |
| De 6 a 10 campos, qualitativos e quantitativos | Dez argumentos em `persona/10` |
| ETL em Python gerando base e perguntas Prolog | `etl.py`, `base_persona.pl` e `consultas.pl` |
| Pelo menos três perguntas | Cinco perguntas em `pergunta/2` |
| Perguntas sofisticadas | Todas usam agregação, comparação, ordenação ou composição de regras |
| README com construção e execução | Instruções acima, com opção local e online |
