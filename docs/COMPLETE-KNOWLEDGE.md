# دانش کامل پروژه Docker-Docs — گزارش و Handoff

> این فایل خلاصهٔ **همهٔ کارها، تصمیم‌ها، خطاها، مفاهیم و وضعیت فعلی** است.  
> مخاطب: انسان + تب AI بعدی.  
> ریپو: `E:\github\Docker-Docs` (بر پایهٔ ONLYOFFICE/Docker-Docs)

---

## فهرست

1. [این ریپو چیست؟](#1-این-ریپو-چیست)
2. [اهداف کاربر](#2-اهداف-کاربر)
3. [کارهای اضافه‌ای که روی ریپو انجام شد](#3-کارهای-اضافه‌ای-که-روی-ریپو-انجام-شد)
4. [ایمیج‌ها در برابر کانتینرها](#4-ایمیجها-در-برابر-کانتینرها)
5. [لیست ایمیج‌های رجیستری شخصی](#5-لیست-ایمیجهای-رجیستری-شخصی)
6. [Docker Compose — اجباری / اختیاری](#6-docker-compose--اجباری--اختیاری)
7. [Kubernetes / Helm — اجباری / اختیاری](#7-kubernetes--helm--اجباری--اختیاری)
8. [چرا لیست اجباری Compose با K8s فرق دارد؟](#8-چرا-لیست-اجباری-compose-با-k8s-فرق-دارد)
9. [Non-root (کاربر ds / UID 101)](#9-non-root-کاربر-ds--uid-101)
10. [مشکل CRLF / bash\\r](#10-مشکل-crlf--bashr)
11. [Community / Developer / Enterprise و لایسنس](#11-community--developer--enterprise-و-لایسنس)
12. [Postgres و schema](#12-postgres-و-schema)
13. [فونت‌های کاستوم](#13-فونتهای-کاستوم)
14. [بیلد و اجرا](#14-بیلد-و-اجرا)
15. [قیمت‌گذاری (خلاصه)](#15-قیمتگذاری-خلاصه)
16. [کارهایی که نباید انجام شود](#16-کارهایی-که-نباید-انجام-شود)
17. [وضعیت فعلی و گام بعدی](#17-وضعیت-فعلی-و-گام-بعدی)
18. [ایندکس فایل‌های مستندات](#18-ایندکس-فایلهای-مستندات)

---

## 1. این ریپو چیست؟

### کاری که می‌کند
- ایمیج رسمی یک‌تکه `onlyoffice/documentserver` را **patch نمی‌کند**.
- از **Fedora** شروع می‌کند، **RPM** فقط‌آفیس را از `download.onlyoffice.com` نصب می‌کند، و ایمیج‌های چندسرویسی برای Compose/K8s می‌سازد.
- از قبل برای اجرای **non-root** طراحی شده: کاربر `ds` با UID/GID **101**.

### جریان بیلد (خلاصه)
```
fedora → ds-base (user ds=101)
       → ds-service (wget + rpm فقط‌آفیس + فونت/پلاگین)
       → docs / proxy / docservice / converter / utils / metrics / db …
```

### انتخاب edition با `.env`
| `PRODUCT_EDITION` | پکیج RPM | معنی |
|-------------------|----------|------|
| خالی `""` | `onlyoffice-documentserver` | Community (رایگان / AGPL) |
| `-de` | `onlyoffice-documentserver-de` | Developer (تجاری) |
| `-ee` | `onlyoffice-documentserver-ee` | Enterprise (تجاری) |

الگوی URL:
```text
https://download.onlyoffice.com/install/documentserver/linux/onlyoffice-documentserver{EDITION}{VERSION}.{arch}.rpm
```
مثال DE 9.4.1:
```text
https://download.onlyoffice.com/install/documentserver/linux/onlyoffice-documentserver-de-9.4.1.x86_64.rpm
```

### مخاطب اصلی ریپو
عمدتاً ایمیج‌های Helm chart رسمی [Kubernetes-Docs](https://github.com/ONLYOFFICE/Kubernetes-Docs).  
`docker-compose.yml` آپ‌استریم برای لوکال ناقص/کهنه است (مثلاً postgresql/metrics بدون `image`).

---

## 2. اهداف کاربر

- اجرای ONLYOFFICE با **non-root** روی **Kubernetes**
- استفاده از رجیستری شخصی: `repo.mohaymen.ir:3060/...`
- فونت فارسی کاستوم
- فهم محدودیت Community در برابر Developer
- محصول خودشان را می‌فروشند → مسیر درست لایسنس: **Developer** (نه کرک)
- تست مقیاس حدود ۱۰۰۰ کاربر هم‌زمان قبل از خرید (مسیر قانونی: trial/لایسنس؛ نه دور زدن قفل)

---

## 3. کارهای اضافه‌ای که روی ریپو انجام شد

### کامیت محلی مهم
`879880a` — Add .gitattributes, build.ps1, update build.yml and docker-compose.yml

| فایل | تغییر | چرا |
|------|--------|-----|
| `.gitattributes` | `eol=lf` برای `.sh`/`.py`/Dockerfile/yml | جلوگیری از CRLF ویندوز داخل ایمیج لینوکس |
| `build.ps1` | معادل PowerShell برای `build.sh` | بیلد روی ویندوز بدون Git Bash اجباری |
| `build.yml` | `image:` برای metrics و postgresql | تگ پایدار `docs-metrics` / `docs-postgresql` |
| `docker-compose.yml` | چند فیکس (پایین) | `compose up` روی Compose v2 کار کند |

### فیکس‌های `docker-compose.yml`
1. `metrics.image` → `…/docs-metrics:${DOCKER_TAG}`
2. `postgresql.image` → `…/docs-postgresql:${DOCKER_TAG}`
3. `example` با `profiles: [example]` (پیش‌فرض بالا نیاید)
4. `EXAMPLE_HOST_PORT=docservice:8000` تا nginx بدون سرویس example کرش نکند
5. healthcheck postgres: `pg_isready -U myuser -d mydb`

### چیزی که بحث شد ولی در Dockerfile فعلی نیست
پیشنهاد strip کردن CRLF داخل ایمیج:
```dockerfile
RUN sed -i 's/\r$//' …entrypoint… && chmod +x …
```
در درخت فعلی **وجود ندارد**. اتکا به `.gitattributes` + LF بودن اسکریپت‌ها + بیلد مجدد.

### مستندات اضافه‌شده در `docs/`
- این فایل (دانش کامل)
- HTMLهای راهنما (Compose / K8s / cluster-vs-split / build-report)

### نتیجهٔ تست موفق لوکال (در جلسه)
- بعد از بیلد مجدد: دیگر `bash\r` نبود
- `docservice` healthy
- `curl http://localhost/healthcheck` → `true`
- `docker compose exec docservice id` → `uid=101(ds)`
- هشدار `license.lic` برای `-de` بدون لایسنس طبیعی است (WARN)

---

## 4. ایمیج‌ها در برابر کانتینرها

### تعریف
| مفهوم | چیست | مثال |
|--------|------|------|
| **Image** | فایل فقط‌خواندنی روی دیسک/رجیستری | `docs-cluster-de:none-root` |
| **Container / Service / Pod** | نمونهٔ در حال اجرا از یک ایمیج | سرویس `docservice` |

**چند کانتینر جدا ≠ چند ایمیج جدا.**  
یک ایمیج می‌تواند چند نقش را با `command`/`entrypoint` مختلف اجرا کند.

### ایمیج‌های Docs این ریپو
| ایمیج | محتوا | پیش‌فرض شروع | توضیح |
|--------|--------|--------------|--------|
| `docs-cluster-*` | کل فایل‌سیستم Docs | entrypoint عمومی + معمولاً docservice | **ایمیج اصلی چندنقشه** |
| `docs-proxy-*` | **همان محتوا** | `proxy-docker-entrypoint.sh` | مستعار / سازگاری Helm |
| `docs-docservice-*` | **همان محتوا** | `CMD docservice` | مستعار |
| `docs-converter-*` | **همان محتوا** | `CMD converter` | مستعار |
| `docs-utils` | اسکریپت‌های کمکی K8s | python | ادیتور نیست |
| `docs-metrics` | StatsD + کانفیگ | statsd | متریک |
| `docs-postgresql` | `postgres` + `createdb.sql` | postgres | shortcut دیتابیس |

طبق Dockerfile آپ‌استریم: stageهای proxy/docservice/converter **فایل اضافه نمی‌کنند**؛ فقط حالت پیش‌فرض اجرا فرق دارد.

### در Compose فعلی این ریپو
| سرویس | نقش runtime | ایمیج استفاده‌شده | چطور نقش تعیین می‌شود |
|--------|-------------|-------------------|-------------------------|
| `proxy` | Nginx لبه، پورت ۸۰ | **`docs-cluster-*`** | `entrypoint: proxy-docker-entrypoint.sh` |
| `docservice` | ادیتور/API | **`docs-cluster-*`** | `command: [docservice]` |
| `converter` | تبدیل فایل | **`docs-cluster-*`** | `command: [converter]` |
| `adminpanel` | پنل ادمین | **`docs-cluster-*`** | `command: [adminpanel]` |

به همین دلیل در Docker Desktop اغلب `docs-proxy-de` / `docs-docservice-de` / `docs-converter-de` وضعیت **Unused** دارند: ساخته شده‌اند، ولی کانتینری آن تگ را اجرا نمی‌کند.

### سوءتفاهم رایج
- **غلط:** «Compose به ایمیج جدا نیاز ندارد ولی Kubernetes نیاز دارد.»
- **درست:** هر دو می‌توانند با یک `docs-cluster` کار کنند. Helm فقط به‌صورت پیش‌فرض نام جدا می‌گذارد (backward compatibility). نیاز واقعی = چند **workload** جدا، نه لزوماً چند **repository ایمیج**.

---

## 5. لیست ایمیج‌های رجیستری شخصی

کاربر این‌ها را دارد (تگ `none-root` یعنی بیلد با هدف non-root):

```text
repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-metrics:none-root
repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-postgresql:none-root
repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-utils:none-root
repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-converter-de:none-root
repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-proxy-de:none-root
repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-cluster-de:none-root
repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-docservice-de:none-root
```

---

## 6. Docker Compose — اجباری / اختیاری

### هسته Docs (بدون این‌ها ادیتور کار نمی‌کند)
| سرویس | وضعیت | کاربرد | ایمیج پیشنهادی |
|--------|--------|--------|----------------|
| `proxy` | **اجباری** | ورودی HTTP (۸۰→۸۸۸۸) | `docs-cluster-de` یا `docs-proxy-de` |
| `docservice` | **اجباری** | ادیتور، API، co-editing | `docs-cluster-de` + command یا `docs-docservice-de` |
| `converter` | **اجباری برای کار واقعی** | تبدیل فرمت | `docs-cluster-de` + command یا `docs-converter-de` |

### زیرساخت داخل compose (برای راحتی لوکال اجباری شده)
| سرویس | وضعیت | کاربرد | ایمیج |
|--------|--------|--------|--------|
| `postgresql` | **اجباری در این فایل** | DB + schema | `docs-postgresql` یا Postgres+SQL |
| `redis` | **اجباری** | کش/هماهنگی | `redis:7` |
| `rabbitmq` | **اجباری** | صف docservice↔converter | `rabbitmq:3` |

### اختیاری
| سرویس | کاربرد | اگر نباشد |
|--------|--------|-----------|
| `adminpanel` | پنل مدیریت | سند باز می‌شود؛ پنل نیست |
| `metrics` | StatsD | اگر METRICS روشن باشد بهتر است باشد یا متریک را خاموش کن |
| `utils` | ابزار K8s | برای تست سند لوکال لازم نیست |
| `example` | دمو | Docs کار می‌کند؛ صفحهٔ نمونه نیست (profile جدا) |

### حداقل برای «Docs کار کند» در Compose
`proxy` + `docservice` + `converter` + `postgresql` + `redis` + `rabbitmq`

### ایمیج‌های ساخته‌شده که Compose لزوماً لازم ندارد
- `docs-proxy-de` / `docs-docservice-de` / `docs-converter-de` → اختیاری اگر از cluster استفاده کنی
- `docs-utils` → برای ادیتور لازم نیست

---

## 7. Kubernetes / Helm — اجباری / اختیاری

### هسته Docs (اجباری)
| Workload | کاربرد | ایمیج |
|----------|--------|--------|
| Deployment `proxy` + Service/Ingress | ورودی ترافیک | `docs-cluster-de` یا `docs-proxy-de` |
| Deployment `docservice` | ادیتور/API | `docs-cluster-de` + args یا `docs-docservice-de` |
| Deployment `converter` | تبدیل (قابل scale) | `docs-cluster-de` + args یا `docs-converter-de` |
| PVC/shared storage | کش فایل مشترک بین podها | — |

### وابستگی‌های خارجی (اجباری برای Docs، معمولاً خارج از chart)
| سرویس | کاربرد | باید ایمیج ONLYOFFICE باشد؟ |
|--------|--------|------------------------------|
| PostgreSQL | DB | **خیر** — Postgres معمولی + `createdb.sql` |
| Redis | کش | خیر |
| RabbitMQ/ActiveMQ | صف | خیر |

### اختیاری روی K8s
- `adminpanel`
- `metrics`
- `utils` / observer
- `example`
- Deployment با ایمیج `docs-postgresql` (معمولاً توصیه نمی‌شود)
- ایمیج‌های split اگر همه را روی `docs-cluster-de` بگذاری

### نمونه values با رجیستری کاربر
```yaml
proxy:
  image:
    repository: repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-cluster-de
    tag: none-root
docservice:
  image:
    repository: repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-cluster-de
    tag: none-root
converter:
  image:
    repository: repo.mohaymen.ir:3060/starrelease/onlyoffice/docs-cluster-de
    tag: none-root

podSecurityContext:
  enabled: true
  fsGroup: 101
```

امنیت کانتینر پیشنهادی: `runAsUser: 101`, `runAsGroup: 101`, `runAsNonRoot: true`

Chart رسمی: [ONLYOFFICE/Kubernetes-Docs](https://github.com/ONLYOFFICE/Kubernetes-Docs)

---

## 8. چرا لیست اجباری Compose با K8s فرق دارد؟

**معماری Docs یکی است.** فرق در «ابزار و فرض استقرار» است:

| موضوع | Compose این ریپو | Kubernetes |
|--------|------------------|------------|
| هدف | stack کامل لوکال با یک دستور | استقرار روی کلاستر سازمانی |
| Postgres/Redis/MQ | داخل همان فایل → اجباریِ آن فایل | معمولاً خارجی → اجباریِ Docs ولی شکل آوردنش آزاد |
| هسته Docs | اجباری | اجباری (یکی) |
| تعداد ایمیج Docs | عملاً ۱ (`cluster`) برای چند سرویس | ۱ کافی است؛ یا ۳ نام برای defaults Helm |
| `docs-postgresql` | در compose فعلی برای راحتی آمده | اختیاری؛ Postgres استاندارد بهتر است |
| شبکه | `ports: 80:8888` | Service + Ingress |
| storage | named volume | PVC / storage کلاس؛ در چندنودی حیاتی‌تر |

**جمع یک‌خطی:**  
در Compose، «اجباری» یعنی چیزی که فایل compose برای بالا آمدن همان stack به آن وابسته است.  
در K8s، «اجباری» یعنی چیزی که بدون آن Docs از کار می‌افتد — ولی DB/Redis/MQ را خودت جدا می‌آوری.

---

## 9. Non-root (کاربر ds / UID 101)

- این ریپو از قبل `USER ds` دارد؛ کار اضافه‌ای برای «فعال کردن non-root در Dockerfile اصلی» لازم نبود (جز فیکس‌های ویندوز/compose).
- روی K8s باید `securityContext` با 101 و `fsGroup: 101` برای PVC ست شود.
- ایمیج رسمی monolithic `documentserver` معمولاً root است و با این ریپو یکی نیست.
- تگ `none-root` در رجیستری کاربر صرفاً نام‌گذاری بیلد خودش است.

---

## 10. مشکل CRLF / bash\r

### علائم
کانتینرها Restart می‌شوند با:
```text
env: 'bash\r': No such file or directory
```

### علت
روی ویندوز، فایل‌های `.sh` گاهی با CRLF چک‌اوت می‌شوند → داخل ایمیج لینوکس shebang می‌شود `bash\r`.

### نکته حیاتی
این باگ **زمان بیلد** است. اگر ایمیج خراب را push کنی، روی Kubernetes لینوکس هم می‌ترکد — فقط مشکل «اجرای ویندوز» نیست.

### اقدامات انجام‌شده
- تبدیل اسکریپت‌ها به LF
- `.gitattributes` با `eol=lf`
- بیلد مجدد موفق

### اگر دوباره برگشت
- LF را enforce کن و/یا `sed` strip را به Dockerfile برگردان
- Docs images را دوباره بیلد کن

---

## 11. Community / Developer / Enterprise و لایسنس

### دو لایه
1. **کدام پکیج/ایمیج** (Community در برابر `-de`/`-ee`) → با `PRODUCT_EDITION`
2. **فعال‌سازی کامل تجاری** → فایل `license.lic` (معمولاً `/var/www/onlyoffice/Data/license.lic`)

دانلود RPM/ایمیج `-de` عمومی است؛ لایسنس کامل نیست. بدون `license.lic` سرویس ممکن است بالا بیاید ولی WARN می‌دهد و امکانات کامل/cluster محدود است.

### Community از ۹.۴
سقف سخت ~۲۰ اتصال هم‌زمان از Community برداشته شده (اعلام رسمی ONLYOFFICE).  
صفحهٔ مقایسه هنوز ممکن است «up to 20 recommended» بگوید = توصیه، نه لزوماً قفل سخت.  
Clustering رسمی تجاری برای EE/DE است. معماری Community ۹.۴ ساده‌تر شده.

منابع:
- https://www.onlyoffice.com/blog/2026/05/onlyoffice-docs-9-4
- https://helpcenter.onlyoffice.com/docs/docs-changelog.aspx
- https://www.onlyoffice.com/compare-editions

### برای فروش محصول کاربر
باید **Developer** بخرد (نه تکیه روی Community برای production فروشی به‌خاطر AGPL و نبود white-label/cluster تجاری تمیز).

### کمک ممنوع
دور زدن محدودیت لایسنس / کرک `license.lic` / پچ سقف اتصال برای استفاده بدون خرید.

---

## 12. Postgres و schema

- `docs-postgresql` = Postgres رسمی + کپی `createdb.sql` در init.
- نسخهٔ ۱۵ اجباری نیست؛ رسمی: **≥ ۱۲.۹**؛ CI این ریپو ۱۲–۱۶ را تست کرده.
- Postgres خالی بدون schema → خطا.
- Postgres معمولی + یک‌بار `createdb.sql` → OK (روی K8s با Job/Init رایج است).
- مسیر SQL تقریبی در پکیج:  
  `.../documentserver/server/schema/postgresql/createdb.sql`

---

## 13. فونت‌های کاستوم

پوشه `fonts/` در بیلد می‌رود به:
`/var/www/onlyoffice/documentserver/core-fonts/custom/`

فونت‌های موجود در پروژه:
- `B-NAZANIN.TTF`
- `IRANSansX-Regular.ttf`
- `Vazir.ttf`
- `Yekan.ttf`
- `.placeholder`

جایگذاری درست است؛ فقط باید ایمیج بعد از گذاشتن فونت‌ها بیلد شده باشد.

---

## 14. بیلد و اجرا

### بیلد
```powershell
# PowerShell
cd E:\github\Docker-Docs
.\build.ps1

# Git Bash
./build.sh
```

### Compose
```powershell
docker compose up -d
docker compose ps
curl http://localhost/healthcheck
docker compose exec docservice id
docker compose logs -f proxy docservice converter
docker compose down
```

آدرس: `http://localhost` (`80:8888`)

### خطاهای bekار رفته و راه‌حل
| خطا | راه‌حل |
|-----|--------|
| `neither an image nor a build` برای postgres/metrics | فیلد `image` در compose |
| `bash\r` | LF + بیلد مجدد |
| proxy: `host not found ... example:3000` | `EXAMPLE_HOST_PORT` به هاست موجود یا بالا آوردن example |
| `license.lic` ENOENT | برای -de بدون لایسنس طبیعی؛ اختیاری تا خرید |

---

## 15. قیمت‌گذاری (خلاصه)

منابع:
- Developer: https://www.onlyoffice.com/developer-edition-prices.aspx (ماشین‌حساب؛ نمونه حدود از ~$3500)
- Enterprise: https://www.onlyoffice.com/docs-enterprise-prices (از حدود $1500)
- Reseller نمونه connections: ComponentSource (۲۵۰/۵۰۰/۱۰۰۰ اتصال سالانه)

قیمت روی **اتصالات هم‌زمان** (تب ادیتور باز) است، نه تعداد اکانت کل.  
برای embed در محصول فروشی → Developer. برای استفاده داخلی سازمان → Enterprise.

---

## 16. کارهایی که نباید انجام شود

- کرک/جعل `license.lic`
- پچ برداشتن محدودیت اتصال برای دور زدن خرید
- فرض اینکه retag کردن `documentserver` رسمی = ایمیج non-root این ریپو
- فرض اینکه Unused بودن ایمیج‌های split یعنی روی K8s حتماً لازم‌اند
- Commit کردن `.env` با secret واقعی بدون آگاهی

---

## 17. وضعیت فعلی و گام بعدی

### انجام‌شده
- بیلد ایمیج‌های `-de` با هدف non-root
- فیکس Compose برای ویندوز/Compose v2
- فیکس CRLF عملی (با rebuild)
- healthcheck لوکال موفق
- push به رجیستری شخصی با تگ `none-root`
- مستندات HTML/MD

### پیشنهادی بعدی
1. Helm values با رجیستری `repo.mohaymen.ir:3060/starrelease/onlyoffice/...` و تگ `none-root`
2. `securityContext` با 101 + PVC
3. Postgres/Redis/MQ خارجی + Job برای `createdb.sql`
4. در صورت نیاز production: `license.lic`
5. اگر CRLF برگشت: sed در Dockerfile + rebuild
6. smoke test: `/healthcheck` → `true`

---

## 18. ایندکس فایل‌های مستندات

| فایل | محتوا |
|------|--------|
| `docs/COMPLETE-KNOWLEDGE.md` | **همین فایل — دانش کامل** |
| `docs/fa-build-report.md` | Handoff کوتاه‌تر برای AI (انگلیسی‌محورتر در نسخهٔ قبلی؛ این فایل کامل‌تر است) |
| `docs/fa-build-report.html` | گزارش HTML |
| `docs/fa-docker-compose.html` | Compose: اجباری/اختیاری با جدول |
| `docs/fa-kubernetes-helm.html` | K8s/Helm: اجباری/اختیاری + چرا با Compose فرق دارد |
| `docs/fa-images-cluster-vs-split.md` | تفاوت ایمیج cluster و split |
| `docs/fa-images-cluster-vs-split.html` | همان به‌صورت HTML |

---

*آخرین به‌روزرسانی بر اساس جلسهٔ کار روی Docker-Docs (بیلد ویندوز، Compose، non-root، رجیستری Mohaymen، مستندسازی).*
