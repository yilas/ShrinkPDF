# Script pour compresser des PDF

Quelque chose comme « I love PDF » mais en local.

```bash
pip install -r requirements.txt --break-system-packages
```

```bash
python3 ./app.py
```

Dans un navigateur, aller sur http://127.0.0.1:5000

## Helm Chart

```bash
helm lint charts/shrinkpdf

helm template shrink ./charts/shrinkpdf

helm upgrade shrink ./charts/shrinkpdf --install

k port-forward deployments/shrink-shrinkpdf 5000:5000
```
