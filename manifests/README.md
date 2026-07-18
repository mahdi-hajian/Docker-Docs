# راهنمای مانیفست `onlyoffice-docs.yaml`

## چه چیزی deploy می‌شود؟

| جزء | وضعیت | توضیح |
|-----|--------|--------|
| `proxy` | اجباری | ورودی HTTP (ClusterIP، بدون LoadBalancer) |
| `docservice` | اجباری | **replicas = 1** |
| `converter` | اجباری | فعلاً 1 replica |
| Redis | اجباری موقت داخل کلاستر | بعداً می‌توانی به Redis پروداکشن وصل کنی |
| RabbitMQ | اجباری موقت داخل کلاستر | بعداً می‌توانی به MQ پروداکشن وصل کنی |
| Postgres | **نمی‌آورد** | از Postgres خودت استفاده می‌کند |
| LoadBalancer | **نیست** | با `port-forward` تست کن |
| adminpanel / metrics / utils / balancer | نیست | طبق درخواست فعلاً نیاوردیم |

ایمیج Docs: `repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-cluster-de:none-root`

---

## قبل از apply

1. روی Postgres پروداکشن‌ات یک دیتابیس خالی بساز (مثلاً `onlyoffice`) و یوزر با دسترسی به آن.
2. در فایل YAML بخش `Secret/onlyoffice-config` را ویرایش کن:
   - `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_PWD`
   - `JWT_SECRET`
3. اگر StorageClass برای `ReadWriteMany` نداری، `accessModes` را موقتاً `ReadWriteOnce` بگذار و همهٔ podهای Docs را روی یک node نگه دار (برای تست).

---

## createdb.sql را چطور روی Postgres خودت بگذاری؟

### روش A — خودکار (داخل همین مانیفست)

Job به‌نام `onlyoffice-db-init`:

1. از داخل ایمیج `docs-cluster-de` فایل را کپی می‌کند از مسیر:
   ```text
   /var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql
   ```
2. با کلاینت `psql` روی Postgres تو اجرا می‌کند:
   ```bash
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f /sql/createdb.sql
   ```

یعنی **لازم نیست دستی SQL را کپی کنی**؛ فقط Secret را درست کن و Job را اجرا بگذار.

بررسی:
```bash
kubectl -n onlyoffice logs job/onlyoffice-db-init -c extract-sql
kubectl -n onlyoffice logs job/onlyoffice-db-init -c apply-sql
kubectl -n onlyoffice wait --for=condition=complete job/onlyoffice-db-init --timeout=180s
```

اگر جدول‌ها از قبل ساخته شده باشند، اجرای دوباره ممکن است خطای `already exists` بدهد. برای نصب اول اوکی است؛ برای تکرار یا DB را خالی کن یا خطا را نادیده بگیر.

### روش B — دستی (ConfigMap)

اگر بخواهی خودت فایل را ببینی/نگه داری:

```bash
# از ایمیج postgresql فقط‌آفیس (همان SQL داخل init است)
docker create --name oo-tmp repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-postgresql:none-root
docker cp oo-tmp:/docker-entrypoint-initdb.d/createdb.sql ./createdb.sql
docker rm oo-tmp

# یا از ایمیج cluster:
# docker create --name oo-tmp repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-cluster-de:none-root
# docker cp oo-tmp:/var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql ./createdb.sql

kubectl -n onlyoffice create configmap onlyoffice-createdb --from-file=createdb.sql

# سپس روی Postgres:
psql -h YOUR_HOST -U YOUR_USER -d onlyoffice -f createdb.sql
```

مسیرها:
| ایمیج | مسیر createdb.sql |
|--------|-------------------|
| `docs-cluster-de` | `/var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql` |
| `docs-postgresql` | `/docker-entrypoint-initdb.d/createdb.sql` |

---

## Apply و تست

```bash
# 1) Secret را در YAML ویرایش کن، بعد:
kubectl apply -f manifests/onlyoffice-docs.yaml

# 2) صبر برای schema
kubectl -n onlyoffice wait --for=condition=complete job/onlyoffice-db-init --timeout=180s

# 3) وضعیت
kubectl -n onlyoffice get pods,svc,job,pvc

# 4) دسترسی بدون LoadBalancer
kubectl -n onlyoffice port-forward svc/proxy 8080:80
# مرورگر: http://localhost:8080
# health:  http://localhost:8080/healthcheck
```

---

## بعداً (اختیاری)

- `converter.replicas` را زیاد کن
- Redis/RabbitMQ را به سرویس‌های پروداکشن وصل کن (فقط Secret را عوض کن)
- Ingress اضافه کن (هنوز LB/Ingress نیاوردیم)
- `license.lic` را روی PVC/Secret برای Developer کامل بگذار
