# פריסת אוטומציה: שמירת פרטי קשר מדיה חברתית

## דרישות מקדימות
- Docker + Docker Compose מותקנים על השרת
- כתובת IP ציבורית או דומיין לשרת (כדי ש-ManyChat יוכל לשלוח webhook)
- Airtable Personal Access Token

---

## שלב 1 — הכנת קובץ .env

```bash
cd sivaninvest-workflows
cp env.example .env
nano .env
```

מלא את הערכים:
```env
AIRTABLE_API_KEY=pat...   # הטוקן שלך מ-Airtable
N8N_HOST=0.0.0.0
N8N_PROTOCOL=http
WEBHOOK_URL=http://YOUR_SERVER_IP:5678/
N8N_API_KEY=              # השאר ריק בהתחלה
```

---

## שלב 2 — הפעלת n8n

```bash
docker compose -f sivaninvest-workflows/docker-compose.yml --env-file sivaninvest-workflows/.env up -d
```

השירות `n8n-init` ייבא אוטומטית:
- את ה-credential של Airtable
- את ה-workflow של ManyChat-Airtable

לאחר ~20 שניות, n8n יהיה זמין בכתובת: `http://YOUR_SERVER_IP:5678`

---

## שלב 3 — הפעלת ה-Workflow

1. כנס לממשק n8n: `http://YOUR_SERVER_IP:5678`
2. צור משתמש admin בעת הכניסה הראשונה
3. עבור לתפריט **Workflows**
4. מצא את ה-workflow **"שמירת פרטי קשר מדיה חברתית"**
5. פתח אותו ולחץ **Activate** (מתג בפינה הימנית העליונה)

> **חשוב:** לאחר ה-Activate, תוקצה ה-Webhook URL הסופית.
> העתק אותה מ: Webhook node → לחץ עליו → "Webhook URLs"

---

## שלב 4 — קישור ManyChat

ה-Webhook URL תיראה כך:
```
http://YOUR_SERVER_IP:5678/webhook/manychat-leads-sync
```

ב-ManyChat:
1. פתח את ה-Flow שלך
2. הוסף Action: **External Request**
3. Method: **POST**
4. URL: `http://YOUR_SERVER_IP:5678/webhook/manychat-leads-sync`
5. Headers: `Content-Type: application/json`
6. Body (JSON):
```json
{
  "first_name": "{{first name}}",
  "last_name": "{{last name}}",
  "email": "{{email}}",
  "phone": "{{phone}}",
  "platform": "Instagram",
  "post_url": "{{post_url}}",
  "trigger_message": "{{trigger_message}}",
  "subscriber_id": "{{user id}}",
  "content_id": "{{content_id}}",
  "dm_keyword": "{{dm_keyword}}"
}
```

ראה `manychat-setup-guide.md` בריפו `sivaninvestgroup` לפירוט מלא.

---

## בדיקה ידנית (curl)

```bash
curl -X POST http://YOUR_SERVER_IP:5678/webhook/manychat-leads-sync \
  -H 'Content-Type: application/json' \
  -d '{
    "first_name": "ישראל",
    "last_name": "ישראלי",
    "email": "test@example.com",
    "phone": "0501234567",
    "platform": "Instagram",
    "post_url": "https://instagram.com/p/test123",
    "trigger_message": "רוצה לדעת יותר",
    "subscriber_id": "sub_test_001",
    "content_id": "test123",
    "dm_keyword": "מידע"
  }'
```

תגובה מצופה: `{"status":"ok"}`

בדוק ב-Airtable שנוצר רשומה חדשה בטבלת **לקוחות** ואירוע חדש בטבלת **Lead Events**.

---

## לוגים

```bash
# לוגים של n8n
docker compose -f sivaninvest-workflows/docker-compose.yml logs -f n8n

# לוגים של תהליך ה-init
docker compose -f sivaninvest-workflows/docker-compose.yml logs n8n-init
```

---

## הפסקה ועדכון

```bash
# עצור
docker compose -f sivaninvest-workflows/docker-compose.yml down

# עדכן ל-n8n חדש
docker compose -f sivaninvest-workflows/docker-compose.yml pull && \
docker compose -f sivaninvest-workflows/docker-compose.yml up -d
```
