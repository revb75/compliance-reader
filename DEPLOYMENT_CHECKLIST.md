# ✅ ComplianceReader Deployment Checklist

## 📦 Files You Have (6 total)

1. ✅ index.html - Landing page
2. ✅ upload.html - Add documents (BYOS)
3. ✅ assign.html - Assign to employees  
4. ✅ reader.html - Document reader with tracking
5. ✅ dashboard.html - Analytics & reports
6. ✅ COMPLETE_PRODUCTION_SCHEMA.sql - Database

---

## 🚀 Deployment Steps

### ☐ Step 1: Supabase (5 min)

- [ ] Go to supabase.com
- [ ] Create new project
- [ ] Wait 60 seconds
- [ ] SQL Editor → New Query
- [ ] Paste entire COMPLETE_PRODUCTION_SCHEMA.sql
- [ ] Click Run
- [ ] See "Success" message
- [ ] Settings → API
- [ ] Copy Project URL
- [ ] Copy anon public key

**Your credentials:**
```
URL:  _________________________________
Key:  _________________________________
```

### ☐ Step 2: Update Files (2 min)

Update these 4 files with your Supabase credentials:

- [ ] upload.html (lines ~237)
- [ ] assign.html (lines ~240)
- [ ] reader.html (lines ~365)
- [ ] dashboard.html (lines ~263)

Find:
```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

Replace with your actual values from Step 1.

### ☐ Step 3: Git Setup (2 min)

```bash
# Create folder
mkdir compliance-reader
cd compliance-reader

# Copy all 6 files here

# Init git
git init
git add .
git commit -m "Initial commit"

# Push to GitHub
git remote add origin https://github.com/YOUR_USERNAME/compliance-reader.git
git push -u origin main
```

- [ ] Folder created
- [ ] All 6 files copied
- [ ] Git initialized
- [ ] Pushed to GitHub

### ☐ Step 4: Deploy to Vercel (3 min)

```bash
npm i -g vercel
vercel --prod
```

- [ ] Vercel CLI installed
- [ ] Deployed successfully
- [ ] Got production URL

**Your URL:** https://________________________________

---

## ✅ Testing (5 min)

### Test 1: Landing Page
- [ ] Open https://your-site.vercel.app/
- [ ] See landing page with 3 cards
- [ ] Click "Analytics Dashboard"

### Test 2: Dashboard
- [ ] Dashboard loads
- [ ] Shows stats (0s initially)
- [ ] Shows demo documents (from SQL)
- [ ] Click "Add Document"

### Test 3: Upload
- [ ] Upload form loads
- [ ] Enter test document:
  - Title: "Test Doc"
  - Slug: "test-doc"
  - URL: "https://example.com/test.pdf"
  - Type: "Policy"
- [ ] Click "Add Document"
- [ ] See success message
- [ ] Redirects to dashboard

### Test 4: Dashboard Again
- [ ] See your test document
- [ ] Stats updated
- [ ] Click "View" on test document

### Test 5: Reader
- [ ] Reader opens with ?doc=test-doc&user=demo
- [ ] Shows progress bar
- [ ] Shows timer
- [ ] Scroll down
- [ ] Wait 5 seconds
- [ ] Status says "Saved"

### Test 6: Check Supabase
```sql
SELECT * FROM documents;
SELECT * FROM document_sessions;
SELECT * FROM reading_events;
```

- [ ] See your test document in documents
- [ ] See reading session in document_sessions
- [ ] See scroll events in reading_events

---

## 🎉 Success Criteria

You're ready to sell when:

- [x] All 6 files deployed
- [x] Landing page loads
- [x] Can add documents via URL
- [x] Dashboard shows documents
- [x] Reader tracks scrolling
- [x] Data appears in Supabase
- [x] Completion modal works (scroll to 95%)

---

## 🐛 If Something Breaks

### Landing page won't load
→ Check Vercel deployment logs

### "Relation does not exist"
→ Re-run COMPLETE_PRODUCTION_SCHEMA.sql in Supabase

### Documents not saving
→ Check credentials in HTML files

### Reader not tracking
→ Check browser console (F12) for errors

### Nothing works
→ Delete Supabase project, start over (it's fast!)

---

## 📞 Quick Reference

**Supabase Dashboard:** https://supabase.com/dashboard  
**Vercel Dashboard:** https://vercel.com/dashboard  
**Your GitHub Repo:** https://github.com/YOUR_USERNAME/compliance-reader

---

## 💰 Next Steps After Launch

1. ✅ Get first customer
2. ✅ Enable RLS in Supabase
3. ✅ Add Supabase Auth
4. ✅ Add email notifications
5. ✅ Set up Stripe billing
6. ✅ Add your domain
7. ✅ Scale to 10 customers → $20K MRR 🎯

---

**Total time: 10 minutes from zero to deployed! 🚀**
