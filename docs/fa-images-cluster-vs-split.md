# ایمیج‌های جدا در برابر `docs-cluster` — کی لازم است و کی نه؟

## اول فرق «ایمیج» و «کانتینر» را قاطی نکن

| مفهوم | چیست؟ | مثال |
|--------|--------|------|
| **Image (ایمیج)** | بستهٔ فقط‌خواندنی روی دیسک/رجیستری | `onlyoffice/docs-cluster-de:latest` |
| **Container / Service / Pod** | نمونهٔ در حال اجرا که از یک ایمیج start می‌شود | سرویس compose به‌نام `docservice` |

یک ایمیج می‌تواند هم‌زمان پایهٔ **چند کانتینر با نقش متفاوت** باشد.  
چند کانتینر جدا ≠ چند ایمیج جدا.

### جدول ایمیج‌ها (محصول بیلد)

| ایمیج | محتوا | پیش‌فرض شروع | اجباری؟ |
|--------|--------|--------------|---------|
| `docs-cluster-*` | کل فایل‌سیستم Docs | entrypoint عمومی + معمولاً docservice | **اصلی** |
| `docs-proxy-*` | همان محتوا | entrypoint پروکسی | اختیاری (مستعار) |
| `docs-docservice-*` | همان محتوا | CMD=docservice | اختیاری (مستعار) |
| `docs-converter-*` | همان محتوا | CMD=converter | اختیاری (مستعار) |
| `docs-utils` / `docs-metrics` / `docs-postgresql` | نقش‌های جانبی واقعاً متفاوت | مخصوص خودشان | جدا از ادیتور |

طبق Dockerfile آپ‌استریم: stageهای proxy/docservice/converter **فایل اضافه نمی‌کنند**؛ فقط حالت پیش‌فرض اجرا فرق دارد.

### جدول کانتینرها در Compose این ریپو

| کانتینر/سرویس | کار واقعی | از کدام ایمیج؟ | چطور نقش مشخص می‌شود؟ |
|----------------|-----------|----------------|------------------------|
| `proxy` | Nginx لبه، پورت ۸۰ | `docs-cluster-*` | `entrypoint: proxy-docker-entrypoint.sh` |
| `docservice` | ادیتور/API | `docs-cluster-*` | `command: [docservice]` |
| `converter` | تبدیل فایل | `docs-cluster-*` | `command: [converter]` |
| `adminpanel` | ادمین | `docs-cluster-*` | `command: [adminpanel]` |
| `postgresql` / `redis` / `rabbitmq` / `metrics` / `utils` | زیرساخت | ایمیج خودشان | — |

برای همین در Docker Desktop اغلب `docs-proxy-de` و مشابهش **Unused**‌اند: ایمیج ساخته شده، ولی هیچ کانتینری آن تگ را اجرا نمی‌کند؛ همه از `docs-cluster-de` می‌آیند.

### جدول workload روی Kubernetes

| Deployment منطقی | باید Pod جدا باشد؟ | باید repository ایمیج جدا باشد؟ |
|------------------|---------------------|----------------------------------|
| proxy | بله | خیر (می‌تواند همان `docs-cluster`) |
| docservice | بله | خیر |
| converter | بله | خیر |

پیش‌فرض Helm گاهی نام‌های جدا می‌گذارد؛ این قرارداد values است نه اجبار kube-apiserver.

---

## سوءتفاهم رایج

جملهٔ اشتباه:

> «در Docker Compose ایمیج‌های جدا لازم نیست، ولی در Kubernetes لازم است.»

جملهٔ درست:

> **نه Compose و نه Kubernetes از نظر فنی مجبور به ایمیج‌های جدا نیستند.**  
> فرق فقط در **قرارداد پیش‌فرض فایل اجرا** است:
>
> - `docker-compose.yml` این ریپو از اول روی **یک ایمیج چندنقشی** (`docs-cluster-*`) نوشته شده است.
> - Helm chart رسمی به‌صورت پیش‌فرض (برای سازگاری عقب‌رو) نام‌های جدا می‌گذارد؛ ولی همان chart صریحاً اجازه می‌دهد همه را به `docs-cluster-*` ببری.

پس موضوع «Compose در برابر K8s» نیست؛ موضوع «**چگونه نقش پروسس داخل کانتینر انتخاب می‌شود**» و «**مقادیر پیش‌فرض tooling چه ایمیجی را می‌کشد**» است.

---

## لایهٔ ۱ — معماری منطقی سرویس‌ها (برای هر دو محیط یکی است)

ONLYOFFICE Docs در این ریپو به چند **نقش پروسس** شکسته می‌شود:

| نقش | مسئولیت |
|-----|----------|
| **proxy** | Nginx لبه؛ TLS termination اختیاری در لایه بالا؛ مسیریابی به docservice/adminpanel/example |
| **docservice** | هستهٔ همکاری روی سند، API، وب‌سوکت ادیتور |
| **converter** | تبدیل فرمت / کارهای CPU-bound؛ معمولاً بیشترین scale افقی |
| **adminpanel** | پنل مدیریت (در editionهای تجاری) |

این تفکیک **منطقی و اجرایی** است (چند Deployment یا چند service در compose)، نه الزاماً تفکیک **فایل ایمیج**.

معماری هدف در هر دو محیط:

```text
Client → proxy → docservice
               ↘ converter  (از طریق AMQP معمولاً)
         Redis / PostgreSQL / RabbitMQ مشترک
```

Compose و Kubernetes هر دو این توپولوژی را پیاده می‌کنند. تفاوت orchestration است، نه الزام به تگ ایمیج متفاوت.

---

## لایهٔ ۲ — واقعیت Dockerfile: ایمیج‌های جدا «مستعار نقش» هستند

در `Dockerfile` تارگت اصلی runtime تقریباً همه فایل‌های لازم Docs را دارد (`docs` / بعداً تگ‌شده به `docs-cluster-*`).

سپس برای سازگاری:

```dockerfile
FROM docs AS proxy
ENTRYPOINT ["proxy-docker-entrypoint.sh"]

FROM docs AS docservice
CMD ["docservice"]

FROM docs AS converter
CMD ["converter"]
```

کامنت رسمی ریپو:

> No additional files or configuration are added here; the image is identical to `docs` except for the default execution mode.

یعنی:

| ایمیج | محتوا نسبت به `docs-cluster` | تفاوت واقعی |
|--------|------------------------------|-------------|
| `docs-cluster-*` | کامل | پیش‌فرض معمولاً `CMD ["docservice"]` + entrypoint عمومی |
| `docs-proxy-*` | همان لایه‌ها | فقط `ENTRYPOINT` پیش‌فرض proxy |
| `docs-docservice-*` | همان لایه‌ها | فقط `CMD` پیش‌فرض docservice |
| `docs-converter-*` | همان لایه‌ها | فقط `CMD` پیش‌فرض converter |

از نگاه OCI image، این‌ها نسخه‌های «همین فایل سیستم با metadata شروع متفاوت» هستند (و در بیلد تو اغلب همان digest/اندازه ~یکسان دیده می‌شود).  
**هیچ باینری اضافه‌ای برای K8s داخل `docs-docservice-de` نیست که در `docs-cluster-de` نباشد.**

---

## لایهٔ ۳ — Docker Compose این ریپو چه می‌کند؟

در `docker-compose.yml` فعلی:

```yaml
proxy:
  image: .../docs-cluster-de:...
  entrypoint: ["proxy-docker-entrypoint.sh"]

docservice:
  image: .../docs-cluster-de:...
  command: ["docservice"]

converter:
  image: .../docs-cluster-de:...
  command: ["converter"]
```

اینجا Compose صریحاً می‌گوید:

1. همه کانتینرها از **یک repository/tag** بیایند.
2. نقش با **بازنویسی entrypoint/command در سطح سرویس** تعیین شود.

نتیجه در Docker Desktop:

- `docs-cluster-de` → In use (چند کانتینر)
- `docs-proxy-de` / `docs-docservice-de` / `docs-converter-de` → Unused

Unused یعنی «هیچ کانتینر در حال اجرایی به این ID اشاره نمی‌کند»، نه «روی کوبر حتماً لازم‌اند».  
`build.yml` آن‌ها را برای سازگاری/هلَم قدیمی هم می‌سازد؛ compose لوکال تصمیم گرفته ازشان استفاده نکند.

### چرا این طراحی برای Compose منطقی است؟

- یک pull/tag برای لوکال ساده‌تر است.
- حجم دیسک کمتر وقتی GC نکنی روی تگ‌های تکراری جدا.
- بازنویسی `command` در Compose idiomatic و شفاف است.
- برای دمو، یک ایمیج = یک منبع حقیقت.

### آیا Compose «نمی‌تواند» از ایمیج جدا استفاده کند؟

می‌تواند. فقط این فایل طوری نوشته نشده. اگر بنویسی:

```yaml
docservice:
  image: onlyoffice/docs-docservice-de:latest
```

باز هم کار می‌کند، چون محتوا یکی است.

---

## لایهٔ ۴ — Kubernetes / Helm چه می‌کند؟

### ۴.۱ نیاز واقعی K8s

Kubernetes به «سه‌تا ایمیج» نیاز ندارد. نیاز واقعی‌اش:

- چند **Workload جدا** (Deployment/StatefulSet) برای scale و lifecycle جدا
- هر Pod با `command`/`args` یا `ENTRYPOINT` مناسب نقشش
- Service/Endpoints برای کشف سرویس
- PVC، SecurityContext، probes، HPA و …

می‌توانی سه Deployment داشته باشی که **همه** `image: docs-cluster-de:9.4.1` باشند و فقط args فرق کند — دقیقاً مدل Compose.

### ۴.۲ رفتار پیش‌فرض Helm chart رسمی

Chart [Kubernetes-Docs](https://github.com/ONLYOFFICE/Kubernetes-Docs) به‌صورت تاریخی برای هر کامپوننت repository جدا دارد، مثلاً:

- `docservice.image.repository = onlyoffice/docs-docservice-de`
- `proxy.image.repository = onlyoffice/docs-proxy-de`
- `converter.image.repository = onlyoffice/docs-converter-de`

دلیل مستند chart:

> kept for **backward compatibility**. You can use `onlyoffice/docs-cluster-de` instead.

یعنی Helm قدیمی‌تر فرض می‌کرد هر سرویس تگ جدا دارد (شاید برای آپدیت/کش جدا یا قرارداد قدیمی). بعداً ONLYOFFICE ایمیج یکپارچه `docs-cluster` را معرفی/ترویج کرد ولی defaults را برای نشکستن آپگریدها نگه داشت.

### ۴.۳ پس «در کوبر نیاز است» چه وقتی درست است؟

فقط در این حالت‌ها:

1. **values پیش‌فرض Helm را عوض نمی‌کنی** → pull می‌کند نام‌های جدا → باید آن تگ‌ها در رجیستری‌ات موجود باشند (یا chart به Docker Hub دسترسی داشته باشد).
2. **سیاست سازمانی** داری که هر microservice یک repository جدا داشته باشد و ImagePolicy/Admission روی نام‌ها سخت‌گیر است.
3. **ابزار CI/CD**ت digest هر سرویس را جدا pin می‌کند و نمی‌خواهی همه یک digest مشترک داشته باشند (با اینکه محتوا یکیست).
4. می‌خواهی از **ENTRYPOINT پیش‌فرض ایمیج** استفاده کنی و در PodSpec `command` را override نکنی (ساده ولی غیرضروری).

و در این حالت‌ها نیاز **استقلال نقش در کلاستر نیست**؛ نیاز **تطابق نام ایمیج با قرارداد tooling** است.

### ۴.۴ چه وقتی در کوبر هم نیاز نیست؟

اگر در values بنویسی (مفهومی):

```yaml
docservice.image.repository: registry/onlyoffice/docs-cluster-de
proxy.image.repository:      registry/onlyoffice/docs-cluster-de
converter.image.repository:  registry/onlyoffice/docs-cluster-de
```

و مطمئن شوی chart برای proxy ورود صحیح entrypoint/command را تنظیم می‌کند (در نسخهٔ مدرن با cluster image پشتیبانی شده)، آنگاه:

- فقط یک ایمیج در رجیستری کافی است  
- مثل compose  
- ایمیج‌های جدا unused/قابل حذف‌اند

---

## لایهٔ ۵ — جدول تصمیم‌گیری

| سؤال | جواب کوتاه |
|------|------------|
| آیا از نظر باینری سه‌تا ایمیج جدا لازمند؟ | **خیر** — محتوا با cluster یکی است |
| آیا از نظر معماری چند پروسس جدا لازمند؟ | **بله** — proxy / docservice / converter جدا scale می‌شوند |
| Compose این ریپو چرا سه‌تا را لازم ندارد؟ | چون نقش را با `command`/`entrypoint` روی همان `cluster` می‌دهد |
| Helm چرا انگار سه‌تا لازم دارد؟ | چون **پیش‌فرض نام repository** جداست (سازگاری عقب‌رو)، نه اجبار موتور K8s |
| کی باید هر سه را push کنی؟ | وقتی values را روی نام‌های جدا می‌گذاری / از defaults Helm استفاده می‌کنی |
| کی فقط `docs-cluster` کافی است؟ | Compose پیش‌فرض این ریپو؛ یا Helm با override همه به cluster |
| Unused در Desktop یعنی چه؟ | این لحظه هیچ کانتینری آن tag را اجرا نمی‌کند |

---

## لایهٔ ۶ — قیاس مفهومی

فکر کن یک برنامهٔ Node داری با یک artifact:

```bash
node dist/index.js proxy
node dist/index.js docservice
node dist/index.js converter
```

می‌توانی سه کانتینر از **همان image** بسازی و آرگومان عوض کنی (مدل `docs-cluster` + Compose).  
می‌توانی سه Dockerfile بسازی که فقط `CMD` پیش‌فرض فرق کند و سه تگ بدهی (مدل `docs-*-de` + defaults Helm).  
هر دو از نظر runtime معادل‌اند؛ دومی فقط نام‌گذاری و قرارداد عملیات است.

---

## لایهٔ ۷ — توصیه عملی برای تیم شما

### محیط توسعه لوکال (Compose)

- روی `docs-cluster-*` بمان.
- ایمیج‌های جدا را می‌توانی بعد از بیلد `docker rmi` کنی اگر فضا مهم است.
- برای تست non-root و healthcheck همین کافی است.

### محیط Kubernetes

1. ترجیح مهندسی: **یک ایمیج `docs-cluster-de` در رجیستری خصوصی** + override همه repositoryها در Helm values.
2. اگر تیم Helm را «دست‌نخورده با defaults» می‌خواهد: هر سه تگ جدا را هم push کن (حتی اگر digest یکسان باشد).
3. همیشه جدا نگه دار:  
   - چند **Deployment** (برای scale)  
   - در برابر چند **repository ایمیج** (اختیاری)

### امنیت / حجم رجیستری

چون لایه‌ها یکی‌اند، ذخیرهٔ چند تگ جدا روی همان daemon اغلب لایه را share می‌کند؛ ولی روی رجیستری ممکن است چند manifest جدا ببینی. از نظر امنیتی محتوا یکی است — اسکن یک digest معمولاً برای هر سه کافی است اگر واقعاً از یک بیلد آمده باشند.

---

## جمع‌بندی نهایی یک‌خطی

**Compose به ایمیج جدا «نیاز ندارد» چون فایل compose نقش را override می‌کند.  
Kubernetes هم ذاتاً به ایمیج جدا «نیاز ندارد»؛ فقط Helm به‌صورت پیش‌فرض نام جدا می‌خواهد مگر values را عوض کنی.**

نیاز واقعی همیشه این است: **چند workload با نقش‌های متفاوت**، نه لزوماً **چند فایل ایمیج متفاوت**.
