#!/usr/bin/env python3
"""
REST API를 사용한 빠른 Firestore 업로드
"""
import requests
import json
import csv
import re
import time

# Firebase 프로젝트 정보
PROJECT_ID = "gnhs-alumni"

def extract_graduation_year(nickname, labels):
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
    return phone.replace('-', '').replace(' ', '').strip()

def upload_to_firestore(doc_id, data):
    """REST API로 Firestore에 문서 업로드"""
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/alumni/{doc_id}"
    
    # Firestore 형식으로 변환
    fields = {}
    for key, value in data.items():
        if isinstance(value, bool):
            fields[key] = {"booleanValue": value}
        elif isinstance(value, int):
            fields[key] = {"integerValue": str(value)}
        else:
            fields[key] = {"stringValue": str(value)}
    
    payload = {"fields": fields}
    
    try:
        # PATCH 요청 (문서 생성 또는 업데이트)
        response = requests.patch(url, json=payload, timeout=10)
        return response.status_code in [200, 201]
    except Exception as e:
        print(f"❌ 업로드 실패 ({doc_id}): {e}")
        return False

print("=" * 80)
print("🚀 REST API로 Firestore 업로드 시작")
print("=" * 80)

uploaded = 0
skipped = 0
failed = 0

with open('contacts.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    
    for idx, row in enumerate(reader, 1):
        name = row.get('First Name', '').strip()
        phone = clean_phone(row.get('Phone 1 - Value', ''))
        
        if not name or not phone or not phone.startswith('010'):
            skipped += 1
            continue
        
        nickname = row.get('Name Suffix', '').strip()
        labels = row.get('Labels', '').strip()
        graduation_year = extract_graduation_year(nickname, labels)
        
        data = {
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
        }
        
        if upload_to_firestore(phone, data):
            uploaded += 1
            if uploaded % 10 == 0:
                print(f"✅ {uploaded}개 업로드 완료...")
        else:
            failed += 1
        
        time.sleep(0.05)  # 너무 빠른 요청 방지

print("\n" + "=" * 80)
print(f"✅ 성공: {uploaded}개")
print(f"⚠️  제외: {skipped}개")
print(f"❌ 실패: {failed}개")
print("=" * 80)
