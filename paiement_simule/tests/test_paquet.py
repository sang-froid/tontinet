"""Test de fumée : le paquet s'importe."""

import paiement_simule


def test_version() -> None:
    assert paiement_simule.__version__ == "0.1.0"
