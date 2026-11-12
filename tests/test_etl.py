"""Testes de integridade da conversão; as análises são feitas em Prolog."""
import copy
import hashlib
import json
from pathlib import Path
import unittest

import etl


class TestETL(unittest.TestCase):
    def setUp(self):
        self.sample = {
            "name": "Arsene", "arcana": "Fool", "level": 1, "dlc": 0,
            "strength": 2, "magic": 2, "endurance": 2, "agility": 3,
            "luck": 1, "weak": ["Ice", "Bless"], "trait": "Pinch Anchor",
        }

    def test_dez_campos_e_ordem_do_predicado(self):
        rows = etl.transform([self.sample])
        self.assertEqual(rows, [
            ("arsene", "fool", 1, "nao", 2, 2, 2, 3, 1, ["bless", "ice"]),
        ])
        self.assertEqual(len(etl.FIELDS), 10)
        self.assertIn(
            "persona(arsene, fool, 1, nao, 2, 2, 2, 3, 1, [bless, ice]).",
            etl.render_base(rows),
        )

    def test_normalizacao_de_nomes(self):
        self.assertEqual(etl.atom("Emperor's Amulet"), "emperor_s_amulet")
        self.assertEqual(etl.atom("Koh-i-Noor"), "koh_i_noor")
        self.assertEqual(etl.atom("Árvore"), "arvore")
        self.assertEqual(etl.atom("7 Teste"), "p_7_teste")

    def test_colisao_nao_sobrescreve_registro(self):
        other = copy.deepcopy(self.sample)
        self.sample["name"], other["name"] = "A-B", "A B"
        with self.assertRaises(ValueError):
            etl.transform([self.sample, other])

    def test_fonte_vazia_ou_objeto_de_erro(self):
        for data in ([], {"error": "unavailable"}, [None]):
            with self.subTest(data=data), self.assertRaises(ValueError):
                etl.transform(data)

    def test_campo_ausente(self):
        del self.sample["magic"]
        with self.assertRaises(ValueError):
            etl.transform([self.sample])

    def test_numeros_invalidos_nao_sao_inventados(self):
        for value in (True, None, "10", 0, 100, 1.5):
            with self.subTest(value=value), self.assertRaises(ValueError):
                etl.transform([{**self.sample, "magic": value}])

    def test_dlc_valido(self):
        self.assertEqual(etl.transform([{**self.sample, "dlc": 1}])[0][3], "sim")
        with self.assertRaises(ValueError):
            etl.transform([{**self.sample, "dlc": 2}])

    def test_fraqueza_vazia_diferente_de_campo_invalido(self):
        self.assertEqual(etl.transform([{**self.sample, "weak": []}])[0][-1], [])
        for value in (None, "Ice", ["Unknown"], [1]):
            with self.subTest(value=value), self.assertRaises(ValueError):
                etl.transform([{**self.sample, "weak": value}])

    def test_fraquezas_repetidas_sao_normalizadas(self):
        row = etl.transform([{**self.sample, "weak": ["Ice", "Ice", "Bless"]}])[0]
        self.assertEqual(row[-1], ["bless", "ice"])

    def test_ordem_da_fonte_nao_muda_saida(self):
        other = {**self.sample, "name": "Abaddon"}
        self.assertEqual(etl.transform([self.sample, other]), etl.transform([other, self.sample]))

    def test_snapshot_e_proveniencia(self):
        raw = (etl.ROOT / "data/personas.json").read_bytes()
        origin = json.loads((etl.ROOT / "data/origem.json").read_text(encoding="utf-8"))
        rows = etl.transform(json.loads(raw))
        self.assertEqual(hashlib.sha256(raw).hexdigest(), origin["sha256"])
        self.assertEqual(len(rows), origin["records"])
        self.assertEqual(len(rows), 232)

    def test_arquivos_versionados_sao_reproduziveis(self):
        data = json.loads((etl.ROOT / "data/personas.json").read_text(encoding="utf-8"))
        for name, expected in etl.artifacts(etl.transform(data)).items():
            with self.subTest(file=name):
                self.assertEqual((etl.ROOT / name).read_text(encoding="utf-8"), expected)


if __name__ == "__main__":
    unittest.main()
