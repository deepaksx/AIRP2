# AIRP v2.0 - Complete Build Prompt

Use this prompt when starting Claude in a fresh AIRP2 folder to build the complete AI-native Financial ERP from scratch.

---

## PROMPT FOR CLAUDE

```markdown
You are an expert staff+ architect and code generator. Build a complete, production-ready AI-native Financial ERP called AIRP v2.0 from scratch.

SCOPE: Financial domain ONLY (GL, AP, AR, FA, Treasury, FP&A, Consolidation, Tax/DRC, Close & Audit)

CONTEXT
- Region: Dubai/UAE (UTC+4), multi-entity, multi-currency (AED base)
- Compliance: IFRS primary, GAAP configurable, UAE VAT 5%, ZATCA (KSA) & EFRIS (Uganda) ready
- Users: CFO, Controller, Treasurer, Auditor, FP&A Analyst

ARCHITECTURE REQUIREMENTS
- Event-sourced immutable ledger (PostgreSQL 15+ partitioned by month)
- Microservices: NestJS (TypeScript) for core services, FastAPI (Python) for AI services
- Event bus: Kafka/Redpanda with exactly-once semantics
- Multi-tenancy: Schema-based isolation (entity_{id})
- Security: RBAC+ABAC, SoD policies, encryption at rest/transit, audit trails
- SLOs: P99 <300ms read, <800ms write, 99.9% uptime, RPO 15min, RTO 60min

AI-NATIVE CAPABILITIES (The Core Differentiator)
1. Auto-Accounting: LLM+rules hybrid (GPT-4 + XGBoost) maps transactions to GL codes
2. Autonomous Reconciliation: ML fuzzy matching for bank-to-ledger with confidence scoring
3. Cash Forecasting: Prophet + time-series models for 90-day rolling forecasts
4. Narrative Reporting: Claude 3 generates executive summaries of financial performance
5. Policy Advisor: RAG over IFRS/GAAP/VAT knowledge base
6. Continuous Close: Predictive accruals, soft-close snapshots, no month-end crunch
7. Anomaly Detection: Flags unusual transactions, duplicates, potential fraud

FUTURE-PROOF DESIGN PRINCIPLES (Critical - Build These In From Day 1)
- Model-agnostic AI fabric: Swap LLMs at runtime via adapters (OpenAI, Anthropic, local, fine-tuned)
- Neural reasoning layer: Hybrid symbolic + neural for explainability & math precision
- Autonomous agent orchestration: AP, AR, Treasury, FP&A, Audit as AI agents with goals, memory, reinforcement feedback
- Continuous learning loop: Auto-labeling from human corrections, federated retraining with differential privacy
- Temporal & causal knowledge graph: Every transaction anchored in time/cause/effect for predictive audit
- Multimodal ingestion: Invoices, emails, speech, spreadsheets, video → structured events
- Quantum-safe crypto: Post-quantum key exchange, lattice-based encryption
- Digital-twin finance simulator: Mirror-world for stress tests, Monte Carlo risk
- Neuro-symbolic policy engine: Machine-readable IFRS/GAAP as constraints
- Ethical AI & truth assurance: Bias audit logs, truth-maintenance detecting manipulative accounting
- Composable AI agents: Plug new domain agents via self-describing contracts
- Edge compute ready: Lightweight inference nodes with federated sync
- Autonomic optimization: Self-tunes DB indexes, model hyperparams, infra scaling
- Synthetic data generator: IFRS-compliant privacy-safe corpora for AI validation
- Cognitive UX: Voice+chat+AR dashboards, finance copilots that reason
- Governance autopilot: Monitors regulations, triggers policy-as-code updates
- Temporal versioned APIs: Backward-compatible schema evolution for decades
- Energy-aware compute: Carbon-cost-optimized scheduling
- Autonomous internal audit: AI auditor agents test controls 24x7

DELIVERABLES (Build Complete, Runnable Code)

1. README.md - Product overview, quickstart (docker compose up), architecture thumbnails

2. /docs/
   - architecture.md: C4 diagrams (System Context, Container, Component), sequence diagrams (AP, AR, Close, Consolidation), event sourcing, multi-tenancy, AI explainability
   - ai_design.md: All AI services, prompting contracts, feedback loops, evaluation metrics
   - security.md: Threat model (STRIDE), data classification, key management, SoD matrix
   - deployment.md: K8s, scaling, DR procedures

3. /apis/openapi/ - Full OpenAPI 3.1 specs:
   - ledger.yaml, ap.yaml, ar.yaml, treasury.yaml, fpna.yaml, policy.yaml, auth.yaml
   - Include examples, error models, idempotency keys, pagination

4. /schemas/
   - sql/ddl.sql: PostgreSQL event_store (append-only), projections (trial_balance, aging), multi-tenant schemas
   - avro/: Kafka event schemas
   - vector/: Policy embeddings format

5. /services/ - Runnable microservices:
   TypeScript (NestJS):
   - api-gateway, ledger-writer, projection-service, ap-service, ar-service, treasury-service, fpna-service, policy-engine, reporting-service

   Python (FastAPI):
   - ai-auto-accounting, ai-recon, ai-forecast, ai-narrative, ai-policy-advisor

   Each with: Dockerfile, health endpoints, env config, business logic, unit tests

6. /infra/
   - docker-compose.yml: Postgres, Kafka, Redis, Keycloak, Grafana, pgvector/Qdrant
   - k8s/: Deployments, Services, Ingress, NetworkPolicies, HPA
   - terraform/: VPC, RDS, MSK, EKS, KMS
   - .github/workflows/: CI/CD (lint, test, build, scan, deploy)

7. /policy/
   - rego/: OPA policies (approval thresholds, SoD, capitalization rules)
   - ifrs/: IFRS mapping tables
   - vat/: UAE VAT 5% config, ZATCA/EFRIS stubs

8. /ml/
   - feature_store.md, model_registry.md
   - notebooks/: GL classification, cash forecast training
   - serving/: Pydantic schemas for inference
   - eval/: Test datasets, metrics scripts

9. /examples/
   - synthetic_data/: AP invoices, AR invoices, bank statements (CSVs)
   - prompts/: Auto-accounting, narrative generation examples
   - postman/: API collection

10. /tests/
    - Unit tests for 2 services (1 TS, 1 Python)
    - Integration tests for invoice-to-ledger flow
    - AI explainability golden test data

ACCEPTANCE CRITERIA
- docker compose up starts all services + loads synthetic data
- Demo script: upload invoice → AI auto-accounts → approve → ledger event → projection updated → narrative generated
- All Mermaid diagrams render
- OpenAPI YAMLs lint with Spectral
- SQL DDL creates successfully in Postgres 15
- Produces: trial balance, AP/AR aging, 90-day cash forecast

IMPLEMENTATION APPROACH
- Start with complete file structure outline
- Build infrastructure first (docker-compose, schemas)
- Then core services (ledger-writer, projection-service)
- Then AI services with real prompts and confidence scoring
- Create working synthetic data that flows through entire system
- Make it RUNNABLE - every service should start and respond to health checks

DO NOT ASK QUESTIONS - I've given you complete requirements. Build it all. Take your time and be thorough. This is a greenfield project, so design it RIGHT from the start with all future-proof principles baked in.

BEGIN: Output the complete directory structure first, then start building files systematically.
```

---

## HOW TO USE

1. Create a new folder for AIRP2:
   ```bash
   mkdir AIRP2
   cd AIRP2
   ```

2. Open Claude Code (or Claude in your IDE)

3. Copy the entire prompt above (everything in the code block)

4. Paste it into Claude and let it build

5. Claude will create the complete directory structure and all files

---

## WHAT YOU'LL GET

A complete, runnable AI-native Financial ERP with:

- ✅ **14 microservices** (9 TypeScript + 5 Python AI services)
- ✅ **Event-sourced ledger** with immutable audit trail
- ✅ **7 AI capabilities** (auto-accounting, reconciliation, forecasting, narrative, policy advisor, continuous close, anomaly detection)
- ✅ **Complete infrastructure** (Docker Compose, Kubernetes, Terraform)
- ✅ **Full API specs** (OpenAPI 3.1 for all services)
- ✅ **Database schemas** (PostgreSQL with partitioning and projections)
- ✅ **Security framework** (RBAC/ABAC, encryption, audit trails)
- ✅ **Policy engine** (OPA/Rego for compliance)
- ✅ **Synthetic data** for testing
- ✅ **CI/CD pipelines** (GitHub Actions)
- ✅ **Comprehensive documentation** (Architecture, AI design, security, deployment)

---

## ESTIMATED BUILD TIME

Claude will systematically build approximately:
- **100+ files**
- **50,000+ lines of code**
- **Complete working system**

The build will take time, but you'll get a production-ready foundation.

---

## NEXT STEPS AFTER BUILD

1. Review the generated code
2. Run `docker compose up` to start all services
3. Load synthetic data
4. Test the demo workflow
5. Customize for your specific needs
6. Deploy to your infrastructure

---

## SUPPORT

If you need help after the build:
- Check the generated `README.md`
- Review `/docs/architecture.md` for system design
- See `/docs/deployment.md` for setup instructions
- Synthetic data and examples in `/examples/`

---

**Ready to build the future of finance? Copy the prompt and let's go! 🚀**
