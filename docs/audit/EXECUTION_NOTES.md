# 🔥 AUDITORÍA v2.0 - NOTAS PARA MAÑANA

## ☕ ANTES DE EMPEZAR

1. **Levantar el stack**:
```bash
cd /Users/ianmont/Dev/ragf
make up
make smoke  # Verificar que todo esté verde
```

2. **Crear rama de auditoría**:
```bash
git checkout -b audit/v2-hardening
```

3. **Tener a mano**:
- Editor (VSCode)
- Terminal con docker compose
- Este roadmap abierto

---

## 🎯 ORDEN DE ATAQUE

### BLOQUE 1: Crypto Fixes (EMPEZAR AQUÍ - MÁS CRÍTICO)
**Por qué primero**: Es el más rápido de arreglar y el más crítico para compliance.

**Archivos a modificar**:
1. `shared/models.py` → Línea 204 (secret)
2. `gateway/decision_engine.py` → Línea 312 (error handling)
3. `.env.example` → Añadir `RAGF_SIGNATURE_SECRET`

**Tiempo**: 45 minutos

---

### BLOQUE 2: Fail-Closed Coverage
**Por qué segundo**: Builds on crypto fixes.

**Archivo a modificar**:
- `gateway/decision_engine.py` → Método `evaluate()`

**Añadir**:
- try/except alrededor de semantic validation
- try/except alrededor de validators
- try/except catch-all final

**Tiempo**: 1 hora

---

### BLOQUE 3: Tests de Failure Modes
**Por qué tercero**: Verifica que los fixes funcionan.

**Crear archivo nuevo**:
- `tests/integration/test_failure_modes.py`

**Tests a implementar**:
```python
async def test_neo4j_timeout():
    # Mock slow Neo4j query
    # Assert verdict.decision == "DENY"

async def test_validator_exception():
    # Mock validator that raises Exception
    # Assert verdict.decision == "DENY"

async def test_signature_failure():
    # Mock compute_signature to raise
    # Assert verdict.decision == "DENY"
```

**Tiempo**: 45 minutos

---

### BLOQUE 4: Boundary Analysis
**Por qué cuarto**: Requiere menos código, más análisis.

**Actividades**:
1. Trace code path: API → DecisionEngine → Persistence
2. Identify all entry points
3. Verify no bypass paths
4. Document in markdown

**Tiempo**: 1 hora

---

### BLOQUE 5: Latency Instrumentation
**Por qué quinto**: Nice-to-have para el paper.

**Modificar**:
- `gateway/decision_engine.py` → Añadir timing logs

**Ejecutar**:
```bash
make benchmark
# Analizar logs para extraer timings
```

**Tiempo**: 30 minutos

---

### BLOQUE 6: Assessment Document
**Por qué último**: Consolida todo lo anterior.

**Crear**:
- `docs/audit/RAGF_v2_Technical_Assessment.md`

**Secciones** (copy/paste de los fixes):
1. Executive Summary
2. Vulnerabilities Found
3. Fixes Applied
4. Test Results
5. Production Readiness

**Tiempo**: 30 minutos

---

## 🚨 SI ALGO FALLA

**Plan B por bloque**:

1. **Crypto fails**: Revert `shared/models.py`, keep rest
2. **Fail-closed fails**: Partial error handling better than none
3. **Tests fail**: Document as known limitation
4. **Boundary unclear**: Document uncertainty
5. **Latency missing**: Use existing benchmarks
6. **Assessment incomplete**: Ship what you have

---

## ✅ CRITERIO DE ÉXITO MÍNIMO

No necesitas completar TODO. Esto es suficiente para ACM:

- ✅ Crypto fixed (secret + error handling)
- ✅ At least 2 failure mode tests passing
- ✅ Assessment document with findings

**Tiempo mínimo**: 3 horas

---

## 📋 CHECKLIST FINAL

Antes de commit:

```bash
# 1. Tests
make smoke  # Debe pasar 5/5
make benchmark  # Debe pasar

# 2. Linting (si tienes tiempo)
black shared/models.py gateway/decision_engine.py

# 3. Commit
git add shared/models.py gateway/decision_engine.py .env.example tests/ docs/audit/
git commit -m "audit: Production hardening v2.0

SECURITY FIXES:
- Move signature secret to environment variable
- Add error handling for signature generation
- Add fail-closed behavior for all error paths

TESTING:
- Add failure mode integration tests
- Verify 100% DENY on exceptions

DOCUMENTATION:
- Technical assessment document
- Vulnerability analysis
- Production readiness evaluation

All smoke tests passing (5/5)
All benchmarks passing (100% safety, 0% FP)

This hardens v2.0 for production deployment and regulatory compliance."

git push origin audit/v2-hardening
```

---

## 🎓 PARA EL PAPER

**Lo que puedes afirmar después de la auditoría**:

> "RAGF v2.0 underwent a comprehensive security and safety audit. 
> We identified and fixed 3 critical vulnerabilities:
> 1. Hardcoded cryptographic secrets (now environment-based)
> 2. Missing error handling in signature generation (now fail-closed)
> 3. Incomplete exception coverage (now 100% DENY on errors)
>
> Post-audit, the system achieves 100% fail-closed coverage across
> all tested failure modes (Neo4j timeout, validator exceptions,
> signature failures)."

**Esto es ORO para reviewers** - muestra rigor científico.

---

## 💡 TIPS

1. **No te bloquees en perfección** - Shipping > Perfection
2. **Documenta lo que NO pudiste hacer** - Honestidad > Marketing
3. **Git commit frecuentemente** - Cada fix es un commit
4. **Tests antes que código** - TDD ayuda a pensar
5. **Si algo toma >30min** - SKIP y documenta como limitation

---

## 🚀 DESPUÉS DE LA AUDITORÍA

1. Merge `audit/v2-hardening` → `main`
2. Tag `v2.1.0` (production-hardened)
3. Update README con security improvements
4. Actualizar Section 5.4 del paper con findings
5. Celebrar 🎉

---

**Nos vemos mañana a las 09:00. Café fuerte recomendado.** ☕
