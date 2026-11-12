#!/usr/bin/env python3
"""Converte uma única tabela JSON da API de Persona 5 em fatos e consultas Prolog."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys
import unicodedata
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent
SOURCE_URL = "https://mpppersona5-api.onrender.com/personas/"
SOURCE_REPOSITORY = "https://github.com/MatheusPagaime17/persona5-api"
FIELDS = (
    "name", "arcana", "level", "dlc", "strength", "magic", "endurance",
    "agility", "luck", "weak",
)
ELEMENTS = {
    "Physical", "Gun", "Fire", "Ice", "Electric", "Wind", "Psychic",
    "Nuclear", "Bless", "Curse",
}
QUESTIONS = (
    (
        "Quais arcanas têm maior média de magia entre Personas sem DLC até o nível 40?",
        "ranking_arcanas(40, nao, Resposta)",
    ),
    (
        "Quais são as 5 maiores pontuações mágicas sem DLC até o nível 30, com no máximo 1 fraqueza?",
        "top_magicos(30, nao, 1, 5, Resposta)",
    ),
    (
        "Quais Personas sem DLC até o nível 40 têm força acima da média de sua própria arcana nesse recorte?",
        "acima_media_arcana(40, nao, Resposta)",
    ),
    (
        "Como se comparam as médias dos atributos e das fraquezas de Personas com e sem DLC em cada faixa de nível?",
        "comparacao_dlc(Resposta)",
    ),
    (
        "Quais são as 5 duplas sem DLC até o nível 20, de arcanas distintas e sem fraqueza em comum, com maior soma de força física e magia?",
        "top_duplas(20, nao, 5, Resposta)",
    ),
)


def atom(text):
    """Cria átomos simples: Shiisaa -> shiisaa; Obariyon -> obariyon."""
    if not isinstance(text, str) or not text.strip():
        raise ValueError("Nome/arcana deve ser texto não vazio")
    # Remove acentos e separadores para formar átomos Prolog válidos.
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    result = re.sub(r"[^a-z0-9]+", "_", ascii_text.lower()).strip("_")
    if not result:
        raise ValueError(f"Não foi possível normalizar {text!r}")
    if result[0].isdigit():
        result = "p_" + result
    return result


def transform(records):
    """Valida e seleciona exatamente dez campos, sem descartar linhas inválidas."""
    if not isinstance(records, list) or not records:
        raise ValueError("A fonte deve ser uma lista JSON não vazia")
    rows = []
    seen_names = set()
    arcanas = {}
    for index, record in enumerate(records, 1):
        # Valida cada registro antes de gerar os fatos.
        if not isinstance(record, dict) or any(key not in record for key in FIELDS):
            raise ValueError(f"Registro {index}: faltam campos obrigatórios")
        name = atom(record["name"])
        arcana = atom(record["arcana"])
        if name in seen_names:
            raise ValueError(f"Nome repetido ou colisão de normalização: {name}")
        seen_names.add(name)
        if arcana in arcanas and arcanas[arcana] != record["arcana"]:
            raise ValueError(f"Colisão de nomes de arcana: {arcana}")
        arcanas[arcana] = record["arcana"]
        for field in ("level", "strength", "magic", "endurance", "agility", "luck"):
            value = record[field]
            if type(value) is not int or not 1 <= value <= 99:
                raise ValueError(f"{name}: {field} deve ser inteiro entre 1 e 99")
        if type(record["dlc"]) is not int or record["dlc"] not in (0, 1):
            raise ValueError(f"{name}: dlc deve ser 0 ou 1")
        weak = record["weak"]
        if not isinstance(weak, list) or any(not isinstance(w, str) or w not in ELEMENTS for w in weak):
            raise ValueError(f"{name}: lista de fraquezas inválida")
        rows.append((
            name, arcana, record["level"], "sim" if record["dlc"] else "nao",
            record["strength"], record["magic"], record["endurance"],
            record["agility"], record["luck"], sorted({atom(w) for w in weak}),
        ))
    return sorted(rows, key=lambda row: row[0])


def render_base(rows):
    lines = [
        "% GERADO por etl.py. Edite a fonte ou o ETL, não este arquivo.",
        "% persona(Nome, Arcana, Nivel, DLC, Forca, Magia, Resistencia, Agilidade, Sorte, Fraquezas).",
        f"% Registros: {len(rows)}. Campos selecionados: {len(FIELDS)}.",
        "",
    ]
    for row in rows:
        fields = [str(value) for value in row[:-1]] + ["[" + ", ".join(row[-1]) + "]"]
        lines.append("persona(" + ", ".join(fields) + ").")
    return "\n".join(lines) + "\n"


def render_queries():
    lines = ["% GERADO por etl.py. Consultas de análise executadas pelo Prolog.", ""]
    for number, (question, goal) in enumerate(QUESTIONS, 1):
        lines.extend([
            f"% {number}. {question}",
            f"% Execute: pergunta({number}, Resposta).",
            f"pergunta({number}, Resposta) :-", f"    {goal}.", "",
        ])
    lines.extend([
        "% Executa as cinco perguntas sem truncar as listas na impressão.",
        "responder_todas :-",
        "    forall(pergunta(Numero, Resposta),",
        "           format('Pergunta ~d:~n~q~n~n', [Numero, Resposta])).",
    ])
    return "\n".join(lines) + "\n"


def artifacts(rows, root=ROOT):
    base = render_base(rows)
    queries = render_queries()
    rules = (root / "regras.pl").read_text(encoding="utf-8")
    combined = (
        "% GERADO por etl.py. Arquivo completo para a área Program do SWISH.\n"
        # SWISH carrega texto Unicode em memória; encoding/1 não se aplica a esse stream.
        "\n" + base + "\n" + rules + "\n" + queries
    )
    return {"base_persona.pl": base, "consultas.pl": queries, "knowledge_base.pl": combined}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--atualizar", action="store_true", help="baixa novamente a tabela da API")
    group.add_argument("--verificar", action="store_true", help="confere os arquivos gerados sem alterá-los")
    args = parser.parse_args(argv)
    source = ROOT / "data" / "personas.json"
    try:
        if args.atualizar:
            request = Request(SOURCE_URL, headers={"User-Agent": "MatDisKnowledgeEngine/1.0"})
            with urlopen(request, timeout=60) as response:
                raw = response.read()
        else:
            raw = source.read_bytes()
        records = json.loads(raw.decode("utf-8"))
        rows = transform(records)
        generated = artifacts(rows)
        digest = hashlib.sha256(raw).hexdigest()
        if args.atualizar:
            # Só substitui o snapshot depois da validação e da geração em memória.
            metadata = {
                "source_url": SOURCE_URL, "source_repository": SOURCE_REPOSITORY,
                "retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
                "sha256": digest, "records": len(rows),
            }
            source.write_bytes(raw)
            (ROOT / "data" / "origem.json").write_text(
                json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
            )
        else:
            # Confere se o snapshot ainda corresponde à sua proveniência.
            metadata = json.loads((ROOT / "data" / "origem.json").read_text(encoding="utf-8"))
            if metadata["sha256"] != digest or metadata["records"] != len(rows):
                raise ValueError("O snapshot não corresponde ao registro de origem")
        if args.verificar:
            # Verifica se os arquivos gerados estão sincronizados.
            outdated = [name for name, text in generated.items()
                        if not (ROOT / name).exists() or (ROOT / name).read_text(encoding="utf-8") != text]
            if outdated:
                raise ValueError("Execute python etl.py para atualizar: " + ", ".join(outdated))
            print(f"OK: {len(rows)} Personas; 10 campos; arquivos reproduzíveis.")
        else:
            for name, text in generated.items():
                (ROOT / name).write_text(text, encoding="utf-8", newline="\n")
            print(f"Gerados {len(rows)} fatos e {len(QUESTIONS)} perguntas em Prolog.")
        return 0
    except (OSError, ValueError, KeyError) as error:
        print(f"Erro: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
