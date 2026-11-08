"""Run after installing ocr-service requirements: python -m unittest discover -s tests."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("ocr_app", Path(__file__).resolve().parents[1] / "ocr-service/app.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class CandidateTests(unittest.TestCase):
    def test_whole_names_and_accents(self):
        found = module.candidates("1. Arnhem\n2. België\n3. Parijs")
        self.assertIn("Arnhem", found)
        self.assertIn("België", found)
        self.assertIn("Parijs", found)

    def test_no_substrings_or_hallucinated_places(self):
        self.assertNotIn("Rome", module.candidates("romero"))
        self.assertEqual(module.candidates("Onbekenddorp"), [])

    def test_typographic_apostrophes(self):
        for apostrophe in ["'", "’", "‘", "`"]:
            self.assertIn("Den Bosch", module.candidates(apostrophe + "s-Hertogenbosch"))

    def test_shared_names_once(self):
        found = module.candidates("Noordzee\nRijn\nAlpen\nMeer van Genève")
        self.assertEqual(found.count("Noordzee"), 1)
        self.assertEqual(found.count("Rijn"), 1)
        self.assertIn("Alpen", found)
        self.assertIn("Meer van Genève", found)

    def test_aliases(self):
        self.assertIn("Den Bosch", module.candidates("'s-Hertogenbosch"))

    def test_textbook_overview_legend(self):
        # Legend of the TopoMaster overview map: province and city with the same
        # name are told apart by the "(provincie)" / "(stad)" suffix.
        found = module.candidates(
            "1. Groningen (provincie)\n2. Friesland\n7. Utrecht (provincie)\n14. Groningen (stad)\n"
            "20. Utrecht (stad)\n28. Afsluitdijk\n33. Schiphol\n34. Randstad\nBiesbos\nAlphen aan den Rijn\nFryslân")
        for name in ["Groningen provincie", "Friesland", "Utrecht provincie", "Groningen", "Utrecht",
                     "Afsluitdijk", "Schiphol", "Randstad", "Biesbos", "Alphen aan den Rijn"]:
            self.assertIn(name, found)

    def test_parts_of_longer_names_do_not_match_on_their_own(self):
        self.assertEqual(module.candidates("Neder-Rijn\nAmsterdam-Rijnkanaal"), ["Neder-Rijn", "Amsterdam-Rijnkanaal"])
        self.assertEqual(module.candidates("Zuid-Limburg"), ["Zuid-Limburg"])
        self.assertEqual(module.candidates("Kop van Noord-Holland"), ["Kop van Noord-Holland"])
        self.assertEqual(module.candidates("Groningen provincie"), ["Groningen provincie"])

    def test_a_part_listed_separately_still_matches(self):
        self.assertEqual(module.candidates("Neder-Rijn\nRijn"), ["Rijn", "Neder-Rijn"])
        self.assertEqual(module.candidates("Zuid-Limburg en Limburg"), ["Limburg", "Zuid-Limburg"])

    def test_masked_text_cannot_join_neighbours_into_a_match(self):
        # "Den" + "Haag" split by a masked name must not form "Den Haag".
        self.assertNotIn("Den Haag", module.candidates("Den Rijn Haag"))

    def test_regions_are_reported_per_name(self):
        places = {m["name"]: m["regions"] for m in module.match_places("Noordzee Rijn Arnhem")}
        self.assertEqual(places, {"Noordzee": ["nl", "eu"], "Rijn": ["nl", "eu"], "Arnhem": ["nl"]})


if __name__ == '__main__':
    unittest.main()
