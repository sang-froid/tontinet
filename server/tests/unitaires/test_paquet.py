"""Test de fumée : le paquet et ses sous-modules s'importent."""

import importlib

import tontinet

SOUS_MODULES = [
    "api", "domaine", "crdt", "replication", "consensus",
    "saga", "notifications", "securite", "infra",
]


def test_version() -> None:
    assert tontinet.__version__ == "0.1.0"


def test_sous_modules_importables() -> None:
    for nom in SOUS_MODULES:
        importlib.import_module(f"tontinet.{nom}")
