# TontiNet

Application répartie de tontine numérique avec client mobile hors connexion — projet de l'EC 1INF2324
« Systèmes répartis et mobiles » (UAC/IFRI, 2026-2027).

## Structure

| Dossier | Contenu |
| --- | --- |
| `server/` | Service réparti (répliques r1, r2, r3) — Python, FastAPI, gRPC, Raft |
| `paiement_simule/` | Prestataire de paiement mobile simulé (saga de versement) |
| `app_flutter/` | Application mobile et bureau — Flutter |
| `proto/` | Contrats Protocol Buffers (source unique) |
| `infra/` | Docker Compose, Mosquitto, PKI, supervision |
| `docs/` | Décisions d'architecture (ADR), conception, exploitation |
| `td/` | Réponses aux TD et TP |

## Prérequis

Python ≥ 3.12 et [uv](https://docs.astral.sh/uv/), Flutter (canal stable), Docker avec Compose v2.

## Vérifier l'installation

```bash
(cd server && uv sync && uv run pytest)
(cd paiement_simule && uv sync && uv run pytest)
(cd app_flutter && flutter pub get && flutter test)
```
