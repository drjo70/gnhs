#!/usr/bin/env python3
"""
CSV 전체 데이터를 Firestore에 빠르게 업로드 (작은 배치 사용)
"""
import firebase_admin
from firebase_admin import credentials, firestore
import csv
import re
import time

# Firebase Admin SDK 초기화
try:
    cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

def extract_graduation_year(nickname, labels):
    """닉네임이나 라벨에서 회차 정보 추출"""
    text = f"{nickname} {labels}"
    match = re.search(r'(\d{1,2})회', text)
    if match:
        year_suffix = int(match.group(1))
        if year_suffix >= 50:
            return 1900 + year_suffix
        else:
            return 2000 + year_suffix
    return 2000

def clean_phone(phone):
    """전화번호에서 하이픈 제거"""
    return phone.replace('-', '').replace(' ', '').strip()

print("=" * 80)
print("🚀 CSV → Firestore 빠른 업로드 시작")
print("=" * 80)

uploaded_count = 0
skipped_count = 0
batch_count = 0

# 작은 배치 (10개씩)
batch = db.batch()

with open('contacts.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    
    for idx, row in enumerate(reader, 1):
        try:
            name = row.get('First Name', '').strip()
            phone = clean_phone(row.get('Phone 1 - Value', ''))
            
            if not name or not phone or not phone.startswith('010'):
                skipped_count += 1
                continue
            
            nickname = row.get('Name Suffix', '').strip()
            labels = row.get('Labels', '').strip()
            graduation_year = extract_graduation_year(nickname, labels)
            
            alumni_data = {
                'phone': phone,
                'name': name,
                'graduation_year': graduation_year,
                'email': row.get('E-mail 1 - Value', '').strip(),
                'email2': row.get('E-mail 2 - Value', '').strip(),
                'company': row.get('Organization Name', '').strip(),
                'job_title': row.get('Organization Title', '').strip(),
                'department': row.get('Organization Department', '').strip(),
                'address': row.get('Address 1 - Formatted', '').strip(),
                'address2': row.get('Address 2 - Formatted', '').strip(),
                'birth_date': row.get('Birthday', '').strip(),
                'notes': row.get('Notes', '').strip(),
                'phone2': clean_phone(row.get('Phone 2 - Value', '')),
                'profile_photo_url': '',
                'is_verified': False,
                'updated_at': firestore.SERVER_TIMESTAMP,
            }
            
            doc_ref = db.collection('alumni').document(phone)
            batch.set(doc_ref, alumni_data)
            batch_count += 1
            uploaded_count += 1
            
            # 10개마다 커밋
            if batch_count >= 10:
                batch.commit()
                print(f"✅ {uploaded_count}개 업로드 완료...")
                batch = db.batch()
                batch_count = 0
                time.sleep(0.1)  # 속도 제한 방지
            
        except Exception as e:
            print(f"❌ 오류 (행 {idx}): {e}")

# 마지막 배치
if batch_count > 0:
    batch.commit()

print("\n" + "=" * 80)
print(f"✅ 업로드 완료: {uploaded_count}명")
print(f"⚠️  제외: {skipped_count}명")
print("=" * 80)
